extends Control


func _on_texture_button_pressed() -> void:
	_launch_scenario(&"scene1")


func _on_texture_button_2_pressed() -> void:
	_launch_scenario(&"scene2")


func _on_zurueck_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StartScreen.tscn")


# Loads a scenario by id via the Config registry. Avoids hardcoding
# scene paths so scenarios can be moved/renamed without touching the menu.
func _launch_scenario(id: StringName) -> void:
	var cfg: ScenarioConfig = Config.get_scenario(id)
	if cfg == null:
		push_error("LevelAuswahl: scenario '%s' missing from Config registry" % id)
		return
	get_tree().change_scene_to_file(cfg.scene_path)
