# Autoload: a full-screen black fade used as a loading transition. Owns its own
# CanvasLayer (above everything) so it renders over any scene and survives a
# scene swap. Three entry points:
#   change_scene(path)     fade to black -> change_scene_to_file -> fade back in
#   launch_scenario(cfg)   same, plus start_scenario() on the loaded scene
#   flash(swap)            fade out -> run a callable (e.g. swap sub-states) -> in
# All are re-entrancy guarded so a double click cannot start two fades.
extends CanvasLayer

const FADE_TIME := 0.35
const OVERLAY_LAYER := 128
const SWAP_MAX_FRAMES := 10

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = OVERLAY_LAYER
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0.0)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	# STOP swallows input while a fade is on screen (prevents double triggers);
	# hidden by default, so it never blocks the live game.
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.visible = false
	add_child(_rect)


# Fade to black, swap the scene, fade back in. Safe to call from any scene.
func change_scene(path: String) -> void:
	await _swap(path, &"")


# Loads a scenario and starts its lifecycle. The id comes from the
# ScenarioConfig, so a scenario never bootstraps itself.
func launch_scenario(cfg: ScenarioConfig) -> void:
	await _swap(cfg.scene_path, cfg.id)


func _swap(path: String, scenario_id: StringName) -> void:
	if _busy:
		return
	_busy = true
	# Safety net: a looping typewriter bed must never survive the screen that
	# started it.
	SfxPlayer.stop_typing()
	await _fade(1.0)
	var previous_id: int = 0
	if get_tree().current_scene != null:
		previous_id = get_tree().current_scene.get_instance_id()
	get_tree().change_scene_to_file(path)
	await _await_scene(previous_id)
	if scenario_id != &"":
		_start_scenario(scenario_id)
	await _fade(0.0)
	_rect.visible = false
	_busy = false


# change_scene_to_file is deferred: current_scene still points at the old scene
# one frame later, so waiting a single frame would hand back the wrong node.
func _await_scene(previous_id: int) -> void:
	for _i in SWAP_MAX_FRAMES:
		await get_tree().process_frame
		var now: Node = get_tree().current_scene
		if now != null and now.get_instance_id() != previous_id:
			return
	push_error("SceneTransition: new scene did not become current")


func _start_scenario(id: StringName) -> void:
	var scene: Node = get_tree().current_scene
	if scene is ScenarioBase:
		(scene as ScenarioBase).start_scenario(String(id))
	else:
		push_error("SceneTransition: scene for '%s' is not a ScenarioBase" % id)


# Fade out, run `swap` (no scene change: e.g. toggle intro -> gameplay), fade
# back in. Use for in-scene "loading" beats.
func flash(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	await _fade(1.0)
	if swap.is_valid():
		swap.call()
	await _fade(0.0)
	_rect.visible = false
	_busy = false


func _fade(target_alpha: float) -> void:
	_rect.visible = true
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", target_alpha, FADE_TIME)
	await tween.finished
