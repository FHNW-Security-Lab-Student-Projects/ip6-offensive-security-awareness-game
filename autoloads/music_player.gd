# Menu music. As an autoload it survives scene changes, so the track runs
# seamlessly across the menu screens. ScenarioBase stops it, the menus resume it.
# Faded, so it blends with the black SceneTransition fade.
extends Node

const MENU_MUSIC := preload("res://assets/audio/terminal_freeze.wav")
const MENU_VOLUME_DB := -6.0
const FADE_TIME := 0.5
const SILENT_DB := -60.0

var _player: AudioStreamPlayer
var _fade_tween: Tween
var _fading_out := false


func _ready() -> void:
	# Keeps playing while the tree is paused (settings overlay).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = MENU_MUSIC
	_player.volume_db = MENU_VOLUME_DB
	_player.bus = &"Music"  # so the music slider in the settings controls it
	# loop_mode alone leaves loop_end at 0, a zero-length loop that stops at once.
	if _player.stream is AudioStreamWAV:
		var wav := _player.stream as AudioStreamWAV
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(_player)
	play_menu_music()


# No-op while already playing, so moving between menu screens never restarts it.
func play_menu_music() -> void:
	if _player == null:
		return
	if _player.playing and not _fading_out:
		return
	_kill_fade()
	_fading_out = false
	if not _player.playing:
		_player.volume_db = SILENT_DB
		_player.play()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", MENU_VOLUME_DB, FADE_TIME)


func stop_menu_music() -> void:
	if _player == null or not _player.playing:
		return
	_kill_fade()
	_fading_out = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", SILENT_DB, FADE_TIME)
	_fade_tween.tween_callback(_finish_stop)


func _finish_stop() -> void:
	_fading_out = false
	if _player != null:
		_player.stop()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
