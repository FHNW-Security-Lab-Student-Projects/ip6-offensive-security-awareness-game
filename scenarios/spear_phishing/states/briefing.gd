# Sub-state 1: boss briefing, framed as a secure video call inside the
# player's terminal. Loads BriefingResource, drives the dialog box,
# gates the Akzeptieren button until all intro lines have been clicked
# through, then emits advance_requested (handled by the scenario shell).
extends Control

signal advance_requested

const BRIEFING_PATH: String = "res://resources/scenarios/spear_phishing/briefing.tres"
const REC_BLINK_INTERVAL: float = 0.6

# Shared briefing-intro music (Scenario 1 and 2). Tied to this screen's
# visibility, so it plays while the briefing is shown and stops on advance /
# when a replay skips the intro.
const BRIEFING_MUSIC := preload("res://assets/audio/cipher_briefing.wav")
const BRIEFING_VOLUME_DB := -6.0
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")

# Which BriefingResource to show. Defaults to Scenario 1's; another scenario
# (e.g. bad_usb) reuses this same screen by setting its own path before the node
# enters the tree. The spear_phishing shell still reads the const above.
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
	# No reward/turn budget for scenarios that leave reward_text empty (bad_usb).
	if _briefing.reward_text.is_empty():
		_reward_label.visible = false
	else:
		_reward_label.text = tr("BRIEFING_REWARD_LINE") % [
			tr(_briefing.reward_text), _briefing.turn_budget,
		]
	_advance_button.visible = false
	_dialog.lines_finished.connect(_on_lines_finished)
	_started_at_ms = Time.get_ticks_msec()
	# The resource stores translation keys, not sentences, so the intro follows
	# the selected language like the rest of the UI.
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
