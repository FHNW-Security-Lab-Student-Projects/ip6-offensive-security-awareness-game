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


# Photo finds render as this platform's own square image card (with hotspots),
# not the generic feed photo card. Hotspot finds are skipped by super (they live
# on their parent photo).
func _widget_for(host, find) -> Control:
	if find.kind == &"photo" and not find.has_hotspot():
		return build_card(host, find)
	return super._widget_for(host, find)


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
	# No clip_contents: it would cut off a hotspot's hover hint at the card edge.
	# COVERED already crops the image; the trade-off is square (not rounded) image
	# corners, which is barely visible at this radius.

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# Square image: fixed height == column width, cropped to fill by COVERED. A
	# fixed custom_minimum_size avoids AspectRatioContainer reporting a zero
	# min-height inside a VBox (which would let the image overlap the text).
	var img := TextureRect.new()
	img.texture = PLACEHOLDER
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(COLUMN_W, COLUMN_W)
	col.add_child(img)
	# Overlay any hotspots for hidden children pointing at this find (e.g. the
	# mail schema on the screen behind Kevin). No-op for finds without children.
	host.attach_hotspots(find, img)

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
