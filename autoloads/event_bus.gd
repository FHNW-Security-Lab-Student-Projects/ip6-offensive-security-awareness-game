# Global signal hub. All scenarios emit telemetry events through here;
# Telemetry subscribes and persists. Keeping the schema flat (single
# Dictionary payload) avoids signal-explosion as scenarios grow.
extends Node

signal generic_event(payload: Dictionary)

# Convenience helper for the most common event type: a player decision.
# Always populates the canonical fields; extra goes into payload.payload.
#
# is_correct is what the study's error rate (Fehlerquote) is computed from, so
# only pass a decision that is genuinely right or wrong here. Branches that are
# merely different (not better or worse) belong in emit_action.
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

# Ungraded counterpart to emit_decision: an interaction that is recorded for the
# behavioural trace but carries no notion of correctness (navigation, opening a
# document, advancing a debrief page). is_correct stays null so these events
# cannot skew the error rate, while latency_ms still captures how long the
# player took.
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
