# Phase 1: the boss briefing, framed as a secure video call. The advance button
# stays hidden until every intro line has been clicked through.
extends Control

signal advance_requested

const BRIEFING_PATH: String = "res://resources/scenarios/spear_phishing/briefing.tres"
const REC_BLINK_INTERVAL: float = 0.6

# Shared by both scenarios. Tied to this screen's visibility.
const BRIEFING_MUSIC := preload("res://assets/audio/cipher_briefing.wav")
const BRIEFING_VOLUME_DB := -6.0
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")

# Which BriefingResource to show. Another scenario reuses this whole screen by
# setting its own path before the node enters the tree.
@export var briefing_path: String = BRIEFING_PATH

@onready var _dialog: DialogBox = $ChannelWindow/DialogBox as DialogBox
@onready var _channel_title: Label = $ChannelWindow/ChannelTitleStrip/ChannelTitleLabel
@onready var _rec_dot: ColorRect = $ChannelWindow/ChannelTitleStrip/RecDot
@onready var _mission_label: Label = $TaskPanel/MissionLabel
@onready var _reward_label: Label = $TaskPanel/RewardLabel
@onready var _advance_button: Button = $TaskPanel/AdvanceButton

var _briefing: BriefingResource
var _started_at_ms: int = 0
var _rec_blink_acc: float = 0.0
var _rec_on: bool = true

func _ready() -> void:
	var music := ScreenMusic.new()
	music.track = BRIEFING_MUSIC
	music.track_volume_db = BRIEFING_VOLUME_DB
	add_child(music)
	_briefing = load(briefing_path) as BriefingResource
	if _briefing == null:
		push_error("Briefing: failed to load %s" % briefing_path)
		return
	_channel_title.text = tr("BRIEFING_CHANNEL_TITLE") % tr(_briefing.speaker_name)
	_mission_label.text = tr("BRIEFING_MISSION_LINE") % tr(_briefing.mission_text)
	# The resource owns the wording, including whether there is a line at all.
	_reward_label.text = _briefing.reward_line()
	_reward_label.visible = not _reward_label.text.is_empty()
	_advance_button.visible = false
	_dialog.lines_finished.connect(_on_lines_finished)
	visibility_changed.connect(_on_visibility_changed)
	_started_at_ms = Time.get_ticks_msec()
	# The resource stores keys, not sentences, so the intro follows the locale.
	var lines := PackedStringArray()
	for key in _briefing.intro_lines:
		lines.append(tr(key))
	_dialog.play(lines, tr(_briefing.speaker_name))

func _process(delta: float) -> void:
	_rec_blink_acc += delta
	if _rec_blink_acc >= REC_BLINK_INTERVAL:
		_rec_blink_acc = 0.0
		_rec_on = not _rec_on
		_rec_dot.modulate.a = 1.0 if _rec_on else 0.25

func _on_lines_finished() -> void:
	_advance_button.visible = true


# The typewriter bed lives on an autoload and outlives this screen. Two cases:
# a replay skips the briefing after _ready already started the dialog (the bed
# would run on over the next phase), and _setup hides every sub-state once before
# showing this one (the line must not end up typing silently).
func _on_visibility_changed() -> void:
	if _dialog == null or not _dialog.is_typing():
		return
	if visible:
		SfxPlayer.start_typing()
	else:
		SfxPlayer.stop_typing()

func _on_advance_button_pressed() -> void:
	var elapsed: int = Time.get_ticks_msec() - _started_at_ms
	var lines_shown: int = _briefing.intro_lines.size() if _briefing else 0
	EventBus.generic_event.emit({
		"phase": "action",
		"scenario_id": GameState.current_scenario_id,
		"action": "briefing_advanced",
		"is_correct": null,
		"latency_ms": elapsed,
		"payload": {"lines_shown": lines_shown},
	})
	advance_requested.emit()
