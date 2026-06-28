extends ScenarioBase

const SCENARIO_ID: String = "bad_usb"

enum SubState { BRIEFING, STREET, FRONT, INSIDE, RESOLVE }

@onready var _ui_briefing = $BadUSBScenario/CanvasLayer/Briefing
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


var _dialogue_step: int = 0
var _inside_start_pos: Vector2
var _front_door_pos: Vector2
var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	_barrier_shape.disabled = false 
	_ui_briefing.visible = false
	_ui_resolve.visible = false
	_ui_enter_btn.visible = false
	_ui_reception_menu.visible = false 
	
	_world_street.visible = false
	_world_street.process_mode = Node.PROCESS_MODE_DISABLED
	_world_front.visible = false
	_world_front.process_mode = Node.PROCESS_MODE_DISABLED
	_world_inside.visible = false
	_world_inside.process_mode = Node.PROCESS_MODE_DISABLED
	
	_ui_briefing.advance_requested.connect(_advance)
	_ui_resolve.advance_requested.connect(_advance)
	
	# Street to Front Door
	var door = $BadUSBScenario/GameWorld/Area2D
	door.body_entered.connect(_on_door_entered)
	
	# Entrance Interaction Zone
	var entrance_zone = $BadUSBScenario/InfrontOfBuilding/BuildingEntrance
	entrance_zone.body_entered.connect(_on_entrance_entered)
	entrance_zone.body_exited.connect(_on_entrance_exited)
	
	_ui_enter_btn.pressed.connect(_on_enter_button_pressed)
	
	var reception_zone = $BadUSBScenario/InsideBuilding/ReceptionZone
	reception_zone.body_entered.connect(_on_reception_entered)
	reception_zone.body_exited.connect(_on_reception_exited)
	
	_btn_stressed.pressed.connect(_on_stressed_pressed)
	_btn_confident.pressed.connect(_on_confident_pressed)
	
	_ui_dialogue_box.visible = false
	_btn_choice1.pressed.connect(_on_dialog_choice_1_pressed)
	_btn_choice2.pressed.connect(_on_dialog_choice_2_pressed)
	
	_ui_failure_popup.visible = false
	_btn_failure_ok.pressed.connect(_on_failure_ok_pressed)
	
	_ui_dialogue_box.visible = false
	_btn_choice1.pressed.connect(_on_dialog_choice_1_pressed)
	_btn_choice2.pressed.connect(_on_dialog_choice_2_pressed)
	
	_ui_failure_popup.visible = false
	_btn_failure_ok.pressed.connect(_on_failure_ok_pressed)
	
	_inside_start_pos = _world_inside.get_node("Player").position

func _on_start() -> void:
	#_change_substate(SubState.BRIEFING)
	_change_substate(SubState.INSIDE)

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

func _on_confident_pressed() -> void:
	_ui_reception_menu.visible = false
	_ui_dialogue_box.visible = true
	_dialogue_step = 20
	_update_dialogue_ui()

func _on_dialog_choice_1_pressed() -> void:
	if _dialogue_step == 10 or _dialogue_step == 20:
		_dialogue_step += 1
		_update_dialogue_ui()
	elif _dialogue_step == 11 or _dialogue_step == 21:
		_dialogue_step += 1
		_update_dialogue_ui()
	elif _dialogue_step == 12 or _dialogue_step == 22:
		print("SUCCESS! Player knows to go to the 2nd Floor!")
		_ui_dialogue_box.visible = false
		
		_barrier_shape.disabled = true

func _on_dialog_choice_2_pressed() -> void:
	# Choice 2 is the WRONG choice
	_ui_dialogue_box.visible = false
	_ui_failure_popup.visible = true

func _on_failure_ok_pressed() -> void:
	_ui_failure_popup.visible = false
	
	_dialogue_step = 0
	
	_world_front.get_node("Player").position = _front_door_pos
	
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
			_change_substate(SubState.INSIDE)
		SubState.INSIDE:
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
				_world_street.process_mode = Node.PROCESS_MODE_DISABLED
			SubState.FRONT:
				_world_front.visible = false
				_world_front.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_enter_btn.visible = false
			SubState.INSIDE:
				_world_inside.visible = false
				_world_inside.process_mode = Node.PROCESS_MODE_DISABLED
				_ui_reception_menu.visible = false
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
	
func _update_dialogue_ui() -> void:
	_btn_choice2.visible = true
	
	match _dialogue_step:
		10: # Stressed - Part 1
			_lbl_npc_text.text = "Guten Tag, kann ich Ihnen helfen? Sie wirken völlig außer Atem!"
			_btn_choice1.text = "Ich bin zu spät für mein Meeting!"
			_btn_choice2.text = "Wo sind hier die Computer? Lassen Sie mich durch!"
		11: # Stressed - Part 2
			_lbl_npc_text.text = "Oh je, beruhigen Sie sich. Mit wem haben Sie das Meeting denn?"
			_btn_choice1.text = "Herr Müller! Dritter Stock, richtig?"
			_btn_choice2.text = "Das geht Sie nichts an!"
		12: # Stressed - Part 3
			_lbl_npc_text.text = "Nein die Meetingräume sind im zweiten Stock! Beeilen Sie sich."
			_btn_choice1.text = "Vielen Dank"
			_btn_choice2.visible = false
			
		20: # Confident - Part 1
			_lbl_npc_text.text = "Guten Tag. Haben Sie einen Termin? Sie tragen keinen Besucherausweis."
			_btn_choice1.text = "Ja, externes IT-Audit. Ich soll ein kritisches Update durchführen."
			_btn_choice2.text = "Ich bin der neue Chef. Hat man Sie nicht informiert?"
		21: # Confident - Part 2
			_lbl_npc_text.text = "Ein Update? Haben Sie eine Bestätigung?"
			_btn_choice1.text = "Ihr Kollege hat mich hier her bestellt... Ich denke er hat Sie informiert?"
			_btn_choice2.text = "Hab ich vergessen. Darf ich trotzdem rein?"
		22: # Confident - Part 3
			_lbl_npc_text.text = "Uhm... Doch alles klar es ist alles korrekt so."
			_btn_choice1.text = "Vielen Dank"
			_btn_choice2.visible = false
