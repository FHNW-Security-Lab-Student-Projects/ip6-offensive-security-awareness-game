# Global signal hub for telemetry. One flat Dictionary instead of a signal per
# event type, so the signal count does not grow with the scenarios.
extends Node

signal generic_event(payload: Dictionary)

# A graded decision. is_correct feeds the study's error rate, so only pass a
# choice that is genuinely right or wrong — merely different belongs in emit_action.
func emit_decision(
	scenario_id: String,
	action: String,
	is_correct: bool,
	latency_ms: int,
	extra: Dictionary = {}
) -> void:
	generic_event.emit({
		"phase": "action",
		"scenario_id": scenario_id,
		"action": action,
		"is_correct": is_correct,
		"latency_ms": latency_ms,
		"payload": extra,
	})

# Ungraded interaction. is_correct stays null so it cannot skew the error rate.
func emit_action(
	scenario_id: String,
	action: String,
	latency_ms: int,
	extra: Dictionary = {}
) -> void:
	generic_event.emit({
		"phase": "action",
		"scenario_id": scenario_id,
		"action": action,
		"is_correct": null,
		"latency_ms": latency_ms,
		"payload": extra,
	})
