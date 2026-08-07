# Phase 2: the OSINT sweep, staged as a browser. Chrome (title bar, url bar,
# tabs) wears the DarkMail skin; the pages inside stay bright and realistic on
# purpose — the player has to read them as real posts.
#
# This screen owns the collect logic; the per-platform layouts live in
# SourcePage subclasses and call back through the build_* host API below.
extends Control

signal advance_requested

# Max finds the player can carry into the mail builder.
const DECK_LIMIT := 7

# Tied to this screen's visibility.
const RECON_MUSIC := preload("res://assets/audio/terminal_stalk.wav")
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")

# The photo box hotspot rects are normalised against.
const PHOTO_W := 520
const PHOTO_H := 340

const Style := preload("res://scenarios/spear_phishing/data/recon_browser_style.gd")
const LockIconScene := preload("res://scenarios/spear_phishing/components/lock_icon.gd")
const PhotoHotspot := preload("res://scenarios/spear_phishing/components/photo_hotspot.gd")

# Finds without an entry fall back to a neutral desk image.
const RECON_PHOTOS := {
	&"q2d_teamfoto": preload("res://assets/sprites/recon/q2d_teamfoto.png"),
	&"q5_praktikant": preload("res://assets/sprites/recon/q5_praktikant.png"),
	&"q5b_badge": preload("res://assets/sprites/recon/q5b_badge.png"),
	&"q5x_cafe": preload("res://assets/sprites/recon/q5x_cafe.png"),
	&"n_insta_sunset": preload("res://assets/sprites/recon/n_insta_sunset.png"),
}
const RECON_PHOTO_DEFAULT: Texture2D = preload("res://assets/sprites/recon/office_default.png")

# Visible tab labels only. The logic keys on the source, never on these.
const TAB_LABELS := {
	"LinkedIn": "LinkBook",
	"Instagram": "Instasnap",
	"kununu": "kmunu",
	"Google": "Goggle",
	"JobScout": "JobScoot",
	"Firmenwebsite": "RECON_TAB_COMPANY",
}
const TAB_DOMAINS := {
	"LinkedIn": "linkbook.local/h-zinsli",
	"Instagram": "instasnap.local/explore",
	"kununu": "kmunu.local/fintech-ag",
	"Google": "goggle.local/search?q=hannes+zinsli",
	"JobScout": "jobscoot.local/fintech-ag",
	"Firmenwebsite": "fintech-ag.local/presse",
}
const TEAM_PHOTO_ID := &"q2d_teamfoto"

# Platform layouts. New platform = new subclass + a case in _page_for, no new
# scene. Preloaded, not class_name: headless runs have no global class cache.
const SourcePage := preload("res://scenarios/spear_phishing/components/source_pages/source_page.gd")
const FeedPage := preload("res://scenarios/spear_phishing/components/source_pages/feed_page.gd")
const PhotoFeedPage := preload("res://scenarios/spear_phishing/components/source_pages/photo_feed_page.gd")
const SearchPage := preload("res://scenarios/spear_phishing/components/source_pages/search_page.gd")
const ReviewPage := preload("res://scenarios/spear_phishing/components/source_pages/review_page.gd")
const ListingPage := preload("res://scenarios/spear_phishing/components/source_pages/listing_page.gd")
const PressPage := preload("res://scenarios/spear_phishing/components/source_pages/press_page.gd")

# Deduplicated by id. Read by the shell on advance, never written to GameState.
var collected: Array[ReconFind] = []

var _finds: Array[ReconFind] = []
var _active_source: String = ""
var _tabs: Dictionary = {}  # source(String) -> Button
var _pages: Dictionary = {}  # source(String) -> SourcePage (cached)

# The run's phase handoff, set by the scenario shell (RunState).
var _scenario_run


func configure_run(run) -> void:
	_scenario_run = run

# --- telemetry ---------------------------------------------------------------
# Graded on junk: a junk find looks like a lead but carries nothing usable, and
# the deck holds only DECK_LIMIT entries, so taking one has a real cost. Noise is
# not collectable and therefore never graded. Decision time runs from the moment
# the current tab was opened.
const SCENARIO_ID := "spear_phishing"
const PromptClock := preload("res://scenarios/base/prompt_clock.gd")

