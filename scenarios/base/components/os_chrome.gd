# Scenario-independent DarkMail OS shell: a two-line HUD pinned to the top of
# every scenario phase.
#
#   Line 1 (status):  DarkMail OS · <target> · ● SECURE · HH:MM
#   Line 2 (mission): [MISSION] <goal>   Recon ▸ Mail ▸ Resolve   ZÜGE n/m
#
# Single source of truth, nothing hardcoded here:
#   - goal text, target name, reward and turn budget come from the
#     BriefingResource passed to configure(),
#   - the active phase and the live turn count come from the GameState
#     autoload (mission_phase_changed / mission_turns_changed), which the
#     scenario shell drives from its existing advance_requested routing.
#
# Clicking the MISSION tag re-opens the full briefing as a dossier overlay.
# Purely presentational: this node never writes game state.
#
# Layout contract: the bar is 80px tall (34 + 46, set in OSChrome.tscn).
# Scenario scenes that instance this shell start their own content at
# y >= 96 (briefing.tscn ChannelWindow, recon.tscn Window) — keep those in
# sync if the bar height ever changes.
class_name OSChrome
extends Control

# Turn budget at or below this turns amber and starts the pulse; 0 turns red.
const LOW_TURNS_THRESHOLD := 2
# Font sizes stay on the Departure Mono 11px grid (see DarkMailPalette).
const FONT_SIZE_STATUS := DarkMailPalette.FONT_SIZE_MONO_SMALL
const FONT_SIZE_MISSION := DarkMailPalette.FONT_SIZE_MONO
const PULSE_INTERVAL := 0.6

var _briefing: BriefingResource
var _steps: Array[Dictionary] = []
# False for scenarios that run without a turn budget; set in configure().
var _shows_turns: bool = true
var _step_labels: Dictionary = {}  # id (StringName) -> Label
var _pulse_tween: Tween

@onready var _status_bar: PanelContainer = %StatusBar
@onready var _mission_bar: PanelContainer = %MissionBar
@onready var _target_label: Label = %TargetLabel
@onready var _secure_label: Label = %SecureLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _app_label: Label = %AppLabel
@onready var _mission_tag: Button = %MissionTag
@onready var _goal_label: Label = %GoalLabel
@onready var _stepper_row: HBoxContainer = %StepperRow
@onready var _turns_label: Label = %TurnsLabel
@onready var _dossier: Control = %Dossier
@onready var _dossier_panel: PanelContainer = %DossierPanel
@onready var _dossier_mission: Label = %DossierMission
@onready var _dossier_reward: Label = %DossierReward
@onready var _dossier_title: Label = %DossierTitle
@onready var _dossier_close: Label = %DossierClose


func _ready() -> void:
	_style_bars()
	GameState.mission_phase_changed.connect(_on_phase_changed)
	GameState.mission_turns_changed.connect(_on_turns_changed)
	_dossier.visible = false
	_mission_tag.pressed.connect(_toggle_dossier)
	_dossier.gui_input.connect(_on_dossier_input)
	(%ClockTimer as Timer).timeout.connect(_update_clock)
	_update_clock()
	_refresh_from_state()


# Called once by the scenario shell. briefing supplies the static mission
# facts; steps supplies the phase stepper as [{"id": StringName, "label":
# String}, ...] in play order (ids must match what the shell later passes to
# GameState.set_mission_phase for the highlight to track).
func configure(briefing: BriefingResource, steps: Array[Dictionary]) -> void:
	if briefing == null:
		push_error("OSChrome.configure: briefing is null")
		return
	_briefing = briefing
	_steps = steps.duplicate()
	# A scenario without a turn budget (bad_usb) has nothing to count down, and
	# an empty readout would sit there permanently at "0/0" in alert red. The
	# resource already carries the answer, the same way briefing.gd reads
	# reward_text to decide whether to show a reward line at all.
	_shows_turns = briefing.turn_budget > 0
	_turns_label.visible = _shows_turns
	_target_label.text = "" if briefing.target_name.is_empty() else "· %s" % tr(briefing.target_name)
	_goal_label.text = tr(briefing.mission_text)
	_dossier_mission.text = tr("BRIEFING_MISSION_LINE") % tr(briefing.mission_text)
	_dossier_reward.text = tr("BRIEFING_REWARD_LINE") % [tr(briefing.reward_text), briefing.turn_budget]
	_build_stepper()
	_refresh_from_state()


# --- styling -----------------------------------------------------------------

func _style_bars() -> void:
	_status_bar.add_theme_stylebox_override("panel", _bar_box(
		DarkMailPalette.BG_RAISED, Color(DarkMailPalette.GREEN, 0.35)))
	_mission_bar.add_theme_stylebox_override("panel", _bar_box(
		DarkMailPalette.BG_PANEL, Color(DarkMailPalette.GREEN, 0.55)))

	DarkMailPalette.apply_mono_label(_app_label, FONT_SIZE_STATUS, DarkMailPalette.GREEN)
	DarkMailPalette.apply_mono_label(_target_label, FONT_SIZE_STATUS, DarkMailPalette.TEXT_GREEN)
	DarkMailPalette.apply_mono_label(_secure_label, FONT_SIZE_STATUS, DarkMailPalette.GREEN)
	DarkMailPalette.apply_mono_label(_clock_label, FONT_SIZE_STATUS, DarkMailPalette.TEXT_GREEN)
	DarkMailPalette.apply_mono_label(_goal_label, FONT_SIZE_MISSION, DarkMailPalette.TEXT_GREEN)
	DarkMailPalette.apply_mono_label(_turns_label, FONT_SIZE_MISSION, DarkMailPalette.GREEN)

	_style_mission_tag()
	_style_dossier()


