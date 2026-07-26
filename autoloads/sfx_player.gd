# Autoload: one-shot UI sound effects. Lives outside the scene tree of any
# screen, so a sound triggered by a button that immediately changes scene still
# plays out instead of being cut off with its scene.
extends Node

const SELECT_SFX := preload("res://assets/audio/menu_select.wav")
const SELECT_VOLUME_DB := -4.0

var _select: AudioStreamPlayer


func _ready() -> void:
	_select = AudioStreamPlayer.new()
	_select.stream = SELECT_SFX
	_select.volume_db = SELECT_VOLUME_DB
	add_child(_select)


# Menu confirmation blip: play on button presses in the menus.
func play_select() -> void:
	if _select != null:
		_select.play()