var _clock := PromptClock.new()
var _phase_started_at_ms: int = 0
# Sources actually opened, for the coverage measure. Not _tabs, which holds
# every tab whether visited or not.
var _visited_sources: Dictionary = {}

@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _finds_container: VBoxContainer = %FindsContainer
@onready var _collected_label: Label = %CollectedLabel
@onready var _deck_label: Label = %DeckLabel


func _ready() -> void:
	var music := ScreenMusic.new()
	music.track = RECON_MUSIC
	add_child(music)
	_style_chrome()
	_phase_started_at_ms = Time.get_ticks_msec()
	_clock.mark()
	_finds = ReconPool.get_finds()
	var sources := _sources_in_order(_finds)
	if not sources.is_empty():
		_active_source = sources[0]
		# The first tab is on screen without being clicked; count it as visited.
		_visited_sources[_active_source] = true
	_build_tabs(sources)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()
	_update_url()


# --- collect logic ----------------------------------------------------------

func collect(find: ReconFind) -> void:
	if find.is_noise:
		return
	if is_collected(find):
		return
	if collected.size() >= DECK_LIMIT:
		# A usability signal, not a wrong answer: the player wanted one more lead
		# than the deck allows.
		EventBus.emit_action(
			SCENARIO_ID,
			"recon_deck_full",
			_clock.elapsed(),
			{"find_id": String(find.id), "source": find.source},
		)
		return
	var updated: Array[ReconFind] = collected.duplicate()
	updated.append(find)
	collected = updated
	EventBus.emit_decision(
		SCENARIO_ID,
		"recon_find_collected",
		not find.is_junk,
		_clock.elapsed(),
		{
			"find_id": String(find.id),
			"source": find.source,
			"is_junk": find.is_junk,
			"is_hidden": find.is_hidden,
			"deck_size": collected.size(),
			"phase_elapsed_ms": _phase_elapsed_ms(),
		},
	)


func uncollect(find: ReconFind) -> void:
	if not is_collected(find):
		return
	var updated: Array[ReconFind] = []
	for entry in collected:
		if entry.id != find.id:
			updated.append(entry)
	collected = updated
	# Ungraded: reconsidering is not an error, but it belongs in the trace.
	EventBus.emit_action(
		SCENARIO_ID,
		"recon_find_uncollected",
		_clock.elapsed(),
		{
			"find_id": String(find.id),
			"source": find.source,
			"is_junk": find.is_junk,
			"deck_size": collected.size(),
		},
	)


func is_collected(find: ReconFind) -> bool:
	for entry in collected:
		if entry.id == find.id:
			return true
	return false


func is_deck_full() -> bool:
	return collected.size() >= DECK_LIMIT


# The photo for a find, or the neutral default if it has no dedicated image.
func photo_texture(find: ReconFind) -> Texture2D:
	return RECON_PHOTOS.get(find.id, RECON_PHOTO_DEFAULT)


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

	# The page stays bright and realistic — that is the learning goal.
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
	title.text = tr("RECON_LINKBOOK_TITLE")
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
		tab.text = tr(TAB_LABELS.get(source, source))
		tab.toggle_mode = true
		# Identify the tab by its bound source, never by the visible label.
		tab.set_meta("source", source)
		tab.button_pressed = source == _active_source
		Style.style_tab_dark(tab, source == _active_source)
		tab.pressed.connect(_on_tab_pressed.bind(source))
		_tab_bar.add_child(tab)
		_tabs[source] = tab


func _on_tab_pressed(source: String) -> void:
	# Which platforms a player opens, and how long they linger, is the coverage
	# measure, so the switch carries the dwell time on the page being left.
	EventBus.emit_action(
		SCENARIO_ID,
		"recon_tab_opened",
		_clock.take(),
		{"from": _active_source, "to": source},
	)
	_clock.mark()
	_active_source = source
	_visited_sources[source] = true
	for entry_source in _tabs:
		var tab: Button = _tabs[entry_source]
		var active: bool = entry_source == source
		tab.button_pressed = active
		Style.style_tab_dark(tab, active)
	_rebuild_finds()
	_update_url()


