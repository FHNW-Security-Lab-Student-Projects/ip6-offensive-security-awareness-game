# Types a Label out character by character, and can be finished early by a click.
#
# The owner drives it: start(), then advance(delta) from _process, finish_now()
# on a click. Used by the NPC dialogue and the debrief in bad_usb.
#
# Preload path instead of class_name: a bare `godot -s` run has no global class
# cache.
extends RefCounted

signal finished

# Matches the intro's DialogBox, so both screens read at the same speed.
const DEFAULT_SPEED: float = 40.0

var _label: Label = null
var _full_text: String = ""
var _chars_shown: float = 0.0
var _speed: float = DEFAULT_SPEED
var _typing: bool = false


func is_typing() -> bool:
	return _typing


# Starting a new line while one runs simply replaces it; the caller sequences.
func start(label: Label, text: String, speed: float = DEFAULT_SPEED) -> void:
	_label = label
	_full_text = text
	_speed = speed
	_chars_shown = 0.0
	if label == null:
		_typing = false
		return
	label.text = text
	# visible_characters, not string slicing: the label keeps its full layout from
	# frame one, so the box does not grow line by line and nothing below jumps.
	label.visible_characters = 0
	_typing = not text.is_empty()
	if not _typing:
		label.visible_characters = -1
		finished.emit()


func advance(delta: float) -> void:
	if not _typing or _label == null:
		return
	_chars_shown += delta * _speed
	if int(_chars_shown) >= _full_text.length():
		finish_now()
		return
	_label.visible_characters = int(_chars_shown)


# Safe to call when nothing is running.
func finish_now() -> void:
	if not _typing:
		return
	_typing = false
	if _label != null:
		_label.visible_characters = -1  # -1 = show everything
	finished.emit()
