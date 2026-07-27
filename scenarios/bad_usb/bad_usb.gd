extends ScenarioBase

const SCENARIO_ID: String = "bad_usb"

enum SubState { BRIEFING, STREET, FRONT, INSIDE, TAILGATE, CORRIDOR, OFFICE, RESOLVE }

var _ui_briefing 
@onready var _ui_resolve = $BadUSBScenario/CanvasLayer/Resolve
@onready var _ui_enter_btn = $BadUSBScenario/CanvasLayer/EnterBuildingBtn

@onready var _ui_reception_menu = $BadUSBScenario/CanvasLayer/ReceptionMenu
@onready var _btn_stressed = $BadUSBScenario/CanvasLayer/ReceptionMenu/StressedBtn
@onready var _btn_confident = $BadUSBScenario/CanvasLayer/ReceptionMenu/ConfidentBtn

@onready var _world_street = $BadUSBScenario/GameWorld
@onready var _world_front = $BadUSBScenario/InfrontOfBuilding
@onready var _world_inside = $BadUSBScenario/InsideBuilding
@onready var _barrier_shape = $BadUSBScenario/InsideBuilding/SecurityBarrier/BarrierShape 

@onready var _ui_dialogue_box = $BadUSBScenario/CanvasLayer/DialogueBox
@onready var _lbl_npc_text = $BadUSBScenario/CanvasLayer/DialogueBox/NPCText
@onready var _btn_choice1 = $BadUSBScenario/CanvasLayer/DialogueBox/VBoxContainer/DialogChoice1
@onready var _btn_choice2 = $BadUSBScenario/CanvasLayer/DialogueBox/VBoxContainer/DialogChoice2

@onready var _ui_failure_popup = $BadUSBScenario/CanvasLayer/FailurePopup
@onready var _btn_failure_ok = $BadUSBScenario/CanvasLayer/FailurePopup/FailureOkBtn

@onready var _world_corridor = $BadUSBScenario/BeforeElevator
@onready var _ui_corridor_btn = $BadUSBScenario/CanvasLayer/EnterCorridorBtn
@onready var _ui_missing_badge = $BadUSBScenario/BeforeElevator/MissingBadgeUI
@onready var _ui_npc_speech = $BadUSBScenario/BeforeElevator/NPCSpeechUI
@onready var _ui_office_btn = $BadUSBScenario/BeforeElevator/EnterOfficeBtn
@onready var _btn_restricted_elevator = $BadUSBScenario/CanvasLayer/RestrictedElevatorBtn

@onready var _world_office = $BadUSBScenario/BigOffice
@onready var _ui_usb_btn = $BadUSBScenario/CanvasLayer/InsertUSBBtn

@onready var _lbl_title = $BadUSBScenario/CanvasLayer/Resolve/VBoxContainer/TitleLabel
@onready var _img_story = $BadUSBScenario/CanvasLayer/Resolve/VBoxContainer/StoryImage
@onready var _lbl_story = $BadUSBScenario/CanvasLayer/Resolve/VBoxContainer/StoryLabel
@onready var _btn_next = $BadUSBScenario/CanvasLayer/Resolve/VBoxContainer/NextBtn
@onready var _btn_finish = $BadUSBScenario/CanvasLayer/Resolve/VBoxContainer/FinishBtn

@onready var _world_tailgate = $BadUSBScenario/TailgateDoor
@onready var _npc_tailgate = $BadUSBScenario/TailgateDoor/Background/Background/NPC
@onready var _sprite_open_door = $BadUSBScenario/TailgateDoor/Background/Background/Door

@onready var _npc_office = $BadUSBScenario/BigOffice/OfficeNPC

@onready var _ui_tailgate_locked = $BadUSBScenario/TailgateDoor/MissingBadgeUI
@onready var _btn_tailgate_trigger = $BadUSBScenario/TailgateDoor/TriggerTailgateBtn
@onready var _btn_tailgate_enter = $BadUSBScenario/TailgateDoor/EnterTailgateDoorBtn

