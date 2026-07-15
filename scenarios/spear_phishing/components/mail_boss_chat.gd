# The handler's chat column. Not a dialogue system: the controller decides which
# state-dependent line to push (from the MailRun state) and calls say(key); this
# node only renders the growing transcript. Each line's text is an i18n key.
extends PanelContainer

var _lines: VBoxContainer


func _ready() -> void:
	var panel := DarkMailPalette.flat_box(
		DarkMailPalette.BG_RAISED, Color(DarkMailPalette.GREEN, 0.4), DarkMailPalette.BORDER_WIDTH)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	add_theme_stylebox_override("panel", panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	DarkMailPalette.apply_mono_label(
		title, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.GREEN)
	title.text = tr("MAIL_BOSS_TITLE")
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 10)
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lines)


# Pushes one handler line. The controller guarantees each trigger fires once, so
# this node stays a dumb append-only transcript.
func say(line_key: String) -> void:
	var bubble := PanelContainer.new()
	var box := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, Color(DarkMailPalette.GREEN, 0.3), DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DarkMailPalette.apply_mono_label(
		label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
	label.text = tr(line_key)
	bubble.add_child(label)
	_lines.add_child(bubble)
