# Sub-state 4: the RESOLVE debrief. VIEW only — it reads GameState.mail_result
# (written by the MailBuilder) and stages the closing feedback; it holds NO game
# logic and never changes balancing. Three blocks build up ONE AFTER ANOTHER so
# the ending lands with weight:
#   1. outcome-specific feedback (one of four, mapped from mail_result.outcome),
#   2. the twist (ALWAYS, even on WIN),
#   3. the closing statistic + its source line (ALWAYS).
# The reveal is time-staggered; a click skips ahead to the buttons. Then three
# choices — next scenario, back to home, retry — each emitted as an intent that
# the scenario shell routes; the sub-state stays ignorant of what comes next.
#
# Runs under the persistent OSChrome bar (content starts at y >= 96), DarkMail
# look. Telemetry: one scenario_debrief event fires when the screen builds (not
# on a button), so it lands exactly once per run regardless of what comes next.
extends Control

signal next_requested      # "Next Scenario": shell completes + loads the next
signal home_requested      # "Back to Home": shell completes + returns to start
signal replay_requested    # "Retry": shell resets + reloads this scenario fresh

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
var _built := false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_build()


func _on_visibility_changed() -> void:
	if visible and not _built:
		_build()


func _build() -> void:
	_built = true
	_emit_debrief()
	_build_layout()
	_start_reveal()


# --- outcome mapping ---------------------------------------------------------

func _outcome_name() -> String:
	return str(GameState.mail_result.get("outcome", ""))


# The RESOLVE_<KEY>_* infix for the current outcome, with a safe fallback so a
# missing/garbled result still shows a coherent screen.
func _outcome_infix() -> String:
	return OUTCOME_KEYS.get(_outcome_name(), FALLBACK_KEY)


# --- telemetry: the last datapoint per run -----------------------------------

func _emit_debrief() -> void:
	var r: Dictionary = GameState.mail_result
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
		},
	})


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

	_button_row = _build_buttons()
	_button_row.modulate.a = 0.0
	col.add_child(_button_row)

	# A transparent catcher over the whole screen turns any click during the
	# staged reveal into a skip. It is freed the moment the buttons appear, so
	# it never sits in front of them.
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_add_button(row, "RESOLVE_NEXT", func() -> void: next_requested.emit())
	_add_button(row, "RESOLVE_HOME", func() -> void: home_requested.emit())
	_add_button(row, "RESOLVE_RETRY", func() -> void: replay_requested.emit())
	return row


func _add_button(row: HBoxContainer, key: String, on_press: Callable) -> void:
	var button := Button.new()
	button.text = tr(key)
	_style_button(button)
	button.pressed.connect(on_press)
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
