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
@onready var _lbl_failure = $BadUSBScenario/CanvasLayer/FailurePopup/Label

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

# --- telemetry ---------------------------------------------------------------
# The study evaluates decisions, error rates and decision times. The dialogue
# tree encodes correctness positionally: on the opening step of each path the
# first option blows the cover, on the follow-up step the second one does. These
# two tables are the single source of truth for grading, so a content change
# only has to be reflected here.
const FAIL_ON_CHOICE_1: Array[int] = [10, 20, 30]
const FAIL_ON_CHOICE_2: Array[int] = [11, 21, 31]

const PromptClock := preload("res://scenarios/base/prompt_clock.gd")
const Typewriter := preload("res://scenarios/base/typewriter.gd")
const Style := preload("res://scenarios/bad_usb/bad_usb_style.gd")

# _dialogue_step / 10 -> which social-engineering approach the player is on.
const DIALOGUE_PATHS: Dictionary = {
	1: "stressed",
	2: "confident",
	3: "office_npc",
}

var _clock: PromptClock = PromptClock.new()
# Blown covers so far. Every failure resets the player to the building entrance,
# so this doubles as the retry counter for the run.
var _failure_count: int = 0
# Dead-end attempts at the badge-protected elevator. Not a cover blower, but a
# wrong turn worth counting for the usability analysis.
var _restricted_attempts: int = 0
# Pretext the player last opened the reception conversation with.
var _reception_path: String = ""

# --- flowing text -------------------------------------------------------------
# Two typewriters because the two screens differ in what happens when a line
# lands: the dialogue reveals its choices, the debrief reveals its image and
# Weiter button. One shared instance would have to disambiguate that in its
# handler.
var _dialogue_typer := Typewriter.new()
var _story_typer := Typewriter.new()
# Whether the step currently on screen offers a second option, remembered while
# both choices are hidden during typing.
var _second_choice_offered: bool = true

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

	_style_ui()

	_dialogue_typer.finished.connect(_on_line_typed)
	_story_typer.finished.connect(_on_typing_finished)


func _process(delta: float) -> void:
	_dialogue_typer.advance(delta)
	_story_typer.advance(delta)


# Click reveals the rest of the current line at once, the same affordance the
# intro's dialog box offers. Handled in _unhandled_input so a click that lands
# on a button (a choice, Weiter) is consumed by that button first and never
# swallowed here; the input is only marked handled while text is actually
# running, so world interaction is untouched otherwise.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event
	if button_event.button_index != MOUSE_BUTTON_LEFT or not button_event.pressed:
		return
	if _dialogue_typer.is_typing():
		_dialogue_typer.finish_now()
		get_viewport().set_input_as_handled()
	elif _story_typer.is_typing():
		_story_typer.finish_now()
		get_viewport().set_input_as_handled()


# Puts the level into the DarkMail terminal look of scenario 1. Explicit lists
# rather than a tree walk on purpose: the briefing is an instanced scene that
# styles itself and must not be restyled from here.
func _style_ui() -> void:
	for button: Button in [
		_ui_enter_btn,
		_btn_stressed, _btn_confident,
		_btn_failure_ok,
		_ui_corridor_btn, _ui_office_btn, _btn_restricted_elevator,
		_ui_usb_btn,
		_btn_next, _btn_finish,
		_btn_tailgate_trigger, _btn_tailgate_enter,
	]:
		Style.style_button(button)

	# The choices wrap inside a fixed column; left to itself a Button demands the
	# width of its whole line, which pushed them past the dialogue box edges.
	for choice: Button in [_btn_choice1, _btn_choice2]:
		Style.style_choice(choice)
	Style.layout_choice_column(_ui_dialogue_box.get_node("VBoxContainer"))

	Style.style_panel(_ui_dialogue_box)
	Style.style_panel(_ui_missing_badge)
	Style.style_panel(_ui_npc_speech)
	Style.style_panel(_ui_tailgate_locked)
	Style.style_panel(_ui_failure_popup)

	Style.replace_backdrop(_ui_resolve, _ui_resolve.get_node("ColorRect"))

	Style.style_body(_lbl_npc_text)
	Style.style_body(_lbl_failure)
	Style.style_body(_lbl_story)
	Style.style_heading(_lbl_title)
	Style.style_body(_ui_missing_badge.get_node("MissingBadgeUI"))
	Style.style_body(_ui_tailgate_locked.get_node("MissingBadgeUI"))
	Style.style_body(_ui_npc_speech.get_node("NPCSpeechUI"))

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
		_clock.mark()
		_front_door_pos = body.position

