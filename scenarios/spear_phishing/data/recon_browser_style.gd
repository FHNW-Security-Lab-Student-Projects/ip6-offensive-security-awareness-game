# The Recon browser look: palette, spacing, radii, fonts and StyleBox factories.
#
# Two layers, deliberately split:
#   - The FRAME (title bar, url bar, tabs, footer) wears the DarkMail skin, so
#     the tool reads as part of the terminal.
#   - The PAGE CONTENT stays bright and realistic. That realism is didactically
#     load-bearing - the player has to recognise leaks in real-looking posts -
#     so the terminal look must never bleed into it.
class_name ReconBrowserStyle
extends RefCounted

# Neutral sans (Noto Sans, OFL-1.1). See assets/fonts/LICENSE-NotoSans.md.
const FONT_REGULAR: Font = preload("res://assets/fonts/NotoSans-Regular.ttf")
const FONT_BOLD: Font = preload("res://assets/fonts/NotoSans-Bold.ttf")

# --- palette ---------------------------------------------------------------
const COLOR_DESKTOP := Color("13181c")        # dark backdrop behind the window
const COLOR_CHROME := Color("e7eaee")          # title/url bar
const COLOR_CHROME_BORDER := Color("cdd2d9")
const COLOR_PAGE := Color("f6f7f9")            # page background
const COLOR_CARD := Color("ffffff")
const COLOR_CARD_BORDER := Color("dfe3e8")
const COLOR_CARD_HOVER := Color("f0f6ff")
const COLOR_CARD_COLLECTED := Color("eafaf0")
const COLOR_ACCENT := Color("2f6bd8")          # link/active blue
const COLOR_CHECK := Color("1f9d55")           # lock icon only (not a marking)
# Marking for collected finds. Value-neutral on purpose: junk and good finds
# look IDENTICAL, the marking says "collected", never "correct". Filled, not
# bordered, so wrapped lines do not read as a framed box.
const COLOR_MARK_HOVER := Color(DarkMailPalette.GREEN, 0.18)  # pre-collect glow
const COLOR_MARK_DECK := Color(DarkMailPalette.GREEN, 0.42)   # collected fill
const COLOR_TEXT := Color("1c2530")
const COLOR_MUTED := Color("6b7684")
const COLOR_TAB_ACTIVE := Color("ffffff")
const COLOR_TAB_INACTIVE := Color("dde1e7")
const COLOR_TAB_HOVER := Color("d6e2f4")        # inactive tab, hovered (blue tint, distinct from white active)
const COLOR_TRAFFIC_RED := Color("ff5f57")
const COLOR_TRAFFIC_YELLOW := Color("febc2e")
const COLOR_TRAFFIC_GREEN := Color("28c840")
# Platform-card accents (bright content layer).
const COLOR_LINK := Color("1a4fc4")            # search-result title (blue link)
const COLOR_URL := Color("0f7a34")             # search-result url line (green)

# --- spacing / radii -------------------------------------------------------
const RADIUS := 8
const RADIUS_SMALL := 5
const PAD := 14
const GAP := 10
const FONT_SIZE_BODY := 22
const FONT_SIZE_SMALL := 18
const FONT_SIZE_TITLE := 26


