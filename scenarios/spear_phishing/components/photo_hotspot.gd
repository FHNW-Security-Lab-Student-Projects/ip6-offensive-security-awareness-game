# A clickable "zoom" region overlaid on a photo. It docks onto the existing
# reveal logic: clicking it emits `activated`, which Recon routes to reveal()
# for the hidden find bound to this hotspot. Purely an alternative trigger — the
# same reveal(), the same parent_id chain, no logic of its own.
#
# Drawn, not textured (font-independent, like lock_icon / hud_brackets): faint
# green corner brackets that brighten on hover, echoing the HUD framing so a
# "there is something to zoom here" hint reads without giving away the leak.
# Referenced by path (preload) from Recon, not via a global class name.
extends Control

signal activated

const GREEN := DarkMailPalette.GREEN

var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		activated.emit()


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
	if _hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(GREEN, 0.14), true)
	var col := Color(GREEN, 0.9 if _hover else 0.35)
	var arm: float = min(w, h) * 0.28
	var t := 2.0
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]
	var dirs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for i in corners.size():
		var c := corners[i]
		var d := dirs[i]
		draw_line(c, c + Vector2(arm * d.x, 0), col, t)
		draw_line(c, c + Vector2(0, arm * d.y), col, t)
