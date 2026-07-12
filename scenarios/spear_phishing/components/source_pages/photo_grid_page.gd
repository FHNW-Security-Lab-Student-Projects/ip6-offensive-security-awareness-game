# Instasnap: an image-centric grid. Every ordinary find renders as an image
# card (placeholder image + caption); the caption carries the leak via the
# shared body. Two columns so the tab reads as a photo feed, not a list.
#
# The placeholder image is a stand-in until real, AI-generated visuals land;
# swap PLACEHOLDER per find in Slice B when photo finds carry their own image.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")
const PLACEHOLDER: Texture2D = preload("res://assets/sprites/placeholder/officeInside.jpg")


func _make_layout(container: Control) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Style.GAP)
	grid.add_theme_constant_override("v_separation", Style.GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(grid)
	return grid


func build_card(host, find) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.post_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var img := TextureRect.new()
	img.texture = PLACEHOLDER
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	img.custom_minimum_size = Vector2(0, 220)
	col.add_child(img)

	var author := Label.new()
	Style.apply_label(author, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	author.text = host.tr(find.author_key())
	col.add_child(author)

	col.add_child(host.build_leak_body(find))
	return card
