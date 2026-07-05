# Sub-state 2: Recon. Slice 3: per-source tabs, a deck limit and reversible
# collecting. Junk finds are collected exactly like good ones (no penalty
# here, that lands in the MailBuilder). Fund buttons are built at runtime
# from ReconPool (single source of truth). Emits advance_requested when the
# player finishes recon and moves on to the mail builder.
extends Control

signal advance_requested

# Max finds the player can carry into the mail builder. One place to tune.
const DECK_LIMIT := 7

# Collected finds, deduplicated by id. Later interface to the MailBuilder;
# stays local to Recon in this slice (no GameState writes).
var collected: Array[ReconFind] = []

# Ids of revealed hidden finds. Monotonic: reveal has no undo.
var revealed: Array[StringName] = []

var _finds: Array[ReconFind] = []
var _active_source: String = ""

@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _finds_container: VBoxContainer = %FindsContainer
@onready var _collected_label: Label = %CollectedLabel
@onready var _deck_label: Label = %DeckLabel


func _ready() -> void:
	_finds = ReconPool.get_finds()
	var sources := _sources_in_order(_finds)
	if not sources.is_empty():
		_active_source = sources[0]
	_build_tabs(sources)
	_rebuild_finds()
	_update_collected_label()
	_update_deck_label()


# --- collect / reveal logic -------------------------------------------------

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


# --- tabs -------------------------------------------------------------------

func _sources_in_order(finds: Array[ReconFind]) -> Array[String]:
	var sources: Array[String] = []
	for find in finds:
		if not sources.has(find.source):
			sources.append(find.source)
	return sources


func _build_tabs(sources: Array[String]) -> void:
	for source in sources:
		var tab := Button.new()
		tab.text = source
		tab.toggle_mode = true
		tab.button_pressed = source == _active_source
		tab.pressed.connect(_on_tab_pressed.bind(source))
		_tab_bar.add_child(tab)


func _on_tab_pressed(source: String) -> void:
	# Switching tabs is free: no deck slot, no telemetry.
	_active_source = source
	for tab in _tab_bar.get_children():
		if tab is Button:
			tab.button_pressed = tab.text == source
	_rebuild_finds()


# --- finds view -------------------------------------------------------------

# Rebuilds the finds column for the active source from persistent state.
func _rebuild_finds() -> void:
	for child in _finds_container.get_children():
		child.queue_free()
	var parent_available := _parent_available_lookup()
	for find in _finds:
		if find.source != _active_source:
			continue
		if find.is_hidden and not is_revealed(find):
			if parent_available.get(find.id, true):
				_add_reveal_button(find)
		else:
			_add_collect_button(find)


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


func _add_collect_button(find: ReconFind) -> void:
	var button := Button.new()
	if is_collected(find):
		button.text = "✔ " + find.title + " (" + find.source + ")"
		button.pressed.connect(_on_uncollect_pressed.bind(find))
	else:
		button.text = find.title + " (" + find.source + ")"
		button.disabled = is_deck_full()
		button.pressed.connect(_on_collect_pressed.bind(find))
	_finds_container.add_child(button)


func _add_reveal_button(find: ReconFind) -> void:
	var button := Button.new()
	button.text = "[Aktion] " + find.reveal_label
	button.pressed.connect(_on_reveal_pressed.bind(find))
	_finds_container.add_child(button)


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
		titles.append(entry.title)
	_collected_label.text = "Eingesammelt (%d): %s" % [collected.size(), ", ".join(titles)]


func _update_deck_label() -> void:
	_deck_label.text = "Deck: %d / %d" % [collected.size(), DECK_LIMIT]


func _on_advance_button_pressed() -> void:
	advance_requested.emit()
