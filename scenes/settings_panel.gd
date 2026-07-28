# Settings overlay for the title screen: volume sliders (master / music / SFX),
# a fullscreen checkbox and a reset. Built in code in the MENU look (white field,
# black pixel frame, mono font) so it matches the title screen buttons rather
# than the in-scenario terminal style. Reads and writes the Settings autoload,
# which applies each change to the audio buses immediately and persists it.
extends Control

signal closed

const MenuStyle := preload("res://resources/theme/menu_style.gd")

const ROW_LABEL_WIDTH := 300
const SLIDER_WIDTH := 420
const PANEL_WIDTH := 900


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := MenuStyle.flat_box(MenuStyle.PANEL_FILL)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 30
	box.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)

	var col := VBoxContainer.new()
	col.custom_minimum_size.x = PANEL_WIDTH
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)

	var title := Label.new()
	MenuStyle.apply_label(title, MenuStyle.FONT_SIZE_LARGE)
	title.text = tr("SETTINGS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(_slider_row("SETTINGS_MASTER", Settings.master_volume, Settings.set_master_volume))
	col.add_child(_slider_row("SETTINGS_MUSIC", Settings.music_volume, Settings.set_music_volume))
	col.add_child(_slider_row("SETTINGS_SFX", Settings.sfx_volume, Settings.set_sfx_volume))
	col.add_child(_checkbox_row("SETTINGS_FULLSCREEN", Settings.fullscreen))
	col.add_child(_language_row())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	buttons.add_child(_button("SETTINGS_RESET", _on_reset))
	buttons.add_child(_button("SETTINGS_CLOSE", func() -> void: closed.emit()))
	col.add_child(buttons)


# --- rows ---------------------------------------------------------------------

func _slider_row(key: String, value: float, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	MenuStyle.apply_label(name_label)
	name_label.text = tr(key)
	name_label.custom_minimum_size.x = ROW_LABEL_WIDTH
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var value_label := Label.new()
	MenuStyle.apply_label(value_label)
	value_label.text = _percent(value)
	value_label.custom_minimum_size.x = 90
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value_label.text = _percent(v))
	return row


func _checkbox_row(key: String, pressed: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	MenuStyle.apply_label(name_label)
	name_label.text = tr(key)
	name_label.custom_minimum_size.x = ROW_LABEL_WIDTH
	row.add_child(name_label)

	var check := CheckBox.new()
	check.button_pressed = pressed
	MenuStyle.style_checkbox(check)
	check.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	row.add_child(check)
	return row


# One button per language, the active one highlighted like the primary menu
# entry. Switching rebuilds this panel so its own labels flip immediately.
#
# Only available from the menus. A Control re-translates its text at draw time
# only when the stored text is a translation key, and the scenarios resolve
# theirs through tr() at build time, so switching mid-scenario would leave the
# running screen in the old language. Locking it here keeps a run in exactly one
# language, which the study needs anyway.
func _language_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	MenuStyle.apply_label(name_label)
	name_label.text = tr("SETTINGS_LANGUAGE")
	name_label.custom_minimum_size.x = ROW_LABEL_WIDTH
	row.add_child(name_label)

	var unlocked: bool = GameState.is_in_menu()
	for entry in [["de", "Deutsch"], ["en", "English"]]:
		var code: String = entry[0]
		var button := Button.new()
		button.text = entry[1]
		MenuStyle.style_button(button, Settings.locale == code)
		button.disabled = not unlocked
		button.pressed.connect(func() -> void:
			if Settings.locale != code:
				Settings.set_locale(code)
				_rebuild())
		row.add_child(button)

	if not unlocked:
		var hint := Label.new()
		MenuStyle.apply_label(hint)
		hint.text = tr("SETTINGS_LANGUAGE_MENU_ONLY")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
	return row


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _on_reset() -> void:
	Settings.reset_to_defaults()
	_rebuild()  # so every control shows the restored values


# --- helpers ------------------------------------------------------------------

func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _button(key: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = tr(key)
	MenuStyle.style_button(button)
	button.pressed.connect(on_press)
	return button


# Black-on-white pixel slider: a thin dark track, a solid filled part and a
# chunky square grabber, matching the hard-edged menu buttons.
func _style_slider(slider: HSlider) -> void:
	var track := MenuStyle.flat_box(MenuStyle.PANEL_FILL, MenuStyle.INK, 2)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	var filled := MenuStyle.flat_box(MenuStyle.PANEL_ALT, MenuStyle.INK, 2)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var grabber := _grabber_texture()
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)


func _grabber_texture() -> ImageTexture:
	var w := 14
	var h := 26
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(MenuStyle.INK)
	for y in range(3, h - 3):
		for x in range(3, w - 3):
			image.set_pixel(x, y, MenuStyle.PANEL_FILL)
	return ImageTexture.create_from_image(image)
