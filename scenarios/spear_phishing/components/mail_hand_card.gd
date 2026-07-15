# One playable hand card. It shows ONLY the type (as colour + label, with the
# schrott disguise) and the card name; the full text is the tooltip. There is
# deliberately NO effect indicator — the player must judge the card's CONTENT,
# not read arrows. The bar effect is revealed only after the mail is sent.
#
# Slot/enabled/consumed handling is driven by the controller; the card owns no
# logic and no thresholds.
extends PanelContainer

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

signal clicked(card)

const CARD_SIZE := Vector2(196, 132)

var card: MailCard
var _enabled := true
var _slotted := false


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

	_restyle()


# --- live state --------------------------------------------------------------

# The payload is clickable only when its gate is open (a visible bar fact, not an
# effect preview); every other card is clickable while the run is live.
func refresh(run) -> void:
	if card.type == MailCard.Type.PAYLOAD:
		_enabled = run.payload_gate_open() and not run.is_over() and run.turns_left > 0
	else:
		_enabled = not run.is_over() and run.turns_left > 0
	_restyle()


func set_slotted(slotted: bool) -> void:
	_slotted = slotted
	_restyle()


# A brief brightening used by the staggered reveal to point out the acting card.
func flash() -> void:
	modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)


func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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


# Traps are NOT visually flagged: schrott wears the same label and accent as the
# card it masquerades as (collected recon intel -> EPIC, a generic scam ->
# STANDARD). Recognising junk from its name/text is the measured skill.
func _display_type() -> int:
	if card.type != MailCard.Type.SCHROTT:
		return card.type
	return MailCard.Type.STANDARD if Pool.is_generic(card.id) else MailCard.Type.EPIC
