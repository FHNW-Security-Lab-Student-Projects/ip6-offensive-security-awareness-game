# A drawn 5-star rating. Font-independent (NotoSans has no star glyphs), so it
# renders identically everywhere — same reasoning as lock_icon.gd. Purely
# presentational: shows `filled` of `total` stars, no interaction.
# Referenced by path (preload) from review_page, not via a global class name.
@tool
extends Control

@export var filled := 0:
	set(value):
		filled = value
		_resize()
		queue_redraw()

@export var total := 5:
	set(value):
		total = value
		_resize()
		queue_redraw()

@export var star_size := 18.0:
	set(value):
		star_size = value
		_resize()
		queue_redraw()

@export var gap := 3.0
@export var color_filled := Color("f5a623")
@export var color_empty := Color("c9cfd8")


func _ready() -> void:
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(total * star_size + maxf(0.0, total - 1) * gap, star_size)


func _draw() -> void:
	var cy := size.y * 0.5
	for i in total:
		var cx := i * (star_size + gap) + star_size * 0.5
		_draw_star(Vector2(cx, cy), star_size * 0.5, i < filled)


func _draw_star(center: Vector2, radius: float, is_filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI / 2.0 + k * PI / 5.0
		var r := radius if k % 2 == 0 else radius * 0.42
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	if is_filled:
		draw_colored_polygon(pts, color_filled)
	else:
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, color_empty, 1.5, true)
