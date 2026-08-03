# Headless test for the post-run Spielbewertung (review): the per-type verdict
# rule, the missed-legendary detection over the Pool's existing unlock rules,
# the by-id card lookup, and the Control building the turn list + missed section
# from a crafted mail_result. Pure data + a synchronous build, no timers.
#
# Run:
#   godot --headless --path . -s tests/test_review.gd
extends SceneTree

const Review := preload("res://scenarios/spear_phishing/components/mail_review.gd")
const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const Check := preload("res://tests/check.gd")

var _done := false
var _c := Check.new()


func _label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_label_texts(child, out)


# The per-card line bundles "name: verdict" into one label, so match on substring.
func _any_contains(texts: Array, needle: String) -> bool:
	for t in texts:
		if (t as String).find(needle) != -1:
			return true
	return false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# --- 1. Verdict is a rule over the card TYPE ------------------------------
	_c.eq("EPIC -> positive verdict", "REVIEW_VERDICT_EPIC", Review.verdict_key(MailCard.Type.EPIC))
	_c.eq("LEGENDARY folds into the EPIC verdict", "REVIEW_VERDICT_EPIC", Review.verdict_key(MailCard.Type.LEGENDARY))
	_c.eq("STANDARD -> warning", "REVIEW_VERDICT_STANDARD", Review.verdict_key(MailCard.Type.STANDARD))
	_c.eq("SCHROTT -> mistake", "REVIEW_VERDICT_SCHROTT", Review.verdict_key(MailCard.Type.SCHROTT))
	_c.eq("PAYLOAD -> neutral", "REVIEW_VERDICT_PAYLOAD", Review.verdict_key(MailCard.Type.PAYLOAD))

	# --- 2. Missed legendary = ingredients collected but never played --------
	var ingredients: Array = [&"q2b_neue_it", &"q3_stelle"]  # unlocks perfekter_absender
	_c.eq("missed when collected + not played", true,
		Review.missed_legendary_ids(ingredients, [], false).has(&"perfekter_absender"))
	_c.eq("NOT missed when the legendary was played", false,
		Review.missed_legendary_ids(ingredients, [&"perfekter_absender"], false).has(&"perfekter_absender"))
	_c.eq("NOT missed when ingredients were never collected", false,
		Review.missed_legendary_ids([], [], false).has(&"perfekter_absender"))

	# --- 3. Pool.card_for_id resolves ids across every catalog ----------------
	_c.ok("lookup finds a recon card", Pool.card_for_id(&"migrations_aufhaenger") != null)
	_c.ok("lookup finds a generic card", Pool.card_for_id(&"konto_gesperrt") != null)
	_c.ok("lookup finds the payload", Pool.card_for_id(&"zugang_bestaetigen") != null)
	_c.ok("lookup finds a legendary", Pool.card_for_id(&"perfekter_absender") != null)
	_c.ok("lookup returns null on an unknown id", Pool.card_for_id(&"nope") == null)

	# --- 4. Control builds one row per sent mail + the missed section ---------
	var history := [
		{"card_ids": [&"migrations_aufhaenger"], "suspicion_before": 4, "pressure_before": 3,
			"suspicion_after": 4, "pressure_after": 5},
		{"card_ids": [&"konto_gesperrt", &"frist_heute"], "suspicion_before": 4, "pressure_before": 5,
			"suspicion_after": 6, "pressure_after": 12},
	]
	var mr := {"outcome": "SPAM", "played": [], "history": history}
	var review = Review.new()
	root.add_child(review)
	review.configure(mr, ingredients, false)
	_c.eq("one row per sent mail", 2, review._turn_count)
	_c.eq("missed legendary detected in build", true, review._missed.has(&"perfekter_absender"))
	var texts: Array = []
	_label_texts(review, texts)
	_c.ok("row shows a played card's name", _any_contains(texts, tr("MAIL_MIGRATIONS_AUFHAENGER_NAME")))
	_c.ok("row shows the card's verdict", _any_contains(texts, tr("REVIEW_VERDICT_EPIC")))
	_c.ok("missed explanation rendered", texts.has(tr("REVIEW_MISSED_PERFEKTER_ABSENDER")))
	review.queue_free()

	# --- 5. Legendary played -> no missed line, positive note instead --------
	var review2 = Review.new()
	root.add_child(review2)
	review2.configure({"history": [], "played": [&"perfekter_absender"]}, ingredients, false)
	_c.eq("nothing missed when it was played", 0, review2._missed.size())
	var texts2: Array = []
	_label_texts(review2, texts2)
	_c.ok("shows the positive no-missed line", texts2.has(tr("REVIEW_NO_MISSED")))
	review2.queue_free()

	quit(_c.finish())
	return true
