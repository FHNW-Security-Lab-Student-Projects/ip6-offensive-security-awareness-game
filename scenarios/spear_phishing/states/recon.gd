# Sub-state 2: Recon. Slice 5: visual contract on the LinkedIn tab only.
# Browser chrome (title bar, url bar, fantasy tabs) plus an embedded, styled
# LinkedIn page. Other tabs stay bare in this slice. The look hangs off the
# existing logic (collect/uncollect/reveal/guard/deck limit) unchanged; the
# same functions are called, only the presentation differs.
#
# Chrome wears the dark DarkMail OS skin (ReconBrowserStyle dark section);
# the page content inside stays bright and realistic on purpose.
# Emits advance_requested when the player finishes recon.
extends Control

signal advance_requested

# Max finds the player can carry into the mail builder. One place to tune.
const DECK_LIMIT := 7

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")
const LockIconScene := preload("res://scenarios/spear_phishing/components/lock_icon.gd")
const TEAM_PHOTO: Texture2D = preload("res://assets/sprites/placeholder/team_photo.png")

# Fantasy platform names for the visible tab labels. Logic uses the source
# StringName, never these labels.
const TAB_LABELS := {
	"LinkedIn": "LinkBook",
	"Instagram": "Instasnap",
	"kununu": "kmunu",
	"Google": "Goggle",
	"JobScout": "JobScoot",
	"Firmenwebsite": "Firmenseite",
}
const TAB_DOMAINS := {
	"LinkedIn": "linkbook.local/h-zinsli",
	"Instagram": "instasnap.local/explore",
	"kununu": "kmunu.local/fintech-ag",
	"Google": "goggle.local/search?q=hannes+zinsli",
	"JobScout": "jobscoot.local/fintech-ag",
	"Firmenwebsite": "fintech-ag.local/presse",
}
const STYLED_SOURCE := "LinkedIn"
const TEAM_PHOTO_ID := &"q2d_teamfoto"

# Collected finds, deduplicated by id. Later interface to the MailBuilder;
# stays local to Recon in this slice (no GameState writes).
var collected: Array[ReconFind] = []

# Ids of revealed hidden finds. Monotonic: reveal has no undo.
var revealed: Array[StringName] = []

var _finds: Array[ReconFind] = []
var _active_source: String = ""
var _tabs: Dictionary = {}  # source(String) -> Button

@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _finds_container: VBoxContainer = %FindsContainer
@onready var _collected_label: Label = %CollectedLabel
@onready var _deck_label: Label = %DeckLabel


func _ready() -> void:
	_style_chrome()
	_finds = ReconPool.get_finds()
	var sources := _sources_in_order(_finds)
	if not sources.is_empty():
		_active_source = sources[0]
	_build_tabs(sources)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()
	_update_url()


# --- collect / reveal logic (unchanged) -------------------------------------

func collect(find: ReconFind) -> void:
	if find.is_hidden and not is_revealed(find):
		return
	if is_collected(find):
		return
	if collected.size() >= DECK_LIMIT:
		return
	var updated: Array[ReconFind] = collected.duplicate()
	updated.append(find)
	collected = updated
	# TODO(telemetry): recon_find_collected → EventBus.generic_event


func uncollect(find: ReconFind) -> void:
	if not is_collected(find):
		return
	var updated: Array[ReconFind] = []
	for entry in collected:
		if entry.id != find.id:
			updated.append(entry)
	collected = updated
	# TODO(telemetry): recon_find_uncollected → EventBus.generic_event


func is_collected(find: ReconFind) -> bool:
	for entry in collected:
		if entry.id == find.id:
			return true
	return false


func is_deck_full() -> bool:
	return collected.size() >= DECK_LIMIT


func reveal(find: ReconFind) -> void:
	if not find.is_hidden or is_revealed(find):
		return
	var updated: Array[StringName] = revealed.duplicate()
	updated.append(find.id)
	revealed = updated
	# TODO(telemetry): recon_find_revealed → EventBus.generic_event


func is_revealed(find: ReconFind) -> bool:
	return revealed.has(find.id)


# --- browser chrome ---------------------------------------------------------