var _tailgate_event_triggered: bool = false
var _office_npc_triggered: bool = false 
var _office_dialogue_done: bool = false 

var _dialogue_step: int = 0
var _inside_start_pos: Vector2 
var _front_door_pos: Vector2 
var _office_npc_start_pos: Vector2 

var _corridor_start_pos: Vector2
var _tailgate_start_pos: Vector2
var _npc_tailgate_start_pos: Vector2

var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

var _story_step: int = 0
var _typewriter_speed: float = 0.04

func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	_barrier_shape.disabled = false

	_swap_in_briefing()

	_ui_briefing.visible = false
	_ui_resolve.visible = false
	_ui_enter_btn.visible = false
	_ui_reception_menu.visible = false 
	_ui_corridor_btn.visible = false 
	_ui_office_btn.visible = false 
	_ui_usb_btn.visible = false    
	_btn_restricted_elevator.visible = false 
	
	_ui_tailgate_locked.visible = false
	_btn_tailgate_trigger.visible = false
	_btn_tailgate_enter.visible = false
	_sprite_open_door.visible = false 
	
	_world_street.visible = false
	_world_street.process_mode = Node.PROCESS_MODE_DISABLED
	_world_front.visible = false
	_world_front.process_mode = Node.PROCESS_MODE_DISABLED
	_world_inside.visible = false
	_world_inside.process_mode = Node.PROCESS_MODE_DISABLED
	_world_tailgate.visible = false 
	_world_tailgate.process_mode = Node.PROCESS_MODE_DISABLED 
	_world_corridor.visible = false
	_world_corridor.process_mode = Node.PROCESS_MODE_DISABLED
	_world_office.visible = false
	_world_office.process_mode = Node.PROCESS_MODE_DISABLED
	
	if _ui_briefing.has_signal("advance_requested") and not _ui_briefing.is_connected("advance_requested", _advance):
		_ui_briefing.advance_requested.connect(_advance)
	
	var door = $BadUSBScenario/GameWorld/Area2D
	if not door.body_entered.is_connected(_on_door_entered):
		door.body_entered.connect(_on_door_entered)
	
	var entrance_zone = $BadUSBScenario/InfrontOfBuilding/BuildingEntrance
	if not entrance_zone.body_entered.is_connected(_on_entrance_entered):
		entrance_zone.body_entered.connect(_on_entrance_entered)
		entrance_zone.body_exited.connect(_on_entrance_exited)
	
	if not _ui_enter_btn.pressed.is_connected(_on_enter_button_pressed):
		_ui_enter_btn.pressed.connect(_on_enter_button_pressed)
	
	var reception_zone = $BadUSBScenario/InsideBuilding/ReceptionZone
	if not reception_zone.body_entered.is_connected(_on_reception_entered):
		reception_zone.body_entered.connect(_on_reception_entered)
		reception_zone.body_exited.connect(_on_reception_exited)
	
	if not _btn_stressed.pressed.is_connected(_on_stressed_pressed):
		_btn_stressed.pressed.connect(_on_stressed_pressed)
		_btn_confident.pressed.connect(_on_confident_pressed)
	
	_ui_dialogue_box.visible = false
	
	if not _btn_choice1.pressed.is_connected(_on_dialog_choice_1_pressed):
		_btn_choice1.pressed.connect(_on_dialog_choice_1_pressed)
	if not _btn_choice2.pressed.is_connected(_on_dialog_choice_2_pressed):
		_btn_choice2.pressed.connect(_on_dialog_choice_2_pressed)
	
	_ui_failure_popup.visible = false
	if not _btn_failure_ok.pressed.is_connected(_on_failure_ok_pressed):
		_btn_failure_ok.pressed.connect(_on_failure_ok_pressed)
	
	var corridor_zone = $BadUSBScenario/InsideBuilding/CorridorZone
	if not corridor_zone.body_entered.is_connected(_on_corridor_zone_entered):
		corridor_zone.body_entered.connect(_on_corridor_zone_entered)
		corridor_zone.body_exited.connect(_on_corridor_zone_exited)
	
	if not _ui_corridor_btn.pressed.is_connected(_on_corridor_btn_pressed):
		_ui_corridor_btn.pressed.connect(_on_corridor_btn_pressed)
	
	_ui_missing_badge.visible = false
	_ui_npc_speech.visible = false
	
	var restricted_zone = $BadUSBScenario/BeforeElevator/RestrictedElevatorZone
	if not restricted_zone.body_entered.is_connected(_on_restricted_entered):
		restricted_zone.body_entered.connect(_on_restricted_entered)
		restricted_zone.body_exited.connect(_on_restricted_exited)
	
	if not _btn_restricted_elevator.pressed.is_connected(_on_restricted_btn_pressed):
		_btn_restricted_elevator.pressed.connect(_on_restricted_btn_pressed) 
	
	var npc_zone = $BadUSBScenario/BeforeElevator/NPCElevatorZone
	if not npc_zone.body_entered.is_connected(_on_npc_zone_entered):
		npc_zone.body_entered.connect(_on_npc_zone_entered)
		npc_zone.body_exited.connect(_on_npc_zone_exited)
	
	if not _ui_office_btn.pressed.is_connected(_on_office_btn_pressed):
		_ui_office_btn.pressed.connect(_on_office_btn_pressed)
	
	var pc_zone = $BadUSBScenario/BigOffice/PCZone
	if not pc_zone.body_entered.is_connected(_on_pc_zone_entered):
		pc_zone.body_entered.connect(_on_pc_zone_entered)
		pc_zone.body_exited.connect(_on_pc_zone_exited)
	
	if not _ui_usb_btn.pressed.is_connected(_on_usb_btn_pressed):
		_ui_usb_btn.pressed.connect(_on_usb_btn_pressed)
	
	if not _btn_next.pressed.is_connected(_on_next_pressed):
		_btn_next.pressed.connect(_on_next_pressed)
		_btn_finish.pressed.connect(_on_finish_pressed)
	
	var tailgate_locked_zone = $BadUSBScenario/TailgateDoor/LockedDoorZone
	if not tailgate_locked_zone.body_entered.is_connected(_on_locked_door_entered):
		tailgate_locked_zone.body_entered.connect(_on_locked_door_entered)
		tailgate_locked_zone.body_exited.connect(_on_locked_door_exited)
	
	if not _btn_tailgate_trigger.pressed.is_connected(_on_tailgate_trigger_pressed):
		_btn_tailgate_trigger.pressed.connect(_on_tailgate_trigger_pressed)
		_btn_tailgate_enter.pressed.connect(_on_tailgate_enter_pressed)
	
	_inside_start_pos = _world_inside.get_node("Player").position
	_office_npc_start_pos = _npc_office.position 
	_npc_office.flip_h = false 
	_npc_office.play("idle")
	
	_corridor_start_pos = _world_corridor.get_node("Player").position
	_tailgate_start_pos = _world_tailgate.get_node("Player").position
	_npc_tailgate_start_pos = _npc_tailgate.position

