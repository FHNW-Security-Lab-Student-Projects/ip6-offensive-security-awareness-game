# LinkBook (and default) feed: an author line above the shared clickable leak
# body, in a plain white post card.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.post_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var author := Label.new()
	Style.apply_label(author, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	author.text = host.tr(find.author_key())
	col.add_child(author)

	col.add_child(host.build_leak_body(find))
	return card
