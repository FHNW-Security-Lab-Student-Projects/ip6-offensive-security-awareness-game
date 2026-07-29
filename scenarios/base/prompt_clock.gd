# Measures the study's "Entscheidungszeit": the time between a choice becoming
# clickable and the player committing to it. Scenarios call mark() when a prompt
# appears and take() when it is answered.
#
# Preload path instead of class_name: a bare `godot -s tests/*.gd` run has no
# global class cache.
extends RefCounted

# Reported when no mark() preceded the decision. A sentinel rather than 0, so an
# un-instrumented path shows up as a gap instead of an instant answer.
const UNKNOWN: int = -1

var _shown_at_ms: int = 0


func mark() -> void:
	_shown_at_ms = Time.get_ticks_msec()


# Consumes the mark, so one prompt yields exactly one measurement.
func take() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	var elapsed_ms: int = Time.get_ticks_msec() - _shown_at_ms
	_shown_at_ms = 0
	return elapsed_ms


# Same, without consuming: for screens where one prompt yields several decisions,
# such as a browser page the player picks multiple finds from.
func elapsed() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	return Time.get_ticks_msec() - _shown_at_ms
