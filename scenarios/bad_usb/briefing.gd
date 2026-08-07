# Placeholder only. bad_usb.gd frees this node at startup and instantiates
# scenario 1's briefing screen in its place; the button below never fires.
extends Control

signal advance_requested


func _on_button_pressed() -> void:
	advance_requested.emit()
