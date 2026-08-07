# A rounded background behind an inline range of a RichTextLabel. The build has
# neither rounded inline backgrounds nor per-character rects, so this measures
# the text with the same font and places one StyleBox per wrapped line, drawn
# behind via show_behind_parent. Neutral by design: "in deck", not "correct".
class_name HighlightMarker
extends Control

var _target: RichTextLabel
var _font: Font
var _font_size: int = 22
var _start: int = 0
var _len: int = 0
var _fill := Color(0, 0, 0, 0)
var _border := Color(0, 0, 0, 0)
const RADIUS := 7


func setup(target: RichTextLabel, font: Font, font_size: int) -> void:
	_target = target
	_font = font
	_font_size = font_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_range(start: int, length: int) -> void:
	_start = start
	_len = length


func set_fill(fill: Color, border: Color) -> void:
	_fill = fill
	_border = border
	queue_redraw()


func _draw() -> void:
	if _target == null or _len <= 0 or _fill.a == 0.0:
		return
	var parsed := _target.get_parsed_text()
	var total := parsed.length()
	var hstart: int = clampi(_start, 0, total)
	var hend: int = clampi(_start + _len, 0, total)
	if hend <= hstart:
		return

	var sb := StyleBoxFlat.new()
	sb.bg_color = _fill
	sb.set_corner_radius_all(RADIUS)
	if _border.a > 0.0:
		sb.set_border_width_all(1)
		sb.border_color = _border

	var line_start := _target.get_character_line(hstart)
	var line_end := _target.get_character_line(hend - 1)
	for line in range(line_start, line_end + 1):
		var rng: Vector2i = _target.get_line_range(line)
		var seg_start: int = maxi(hstart, rng.x)
		var seg_end: int = mini(hend, rng.y)
		if seg_end <= seg_start:
			continue
		var prefix := parsed.substr(rng.x, seg_start - rng.x)
		var seg := parsed.substr(seg_start, seg_end - seg_start)
		var x := _font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var w := _font.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var y := _target.get_line_offset(line)
		var h := _target.get_line_height(line)
		draw_style_box(sb, Rect2(x - 4, y - 1, w + 8, h + 2))