func _on_entrance_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_enter_btn.visible = false

func _on_enter_button_pressed() -> void:
	EventBus.emit_action(scenario_id, "enter_building", _clock.take())
	_ui_enter_btn.visible = false
	_world_inside.get_node("Player").position = _inside_start_pos
	_change_substate(SubState.INSIDE)

func _on_corridor_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_corridor_btn.visible = true
		_clock.mark()

func _on_corridor_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_corridor_btn.visible = false

func _on_corridor_btn_pressed() -> void:
	EventBus.emit_action(scenario_id, "enter_corridor", _clock.take())
	_ui_corridor_btn.visible = false
	_change_substate(SubState.CORRIDOR)

func _on_locked_door_entered(body: Node2D) -> void:
	if body.name == "Player":
		if not _tailgate_event_triggered:
			_btn_tailgate_trigger.visible = true
			_clock.mark()
		elif _sprite_open_door.visible:
			_btn_tailgate_enter.visible = true
			_clock.mark()

func _on_locked_door_exited(body: Node2D) -> void:
	if body.name == "Player":
		_btn_tailgate_trigger.visible = false
		_btn_tailgate_enter.visible = false 
		_ui_tailgate_locked.visible = false

func _on_tailgate_trigger_pressed() -> void:
	# Waiting at the locked door for someone with a badge is the tailgating
	# technique this level teaches, so it is graded as the intended move.
	EventBus.emit_decision(scenario_id, "tailgate_wait", true, _clock.take())
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
	_clock.mark()

func _on_tailgate_enter_pressed() -> void:
	EventBus.emit_decision(scenario_id, "tailgate_through_door", true, _clock.take())
	_btn_tailgate_enter.visible = false
	_change_substate(SubState.OFFICE)

func _on_restricted_entered(body: Node2D) -> void:
	if body.name == "Player":
		_btn_restricted_elevator.visible = true
		_clock.mark()

func _on_restricted_exited(body: Node2D) -> void:
	if body.name == "Player":
		_btn_restricted_elevator.visible = false
		_ui_missing_badge.visible = false

func _on_restricted_btn_pressed() -> void:
	# The badge-protected elevator is a dead end. Taking it is not fatal, but it
	# is the wrong route, so it counts against the error rate.
	_restricted_attempts += 1
	EventBus.emit_decision(
		scenario_id,
		"restricted_elevator_attempt",
		false,
		_clock.take(),
		{"attempt": _restricted_attempts},
	)
	_btn_restricted_elevator.visible = false
	_ui_missing_badge.visible = true

func _on_npc_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_npc_speech.visible = true
		_ui_office_btn.visible = true
		_clock.mark()

func _on_npc_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_npc_speech.visible = false
		_ui_office_btn.visible = false

func _on_office_btn_pressed() -> void:
	EventBus.emit_action(scenario_id, "leave_elevator_area", _clock.take())
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
			_clock.mark()

func _on_pc_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_usb_btn.visible = false
		_ui_dialogue_box.visible = false

func _on_usb_btn_pressed() -> void:
	# Planting the drive is the objective of the level: the attack succeeded.
	EventBus.emit_decision(scenario_id, "usb_inserted", true, _clock.take())
	_ui_usb_btn.visible = false
	_change_substate(SubState.RESOLVE)

func _on_reception_entered(body: Node2D) -> void:
	if body.name == "Player":
		_ui_reception_menu.visible = true
		_clock.mark()

func _on_reception_exited(body: Node2D) -> void:
	if body.name == "Player":
		_ui_reception_menu.visible = false

func _on_stressed_pressed() -> void:
	_start_reception_dialogue(10)

func _on_confident_pressed() -> void:
	_start_reception_dialogue(20)

# Both openings are viable pretexts rather than a right/wrong pair, so the
# choice is recorded ungraded. Which one a player reaches for is still one of
# the more interesting behavioural signals in this level.
func _start_reception_dialogue(step: int) -> void:
	_reception_path = DIALOGUE_PATHS.get(step / 10, "unknown")
	EventBus.emit_action(
		scenario_id,
		"reception_approach",
		_clock.take(),
		{"path": _reception_path},
	)
	_ui_reception_menu.visible = false
	_ui_dialogue_box.visible = true
	_dialogue_step = step
	_update_dialogue_ui()
	
	var player = _world_inside.get_node("Player")
	player.set_physics_process(false)
	player.get_node("AnimatedSprite2D").play("idle")

