# The mail thread: the exchange between the player and Hannes. A static
# Von/An/Betreff header sits above a scrollable list of message bubbles —
# outgoing (your drafted/sent mails, green) and incoming (Hannes' replies,
# amber). The bottom bubble is the live DRAFT: fragments type themselves in as
# cards are slotted (skippable), then it is sealed on send and a reply is
# appended. Purely visual: fragment text is each card's <ID>_FRAG i18n key, the
# reply text is passed in. No logic, no thresholds.
extends PanelContainer

const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")

# Writing speed of the draft typewriter, in characters per second. Tuning knob.
const TYPE_CPS := 45.0

var replies: int = 0  # test/inspection: how many Hannes replies are in the thread

var _thread: VBoxContainer
var _scroll: ScrollContainer
var _draft_body: VBoxContainer      # body of the live draft bubble (null once sealed)
var _draft_placeholder: Label
var _typing_tween: Tween
var _typing_label: Label


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

	root.add_child(_header_row("MAIL_PREVIEW_TO_LABEL", "MAIL_PREVIEW_TO_VALUE"))
	root.add_child(_header_row("MAIL_PREVIEW_SUBJECT_LABEL", "MAIL_PREVIEW_SUBJECT_VALUE"))

	root.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)

	_thread = VBoxContainer.new()
	_thread.add_theme_constant_override("separation", 12)
	_thread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_thread)

	begin_new_draft()


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


# --- message bubbles ---------------------------------------------------------

# Builds a bubble (sender label + empty body) and returns its body container.
func _make_bubble(sender_key: String, accent: Color) -> VBoxContainer:
	var bubble := PanelContainer.new()
	var box := DarkMailPalette.flat_box(DarkMailPalette.BG_FIELD, accent, DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	bubble.add_child(col)

	var sender := Label.new()
	DarkMailPalette.apply_mono_label(sender, DarkMailPalette.FONT_SIZE_MONO_SMALL, accent)
	sender.text = tr(sender_key)
	col.add_child(sender)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	_thread.add_child(bubble)
	_scroll_to_bottom()
	return body


func _body_line(text: String) -> Label:
	var line := Label.new()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DarkMailPalette.apply_mono_label(
		line, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
	line.text = text
	return line


# --- draft (outgoing, live) --------------------------------------------------

# Opens a fresh empty draft bubble at the bottom of the thread.
func begin_new_draft() -> void:
	_draft_body = _make_bubble("MAIL_SENDER_YOU", DarkMailPalette.GREEN)
	_draft_placeholder = Label.new()
	DarkMailPalette.apply_mono_label(
		_draft_placeholder, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	_draft_placeholder.text = "…"
	_draft_body.add_child(_draft_placeholder)


# Appends one fragment to the draft; types it in when animate is set.
func add_draft_fragment(card, animate: bool) -> void:
	if _draft_body == null:
		return
	if _draft_placeholder != null:
		_draft_placeholder.free()
		_draft_placeholder = null
	var line := _body_line(tr("MAIL_%s_FRAG" % String(card.id).to_upper()))
	_draft_body.add_child(line)
	_scroll_to_bottom()
	if animate:
		_typewriter(line)


# Rebuilds the draft body from scratch (used on unslot; no typewriter).
func rebuild_draft(cards: Array) -> void:
	finish_typing()
	if _draft_body == null:
		return
	for child in _draft_body.get_children():
		child.free()
	_draft_placeholder = null
	if cards.is_empty():
		_draft_placeholder = Label.new()
		DarkMailPalette.apply_mono_label(
			_draft_placeholder, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
		_draft_placeholder.text = "…"
		_draft_body.add_child(_draft_placeholder)
		return
	for card in cards:
		_draft_body.add_child(_body_line(tr("MAIL_%s_FRAG" % String(card.id).to_upper())))


# Freezes the current draft: it stays in the thread as a sent mail.
func seal_draft() -> void:
	finish_typing()
	_draft_body = null
	_draft_placeholder = null


# --- Hannes reply (incoming) -------------------------------------------------

func add_reply(text: String) -> void:
	var body := _make_bubble("MAIL_SENDER_HANNES", DarkMailPalette.WARN_AMBER)
	var line := _body_line(text)
	line.add_theme_color_override("font_color", DarkMailPalette.TEXT_GREEN)
	body.add_child(line)
	replies += 1


# --- typewriter --------------------------------------------------------------

func _typewriter(label: Label) -> void:
	finish_typing()
	label.visible_ratio = 0.0
	var duration := clampf(label.text.length() / TYPE_CPS, 0.15, 1.2)
	_typing_label = label
	_typing_tween = create_tween()
	_typing_tween.tween_property(label, "visible_ratio", 1.0, duration)
	_typing_tween.tween_callback(_clear_typing)


# Completes any running typewriter at once — never blocking.
func finish_typing() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	if _typing_label != null:
		_typing_label.visible_ratio = 1.0
	_clear_typing()


func _clear_typing() -> void:
	_typing_tween = null
	_typing_label = null


func _scroll_to_bottom() -> void:
	_scroll.set_deferred("scroll_vertical", 1_000_000)
