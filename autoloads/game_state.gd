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

# ---- Mission HUD state (presentation only) ----
# Read by the OSChrome shell, written by scenario shells: begin_mission on
# scenario start, set_mission_phase from the shell's advance routing, and
# consume_mission_turn from the mail builder (Phase 4). Deliberately not part
# of the session state machine above — it carries no game logic.

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

# ---- Recon → MailBuilder handoff ----
# Recon writes the ids of the collected finds here on advance; the MailBuilder
# reads them to build the hand (find id -> card). Carries no logic itself.
var collected_find_ids: Array[StringName] = []

# Set true once the mail-phase probe (out-of-office reply, bible Q8) has run.
# Deferred to a future UI task; the MailBuilder catalog gates the Q8 cards on it.
var probe_signature_obtained: bool = false

func set_collected_finds(ids: Array[StringName]) -> void:
	collected_find_ids = ids.duplicate()

# ---- MailBuilder → Resolve handoff ----
# The MailBuilder writes the finished run here (outcome name, final bars,
# turns used, played card ids); the Resolve phase reads it to build its
# debrief. Carries no logic itself.
var mail_result: Dictionary = {}

func set_mail_result(result: Dictionary) -> void:
	mail_result = result.duplicate(true)

# ---- Replay navigation hint ----
# Set by the scenario shell right before a "Nochmal spielen" reload; read once
# by the shell's _on_start to jump straight into the gameplay (skip the intro
# briefing) and cleared on read. A one-shot flag, deliberately NOT touched by
# reset_scenario (it is navigation, not per-run state).
var replay_skip_briefing: bool = false

# ---- Replay: wipe the per-run handoff state ----
# GameState is an autoload, so a scene reload does NOT clear these fields. The
# Resolve "Nochmal spielen" path calls this before reloading the scenario so a
# second run starts clean (no stale recon finds, mail result or probe flag) —
# critical for the user study, where mixed runs would poison the data. The
# mission HUD counters are re-seeded by begin_mission on the fresh scene load;
# zeroing them here just avoids a one-frame stale read.
func reset_scenario() -> void:
	collected_find_ids = []
	mail_result = {}
	probe_signature_obtained = false
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