# --- finds view -------------------------------------------------------------

# Each platform arranges its own finds; the collect interaction is the same
# everywhere, provided by the build_* host methods below.
func _rebuild_finds() -> void:
	for child in _finds_container.get_children():
		child.queue_free()
	_finds_container.add_theme_constant_override("separation", Style.GAP)
	var finds_for_source: Array[ReconFind] = []
	for find in _finds:
		if find.source == _active_source:
			finds_for_source.append(find)
	_page_for(_active_source).build(self, _finds_container, finds_for_source)


# Pages are stateless and cached per source.
func _page_for(source: String) -> SourcePage:
	if not _pages.has(source):
		var page: SourcePage
		match source:
			"Instagram": page = PhotoFeedPage.new()
			"Google": page = SearchPage.new()
			"kununu": page = ReviewPage.new()
			"JobScout": page = ListingPage.new()
			"Firmenwebsite": page = PressPage.new()
			_: page = FeedPage.new()
		_pages[source] = page
	return _pages[source]


# --- host API for SourcePages (collect logic stays here) --------------------

# The ONLY path to collecting: every platform card embeds this body, nothing
# else collects. The leak is marked inline in the translated text and rendered as
# a clickable region, so a card never advertises where the leak sits.
func build_leak_body(find: ReconFind) -> RichTextLabel:
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

	# Noise gets no leak span and no collect wiring, so it can never enter the
	# deck. collect() guards it a second time.
	if find.is_noise:
		body.text = ReconFind.parse_leak(tr(find.body_key())).get("text", "").replace("[", "[lb]")
		return body

	# Parsed once and stashed on the body, so the render helpers stay stateless.
	var leak := ReconFind.parse_leak(tr(find.body_key()))
	body.set_meta("leak", leak)

	# The neutral marking drawn behind the leak span.
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
	return body


# Overlays a hotspot for every find that hangs off `parent_find` and carries a
# rect. Those finds live only here: hovering hints, clicking collects, and there
# is no standalone card for them anywhere.
func attach_hotspots(parent_find: ReconFind, image: Control) -> void:
	image.mouse_filter = Control.MOUSE_FILTER_PASS
	var bar := _build_hint_bar()
	var bar_label := bar.get_child(0) as Label
	var has_hotspot := false
	for child in _finds:
		if child.parent_id != parent_find.id or not child.has_hotspot():
			continue
		has_hotspot = true
		var hint: String = ReconFind.parse_leak(tr(child.body_key())).get("text", "")
		var hs := PhotoHotspot.new()
		hs.set_meta("hotspot_for", child.id)
		hs.setup(hint, is_collected(child))
		var r := child.hotspot
		hs.anchor_left = r.position.x
		hs.anchor_top = r.position.y
		hs.anchor_right = r.position.x + r.size.x
		hs.anchor_bottom = r.position.y + r.size.y
		hs.offset_left = 0.0
		hs.offset_top = 0.0
		hs.offset_right = 0.0
		hs.offset_bottom = 0.0
		hs.clicked.connect(_on_hotspot_clicked.bind(child))
		hs.mouse_entered.connect(_on_hotspot_hover.bind(bar, bar_label, hint, true))
		hs.mouse_exited.connect(_on_hotspot_hover.bind(bar, bar_label, hint, false))
		image.add_child(hs)
	# Add the bar last so it draws above the hotspots; only if the image has any.
	if has_hotspot:
		image.add_child(bar)


