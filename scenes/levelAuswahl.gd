extends Control

const MenuStyle := preload("res://resources/theme/menu_style.gd")


func _ready() -> void:
	# Returning here ends the previous scenario as far as the session state is
	# concerned. user_interface.gd makes the same call for the same reason.
	GameState.transition_to(GameState.State.MENU)
	# Resume in case a scenario stopped it before returning here.
	MusicPlayer.play_menu_music()
	MenuStyle.style_menu_button($MarginContainer2/VBoxContainer/ZurueckButton)


func _on_zurueck_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StartScreen.tscn")


# By id through the Config registry, not by scene path, so a scenario can be
# moved or renamed without touching the menu.
func _launch_scenario(id: StringName) -> void:
	var cfg: ScenarioConfig = Config.get_scenario(id)
	if cfg == null:
		push_error("LevelAuswahl: scenario '%s' missing from Config registry" % id)
		return
	SceneTransition.launch_scenario(cfg)



func _on_scene_1_button_pressed() -> void:
	_launch_scenario(&"spear_phishing")


func _on_scene_2_button_pressed() -> void:
	_launch_scenario(&"bad_usb")
