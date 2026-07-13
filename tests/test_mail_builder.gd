# Headless unit tests for the MailBuilder core: bar application, the four
# outcomes, the payload gate, legendary unlocking, the "Keiner fragt nach"
# amplifier, trap cards landing in the hand, and telemetry emission. Plain
# SceneTree script, no framework (like tests/test_recon.gd).
#
# Run:
#   godot --headless --path . -s tests/test_mail_builder.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const MailRun := preload("res://scenarios/spear_phishing/data/mail_builder_state.gd")

var _events: Array = []
var _done := false


func _initialize() -> void:
	# Capture telemetry. The EventBus autoload is reached by node path, not the
	# global identifier (a bare `-s` script cannot compile the global).
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _card(id: StringName, type: int, sus: int, pre: int, amp := false) -> MailCard:
	return MailCard.new(id, type, sus, pre, &"test", amp)


func _pay() -> MailCard:
	return _card(&"payload", MailCard.Type.PAYLOAD, 0, 0)


func _outcome_name(o: int) -> String:
	return MailRun.Outcome.keys()[o]


func _events_of(phase: String) -> Array:
	var out: Array = []
	for e in _events:
		if e.get("phase", "") == phase:
			out.append(e)
	return out


func _has_card(hand: Array, id: StringName) -> bool:
	return Pool.find_in_hand(hand, id) != null


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# 1. Bar application from the start values (3 / 5), with the floor.
	var run := MailRun.new(8)
	print("start suspicion (expect 3): ", run.suspicion)
	print("start pressure (expect 5): ", run.pressure)
	run.play_card(_card(&"c", MailCard.Type.EPIC, -2, 2))
	print("suspicion after -2 (expect 1): ", run.suspicion)
	print("pressure after +2 (expect 7): ", run.pressure)
	run.play_card(_card(&"floor", MailCard.Type.EPIC, -5, 0))
	print("suspicion floored at 0 (expect 0): ", run.suspicion)

	# 2. WIN: reach pressure >= 7 with suspicion <= 3, then payload.
	var win := MailRun.new(8)
	win.play_card(_card(&"p", MailCard.Type.EPIC, 0, 2))  # pressure 7, suspicion 3
	var win_out := win.play_card(_card(&"pay", MailCard.Type.PAYLOAD, 0, 0))
	print("payload with 7/3 wins (expect WIN): ", MailRun.Outcome.keys()[win_out])

	# 3. SPAM: suspicion pushed above 7 ends the run immediately.
	var spam := MailRun.new(8)
	spam.play_card(_card(&"s1", MailCard.Type.SCHROTT, 3, 0))  # suspicion 6
	var spam_out := spam.play_card(_card(&"s2", MailCard.Type.SCHROTT, 3, 0))  # 9 -> spam
	print("suspicion 9 triggers spam (expect SPAM): ", MailRun.Outcome.keys()[spam_out])

	# 4. KOLLEGEN_RUECKFRAGE: pressure reached but suspicion in 4..7 at payload.
	var koll := MailRun.new(8)
	koll.play_card(_card(&"k", MailCard.Type.STANDARD, 1, 4))  # pressure 9, suspicion 4
	var koll_out := koll.play_card(_card(&"pay", MailCard.Type.PAYLOAD, 0, 0))
	print("payload with 9/4 -> kollegen (expect KOLLEGEN_RUECKFRAGE): ", MailRun.Outcome.keys()[koll_out])

	# 5. IGNORIERT: budget spent without a winning payload.
	var ign := MailRun.new(2)
	ign.play_card(_card(&"a", MailCard.Type.EPIC, 0, 0))
	var ign_out := ign.play_card(_card(&"b", MailCard.Type.EPIC, 0, 0))
	print("budget exhausted (expect IGNORIERT): ", MailRun.Outcome.keys()[ign_out])

	# 6. Payload gate: too-early payload (pressure < 7) is not a win.
	var early := MailRun.new(8)
	var early_out := early.play_card(_card(&"pay", MailCard.Type.PAYLOAD, 0, 0))  # 5/3
	print("early payload not a win (expect KOLLEGEN_RUECKFRAGE): ", MailRun.Outcome.keys()[early_out])

	# 7. "Keiner fragt nach" amplifier: +1 on later pressure cards only.
	var amp := MailRun.new(8)
	amp.play_card(_card(&"kfn", MailCard.Type.EPIC, -1, 0, true))  # suspicion 2, amp on
	amp.play_card(_card(&"press", MailCard.Type.STANDARD, 1, 3))   # pressure 5+(3+1)=9
	print("amplified pressure card (expect 9): ", amp.pressure)
	print("non-pressure card unaffected by amp: suspicion (expect 3): ", amp.suspicion)

	# 8. Legendary unlocking (rule over collected find ids).
	print("perfekter_absender unlocked by q2b+q3 (expect true): ",
		Pool.unlocked_legendary_ids([&"q2b_neue_it", &"q3_stelle"], false).has(&"perfekter_absender"))
	print("identitaet_gesichert via archiv, no probe (expect true): ",
		Pool.unlocked_legendary_ids([&"q5_schema", &"q10_archiv"], false).has(&"identitaet_gesichert"))
	print("identitaet_gesichert with only schema (expect false): ",
		Pool.unlocked_legendary_ids([&"q5_schema"], false).has(&"identitaet_gesichert"))
	print("identitaet_gesichert via schema+probe (expect true): ",
		Pool.unlocked_legendary_ids([&"q5_schema"], true).has(&"identitaet_gesichert"))

	# 9. Hand: recon cards (incl. traps) + generics + payload; no draw.
	var hand := Pool.build_hand([&"q2a_sonntags", &"q2c_katze", &"q7_jodler"], false)
	print("collected epic on hand (expect true): ", _has_card(hand, &"sonntags_hannes"))
	print("trap katze on hand, not filtered (expect true): ", _has_card(hand, &"katzen_smalltalk"))
	print("trap namensvetter on hand (expect true): ", _has_card(hand, &"namensvetter_jodler"))
	print("generic konto_gesperrt always on hand (expect true): ", _has_card(hand, &"konto_gesperrt"))
	print("payload always on hand (expect true): ", _has_card(hand, &"zugang_bestaetigen"))
	print("uncollected epic NOT on hand (expect false): ", _has_card(hand, &"frische_it"))
	print("q8 card absent without probe (expect false): ", _has_card(hand, &"abwesenheits_fenster"))
	print("q8 card present with probe (expect true): ",
		_has_card(Pool.build_hand([], true), &"abwesenheits_fenster"))

	# 10. Telemetry actually emitted through EventBus.
	print("mail_card_played events emitted (expect > 0): ", _events_of("mail_card_played").size() > 0)
	print("mail_payload_attempt events emitted (expect > 0): ", _events_of("mail_payload_attempt").size() > 0)
	var outcomes := _events_of("mail_outcome")
	print("mail_outcome events emitted (expect > 0): ", outcomes.size() > 0)
	var has_win_outcome := false
	for e in outcomes:
		if e.get("action", "") == "WIN":
			has_win_outcome = true
	print("a WIN outcome was logged (expect true): ", has_win_outcome)
	# Card-played payload carries the before/after and principle for the thesis.
	var sample: Dictionary = _events_of("mail_card_played")[0]
	print("card event has principle (expect true): ", sample["payload"].has("principle"))
	print("card event has suspicion_before/after (expect true): ",
		sample["payload"].has("suspicion_before") and sample["payload"].has("suspicion_after"))

	# ---- Threshold boundaries (off-by-one gives the wrong teaching moment) ----

	# 11. SPAM threshold: suspicion exactly 7 is NOT spam; 8 is. (SPAM at > 7.)
	var s7 := MailRun.new(8)
	s7.play_card(_card(&"a", MailCard.Type.STANDARD, 4, 0))  # 3 -> 7
	print("suspicion exactly 7 is not spam (expect NONE): ", _outcome_name(s7.outcome))
	print("suspicion sits at 7 (expect 7): ", s7.suspicion)
	var s8_out := s7.play_card(_card(&"b", MailCard.Type.STANDARD, 1, 0))  # 7 -> 8
	print("suspicion 8 triggers spam (expect SPAM): ", _outcome_name(s8_out))

	# 12. Payload suspicion boundary at 3 vs 4 (pressure fixed at target 7).
	# WIN requires suspicion <= 3; 4 falls into kollegen.
	var ps3 := MailRun.new(8)
	ps3.play_card(_card(&"a", MailCard.Type.EPIC, 0, 2))  # pressure 7, suspicion 3
	print("payload at suspicion 3 wins (expect WIN): ", _outcome_name(ps3.play_card(_pay())))
	var ps4 := MailRun.new(8)
	ps4.play_card(_card(&"a", MailCard.Type.EPIC, 0, 2))   # pressure 7
	ps4.play_card(_card(&"b", MailCard.Type.EPIC, 1, 0))   # suspicion 4
	print("payload at suspicion 4 loses (expect KOLLEGEN_RUECKFRAGE): ", _outcome_name(ps4.play_card(_pay())))

	# 13. Payload suspicion upper edge at 7 (still not spam, pressure ok) -> kollegen.
	var ps7 := MailRun.new(8)
	ps7.play_card(_card(&"a", MailCard.Type.EPIC, 0, 2))   # pressure 7, suspicion 3
	ps7.play_card(_card(&"b", MailCard.Type.STANDARD, 4, 0))  # suspicion 7, not spam
	print("suspicion 7 pre-payload is not spam (expect NONE): ", _outcome_name(ps7.outcome))
	print("payload at suspicion 7 -> kollegen (expect KOLLEGEN_RUECKFRAGE): ", _outcome_name(ps7.play_card(_pay())))

	# 14. Payload pressure boundary at 7 vs 6 (suspicion fixed <= 3).
	# WIN requires pressure >= 7; 6 falls into kollegen.
	var pp7 := MailRun.new(8)
	pp7.play_card(_card(&"a", MailCard.Type.EPIC, 0, 2))  # pressure 7, suspicion 3
	print("payload at pressure 7 wins (expect WIN): ", _outcome_name(pp7.play_card(_pay())))
	var pp6 := MailRun.new(8)
	pp6.play_card(_card(&"a", MailCard.Type.EPIC, 0, 1))  # pressure 6, suspicion 3
	print("payload at pressure 6 loses (expect KOLLEGEN_RUECKFRAGE): ", _outcome_name(pp6.play_card(_pay())))

	# 15. IGNORIERT boundary: the payload spends the last turn and still RESOLVES;
	# it is never mistaken for budget exhaustion.
	var ig1 := MailRun.new(1)
	print("single non-payload turn exhausts (expect IGNORIERT): ",
		_outcome_name(ig1.play_card(_card(&"x", MailCard.Type.EPIC, 0, 0))))
	var lp := MailRun.new(1)
	print("payload on the only turn resolves, not ignoriert (expect KOLLEGEN_RUECKFRAGE): ",
		_outcome_name(lp.play_card(_pay())))
	var lw := MailRun.new(2)
	lw.play_card(_card(&"a", MailCard.Type.EPIC, 0, 2))  # pressure 7, turns_left 1
	print("win on the last turn, not ignoriert (expect WIN): ", _outcome_name(lw.play_card(_pay())))

	print("TEST DONE")
	return true