func _swap_in_briefing() -> void:
	var canvas = $BadUSBScenario/CanvasLayer
	var placeholder = canvas.get_node_or_null("Briefing")
	if placeholder != null:
		placeholder.name = "BriefingPlaceholder"
		placeholder.queue_free()
	_ui_briefing = load("res://scenarios/spear_phishing/states/briefing.tscn").instantiate()
	_ui_briefing.briefing_path = "res://resources/scenarios/bad_usb/briefing.tres"
	canvas.add_child(_ui_briefing)

func _on_start() -> void:
	_change_substate(SubState.BRIEFING)

func _on_door_entered(body: Node2D) -> void:
	if body.name == "Player":
		_change_substate(SubState.FRONT)

func _on_entrance_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_enter_btn.visible = true
		_front_door_pos = body.position 

func _on_entrance_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_enter_btn.visible = false

func _on_enter_button_pressed() -> void:
	_ui_enter_btn.visible = false
	_world_inside.get_node("Player").position = _inside_start_pos
	_change_substate(SubState.INSIDE)

func _on_corridor_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_corridor_btn.visible = true

func _on_corridor_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_corridor_btn.visible = false

func _on_corridor_btn_pressed() -> void:
	_ui_corridor_btn.visible = false
	_change_substate(SubState.CORRIDOR)

