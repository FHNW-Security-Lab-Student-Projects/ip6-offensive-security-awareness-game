# The one settings overlay for the whole game. Escape opens and closes it
# anywhere; the tree pauses while it is up. The title screen's button routes here
# too, so there is a single instance and a single code path.
extends CanvasLayer

const SettingsPanel := preload("res://scenes/settings_panel.gd")
const OVERLAY_LAYER := 100
const TITLE_SCENE := "res://scenes/StartScreen.tscn"

var _panel: Control


func _ready() -> void:
	layer = OVERLAY_LAYER
	# Without this, Escape could open the dialog but never close it again.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open():
		return
	_panel = SettingsPanel.new()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.closed.connect(close)
	add_child(_panel)
	get_tree().paused = true


func close() -> void:
	get_tree().paused = false
	if is_open():
		_panel.queue_free()
	_panel = null


# Records the run as abandoned, so the analysis can tell an exit from a crash.
# Order matters: close() lifts the pause, or the fade sits frozen on a paused tree.
func leave_to_title() -> void:
	if not GameState.is_in_menu():
		EventBus.emit_action(
			GameState.current_scenario_id,
			"scenario_aborted",
			-1,  # no clock on this: it is an exit, not a decision
			{"phase": String(GameState.mission_phase)},
		)
	close()
	SceneTransition.change_scene(TITLE_SCENE)
