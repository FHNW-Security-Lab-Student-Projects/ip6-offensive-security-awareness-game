# Global signal hub. All scenarios emit telemetry events through here;
# Telemetry subscribes and persists. Keeping the schema flat (single
# Dictionary payload) avoids signal-explosion as scenarios grow.
extends Node

signal generic_event(payload: Dictionary)

# Convenience helper for the most common event type: a player decision.
# Always populates the canonical fields; extra goes into payload.payload.
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