func _on_locked_door_entered(body: Node2D) -> void:
	if body.name == "Player":
		if not _tailgate_event_triggered:
			_btn_tailgate_trigger.visible = true 
		elif _sprite_open_door.visible: 
			_btn_tailgate_enter.visible = true

func _on_locked_door_exited(body: Node2D) -> void:
	if body.name == "Player":
		_btn_tailgate_trigger.visible = false
		_btn_tailgate_enter.visible = false 
		_ui_tailgate_locked.visible = false

func _on_tailgate_trigger_pressed() -> void:
	_btn_tailgate_trigger.visible = false 
	_ui_tailgate_locked.visible = true 
	_tailgate_event_triggered = true 
	_start_npc_walk_event()

func _start_npc_walk_event() -> void:
	var door_position = Vector2(5534, _npc_tailgate.position.y) 
	
	_npc_tailgate.flip_h = true
	# Start walking animation
	_npc_tailgate.play("walk")
	
	var tween = create_tween()
	tween.tween_property(_npc_tailgate, "position", door_position, 6) 
	tween.finished.connect(_on_npc_arrived_at_door)

func _on_npc_arrived_at_door() -> void:
	_npc_tailgate.play("idle")
	
	_ui_tailgate_locked.visible = false 
	_sprite_open_door.visible = true 
	_npc_tailgate.visible = false    
	_btn_tailgate_enter.visible = true

func _on_tailgate_enter_pressed() -> void:
	_btn_tailgate_enter.visible = false
	_change_substate(SubState.OFFICE) 

func _on_restricted_entered(body: Node2D) -> void:
	if body.name == "Player":
		_btn_restricted_elevator.visible = true 

func _on_restricted_exited(body: Node2D) -> void:
	if body.name == "Player":
		_btn_restricted_elevator.visible = false
		_ui_missing_badge.visible = false 

func _on_restricted_btn_pressed() -> void:
	_btn_restricted_elevator.visible = false 
	_ui_missing_badge.visible = true 

func _on_npc_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_npc_speech.visible = true
		_ui_office_btn.visible = true

func _on_npc_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_npc_speech.visible = false
		_ui_office_btn.visible = false

func _on_office_btn_pressed() -> void:
	_ui_office_btn.visible = false
	_ui_npc_speech.visible = false
	_change_substate(SubState.TAILGATE) 

func _start_office_npc_approach() -> void:
	var player = _world_office.get_node("Player")
	var player_sprite = player.get_node("AnimatedSprite2D")
	
	_npc_office.global_position.y = player_sprite.global_position.y
	_npc_office.global_position.x = player_sprite.global_position.x + 800
	_npc_office.z_index = 10
	_npc_office.visible = true
	
	var target_x = player_sprite.global_position.x - 250 
	
	_npc_office.flip_h = true 
	_npc_office.play("walk")
	
	var tween = create_tween()
	tween.tween_property(_npc_office, "global_position:x", target_x, 1.5)
	tween.finished.connect(_on_office_npc_arrived)