# Hidden until a hotspot is hovered, and shared by all hotspots on the image.
func _build_hint_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks pass through to the hotspot
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := DarkMailPalette.flat_box(
		Color(DarkMailPalette.BG_PANEL, 0.92), DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	DarkMailPalette.apply_mono_label(label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
	bar.add_child(label)
	return bar


func _on_hotspot_hover(bar: Control, label: Label, hint: String, entered: bool) -> void:
	if entered:
		label.text = hint
	bar.visible = entered


# Three states: rest is plain, hover adds a glow and a "+", collected is filled
# and offers a "–". The text colour never changes, so it stays readable in all
# three.
func _apply_post_state(body: RichTextLabel, marker: HighlightMarker, find: ReconFind) -> void:
	var hovered: bool = body.get_meta("hovered", false)
	var leak: Dictionary = body.get_meta("leak", {})
	body.text = _render_post_text(find, leak, hovered)
	# Fill only: a border makes wrapped highlights read as a framed box.
	var fill := Color(0, 0, 0, 0)
	if is_collected(find):
		fill = Style.COLOR_MARK_DECK
	elif hovered:
		fill = Style.COLOR_MARK_HOVER
	marker.set_fill(fill, Color(0, 0, 0, 0))


# The span position is on the demarked text, so split there FIRST and escape the
# parts afterwards. A post with no leak renders plain.
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


# The photo itself is not collectable; the finds embedded in it are, via
# attach_hotspots. The image sits in a fixed-size box and COVERED fills it, so
# the normalised hotspot rects map onto what is actually visible.
func build_photo_card(find: ReconFind) -> Control:
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

	var caption := Label.new()
	Style.apply_label(caption, Style.FONT_SIZE_BODY, Style.COLOR_TEXT)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The caption has no leak; parse_leak strips stray markers defensively.
	caption.text = ReconFind.parse_leak(tr(find.body_key())).get("text", "")
	col.add_child(caption)

	# No clip_contents: COVERED already crops, and clipping would cut off a
	# hotspot's hover hint at the image edge.
	var photo := TextureRect.new()
	photo.texture = photo_texture(find)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size = Vector2(PHOTO_W, PHOTO_H)
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(photo)
	attach_hotspots(find, photo)

	return card


func _on_highlight_clicked(_meta: Variant, find: ReconFind) -> void:
	SfxPlayer.play_highlight()
	if is_collected(find):
		uncollect(find)
	else:
		collect(find)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


func _on_highlight_hover(_meta: Variant, body: RichTextLabel, marker: HighlightMarker, find: ReconFind, entered: bool) -> void:
	# The collected marking underneath is unaffected.
	body.set_meta("hovered", entered)
	_apply_post_state(body, marker, find)


# --- interaction handlers (route to collect logic) --------------------------

# The same toggle as an inline leak span, triggered from the image.
func _on_hotspot_clicked(find: ReconFind) -> void:
	if is_collected(find):
		uncollect(find)
	else:
		collect(find)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


# --- status labels ----------------------------------------------------------

func _update_collected_label() -> void:
	if collected.is_empty():
		_collected_label.text = tr("RECON_COLLECTED_EMPTY")
		return
	var titles := PackedStringArray()
	for entry in collected:
		titles.append(tr(entry.title_key()))
	_collected_label.text = tr("RECON_COLLECTED") % [collected.size(), ", ".join(titles)]


func _update_deck_label() -> void:
	_deck_label.text = tr("RECON_DECK") % [collected.size(), DECK_LIMIT]


func _on_advance_button_pressed() -> void:
	# Hand the collected finds on; the MailBuilder maps each id to a card.
	var ids: Array[StringName] = []
	for entry in collected:
		ids.append(entry.id)
	_emit_recon_summary(ids)
	if _scenario_run != null:
		_scenario_run.set_collected_finds(ids)
	advance_requested.emit()


# --- telemetry --------------------------------------------------------------

func _phase_elapsed_ms() -> int:
	if _phase_started_at_ms == 0:
		return PromptClock.UNKNOWN
	return Time.get_ticks_msec() - _phase_started_at_ms


# What the player walked away with, in ONE event, so the summary table does not
# have to replay the whole collect/uncollect stream to reconstruct the deck.
func _emit_recon_summary(ids: Array[StringName]) -> void:
	var junk_count: int = 0
	var collected_ids := PackedStringArray()
	for entry in collected:
		collected_ids.append(String(entry.id))
		if entry.is_junk:
			junk_count += 1
	EventBus.emit_action(
		SCENARIO_ID,
		"recon_completed",
		_phase_elapsed_ms(),
		{
			"collected_count": ids.size(),
			"junk_count": junk_count,
			"deck_limit": DECK_LIMIT,
			"sources_opened": _visited_sources.size(),
			"sources_available": _tabs.size(),
			"collected_ids": collected_ids,
		},
	)
