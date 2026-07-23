# Autoload: a full-screen black fade used as a loading transition. Owns its own
# CanvasLayer (above everything) so it renders over any scene and survives a
# scene swap. Two entry points:
#   change_scene(path)  fade to black -> change_scene_to_file -> fade back in
#   flash(swap)         fade out -> run a callable (e.g. swap sub-states) -> in
# Both are re-entrancy guarded so a double click cannot start two fades.
extends CanvasLayer

const FADE_TIME := 0.35
const OVERLAY_LAYER := 128

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
	if _busy:
		return
	_busy = true
	await _fade(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # let the new scene enter the tree
	await _fade(0.0)
	_rect.visible = false
	_busy = false


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
