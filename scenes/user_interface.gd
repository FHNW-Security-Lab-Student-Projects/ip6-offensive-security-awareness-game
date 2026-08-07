# Title screen: menu music, the styled menu buttons and their navigation.
extends Control

const MenuStyle := preload("res://resources/theme/menu_style.gd")

# Text inset inside the participant-code field.
const FIELD_PADDING_X := 18
const FIELD_PADDING_Y := 6


func _ready() -> void:
	# Nothing else returns the session to MENU. Without it the state stays on
	# FEEDBACK for the rest of the run and the language stays locked.
	GameState.transition_to(GameState.State.MENU)
	# On the autoload, so it carries over to the scenario selection. Resume in
	# case a scenario stopped it.
	MusicPlayer.play_menu_music()
	# The play button is the primary one, so it is brighter and larger.
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnLevels, true)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnEinstellungen)
	MenuStyle.style_menu_button($Monitorbereich/ButtonListe/BtnBeenden)
	_build_participant_field()


# In the corner rather than the menu column: an operator control for the study
# lead, not something the player acts on. Optional, so play is unaffected.
func _build_participant_field() -> void:
	var holder := PanelContainer.new()
	holder.name = "ParticipantRow"
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = 40
	holder.offset_top = -96
	holder.offset_right = 560
	holder.offset_bottom = -32
	var box := MenuStyle.flat_box(MenuStyle.PANEL_FILL)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	holder.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)

	var label := Label.new()
	MenuStyle.apply_label(label)
	label.text = tr("STUDY_PARTICIPANT_CODE")
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var field := LineEdit.new()
	field.name = "ParticipantCode"
	# Survives a return to the title screen, since GameState outlives the scene.
	field.text = GameState.participant_code
	field.max_length = GameState.PARTICIPANT_CODE_MAX_LENGTH
	field.custom_minimum_size = Vector2(200, 44)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The same padding on both, so the text does not shift on focus.
	field.add_theme_stylebox_override("normal", _field_box(MenuStyle.PANEL_ALT))
	field.add_theme_stylebox_override("focus", _field_box(MenuStyle.PANEL_FILL))
	field.add_theme_font_override("font", MenuStyle.FONT_MONO)
	field.add_theme_font_size_override("font_size", MenuStyle.FONT_SIZE)
	field.add_theme_color_override("font_color", MenuStyle.INK)
	field.add_theme_color_override("caret_color", MenuStyle.INK)
	field.text_changed.connect(GameState.set_participant_code)
	row.add_child(field)

	add_child(holder)


# flat_box carries no content margins, which would leave the text and the caret
# sitting on the border.
func _field_box(fill: Color) -> StyleBoxFlat:
	var box := MenuStyle.flat_box(fill)
	box.content_margin_left = FIELD_PADDING_X
	box.content_margin_right = FIELD_PADDING_X
	box.content_margin_top = FIELD_PADDING_Y
	box.content_margin_bottom = FIELD_PADDING_Y
	return box


# SfxPlayer wires the select blip for every button, so these only navigate.
func _on_btn_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelAuswahl.tscn")


func _on_btn_einstellungen_pressed() -> void:
	# The same overlay Escape opens: one instance, one code path.
	SettingsMenu.open()


func _on_btn_beenden_pressed() -> void:
	get_tree().quit()
