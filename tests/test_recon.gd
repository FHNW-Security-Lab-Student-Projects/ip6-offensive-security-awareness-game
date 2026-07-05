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
	print("pool size (expect 16): ", finds.size())
	print("junk count (expect 6, ~1/3): ", junk)
	print("distinct sources (expect 4): ", sources.size())

	# Tabs: one per source, exactly one active at start.
	var tab_bar := _recon.get_node("%TabBar")
	var active := 0
	for t in tab_bar.get_children():
		if t is Button and t.button_pressed:
			active += 1
	print("tab count (expect 4): ", tab_bar.get_child_count(), " active (expect 1): ", active)

	# Active tab is the first source (LinkedIn) and shows only its finds.
	print("deck label at start: ", _recon.get_node("%DeckLabel").text)
	print("linkedin tab button count (5 finds, whiteboard hidden -> 4 collect + 1 reveal = 5): ", _live_finds().size())

	# Collect a good find and a junk find on LinkedIn.
	_collect_button_titled("Jobtitel").pressed.emit()
	print("collected after 1 (expect 1): ", _recon.collected.size(), " label: ", _recon.get_node("%DeckLabel").text)
	_collect_button_titled("Motivationspost").pressed.emit()
	print("junk collected normally (expect 2): ", _recon.collected.size())

	# Reveal on LinkedIn does not cost a slot.
	var before: int = _recon.collected.size()
	_collect_button_titled("[Aktion] Foto zoomen").pressed.emit()
	print("whiteboard revealed (expect true): ", _recon.is_revealed(_find_by_id(finds, &"d_li_whiteboard")))
	print("deck size unchanged by reveal (expect ", before, "): ", _recon.collected.size())

	# Switch to Google tab: LinkedIn collected state persists, Google finds show.
	_tab("Google").pressed.emit()
	var g_active := _tab("Google").button_pressed
	print("google tab active (expect true): ", g_active)
	print("google finds shown (expect 4): ", _live_finds().size())
	print("collected persists across tab switch (expect 2): ", _recon.collected.size())

	# Fill deck to the limit of 7. Currently 2. Collect 5 more good/junk.
	_collect_button_titled("Pressemitteilung").pressed.emit()
	_collect_button_titled("Vereinsprotokoll").pressed.emit()
	_collect_button_titled("Namensvetter").pressed.emit()
	_collect_button_titled("Krypto").pressed.emit()
	print("collected now (expect 6): ", _recon.collected.size())
	_tab("kununu").pressed.emit()
	_collect_button_titled("Firmenkultur").pressed.emit()
	print("collected now (expect 7, full): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)

	# Deck full: further collect blocked, buttons disabled.
	var extra := _collect_button_titled("starre Prozesse")
	print("blocked button disabled at full deck (expect true): ", extra.disabled)
	extra.pressed.emit()
	print("collect blocked at limit (expect 7): ", _recon.collected.size())

	# uncollect frees a slot; then collecting works again.
	_tab("Google").pressed.emit()
	_collect_button_titled("Krypto").pressed.emit()  # now a ✔ button, so this uncollects
	print("after uncollect (expect 6): ", _recon.collected.size(), " ", _recon.get_node("%DeckLabel").text)
	_tab("kununu").pressed.emit()
	_collect_button_titled("starre Prozesse").pressed.emit()
	print("collect works again after freeing slot (expect 7): ", _recon.collected.size())
	print("TEST DONE")
	return true
