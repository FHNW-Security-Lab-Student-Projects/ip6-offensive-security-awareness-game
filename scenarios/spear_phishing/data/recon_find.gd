# One recon find: structure only, no display text. Every visible string is a
# translation key derived from the id, resolved at render time.
#
# The leak is marked inline with the delimiters below instead of a separate
# substring field, so "the leak is inside the body" holds per language by
# construction: a translation carries its own marker.
class_name ReconFind
extends Resource

# Chosen so they survive BBCode escaping (not "[") and never occur in copy.
const LEAK_OPEN := "⟦"
const LEAK_CLOSE := "⟧"

@export var id: StringName
@export var source: String
@export var is_hidden: bool = false
@export var is_junk: bool = false
# Stage dressing: renders like a find but never enters the deck. Guaranteed by
# this flag, not by the content.
@export var is_noise: bool = false
# The surface find this one hangs off. One level only, no deeper nesting.
@export var parent_id: StringName = &""
@export var kind: StringName = &"post"  # "post" | "profile" | "photo"
# Normalised region on the PARENT photo; clicking it collects this find.
# Empty falls back to a reveal button.
@export var hotspot: Rect2 = Rect2()


static func create(p_id: StringName, p_source: String,
		p_is_hidden: bool = false, p_is_junk: bool = false,
		p_parent_id: StringName = &"", p_hotspot: Rect2 = Rect2()) -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.source = p_source
	find.is_hidden = p_is_hidden
	find.is_junk = p_is_junk
	find.parent_id = p_parent_id
	find.hotspot = p_hotspot
	return find


func has_hotspot() -> bool:
	return hotspot.has_area()


# A styled feed item (profile/post/photo).
static func create_post(p_id: StringName, p_source: String, p_kind: StringName,
		p_is_junk: bool = false) -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.source = p_source
	find.kind = p_kind
	find.is_junk = p_is_junk
	return find


# Noise: renders like a find, never collectable, carries no leak marker.
static func create_noise(p_id: StringName, p_source: String) -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.source = p_source
	find.is_noise = true
	return find


# --- translation keys (derived from id, single source: the id) --------------

func _qid() -> String:
	return String(id).to_upper()

# RECON_<QID>_<SUFFIX>. The helpers below cover the common cases; platform
# cards call key() directly for their extra fields.
func key(suffix: String) -> String:
	return "RECON_%s_%s" % [_qid(), suffix]

func title_key() -> String:
	return key("TITLE")

func author_key() -> String:
	return key("AUTHOR")

func body_key() -> String:
	return key("BODY")

func reveal_key() -> String:
	return key("REVEAL")


# --- leak marker parsing ----------------------------------------------------

# Splits an already translated body into visible text plus leak span, as
# { text, start, len }. start/len count CODEPOINTS of the visible text, which is
# what RichTextLabel and HighlightMarker measure.
#
# No marker gives start = -1. A malformed marker is a content error: logged, and
# the body renders unmarked rather than showing stray delimiters.
static func parse_leak(resolved_body: String) -> Dictionary:
	var opens := resolved_body.count(LEAK_OPEN)
	var closes := resolved_body.count(LEAK_CLOSE)
	if opens == 0 and closes == 0:
		return {"text": resolved_body, "start": -1, "len": 0}
	if opens != 1 or closes != 1:
		push_error("ReconFind.parse_leak: expected one %s…%s pair, got %d/%d in: %s"
				% [LEAK_OPEN, LEAK_CLOSE, opens, closes, resolved_body])
		return {"text": _strip_markers(resolved_body), "start": -1, "len": 0}
	var open_idx := resolved_body.find(LEAK_OPEN)
	var close_idx := resolved_body.find(LEAK_CLOSE)
	if close_idx < open_idx:
		push_error("ReconFind.parse_leak: %s before %s in: %s"
				% [LEAK_CLOSE, LEAK_OPEN, resolved_body])
		return {"text": _strip_markers(resolved_body), "start": -1, "len": 0}
	var before := resolved_body.substr(0, open_idx)
	var span := resolved_body.substr(open_idx + 1, close_idx - open_idx - 1)
	var after := resolved_body.substr(close_idx + 1)
	return {"text": before + span + after, "start": before.length(), "len": span.length()}


static func _strip_markers(s: String) -> String:
	return s.replace(LEAK_OPEN, "").replace(LEAK_CLOSE, "")
