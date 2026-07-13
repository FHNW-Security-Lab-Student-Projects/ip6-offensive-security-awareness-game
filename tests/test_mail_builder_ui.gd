# Headless smoke test for the MailBuilder UI in its mail-as-a-turn form:
# instantiate the real scene, DRAFT cards into slots, send the bundled mail and
# assert the view stays in lockstep with the engine (draft preview, one turn per
# mail, recon consumption, inexhaustible generics, probe swap, outcome handoff).
# The staggered reveal is cosmetic and time-based, so the test drives the
# synchronous commit/finish seam instead of the tween.
#
# Run:
#   godot --headless --path . -s tests/test_mail_builder_ui.gd
extends SceneTree

const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const SCENE := "res://scenarios/spear_phishing/states/mail_builder.tscn"

var _done := false


func _card_widget(mb, id: StringName):
	for widget in mb._cards:
		if widget.card.id == id:
			return widget
	return null


func _draft(mb, id: StringName) -> void:
	var widget = _card_widget(mb, id)
	mb._toggle_slot(widget.card, widget)


func _send(mb) -> void:
	var cards: Array = mb._slots.duplicate()
	mb._commit_mail(cards)
	mb._finish_reveal(cards)  # skip the cosmetic tween, run the post-send logic


func _build_mb(collected: Array[StringName], probe_done: bool, budget: int):
	var gs := root.get_node("GameState")
	gs.set_collected_finds(collected)
	gs.probe_signature_obtained = probe_done
	gs.mail_result = {}
	gs.begin_mission(budget)
	var mb = load(SCENE).instantiate()
	root.add_child(mb)  # visible by default -> _ready runs _build()
	return mb


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# --- 1. Draft -> send WIN, with recon consumption --------------------------
	var mb = _build_mb([&"q4_presse", &"q2d_whiteboard", &"q2c_katze"], false, 5)
	print("hand built with widgets (expect true): ", mb._cards.size() > 0)
	print("payload widget present (expect true): ", _card_widget(mb, &"zugang_bestaetigen") != null)
	print("payload not enabled at start, gate closed (expect false): ", _card_widget(mb, &"zugang_bestaetigen")._enabled)
	print("recon trap disguised as EPIC (expect EPIC): ", _card_widget(mb, &"katzen_smalltalk")._type_tag_text())
	print("generic trap disguised as STANDARD (expect STANDARD): ", _card_widget(mb, &"gratis_krypto")._type_tag_text())

	_draft(mb, &"migrations_aufhaenger")
	_draft(mb, &"projekt_helvetia")
	print("draft holds two cards (expect 2): ", mb._slots.size())
	print("draft preview shows two fragments (expect 2): ", mb._preview._body.get_child_count())
	_send(mb)

	print("one mail spent one turn (expect 4 left): ", mb._run.turns_left)
	print("bundled pressure applied 5+2+2 (expect 9): ", mb._run.pressure)
	print("recon card consumed after send (expect true): ", _card_widget(mb, &"migrations_aufhaenger") == null)
	print("generic card still in hand (expect true): ", _card_widget(mb, &"konto_gesperrt") != null)
	print("uninvolved trap still in hand (expect true): ", _card_widget(mb, &"katzen_smalltalk") != null)
	print("draft cleared after send (expect 0): ", mb._slots.size())
	print("payload enabled once gate open (expect true): ", _card_widget(mb, &"zugang_bestaetigen")._enabled)

	_draft(mb, &"zugang_bestaetigen")
	_send(mb)
	print("payload mail wins (expect WIN): ", ["NONE","WIN","SPAM","KOLLEGEN_RUECKFRAGE","IGNORIERT"][mb._run.outcome])
	var result := (root.get_node("GameState").mail_result as Dictionary)
	print("mail_result handed to GameState (expect WIN): ", result.get("outcome", ""))
	mb.queue_free()

	# --- 2. Generics are inexhaustible; pass runs the budget down --------------
	var mb2 = _build_mb([], false, 5)
	_draft(mb2, &"konto_gesperrt")
	_draft(mb2, &"frist_heute")
	_send(mb2)
	print("two-card mail cost one turn (expect 4 left): ", mb2._run.turns_left)
	print("generic reusable next turn (expect true): ", _card_widget(mb2, &"konto_gesperrt") != null)
	print("second generic reusable too (expect true): ", _card_widget(mb2, &"frist_heute") != null)
	mb2._on_pass()
	print("pass spent a turn, GameState in sync (expect true): ",
		root.get_node("GameState").mission_turns_left == 3)
	mb2.queue_free()

	# --- 3. Probe flip swaps the unlocked card into the hand ------------------
	var mb3 = _build_mb([], false, 5)
	print("q8 card absent before probe (expect true): ", _card_widget(mb3, &"abwesenheits_fenster") == null)
	_draft(mb3, &"probe_ooo")
	_send(mb3)
	print("probe flag set on GameState (expect true): ", root.get_node("GameState").probe_signature_obtained)
	print("q8 card swapped into the hand (expect true): ", _card_widget(mb3, &"abwesenheits_fenster") != null)
	print("probe card consumed after it ran (expect true): ", _card_widget(mb3, &"probe_ooo") == null)
	mb3.queue_free()

	print("TEST DONE")
	return true
