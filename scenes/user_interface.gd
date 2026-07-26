extends Control

const SettingsPanel := preload("res://scenes/settings_panel.gd")
const MenuStyle := preload("res://resources/theme/menu_style.gd")

var _settings: Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# The menu music lives in the persistent MusicPlayer autoload so it carries
	# over to the scenario selection; resume it in case a scenario stopped it.
	MusicPlayer.play_menu_music()
	# Arcade slabs in the artwork's warm accent; the play button is the primary
	# one, so it is brighter, larger and glows.
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnLevels, true)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnEinstellungen)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnBeenden)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# The select blip is wired automatically for every button by the SfxPlayer
# autoload, so the handlers below only do navigation.
func _on_btn_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelAuswahl.tscn")


func _on_btn_einstellungen_pressed() -> void:
	if _settings != null and is_instance_valid(_settings):
		return  # already open
	_settings = SettingsPanel.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)


func _on_settings_closed() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
	_settings = null


func _on_btn_beenden_pressed() -> void:
	pass
