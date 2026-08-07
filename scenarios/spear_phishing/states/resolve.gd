# Phase 4: the debrief. VIEW only, no game logic. Three blocks appear one after
# another so the ending lands with weight:
#   1. outcome-specific feedback, mapped from mail_result.outcome
#   2. the twist, ALWAYS, even on a win
#   3. the closing statistic and its source, ALWAYS
# A click skips ahead. The three exits are emitted as intents; this screen stays
# ignorant of what comes next.
#
# scenario_debrief fires when the screen BUILDS, not on a button, so it lands
# exactly once per run whatever the player does afterwards.
extends Control

signal next_requested      # "Next Scenario": shell completes + loads the next
signal home_requested      # "Back to Home": shell completes + returns to start
signal replay_requested    # "Retry": shell resets + reloads this scenario fresh

const MailReview := preload("res://scenarios/spear_phishing/components/mail_review.gd")
const ScreenMusic := preload("res://scenarios/base/components/screen_music.gd")
const PromptClock := preload("res://scenarios/base/prompt_clock.gd")

# Covers the review overlay too, which is a child of this screen.
const RESOLVE_MUSIC := preload("res://assets/audio/terminal_echo_drift.wav")

const SCENARIO_ID := "spear_phishing"
const REVEAL_STEP_TIME := 1.1   # pause between the three blocks
const FADE_TIME := 0.5
const BODY_WIDTH := 760          # wrap width for the paragraphs

# mail_result.outcome (engine enum key) -> RESOLVE_<KEY>_TITLE/_BODY infix.
const OUTCOME_KEYS := {
	"WIN": "WIN",
	"SPAM": "SPAM",
	"KOLLEGEN_RUECKFRAGE": "KOLLEGEN",
	"IGNORIERT": "IGNORIERT",
}
const FALLBACK_KEY := "IGNORIERT"   # empty/unknown result: fail safe, never crash

var _blocks: Array = []          # the three staged content blocks (fade targets)
var _button_row: Control
var _click_catcher: Control
var _reveal_tween: Tween
var _revealed := false

# --- feedback attention (research question 3) --------------------------------
# Without this we know what the run did, but not whether anyone read why.
var _screen_clock := PromptClock.new()
var _review_clock := PromptClock.new()
var _review_opened := false
var _built := false

# The run's phase handoff, set by the scenario shell (RunState).
var _scenario_run


func configure_run(run) -> void:
	_scenario_run = run


func _ready() -> void:
	var music := ScreenMusic.new()
	music.track = RESOLVE_MUSIC
	add_child(music)
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_build()


func _on_visibility_changed() -> void:
	if visible and not _built:
		_build()


func _build() -> void:
	_built = true
	# Only a WIN reached the goal; every other outcome is a failed run.
	if _outcome_name() == "WIN":
		SfxPlayer.play_completion()
	else:
		SfxPlayer.play_fail()
	_emit_debrief()
	_build_layout()
	_start_reveal()


# --- outcome mapping ---------------------------------------------------------

func _outcome_name() -> String:
	return str(_result().get("outcome", ""))


# Empty when the phase is reached without a run; the fallback below covers it.
func _result() -> Dictionary:
	return _scenario_run.mail_result if _scenario_run != null else {}


# Falls back, so a missing or garbled result still shows a coherent screen.
func _outcome_infix() -> String:
	return OUTCOME_KEYS.get(_outcome_name(), FALLBACK_KEY)


# --- telemetry: the last datapoint per run -----------------------------------

func _emit_debrief() -> void:
	var r: Dictionary = _result()
	var outcome: String = _outcome_name() if not _outcome_name().is_empty() else "UNKNOWN"
	EventBus.generic_event.emit({
		"phase": "scenario_debrief",
		"scenario_id": SCENARIO_ID,
		"action": outcome,
		"is_correct": outcome == "WIN",
		"latency_ms": null,
		"payload": {
			"outcome": outcome,
			"turns_used": int(r.get("turns_used", 0)),
			"suspicion": int(r.get("suspicion", 0)),
			"pressure": int(r.get("pressure", 0)),
			"cards_played": _played_ids(r),
		},
	})


# Flattened to plain strings: StringName has no distinct JSON form, and the
# analysis can count card usage without replaying the per-turn events.
func _played_ids(result: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for id in result.get("played", []):
		ids.append(String(id))
	return ids


# --- layout ------------------------------------------------------------------

func _build_layout() -> void:
	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 80
	col.offset_top = 96
	col.offset_right = -80
	col.offset_bottom = -40
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	add_child(col)

	var infix := _outcome_infix()
	_blocks = [
		_build_outcome_block(infix),
		_build_twist_block(),
		_build_stat_block(),
	]
	for block in _blocks:
		block.modulate.a = 0.0   # hidden until its reveal step
		col.add_child(block)

	# Extra breathing room between the statistic and the action buttons.
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 28
	col.add_child(spacer)

	_button_row = _build_buttons()
	_button_row.modulate.a = 0.0
	col.add_child(_button_row)

	# Turns any click during the reveal into a skip. Freed the moment the buttons
	# appear, so it never sits in front of them.
	_click_catcher = Control.new()
	_click_catcher.anchor_right = 1.0
	_click_catcher.anchor_bottom = 1.0
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.gui_input.connect(_on_catcher_input)
	add_child(_click_catcher)


func _build_outcome_block(infix: String) -> Control:
	var block := VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 14)

	var accent := DarkMailPalette.GREEN if infix == "WIN" else DarkMailPalette.ALERT_RED
	var title := _make_label(
		tr("RESOLVE_%s_TITLE" % infix), DarkMailPalette.FONT_SIZE_MONO_LARGE, accent)
	block.add_child(title)

	var body := _make_paragraph(tr("RESOLVE_%s_BODY" % infix), DarkMailPalette.TEXT_GREEN)
	block.add_child(body)
	return block


