# Sub-state 1: boss briefing. Placeholder UI; real dialog box + mission
# banner arrive in Phase 2. Emits advance_requested when the player is
# ready to move on to Recon.
extends Control

signal advance_requested

func _on_advance_button_pressed() -> void:
	advance_requested.emit()
