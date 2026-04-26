# Session-wide state: a stable session_uuid, the currently-running
# scenario id, and a tiny state machine used by Main and ScenarioBase
# to decide what scene should be on screen.
extends Node

enum State { MENU, IN_SCENARIO, FEEDBACK }

signal state_changed(old_state: State, new_state: State)

var session_uuid: String = ""
var current_scenario_id: String = ""
var state: State = State.MENU

func _ready() -> void:
	session_uuid = _generate_session_uuid()
	# Emit a session_start event so the very first line of every JSONL
	# log identifies the session.
	EventBus.generic_event.emit({
		"phase": "session_start",
		"scenario_id": "",
		"action": null,
		"is_correct": null,
		"latency_ms": null,
		"payload": {"session_uuid": session_uuid},
	})

func transition_to(new_state: State) -> void:
	if new_state == state:
		return
	var old: State = state
	state = new_state
	state_changed.emit(old, new_state)
	EventBus.generic_event.emit({
		"phase": "state_change",
		"scenario_id": current_scenario_id,
		"action": null,
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"from": State.keys()[old],
			"to": State.keys()[new_state],
		},
	})

# Sortable, debuggable id: YYYYMMDD_HHMMSS_xxxx (xxxx = 4 hex chars).
# Not cryptographically unique — fine for ~30 study participants.
func _generate_session_uuid() -> String:
	var ts: String = (
		Time.get_datetime_string_from_system()
			.replace("-", "")
			.replace(":", "")
			.replace("T", "_")
	)
	return "%s_%04x" % [ts, randi() & 0xFFFF]
