# One-shot UI sounds. Outside any screen tree, so a sound survives the scene
# change its button triggered. Every BaseButton is wired to the select blip
# automatically on entering the tree; non-buttons call play_select() themselves.
extends Node

const SELECT_SFX := preload("res://assets/audio/menu_select.wav")
const SELECT_VOLUME_DB := -4.0
const HIGHLIGHT_SFX := preload("res://assets/audio/menu_highlight.wav")
const HIGHLIGHT_VOLUME_DB := 0.0
const NOTIFICATION_SFX := preload("res://assets/audio/notification.wav")
const NOTIFICATION_VOLUME_DB := -11.0
const TYPING_SFX := preload("res://assets/audio/typing.wav")
const TYPING_VOLUME_DB := -20.0   # a quiet bed under the text, never dominant
const UNLOCK_SFX := preload("res://assets/audio/plim.wav")
const UNLOCK_VOLUME_DB := -6.0
const REPLY_SFX := preload("res://assets/audio/hannes_reply.ogg")
const REPLY_VOLUME_DB := 4.0
const COMPLETION_SFX := preload("res://assets/audio/completion.wav")
const COMPLETION_VOLUME_DB := 2.0
const SUSPICION_SFX := preload("res://assets/audio/misstrauen.wav")
const SUSPICION_VOLUME_DB := -9.0
const FAIL_SFX := preload("res://assets/audio/fail.mp3")
const FAIL_VOLUME_DB := -16.0

var _select: AudioStreamPlayer
var _highlight: AudioStreamPlayer
var _notification: AudioStreamPlayer
var _typing: AudioStreamPlayer
var _unlock: AudioStreamPlayer
var _reply: AudioStreamPlayer
var _completion: AudioStreamPlayer
var _suspicion: AudioStreamPlayer
var _fail: AudioStreamPlayer


func _ready() -> void:
	# Must still fire while the tree is paused (settings overlay).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_select = _make_player(SELECT_SFX, SELECT_VOLUME_DB)
	_highlight = _make_player(HIGHLIGHT_SFX, HIGHLIGHT_VOLUME_DB)
	_notification = _make_player(NOTIFICATION_SFX, NOTIFICATION_VOLUME_DB)
	_typing = _make_player(TYPING_SFX, TYPING_VOLUME_DB)
	_unlock = _make_player(UNLOCK_SFX, UNLOCK_VOLUME_DB)
	_reply = _make_player(REPLY_SFX, REPLY_VOLUME_DB)
	_completion = _make_player(COMPLETION_SFX, COMPLETION_VOLUME_DB)
	_suspicion = _make_player(SUSPICION_SFX, SUSPICION_VOLUME_DB)
	_fail = _make_player(FAIL_SFX, FAIL_VOLUME_DB)
	# loop_mode alone leaves loop_end at 0, which is silence.
	if _typing.stream is AudioStreamWAV:
		var wav := _typing.stream as AudioStreamWAV
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	get_tree().node_added.connect(_on_node_added)
	_wire_existing(get_tree().root)


# The bed is the only continuous sound, so it follows the pause state; one-shots
# just finish. Mirrored per frame so any pause source works.
func _process(_delta: float) -> void:
	# No playing-guard: a paused stream reports false and would never resume.
	if _typing != null:
		var should_pause := get_tree().paused
		if _typing.stream_paused != should_pause:
			_typing.stream_paused = should_pause


func _make_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"  # so the SFX slider in the settings controls it
	add_child(player)
	return player


# Auto-played on button presses; callable from non-BaseButton clickables.
func play_select() -> void:
	if _select != null:
		_select.play()


# Advancing text, marking a recon find.
func play_highlight() -> void:
	if _highlight != null:
		_highlight.play()


# A status bar actually moved.
func play_notification() -> void:
	if _notification != null:
		_notification.play()


# Idempotent: repeated starts do not restart the loop.
func start_typing() -> void:
	if _typing != null and not _typing.playing:
		_typing.play()


func stop_typing() -> void:
	if _typing == null:
		return
	# Unguarded on purpose: playing reads false while paused, so a guard let the
	# bed resume after leaving through the pause menu. stop() on idle is free.
	_typing.stop()


# Something new became playable (legendary, payload gate).
func play_unlock() -> void:
	if _unlock != null:
		_unlock.play()


# The target answered in the mail thread.
func play_reply() -> void:
	if _reply != null:
		_reply.play()


# Scenario ended without reaching its goal.
func play_fail() -> void:
	if _fail != null:
		_fail.play()


# Goal reached, debrief comes up.
func play_completion() -> void:
	if _completion != null:
		_completion.play()


# A card backfired: suspicion rose. Replaces the neutral bar blip.
func play_suspicion() -> void:
	if _suspicion != null:
		_suspicion.play()


func _on_node_added(node: Node) -> void:
	_wire(node)


func _wire_existing(node: Node) -> void:
	_wire(node)
	for child in node.get_children():
		_wire_existing(child)


func _wire(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(play_select):
		(node as BaseButton).pressed.connect(play_select)
