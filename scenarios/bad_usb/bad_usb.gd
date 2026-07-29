extends ScenarioBase

const SCENARIO_ID: String = "bad_usb"
const HOME_SCENE: String = "res://scenes/StartScreen.tscn"
const LEVELS_SCENE: String = "res://scenes/levelAuswahl.tscn"

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

# --- telemetry ---------------------------------------------------------------
# The study evaluates decisions, error rates and decision times. Which answer is
# right, and which pretext a step belongs to, lives in dialogue.gd next to the
# lines themselves.

const PromptClock := preload("res://scenarios/base/prompt_clock.gd")
const Typewriter := preload("res://scenarios/base/typewriter.gd")
const SkipHint := preload("res://scenarios/base/skip_hint.gd")
const Style := preload("res://scenarios/bad_usb/bad_usb_style.gd")
const Debrief := preload("res://scenarios/bad_usb/debrief.gd")
const Dialogue := preload("res://scenarios/bad_usb/dialogue.gd")
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")

# Reused from scenario 1's Recon phase. One continuous track across every
# playable phase, hung off a dedicated holder rather than the world nodes:
# ScreenMusic follows its parent's visibility, so swapping worlds would restart
# it at every doorway.
const WORLD_MUSIC := preload("res://assets/audio/terminal_stalk.wav")
# Every change of location fades through black; without it the worlds snap over
# each other. SceneTransition swallows input during the fade.

# --- OS shell -----------------------------------------------------------------
# The eight sub-states are too fine-grained for a stepper, so they are grouped
# into five. BRIEFING maps to nothing, as in scenario 1.
const OS_CHROME_SCENE := "res://scenarios/base/components/OSChrome.tscn"
const BRIEFING_RESOURCE := "res://resources/scenarios/bad_usb/briefing.tres"

# The bar belongs to the terminal screens; over the pixel-art world it reads as
# a foreign overlay. Scenario 1 keeps it up throughout because every one of its
# phases IS such a screen.
const CHROME_SUBSTATES: Array[int] = [SubState.BRIEFING, SubState.RESOLVE]

