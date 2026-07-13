# A clickable region on a photo that collects an embedded find directly. Hover
# brightens the corner brackets (and shows a hint bar, driven by Recon on the
# parent image); a click collects or uncollects the find. No reveal step and no
# standalone card: the find lives only here, on its parent photo.
#
# Drawn, not textured (font-independent, like lock_icon / hud_brackets): faint
# corner brackets that brighten on hover, a green fill with a check when
# collected. Referenced by path (preload) from Recon, not via a class name.
extends Control

signal clicked

const GREEN := DarkMailPalette.GREEN

var hint: String = ""
var collected: bool = false

var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_hint: String, p_collected: bool) -> void:
	hint = p_hint
	collected = p_collected


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# Only the collected state fills; hover just brightens the brackets so the
	# photo is not washed green.
	if collected:
		draw_rect(Rect2(Vector2.ZERO, size), Color(GREEN, 0.28), true)
		_draw_check(Vector2(w * 0.5, h * 0.5), min(w, h) * 0.2)
	var a := 0.95 if (_hover or collected) else 0.45
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
