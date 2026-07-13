# JobScoot: a job-listing look. A prominent job title, a small source/meta line,
# then the listing text (which carries the leak).
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card_box(false, false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var title := Label.new()
	Style.apply_label(title, Style.FONT_SIZE_TITLE, Style.COLOR_TEXT, true)
	title.text = host.tr(find.title_key())
	col.add_child(title)

	var meta := Label.new()
	Style.apply_label(meta, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED)
	meta.text = host.tr(find.author_key())
	col.add_child(meta)

	col.add_child(host.build_leak_body(find))
	return card
