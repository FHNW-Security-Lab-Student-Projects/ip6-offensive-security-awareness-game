extends ScenarioBase

const SCENARIO_ID: String = "bad_usb"

# Updated the states to match your level progression
enum SubState { BRIEFING, STREET, FRONT, RESOLVE }

@onready var _ui_briefing = $BadUSBScenario/CanvasLayer/Briefing
@onready var _ui_resolve = $BadUSBScenario/CanvasLayer/Resolve

# Updated paths for your specific node names
@onready var _world_street = $BadUSBScenario/GameWorld
@onready var _world_front = $BadUSBScenario/InfrontOfBuilding 

var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	_ui_briefing.visible = false
	_ui_resolve.visible = false
	
	# Freeze both worlds at the start
	_world_street.visible = false
	_world_street.process_mode = Node.PROCESS_MODE_DISABLED
	_world_front.visible = false
	_world_front.process_mode = Node.PROCESS_MODE_DISABLED
	
	_ui_briefing.advance_requested.connect(_advance)
	_ui_resolve.advance_requested.connect(_advance)
	
	var door = $BadUSBScenario/GameWorld/Area2D
	door.body_entered.connect(_on_door_entered)

func _on_start() -> void:
	_change_substate(SubState.BRIEFING)

# Triggers when the player touches the right edge
func _on_door_entered(body: Node2D) -> void:
	if body.name == "Player":
		_change_substate(SubState.FRONT)

func _on_action(_action_id: String) -> void:
	pass

func _on_complete() -> void:
	pass

func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			_change_substate(SubState.STREET)
		SubState.STREET:
			_change_substate(SubState.FRONT)
		SubState.FRONT:
			_change_substate(SubState.RESOLVE)
		SubState.RESOLVE:
			complete_scenario()

func _change_substate(new_state: SubState) -> void:
	var from_name: String = (
		SubState.keys()[_current] if _initialised else "INIT"
	)
	
	# Hide and freeze current state
	if _initialised:
		match _current:
			SubState.BRIEFING: 
				_ui_briefing.visible = false
			SubState.STREET: 
				_world_street.visible = false
				_world_street.process_mode = Node.PROCESS_MODE_DISABLED
			SubState.FRONT:
				_world_front.visible = false
				_world_front.process_mode = Node.PROCESS_MODE_DISABLED
			SubState.RESOLVE: 
				_ui_resolve.visible = false

	# Show and unfreeze new state
	match new_state:
		SubState.BRIEFING: 
			_ui_briefing.visible = true
		SubState.STREET: 
			_world_street.visible = true
			_world_street.process_mode = Node.PROCESS_MODE_INHERIT
			# Force the camera to look at the first player
			_world_street.get_node("Player/Camera2D").make_current()
		SubState.FRONT: 
			_world_front.visible = true
			_world_front.process_mode = Node.PROCESS_MODE_INHERIT
			# Force the camera to switch to the new player!
			_world_front.get_node("Player/Camera2D").make_current()
		SubState.RESOLVE: 
			_ui_resolve.visible = true

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
