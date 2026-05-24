# Sub-state 4: outcome screen. Placeholder UI; real win/lose flavor and
# stats arrive alongside Phase 4. Emits advance_requested when the
# player acknowledges the result; the scenario then calls
# complete_scenario() and the engine transitions to FEEDBACK.
extends Control

signal advance_requested

func _on_advance_button_pressed() -> void:
	advance_requested.emit()