const PHASE_BY_SUBSTATE: Dictionary = {
	SubState.STREET: &"ARRIVAL",
	SubState.FRONT: &"ARRIVAL",
	SubState.INSIDE: &"LOBBY",
	SubState.CORRIDOR: &"FLOOR",
	SubState.TAILGATE: &"FLOOR",
	SubState.OFFICE: &"OFFICE",
	SubState.RESOLVE: &"DEBRIEF",
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
# True once a blown cover has ended the run. Decides both which debrief is shown
# and which outcome the study data records, so a failed run can never be
# reported as a planted stick.
var _run_failed: bool = false

# --- flowing text -------------------------------------------------------------
var _dialogue_typer := Typewriter.new()
# "▼ klicken für weiter", shown only while the question is still running.
var _dialogue_hint: Label
# The closing screen, built on demand when the level reaches RESOLVE.
var _debrief: Control
# The shared DarkMail OS bar, instanced in _setup.
var _os_chrome: Control
# Invisible holder whose visibility drives the world music: shown exactly while
# the player is in a playable phase.
var _world_music_host: Control
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
	
	# Left in the scene but never shown: the fail screen replaced it.
	_ui_failure_popup.visible = false
	
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
	_setup_os_chrome()
	_setup_world_music()

	_dialogue_typer.finished.connect(_on_line_typed)


func _process(delta: float) -> void:
	_dialogue_typer.advance(delta)


# Click reveals the rest of the line, as in the intro. In _unhandled_input so a
# click on a button is consumed by that button first, and only marked handled
# while text is running.
#
# Catches clicks OUTSIDE the boxes only: the panels have mouse_filter STOP and
# swallow their own clicks, which _on_dialogue_box_clicked handles.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	if _skip_running_text():
		get_viewport().set_input_as_handled()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var button_event: InputEventMouseButton = event
	return button_event.button_index == MOUSE_BUTTON_LEFT and button_event.pressed


# True if a click actually had text to hurry along.
func _skip_running_text() -> bool:
	if _dialogue_typer.is_typing():
		_dialogue_typer.finish_now()
		return true
	return false


# The whole speech box is the click target, not just the hint in its corner.
func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if _is_left_click(event):
		_skip_running_text()



# Puts the level into the DarkMail terminal look of scenario 1. Explicit lists
# rather than a tree walk on purpose: the briefing is an instanced scene that
# styles itself and must not be restyled from here.
func _style_ui() -> void:
	for button: Button in [
		_ui_enter_btn,
		_btn_stressed, _btn_confident,
		_ui_corridor_btn, _ui_office_btn, _btn_restricted_elevator,
		_ui_usb_btn,
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

	_dialogue_hint = SkipHint.new()
	Style.place_skip_hint(_dialogue_hint, _ui_dialogue_box)
	_dialogue_hint.set_active(false)
	# The whole speech box is the click target, not just the hint in its corner.
	# The panel has mouse_filter STOP, so the click never reaches
	# _unhandled_input and has to be taken here.
	if not _ui_dialogue_box.gui_input.is_connected(_on_dialogue_box_clicked):
		_ui_dialogue_box.gui_input.connect(_on_dialogue_box_clicked)

	Style.style_body(_lbl_npc_text)
	Style.style_body(_ui_missing_badge.get_node("MissingBadgeUI"))
	Style.style_body(_ui_tailgate_locked.get_node("MissingBadgeUI"))
	Style.style_body(_ui_npc_speech.get_node("NPCSpeechUI"))

# The same OS bar scenario 1 runs under. Instanced in code so bad_usb.tscn stays
# untouched. The briefing resource carries turn_budget = 0, so OSChrome hides its
# counter.
func _setup_os_chrome() -> void:
	var briefing := load(BRIEFING_RESOURCE) as BriefingResource
	if briefing == null:
		push_error("%s: failed to load %s" % [SCENARIO_ID, BRIEFING_RESOURCE])
		return
	_os_chrome = (load(OS_CHROME_SCENE) as PackedScene).instantiate()
	$BadUSBScenario/CanvasLayer.add_child(_os_chrome)
	# Stays in front: the briefing and the debrief both cover the whole screen,
	# and the bar is meant to frame them, not to disappear behind them.
	_keep_chrome_on_top()
	var steps: Array[Dictionary] = [
		{"id": &"ARRIVAL", "label": tr("BADUSB_PHASE_ARRIVAL")},
		{"id": &"LOBBY", "label": tr("BADUSB_PHASE_LOBBY")},
		{"id": &"FLOOR", "label": tr("BADUSB_PHASE_FLOOR")},
		{"id": &"OFFICE", "label": tr("BADUSB_PHASE_OFFICE")},
		{"id": &"DEBRIEF", "label": tr("BADUSB_PHASE_DEBRIEF")},
	]
	_os_chrome.configure(briefing, steps)


# One row per run for the study's summary table, mirroring the scenario_debrief
# that spear_phishing emits from its resolve screen. Fires once, when the
# debrief is built.
func _emit_debrief() -> void:
	var outcome: String = "COVER_BLOWN" if _run_failed else "USB_PLANTED"
	EventBus.generic_event.emit({
		"phase": "scenario_debrief",
		"scenario_id": scenario_id,
		"action": outcome,
		"is_correct": not _run_failed,
		"latency_ms": null,
		"payload": {
			"outcome": outcome,
			"failures": _failure_count,
			"restricted_attempts": _restricted_attempts,
			"reception_path": _reception_path,
		},
	})


# The briefing and the debrief bring their own track, so the world bed follows
# the inverse of the OS bar's rule.
func _setup_world_music() -> void:
	_world_music_host = Control.new()
	_world_music_host.name = "WorldMusicHost"
	_world_music_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_music_host.visible = false
	$BadUSBScenario/CanvasLayer.add_child(_world_music_host)
	var music := ScreenMusic.new()
	music.track = WORLD_MUSIC
	_world_music_host.add_child(music)


func _keep_chrome_on_top() -> void:
	if _os_chrome != null and is_instance_valid(_os_chrome):
		$BadUSBScenario/CanvasLayer.move_child(_os_chrome, -1)


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
	# A replay drops straight into the street: the player has just read the
	# briefing and sitting through it again is pure friction. Same one-shot flag
	# scenario 1 uses, consumed here.
	if GameState.replay_skip_briefing:
		GameState.replay_skip_briefing = false
		_change_substate(SubState.STREET)
	else:
		_change_substate(SubState.BRIEFING)

func _on_door_entered(body: Node2D) -> void:
	if body.name == "Player":
		SceneTransition.flash(_change_substate.bind(SubState.FRONT))

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
	SceneTransition.flash(_change_substate.bind(SubState.INSIDE))

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
	SceneTransition.flash(_change_substate.bind(SubState.CORRIDOR))

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
	SceneTransition.flash(_change_substate.bind(SubState.OFFICE))

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
	SceneTransition.flash(_change_substate.bind(SubState.TAILGATE))

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
	SceneTransition.flash(_change_substate.bind(SubState.RESOLVE))

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
	_reception_path = Dialogue.path_for(step)
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
			_fail_run()

func _on_dialog_choice_2_pressed() -> void:
	_log_dialogue_choice(2)
	match _dialogue_step:
		10, 20, 30:
			_dialogue_step += 1
			_update_dialogue_ui()
		11, 21, 31:
			_fail_run()

# Grades and records the answer for the step the player is currently on. MUST
# run before the handlers touch _dialogue_step, otherwise the event lands on the
# following step and the graded outcome no longer matches the question asked.
func _log_dialogue_choice(choice: int) -> void:
	var blows_cover: bool = Dialogue.blows_cover(_dialogue_step, choice)
	EventBus.emit_decision(
		scenario_id,
		"dialogue_choice",
		not blows_cover,
		_clock.take(),
		{
			"step": _dialogue_step,
			"choice": choice,
			"path": Dialogue.path_for(_dialogue_step),
			"attempt": _failure_count + 1,
		},
	)
	if blows_cover:
		_failure_count += 1

# A blown cover ends the run and goes straight to the fail screen, like a losing
# outcome in scenario 1. Back in via "Nochmal spielen", which reloads the level.
#
# BADUSB_FAILURE_TEXT, formerly the popup notice, now opens that screen. The
# in-run reset to the entrance is gone with the popup: a reload rebuilds it, and
# a run now has exactly one outcome instead of silent retries.
func _fail_run() -> void:
	_run_failed = true
	EventBus.emit_action(
		scenario_id,
		"run_failed",
		PromptClock.UNKNOWN,
		{"at_step": _dialogue_step, "path": _reception_path},
	)
	_ui_dialogue_box.visible = false
	_dialogue_step = 0
	SceneTransition.flash(_change_substate.bind(SubState.RESOLVE))

func _on_action(_action_id: String) -> void:
	pass

# The base class owns scenario_complete; the run's summary row is emitted when
# the debrief screen appears (see _emit_debrief), not here. That mirrors
# scenario 1 and means one row exists as soon as the player reached the end of
# the level, whether or not they then clicked an exit.
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
			# The scene's own Resolve node stays hidden: the debrief is built by
			# the Debrief component instead, which owns its own full-screen
			# layout. The node is left in the scene so the level file keeps
			# working in the editor.
			# A blown cover must not end on the success chime.
			if _run_failed:
				SfxPlayer.play_fail()
			else:
				SfxPlayer.play_completion()
			_start_resolve_story()

	_current = new_state
	_initialised = true

	# Drive the OS bar's phase stepper; ids match the configure() steps.
	GameState.set_mission_phase(PHASE_BY_SUBSTATE.get(new_state, &""))
	var on_terminal_screen: bool = CHROME_SUBSTATES.has(new_state)
	if _os_chrome != null and is_instance_valid(_os_chrome):
		_os_chrome.visible = on_terminal_screen
	if _world_music_host != null and is_instance_valid(_world_music_host):
		_world_music_host.visible = not on_terminal_screen

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
	if not Dialogue.has_step(_dialogue_step):
		push_error("%s: no dialogue for step %d" % [SCENARIO_ID, _dialogue_step])
		return
	_lbl_npc_text.text = tr(Dialogue.npc_key(_dialogue_step))
	_btn_choice1.text = tr(Dialogue.choice_key(_dialogue_step, 1))
	_second_choice_offered = Dialogue.offers_second_choice(_dialogue_step)
	if _second_choice_offered:
		_btn_choice2.text = tr(Dialogue.choice_key(_dialogue_step, 2))

	# Hold both answers back while the question types itself out, so the player
	# reads it before answering; _on_line_typed restores the decision above.
	_btn_choice1.visible = false
	_btn_choice2.visible = false
	SfxPlayer.start_typing()
	_dialogue_hint.set_active(true)
	_dialogue_typer.start(_lbl_npc_text, _lbl_npc_text.text)


func _on_line_typed() -> void:
	SfxPlayer.stop_typing()
	_dialogue_hint.set_active(false)
	_btn_choice1.visible = true
	_btn_choice2.visible = _second_choice_offered
	# Decision time starts when the options actually become clickable. Marking it
	# when the line starts typing would fold the typewriter duration into every
	# recorded latency and make fast readers look slow.
	_clock.mark()

# --- debrief ------------------------------------------------------------------

# Two sets, because the success stages describe things a failed run never did
# ("Du konntest den eingeschraenkten Bereich betreten").
const DEBRIEF_STAGES_SUCCESS: Array[Dictionary] = [
	{"title": "BADUSB_STORY_0_TITLE", "text": "BADUSB_STORY_0_TEXT",
		"image": "res://assets/sprites/placeholder/storyImages/lobby_img.png"},
	{"title": "BADUSB_STORY_1_TITLE", "text": "BADUSB_STORY_1_TEXT",
		"image": "res://assets/sprites/placeholder/storyImages/elevator_img.png"},
	{"title": "BADUSB_STORY_2_TITLE", "text": "BADUSB_STORY_2_TEXT",
		"image": "res://assets/sprites/placeholder/storyImages/door_img.png"},
	{"title": "BADUSB_STORY_3_TITLE", "text": "BADUSB_STORY_3_TEXT",
		"image": "res://assets/sprites/placeholder/storyImages/pc_img.png"},
	{"title": "BADUSB_STORY_4_TITLE", "text": "BADUSB_STORY_4_TEXT", "image": ""},
]

# Shorter on purpose: the run ended at the first checkpoint. Opens with
# BADUSB_FAILURE_TEXT, the notice the popup used to carry.
const DEBRIEF_STAGES_FAILED: Array[Dictionary] = [
	{"title": "BADUSB_FAIL_0_TITLE", "text": "BADUSB_FAILURE_TEXT",
		"image": "res://assets/sprites/placeholder/storyImages/lobby_img.png"},
	{"title": "BADUSB_FAIL_1_TITLE", "text": "BADUSB_FAIL_1_TEXT", "image": ""},
]

const FAIL_ACCENT: Color = DarkMailPalette.ALERT_RED


func _start_resolve_story() -> void:
	if _debrief != null:
		return
	_debrief = Debrief.new()
	_debrief.stage_advanced.connect(_on_debrief_stage_advanced)
	_debrief.levels_requested.connect(_on_debrief_levels)
	_debrief.home_requested.connect(_on_debrief_home)
	_debrief.replay_requested.connect(_on_debrief_replay)
	$BadUSBScenario/CanvasLayer.add_child(_debrief)
	_keep_chrome_on_top()

	_emit_debrief()

	var source: Array = DEBRIEF_STAGES_FAILED if _run_failed else DEBRIEF_STAGES_SUCCESS
	var stages: Array = []
	for stage in source:
		var image_path: String = stage["image"]
		stages.append({
			"title": tr(stage["title"]),
			"text": tr(stage["text"]),
			"image": load(image_path) if not image_path.is_empty() else null,
		})
	_debrief.configure(
		stages, FAIL_ACCENT if _run_failed else DarkMailPalette.GREEN)


# How long each debrief stage stood finished on screen before the player moved
# on. Research question 3 is about whether the feedback lands, and this is the
# only signal we have for whether it was read at all.
func _on_debrief_stage_advanced(index: int, dwell_ms: int) -> void:
	EventBus.emit_action(
		scenario_id,
		"debrief_advanced",
		dwell_ms,
		{"story_step": index},
	)


func _on_debrief_levels() -> void:
	complete_scenario()
	SceneTransition.change_scene(LEVELS_SCENE)


func _on_debrief_home() -> void:
	complete_scenario()
	SceneTransition.change_scene(HOME_SCENE)


# Wipes the per-run handoff state (autoloads survive a scene reload) and loads
# the level again, mirroring how scenario 1 handles its retry.
func _on_debrief_replay() -> void:
	complete_scenario()
	GameState.reset_scenario()
	GameState.replay_skip_briefing = true
	var cfg: ScenarioConfig = Config.get_scenario(StringName(SCENARIO_ID))
	if cfg == null:
		push_error("%s: cannot replay, scenario missing from Config" % SCENARIO_ID)
		return
	SceneTransition.change_scene(cfg.scene_path)
