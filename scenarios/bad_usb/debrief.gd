# The closing screen, built to match scenario 1's RESOLVE: full screen, DarkMail
# look, fading content, click to hurry the text, the same exits.
#
# Unlike scenario 1 the stages come one at a time instead of stacked: five images
# on one surface would need scrolling, and a debrief that scrolls is a debrief
# nobody finishes.
#
# VIEW only. The shell decides what each exit means.
extends Control

# dwell_ms is how long the finished text stood, which is the attention measure.
signal stage_advanced(index: int, dwell_ms: int)
signal levels_requested
signal home_requested
signal replay_requested

const Typewriter := preload("res://scenarios/base/typewriter.gd")
const SkipHint := preload("res://scenarios/base/skip_hint.gd")
const PromptClock := preload("res://scenarios/base/prompt_clock.gd")
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")

# Scenario 1 closes on this too, so both levels end on the same note.
const DEBRIEF_MUSIC := preload("res://assets/audio/terminal_echo_drift.wav")

const FADE_TIME: float = 0.45
const IMAGE_HEIGHT: int = 300
const CHARS_PER_SECOND: float = 45.0
# A full-width line of mono text is too long to track back to the next.
const BODY_WIDTH: int = 900
const SIDE_MARGIN: int = 80
# Clears the OS bar, the same contract scenario 1's screens follow.
const TOP_MARGIN: int = 96
const BOTTOM_MARGIN: int = 40

var _stages: Array = []          # [{title: String, text: String, image: Texture2D}]
var _index: int = 0

var _typer := Typewriter.new()
var _clock := PromptClock.new()
var _panel: Control   # the opaque full-screen backdrop, also the click target
var _title: Label
var _body: Label
var _image: TextureRect
var _hint: Label
var _buttons: Control
var _stage_box: Control


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var music := ScreenMusic.new()
	music.track = DEBRIEF_MUSIC
	add_child(music)
	_build()
	_typer.finished.connect(_on_stage_typed)


func _process(delta: float) -> void:
	_typer.advance(delta)


# stages is already translated. accent colours the headings; a losing outcome
# gets red, so the result reads before a single word does.
func configure(stages: Array, accent: Color = DarkMailPalette.GREEN) -> void:
	_stages = stages.duplicate()
	_index = 0
	_title.add_theme_color_override("font_color", accent)
	_show_stage()


# --- layout -------------------------------------------------------------------

func _build() -> void:
	# Opaque, not a dim over the level: the debrief should be the only thing left
	# to look at.
	_panel = ColorRect.new()
	(_panel as ColorRect).color = DarkMailPalette.BG_PANEL
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	# The whole screen is the click target; the corner hint advertises it but is
	# not the only way in.
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_click)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = SIDE_MARGIN
	column.offset_top = TOP_MARGIN
	column.offset_right = -SIDE_MARGIN
	column.offset_bottom = -BOTTOM_MARGIN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks fall through
	add_child(column)

	# One node for everything that changes per stage, so a stage change is a
	# single fade instead of three that can drift apart.
	_stage_box = VBoxContainer.new()
	(_stage_box as VBoxContainer).add_theme_constant_override("separation", 22)
	# Containers default to STOP and would eat every click landing on the text,
	# leaving only the bare background clickable.
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage_box)

	_title = _make_label(DarkMailPalette.FONT_SIZE_MONO_LARGE, DarkMailPalette.GREEN)
	_stage_box.add_child(_title)

	_body = _make_label(DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	_body.custom_minimum_size.x = BODY_WIDTH
	_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage_box.add_child(_body)

	_image = TextureRect.new()
	_image.custom_minimum_size.y = IMAGE_HEIGHT
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(_image)

	_hint = SkipHint.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)

	_buttons = _build_buttons()
	_buttons.visible = false
	column.add_child(_buttons)


# Scenario 1's exits minus "next scenario": this level is last in the registry.
func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	# Same reason: the gaps between the buttons must not swallow clicks. The
	# buttons sit on top and still get their own.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_button(row, "RESOLVE_LEVELS", func() -> void: levels_requested.emit())
	_add_button(row, "RESOLVE_HOME", func() -> void: home_requested.emit())
	_add_button(row, "RESOLVE_RETRY", func() -> void: replay_requested.emit())
	return row


# Clicks fall through so the whole screen stays one target.
func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DarkMailPalette.apply_mono_label(label, size, color)
	return label


func _add_button(row: HBoxContainer, key: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = tr(key)
	DarkMailPalette.style_button(button)
	button.pressed.connect(on_press)
	row.add_child(button)


# --- stages --------------------------------------------------------------------

func _show_stage() -> void:
	if _index >= _stages.size():
		return
	var stage: Dictionary = _stages[_index]
	_title.text = String(stage.get("title", ""))
	var texture = stage.get("image")
	_image.texture = texture
	# Hidden until the text has landed, so it rewards reading instead of
	# competing with it.
	_image.visible = false
	_buttons.visible = false
	_hint.set_active(true)

	_stage_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_stage_box, "modulate:a", 1.0, FADE_TIME)

	SfxPlayer.start_typing()
	_typer.start(_body, String(stage.get("text", "")), CHARS_PER_SECOND)


func _on_stage_typed() -> void:
	SfxPlayer.stop_typing()
	_hint.set_active(false)
	if _image.texture != null:
		_image.visible = true
		_fade_in(_image)
	if _is_last_stage():
		_buttons.visible = true
		_fade_in(_buttons)
	else:
		_hint.set_active(true)   # now it means "click for the next stage"
	_clock.mark()


func _fade_in(node: CanvasItem) -> void:
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, FADE_TIME)


func _is_last_stage() -> bool:
	return _index >= _stages.size() - 1


# A click hurries the running text, then turns the page. The last stage is left
# to its buttons, so a stray click cannot leave the screen.
func _on_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if _typer.is_typing():
		_typer.finish_now()
		return
	if _is_last_stage():
		return
	advance()


# Public so the headless test can drive the sequence without faking input.
func advance() -> void:
	if _is_last_stage():
		return
	stage_advanced.emit(_index, _clock.take())
	_index += 1
	_show_stage()
