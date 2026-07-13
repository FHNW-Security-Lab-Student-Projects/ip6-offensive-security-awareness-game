# kmunu: an employer-review list. Each card leads with a drawn star rating and
# a reviewer line, then the review title and the review body (which carries the
# leak). Star count comes from the RECON_<id>_STARS content key.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")
const StarRating := preload("res://scenarios/spear_phishing/components/star_rating.gd")


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card_box(false, false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_stars(host, find))
	var reviewer := Label.new()
	Style.apply_label(reviewer, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	reviewer.text = host.tr(find.author_key())
	reviewer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(reviewer)
	col.add_child(header)

	var title := Label.new()
	Style.apply_label(title, Style.FONT_SIZE_BODY, Style.COLOR_TEXT, true)
	title.text = host.tr(find.title_key())
	col.add_child(title)

	col.add_child(host.build_leak_body(find))
	return card


func _stars(host, find) -> Control:
	var sr := StarRating.new()
	sr.total = 5
	sr.filled = clampi(int(host.tr(find.key("STARS"))), 0, 5)
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return sr
