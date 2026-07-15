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

	# 1. Bar application from the start values (4 / 3), with the floor.
	var run := MailRun.new(8)
	print("start suspicion (expect 4): ", run.suspicion)
	print("start pressure (expect 3): ", run.pressure)
	run.play_card(_card(&"c", MailCard.Type.EPIC, -2, 2))
	print("suspicion after -2 (expect 2): ", run.suspicion)
	print("pressure after +2 (expect 5): ", run.pressure)
	run.play_card(_card(&"floor", MailCard.Type.EPIC, -5, 0))
	print("suspicion floored at 0 (expect 0): ", run.suspicion)

	# 2. WIN: reach pressure >= 7 with suspicion <= 3, then payload.
	var win := MailRun.new(8)
	win.play_card(_card(&"p", MailCard.Type.EPIC, -1, 4))  # pressure 7, suspicion 3
	var win_out := win.play_card(_card(&"pay", MailCard.Type.PAYLOAD, 0, 0))
	print("payload with 7/3 wins (expect WIN): ", MailRun.Outcome.keys()[win_out])

	# 3. SPAM: suspicion pushed above 7 ends the run immediately.
	var spam := MailRun.new(8)
	spam.play_card(_card(&"s1", MailCard.Type.SCHROTT, 3, 0))  # suspicion 7
	var spam_out := spam.play_card(_card(&"s2", MailCard.Type.SCHROTT, 3, 0))  # 10 -> spam
	print("suspicion 10 triggers spam (expect SPAM): ", MailRun.Outcome.keys()[spam_out])

	# 4. KOLLEGEN_RUECKFRAGE: pressure reached but suspicion in 4..7 at payload.
	var koll := MailRun.new(8)
	koll.play_card(_card(&"k", MailCard.Type.STANDARD, 1, 4))  # pressure 7, suspicion 5
	var koll_out := koll.play_card(_card(&"pay", MailCard.Type.PAYLOAD, 0, 0))
	print("payload with 7/5 -> kollegen (expect KOLLEGEN_RUECKFRAGE): ", MailRun.Outcome.keys()[koll_out])

	# 5. IGNORIERT: budget spent without a winning payload.
	var ign := MailRun.new(2)
	ign.play_card(_card(&"a", MailCard.Type.EPIC, 0, 0))
	var ign_out := ign.play_card(_card(&"b", MailCard.Type.EPIC, 0, 0))
	print("budget exhausted (expect IGNORIERT): ", MailRun.Outcome.keys()[ign_out])

	# 6. Payload gate: below the pressure target the payload is not playable. It
	# is rejected (no turn spent, run continues) — NOT resolved as a loss. The
	# gate is pressure-only; suspicion decides win vs kollegen once it is open.
	var early := MailRun.new(8)
	print("gate closed at start pressure 3 (expect false): ", early.payload_gate_open())
	print("non-payload playable while gate closed (expect true): ",
		early.card_playable(_card(&"x", MailCard.Type.EPIC, 0, 0)))
	print("payload not playable while gate closed (expect false): ", early.card_playable(_pay()))
	var early_out := early.play_card(_pay())  # pressure 3 < 7
	print("early payload rejected, run continues (expect NONE): ", _outcome_name(early_out))
	print("rejected payload spent no turn (expect 8): ", early.turns_left)
	early.play_card(_card(&"a", MailCard.Type.EPIC, 0, 4))  # pressure 7
	print("gate open once pressure hits 7 (expect true): ", early.payload_gate_open())
	print("open gate locks non-payload cards (expect false): ",
		early.card_playable(_card(&"x", MailCard.Type.EPIC, 0, 0)))
	print("open gate leaves the payload playable (expect true): ", early.card_playable(_pay()))

	# 7. "Keiner fragt nach" amplifier: +1 on later pressure cards only.
	var amp := MailRun.new(8)
	amp.play_card(_card(&"kfn", MailCard.Type.EPIC, -1, 0, true))  # suspicion 3, amp on
	amp.play_card(_card(&"press", MailCard.Type.STANDARD, 1, 3))   # pressure 3+(3+1)=7
	print("amplified pressure card (expect 7): ", amp.pressure)
	print("non-pressure card unaffected by amp: suspicion (expect 4): ", amp.suspicion)

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
	s7.play_card(_card(&"a", MailCard.Type.STANDARD, 3, 0))  # 4 -> 7
	print("suspicion exactly 7 is not spam (expect NONE): ", _outcome_name(s7.outcome))
	print("suspicion sits at 7 (expect 7): ", s7.suspicion)
	var s8_out := s7.play_card(_card(&"b", MailCard.Type.STANDARD, 1, 0))  # 7 -> 8
	print("suspicion 8 triggers spam (expect SPAM): ", _outcome_name(s8_out))

	# 12. Payload suspicion boundary at 3 vs 4 (pressure fixed at target 7).
	# WIN requires suspicion <= 3; 4 falls into kollegen.
	var ps3 := MailRun.new(8)
	ps3.play_card(_card(&"a", MailCard.Type.EPIC, -1, 4))  # pressure 7, suspicion 3
	print("payload at suspicion 3 wins (expect WIN): ", _outcome_name(ps3.play_card(_pay())))
	var ps4 := MailRun.new(8)
	ps4.play_card(_card(&"a", MailCard.Type.EPIC, -1, 4))   # pressure 7, suspicion 3
	ps4.play_card(_card(&"b", MailCard.Type.EPIC, 1, 0))   # suspicion 4
	print("payload at suspicion 4 loses (expect KOLLEGEN_RUECKFRAGE): ", _outcome_name(ps4.play_card(_pay())))

	# 13. Payload suspicion upper edge at 7 (still not spam, pressure ok) -> kollegen.
	var ps7 := MailRun.new(8)
	ps7.play_card(_card(&"a", MailCard.Type.EPIC, -1, 4))   # pressure 7, suspicion 3
	ps7.play_card(_card(&"b", MailCard.Type.STANDARD, 4, 0))  # suspicion 7, not spam
	print("suspicion 7 pre-payload is not spam (expect NONE): ", _outcome_name(ps7.outcome))
	print("payload at suspicion 7 -> kollegen (expect KOLLEGEN_RUECKFRAGE): ", _outcome_name(ps7.play_card(_pay())))

	# 14. Payload pressure boundary at 7 vs 6 (suspicion fixed <= 3).
	# WIN requires pressure >= 7; 6 falls into kollegen.
	var pp7 := MailRun.new(8)
	pp7.play_card(_card(&"a", MailCard.Type.EPIC, -1, 4))  # pressure 7, suspicion 3
	print("payload at pressure 7 wins (expect WIN): ", _outcome_name(pp7.play_card(_pay())))
	# One below target the gate is closed, so pressure 6 rejects the payload
	# (no turn spent) rather than resolving it as a loss.
	var pp6 := MailRun.new(8)
	pp6.play_card(_card(&"a", MailCard.Type.EPIC, -1, 3))  # pressure 6, suspicion 3
	print("payload at pressure 6 rejected, not playable (expect NONE): ", _outcome_name(pp6.play_card(_pay())))
	print("pressure-6 payload spent no turn (expect 7): ", pp6.turns_left)

	# 15. IGNORIERT boundary: a payload played on the last OPEN-gate turn still
	# RESOLVES; a gate-closed payload is rejected and never ends the run.
	var ig1 := MailRun.new(1)
	print("single non-payload turn exhausts (expect IGNORIERT): ",
		_outcome_name(ig1.play_card(_card(&"x", MailCard.Type.EPIC, 0, 0))))
	var lp := MailRun.new(1)
	print("gate-closed payload rejected (expect NONE): ", _outcome_name(lp.play_card(_pay())))
	print("rejected payload left the turn (expect 1 left): ", lp.turns_left)
	var lw := MailRun.new(2)
	lw.play_card(_card(&"a", MailCard.Type.EPIC, -1, 4))  # pressure 7, suspicion 3, turns_left 1
	print("win on the last turn, not ignoriert (expect WIN): ", _outcome_name(lw.play_card(_pay())))

	# 16. pass_turn: spends a turn, logs telemetry, runs the budget down to
	# IGNORIERT instead of forcing a suspicion card (and SPAM).
	var pt := MailRun.new(2)
	pt.pass_turn()
	print("pass spent a turn (expect 1 left): ", pt.turns_left)
	print("run still open after one pass (expect NONE): ", _outcome_name(pt.outcome))
	print("passing out the budget (expect IGNORIERT): ", _outcome_name(pt.pass_turn()))
	print("mail_pass telemetry emitted (expect > 0): ", _events_of("mail_pass").size() > 0)

	# 17. Probe mechanic (engine, not UI): the probe card is in hand before it
	# runs; playing it flips probe_done and swaps the Abwesenheits-Fenster card
	# into the hand while removing the probe.
	print("probe card in hand before probe (expect true): ",
		_has_card(Pool.build_hand([], false), &"probe_ooo"))
	print("q8 card absent before probe (expect false): ",
		_has_card(Pool.build_hand([], false), &"abwesenheits_fenster"))
	var probe_card := Pool.find_in_hand(Pool.build_hand([], false), &"probe_ooo")
	var pr := MailRun.new(8)
	print("probe flag starts false (expect false): ", pr.probe_done)
	pr.play_card(probe_card)
	print("probe card flips the flag (expect true): ", pr.probe_done)
	print("probe spent a turn (expect 7 left): ", pr.turns_left)
	var after_probe := Pool.build_hand([], pr.probe_done)
	print("q8 card in hand after probe (expect true): ", _has_card(after_probe, &"abwesenheits_fenster"))
	print("probe card gone after it ran (expect false): ", _has_card(after_probe, &"probe_ooo"))

	# ---- play_mail: bundled effects, one turn per mail, end-state resolution ----

	# 18. Multiple cards bundle into ONE turn; effects sum.
	var m := MailRun.new(5)
	m.play_mail([_card(&"a", MailCard.Type.EPIC, 0, 2), _card(&"b", MailCard.Type.EPIC, 0, 2)])
	print("two-card mail costs one turn (expect 4): ", m.turns_left)
	print("two-card mail sums pressure 3+2+2 (expect 7): ", m.pressure)
	print("reveal trace has one step per card (expect 2): ", m.last_mail_steps.size())

	# 19. The amplifier boosts a later card within the same mail (slot order).
	var ma := MailRun.new(5)
	ma.play_mail([_card(&"kfn", MailCard.Type.EPIC, 0, 0, true), _card(&"p", MailCard.Type.STANDARD, 0, 3)])
	print("amplified pressure inside one mail 3+(3+1) (expect 7): ", ma.pressure)

	# 20. Outcome resolves on the END state: a senker after a raiser dodges spam.
	var ms := MailRun.new(5)
	var ms_out := ms.play_mail([_card(&"up", MailCard.Type.STANDARD, 5, 0), _card(&"dn", MailCard.Type.EPIC, -3, 0)])
	print("mid-mail spike does not spam if end is safe (expect NONE): ", _outcome_name(ms_out))
	print("end suspicion is the summed value 4+5-3 (expect 6): ", ms.suspicion)

	# 21. Payload bundled with a senker: clean up and fire in one mail.
	var mp := MailRun.new(5)
	mp.play_mail([_card(&"pr", MailCard.Type.EPIC, 0, 4)])   # pressure 7, gate opens
	mp.play_mail([_card(&"dirty", MailCard.Type.EPIC, 3, 0)])  # suspicion 7
	var mp_out := mp.play_mail([_card(&"clean", MailCard.Type.EPIC, -4, 0), _pay()])  # -> 3, then win
	print("payload bundled with a senker wins (expect WIN): ", _outcome_name(mp_out))

	# 22. One turn per mail regardless of card count (budget of 5 mails).
	var mt := MailRun.new(5)
	mt.play_mail([_card(&"x", MailCard.Type.EPIC, 0, 1), _card(&"y", MailCard.Type.EPIC, 0, 1),
		_card(&"z", MailCard.Type.EPIC, 0, 1)])
	print("three-card mail still costs one turn (expect 4): ", mt.turns_left)

	# 23. mail_sent telemetry carries the bundle.
	var sent := _events_of("mail_sent")
	print("mail_sent events emitted (expect > 0): ", sent.size() > 0)
	print("mail_sent carries card_ids (expect true): ", sent[0]["payload"].has("card_ids"))
	var has_bundle := false
	for e in sent:
		if int(e["payload"]["card_count"]) >= 2:
			has_bundle = true
	print("a multi-card mail_sent was logged (expect true): ", has_bundle)

	# ---- Hannes state: derived from the bars, mirrors only (no effect) ----

	# 24. All four states over the bar combinations (existing thresholds only).
	print("neutral at safe bars 3/3 (expect NEUTRAL): ", Pool.HannesState.keys()[Pool.hannes_state(3, 3)])
	print("start state is misstrauisch at 4/3 (expect MISSTRAUISCH): ",
		Pool.HannesState.keys()[Pool.hannes_state(Pool.SUSPICION_START, Pool.PRESSURE_START)])
	print("misstrauisch at suspicion 4 (expect MISSTRAUISCH): ", Pool.HannesState.keys()[Pool.hannes_state(4, 5)])
	print("interessiert at pressure 6 (expect INTERESSIERT): ", Pool.HannesState.keys()[Pool.hannes_state(3, 6)])
	print("angebissen at 3/7 (expect ANGEBISSEN): ", Pool.HannesState.keys()[Pool.hannes_state(3, 7)])
	# Gate open (pressure 8) but suspicious (5) -> misstrauisch, not angebissen.
	print("gate-open-but-suspicious reads misstrauisch (expect MISSTRAUISCH): ",
		Pool.HannesState.keys()[Pool.hannes_state(5, 8)])

	# ANGEBISSEN coincides exactly with the win-ready state.
	var hw := MailRun.new(5)
	hw.play_mail([_card(&"a", MailCard.Type.EPIC, -1, 4)])  # pressure 7, suspicion 3
	print("run reports angebissen when win-ready (expect ANGEBISSEN): ", Pool.HannesState.keys()[hw.hannes_state()])
	print("angebissen matches payload_would_win (expect true): ", hw.payload_would_win())

	# 25. hannes_state telemetry emitted per mail.
	var hs := _events_of("hannes_state")
	print("hannes_state events emitted (expect > 0): ", hs.size() > 0)
	print("hannes_state carries the state (expect true): ", hs[0]["payload"].has("state"))

	print("TEST DONE")
	return true
