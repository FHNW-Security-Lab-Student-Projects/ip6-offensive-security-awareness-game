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


# Plays a card: applies its effect (with the "Keiner fragt nach" amplifier on
# pressure cards), spends a turn, and resolves SPAM/IGNORIERT — or, for the
# payload, the win/fail outcome. Returns the resulting Outcome (NONE if the run
# continues). A finished run or an exhausted budget rejects further plays.
func play_card(card: MailCard) -> Outcome:
	if is_over() or turns_left <= 0:
		return outcome

	if card.type == MailCard.Type.PAYLOAD:
		return _resolve_payload(card)

	var suspicion_before := suspicion
	var pressure_before := pressure

	var applied_pressure := card.pressure
	if card.pressure > 0 and _pressure_amplified:
		applied_pressure += Pool.AMPLIFIER_BONUS
	suspicion = maxi(Pool.SUSPICION_MIN, suspicion + card.suspicion)
	pressure = maxi(Pool.PRESSURE_MIN, pressure + applied_pressure)
	if card.amplifies_pressure:
		_pressure_amplified = true

	turns_left -= 1
	played.append(card.id)
	_emit_card_played(card, suspicion_before, pressure_before)

	if suspicion > Pool.SPAM_THRESHOLD:
		_finish(Outcome.SPAM)
	elif turns_left <= 0:
		_finish(Outcome.IGNORIERT)
	return outcome


func _resolve_payload(card: MailCard) -> Outcome:
	turns_left -= 1
	played.append(card.id)
	var won := pressure >= Pool.PRESSURE_TARGET and suspicion <= Pool.SUSPICION_TARGET
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
