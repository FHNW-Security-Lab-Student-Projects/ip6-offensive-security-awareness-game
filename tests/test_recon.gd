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


func _bare_button(find_id: StringName) -> Button:
	for c in _finds_container().get_children():
		if c is Button and not c.is_queued_for_deletion() and c.get_meta("find_id", &"") == find_id:
			return c
	return null


func _initialize() -> void:
	var recon_scene: PackedScene = load("res://scenarios/spear_phishing/states/recon.tscn")
	_recon = recon_scene.instantiate()
	root.add_child(_recon)


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
	print("pool size (expect 17): ", finds.size())
	print("junk count (expect 6): ", junk)
	print("distinct sources (expect 6): ", sources.size())

	# Every LinkBook post's highlight is an exact substring of its body.
	var bad_highlight := 0
	for f in finds:
		if f.source == "LinkedIn" and f.kind != &"photo" and not f.is_hidden:
			if f.highlight.is_empty() or not f.body.contains(f.highlight):
				bad_highlight += 1
	print("linkbook highlights all exact substrings (expect 0 bad): ", bad_highlight)

	# Namesake traps still carry the exact target name.
	print("q7_jodler names target (expect true): ", _find_by_id(finds, &"q7_jodler").title.contains("Markus Weber"))

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
	print("linkbook buttons in page (expect 0): ", buttons.size())
	print("linkbook photo surfaces (expect 1): ", photos.size())
	print("whiteboard not rendered on linkbook (expect null): ", _rtl_for(&"q2d_whiteboard"))

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

	# Fill the deck to 7 via the bare tabs, junk collected like any find.
	_tab("Instagram").pressed.emit()
	_bare_button(&"q5_praktikant").pressed.emit()
	_bare_button(&"q5x_cafe").pressed.emit()
	_tab("kununu").pressed.emit()
	_bare_button(&"q6_kununu").pressed.emit()
	_bare_button(&"q6x_lob").pressed.emit()
	_tab("Google").pressed.emit()
	_bare_button(&"q7_jodler").pressed.emit()
	_bare_button(&"q7x_makler").pressed.emit()
	_bare_button(&"q9_verein").pressed.emit()
	print("deck filled (expect 7): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)

	# Full deck blocks further collect: bare button disabled, inline click inert.
	_tab("JobScout").pressed.emit()
	print("bare button disabled at full deck (expect true): ", _bare_button(&"q3_stelle").disabled)
	_tab("LinkedIn").pressed.emit()
	_rtl_for(&"q1_kontakt").meta_clicked.emit("q1_kontakt")
	print("inline collect blocked at full deck (expect 7): ", _recon.collected.size())

	# Free a slot, then inline collect works again.
	_tab("Google").pressed.emit()
	_bare_button(&"q9_verein").pressed.emit()  # collected -> uncollect
	print("after uncollect (expect 6): ", _recon.collected.size())
	_tab("LinkedIn").pressed.emit()
	_rtl_for(&"q1_kontakt").meta_clicked.emit("q1_kontakt")
	print("inline collect works again (expect 7): ", _recon.collected.size())

	# Hidden whiteboard logic stays intact (harvested from the photo later).
	var wb := _find_by_id(finds, &"q2d_whiteboard")
	_recon.reveal(wb)
	print("whiteboard reveal still works (expect true): ", _recon.is_revealed(wb))
	print("TEST DONE")
	return true
