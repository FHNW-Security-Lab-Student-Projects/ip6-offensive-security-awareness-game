# Dresses the level in scenario 1's DarkMail look, so the two read as one game.
#
# The level was authored against Godot's default theme, with LabelSettings and
# StyleBoxes per node in the .tscn. Restyling happens here in code rather than in
# the scene file, which keeps the visual contract in one reviewable place.
extends RefCounted

# A touch more opaque than scenario 1's screens: these sit over a bright world,
# not over black.
const PANEL_ALPHA: float = 0.92

# Without a cap a Button derives its minimum width from the full line of text,
# which pushes the choices wider than the dialogue box itself.
const CHOICE_WIDTH: int = 980

const BUTTON_PADDING_X: int = 16
const BUTTON_PADDING_Y: int = 8


static func _panel_box(alpha: float = PANEL_ALPHA) -> StyleBoxFlat:
	var box := DarkMailPalette.flat_box(
		Color(DarkMailPalette.BG_PANEL, alpha),
		DarkMailPalette.GREEN,
		DarkMailPalette.BORDER_WIDTH,
	)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func style_panel(panel: Control, alpha: float = PANEL_ALPHA) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _panel_box(alpha))


# Clears the .tscn LabelSettings first: they win over theme overrides and would
# keep the old black default font.
static func style_body(label: Label, size: int = DarkMailPalette.FONT_SIZE_MONO) -> void:
	if label == null:
		return
	label.label_settings = null
	DarkMailPalette.apply_mono_label(label, size, DarkMailPalette.TEXT_GREEN)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func style_heading(label: Label, size: int = DarkMailPalette.FONT_SIZE_MONO_LARGE) -> void:
	if label == null:
		return
	label.label_settings = null
	DarkMailPalette.apply_mono_label(label, size, DarkMailPalette.GREEN)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func style_button(button: Button) -> void:
	if button == null:
		return
	DarkMailPalette.style_button(button, BUTTON_PADDING_X, BUTTON_PADDING_Y)


# Wrapping is what keeps the option inside the dialogue box: the button may use
# the full width but must not demand more than CHOICE_WIDTH.
static func style_choice(button: Button) -> void:
	if button == null:
		return
	style_button(button)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.x = CHOICE_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# The debrief's backdrop is a bare ColorRect, and Godot defaults those to opaque
# white, on which terminal green is unreadable. Hide it and put the speech boxes'
# framed panel in its place.
static func replace_backdrop(host: Control, rect: ColorRect) -> Panel:
	if host == null or rect == null:
		return null
	if host.has_node("TerminalBackdrop"):
		return host.get_node("TerminalBackdrop") as Panel
	rect.visible = false
	var panel := Panel.new()
	panel.name = "TerminalBackdrop"
	# Must not eat the clicks meant for the buttons above it.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _panel_box(0.97))
	host.add_child(panel)
	host.move_child(panel, 0)
	return panel


# The same insets the intro's dialog box gives its hint, so the affordance sits
# in the same place in both scenarios.
const HINT_MARGIN_X: int = 32
const HINT_MARGIN_Y: int = 24
const HINT_WIDTH: int = 300


static func place_skip_hint(hint: Label, host: Control) -> void:
	if hint == null or host == null:
		return
	host.add_child(hint)
	hint.anchor_left = 1.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = -(HINT_WIDTH + HINT_MARGIN_X)
	hint.offset_top = -(DarkMailPalette.FONT_SIZE_MONO + HINT_MARGIN_Y)
	hint.offset_right = -HINT_MARGIN_X
	hint.offset_bottom = -HINT_MARGIN_Y
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# Replaces the narrower fixed offsets the .tscn lays out.
static func layout_choice_column(column: BoxContainer, bottom_margin: int = 24) -> void:
	if column == null:
		return
	column.add_theme_constant_override("separation", 10)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = -CHOICE_WIDTH / 2.0
	column.offset_right = CHOICE_WIDTH / 2.0
	column.offset_top = 0.0
	column.offset_bottom = -bottom_margin
