extends ScenarioBase

const SCENARIO_ID: String = "bad_usb"

enum SubState { BRIEFING, INFILTRATION, RESOLVE }

@onready var _ui_briefing = $BadUSBScenario/CanvasLayer/Briefing
@onready var _ui_resolve = $BadUSBScenario/CanvasLayer/Resolve
@onready var _game_world = $BadUSBScenario/GameWorld

var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	_ui_briefing.visible = false
	_ui_resolve.visible = false
	_game_world.visible = false
	
	_ui_briefing.advance_requested.connect(_advance)
	_ui_resolve.advance_requested.connect(_advance)
	
	# Custom signal for when the player drops the USB in the 2D world
	# _game_world.usb_dropped.connect(_advance) 

func _on_start() -> void:
	_change_substate(SubState.INFILTRATION)

func _on_action(_action_id: String) -> void:
	pass

func _on_complete() -> void:
	pass

func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			_change_substate(SubState.INFILTRATION)
		SubState.INFILTRATION:
			_change_substate(SubState.RESOLVE)
		SubState.RESOLVE:
			complete_scenario()

func _change_substate(new_state: SubState) -> void:
	var from_name: String = (
		SubState.keys()[_current] if _initialised else "INIT"
	)
	
	# Hide current state
	if _initialised:
		match _current:
			SubState.BRIEFING: _ui_briefing.visible = false
			SubState.INFILTRATION: _game_world.visible = false
			SubState.RESOLVE: _ui_resolve.visible = false

	# Show new state
	match new_state:
		SubState.BRIEFING: _ui_briefing.visible = true
		SubState.INFILTRATION: _game_world.visible = true
		SubState.RESOLVE: _ui_resolve.visible = true

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
