# Session-wide state: a stable session_uuid, the currently-running
# scenario id, and a tiny state machine used by Main and ScenarioBase
# to decide what scene should be on screen.
extends Node

enum State { MENU, IN_SCENARIO, FEEDBACK }

signal state_changed(old_state: State, new_state: State)

var session_uuid: String = ""
var current_scenario_id: String = ""
var state: State = State.MENU

# ---- Study participant code ----
# Joins this session's telemetry to the questionnaires. Trimmed and capped so a
# stray space cannot split one participant into two rows. Not persisted: a code
# left over from the previous participant would mislabel a whole session.
const PARTICIPANT_CODE_MAX_LENGTH: int = 32

var participant_code: String = ""


func set_participant_code(value: String) -> void:
	participant_code = value.strip_edges().substr(0, PARTICIPANT_CODE_MAX_LENGTH)

func _ready() -> void:
	session_uuid = _generate_session_uuid()

# Outside a running scenario. Menu scenes announce themselves via transition_to
# on _ready, so this stays accurate for the whole session, not just the start.
func is_in_menu() -> bool:
	return state == State.MENU


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

# ---- Mission HUD state ----
# Presentation only, no game logic: written by the scenario shells and the mail
# builder, read by the OSChrome bar through the two signals below.

signal mission_phase_changed(phase: StringName)
signal mission_turns_changed(turns_left: int, turn_budget: int)

var mission_phase: StringName = &""
var mission_turn_budget: int = 0
var mission_turns_left: int = 0

func begin_mission(turn_budget: int) -> void:
	mission_turn_budget = turn_budget
	mission_turns_left = turn_budget
	mission_phase = &""
	mission_turns_changed.emit(mission_turns_left, mission_turn_budget)

func set_mission_phase(phase: StringName) -> void:
	if phase == mission_phase:
		return
	mission_phase = phase
	mission_phase_changed.emit(phase)

# One spent turn; clamped at zero so a stray extra call cannot underflow.
func consume_mission_turn() -> void:
	if mission_turns_left <= 0:
		return
	mission_turns_left -= 1
	mission_turns_changed.emit(mission_turns_left, mission_turn_budget)

# One-shot flag for a replay: set before the reload, consumed by the shell's
# _on_start to skip the intro briefing. Navigation, so reset_scenario leaves it.
var replay_skip_briefing: bool = false

# Zeroes the HUD counters before a replay reload; begin_mission re-seeds them on
# the fresh scene, so this only avoids a stale read in the frames between.
func reset_scenario() -> void:
	mission_phase = &""
	mission_turn_budget = 0
	mission_turns_left = 0

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
