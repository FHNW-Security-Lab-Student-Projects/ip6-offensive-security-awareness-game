# Headless test for the Recon sub-state: pool shape, embedded LinkBook posts,
# tab navigation, deck limit, collect/uncollect/reveal logic. Plain SceneTree
# script, no test framework.
#
# Run:
#   godot --headless --path . -s tests/test_recon.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

var _recon: Control
var _done := false


func _find_by_id(finds: Array[ReconFind], id: StringName) -> ReconFind:
	for f in finds:
		if f.id == id:
			return f
	return null


func _tab(source: String) -> Button:
	for t in _recon.get_node("%TabBar").get_children():
		if t is Button and t.get_meta("source", "") == source:
			return t
	return null


func _finds_container() -> VBoxContainer:
	return _recon.get_node("%FindsContainer")


# Recursively collects live nodes of the given class under the finds container.
func _walk(node: Node, cls, out: Array) -> void:
	for c in node.get_children():
		if c.is_queued_for_deletion():
			continue
		if is_instance_of(c, cls):
			out.append(c)
		_walk(c, cls, out)


func _rtl_for(find_id: StringName) -> RichTextLabel:
	var out: Array = []
	_walk(_finds_container(), RichTextLabel, out)
	for r in out:
		if r.get_meta("find_id", &"") == find_id:
			return r
	return null


func _hotspot_for(find_id: StringName) -> Control:
	var out: Array = []
	_walk(_finds_container(), Control, out)
	for n in out:
		if n.has_meta("hotspot_for") and n.get_meta("hotspot_for") == find_id:
			return n
	return null


func _initialize() -> void:
	_ensure_translations()
	var recon_scene: PackedScene = load("res://scenarios/spear_phishing/states/recon.tscn")
	_recon = recon_scene.instantiate()
	root.add_child(_recon)


