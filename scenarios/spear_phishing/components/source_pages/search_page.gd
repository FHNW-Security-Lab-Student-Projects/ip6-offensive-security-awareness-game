# Goggle: a classic search-results list — a blue title line, a green URL/result
# line, then the snippet (which carries the leak). Results sit on the page with
# no card outline, the way a search engine renders them.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.search_card_box())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var title := Label.new()
	Style.apply_label(title, Style.FONT_SIZE_TITLE, Style.COLOR_LINK)
	title.text = host.tr(find.title_key())
	col.add_child(title)

	var url := Label.new()
	Style.apply_label(url, Style.FONT_SIZE_SMALL, Style.COLOR_URL)
	url.text = host.tr(find.author_key())
	col.add_child(url)

	col.add_child(host.build_leak_body(find))
	return card