func _on_dialog_choice_1_pressed() -> void:
	_log_dialogue_choice(1)
	match _dialogue_step:
		11, 21, 31:
			_dialogue_step += 1
			_update_dialogue_ui()
		12, 22:
			_ui_dialogue_box.visible = false
			_barrier_shape.disabled = true
			# The reception dialogue froze the player; release them again now
			# that the barrier is open.
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
	_log_dialogue_choice(2)
	match _dialogue_step:
		10, 20, 30:
			_dialogue_step += 1
			_update_dialogue_ui()
		11, 21, 31:
			_ui_dialogue_box.visible = false
			_ui_failure_popup.visible = true

# Grades and records the answer for the step the player is currently on. MUST
# run before the handlers touch _dialogue_step, otherwise the event lands on the
# following step and the graded outcome no longer matches the question asked.
func _log_dialogue_choice(choice: int) -> void:
	var blows_cover: bool = (
		FAIL_ON_CHOICE_1.has(_dialogue_step)
		if choice == 1
		else FAIL_ON_CHOICE_2.has(_dialogue_step)
	)
	EventBus.emit_decision(
		scenario_id,
		"dialogue_choice",
		not blows_cover,
		_clock.take(),
		{
			"step": _dialogue_step,
			"choice": choice,
			"path": DIALOGUE_PATHS.get(_dialogue_step / 10, "unknown"),
			"attempt": _failure_count + 1,
		},
	)
	if blows_cover:
		_failure_count += 1

func _on_failure_ok_pressed() -> void:
	# The player was thrown back to the entrance and is starting over. Recorded
	# separately from the failing answer so a run's retries can be counted
	# without re-deriving them from the decision stream.
	EventBus.emit_action(
		scenario_id,
		"retry_after_failure",
		PromptClock.UNKNOWN,
		{"failures_so_far": _failure_count},
	)
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

# One row per run for the study's summary table, mirroring the scenario_debrief
# that spear_phishing emits from its resolve screen. The level has no losing
# end state (a blown cover sends the player back to try again), so the outcome
# is fixed and the interesting variance sits in the retry and detour counters.
func _on_complete() -> void:
	EventBus.generic_event.emit({
		"phase": "scenario_debrief",
		"scenario_id": scenario_id,
		"action": "USB_PLANTED",
		"is_correct": true,
		"latency_ms": null,
		"payload": {
			"outcome": "USB_PLANTED",
			"failures": _failure_count,
			"restricted_attempts": _restricted_attempts,
			"reception_path": _reception_path,
		},
	})

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

	# The match above decided whether this step offers a second option. Hold both
	# back while the line types itself out, so the player reads the question
	# before the answers appear, then restore that decision in _on_line_typed.
	_second_choice_offered = _btn_choice2.visible
	_btn_choice1.visible = false
	_btn_choice2.visible = false
	SfxPlayer.start_typing()
	_dialogue_typer.start(_lbl_npc_text, _lbl_npc_text.text)


func _on_line_typed() -> void:
	SfxPlayer.stop_typing()
	_btn_choice1.visible = true
	_btn_choice2.visible = _second_choice_offered
	# Decision time starts when the options actually become clickable. Marking it
	# when the line starts typing would fold the typewriter duration into every
	# recorded latency and make fast readers look slow.
	_clock.mark()

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
		
	SfxPlayer.start_typing()
	_story_typer.start(_lbl_story, target_text, 1.0 / _typewriter_speed)

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

	# Text fully revealed: from here on the player is reading, not waiting for
	# the typewriter. That interval is the debrief dwell time.
	_clock.mark()

func _on_next_pressed() -> void:
	EventBus.emit_action(
		scenario_id,
		"debrief_advanced",
		_clock.take(),
		{"story_step": _story_step},
	)
	_story_step += 1
	_play_story_step()

func _on_finish_pressed() -> void:
	EventBus.emit_action(
		scenario_id,
		"debrief_advanced",
		_clock.take(),
		{"story_step": _story_step},
	)
	complete_scenario()
	SceneTransition.change_scene("res://scenes/levelAuswahl.tscn")
