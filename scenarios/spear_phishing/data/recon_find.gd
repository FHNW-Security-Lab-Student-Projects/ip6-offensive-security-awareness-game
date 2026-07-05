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