func _bar_box(bg: Color, underline: Color) -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(bg)
	sb.border_width_bottom = DarkMailPalette.BORDER_WIDTH
	sb.border_color = underline
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _style_mission_tag() -> void:
	var normal := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	var hover := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.22), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	for sb in [normal, hover]:
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
	_mission_tag.add_theme_stylebox_override("normal", normal)
	_mission_tag.add_theme_stylebox_override("hover", hover)
	_mission_tag.add_theme_stylebox_override("pressed", hover)
	_mission_tag.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_mission_tag.add_theme_font_override("font", DarkMailPalette.FONT_MONO)
	_mission_tag.add_theme_font_size_override("font_size", FONT_SIZE_MISSION)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_mission_tag.add_theme_color_override(state, DarkMailPalette.GREEN)


func _style_dossier() -> void:
	var panel := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	panel.content_margin_left = 32
	panel.content_margin_right = 32
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	_dossier_panel.add_theme_stylebox_override("panel", panel)
	DarkMailPalette.apply_mono_label(_dossier_title, FONT_SIZE_MISSION, DarkMailPalette.GREEN)
	DarkMailPalette.apply_mono_label(_dossier_mission, DarkMailPalette.FONT_SIZE_MONO_LARGE, DarkMailPalette.TEXT_GREEN)
	DarkMailPalette.apply_mono_label(_dossier_reward, FONT_SIZE_MISSION, DarkMailPalette.TEXT_GREEN)
	DarkMailPalette.apply_mono_label(_dossier_close, FONT_SIZE_STATUS, DarkMailPalette.TEXT_DIM)


# --- stepper -----------------------------------------------------------------

func _build_stepper() -> void:
	for child in _stepper_row.get_children():
		child.queue_free()
	_step_labels = {}
	_stepper_row.add_theme_constant_override("separation", 10)
	for i in _steps.size():
		if i > 0:
			var sep := Label.new()
			sep.text = "▸"
			sep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			DarkMailPalette.apply_mono_label(sep, FONT_SIZE_MISSION, DarkMailPalette.TEXT_DIM)
			_stepper_row.add_child(sep)
		var step: Dictionary = _steps[i]
		var label := Label.new()
		label.text = str(step.get("label", ""))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stepper_row.add_child(label)
		_step_labels[step.get("id", &"")] = label
	_highlight_step(GameState.mission_phase)


func _highlight_step(phase: StringName) -> void:
	for id: StringName in _step_labels:
		var label: Label = _step_labels[id]
		var active := id == phase
		DarkMailPalette.apply_mono_label(
			label,
			FONT_SIZE_MISSION,
			DarkMailPalette.GREEN_BRIGHT if active else DarkMailPalette.TEXT_DIM,
		)
		if active:
			var sb := DarkMailPalette.flat_box(DarkMailPalette.BG_FIELD)
			sb.border_width_bottom = DarkMailPalette.BORDER_WIDTH
			sb.border_color = DarkMailPalette.GREEN
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			label.add_theme_stylebox_override("normal", sb)
		else:
			label.remove_theme_stylebox_override("normal")


# --- live state --------------------------------------------------------------

func _refresh_from_state() -> void:
	_highlight_step(GameState.mission_phase)
	_on_turns_changed(GameState.mission_turns_left, GameState.mission_turn_budget)


func _on_phase_changed(phase: StringName) -> void:
	_highlight_step(phase)


func _on_turns_changed(turns_left: int, turn_budget: int) -> void:
	if not _shows_turns:
		return
	_turns_label.text = tr("OSCHROME_TURNS") % [turns_left, turn_budget]
	var color := DarkMailPalette.GREEN
	if turns_left <= 0:
		color = DarkMailPalette.ALERT_RED
	elif turns_left <= LOW_TURNS_THRESHOLD:
		color = DarkMailPalette.WARN_AMBER
	_turns_label.add_theme_color_override("font_color", color)
	_set_pulsing(turns_left <= LOW_TURNS_THRESHOLD and turn_budget > 0)


# A quiet pulse on the turn budget once it runs low: opacity breathing, no
# movement, so it draws the eye without shifting layout.
func _set_pulsing(on: bool) -> void:
	if on and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_turns_label, "modulate:a", 0.55, PULSE_INTERVAL)
		_pulse_tween.tween_property(_turns_label, "modulate:a", 1.0, PULSE_INTERVAL)
	elif not on and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		_turns_label.modulate.a = 1.0


# --- clock -------------------------------------------------------------------

func _update_clock() -> void:
	_clock_label.text = Time.get_time_string_from_system().substr(0, 5)


# --- dossier overlay ---------------------------------------------------------

func _toggle_dossier() -> void:
	_dossier.visible = not _dossier.visible


func _on_dossier_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dossier.visible = false