static func _flat(bg: Color, border: Color, radius: int, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = PAD
	sb.content_margin_bottom = PAD
	return sb


static func window_box() -> StyleBoxFlat:
	var sb := _flat(COLOR_PAGE, COLOR_CHROME_BORDER, RADIUS, 1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


static func chrome_box() -> StyleBoxFlat:
	var sb := _flat(COLOR_CHROME, COLOR_CHROME_BORDER, 0, 0)
	return sb


static func url_field_box() -> StyleBoxFlat:
	var sb := _flat(Color("ffffff"), COLOR_CHROME_BORDER, RADIUS, 1)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func card_box(collected: bool, hover: bool) -> StyleBoxFlat:
	var bg := COLOR_CARD
	var border := COLOR_CARD_BORDER
	if collected:
		bg = COLOR_CARD_COLLECTED
		border = COLOR_CHECK
	elif hover:
		bg = COLOR_CARD_HOVER
		border = COLOR_ACCENT
	return _flat(bg, border, RADIUS, 1)


# Feed post. No collected or hover state: the interaction lives on the embedded
# highlight, not on the card.
static func post_box() -> StyleBoxFlat:
	return _flat(COLOR_CARD, COLOR_CARD_BORDER, RADIUS, 1)


# Search result: no outline, just padding, the classic search-engine look.
static func search_card_box() -> StyleBoxFlat:
	return _flat(COLOR_PAGE, Color(0, 0, 0, 0), 0, 0)


# The active tab drops its bottom border and takes the page colour, so it merges
# into the content area the way a real browser tab does.
static func _tab_box_bg(bg: Color, bottom_border: bool) -> StyleBoxFlat:
	var sb := _flat(bg, COLOR_CHROME_BORDER, RADIUS_SMALL, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	if not bottom_border:
		sb.border_width_bottom = 0
	return sb


static func tab_box(active: bool) -> StyleBoxFlat:
	# Active connects to the page; inactive sits back with a full outline.
	return _tab_box_bg(COLOR_PAGE if active else COLOR_TAB_INACTIVE, not active)


# Inactive tab under the cursor: background lifts a step, text unchanged.
static func tab_box_hover() -> StyleBoxFlat:
	return _tab_box_bg(COLOR_TAB_HOVER, true)


# Keeps the per-node font overrides in one place.
static func apply_label(label: Label, size: int = FONT_SIZE_BODY, color: Color = COLOR_TEXT, bold: bool = false) -> void:
	label.add_theme_font_override("font", FONT_BOLD if bold else FONT_REGULAR)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func _btn_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := _flat(bg, border, radius, 1)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# Overrides the global terminal theme explicitly, so the green button look never
# bleeds into the bright browser surface.
static func _set_button_fonts(btn: Button, size: int, color: Color, bold: bool) -> void:
	btn.add_theme_font_override("font", FONT_BOLD if bold else FONT_REGULAR)
	btn.add_theme_font_size_override("font_size", size)
	# Hovering an active tab uses hover_pressed; without it the terminal theme's
	# near white bleeds in and the label disappears.
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(state, color)


static func style_tab(btn: Button, active: bool) -> void:
	# Three states, text stays COLOR_TEXT in all of them.
	btn.add_theme_stylebox_override("normal", tab_box(active))
	btn.add_theme_stylebox_override("hover", tab_box(true) if active else tab_box_hover())
	btn.add_theme_stylebox_override("pressed", tab_box(true))
	# An active tab under the cursor: keep the active look so text never drops out.
	btn.add_theme_stylebox_override("hover_pressed", tab_box(true))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_button_fonts(btn, FONT_SIZE_SMALL, COLOR_TEXT, active)


static func style_pill(btn: Button, collected: bool) -> void:
	var accent := COLOR_CHECK if collected else COLOR_ACCENT
	btn.add_theme_stylebox_override("normal", _btn_box(Color("ffffff"), accent, RADIUS_SMALL))
	btn.add_theme_stylebox_override("hover", _btn_box(Color("f0f6ff"), accent, RADIUS_SMALL))
	btn.add_theme_stylebox_override("pressed", _btn_box(Color("e6eefc"), accent, RADIUS_SMALL))
	btn.add_theme_stylebox_override("disabled", _btn_box(Color("f2f3f5"), COLOR_CARD_BORDER, RADIUS_SMALL))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_button_fonts(btn, FONT_SIZE_SMALL, accent, true)
	btn.add_theme_color_override("font_disabled_color", COLOR_MUTED)


static func style_primary(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn_box(COLOR_ACCENT, COLOR_ACCENT, RADIUS_SMALL))
	btn.add_theme_stylebox_override("hover", _btn_box(Color("2559b8"), Color("2559b8"), RADIUS_SMALL))
	btn.add_theme_stylebox_override("pressed", _btn_box(Color("1e4aa0"), Color("1e4aa0"), RADIUS_SMALL))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_button_fonts(btn, FONT_SIZE_BODY, Color("ffffff"), true)


# --- dark chrome (DarkMail OS skin) ------------------------------------------
# Frame only. Palette and metrics come from DarkMailPalette, so the chrome cannot
# drift from the terminal theme. The bright page factories above stay untouched.

const FONT_MONO: Font = DarkMailPalette.FONT_MONO


static func window_box_dark() -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	return sb


static func chrome_box_dark() -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(DarkMailPalette.BG_RAISED)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func url_field_box_dark() -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, Color(DarkMailPalette.GREEN, 0.45), 1)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func tab_strip_box_dark() -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(DarkMailPalette.BG_RAISED)
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = 8
	sb.content_margin_bottom = 0
	return sb


static func footer_box_dark() -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(DarkMailPalette.BG_RAISED)
	sb.border_width_top = DarkMailPalette.BORDER_WIDTH
	sb.border_color = Color(DarkMailPalette.GREEN, 0.35)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


# The active tab carries the green underline, inactive ones lift on hover.
static func _tab_box_dark(bg: Color, underline: bool) -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(bg)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	if underline:
		sb.border_width_bottom = DarkMailPalette.BORDER_WIDTH
		sb.border_color = DarkMailPalette.GREEN
	return sb


static func tab_box_dark(active: bool) -> StyleBoxFlat:
	return _tab_box_dark(
		DarkMailPalette.BG_FIELD if active else DarkMailPalette.BG_RAISED, active)


static func tab_box_dark_hover() -> StyleBoxFlat:
	return _tab_box_dark(Color(DarkMailPalette.GREEN, 0.12), false)


static func _set_button_fonts_mono(btn: Button, size: int, color: Color) -> void:
	btn.add_theme_font_override("font", FONT_MONO)
	btn.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(state, color)


static func style_tab_dark(btn: Button, active: bool) -> void:
	btn.add_theme_stylebox_override("normal", tab_box_dark(active))
	btn.add_theme_stylebox_override("hover", tab_box_dark(true) if active else tab_box_dark_hover())
	btn.add_theme_stylebox_override("pressed", tab_box_dark(true))
	btn.add_theme_stylebox_override("hover_pressed", tab_box_dark(true))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_button_fonts_mono(
		btn, DarkMailPalette.FONT_SIZE_MONO,
		DarkMailPalette.GREEN if active else DarkMailPalette.TEXT_DIM)


# Mirrors the button look of secret_ops_theme.tres through the shared palette.
static func style_terminal_button(btn: Button) -> void:
	var normal := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	var hover := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.22), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	var pressed := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.45), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	for sb in [normal, hover, pressed]:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", FONT_MONO)
	btn.add_theme_font_size_override("font_size", DarkMailPalette.FONT_SIZE_MONO)
	btn.add_theme_color_override("font_color", DarkMailPalette.GREEN)
	btn.add_theme_color_override("font_hover_color", DarkMailPalette.GREEN_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", Color("fffff2"))
	btn.add_theme_color_override("font_focus_color", DarkMailPalette.GREEN)


# Sizes must stay on the Departure Mono 11px grid (see DarkMailPalette).
static func apply_mono_label(label: Label, size: int = DarkMailPalette.FONT_SIZE_MONO, color: Color = DarkMailPalette.TEXT_GREEN) -> void:
	DarkMailPalette.apply_mono_label(label, size, color)
