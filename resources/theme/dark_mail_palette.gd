# The DarkMail OS palette: terminal green, dark backgrounds, border width and
# the mono font, shared by every in-scenario frame element.
#
# CAUTION: secret_ops_theme.tres cannot reference GDScript constants and mirrors
# these values as literals. Change one, change the other:
#   GREEN        <-> border/font green   Color(0.27, 1, 0.45)
#   TEXT_GREEN   <-> Label font color    Color(0.78, 0.96, 0.84)
#   BG_PANEL     <-> Panel bg            Color(0.027, 0.055, 0.039)
#   BG_FIELD     <-> Button normal bg    Color(0.043, 0.094, 0.067)
#   BORDER_WIDTH <-> all border widths   2
class_name DarkMailPalette
extends RefCounted

# --- core palette (mirrored in secret_ops_theme.tres, see header) -----------
const GREEN := Color("45ff73")         # primary phosphor green: borders, accents
const GREEN_BRIGHT := Color("d9ffe6")  # hover/active text on green elements
const TEXT_GREEN := Color("c7f5d6")    # readable body green
const TEXT_DIM := Color("6fae86")      # muted green for secondary text
const BG_PANEL := Color("070e0a")      # window/panel background
const BG_RAISED := Color("0c1310")     # chrome strips (bars, tab strip)
const BG_FIELD := Color("0b1811")      # buttons, input fields

# --- status colours ----------------------------------------------------------
const WARN_AMBER := Color("ffb454")    # low resource (e.g. turn budget <= 2)
const ALERT_RED := Color("ff4f58")     # depleted / critical

# --- frame metrics -----------------------------------------------------------
const BORDER_WIDTH := 2                # hard 2px frames, no rounded corners

# --- mono UI font (terminal + dark chrome; OFL, see assets/fonts) ------------
# Departure Mono is a pixel font drawn on an 11px grid: use ONLY multiples of
# 11 (11/22/33...) or the glyphs land between pixels and blur. Its import is
# configured aliased (antialiasing off, no mipmaps, hinting none) to match.
const FONT_MONO: Font = preload("res://assets/fonts/DepartureMono-Regular.otf")
const FONT_SIZE_MONO_SMALL := 11       # status lines, fine print
const FONT_SIZE_MONO := 22             # default UI text (theme default size)
const FONT_SIZE_MONO_LARGE := 33       # headlines (e.g. dossier mission line)


# Zero radius is deliberate: the terminal frame never rounds its corners.
static func flat_box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	return sb


# The shared terminal button look, so dialogs read as the same system as the
# scenario screens.
static func style_button(button: Button, padding_x: int = 20, padding_y: int = 10) -> void:
	var normal := flat_box(BG_FIELD, GREEN, BORDER_WIDTH)
	var hover := flat_box(Color(GREEN, 0.22), GREEN_BRIGHT, BORDER_WIDTH)
	var disabled := flat_box(BG_FIELD, TEXT_DIM, BORDER_WIDTH)
	# Same padding in all three, or the button resizes when greyed out.
	for sb in [normal, hover, disabled]:
		sb.content_margin_left = padding_x
		sb.content_margin_right = padding_x
		sb.content_margin_top = padding_y
		sb.content_margin_bottom = padding_y
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_override("font", FONT_MONO)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MONO)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, GREEN)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func apply_mono_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", FONT_MONO)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
