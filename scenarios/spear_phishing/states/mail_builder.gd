# Sub-state 3: DarkMail composer (the card game). Placeholder UI; real
# hand/deck/status/boss-chat arrive in Phase 4. Emits advance_requested
# when the mail is sent (or the run otherwise ends) to move on to
# Resolve.
extends Control

signal advance_requested

func _on_advance_button_pressed() -> void:
	advance_requested.emit()
