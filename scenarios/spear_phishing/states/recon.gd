# Sub-state 2: Recon. Slice 1: collect logic + placeholder UI, no look.
# Fund buttons are built at runtime from ReconPool (single source of truth).
# Emits advance_requested when the player finishes recon and moves on
# to the mail builder.
extends Control

signal advance_requested

# Collected finds, deduplicated by id. Later interface to the MailBuilder;
# stays local to Recon in this slice (no GameState writes).
var collected: Array[ReconFind] = []

@onready var _finds_container: VBoxContainer = %FindsContainer
@onready var _collected_label: Label = %CollectedLabel


func _ready() -> void:
	for find in ReconPool.get_dummy_finds():
		var button := Button.new()
		button.text = find.title + " (" + find.source + ")"
		button.pressed.connect(_on_find_button_pressed.bind(find, button))
		_finds_container.add_child(button)
	_update_collected_label()


func collect(find: ReconFind) -> void:
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


func _on_find_button_pressed(find: ReconFind, button: Button) -> void:
	collect(find)
	button.disabled = true
	button.text = "✔ " + find.title + " (" + find.source + ")"
	_update_collected_label()


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
