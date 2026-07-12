# Data structure for a single recon find. Pure structure, no display text:
# the pool declares which finds exist and how they behave; every visible
# string (title, author, body, reveal label) is a translation key derived
# from the id and resolved via tr() at render time. Content lives in
# resources/i18n/recon_content.csv, one column per language.
#
# The leak inside a body is marked inline with ⟦…⟧ (see parse_leak) instead of
# a separate substring field, so the "leak is inside the body" invariant holds
# per language by construction — a translation carries its own marker.
class_name ReconFind
extends Resource

# Inline leak delimiters (U+27E6 / U+27E7). Chosen so they survive the BBCode
# escaping in the renderer (they are not "[") and are unlikely to occur in copy.
const LEAK_OPEN := "⟦"
const LEAK_CLOSE := "⟧"

@export var id: StringName
@export var source: String
@export var is_hidden: bool = false
@export var is_junk: bool = false
# Optional surface find this hidden find is attached to. Empty = standalone.
# One parent->child level only, no deeper nesting.
@export var parent_id: StringName = &""
@export var kind: StringName = &"post"  # "post" | "profile" | "photo"


static func create(p_id: StringName, p_source: String,
		p_is_hidden: bool = false, p_is_junk: bool = false,
		p_parent_id: StringName = &"") -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.source = p_source
	find.is_hidden = p_is_hidden
	find.is_junk = p_is_junk
	find.parent_id = p_parent_id
	return find


# Factory for a styled LinkBook feed item (profile/post/photo). All display
# text is keyed off the id; the body carries its leak as a ⟦…⟧ marker.
static func create_post(p_id: StringName, p_source: String, p_kind: StringName,
		p_is_junk: bool = false) -> ReconFind:
	var find := ReconFind.new()
	find.id = p_id
	find.source = p_source
	find.kind = p_kind
	find.is_junk = p_is_junk
	return find


# --- translation keys (derived from id, single source: the id) --------------

func _qid() -> String:
	return String(id).to_upper()

func title_key() -> String:
	return "RECON_%s_TITLE" % _qid()

func author_key() -> String:
	return "RECON_%s_AUTHOR" % _qid()

func body_key() -> String:
	return "RECON_%s_BODY" % _qid()

func reveal_key() -> String:
	return "RECON_%s_REVEAL" % _qid()


# --- leak marker parsing ----------------------------------------------------

# Splits a resolved (already translated) body into the visible text plus the
# leak span. Returns { text, start, len } where text is the body without the
# ⟦…⟧ delimiters and start/len are the span position in CODEPOINTS of that
# visible text (what RichTextLabel.get_parsed_text and HighlightMarker measure).
#
# No marker → { text, start = -1, len = 0 } (a post without a leak, e.g. a
# photo caption). A malformed marker (not exactly one well-formed pair) is a
# content error: it is logged and the body renders unmarked rather than showing
# stray delimiters.
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
