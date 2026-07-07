# Data structure for a single recon find. Pure data, no behavior:
# card effects and bar values are out of scope for this slice.
class_name ReconFind
extends Resource

@export var id: StringName
@export var title: String
@export var source: String
@export var is_hidden: bool = false
@export var is_junk: bool = false
# Text of the reveal action (e.g. "Foto zoomen"). Only relevant if is_hidden.
@export var reveal_label: String = ""
# Optional surface find this hidden find is attached to. Empty = standalone.
# One parent->child level only, no deeper nesting.
@export var parent_id: StringName = &""

# Styled-page content (LinkBook tab). The leak is embedded in body; highlight is
# the exact clickable substring of body that collects the find. title stays as
# the internal deck label only, it is no longer shown as a page heading.
@export var author: String = ""
@export var body: String = ""
@export var highlight: String = ""
@export var kind: StringName = &"post"  # "post" | "profile" | "photo"


static func create(p_id: StringName, p_title: String, p_source: String,
		p_is_hidden: bool = false, p_is_junk: bool = false,
		p_reveal_label: String = "", p_parent_id: StringName = &"") -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.title = p_title
	find.source = p_source
	find.is_hidden = p_is_hidden
	find.is_junk = p_is_junk
	find.reveal_label = p_reveal_label
	find.parent_id = p_parent_id
	return find


# Factory for a styled LinkBook feed item. highlight must be an exact substring
# of body (verified in the recon test).
static func create_post(p_id: StringName, p_title: String, p_source: String,
		p_kind: StringName, p_author: String, p_body: String, p_highlight: String,
		p_is_junk: bool = false) -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.title = p_title
	find.source = p_source
	find.kind = p_kind
	find.author = p_author
	find.body = p_body
	find.highlight = p_highlight
	find.is_junk = p_is_junk
	return find
