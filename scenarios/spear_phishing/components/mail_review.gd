# The optional turn-by-turn review, opened from Resolve. VIEW plus pure
# derivation: it reads the recorded mail history and the collected finds, judges
# each card by its TYPE, and flags legendaries whose ingredients were collected
# but never played — the Pool's own unlock rules, asked in reverse.
#
# A full-screen child of Resolve; the Back button emits close_requested so the
# owner can free it.
extends Control

const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")

signal close_requested

const BODY_WIDTH := 860

# The ids come straight from Pool.LEGENDARIES; the texts are per combination.
const MISSED_KEYS := {
	&"perfekter_absender": "REVIEW_MISSED_PERFEKTER_ABSENDER",
	&"echter_vorwand": "REVIEW_MISSED_ECHTER_VORWAND",
	&"verifiziert": "REVIEW_MISSED_VERIFIZIERT",
	&"identitaet_gesichert": "REVIEW_MISSED_IDENTITAET",
}

var _turn_count := 0            # rows built (== sent-mail count); read by tests
var _missed: Array = []         # missed legendary ids shown; read by tests


# --- pure derivation (unit-tested, no UI) ------------------------------------

# One verdict per card TYPE, not per card. EPIC and LEGENDARY share one.
static func verdict_key(card_type: int) -> String:
	match card_type:
		MailCard.Type.STANDARD:
			return "REVIEW_VERDICT_STANDARD"
		MailCard.Type.SCHROTT:
			return "REVIEW_VERDICT_SCHROTT"
		MailCard.Type.PAYLOAD:
			return "REVIEW_VERDICT_PAYLOAD"
		_:
			return "REVIEW_VERDICT_EPIC"


# The unlock question in reverse, against the same Pool rules: which legendaries
# could have been built from what was collected, but never were.
static func missed_legendary_ids(collected: Array, played: Array, probe_done: bool) -> Array:
	var missed: Array = []
	for lid in Pool.unlocked_legendary_ids(collected, probe_done):
		if not played.has(lid):
			missed.append(lid)
	return missed


# --- build -------------------------------------------------------------------

func configure(mail_result: Dictionary, collected: Array, probe_done: bool) -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_add_background()

	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 80
	col.offset_top = 96
	col.offset_right = -80
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 24)
	add_child(col)

	var title := _make_label(tr("REVIEW_TITLE"), DarkMailPalette.FONT_SIZE_MONO_LARGE, DarkMailPalette.GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# The Back button rides at the end of the scrolled content instead of being
	# pinned, so a short debrief has no dead gap before it.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	_build_turns(list, mail_result.get("history", []))
	list.add_child(_spacer(16))
	_build_missed(list, collected, mail_result.get("played", []), probe_done)
	list.add_child(_spacer(28))
	list.add_child(_build_back_button())


func _add_background() -> void:
	var bg := ColorRect.new()
	bg.color = DarkMailPalette.BG_PANEL
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)


# --- turn list ---------------------------------------------------------------

func _build_turns(list: VBoxContainer, history: Array) -> void:
	_turn_count = history.size()
	for i in history.size():
		list.add_child(_build_turn_card(i + 1, history[i]))


func _build_turn_card(number: int, entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, Color(DarkMailPalette.GREEN, 0.35), DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	vb.add_child(_make_label(
		tr("REVIEW_TURN") % number, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN_BRIGHT))

	# One line per card in the mail, judged by its type.
	for id in entry.get("card_ids", []):
		var card = Pool.card_for_id(id)
		if card == null:
			continue
		var line := "%s: %s" % [tr(card.name_key()), tr(verdict_key(card.type))]
		vb.add_child(_make_paragraph(line, _verdict_color(card.type)))

	vb.add_child(_make_label(
		_bar_summary(entry), DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM))
	return panel


# "MISSTRAUEN 4 -> 5 (+1)    HANDLUNGSDRUCK 3 -> 7 (+4)"
func _bar_summary(entry: Dictionary) -> String:
	var s: String = "%s %d → %d (%s)" % [
		tr("MAIL_BAR_SUSPICION"), int(entry["suspicion_before"]), int(entry["suspicion_after"]),
		_signed(int(entry["suspicion_after"]) - int(entry["suspicion_before"]))]
	var p: String = "%s %d → %d (%s)" % [
		tr("MAIL_BAR_PRESSURE"), int(entry["pressure_before"]), int(entry["pressure_after"]),
		_signed(int(entry["pressure_after"]) - int(entry["pressure_before"]))]
	return "%s    %s" % [s, p]


func _signed(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	if delta < 0:
		return "%d" % delta
	return "±0"


# By decision quality: SCHROTT is the clear mistake, STANDARD and the payload are
# neutral, the recon-backed types are the good plays.
func _verdict_color(card_type: int) -> Color:
	match card_type:
		MailCard.Type.SCHROTT:
			return DarkMailPalette.ALERT_RED
		MailCard.Type.STANDARD, MailCard.Type.PAYLOAD:
			return DarkMailPalette.WARN_AMBER
		_:
			return DarkMailPalette.GREEN


# --- missed legendaries ------------------------------------------------------

func _build_missed(list: VBoxContainer, collected: Array, played: Array, probe_done: bool) -> void:
	_missed = missed_legendary_ids(collected, played, probe_done)
	list.add_child(_make_label(
		tr("REVIEW_MISSED_TITLE"), DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN))
	if _missed.is_empty():
		list.add_child(_make_paragraph(tr("REVIEW_NO_MISSED"), DarkMailPalette.TEXT_DIM))
		return
	for lid in _missed:
		var key: String = MISSED_KEYS.get(lid, "")
		if key.is_empty():
			continue
		list.add_child(_make_paragraph(tr(key), DarkMailPalette.TEXT_GREEN))


# --- back button + label helpers ---------------------------------------------

func _build_back_button() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var button := Button.new()
	button.text = tr("REVIEW_BACK")
	_style_button(button)
	button.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(button)
	return row


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	DarkMailPalette.apply_mono_label(label, size, color)
	label.text = text
	return label


func _make_paragraph(text: String, color: Color) -> Label:
	var label := _make_label(text, DarkMailPalette.FONT_SIZE_MONO, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = BODY_WIDTH
	return label


func _style_button(button: Button) -> void:
	var normal := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	var hover := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.22), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	for sb in [normal, hover]:
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", DarkMailPalette.FONT_MONO)
	button.add_theme_font_size_override("font_size", DarkMailPalette.FONT_SIZE_MONO)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, DarkMailPalette.GREEN)
