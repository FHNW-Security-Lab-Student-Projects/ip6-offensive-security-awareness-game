# The MailBuilder run: the pure logic core (no UI). Holds the two target bars,
# the remaining turns and the played cards; play_card applies effects, spends a
# turn and resolves outcomes. Emits telemetry through the existing EventBus on
# every play and at the outcome. Referenced by path (preload), no global class
# name.
extends RefCounted

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

const SCENARIO_ID := "spear_phishing"

enum Outcome { NONE, WIN, SPAM, KOLLEGEN_RUECKFRAGE, IGNORIERT }

var suspicion: int
var pressure: int
var turns_left: int
var outcome: Outcome = Outcome.NONE
var played: Array[StringName] = []   # card ids in play order
var probe_done: bool = false         # flipped once the probe card is played
# Per-card snapshots of the most recent mail: [{id, suspicion, pressure}, ...] in
# application order. The UI replays it to reveal the effect card by card.
var last_mail_steps: Array = []

var _turn_budget: int
var _pressure_amplified: bool = false
var _bus: Node = null
var _bus_resolved := false


func _init(turn_budget: int) -> void:
	_turn_budget = turn_budget
	suspicion = Pool.SUSPICION_START
	pressure = Pool.PRESSURE_START
	turns_left = turn_budget


func is_over() -> bool:
	return outcome != Outcome.NONE


func turns_used() -> int:
	return _turn_budget - turns_left


# The payload becomes playable on pressure alone; suspicion decides the outcome
# (win vs Kollegen-Rückfrage). The gate and the win test are the run's single
# source of truth — the UI reads them, it never re-derives the thresholds.
func payload_gate_open() -> bool:
	return pressure >= Pool.PRESSURE_TARGET


func payload_would_win() -> bool:
	return payload_gate_open() and suspicion <= Pool.SUSPICION_TARGET


# Which cards may go into the current mail. The payload unlocks with its gate
# (pressure alone). Everything else stays available until the attack would
# actually WIN — only then does the run funnel the player into the send
# decision. Locking on the open gate alone would strand a player whose pressure
# is high but whose suspicion is still above target: they could neither repair
# the suspicion nor win, and every remaining move would be a loss.
# The UI reads this fact per card; play_mail itself stays tolerant of
# hand-built input (tests drive it directly).
func card_playable(card: MailCard) -> bool:
	if is_over() or turns_left <= 0:
		return false
	if card.type == MailCard.Type.PAYLOAD:
		return payload_gate_open()
	return not payload_would_win()


# Hannes' reactive state, derived from the current bars (read-only, no effect on
# the run). The UI reads it to pick his reply; the thresholds live in the Pool.
func hannes_state() -> int:
	return Pool.hannes_state(suspicion, pressure)


# One mail = one turn. Applies the drafted cards' effects in slot order
# (bundled), spends a SINGLE turn, then resolves on the SUMMED end state. Records
# a per-card reveal trace in last_mail_steps so the UI can show the effect card
# by card AFTER sending (never before). Returns the resulting Outcome. A payload
# in the draft fires the attack once its gate is open on the current bars.
func play_mail(cards: Array) -> Outcome:
	last_mail_steps = []
	if is_over() or turns_left <= 0:
		return outcome
	if cards.is_empty():
		return outcome
	var payload_card := _find_payload(cards)
	if payload_card != null and not payload_gate_open():
		return outcome  # cannot fire the link yet; no turn spent

	var suspicion_before := suspicion
	var pressure_before := pressure
	var ids: Array[String] = []
	for card in cards:
		ids.append(String(card.id))
		if card.type == MailCard.Type.PAYLOAD:
			continue
		_apply_card(card)
		last_mail_steps.append({"id": card.id, "suspicion": suspicion, "pressure": pressure})

	turns_left -= 1
	_emit_mail_sent(ids, suspicion_before, pressure_before)
	_emit_hannes_state()

	if payload_card != null:
		last_mail_steps.append({"id": payload_card.id, "suspicion": suspicion, "pressure": pressure})
		return _resolve_payload(payload_card)
	if suspicion > Pool.SPAM_THRESHOLD:
		_finish(Outcome.SPAM)
	elif turns_left <= 0:
		_finish(Outcome.IGNORIERT)
	return outcome


# A single card is just a one-card mail: keeps the earlier per-card semantics
# (and every existing boundary test) intact while the UI drafts multi-card mails.
func play_card(card: MailCard) -> Outcome:
	return play_mail([card])


