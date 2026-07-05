# Headless test for the Recon sub-state: pool shape, tabs, deck limit,
# collect/uncollect/reveal logic. No test framework, plain SceneTree script.
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
		if t is Button and t.text == source:
			return t
	return null


func _finds_container() -> VBoxContainer:
	return _recon.get_node("%FindsContainer")


# Live children only. queue_free defers removal to frame end, so a synchronous
# test must skip nodes already marked for deletion after a rebuild.
func _live_finds() -> Array:
	var out := []
	for c in _finds_container().get_children():
		if not c.is_queued_for_deletion():
			out.append(c)
	return out


func _collect_button_titled(prefix: String) -> Button:
	for c in _live_finds():
		if c is Button and c.text.contains(prefix):
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

	# Both q7 namesake traps carry the exact target name.
	print("q7_jodler names target (expect true): ", _find_by_id(finds, &"q7_jodler").title.contains("Markus Weber"))
	print("q7x_makler names target (expect true): ", _find_by_id(finds, &"q7x_makler").title.contains("Markus Weber"))

	# Parent wiring, one level.
	print("whiteboard parent (expect q2d_teamfoto): ", _find_by_id(finds, &"q2d_whiteboard").parent_id)
	print("schema parent (expect q5_praktikant): ", _find_by_id(finds, &"q5_schema").parent_id)

	# Tabs: one per source, exactly one active at start.
	var tab_bar := _recon.get_node("%TabBar")
	var active := 0
	for t in tab_bar.get_children():
		if t is Button and t.button_pressed:
			active += 1
	print("tab count (expect 6): ", tab_bar.get_child_count(), " active (expect 1): ", active)

	# LinkedIn is first source: 6 surface finds + 1 reveal control (whiteboard).
	print("deck label at start: ", _recon.get_node("%DeckLabel").text)
	print("linkedin finds (expect 7 = 6 collect + 1 reveal): ", _live_finds().size())

	# Collect a good find and a junk find on LinkedIn.
	_collect_button_titled("Vertrauter Kontakt").pressed.emit()
	print("collected after 1 (expect 1): ", _recon.collected.size(), " label: ", _recon.get_node("%DeckLabel").text)
	_collect_button_titled("Katzen-Smalltalk").pressed.emit()
	print("junk collected normally (expect 2): ", _recon.collected.size())

	# Reveal on LinkedIn does not cost a slot; only the whiteboard is revealed.
	var before: int = _recon.collected.size()
	_collect_button_titled("[Aktion] Foto zoomen").pressed.emit()
	print("whiteboard revealed (expect true): ", _recon.is_revealed(_find_by_id(finds, &"q2d_whiteboard")))
	print("schema still hidden (expect false): ", _recon.is_revealed(_find_by_id(finds, &"q5_schema")))
	print("deck size unchanged by reveal (expect ", before, "): ", _recon.collected.size())

	# Instagram tab: reveal control present, schema becomes collectable.
	_tab("Instagram").pressed.emit()
	print("instagram active (expect true): ", _tab("Instagram").button_pressed)
	print("instagram finds (expect 3 = 2 collect + 1 reveal): ", _live_finds().size())
	print("collected persists across tab switch (expect 2): ", _recon.collected.size())
	_collect_button_titled("[Aktion] Bildschirm zoomen").pressed.emit()
	_collect_button_titled("Mail-Schema").pressed.emit()
	print("schema collectable after reveal (expect 3): ", _recon.collected.size())

	# Fill deck to the limit of 7. Currently 3.
	_tab("Google").pressed.emit()
	print("google finds (expect 3): ", _live_finds().size())
	_collect_button_titled("Jodel-Dirigent").pressed.emit()
	_collect_button_titled("Immobilienmakler").pressed.emit()
	_collect_button_titled("Vereinsprotokoll").pressed.emit()
	print("collected now (expect 6): ", _recon.collected.size())
	_tab("JobScout").pressed.emit()
	_collect_button_titled("Stellenanzeige").pressed.emit()
	print("collected now (expect 7, full): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)

	# Deck full: further collect blocked, buttons disabled.
	_tab("Firmenwebsite").pressed.emit()
	var extra := _collect_button_titled("Pressemitteilung")
	print("blocked button disabled at full deck (expect true): ", extra.disabled)
	extra.pressed.emit()
	print("collect blocked at limit (expect 7): ", _recon.collected.size())

	# uncollect frees a slot; then collecting works again.
	_tab("JobScout").pressed.emit()
	_collect_button_titled("Stellenanzeige").pressed.emit()  # now a ✔ button, so this uncollects
	print("after uncollect (expect 6): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)
	_tab("Firmenwebsite").pressed.emit()
	_collect_button_titled("Pressemitteilung").pressed.emit()
	print("collect works again after freeing slot (expect 7): ", _recon.collected.size())
	print("TEST DONE")
	return true
