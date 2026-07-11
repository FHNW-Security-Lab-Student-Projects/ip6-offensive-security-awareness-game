# Four green corner brackets drawn around this control's own rect — a HUD
# targeting frame. Place it as a sibling of the node to frame, slightly
# larger than that node's rect. Draw-only: the control ignores the mouse.
@tool
class_name HudBrackets
extends Control

@export var color := DarkMailPalette.GREEN:
	set(value):
		color = value
		queue_redraw()

@export_range(8.0, 120.0) var arm_length := 34.0:
	set(value):
		arm_length = value
		queue_redraw()

@export_range(1.0, 8.0) var thickness := float(DarkMailPalette.BORDER_WIDTH):
	set(value):
		thickness = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var arm: float = min(arm_length, min(w, h) * 0.5)
	# Each corner: one horizontal and one vertical arm meeting in the corner.
	var corners: Array[Vector2] = [
		Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h),
	]
	var dirs: Array[Vector2] = [
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
	]
	for i in corners.size():
		var c := corners[i]
		var d := dirs[i]
		draw_line(c, c + Vector2(arm * d.x, 0), color, thickness)
		draw_line(c, c + Vector2(0, arm * d.y), color, thickness)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