func _start_office_npc_run_away() -> void:
	_npc_office.flip_h = true 
	_npc_office.play("walk")
	
	var target_x = _npc_office.global_position.x - 1000 
	
	var tween = create_tween()
	tween.tween_property(_npc_office, "global_position:x", target_x, 1.5) 
	tween.finished.connect(_on_office_npc_gone)

func _on_office_npc_arrived() -> void:
	var player = _world_office.get_node("Player")
	player.set_physics_process(false) 
	
	_npc_office.flip_h = false 
	_npc_office.play("idle")
	
	var player_sprite = player.get_node("AnimatedSprite2D")
	player_sprite.flip_h = true 
	player_sprite.play("idle")
	
	_ui_dialogue_box.visible = true
	_dialogue_step = 30
	_update_dialogue_ui()

func _on_office_npc_gone() -> void:
	_npc_office.visible = false

func _on_pc_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		if _office_dialogue_done:
			_ui_usb_btn.visible = true

func _on_pc_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_usb_btn.visible = false
		_ui_dialogue_box.visible = false

func _on_usb_btn_pressed() -> void:
	_ui_usb_btn.visible = false
	_change_substate(SubState.RESOLVE) 

func _on_reception_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_reception_menu.visible = true

func _on_reception_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_reception_menu.visible = false

func _on_stressed_pressed() -> void:
	_ui_reception_menu.visible = false
	_ui_dialogue_box.visible = true
	_dialogue_step = 10
	_update_dialogue_ui()
	
	var player = _world_inside.get_node("Player")
	player.set_physics_process(false)
	player.get_node("AnimatedSprite2D").play("idle")

func _on_confident_pressed() -> void:
	_ui_reception_menu.visible = false
	_ui_dialogue_box.visible = true
	_dialogue_step = 20
	_update_dialogue_ui()
	
	var player = _world_inside.get_node("Player")
	player.set_physics_process(false)
	player.get_node("AnimatedSprite2D").play("idle")

func _on_dialog_choice_1_pressed() -> void:
	match _dialogue_step:
		11, 21, 31: 
			_dialogue_step += 1
			_update_dialogue_ui()
		12, 22: 
			_ui_dialogue_box.visible = false
			_barrier_shape.disabled = true 
			_world_inside.get_node("Player").set_physics_process(true)
		32:
			_ui_dialogue_box.visible = false
			_office_dialogue_done = true
			
			_start_office_npc_run_away() 
			_world_office.get_node("Player").set_physics_process(true)
			
		10, 20, 30: 
			_ui_dialogue_box.visible = false
			_ui_failure_popup.visible = true

func _on_dialog_choice_2_pressed() -> void:
	match _dialogue_step:
		10, 20, 30: 
			_dialogue_step += 1
			_update_dialogue_ui()
		11, 21, 31: 
			_ui_dialogue_box.visible = false
			_ui_failure_popup.visible = true

func _on_failure_ok_pressed() -> void:
	_ui_failure_popup.visible = false
	_dialogue_step = 0
	
	_tailgate_event_triggered = false
	_office_npc_triggered = false
	_office_dialogue_done = false
	
	# --- Reset Office NPC ---
	_npc_office.position = _office_npc_start_pos
	_npc_office.flip_h = false
	_npc_office.play("idle")
	_npc_office.visible = false 
	
	_world_office.get_node("Player").set_physics_process(true)
	_world_inside.get_node("Player").set_physics_process(true)
	
	# --- Reset Tailgate Scene ---
	_sprite_open_door.visible = false
	_npc_tailgate.position = _npc_tailgate_start_pos
	_npc_tailgate.flip_h = false 
	_npc_tailgate.play("idle")
	_npc_tailgate.visible = true 
	
	# --- Reset Player Positions ---
	_world_front.get_node("Player").position = _front_door_pos
	_world_inside.get_node("Player").position = _inside_start_pos
	_world_corridor.get_node("Player").position = _corridor_start_pos
	_world_tailgate.get_node("Player").position = _tailgate_start_pos
	
	_change_substate(SubState.FRONT)