# The recon UI now resolves its content via tr(); the translation tables must
# be loaded before it is instanced. If the I18n autoload already ran (normal
# editor / full run) this is a no-op; under `godot -s` we load it here so the
# same loader (and thus recon_content.csv) is used.
func _ensure_translations() -> void:
	if tr("RECON_Q2A_SONNTAGS_BODY") != "RECON_Q2A_SONNTAGS_BODY":
		return
	var i18n: Node = (load("res://autoloads/i18n.gd") as GDScript).new()
	root.add_child(i18n)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var finds: Array[ReconFind] = ReconPool.get_finds()
	var junk := 0
	var sources := {}
	for f in finds:
		if f.is_junk:
			junk += 1
		sources[f.source] = true
	print("pool size (expect 31): ", finds.size())
	print("junk count (expect 7): ", junk)
	print("distinct sources (expect 6): ", sources.size())

	# Noise is non-collectable stage dressing: collect() rejects it and its body
	# carries no leak marker (deck is still empty here).
	var noise := _find_by_id(finds, &"n_goggle_uni")
	print("noise carries no leak marker (expect true): ", not tr(noise.body_key()).contains(ReconFind.LEAK_OPEN))
	var before_noise: int = _recon.collected.size()
	_recon.collect(noise)
	print("collect() rejects noise (expect unchanged): ", _recon.collected.size() == before_noise)

	# Marker invariant across every post-rendered find (any find that resolves a
	# body). A body WITHOUT a marker is valid (no leak); a body WITH markers must
	# hold exactly one well-formed ⟦…⟧ pair with non-empty content. Photo
	# captions and finds without a body key are exempt.
	var bad_marker := 0
	for f in finds:
		if f.kind == &"photo":
			continue
		var body := tr(f.body_key())
		if body == f.body_key():
			continue  # no body content for this find
		var has_marker := body.contains(ReconFind.LEAK_OPEN) or body.contains(ReconFind.LEAK_CLOSE)
		if not has_marker:
			continue  # a body without a leak is valid
		var leak := ReconFind.parse_leak(body)
		if int(leak["start"]) < 0 or int(leak["len"]) <= 0:
			bad_marker += 1
	print("all post bodies have valid leak spans (expect 0 bad): ", bad_marker)

	# Namesake traps still carry the exact target name (Hannes Zinsli).
	print("q7_jodler names target (expect true): ", tr(_find_by_id(finds, &"q7_jodler").title_key()).contains("Hannes Zinsli"))

	# Tabs: one per source, exactly one active; three traffic-light dots.
	var tab_bar := _recon.get_node("%TabBar")
	var active := 0
	for t in tab_bar.get_children():
		if t is Button and t.button_pressed:
			active += 1
	print("tab count (expect 6): ", tab_bar.get_child_count(), " active (expect 1): ", active)
	print("traffic dots (expect 3): ", _recon.get_node("%TrafficLights").get_child_count())

	# LinkBook view: real posts (RichTextLabels), no collect buttons, one photo.
	var posts: Array = []
	_walk(_finds_container(), RichTextLabel, posts)
	var buttons: Array = []
	_walk(_finds_container(), Button, buttons)
	var photos: Array = []
	_walk(_finds_container(), TextureRect, photos)
	print("linkbook post labels (expect 5): ", posts.size())
	# The whiteboard is now a hotspot on the team photo, not a reveal button.
	print("linkbook buttons in page (expect 0): ", buttons.size())
	print("linkbook photo surfaces (expect 1): ", photos.size())
	# The whiteboard lives only as a hotspot on the team photo, never a card.
	print("whiteboard is never a standalone post (expect null): ", _rtl_for(&"q2d_whiteboard"))
	var wb_hs := _hotspot_for(&"q2d_whiteboard")
	print("whiteboard has a photo hotspot (expect true): ", wb_hs != null)
	# Clicking the hotspot collects the find directly (no reveal step), and
	# clicking again uncollects it. Deck is empty here.
	if wb_hs != null:
		wb_hs.emit_signal("clicked")
	print("whiteboard collected via hotspot (expect 1): ", _recon.collected.size())
	_hotspot_for(&"q2d_whiteboard").emit_signal("clicked")
	print("whiteboard uncollected via second click (expect 0): ", _recon.collected.size())

	# Collect via the embedded highlight (meta click), then uncollect.
	# Marking is value-neutral now: no success glyph in the text.
	_rtl_for(&"q2a_sonntags").meta_clicked.emit("q2a_sonntags")
	print("collected via inline highlight (expect 1): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)
	print("no success glyph on collected good find (expect false): ", _rtl_for(&"q2a_sonntags").text.contains("✔"))
	_rtl_for(&"q2a_sonntags").meta_clicked.emit("q2a_sonntags")
	print("uncollected via second click (expect 0): ", _recon.collected.size())

	# Junk collects and marks exactly like a good find (no distinguishing glyph).
	_rtl_for(&"q2c_katze").meta_clicked.emit("q2c_katze")
	print("junk collected like any find (expect 1): ", _recon.collected.size())
	print("no success glyph on collected junk (expect false): ", _rtl_for(&"q2c_katze").text.contains("✔"))
	_rtl_for(&"q2c_katze").meta_clicked.emit("q2c_katze")

	# Hover keeps text readable and shows the add affordance (+), no bgcolor tag.
	var rtl := _rtl_for(&"q2b_neue_it")
	rtl.meta_hover_started.emit("q2b_neue_it")
	print("hover shows add affordance (expect true): ", rtl.text.contains("+"))
	print("hover keeps highlight text (expect true): ", rtl.text.contains("Bit & Bürli GmbH"))
	print("no raw bgcolor marking in text (expect false): ", rtl.text.contains("bgcolor"))
	rtl.meta_hover_ended.emit("q2b_neue_it")

	# Fill the deck to 7 via inline collection across tabs; every collectable
	# post is collected the same way (meta click on the leak span). q5_praktikant
	# has no leak marker and is intentionally not collectable, so it is skipped.
	_tab("Instagram").pressed.emit()
	_rtl_for(&"q5x_cafe").meta_clicked.emit("q5x_cafe")
	_tab("kununu").pressed.emit()
	_rtl_for(&"q6_kununu").meta_clicked.emit("q6_kununu")
	_rtl_for(&"q6x_lob").meta_clicked.emit("q6x_lob")
	_tab("Google").pressed.emit()
	_rtl_for(&"q7_jodler").meta_clicked.emit("q7_jodler")
	_rtl_for(&"q7x_makler").meta_clicked.emit("q7x_makler")
	_rtl_for(&"q9_verein").meta_clicked.emit("q9_verein")
	_tab("JobScout").pressed.emit()
	_rtl_for(&"q3_stelle").meta_clicked.emit("q3_stelle")
	print("deck filled (expect 7): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)

	# Full deck blocks any further inline collect.
	_tab("Firmenwebsite").pressed.emit()
	_rtl_for(&"q4_presse").meta_clicked.emit("q4_presse")
	print("inline collect blocked at full deck (expect 7): ", _recon.collected.size())

	# Free a slot, then inline collect works again.
	_tab("Google").pressed.emit()
	_rtl_for(&"q9_verein").meta_clicked.emit("q9_verein")  # collected -> uncollect
	print("after uncollect (expect 6): ", _recon.collected.size())
	_tab("LinkedIn").pressed.emit()
	_rtl_for(&"q1_kontakt").meta_clicked.emit("q1_kontakt")
	print("inline collect works again (expect 7): ", _recon.collected.size())

	# Platform-distinct layout: Instasnap is an image-centric feed — each post
	# carries its own image, unlike the text tabs. Kevin's selfie + badge photos
	# carry their own collectable hotspots (schema, badge details).
	_tab("Instagram").pressed.emit()
	var imgs: Array = []
	_walk(_finds_container(), TextureRect, imgs)
	print("instasnap posts are image-centric (expect >=2): ", imgs.size())
	print("instasnap schema hotspot present (expect true): ", _hotspot_for(&"q5_schema") != null)
	print("instasnap badge hotspot present (expect true): ", _hotspot_for(&"q5b_details") != null)
	print("TEST DONE")
	return true
