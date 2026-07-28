# Measures the study's "Entscheidungszeit": the interval between a choice
# becoming actionable on screen and the player committing to it.
#
# Scenarios call mark() at the moment a prompt appears (dialogue rendered,
# button shown, menu opened) and take() at the moment the player answers. take()
# consumes the mark, so one prompt yields exactly one measurement.
#
# Deliberately NOT measuring from scene entry: the interesting number for the
# evaluation is deliberation time, not how long someone walked around first.
#
# Referenced by preload path rather than a global class_name, matching the rest
# of this codebase: a bare `godot -s tests/*.gd` run has no global class cache,
# so a class_name here would fail to resolve under the headless tests.
extends RefCounted

# Reported when a decision was made without a preceding mark(). Kept as an
# explicit sentinel rather than 0 so an un-instrumented path is visible as a gap
# in the data instead of masquerading as an instant decision.
const UNKNOWN: int = -1

var _shown_at_ms: int = 0


# Start the clock. Safe to call repeatedly; the latest call wins.
func mark() -> void:
	_shown_at_ms = Time.get_ticks_msec()


# Milliseconds since the last mark(), or UNKNOWN if no prompt was marked.
# Consumes the mark.
func take() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	var elapsed_ms: int = Time.get_ticks_msec() - _shown_at_ms
	_shown_at_ms = 0
	return elapsed_ms


# Milliseconds since the last mark() WITHOUT consuming it. For screens where one
# prompt yields several decisions (a browser page the player picks multiple
# finds from), so each decision is measured against the same reference point.
func elapsed() -> int:
	if _shown_at_ms == 0:
		return UNKNOWN
	return Time.get_ticks_msec() - _shown_at_ms
