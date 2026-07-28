# Types a Label out character by character, and can be finished early.
#
# Same feel as the intro's DialogBox: while text is still running a click jumps
# to the end of the line instead of skipping it, so a fast reader never has to
# wait and a slow one is not rushed. Extracted as its own object because two
# screens in bad_usb need it (the NPC dialogue and the debrief story) and
# neither should own a copy of the timing logic.
#
# The owner drives it: call start(), then advance(delta) from _process, and
# finish_now() on a click. Referenced by preload path, not a class_name, so the
# headless tests can compile it without the editor's global class cache.
extends RefCounted

signal finished

# Characters per second. The intro's DialogBox uses 40, so the two screens read
# at the same speed.
const DEFAULT_SPEED: float = 40.0

var _label: Label = null
var _full_text: String = ""
var _chars_shown: float = 0.0
var _speed: float = DEFAULT_SPEED
var _typing: bool = false


func is_typing() -> bool:
	return _typing


# Begins typing `text` into `label`. Starting a new line while one is running
# simply replaces it; the caller owns the sequencing.
func start(label: Label, text: String, speed: float = DEFAULT_SPEED) -> void:
	_label = label
	_full_text = text
	_speed = speed
	_chars_shown = 0.0
	if label == null:
		_typing = false
		return
	label.text = text
	# visible_characters rather than slicing the string: the label keeps its full
	# layout from the first frame, so the box does not grow line by line while
	# typing and the text below it never jumps.
	label.visible_characters = 0
	_typing = not text.is_empty()
	if not _typing:
		label.visible_characters = -1
		finished.emit()


# Call once per frame from the owner's _process while typing.
func advance(delta: float) -> void:
	if not _typing or _label == null:
		return
	_chars_shown += delta * _speed
	if int(_chars_shown) >= _full_text.length():
		finish_now()
		return
	_label.visible_characters = int(_chars_shown)


# Reveals the rest immediately. Safe to call when nothing is running.
func finish_now() -> void:
	if not _typing:
		return
	_typing = false
	if _label != null:
		_label.visible_characters = -1  # -1 = show everything
	finished.emit()
