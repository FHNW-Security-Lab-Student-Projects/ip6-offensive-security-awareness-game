# Firmenseite: a plain corporate press page. A small dateline/source above a
# headline, then the press body (which carries the leak). Deliberately sober —
# no feed chrome, no avatars — so it reads as an official company page.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card_box(false, false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var dateline := Label.new()
	Style.apply_label(dateline, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED)
	dateline.text = host.tr(find.author_key())
	col.add_child(dateline)

	var headline := Label.new()
	Style.apply_label(headline, Style.FONT_SIZE_TITLE, Style.COLOR_TEXT, true)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.text = host.tr(find.title_key())
	col.add_child(headline)

	col.add_child(host.build_leak_body(find))
	return card
