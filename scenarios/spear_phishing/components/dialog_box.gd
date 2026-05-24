# Reusable dialog box with typewriter text.
#
# API:
#   play(lines, speaker)  - start showing a sequence of lines.
#   signal lines_finished - all lines have been shown AND the user has
#                           clicked past the last one.
#
# Click behaviour:
#   - line is still typing  -> jump to end of current line.
#   - line is fully shown   -> advance to next line, or emit
#                              lines_finished if this was the last one.
#
# Mouse input is captured by the Panel child; clicks outside the panel
# (e.g. on a Weiter button next to the dialog box) pass through.
class_name DialogBox
extends Control

signal lines_finished

@export var chars_per_second: float = 40.0
@export var caret_blink_interval: float = 0.5
@export var caret_glyph: String = "▌"

@onready var _panel: Panel = $Panel
@onready var _speaker_label: Label = $Panel/Margin/VBox/SpeakerLabel
@onready var _body_label: Label = $Panel/Margin/VBox/BodyLabel
@onready var _hint_label: Label = $Panel/Margin/VBox/HintLabel

var _lines: PackedStringArray = PackedStringArray()
var _line_idx: int = 0
var _char_acc: float = 0.0
var _typing: bool = false
var _caret_acc: float = 0.0
var _caret_on: bool = true

func _ready() -> void:
	_panel.gui_input.connect(_on_panel_input)
	_clear()

func play(lines: PackedStringArray, speaker: String = "") -> void:
	_lines = lines
	_line_idx = 0
	_speaker_label.text = speaker
	_speaker_label.visible = not speaker.is_empty()
	if _lines.is_empty():
		_clear()
		lines_finished.emit()
		return
	_start_line()

func _process(delta: float) -> void:
	if _typing:
		var target: String = _lines[_line_idx]
		_char_acc += delta * chars_per_second
		var visible_chars: int = int(_char_acc)
		if visible_chars >= target.length():
			_body_label.text = target
			_typing = false
			_hint_label.visible = true
			_hint_label.modulate.a = 1.0
			_caret_acc = 0.0
			_caret_on = true
		else:
			_body_label.text = target.substr(0, visible_chars)
	elif _line_idx < _lines.size():
		_caret_acc += delta
		if _caret_acc >= caret_blink_interval:
			_caret_acc = 0.0
			_caret_on = not _caret_on
			_hint_label.modulate.a = 1.0 if _caret_on else 0.25

func _start_line() -> void:
	_body_label.text = ""
	_char_acc = 0.0
	_typing = true
	_hint_label.visible = false

func _finish_line_now() -> void:
	_body_label.text = _lines[_line_idx]
	_typing = false
	_hint_label.visible = true
	_hint_label.modulate.a = 1.0
	_caret_acc = 0.0
	_caret_on = true

func _advance() -> void:
	_line_idx += 1
	if _line_idx >= _lines.size():
		_hint_label.visible = false
		lines_finished.emit()
		return
	_start_line()

func _clear() -> void:
	_body_label.text = ""
	_speaker_label.text = ""
	_speaker_label.visible = false
	_hint_label.visible = false

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _typing:
				_finish_line_now()
			else:
				_advance()
