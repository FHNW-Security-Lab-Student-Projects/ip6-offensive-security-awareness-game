# One playable hand card: type as colour and label, the name, and the full text
# in the tooltip. Deliberately NO effect indicator — the player has to judge the
# card's CONTENT, not read arrows off it. The bars move only after sending.
#
# Slot and enabled state come from the controller; the card owns no thresholds.
extends PanelContainer

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

signal clicked(card)

const CARD_SIZE := Vector2(196, 132)
const PULSE_BRIGHT := Color(1.7, 1.55, 1.15)  # amber-ish glow over the base style
const PULSE_HALF_TIME := 0.4
const ARROW_SIZE := Vector2(26, 14)
const ARROW_BOB := 6.0        # vertical bob distance of the payload arrow
const ARROW_BOB_TIME := 0.35

var card: MailCard
var _enabled := true
var _slotted := false
var _pulse_tween: Tween
var _arrow: Control
var _arrow_tween: Tween
var _info_overlay: Control


func setup(c: MailCard) -> void:
	card = c
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = tr(card.text_key())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var type_tag := Label.new()
	DarkMailPalette.apply_mono_label(
		type_tag, DarkMailPalette.FONT_SIZE_MONO_SMALL, _accent_color())
	type_tag.text = _type_tag_text()
	box.add_child(type_tag)

	var name_label := Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	DarkMailPalette.apply_mono_label(
		name_label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	name_label.text = tr(card.name_key())
	box.add_child(name_label)

	_build_arrow()
	_build_info_badge()
	_restyle()


# Affordance only — hovering anywhere on the card shows the tooltip. On the armed
# payload it yields to the arrow, which shares the corner.
func _build_info_badge() -> void:
	_info_overlay = Control.new()
	_info_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_overlay)

	var badge := Label.new()
	badge.text = "[i]"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DarkMailPalette.apply_mono_label(badge, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.GREEN)
	_info_overlay.add_child(badge)
	_info_overlay.resized.connect(func() -> void:
		var s := badge.get_minimum_size()
		badge.position = Vector2(_info_overlay.size.x - s.x - 4.0, 2.0))


# Replaces Godot's default grey tooltip box with the DarkMail look.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var box := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 360
	DarkMailPalette.apply_mono_label(
		label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	panel.add_child(label)
	return panel


# --- live state --------------------------------------------------------------

# Playability is a run fact: the widget asks the run and owns no thresholds.
func refresh(run) -> void:
	_enabled = run.card_playable(card)
	_restyle()
	_update_pulse()


func set_slotted(slotted: bool) -> void:
	_slotted = slotted
	_restyle()
	_update_pulse()


# Points out the acting card during the staggered reveal.
func flash() -> void:
	if _is_pulsing():
		return  # the pulse already owns modulate and draws more attention anyway
	modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)


# --- payload pulse -------------------------------------------------------------

# The armed payload pulses and grows a bobbing arrow while it is playable and
# not yet drafted, so an open gate cannot be overlooked. Slotting it, or the run
# ending, stops both and restores the static style.
func _is_pulsing() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()


func _should_pulse() -> bool:
	return card.type == MailCard.Type.PAYLOAD and _enabled and not _slotted


func _update_pulse() -> void:
	if _should_pulse():
		if _is_pulsing():
			return
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(self, "modulate", PULSE_BRIGHT, PULSE_HALF_TIME)
		_pulse_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), PULSE_HALF_TIME)
		_arrow.visible = true
		if _info_overlay != null:
			_info_overlay.visible = false  # arrow takes over the top-right corner
		_arrow_tween = create_tween().set_loops()
		_arrow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_arrow_tween.tween_property(_arrow, "position:y", ARROW_BOB, ARROW_BOB_TIME)
		_arrow_tween.tween_property(_arrow, "position:y", 0.0, ARROW_BOB_TIME)
	elif _is_pulsing():
		_pulse_tween.kill()
		_pulse_tween = null
		if _arrow_tween != null and _arrow_tween.is_valid():
			_arrow_tween.kill()
		_arrow_tween = null
		_arrow.visible = false
		_arrow.position.y = 0.0
		if _info_overlay != null:
			_info_overlay.visible = true
		_apply_modulate()


# --- payload arrow: a bobbing pointer drawn over the armed payload -------------

# The wrapper is fitted to the panel's content rect; the arrow inside it sits
# outside any container layout, which is what lets it bob.
class ArrowMarker extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2.ZERO,
			Vector2(size.x, 0.0),
			Vector2(size.x * 0.5, size.y),
		]), DarkMailPalette.WARN_AMBER)


func _build_arrow() -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_arrow = ArrowMarker.new()
	_arrow.size = ARROW_SIZE
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	overlay.add_child(_arrow)
	overlay.resized.connect(func() -> void:
		_arrow.position.x = maxf(0.0, overlay.size.x - ARROW_SIZE.x - 6.0))


func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play_select()  # not a BaseButton, so the blip is not auto-wired
		clicked.emit(card)


# --- styling -----------------------------------------------------------------

func _restyle() -> void:
	var border := DarkMailPalette.GREEN_BRIGHT if _slotted else _accent_color()
	var bg := Color(DarkMailPalette.GREEN, 0.14) if _slotted else DarkMailPalette.BG_FIELD
	var box := DarkMailPalette.flat_box(bg, border, DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	add_theme_stylebox_override("panel", box)
	if not _is_pulsing():
		_apply_modulate()


func _apply_modulate() -> void:
	modulate = Color(1, 1, 1, 1) if _enabled else Color(1, 1, 1, 0.45)


func _accent_color() -> Color:
	match _display_type():
		MailCard.Type.LEGENDARY:
			return DarkMailPalette.GREEN_BRIGHT
		MailCard.Type.PAYLOAD:
			return DarkMailPalette.WARN_AMBER
		MailCard.Type.STANDARD:
			return DarkMailPalette.TEXT_DIM
		_:
			return DarkMailPalette.GREEN


func _type_tag_text() -> String:
	if card.grants_probe:
		return "PROBE"
	return MailCard.Type.keys()[_display_type()]


# Traps are NOT flagged: schrott wears the label and accent of whatever it
# masquerades as. Recognising junk from its text is the measured skill.
func _display_type() -> int:
	if card.type != MailCard.Type.SCHROTT:
		return card.type
	return MailCard.Type.STANDARD if Pool.is_generic(card.id) else MailCard.Type.EPIC
