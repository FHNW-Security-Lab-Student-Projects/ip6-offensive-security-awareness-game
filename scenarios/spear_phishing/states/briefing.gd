# Sub-state 1: boss briefing, framed as a secure video call inside the
# player's terminal. Loads BriefingResource, drives the dialog box,
# gates the Akzeptieren button until all intro lines have been clicked
# through, then emits advance_requested (handled by the scenario shell).
extends Control

signal advance_requested

const BRIEFING_PATH: String = "res://resources/scenarios/spear_phishing/briefing.tres"
const REC_BLINK_INTERVAL: float = 0.6

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
	_briefing = load(BRIEFING_PATH) as BriefingResource
	if _briefing == null:
		push_error("Briefing: failed to load %s" % BRIEFING_PATH)
		return
	_channel_title.text = tr("BRIEFING_CHANNEL_TITLE") % _briefing.speaker_name
	_mission_label.text = tr("BRIEFING_MISSION_LINE") % _briefing.mission_text
	_reward_label.text = tr("BRIEFING_REWARD_LINE") % [
		_briefing.reward_text, _briefing.turn_budget,
	]
	_advance_button.visible = false
	_dialog.lines_finished.connect(_on_lines_finished)
	_started_at_ms = Time.get_ticks_msec()
	_dialog.play(_briefing.intro_lines, _briefing.speaker_name)

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
