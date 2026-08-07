# Instasnap: one centred column, each post a square image with the caption (which
# carries the leak) below. Image-centric on purpose, so the platform reads as a
# photo feed rather than a list.
extends "res://scenarios/spear_phishing/components/source_pages/source_page.gd"

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")

# The square image derives its height from this.
const COLUMN_W := 460


# Photo finds get this platform's square card instead of the generic one.
func _widget_for(host, find) -> Control:
	if find.kind == &"photo" and not find.has_hotspot():
		return build_card(host, find)
	return super._widget_for(host, find)


func build_card(host, find) -> Control:
	# Zero margins so the image sits flush to the card edges; the caption below
	# gets its own padding.
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
	# COVERED already crops; the cost is square image corners, barely visible at
	# this radius.

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	# A fixed minimum size, not an AspectRatioContainer: that reports a zero
	# min-height inside a VBox and lets the image overlap the text.
	var img := TextureRect.new()
	img.texture = host.photo_texture(find)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(COLUMN_W, COLUMN_W)
	col.add_child(img)
	# No-op for finds without hotspot children.
	host.attach_hotspots(find, img)

	# Padded away from the flush image.
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
