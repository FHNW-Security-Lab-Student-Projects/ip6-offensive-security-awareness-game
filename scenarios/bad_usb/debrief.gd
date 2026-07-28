# The bad_usb closing screen, built to match scenario 1's RESOLVE: full screen,
# DarkMail look, content fading in rather than snapping, a click that hurries
# the text along, and the same set of exits at the end.
#
# Difference to scenario 1: this debrief has five stages, each with its own
# image, so they are shown one at a time instead of stacked. Five images on one
# surface would need scrolling, and a debrief the player has to scroll is a
# debrief the player stops reading.
#
# VIEW only. It renders what it is configured with and reports what the player
# did; it owns no game logic and no routing. The scenario shell decides what
# each exit means.
extends Control

# The player is done reading a stage. dwell_ms is the time the finished text
# stood on screen, which is the debrief-attention measure for the study.
signal stage_advanced(index: int, dwell_ms: int)
signal levels_requested
signal home_requested
signal replay_requested

const Typewriter := preload("res://scenarios/base/typewriter.gd")
const SkipHint := preload("res://scenarios/base/skip_hint.gd")
const PromptClock := preload("res://scenarios/base/prompt_clock.gd")

const FADE_TIME: float = 0.45
const IMAGE_HEIGHT: int = 300
const CHARS_PER_SECOND: float = 45.0
# Wrap width for the paragraphs, the same idea as scenario 1's BODY_WIDTH: a
# full-width line of mono text is too long to track back to the next line.
const BODY_WIDTH: int = 900
const SIDE_MARGIN: int = 80
# Clears the 80px OS bar, the same y >= 96 contract scenario 1's screens follow.
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
	_build()
	_typer.finished.connect(_on_stage_typed)


func _process(delta: float) -> void:
	_typer.advance(delta)


# stages: [{title: <translated>, text: <translated>, image: Texture2D or null}]
#
# accent colours the headings. Scenario 1 does the same thing on its Resolve
# screen: a losing outcome gets ALERT_RED instead of the phosphor green, so the
# result is readable before a single word is.
func configure(stages: Array, accent: Color = DarkMailPalette.GREEN) -> void:
	_stages = stages.duplicate()
	_index = 0
	_title.add_theme_color_override("font_color", accent)
	_show_stage()


# --- layout -------------------------------------------------------------------

func _build() -> void:
	# Opaque, not a dim over the level: the closing screen takes the whole
	# display the way scenario 1's Resolve does, so the debrief is the only
	# thing left to look at. Same colour as its Background rect.
	_panel = ColorRect.new()
	(_panel as ColorRect).color = DarkMailPalette.BG_PANEL
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	# The whole screen is the click target, the way scenario 1's reveal catcher
	# is: the hint in the corner advertises it, but it is not the only way in.
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

	# Everything that changes per stage lives in one node, so a stage change is
	# one fade instead of three that can drift apart.
	_stage_box = VBoxContainer.new()
	(_stage_box as VBoxContainer).add_theme_constant_override("separation", 22)
	column.add_child(_stage_box)

	_title = _make_label(DarkMailPalette.FONT_SIZE_MONO_LARGE, DarkMailPalette.GREEN)
	_stage_box.add_child(_title)

	_body = _make_label(DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	# Bounded and centred like scenario 1's paragraphs rather than run edge to
	# edge across the display.
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


# The exits scenario 1 offers, minus "next scenario": bad_usb is the last one in
# the registry, so that button would have nowhere to go.
func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_add_button(row, "RESOLVE_LEVELS", func() -> void: levels_requested.emit())
	_add_button(row, "RESOLVE_HOME", func() -> void: home_requested.emit())
	_add_button(row, "RESOLVE_RETRY", func() -> void: replay_requested.emit())
	return row


# Centred mono label, the shape scenario 1's debrief uses for every line it
# shows. Clicks fall through so the whole screen stays one target.
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
	# Hidden until the text has landed, so the image is a reward for reading
	# rather than a distraction beside it.
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


# A click hurries the running text, and once it stands it turns the page. The
# last stage is left to its buttons so a stray click cannot leave the screen.
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


# Public so the headless test can drive the sequence without synthesising input.
func advance() -> void:
	if _is_last_stage():
		return
	stage_advanced.emit(_index, _clock.take())
	_index += 1
	_show_stage()
