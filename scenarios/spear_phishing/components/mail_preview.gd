# The current mail DRAFT. Static Von/An/Betreff header plus one body fragment per
# slotted card, in draft order. Purely visual: the text is each card's <ID>_FRAG
# i18n key. set_draft() rebuilds the body as the player slots/unslots cards; it
# resets to a placeholder between mails. The preview holds no logic.
extends PanelContainer

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")

var _body: VBoxContainer


func _ready() -> void:
	var panel := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, Color(DarkMailPalette.GREEN, 0.4), DarkMailPalette.BORDER_WIDTH)
	panel.content_margin_left = 20
	panel.content_margin_right = 20
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	add_theme_stylebox_override("panel", panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	DarkMailPalette.apply_mono_label(
		title, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.GREEN)
	title.text = tr("MAIL_PREVIEW_TITLE")
	root.add_child(title)

	root.add_child(_header_row("MAIL_PREVIEW_FROM_LABEL", "MAIL_PREVIEW_FROM_VALUE"))
	root.add_child(_header_row("MAIL_PREVIEW_TO_LABEL", "MAIL_PREVIEW_TO_VALUE"))
	root.add_child(_header_row("MAIL_PREVIEW_SUBJECT_LABEL", "MAIL_PREVIEW_SUBJECT_VALUE"))

	var sep := HSeparator.new()
	root.add_child(sep)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	set_draft([])


func _header_row(label_key: String, value_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.custom_minimum_size.x = 90
	DarkMailPalette.apply_mono_label(
		label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	label.text = tr(label_key)
	row.add_child(label)
	var value := Label.new()
	DarkMailPalette.apply_mono_label(
		value, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
	value.text = tr(value_key)
	row.add_child(value)
	return row


# Rebuilds the draft body from the currently slotted cards (draft order). Empty
# draft shows a placeholder. Schrott/trap fragments read as honestly off-key body
# text — that is how the player sees what a bad card does to the mail.
func set_draft(cards: Array) -> void:
	# Immediate free (not queue_free): a from-scratch rebuild must not leave the
	# previous frame's deferred-free lines lingering in the body.
	for child in _body.get_children():
		child.free()
	if cards.is_empty():
		var placeholder := Label.new()
		DarkMailPalette.apply_mono_label(
			placeholder, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
		placeholder.text = "…"
		_body.add_child(placeholder)
		return
	for card in cards:
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		DarkMailPalette.apply_mono_label(
			line, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
		line.text = tr("MAIL_%s_FRAG" % String(card.id).to_upper())
		_body.add_child(line)
