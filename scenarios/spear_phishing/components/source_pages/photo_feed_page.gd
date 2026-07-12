# Instasnap: an Instagram-style feed — a single centred column of fixed width,
# each post a square image on top with the caption (carrying the leak) below.
# Image-centric on purpose: the platform reads as a photo feed, not a list.
#
# The placeholder image is a stand-in until real, AI-generated visuals land;
# swap PLACEHOLDER per find in Slice B when photo finds carry their own image.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")
const PLACEHOLDER: Texture2D = preload("res://assets/sprites/placeholder/officeInside.jpg")

# Feed column width; the square image derives its height from it. Centred in the
# page, so the tab reads as a narrow photo feed rather than a full-width list.
const COLUMN_W := 460


# Keep every widget (incl. the shared reveal button) within the centred column,
# so a hidden find's reveal control matches the feed width instead of spanning
# the whole page. Other tabs keep the full-width default (no override there).
func _widget_for(host, find) -> Control:
	var widget := super._widget_for(host, find)
	if widget is Button:
		widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		widget.custom_minimum_size = Vector2(COLUMN_W, 0)
	return widget


func build_card(host, find) -> Control:
	# Centred, fixed-width card. Zero the panel's own margins so the image sits
	# flush to the card edges; the caption below gets its own padding.
	var card := PanelContainer.new()
	var box := Style.post_box()
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(COLUMN_W, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.clip_contents = true

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# Square image: fixed height == column width, cropped to fill (clipped by the
	# card). A fixed custom_minimum_size avoids AspectRatioContainer reporting a
	# zero min-height inside a VBox (which would let the image overlap the text).
	var img := TextureRect.new()
	img.texture = PLACEHOLDER
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(COLUMN_W, COLUMN_W)
	col.add_child(img)

	# Caption block, padded away from the flush image.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Style.PAD)
	pad.add_theme_constant_override("margin_right", Style.PAD)
	pad.add_theme_constant_override("margin_top", Style.PAD)
	pad.add_theme_constant_override("margin_bottom", Style.PAD)
	col.add_child(pad)
	var caption := VBoxContainer.new()
	caption.add_theme_constant_override("separation", 6)
	pad.add_child(caption)

	var author := Label.new()
	Style.apply_label(author, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	author.text = host.tr(find.author_key())
	caption.add_child(author)

	caption.add_child(host.build_leak_body(find))
	return card
