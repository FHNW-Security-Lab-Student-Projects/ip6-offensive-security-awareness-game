# Stub. Phase 3 will turn the buffered session events into a feedback
# payload (per-decision correctness, latency, hints to surface). For
# now it just collects events between scenario start/complete so the
# downstream UI has a buffer to read from.
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

# TODO Phase 3: real feedback computation.
func evaluate(events: Array = []) -> Dictionary:
	if events.is_empty():
		events = _current_buffer
	return {
		"summary": "Feedback engine stub — implement in Phase 3.",
		"event_count": events.size(),
	}
