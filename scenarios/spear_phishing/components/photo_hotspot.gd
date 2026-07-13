# A clickable region on a photo that collects an embedded find directly. Hover
# shows a hint of what is in the image (the "zoom"); a click collects or
# uncollects the find. No separate reveal step and no standalone card: the find
# lives only here, on its parent photo.
#
# Drawn, not textured (font-independent, like lock_icon / hud_brackets): faint
# corner brackets that brighten on hover, a green fill with a check when
# collected. Referenced by path (preload) from Recon, not via a class name.
extends Control

signal clicked

const GREEN := DarkMailPalette.GREEN
const TEXT_GREEN := DarkMailPalette.TEXT_GREEN

var hint: String = ""
var collected: bool = false

var _hover := false
var _hint_panel: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# Configure before adding to the tree (or right after; _ready builds the hint).
func setup(p_hint: String, p_collected: bool) -> void:
	hint = p_hint
	collected = p_collected


func _ready() -> void:
	_build_hint_panel()


func _build_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.visible = false
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark terminal tooltip so it reads over the bright photo.
	var sb := DarkMailPalette.flat_box(DarkMailPalette.BG_PANEL, GREEN, DarkMailPalette.BORDER_WIDTH)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_hint_panel.add_theme_stylebox_override("panel", sb)
	# Appear just below the hotspot's top-left, growing downward.
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_top = 6.0
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_END
	var lbl := Label.new()
	lbl.text = hint
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(280, 0)
	DarkMailPalette.apply_mono_label(lbl, DarkMailPalette.FONT_SIZE_MONO_SMALL, TEXT_GREEN)
	_hint_panel.add_child(lbl)
	add_child(_hint_panel)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		if _hint_panel != null:
			_hint_panel.visible = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		if _hint_panel != null:
			_hint_panel.visible = false
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	if collected:
		# Collected: soft green fill plus a check, matching the deck marking.
		draw_rect(Rect2(Vector2.ZERO, size), Color(GREEN, 0.30), true)
		_draw_check(Vector2(w * 0.5, h * 0.5), min(w, h) * 0.22)
	elif _hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(GREEN, 0.16), true)
	# Corner brackets: findable normally, brighter on hover, bright when collected.
	var a := 0.9 if (_hover or collected) else 0.4
	var col := Color(GREEN, a)
	var arm: float = min(w, h) * 0.28
	var t := 2.0
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]
	var dirs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for i in corners.size():
		var c := corners[i]
		var d := dirs[i]
		draw_line(c, c + Vector2(arm * d.x, 0), col, t)
		draw_line(c, c + Vector2(0, arm * d.y), col, t)


func _draw_check(center: Vector2, r: float) -> void:
	var col := Color(GREEN, 1.0)
	var p1 := center + Vector2(-r, 0.0)
	var p2 := center + Vector2(-r * 0.3, r * 0.7)
	var p3 := center + Vector2(r, -r * 0.7)
	draw_line(p1, p2, col, 3.0)
	draw_line(p2, p3, col, 3.0)