func _build_twist_block() -> Control:
	var block := VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	var twist := _make_paragraph(tr("RESOLVE_TWIST"), DarkMailPalette.TEXT_GREEN)
	block.add_child(twist)
	return block


func _build_stat_block() -> Control:
	var block := VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 8)

	var stat := _make_paragraph(tr("RESOLVE_STAT"), DarkMailPalette.TEXT_DIM)
	block.add_child(stat)

	var source := _make_label(
		tr("RESOLVE_STAT_SOURCE"), DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	source.custom_minimum_size.x = BODY_WIDTH
	block.add_child(source)
	return block


func _build_buttons() -> Control:
	# The wrapper shrinks to the exit row, the button fills it: that lines the
	# review button up with the three buttons below.
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 14)
	wrap.add_child(block)

	var review := Button.new()
	review.text = tr("RESOLVE_REVIEW_BUTTON")
	review.size_flags_horizontal = Control.SIZE_FILL
	_style_button(review)
	review.pressed.connect(_open_review)
	block.add_child(review)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_add_button(row, "RESOLVE_NEXT", func() -> void: next_requested.emit())
	_add_button(row, "RESOLVE_HOME", func() -> void: home_requested.emit())
	_add_button(row, "RESOLVE_RETRY", func() -> void: replay_requested.emit())
	block.add_child(row)
	return wrap


# The optional turn-by-turn review, as an overlay. Read-only, no flow change.
func _open_review() -> void:
	# The most direct signal for research question 3.
	_review_opened = true
	EventBus.emit_action(SCENARIO_ID, "review_opened", _screen_clock.elapsed())
	_review_clock.mark()

	var review := MailReview.new()
	review.close_requested.connect(_on_review_closed)
	review.close_requested.connect(review.queue_free)
	add_child(review)
	review.configure(
		_result(),
		_scenario_run.collected_find_ids if _scenario_run != null else [],
		_scenario_run.probe_done if _scenario_run != null else false)


# A second means they glanced, half a minute means they read it.
func _on_review_closed() -> void:
	EventBus.emit_action(SCENARIO_ID, "review_closed", _review_clock.take())


func _add_button(row: HBoxContainer, key: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = tr(key)
	_style_button(button)
	# Every exit reports how long the debrief stood before the player left.
	button.pressed.connect(func() -> void:
		EventBus.emit_action(
			SCENARIO_ID,
			"resolve_left",
			_screen_clock.elapsed(),
			{"exit": key, "review_opened": _review_opened},
		)
		on_press.call())
	row.add_child(button)


# --- label helpers -----------------------------------------------------------

func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DarkMailPalette.apply_mono_label(label, size, color)
	label.text = text
	return label


func _make_paragraph(text: String, color: Color) -> Label:
	var label := _make_label(text, DarkMailPalette.FONT_SIZE_MONO, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = BODY_WIDTH
	return label


# --- staged reveal -----------------------------------------------------------

func _start_reveal() -> void:
	_reveal_tween = create_tween()
	for block in _blocks:
		_reveal_tween.tween_callback(_fade_in.bind(block))
		_reveal_tween.tween_interval(REVEAL_STEP_TIME)
	_reveal_tween.tween_callback(_show_buttons)


func _fade_in(node: CanvasItem) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, FADE_TIME)


# A click before the buttons are up jumps straight to the end.
func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SfxPlayer.play_highlight()  # clicking ahead through the debrief text
		# Skipping the reveal is not the same as reading the finished screen.
		if not _revealed:
			EventBus.emit_action(SCENARIO_ID, "resolve_reveal_skipped", PromptClock.UNKNOWN)
		reveal_all()


# Shows every block and the buttons at once. Idempotent; also the natural end of
# the reveal tween. Public so the headless test can drive it without the timer.
func reveal_all() -> void:
	if _revealed:
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
		_reveal_tween = null
	for block in _blocks:
		block.modulate.a = 1.0
	_show_buttons()


func _show_buttons() -> void:
	_revealed = true
	# Starts once the screen stands, so it measures reading, not the animation.
	_screen_clock.mark()
	_button_row.modulate.a = 1.0
	if is_instance_valid(_click_catcher):
		_click_catcher.queue_free()
		_click_catcher = null


# --- shared button style (DarkMail) ------------------------------------------

func _style_button(button: Button) -> void:
	var normal := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	var hover := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.22), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	for sb in [normal, hover]:
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", DarkMailPalette.FONT_MONO)
	button.add_theme_font_size_override("font_size", DarkMailPalette.FONT_SIZE_MONO)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, DarkMailPalette.GREEN)