func _on_action(_action_id: String) -> void:
	pass

func _on_complete() -> void:
	pass

func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			# Intro -> gameplay: black fade as a loading beat.
			SceneTransition.flash(_change_substate.bind(SubState.STREET))
		SubState.STREET:
			_change_substate(SubState.FRONT)
		SubState.FRONT:
			_change_substate(SubState.INSIDE)
		SubState.INSIDE:
			_change_substate(SubState.CORRIDOR) 
		SubState.CORRIDOR:
			_change_substate(SubState.TAILGATE) 
		SubState.TAILGATE:
			_change_substate(SubState.OFFICE)   
		SubState.OFFICE:
			_change_substate(SubState.RESOLVE)
		SubState.RESOLVE:
			complete_scenario()

func _change_substate(new_state: SubState) -> void:
	var from_name: String = (
		SubState.keys()[_current] if _initialised else "INIT"
	)
	
	if _initialised:
		match _current:
			SubState.BRIEFING:
				_ui_briefing.visible = false
			SubState.STREET:
				_world_street.visible = false
				_world_street.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
			SubState.FRONT:
				_world_front.visible = false
				_world_front.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_enter_btn.visible = false
			SubState.INSIDE:
				_world_inside.visible = false
				_world_inside.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_reception_menu.visible = false
				_ui_corridor_btn.visible = false 
			SubState.TAILGATE: 
				_world_tailgate.visible = false
				_world_tailgate.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_tailgate_locked.visible = false
				_btn_tailgate_trigger.visible = false
				_btn_tailgate_enter.visible = false
			SubState.CORRIDOR:
				_world_corridor.visible = false
				_world_corridor.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_office_btn.visible = false 
				_btn_restricted_elevator.visible = false 
			SubState.OFFICE:
				_world_office.visible = false
				_world_office.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_usb_btn.visible = false 
				_ui_dialogue_box.visible = false 
			SubState.RESOLVE:
				_ui_resolve.visible = false

	match new_state:
		SubState.BRIEFING:
			_ui_briefing.visible = true
		SubState.STREET:
			_world_street.visible = true
			_world_street.process_mode = Node.PROCESS_MODE_INHERIT
			_world_street.get_node("Player/Camera2D").make_current()
		SubState.FRONT:
			_world_front.visible = true
			_world_front.process_mode = Node.PROCESS_MODE_INHERIT
			_world_front.get_node("Player/Camera2D").make_current()
		SubState.INSIDE:
			_world_inside.visible = true
			_world_inside.process_mode = Node.PROCESS_MODE_INHERIT
			_world_inside.get_node("Player/Camera2D").make_current()
		SubState.TAILGATE: 
			_world_tailgate.visible = true
			_world_tailgate.process_mode = Node.PROCESS_MODE_INHERIT
			_world_tailgate.get_node("Player/Camera2D").make_current()
		SubState.CORRIDOR:
			_world_corridor.visible = true
			_world_corridor.process_mode = Node.PROCESS_MODE_INHERIT
			_world_corridor.get_node("Player/Camera2D").make_current()
		SubState.OFFICE:
			_world_office.visible = true
			_world_office.process_mode = Node.PROCESS_MODE_INHERIT
			_world_office.get_node("Player/Camera2D").make_current()
			
			if not _office_npc_triggered:
				_office_npc_triggered = true
				_npc_office.visible = true 
				_start_office_npc_approach()
				
		SubState.RESOLVE:
			_ui_resolve.visible = true
			SfxPlayer.play_completion()  # scenario finished, the debrief comes up
			_start_resolve_story()

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
	
