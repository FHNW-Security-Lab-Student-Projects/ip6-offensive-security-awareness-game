# The blinking "▼ klicken für weiter" affordance from the intro's dialog box, so
# a player can tell that running text may be hurried along with a click instead
# of waiting it out.
#
# Reuses DIALOG_HINT_CLICK, the key the intro already uses, so the wording and
# the arrow glyph stay defined in exactly one place.
#
# Referenced by preload path rather than a class_name, so the headless tests
# compile it without the editor's global class cache.
extends Label

const BLINK_INTERVAL: float = 0.5
const DIM_ALPHA: float = 0.25


func _ready() -> void:
	text = tr("DIALOG_HINT_CLICK")
	DarkMailPalette.apply_mono_label(
		self, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN
	)
	# Purely an affordance: it must never intercept the very click it advertises.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var _blink_acc: float = 0.0
var _lit: bool = true


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_acc += delta
	if _blink_acc < BLINK_INTERVAL:
		return
	_blink_acc = 0.0
	_lit = not _lit
	modulate.a = 1.0 if _lit else DIM_ALPHA


# Shown while text is running, hidden once it has landed and the real buttons
# take over as the way forward.
func set_active(active: bool) -> void:
	visible = active
	if active:
		_blink_acc = 0.0
		_lit = true
		modulate.a = 1.0
