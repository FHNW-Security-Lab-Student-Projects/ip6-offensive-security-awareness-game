# Base class for a platform-specific Recon page layout. A SourcePage turns the
# finds of one source into widgets and arranges them. The collect / reveal /
# leak interaction is provided by the host (the Recon control) and is identical
# on every platform — only the surrounding presentation differs. Adding a new
# platform = a new SourcePage subclass plus a case in Recon._page_for, never a
# new scene.
#
# Host contract (methods this class and its subclasses call on `host`):
#   build_leak_body(find) -> Control      shared clickable body (the ONLY collect path)
#   build_photo_card(find) -> Control     image surface with caption
#   build_reveal_button(find) -> Button   fallback reveal control for a hidden find
#   is_revealed(find) -> bool
#   is_reveal_available(find) -> bool
#   tr(key) -> String                     (built-in on the host Node)
#
# Subclasses extend this file by path and Recon preloads them, so no global
# class-name registration is required (headless runs work without an import).
extends RefCounted


# Populates `container` (the FindsContainer VBox) with the given source's finds.
func build(host, container: Control, finds: Array) -> void:
	var target := _make_layout(container)
	for find in finds:
		var widget := _widget_for(host, find)
		if widget != null:
			target.add_child(widget)


# List pages build straight into the VBox. A grid page overrides this to insert
# and return its own container.
func _make_layout(container: Control) -> Control:
	return container


# Shared routing: photo finds and hidden (unrevealed) finds render the same way
# on every platform; only the ordinary card differs (build_card, overridden).
# Returns null to skip a find entirely (revealed via a photo hotspot, or a
# hidden child whose parent is absent).
func _widget_for(host, find) -> Control:
	if find.is_hidden and not host.is_revealed(find):
		if find.has_hotspot():
			return null  # revealed by a hotspot on its parent photo, not here
		if not host.is_reveal_available(find):
			return null
		return host.build_reveal_button(find)
	if find.kind == &"photo":
		return host.build_photo_card(find)
	return build_card(host, find)


# Platform-specific card for an ordinary (visible, non-photo) find. Override.
func build_card(_host, _find) -> Control:
	push_error("SourcePage.build_card must be overridden")
	return Control.new()
