# Scenario 1: Phishing (Phase 1 sub-state shell).
#
# Owns four sub-states (Briefing -> Recon -> MailBuilder -> Resolve) and
# the advance wiring between them. Each sub-state scene is a Control
# child of CanvasLayer; only one is visible at a time. The real UI for
# each sub-state arrives in later phases — this file is the plumbing.
extends ScenarioBase

const SCENARIO_ID: String = "spear_phishing"

enum SubState { BRIEFING, RECON, MAIL, RESOLVE }

@onready var _states: Dictionary = {
	SubState.BRIEFING: $CanvasLayer/Briefing,
	SubState.RECON:    $CanvasLayer/Recon,
	SubState.MAIL:     $CanvasLayer/MailBuilder,
	SubState.RESOLVE:  $CanvasLayer/Resolve,
}

var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

# LevelAuswahl change_scene_to_file()s into this scene without calling
# start_scenario, so we bootstrap here. Promote to ScenarioBase if/when
# other scenarios need the same treatment.
func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	for state in _states.values():
		state.visible = false
		state.advance_requested.connect(_advance)

func _on_start() -> void:
	_change_substate(SubState.BRIEFING)

func _on_action(_action_id: String) -> void:
	pass

func _on_complete() -> void:
	pass

# Sub-states emit advance_requested when the player wants to move on.
# Routing lives here so sub-states stay ignorant of what comes next.
func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			_change_substate(SubState.RECON)
		SubState.RECON:
			_change_substate(SubState.MAIL)
		SubState.MAIL:
			_change_substate(SubState.RESOLVE)
		SubState.RESOLVE:
			complete_scenario()

func _change_substate(new_state: SubState) -> void:
	var from_name: String = (
		SubState.keys()[_current] if _initialised else "INIT"
	)
	if _initialised and _states.has(_current):
		_states[_current].visible = false
	_states[new_state].visible = true
	_current = new_state
	_initialised = true
	EventBus.generic_event.emit({
		"phase": "substate_change",
		"scenario_id": scenario_id,
		"action": null,
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"from": from_name,
			"to": SubState.keys()[new_state],
		},
	})
