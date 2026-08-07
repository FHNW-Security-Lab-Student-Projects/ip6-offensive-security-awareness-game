# The MailBuilder run: pure logic, no UI. Holds the two bars, the remaining
# turns and the played cards, and emits its own telemetry.
# Preload, no class_name: a bare `godot -s` run has no global class cache.
extends RefCounted

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

const SCENARIO_ID := "spear_phishing"

# The engine has no clock of its own. A turn played without one reports null,
# not a fabricated zero.
const UNKNOWN_LATENCY := -1

enum Outcome { NONE, WIN, SPAM, KOLLEGEN_RUECKFRAGE, IGNORIERT }

var suspicion: int
var pressure: int
var turns_left: int
var outcome: Outcome = Outcome.NONE
var played: Array[StringName] = []   # card ids in play order
var probe_done: bool = false         # flipped once the probe card is played
# Per-card snapshots of the last mail, in application order. The UI replays it
# to reveal the effect card by card.
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


# The payload unlocks on pressure alone; suspicion decides how it ends. These
# two are the run's single source of truth: the UI reads them and never
# re-derives the thresholds.
func payload_gate_open() -> bool:
	return pressure >= Pool.PRESSURE_TARGET


func payload_would_win() -> bool:
	return payload_gate_open() and suspicion <= Pool.SUSPICION_TARGET


# Everything stays playable until the attack would actually WIN; only then does
# the run funnel the player into the send. Locking on the open gate alone would
# strand a player with high pressure and too much suspicion: no repair, no win,
# every remaining move a loss.
# play_mail itself stays tolerant of hand-built input, so tests can drive it.
func card_playable(card: MailCard) -> bool:
	if is_over() or turns_left <= 0:
		return false
	if card.type == MailCard.Type.PAYLOAD:
		return payload_gate_open()
	return not payload_would_win()


# Read-only, no effect on the run. The UI reads it to pick the target's reply.
func hannes_state() -> int:
	return Pool.hannes_state(suspicion, pressure)


# One mail is one turn: the drafted cards apply in slot order, a SINGLE turn is
# spent, and the outcome resolves on the SUMMED end state. The per-card trace in
# last_mail_steps lets the UI reveal the effect card by card after sending,
# never before. latency_ms comes from the view.
func play_mail(cards: Array, latency_ms: int = UNKNOWN_LATENCY) -> Outcome:
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
	_emit_mail_sent(ids, suspicion_before, pressure_before, latency_ms)
	_emit_hannes_state()

	if payload_card != null:
		last_mail_steps.append({"id": payload_card.id, "suspicion": suspicion, "pressure": pressure})
		return _resolve_payload(payload_card)
	if suspicion > Pool.SPAM_THRESHOLD:
		_finish(Outcome.SPAM)
	elif turns_left <= 0:
		_finish(Outcome.IGNORIERT)
	return outcome


# A single card is a one-card mail, kept so the per-card boundary tests hold.
func play_card(card: MailCard) -> Outcome:
	return play_mail([card])


# Effect and log only. play_mail owns the turn and the outcome, so several cards
# bundle into one mail.
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


# Spends a turn without a card, so a player can run down to IGNORIERT instead of
# being forced into SPAM.
func pass_turn(latency_ms: int = UNKNOWN_LATENCY) -> Outcome:
	if is_over() or turns_left <= 0:
		return outcome
	turns_left -= 1
	_emit({
		"phase": "mail_pass",
		"scenario_id": SCENARIO_ID,
		"action": "pass_turn",
		"is_correct": null,
		"latency_ms": _latency_or_null(latency_ms),
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


# Scores win vs Kollegen-Rueckfrage and finishes. The gate check and the turn
# belong to play_mail.
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


# Keeps the int-or-null contract for latency_ms: an unmeasured turn must not
# look like an instant one in the analysis.
func _latency_or_null(latency_ms: int) -> Variant:
	return null if latency_ms < 0 else latency_ms


func _emit(payload: Dictionary) -> void:
	if not _bus_resolved:
		_bus_resolved = true
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			_bus = (loop as SceneTree).root.get_node_or_null("EventBus")
	if _bus != null:
		_bus.emit_signal("generic_event", payload)


# Additive telemetry, no game effect: it mirrors the bars the player drove.
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


# The mail as a unit, complementing the per-card events.
func _emit_mail_sent(
	card_ids: Array, suspicion_before: int, pressure_before: int, latency_ms: int
) -> void:
	_emit({
		"phase": "mail_sent",
		"scenario_id": SCENARIO_ID,
		"action": "mail_sent",
		"is_correct": null,
		"latency_ms": _latency_or_null(latency_ms),
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


# Graded on SCHROTT, the one card type the game itself calls a mistake: it burns
# a slot and buys nothing. Every other type is a legitimate move whose merit only
# shows in the outcome, which the outcome events already grade.
func _emit_card_played(card: MailCard, suspicion_before: int, pressure_before: int) -> void:
	_emit({
		"phase": "mail_card_played",
		"scenario_id": SCENARIO_ID,
		"action": String(card.id),
		"is_correct": card.type != MailCard.Type.SCHROTT,
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
