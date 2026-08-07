# The study's decision time: from a choice becoming clickable to the player
# committing. mark() when the prompt appears, take() when it is answered.
#
# Preload, no class_name: a bare `godot -s` run has no global class cache.
extends RefCounted

# No mark() preceded this decision. A sentinel, not 0, so an un-instrumented
# path shows up as a gap instead of an instant answer.
const UNKNOWN: int = -1

var _shown_at_ms: int = 0


func mark() -> void:
	_shown_at_ms = Time.get_ticks_msec()


# Consumes the mark: one prompt, one measurement.
func take() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	var elapsed_ms: int = Time.get_ticks_msec() - _shown_at_ms
	_shown_at_ms = 0
	return elapsed_ms


# Without consuming, for screens where one prompt yields several decisions.
func elapsed() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	return Time.get_ticks_msec() - _shown_at_ms
