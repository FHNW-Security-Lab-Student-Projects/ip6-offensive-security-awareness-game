# Stub. Buffers all events between scenario_start and scenario_complete
# so the downstream UI has something to read from. Real evaluation
# (per-decision correctness, latency, hints) is not implemented yet.
extends Node

var _current_buffer: Array = []

func _ready() -> void:
	EventBus.generic_event.connect(_on_event)

func _on_event(payload: Dictionary) -> void:
	var phase: Variant = payload.get("phase", "")
	if phase == "scenario_start":
		_current_buffer = [payload]
	elif phase == "scenario_complete":
		_current_buffer.append(payload)
	elif _current_buffer.size() > 0:
		_current_buffer.append(payload)

# TODO: real feedback computation.
func evaluate(events: Array = []) -> Dictionary:
	if events.is_empty():
		events = _current_buffer
	return {
		"summary": "Feedback engine stub.",
		"event_count": events.size(),
	}
