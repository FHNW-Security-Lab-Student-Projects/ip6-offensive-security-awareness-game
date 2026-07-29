# The blinking "▼ klicken für weiter" hint from the intro's dialog box, telling
# the player that running text can be hurried along with a click.
#
# Reuses DIALOG_HINT_CLICK so the wording and the arrow glyph stay in one place.
# Preload path instead of class_name: a bare `godot -s` run has no global class
# cache.
extends Label

const BLINK_INTERVAL: float = 0.5
const DIM_ALPHA: float = 0.25

var _blink_acc: float = 0.0
var _lit: bool = true


func _ready() -> void:
	text = tr("DIALOG_HINT_CLICK")
	DarkMailPalette.apply_mono_label(
		self, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN
	)
	# Must never intercept the very click it advertises.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_acc += delta
	if _blink_acc < BLINK_INTERVAL:
		return
	_blink_acc = 0.0
	_lit = not _lit
	modulate.a = 1.0 if _lit else DIM_ALPHA


# Shown while text runs, hidden once the real buttons take over.
func set_active(active: bool) -> void:
	visible = active
	if active:
		_blink_acc = 0.0
		_lit = true
		modulate.a = 1.0
