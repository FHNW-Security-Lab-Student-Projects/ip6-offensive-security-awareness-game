# Sub-state 2: Recon desktop. Placeholder UI; real DarkMail OS windows
# and info chips arrive in Phase 3. Emits advance_requested when the
# player finishes recon and moves on to the mail builder.
extends Control

signal advance_requested

func _on_advance_button_pressed() -> void:
	advance_requested.emit()