func _style_chrome() -> void:
	# Frame in DarkMail OS optics: dark panels, green accents, hard borders.
	%Window.add_theme_stylebox_override("panel", Style.window_box_dark())
	# No gaps between the chrome sections, so the active tab meets the page.
	(%Window.get_node("WindowVBox") as VBoxContainer).add_theme_constant_override("separation", 0)
	%TitleBar.add_theme_stylebox_override("panel", Style.chrome_box_dark())
	%UrlBar.add_theme_stylebox_override("panel", Style.chrome_box_dark())
	%UrlField.add_theme_stylebox_override("panel", Style.url_field_box_dark())
	%TabStrip.add_theme_stylebox_override("panel", Style.tab_strip_box_dark())

	# The page itself stays bright and realistic — that is the learning goal.
	var page_box := Style._flat(Style.COLOR_PAGE, Style.COLOR_CHROME_BORDER, 0, 0)
	%Page.add_theme_stylebox_override("panel", page_box)

	# Footer as a terminal readout: RECON // OSINT-SWEEP · DECK n/m · action.
	%Footer.add_theme_stylebox_override("panel", Style.footer_box_dark())
	var footer_row := %Footer.get_node("FooterRow") as HBoxContainer
	footer_row.add_theme_constant_override("separation", 16)
	Style.apply_mono_label(%ReadoutLabel as Label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN)
	Style.apply_mono_label(_deck_label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	Style.apply_mono_label(_collected_label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_DIM)

	var title := %WindowTitle as Label
	Style.apply_mono_label(title, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	title.text = "LinkBook — Recherche"
	Style.apply_mono_label(%UrlLabel as Label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.TEXT_GREEN)
	Style.apply_mono_label(%InterceptLabel as Label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.GREEN)

	var advance := %AdvanceButton as Button
	advance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Style.style_terminal_button(advance)

	_build_traffic_lights()
	var lock_holder := %LockHolder as Control
	lock_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lock := LockIconScene.new()
	lock.color = DarkMailPalette.GREEN
	lock_holder.add_child(lock)
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_traffic_lights() -> void:
	var holder := %TrafficLights as HBoxContainer
	holder.add_theme_constant_override("separation", 8)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c in [Style.COLOR_TRAFFIC_RED, Style.COLOR_TRAFFIC_YELLOW, Style.COLOR_TRAFFIC_GREEN]:
		var dot := Panel.new()
		# Fixed square so the circular stylebox never stretches into a pill.
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", sb)
		holder.add_child(dot)


func _update_url() -> void:
	(%UrlLabel as Label).text = TAB_DOMAINS.get(_active_source, "%s.local" % _active_source.to_lower())


# --- tabs -------------------------------------------------------------------

func _sources_in_order(finds: Array[ReconFind]) -> Array[String]:
	var sources: Array[String] = []
	for find in finds:
		if not sources.has(find.source):
			sources.append(find.source)
	return sources


func _build_tabs(sources: Array[String]) -> void:
	_tab_bar.add_theme_constant_override("separation", 4)
	for source in sources:
		var tab := Button.new()
		tab.text = TAB_LABELS.get(source, source)
		tab.toggle_mode = true
		# Identify the tab by its bound source, never by the visible label.
		tab.set_meta("source", source)
		tab.button_pressed = source == _active_source
		Style.style_tab_dark(tab, source == _active_source)
		tab.pressed.connect(_on_tab_pressed.bind(source))
		_tab_bar.add_child(tab)
		_tabs[source] = tab


func _on_tab_pressed(source: String) -> void:
	# Switching tabs is free: no deck slot, no telemetry.
	_active_source = source
	for entry_source in _tabs:
		var tab: Button = _tabs[entry_source]
		var active: bool = entry_source == source
		tab.button_pressed = active
		Style.style_tab_dark(tab, active)
	_rebuild_finds()
	_update_url()


# --- finds view -------------------------------------------------------------

# Rebuilds the finds column for the active source from persistent state.
# Every source now renders through the styled post path.
func _rebuild_finds() -> void:
	for child in _finds_container.get_children():
		child.queue_free()
	_finds_container.add_theme_constant_override("separation", Style.GAP)
	_build_styled_page()


func _build_bare_finds() -> void:
	var parent_available := _parent_available_lookup()
	for find in _finds:
		if find.source != _active_source:
			continue
		if find.is_hidden and not is_revealed(find):
			if parent_available.get(find.id, true):
				_add_reveal_button(find)
		else:
			_add_collect_button(find)


# Styled page for any source: text finds become embedded post cards, a photo
# find becomes a viewable image surface, and a hidden find shows a reveal
# control until revealed (afterwards it renders as a normal post).
func _build_styled_page() -> void:
	var parent_available := _parent_available_lookup()
	for find in _finds:
		if find.source != _active_source:
			continue
		if find.kind == &"photo":
			_add_photo(find)
		elif find.is_hidden and not is_revealed(find):
			if parent_available.get(find.id, true):
				_add_reveal_button(find)
		else:
			_add_post(find)


# One parent->child level only: a hidden find with a parent_id gets its
# reveal control only if the parent find exists in the pool.
func _parent_available_lookup() -> Dictionary:
	var ids := {}
	for find in _finds:
		ids[find.id] = true
	var available := {}
	for find in _finds:
		if find.is_hidden and find.parent_id != &"":
			available[find.id] = ids.has(find.parent_id)
	return available


# --- bare view widgets (unstyled tabs) --------------------------------------

func _add_collect_button(find: ReconFind) -> void:
	var button := Button.new()
	button.set_meta("find_id", find.id)
	var title := tr(find.title_key())
	if is_collected(find):
		button.set_meta("kind", "uncollect")
		button.text = "✔ " + title + " (" + find.source + ")"
		button.pressed.connect(_on_uncollect_pressed.bind(find))
	else:
		button.set_meta("kind", "collect")
		button.text = title + " (" + find.source + ")"
		button.disabled = is_deck_full()
		button.pressed.connect(_on_collect_pressed.bind(find))
	_finds_container.add_child(button)


func _add_reveal_button(find: ReconFind) -> void:
	var button := Button.new()
	button.set_meta("find_id", find.id)
	button.set_meta("kind", "reveal")
	button.text = "[Aktion] " + tr(find.reveal_key())
	button.pressed.connect(_on_reveal_pressed.bind(find))
	_finds_container.add_child(button)


# --- styled feed posts (LinkedIn / LinkBook) --------------------------------

# A real feed post: author line plus the full body text. The leak is marked
# inline in the translated body with ⟦…⟧ (parsed to a span here) and rendered
# as an inline clickable region via RichTextLabel meta. Collecting happens by
# clicking that region only, never a button, so the post does not advertise
# where the leak sits.
func _add_post(find: ReconFind) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.post_box())

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var author := Label.new()
	Style.apply_label(author, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	author.text = tr(find.author_key())
	col.add_child(author)

	var body := RichTextLabel.new()
	body.set_meta("find_id", find.id)
	body.set_meta("hovered", false)
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = false
	body.meta_underlined = false
	body.focus_mode = Control.FOCUS_NONE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font", Style.FONT_REGULAR)
	body.add_theme_font_size_override("normal_font_size", Style.FONT_SIZE_BODY)
	body.add_theme_color_override("default_color", Style.COLOR_TEXT)
	col.add_child(body)

	# Resolve + parse the leak once; the demarked text and span position are
	# stashed on the body so _render_post_text/_apply_post_state stay stateless.
	var leak := ReconFind.parse_leak(tr(find.body_key()))
	body.set_meta("leak", leak)

	# Rounded neutral marking drawn behind the leak span.
	var marker := HighlightMarker.new()
	body.add_child(marker)
	marker.setup(body, Style.FONT_REGULAR, Style.FONT_SIZE_BODY)
	var start: int = leak.get("start", -1)
	var span_len: int = leak.get("len", 0)
	if start >= 0 and span_len > 0:
		marker.set_range(start, span_len)
	body.resized.connect(marker.queue_redraw)

	body.meta_clicked.connect(_on_highlight_clicked.bind(find))
	body.meta_hover_started.connect(_on_highlight_hover.bind(body, marker, find, true))
	body.meta_hover_ended.connect(_on_highlight_hover.bind(body, marker, find, false))
	_apply_post_state(body, marker, find)

	_finds_container.add_child(card)


# Renders the body text for the current state and drives the neutral marker.
# rest = plain text, no marking; hover = light glow plus a "+" (add) affordance;
# collected = filled neutral marking, hover adds a "–" (remove) affordance.
# Text colour never changes, so the text stays readable in every state.
func _apply_post_state(body: RichTextLabel, marker: HighlightMarker, find: ReconFind) -> void:
	var hovered: bool = body.get_meta("hovered", false)
	var leak: Dictionary = body.get_meta("leak", {})
	body.text = _render_post_text(find, leak, hovered)
	# Fill only, no border: a border makes wrapped highlights read as a framed
	# box (leftover vertical edges left and right). Highlighter look instead.
	var fill := Color(0, 0, 0, 0)
	if is_collected(find):
		fill = Style.COLOR_MARK_DECK
	elif hovered:
		fill = Style.COLOR_MARK_HOVER
	marker.set_fill(fill, Color(0, 0, 0, 0))


# Builds the BBCode for a post from the parsed leak. The span position is on
# the demarked text (== visible text), so we split there first, THEN escape
# each part ("[" -> "[lb]") and wrap the span in the clickable url. A post with
# no leak (start < 0, e.g. a photo caption) renders plain.
func _render_post_text(find: ReconFind, leak: Dictionary, hovered: bool) -> String:
	var text: String = leak.get("text", "")
	var start: int = leak.get("start", -1)
	var span_len: int = leak.get("len", 0)
	if start < 0 or span_len <= 0:
		return text.replace("[", "[lb]")
	var before := text.substr(0, start).replace("[", "[lb]")
	var span := text.substr(start, span_len).replace("[", "[lb]")
	var after := text.substr(start + span_len).replace("[", "[lb]")
	var affordance := ""
	if is_collected(find):
		if hovered:
			affordance = " [color=#%s]–[/color]" % Style.COLOR_MUTED.to_html(false)
	elif hovered:
		affordance = " [color=#%s]+[/color]" % Style.COLOR_MUTED.to_html(false)
	var wrapped := "[url=%s]%s%s[/url]" % [find.id, span, affordance]
	return before + wrapped + after


# The team photo is a viewable surface, not a collectable find. Zoom and
# hotspots arrive in the next step; here it is just the image.
func _add_photo(find: ReconFind) -> void:
	var card := PanelContainer.new()
	card.set_meta("photo_id", find.id)
	card.add_theme_stylebox_override("panel", Style.post_box())

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var author := Label.new()
	Style.apply_label(author, Style.FONT_SIZE_SMALL, Style.COLOR_MUTED, true)
	author.text = tr(find.author_key())
	col.add_child(author)

	var body := Label.new()
	Style.apply_label(body, Style.FONT_SIZE_BODY, Style.COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Caption has no leak; parse_leak strips any stray markers defensively.
	body.text = ReconFind.parse_leak(tr(find.body_key())).get("text", "")
	col.add_child(body)

	var photo := TextureRect.new()
	photo.texture = TEAM_PHOTO
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	photo.custom_minimum_size = Vector2(0, 320)
	col.add_child(photo)

	_finds_container.add_child(card)


func _on_highlight_clicked(_meta: Variant, find: ReconFind) -> void:
	if is_collected(find):
		uncollect(find)
	else:
		collect(find)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


func _on_highlight_hover(_meta: Variant, body: RichTextLabel, marker: HighlightMarker, find: ReconFind, entered: bool) -> void:
	# Hover shows the add/remove affordance and the pre-collect glow; the
	# collected marking underneath is unaffected.
	body.set_meta("hovered", entered)
	_apply_post_state(body, marker, find)


# --- interaction handlers (route to unchanged logic) ------------------------

func _on_collect_pressed(find: ReconFind) -> void:
	collect(find)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


func _on_uncollect_pressed(find: ReconFind) -> void:
	uncollect(find)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


func _on_reveal_pressed(find: ReconFind) -> void:
	reveal(find)
	_rebuild_finds()


# --- status labels ----------------------------------------------------------

func _update_collected_label() -> void:
	if collected.is_empty():
		_collected_label.text = "Eingesammelt: (noch nichts)"
		return
	var titles := PackedStringArray()
	for entry in collected:
		titles.append(tr(entry.title_key()))
	_collected_label.text = "Eingesammelt (%d): %s" % [collected.size(), ", ".join(titles)]


func _update_deck_label() -> void:
	_deck_label.text = "DECK %d/%d" % [collected.size(), DECK_LIMIT]


func _on_advance_button_pressed() -> void:
	advance_requested.emit()