# Applies one card's effect (bars, the "Keiner fragt nach" amplifier, the probe
# flag) and logs it — WITHOUT spending a turn or resolving. play_mail owns the
# turn and the outcome so effects bundle into a single mail.
func _apply_card(card: MailCard) -> void:
	var suspicion_before := suspicion
	var pressure_before := pressure
	var applied_pressure := card.pressure
	if card.pressure > 0 and _pressure_amplified:
		applied_pressure += Pool.AMPLIFIER_BONUS
	suspicion = maxi(Pool.SUSPICION_MIN, suspicion + card.suspicion)
	pressure = maxi(Pool.PRESSURE_MIN, pressure + applied_pressure)
	if card.amplifies_pressure:
		_pressure_amplified = true
	if card.grants_probe:
		probe_done = true
	played.append(card.id)
	_emit_card_played(card, suspicion_before, pressure_before)


func _find_payload(cards: Array) -> MailCard:
	for card in cards:
		if card.type == MailCard.Type.PAYLOAD:
			return card
	return null


# Passing spends a turn without playing a card (telemetry logs it). Lets a
# player run the budget down to IGNORIERT instead of being forced into SPAM.
func pass_turn() -> Outcome:
	if is_over() or turns_left <= 0:
		return outcome
	turns_left -= 1
	_emit({
		"phase": "mail_pass",
		"scenario_id": SCENARIO_ID,
		"action": "pass_turn",
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"turn": played.size(),
			"turns_left": turns_left,
			"suspicion": suspicion,
			"pressure": pressure,
		},
	})
	if turns_left <= 0:
		_finish(Outcome.IGNORIERT)
	return outcome


# Resolves the payload against the final bars. The gate check and the turn are
# owned by play_mail; here we only score win vs Kollegen-Rückfrage and finish.
func _resolve_payload(card: MailCard) -> Outcome:
	played.append(card.id)
	var won := payload_would_win()
	var result := Outcome.WIN if won else Outcome.KOLLEGEN_RUECKFRAGE
	_emit({
		"phase": "mail_payload_attempt",
		"scenario_id": SCENARIO_ID,
		"action": String(card.id),
		"is_correct": won,
		"latency_ms": null,
		"payload": {
			"pressure": pressure,
			"suspicion": suspicion,
			"outcome": Outcome.keys()[result],
		},
	})
	_finish(result)
	return result


func _finish(result: Outcome) -> void:
	outcome = result
	_emit({
		"phase": "mail_outcome",
		"scenario_id": SCENARIO_ID,
		"action": Outcome.keys()[result],
		"is_correct": result == Outcome.WIN,
		"latency_ms": null,
		"payload": {
			"turns_used": turns_used(),
			"turn_budget": _turn_budget,
			"suspicion": suspicion,
			"pressure": pressure,
		},
	})


# Telemetry sink: the real EventBus autoload, resolved by node path (not the
# global identifier, which a bare `-s` test script cannot compile). Present at
# runtime in the game and under headless tests, so events reach Telemetry.
func _emit(payload: Dictionary) -> void:
	if not _bus_resolved:
		_bus_resolved = true
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			_bus = (loop as SceneTree).root.get_node_or_null("EventBus")
	if _bus != null:
		_bus.emit_signal("generic_event", payload)


# Hannes' state after the mail, mirrored from the final bars. Additive telemetry;
# it carries no game effect (he only reflects the bars the player already drove).
func _emit_hannes_state() -> void:
	var state := Pool.hannes_state(suspicion, pressure)
	_emit({
		"phase": "hannes_state",
		"scenario_id": SCENARIO_ID,
		"action": Pool.HannesState.keys()[state],
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"state": Pool.HannesState.keys()[state],
			"turn": turns_used(),
			"suspicion": suspicion,
			"pressure": pressure,
		},
	})


# The mail unit: which cards went out together, on which turn, and the bar delta
# for the whole mail. Complements the per-card mail_card_played events.
func _emit_mail_sent(card_ids: Array, suspicion_before: int, pressure_before: int) -> void:
	_emit({
		"phase": "mail_sent",
		"scenario_id": SCENARIO_ID,
		"action": "mail_sent",
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"card_ids": card_ids,
			"card_count": card_ids.size(),
			"turn": turns_used(),
			"suspicion_before": suspicion_before,
			"suspicion_after": suspicion,
			"pressure_before": pressure_before,
			"pressure_after": pressure,
		},
	})


func _emit_card_played(card: MailCard, suspicion_before: int, pressure_before: int) -> void:
	_emit({
		"phase": "mail_card_played",
		"scenario_id": SCENARIO_ID,
		"action": String(card.id),
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"card_type": card.type_name(),
			"principle": String(card.principle),
			"suspicion_before": suspicion_before,
			"suspicion_after": suspicion,
			"pressure_before": pressure_before,
			"pressure_after": pressure,
			"turn": played.size(),
			"turns_left": turns_left,
		},
	})
