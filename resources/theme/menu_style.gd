# The title-screen / menu look: chunky arcade slabs in the artwork's own warm
# accent colours, with a hard offset shadow and the mono pixel font. The primary
# entry (play) is brighter and larger so the eye lands on it first.
#
# Deliberately separate from DarkMailPalette (the in-scenario terminal look):
# the menus live on a bright CRT, the scenarios inside a dark OS.
extends RefCounted

const FONT_MONO: Font = preload("res://assets/fonts/DepartureMono-Regular.otf")

# Sampled from the title artwork (PC_Setup.png): the warm rust of the desk and
# lamp is the scene's dominant accent, so the buttons belong to the picture.
const PRIMARY := Color("e07a35")
const PRIMARY_HOVER := Color("ff9a4d")
const PRIMARY_PRESSED := Color("b75f2e")
const SECONDARY := Color("a85b30")
const SECONDARY_HOVER := Color("cf7a3d")
const SECONDARY_PRESSED := Color("873d1f")
const OUTLINE := Color("2b1a12")
const LABEL := Color("fff3dc")

# Panel surfaces (settings dialog) stay in the bright CRT palette.
const PANEL_FILL := Color("fff6e0")
const PANEL_ALT := Color("e7cfa8")
const INK := Color("2b1a12")

const FONT_SIZE := 24
const FONT_SIZE_PRIMARY := 28
const FONT_SIZE_LARGE := 33

const BUTTON_SIZE := Vector2(340, 74)
const SHADOW_OFFSET := 6
const SHADOW_OFFSET_PRESSED := 2



static func flat_box(bg: Color, border: Color = INK, border_w: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	return sb


static func apply_label(label: Label, size: int = FONT_SIZE, color: Color = INK) -> void:
	label.add_theme_font_override("font", FONT_MONO)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


# --- arcade slab buttons ------------------------------------------------------

# Main menu entry. `primary` marks the play button: brighter fill, bigger label.
static func style_menu_button(button: Button, primary: bool = false) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_slab(button, primary)


# Smaller slab for dialogs (settings), same material, no fixed width.
static func style_button(button: Button, primary: bool = false) -> void:
	_apply_slab(button, primary, 20, 12)


static func _apply_slab(button: Button, primary: bool, pad_x: int = 24, pad_y: int = 16) -> void:
	var face := PRIMARY if primary else SECONDARY
	var face_hover := PRIMARY_HOVER if primary else SECONDARY_HOVER
	var face_pressed := PRIMARY_PRESSED if primary else SECONDARY_PRESSED
	# Hover only brightens — moving the slab on hover reads as a glitch. The
	# press does move, which is the one place a shift feels right.
	button.add_theme_stylebox_override("normal", _slab(face, SHADOW_OFFSET, pad_x, pad_y, 0))
	button.add_theme_stylebox_override("hover", _slab(face_hover, SHADOW_OFFSET, pad_x, pad_y, 0))
	button.add_theme_stylebox_override("pressed", _slab(face_pressed, SHADOW_OFFSET_PRESSED, pad_x, pad_y, 3))
	button.add_theme_stylebox_override("disabled", _slab(SECONDARY_PRESSED, SHADOW_OFFSET, pad_x, pad_y, 0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", FONT_MONO)
	button.add_theme_font_size_override("font_size", FONT_SIZE_PRIMARY if primary else FONT_SIZE)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color"]:
		button.add_theme_color_override(state, LABEL)


# One slab: solid face, hard dark outline and a hard offset shadow. Built from a
# StyleBoxFlat rather than a 9-sliced texture, because slicing a texture with a
# baked-in shadow stretches the inner bands into visible seams. `shift` nudges
# the label down while pressed, so the key reads as going down.
static func _slab(face: Color, shadow_offset: int, pad_x: int, pad_y: int, shift: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(3)
	sb.border_color = OUTLINE
	sb.shadow_color = OUTLINE
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(shadow_offset, shadow_offset)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y + shift
	sb.content_margin_bottom = pad_y - shift
	return sb


# --- pixel checkbox ----------------------------------------------------------

# Square pixel checkbox drawn in code: light field with a dark frame, and a
# solid block inside when checked.
static func checkbox_texture(checked: bool, size: int = 26) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(PANEL_FILL)
	var frame := 3
	for y in size:
		for x in size:
			if x < frame or y < frame or x >= size - frame or y >= size - frame:
				image.set_pixel(x, y, INK)
	if checked:
		var inset := frame + 3
		for y in range(inset, size - inset):
			for x in range(inset, size - inset):
				image.set_pixel(x, y, PRIMARY)
	return ImageTexture.create_from_image(image)


static func style_checkbox(check: CheckBox) -> void:
	var off := checkbox_texture(false)
	var on := checkbox_texture(true)
	check.add_theme_icon_override("unchecked", off)
	check.add_theme_icon_override("unchecked_disabled", off)
	check.add_theme_icon_override("checked", on)
	check.add_theme_icon_override("checked_disabled", on)
	for state in ["normal", "hover", "pressed", "focus"]:
		check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	check.add_theme_font_override("font", FONT_MONO)
	check.add_theme_font_size_override("font_size", FONT_SIZE)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		check.add_theme_color_override(state, INK)
