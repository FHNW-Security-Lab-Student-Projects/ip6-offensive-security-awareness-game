# Title screen: menu music, the styled menu buttons and their navigation.
extends Control

const MenuStyle := preload("res://resources/theme/menu_style.gd")


func _ready() -> void:
	# The menu music lives in the persistent MusicPlayer autoload so it carries
	# over to the scenario selection; resume it in case a scenario stopped it.
	MusicPlayer.play_menu_music()
	# Arcade slabs in the artwork's warm accent; the play button is the primary
	# one, so it is brighter and larger.
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnLevels, true)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnEinstellungen)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnBeenden)


# The select blip is wired automatically for every button by the SfxPlayer
# autoload, so the handlers below only do navigation.
func _on_btn_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelAuswahl.tscn")


func _on_btn_einstellungen_pressed() -> void:
	# The same overlay Escape opens, so there is one instance and one code path.
	SettingsMenu.open()


func _on_btn_beenden_pressed() -> void:
	get_tree().quit()
