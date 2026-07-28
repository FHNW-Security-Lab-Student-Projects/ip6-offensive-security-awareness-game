# Dresses the bad_usb level in the DarkMail terminal look that scenario 1 uses,
# so the two levels read as one game.
#
# The level was authored against Godot's default theme with per-node
# LabelSettings and StyleBoxes in the .tscn. Restyling happens here in code
# rather than by editing bad_usb.tscn: the scene file is owned by the level
# work, and a code pass keeps the visual contract in one reviewable place.
#
# Referenced by preload path, not a class_name, so headless tests compile it
# without the editor's global class cache.
extends RefCounted

# Speech panels sit over a bright pixel-art world, so they carry a touch more
# opacity than the terminal screens of scenario 1, which sit on black.
const PANEL_ALPHA: float = 0.92

# Dialogue choices wrap inside this width instead of stretching their container.
# Without a cap a Button derives its minimum width from the full line of text,
# which pushed the choices wider than the dialogue box itself.
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


# A speech/notice panel: dark fill, hard green frame.
static func style_panel(panel: Control, alpha: float = PANEL_ALPHA) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _panel_box(alpha))


# Body text inside a panel. Clears the .tscn LabelSettings first, which would
# otherwise win over the theme overrides and keep the old black default font.
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


# A dialogue choice. Wrapping is what keeps the option inside the dialogue box:
# the button may use the full width but must not demand more than CHOICE_WIDTH.
static func style_choice(button: Button) -> void:
	if button == null:
		return
	style_button(button)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.x = CHOICE_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# The debrief's backdrop is a bare ColorRect, and Godot's default for one is
# opaque white: terminal-green text is unreadable on it. Hide it and put the
# same framed panel the speech boxes use in its place, so the debrief reads as
# part of the same screen family.
static func replace_backdrop(host: Control, rect: ColorRect) -> void:
	if host == null or rect == null:
		return
	if host.has_node("TerminalBackdrop"):
		return
	rect.visible = false
	var panel := Panel.new()
	panel.name = "TerminalBackdrop"
	# Must not eat the clicks meant for the Weiter/Beenden buttons above it.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _panel_box(0.97))
	host.add_child(panel)
	host.move_child(panel, 0)


# Centres a choice column of CHOICE_WIDTH on its parent and pins it to the
# bottom, replacing the narrower fixed offsets the .tscn lays out.
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
