# Sub-state 2: Recon. Slice 2: hidden finds start as reveal controls and
# only become collectable after reveal(). Fund buttons are built at runtime
# from ReconPool (single source of truth). Emits advance_requested when the
# player finishes recon and moves on to the mail builder.
extends Control

signal advance_requested

# Collected finds, deduplicated by id. Later interface to the MailBuilder;
# stays local to Recon in this slice (no GameState writes).
var collected: Array[ReconFind] = []

# Ids of revealed hidden finds. Monotonic: reveal has no undo.
var revealed: Array[StringName] = []

@onready var _finds_container: VBoxContainer = %FindsContainer
@onready var _collected_label: Label = %CollectedLabel


func _ready() -> void:
	for find in ReconPool.get_dummy_finds():
		if find.is_hidden:
			_add_reveal_button(find)
		else:
			_add_collect_button(find)
	_update_collected_label()


func collect(find: ReconFind) -> void:
	if find.is_hidden and not is_revealed(find):
		return
	if is_collected(find):
		return
	var updated: Array[ReconFind] = collected.duplicate()
	updated.append(find)
	collected = updated
	# TODO(telemetry): recon_find_collected → EventBus.generic_event


func is_collected(find: ReconFind) -> bool:
	for entry in collected:
		if entry.id == find.id:
			return true
	return false


func reveal(find: ReconFind) -> void:
	if not find.is_hidden or is_revealed(find):
		return
	var updated: Array[StringName] = revealed.duplicate()
	updated.append(find.id)
	revealed = updated
	# TODO(telemetry): recon_find_revealed → EventBus.generic_event


func is_revealed(find: ReconFind) -> bool:
	return revealed.has(find.id)


func _add_collect_button(find: ReconFind, at_index: int = -1) -> void:
	var button := Button.new()
	button.text = find.title + " (" + find.source + ")"
	button.pressed.connect(_on_find_button_pressed.bind(find, button))
	_finds_container.add_child(button)
	if at_index >= 0:
		_finds_container.move_child(button, at_index)


func _add_reveal_button(find: ReconFind) -> void:
	var button := Button.new()
	button.text = "[Aktion] " + find.reveal_label
	button.pressed.connect(_on_reveal_button_pressed.bind(find, button))
	_finds_container.add_child(button)


func _on_find_button_pressed(find: ReconFind, button: Button) -> void:
	collect(find)
	button.disabled = true
	button.text = "✔ " + find.title + " (" + find.source + ")"
	_update_collected_label()


func _on_reveal_button_pressed(find: ReconFind, button: Button) -> void:
	reveal(find)
	var index := button.get_index()
	button.queue_free()
	_add_collect_button(find, index)


func _update_collected_label() -> void:
	if collected.is_empty():
		_collected_label.text = "Eingesammelt: (noch nichts)"
		return
	var titles := PackedStringArray()
	for entry in collected:
		titles.append(entry.title)
	_collected_label.text = "Eingesammelt (%d): %s" % [collected.size(), ", ".join(titles)]


func _on_advance_button_pressed() -> void:
	advance_requested.emit()
