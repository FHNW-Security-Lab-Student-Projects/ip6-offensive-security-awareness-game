# Turns the finds of one source into widgets and arranges them. The collect
# interaction comes from the host and is identical on every platform — only the
# surrounding presentation differs. A new platform is a new subclass plus a case
# in Recon._page_for, never a new scene.
#
# What subclasses may call on `host`:
#   build_leak_body(find) -> Control     the shared clickable body
#   build_photo_card(find) -> Control    image surface with caption + hotspots
#   photo_texture(find) -> Texture2D     the find's photo, or the default
#   attach_hotspots(find, image)         overlays the hidden finds on a photo
extends RefCounted


# Populates the finds column with this source's finds.
func build(host, container: Control, finds: Array) -> void:
	var target := _make_layout(container)
	for find in finds:
		var widget := _widget_for(host, find)
		if widget != null:
			target.add_child(widget)


# List pages build straight into the VBox; a grid page returns its own.
func _make_layout(container: Control) -> Control:
	return container


# A find with a hotspot is collected on its parent photo and renders no card
# here. Photo finds become the image surface, everything else build_card.
func _widget_for(host, find) -> Control:
	if find.has_hotspot():
		return null
	if find.kind == &"photo":
		return host.build_photo_card(find)
	return build_card(host, find)


# The platform's card for an ordinary find. Override.
func build_card(_host, _find) -> Control:
	push_error("SourcePage.build_card must be overridden")
	return Control.new()
