extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# The menu music lives in the persistent MusicPlayer autoload so it carries
	# over to the scenario selection; resume it in case a scenario stopped it.
	MusicPlayer.play_menu_music()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# The select blip is wired automatically for every button by the SfxPlayer
# autoload, so the handlers below only do navigation.
func _on_btn_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelAuswahl.tscn")


func _on_btn_einstellungen_pressed() -> void:
	pass


func _on_btn_beenden_pressed() -> void:
	pass
