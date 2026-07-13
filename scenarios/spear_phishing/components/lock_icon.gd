# A small custom-drawn padlock for the browser URL bar. Drawn, not an emoji
# or a brand asset, so it renders identically regardless of the font.
@tool
class_name LockIcon
extends Control

@export var color := Color("1f9d55"):
	set(value):
		color = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(16, 18)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Body: rounded rectangle in the lower two thirds.
	var body := Rect2(w * 0.15, h * 0.42, w * 0.7, h * 0.5)
	draw_rect(body, color, true)
	# Shackle: an arc above the body.
	var center := Vector2(w * 0.5, h * 0.42)
	var radius := w * 0.22
	draw_arc(center, radius, PI, TAU, 16, color, 2.0, true)
	# Keyhole.
	draw_circle(Vector2(w * 0.5, h * 0.62), w * 0.08, Color("ffffff"))