func _update_dialogue_ui() -> void:
	_btn_choice2.visible = true
	
	match _dialogue_step:
		# --- STRESSED PATH ---
		10:
			_lbl_npc_text.text = tr("BADUSB_DLG_10_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_10_C1")
			_btn_choice2.text = tr("BADUSB_DLG_10_C2")
		11:
			_lbl_npc_text.text = tr("BADUSB_DLG_11_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_11_C1")
			_btn_choice2.text = tr("BADUSB_DLG_11_C2")
		12:
			_lbl_npc_text.text = tr("BADUSB_DLG_12_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_12_C1")
			_btn_choice2.visible = false

		# --- CONFIDENT PATH ---
		20:
			_lbl_npc_text.text = tr("BADUSB_DLG_20_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_20_C1")
			_btn_choice2.text = tr("BADUSB_DLG_20_C2")
		21:
			_lbl_npc_text.text = tr("BADUSB_DLG_21_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_21_C1")
			_btn_choice2.text = tr("BADUSB_DLG_21_C2")
		22:
			_lbl_npc_text.text = tr("BADUSB_DLG_22_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_22_C1")
			_btn_choice2.visible = false

		# --- SUSPICIOUS IT OFFICE NPC ---
		30:
			_lbl_npc_text.text = tr("BADUSB_DLG_30_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_30_C1")
			_btn_choice2.text = tr("BADUSB_DLG_30_C2")
		31:
			_lbl_npc_text.text = tr("BADUSB_DLG_31_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_31_C1")
			_btn_choice2.text = tr("BADUSB_DLG_31_C2")
		32:
			_lbl_npc_text.text = tr("BADUSB_DLG_32_NPC")
			_btn_choice1.text = tr("BADUSB_DLG_32_C1")
			_btn_choice2.visible = false

func _start_resolve_story() -> void:
	_story_step = 0
	_play_story_step()

func _play_story_step() -> void:
	_btn_next.visible = false
	_btn_finish.visible = false
	_img_story.visible = false 
	
	var target_text = ""
	
	if _story_step == 0:
		_lbl_title.text = tr("BADUSB_STORY_0_TITLE")
		target_text = tr("BADUSB_STORY_0_TEXT")
		_img_story.texture = preload("res://assets/sprites/placeholder/storyImages/lobby_img.png")

	elif _story_step == 1:
		_lbl_title.text = tr("BADUSB_STORY_1_TITLE")
		target_text = tr("BADUSB_STORY_1_TEXT")
		_img_story.texture = preload("res://assets/sprites/placeholder/storyImages/elevator_img.png")

	elif _story_step == 2:
		_lbl_title.text = tr("BADUSB_STORY_2_TITLE")
		target_text = tr("BADUSB_STORY_2_TEXT")
		_img_story.texture = preload("res://assets/sprites/placeholder/storyImages/door_img.png")

	elif _story_step == 3:
		_lbl_title.text = tr("BADUSB_STORY_3_TITLE")
		target_text = tr("BADUSB_STORY_3_TEXT")
		_img_story.texture = preload("res://assets/sprites/placeholder/storyImages/pc_img.png")

	elif _story_step == 4:
		_lbl_title.text = tr("BADUSB_STORY_4_TITLE")
		target_text = tr("BADUSB_STORY_4_TEXT")
		
	_lbl_story.text = target_text
	_lbl_story.visible_characters = 0
	
	var total_time = target_text.length() * _typewriter_speed
	SfxPlayer.start_typing()
	var tween = create_tween()
	tween.tween_property(_lbl_story, "visible_characters", target_text.length(), total_time)

	tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	SfxPlayer.stop_typing()
	if _story_step < 4:
		_img_story.visible = true 
	
	if _story_step >= 4:
		_btn_next.visible = false
		_btn_finish.visible = true
	else:
		_btn_next.visible = true
		_btn_finish.visible = false

func _on_next_pressed() -> void:
	_story_step += 1
	_play_story_step()

func _on_finish_pressed() -> void:
	complete_scenario()
	SceneTransition.change_scene("res://scenes/levelAuswahl.tscn")
