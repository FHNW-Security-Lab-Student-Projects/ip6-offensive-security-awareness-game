# A looping player that follows its PARENT's visibility, so the music changes
# with the phase. Add it as a child of any screen and set `track`.
# The loop region is set explicitly: loop_mode alone leaves loop_end at 0, which
# is silence. Preload, no class_name.
extends AudioStreamPlayer

const FADE_TIME := 0.5
const SILENT_DB := -60.0

@export var track: AudioStream
@export var track_volume_db: float = -6.0

var _fade_tween: Tween


func _ready() -> void:
	if track != null:
		stream = track
	volume_db = track_volume_db
	bus = &"Music"  # so the music slider in the settings controls it
	# Keep playing while the tree is paused (settings overlay).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var parent := get_parent() as CanvasItem
	if parent != null:
		parent.visibility_changed.connect(_on_parent_visibility)
		if parent.is_visible_in_tree():
			fade_in()


func _on_parent_visibility() -> void:
	var parent := get_parent() as CanvasItem
	if parent == null:
		return
	if parent.is_visible_in_tree():
		fade_in()
	else:
		fade_out()


func fade_in() -> void:
	_kill_fade()
	if not playing:
		volume_db = SILENT_DB
		play()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", track_volume_db, FADE_TIME)


func fade_out() -> void:
	if not playing:
		return
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "volume_db", SILENT_DB, FADE_TIME)
	_fade_tween.tween_callback(stop)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
