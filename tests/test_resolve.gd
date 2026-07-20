# Headless smoke test for the RESOLVE debrief: instantiate the real scene per
# outcome and assert the view reads GameState.mail_result correctly — the right
# outcome feedback, the twist and statistic ALWAYS present (even on WIN), the
# scenario_debrief telemetry firing once with the run's metrics, and the replay
# reset actually wiping the per-run handoff state.
#
# The staged reveal is time-based; the test drives the synchronous reveal_all()
# seam instead of the tween.
#
# Run:
#   godot --headless --path . -s tests/test_resolve.gd
extends SceneTree

const SCENE := "res://scenarios/spear_phishing/states/resolve.tscn"

var _events: Array = []
var _done := false


func _initialize() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _debriefs() -> Array:
	var out: Array = []
	for e in _events:
		if e.get("phase", "") == "scenario_debrief":
			out.append(e)
	return out


# Recursively collect every Label's text under a node, so assertions do not
# depend on the exact child layout.
func _label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_label_texts(child, out)


# Same, for Button labels (the three exit buttons).
func _button_texts(node: Node, out: Array) -> void:
	if node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_button_texts(child, out)


func _build_resolve(outcome: String):
	var gs := root.get_node("GameState")
	gs.set_mail_result({
		"outcome": outcome,
		"suspicion": 2,
		"pressure": 8,
		"turns_used": 3,
		"played": [],
	})
	var r = load(SCENE).instantiate()
	root.add_child(r)  # visible by default -> _ready runs _build()
	return r


func _has(texts: Array, key: String) -> bool:
	return texts.has(tr(key))


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# --- 1. Outcome-specific feedback maps from mail_result.outcome -----------
	var cases := {
		"WIN": "RESOLVE_WIN_TITLE",
		"SPAM": "RESOLVE_SPAM_TITLE",
		"KOLLEGEN_RUECKFRAGE": "RESOLVE_KOLLEGEN_TITLE",
		"IGNORIERT": "RESOLVE_IGNORIERT_TITLE",
	}
	for outcome in cases:
		var r = _build_resolve(outcome)
		var texts: Array = []
		_label_texts(r, texts)
		print("%s shows its title (expect true): " % outcome, _has(texts, cases[outcome]))
		# Twist + statistic + source appear for EVERY outcome, WIN included.
		print("%s shows the twist (expect true): " % outcome, _has(texts, "RESOLVE_TWIST"))
		print("%s shows the statistic (expect true): " % outcome, _has(texts, "RESOLVE_STAT"))
		print("%s shows the source line (expect true): " % outcome, _has(texts, "RESOLVE_STAT_SOURCE"))
		r.queue_free()

	# --- 2. Unknown/empty result fails safe to the IGNORIERT feedback ---------
	var ru = _build_resolve("")
	var utexts: Array = []
	_label_texts(ru, utexts)
	print("empty result falls back to IGNORIERT title (expect true): ",
		_has(utexts, "RESOLVE_IGNORIERT_TITLE"))
	print("empty result still shows twist + stat (expect true): ",
		_has(utexts, "RESOLVE_TWIST") and _has(utexts, "RESOLVE_STAT"))
	ru.queue_free()

	# --- 3. scenario_debrief telemetry: once per build, carrying the metrics --
	var debriefs := _debriefs()
	print("one debrief event per build so far (expect 5): ", debriefs.size())
	var win_debrief: Dictionary = debriefs[0]
	print("debrief action carries the outcome (expect WIN): ", win_debrief.get("action", ""))
	print("debrief flags WIN as correct (expect true): ", win_debrief.get("is_correct"))
	var wp: Dictionary = win_debrief["payload"]
	print("debrief payload has outcome (expect WIN): ", wp.get("outcome", ""))
	print("debrief payload has turns_used (expect 3): ", wp.get("turns_used"))
	print("debrief payload has final bars (expect 2/8): ",
		"%s/%s" % [wp.get("suspicion"), wp.get("pressure")])
	var empty_debrief: Dictionary = debriefs[4]
	print("empty-result debrief logs UNKNOWN (expect UNKNOWN): ", empty_debrief.get("action", ""))

	# --- 4. reveal_all() shows the buttons synchronously ----------------------
	var rb = _build_resolve("WIN")
	print("buttons hidden before reveal (expect 0.0): ", rb._button_row.modulate.a)
	rb.reveal_all()
	print("reveal_all shows the buttons (expect 1.0): ", rb._button_row.modulate.a)
	print("reveal_all is marked revealed (expect true): ", rb._revealed)

	# The three exit buttons and their intent signals are present.
	var btns: Array = []
	_button_texts(rb, btns)
	print("three exit buttons present (expect 3): ", btns.size())
	print("next-scenario button labelled (expect true): ", btns.has(tr("RESOLVE_NEXT")))
	print("home button labelled (expect true): ", btns.has(tr("RESOLVE_HOME")))
	print("retry button labelled (expect true): ", btns.has(tr("RESOLVE_RETRY")))
	print("next_requested signal present (expect true): ", rb.has_signal("next_requested"))
	print("home_requested signal present (expect true): ", rb.has_signal("home_requested"))
	print("replay_requested signal present (expect true): ", rb.has_signal("replay_requested"))
	rb.queue_free()

	# --- 5. reset_scenario() wipes the per-run handoff (clean replay) ---------
	var gs := root.get_node("GameState")
	var finds: Array[StringName] = [&"q4_presse", &"q2c_katze"]
	gs.set_collected_finds(finds)
	gs.set_mail_result({"outcome": "WIN", "suspicion": 2, "pressure": 8, "turns_used": 3, "played": []})
	gs.probe_signature_obtained = true
	gs.reset_scenario()
	print("reset clears collected finds (expect 0): ", gs.collected_find_ids.size())
	print("reset clears mail_result (expect 0): ", gs.mail_result.size())
	print("reset clears probe flag (expect false): ", gs.probe_signature_obtained)

	print("TEST DONE")
	return true
