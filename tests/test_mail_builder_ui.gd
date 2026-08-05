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
const Check := preload("res://tests/check.gd")
const RunState := preload("res://scenarios/spear_phishing/data/run_state.gd")

const OUTCOME_NAMES := ["NONE", "WIN", "SPAM", "KOLLEGEN_RUECKFRAGE", "IGNORIERT"]

var _done := false
var _run   # the RunState handed to the phase under test
var _c := Check.new()


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
	gs.begin_mission(budget)
	# The scenario shell hands the run over before the phase becomes visible;
	# here the scene is visible on add_child, so configure_run comes first.
	_run = RunState.new()
	_run.set_collected_finds(collected)
	_run.probe_done = probe_done
	var mb = load(SCENE).instantiate()
	mb.configure_run(_run)
	root.add_child(mb)  # visible by default -> _ready runs _build()
	return mb


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# --- 1. Draft -> send WIN, with recon consumption --------------------------
	# q2a_sonntags supplies the senker: suspicion starts one over target, so the
	# winning line is senken + druck in one mail, then the payload alone.
	var mb = _build_mb([&"q2a_sonntags", &"q4_presse", &"q2d_whiteboard", &"q2c_katze"], false, 5)
	_c.ok("hand built with widgets", mb._cards.size() > 0)
	_c.ok("payload widget present", _card_widget(mb, &"zugang_bestaetigen") != null)
	_c.eq("payload not enabled at start, gate closed", false, _card_widget(mb, &"zugang_bestaetigen")._enabled)
	_c.eq("payload not pulsing while gate closed", false, _card_widget(mb, &"zugang_bestaetigen")._is_pulsing())
	_c.eq("payload arrow hidden while gate closed", false, _card_widget(mb, &"zugang_bestaetigen")._arrow.visible)
	_c.ok("hand scroll wired for the payload spotlight", mb._hand_scroll != null)
	_c.ok("payload widget finder", mb._payload_widget() == _card_widget(mb, &"zugang_bestaetigen"))
	_c.eq("recon trap disguised as EPIC", "EPIC", _card_widget(mb, &"katzen_smalltalk")._type_tag_text())
	_c.eq("generic trap disguised as STANDARD", "STANDARD", _card_widget(mb, &"gratis_krypto")._type_tag_text())

	_draft(mb, &"sonntags_hannes")
	_draft(mb, &"migrations_aufhaenger")
	_draft(mb, &"projekt_helvetia")
	_c.eq("draft holds three cards", 3, mb._slots.size())
	_c.eq("drafting leaves engine bars untouched", 3, mb._run.pressure)
	_send(mb)

	_c.eq("one mail spent one turn", 4, mb._run.turns_left)
	_c.eq("bundled pressure applied 3+2+2", 7, mb._run.pressure)
	_c.eq("senker applied 4-2", 2, mb._run.suspicion)
	_c.eq("hannes replied in the thread", 1, mb._preview.replies)
	_c.ok("recon card consumed after send", _card_widget(mb, &"migrations_aufhaenger") == null)
	_c.ok("generic card still in hand", _card_widget(mb, &"konto_gesperrt") != null)
	_c.ok("uninvolved trap still in hand", _card_widget(mb, &"katzen_smalltalk") != null)
	_c.eq("draft cleared after send", 0, mb._slots.size())
	_c.eq("payload enabled once gate open", true, _card_widget(mb, &"zugang_bestaetigen")._enabled)
	_c.eq("payload pulses once gate open", true, _card_widget(mb, &"zugang_bestaetigen")._is_pulsing())
	_c.eq("payload arrow shown once gate open", true, _card_widget(mb, &"zugang_bestaetigen")._arrow.visible)
	_c.eq("generic locked once gate open", false, _card_widget(mb, &"konto_gesperrt")._enabled)
	_c.eq("trap locked once gate open", false, _card_widget(mb, &"katzen_smalltalk")._enabled)

	_draft(mb, &"zugang_bestaetigen")
	_c.eq("pulse stops while payload drafted", false, _card_widget(mb, &"zugang_bestaetigen")._is_pulsing())
	_c.eq("arrow hidden while payload drafted", false, _card_widget(mb, &"zugang_bestaetigen")._arrow.visible)
	_draft(mb, &"zugang_bestaetigen")  # toggle back out of the draft
	_c.eq("pulse resumes after undraft", true, _card_widget(mb, &"zugang_bestaetigen")._is_pulsing())
	_draft(mb, &"zugang_bestaetigen")
	_send(mb)
	_c.eq("payload mail wins", "WIN", OUTCOME_NAMES[mb._run.outcome])
	var result := (_run.mail_result as Dictionary)
	_c.eq("mail_result handed to the run", "WIN", result.get("outcome", ""))
	_c.eq("mail_result carries per-mail history", 2, (result.get("history", []) as Array).size())
	_c.eq("final reply appended before advance", 2, mb._preview.replies)
	mb.queue_free()

	# --- 2. Generics are inexhaustible; pass runs the budget down --------------
	var mb2 = _build_mb([], false, 5)
	_draft(mb2, &"konto_gesperrt")
	_draft(mb2, &"frist_heute")
	_send(mb2)
	_c.eq("two-card mail cost one turn", 4, mb2._run.turns_left)
	_c.ok("generic reusable next turn", _card_widget(mb2, &"konto_gesperrt") != null)
	_c.ok("second generic reusable too", _card_widget(mb2, &"frist_heute") != null)
	mb2._on_pass()
	_c.eq("pass spent a turn, GameState in sync", 3,
		root.get_node("GameState").mission_turns_left)
	mb2.queue_free()

	# --- 3. Probe flip swaps the unlocked card into the hand ------------------
	var mb3 = _build_mb([], false, 5)
	_c.ok("q8 card absent before probe", _card_widget(mb3, &"abwesenheits_fenster") == null)
	_draft(mb3, &"probe_ooo")
	_send(mb3)
	_c.eq("probe flag set on the run", true, _run.probe_done)
	_c.ok("q8 card swapped into the hand", _card_widget(mb3, &"abwesenheits_fenster") != null)
	_c.ok("probe card consumed after it ran", _card_widget(mb3, &"probe_ooo") == null)
	mb3.queue_free()

	# --- 4. Pulse stops when a sent mail ends the run without the payload ------
	var mb4 = _build_mb([], false, 2)
	_draft(mb4, &"konto_gesperrt")
	_draft(mb4, &"frist_heute")
	_send(mb4)
	_c.eq("gate open, payload pulsing before the final send", true, _card_widget(mb4, &"zugang_bestaetigen")._is_pulsing())
	# Deliberately bypasses the UI lock (direct _toggle_slot, engine stays
	# tolerant): the point is _finish_reveal's defensive is_over refresh.
	_draft(mb4, &"gratis_krypto")
	_send(mb4)
	_c.eq("run over via send", "SPAM", OUTCOME_NAMES[mb4._run.outcome])
	_c.eq("payload disabled after run-over send", false, _card_widget(mb4, &"zugang_bestaetigen")._enabled)
	_c.eq("pulse stopped after run-over send", false, _card_widget(mb4, &"zugang_bestaetigen")._is_pulsing())
	_c.eq("arrow hidden after run-over send", false, _card_widget(mb4, &"zugang_bestaetigen")._arrow.visible)
	mb4.queue_free()

	# --- 5. Passing discards the draft (no ghost slots, no false pulse) --------
	var mb5 = _build_mb([], false, 5)
	_draft(mb5, &"konto_gesperrt")
	_draft(mb5, &"frist_heute")
	_send(mb5)  # gate opens
	_draft(mb5, &"zugang_bestaetigen")
	mb5._on_pass()
	_c.eq("pass clears the draft", 0, mb5._slots.size())
	_c.eq("rebuilt payload pulses again after pass", true, _card_widget(mb5, &"zugang_bestaetigen")._is_pulsing())
	mb5.queue_free()

	quit(_c.finish())
	return true
