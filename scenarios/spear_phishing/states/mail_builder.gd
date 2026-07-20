# Sub-state 3: the MailBuilder (the card game). VIEW/controller: it owns a
# MailRun (engine) and MailCardPool (the hand) and renders the two bars, the mail
# draft, the handler chat and the hand. It contains NO game logic, NO balancing
# values and NO outcome evaluation — every such fact is read back from MailRun.
#
# Turn flow: the player DRAFTS 1-3 cards into the mail (slots) and judges the
# resulting TEXT; there is no effect preview. "Mail senden" bundles the drafted
# cards into one turn via MailRun.play_mail(). The bar effect is then revealed
# card by card (last_mail_steps), never before sending. Recon cards are consumed;
# generic cards are inexhaustible, so the player is never left without options.
#
# Layout sits under the persistent OSChrome bar (content starts at y >= 96).
extends Control

signal advance_requested

const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const MailRun := preload("res://scenarios/spear_phishing/data/mail_builder_state.gd")
const MailCard := preload("res://scenarios/spear_phishing/data/mail_card.gd")
const StatusBars := preload("res://scenarios/spear_phishing/components/mail_status_bars.gd")
const Preview := preload("res://scenarios/spear_phishing/components/mail_preview.gd")
const BossChat := preload("res://scenarios/spear_phishing/components/mail_boss_chat.gd")
const HandCard := preload("res://scenarios/spear_phishing/components/mail_hand_card.gd")

const MAX_SLOTS := 3
const PAYLOAD_SCROLL_TIME := 0.45
const REVEAL_STEP_TIME := 0.5
const TOAST_HOLD := 2.6
const REPLY_VARIANTS := 3     # HANNES_REPLY_<STATE>_1..N per state, rotated
const REPLY_HOLD := 1.4       # let the final reply read before the outcome overlay

var _run
var _slots: Array = []          # cards drafted into the current mail (order)
var _consumed: Dictionary = {}  # consumed non-generic card ids
var _cards: Array = []          # MailHandCard widgets, current hand
var _bars
var _preview
var _boss
var _hand_row: HBoxContainer
var _hand_scroll: ScrollContainer
var _turn_label: Label
var _count_label: Label
var _send_button: Button
var _pass_button: Button
var _built := false
var _revealing := false
var _boss_fired: Dictionary = {}
var _last_probe_done := false
var _reply_rotation: Dictionary = {}  # Hannes state name -> times shown (rotation)


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_build()


func _on_visibility_changed() -> void:
	if visible and not _built:
		_build()


func _build() -> void:
	_built = true
	_run = MailRun.new(GameState.mission_turn_budget)
	_build_layout()
	_rebuild_hand()
	_refresh_committed()
	_boss.say("MAIL_BOSS_INTRO")


# --- layout ------------------------------------------------------------------

func _build_layout() -> void:
	var content := VBoxContainer.new()
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 60
	content.offset_top = 96
	content.offset_right = -60
	content.offset_bottom = -50
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 18)
	content.add_child(top)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	left.add_theme_constant_override("separation", 18)
	top.add_child(left)

	_bars = StatusBars.new()
	left.add_child(_bars)

	_preview = Preview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)

	_boss = BossChat.new()
	_boss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss.size_flags_stretch_ratio = 1.0
	_boss.custom_minimum_size.x = 440
	top.add_child(_boss)

	content.add_child(_build_hand_bar())


func _build_hand_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size.y = 196
	var box := DarkMailPalette.flat_box(
		DarkMailPalette.BG_RAISED, Color(DarkMailPalette.GREEN, 0.35), DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	_hand_scroll = ScrollContainer.new()
	_hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_hand_scroll)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 12)
	_hand_scroll.add_child(_hand_row)

	var controls := VBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	row.add_child(controls)

	_turn_label = Label.new()
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DarkMailPalette.apply_mono_label(_turn_label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN)
	controls.add_child(_turn_label)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DarkMailPalette.apply_mono_label(
		_count_label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	controls.add_child(_count_label)

	_send_button = Button.new()
	_send_button.text = tr("MAIL_SEND")
	_style_button(_send_button)
	_send_button.pressed.connect(_on_send)
	controls.add_child(_send_button)

	_pass_button = Button.new()
	_pass_button.text = tr("MAIL_END_TURN")
	_style_button(_pass_button)
	_pass_button.pressed.connect(_on_pass)
	controls.add_child(_pass_button)

	return bar


func _style_button(button: Button) -> void:
	var normal := DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.GREEN, DarkMailPalette.BORDER_WIDTH)
	var hover := DarkMailPalette.flat_box(
		Color(DarkMailPalette.GREEN, 0.22), DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	for sb in [normal, hover]:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", DarkMailPalette.flat_box(
		DarkMailPalette.BG_FIELD, DarkMailPalette.TEXT_DIM, DarkMailPalette.BORDER_WIDTH))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", DarkMailPalette.FONT_MONO)
	button.add_theme_font_size_override("font_size", DarkMailPalette.FONT_SIZE_MONO)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, DarkMailPalette.GREEN)
	button.add_theme_color_override("font_disabled_color", DarkMailPalette.TEXT_DIM)


# --- hand --------------------------------------------------------------------

# Rebuilds the hand from the pool minus consumed cards. Generics always return
# (never consumed); the probe flag swaps the probe card for the unlocked window.
func _rebuild_hand() -> void:
	for widget in _cards:
		widget.queue_free()
	_cards = []
	var hand: Array = Pool.build_hand(GameState.collected_find_ids, _run.probe_done)
	for card in hand:
		if not _consumed.has(card.id):
			_add_card_widget(card)
	for widget in _cards:
		widget.refresh(_run)
	_scroll_to_payload_if_ready()


# Once the gate is open the (pulsing) payload must not hide off-screen: after
# the rebuilt hand has laid out, glide the scroll until the card is fully in
# view. Cosmetic only; it never touches slots or the run.
func _scroll_to_payload_if_ready() -> void:
	if _run == null or _run.is_over() or not _run.payload_gate_open():
		return
	var widget = _payload_widget()
	if widget == null:
		return
	await get_tree().process_frame  # fresh widgets: wait for the HBox layout pass
	if not is_instance_valid(widget) or not is_instance_valid(_hand_scroll):
		return
	var view_left := float(_hand_scroll.scroll_horizontal)
	var view_right := view_left + _hand_scroll.size.x
	if widget.position.x >= view_left and widget.position.x + widget.size.x <= view_right:
		return  # already fully visible, do not fight the player's scroll
	var target := clampf(
		widget.position.x + widget.size.x * 0.5 - _hand_scroll.size.x * 0.5,
		0.0, maxf(0.0, _hand_row.size.x - _hand_scroll.size.x))
	var tween := create_tween()
	tween.tween_property(_hand_scroll, "scroll_horizontal", int(target), PAYLOAD_SCROLL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _payload_widget():
	for widget in _cards:
		if widget.card.type == MailCard.Type.PAYLOAD:
			return widget
	return null


func _add_card_widget(card) -> void:
	var widget := HandCard.new()
	widget.setup(card)
	widget.clicked.connect(_toggle_slot.bind(widget))
	_hand_row.add_child(widget)
	_cards.append(widget)


func _find_widget(card_id: StringName):
	for widget in _cards:
		if widget.card.id == card_id:
			return widget
	return null


# --- drafting ----------------------------------------------------------------

func _toggle_slot(_card, widget) -> void:
	if _revealing or _run.is_over():
		return
	var card = widget.card
	if _slots.has(card):
		_slots.erase(card)
		widget.set_slotted(false)
		_preview.rebuild_draft(_slots)
	elif _slots.size() < MAX_SLOTS:
		_slots.append(card)
		widget.set_slotted(true)
		_preview.finish_typing()  # skip any running type-in before the next one
		_preview.add_draft_fragment(card, true)
	else:
		return
	_refresh_controls()


# --- send: bundle the draft into one turn, then reveal card by card ----------

func _on_send() -> void:
	if _revealing or _run.is_over() or _slots.is_empty():
		return
	_preview.finish_typing()
	var cards: Array = _slots.duplicate()
	_commit_mail(cards)
	_start_reveal(cards)


# Applies the mail to the engine and syncs the turn counter. Split from the
# reveal (which is cosmetic) so the commit is synchronous and testable.
func _commit_mail(cards: Array) -> void:
	var turns_before: int = _run.turns_left
	_run.play_mail(cards)
	if _run.turns_left < turns_before:
		GameState.consume_mission_turn()


func _on_pass() -> void:
	if _revealing or _run.is_over():
		return
	var turns_before: int = _run.turns_left
	_run.pass_turn()
	if _run.turns_left < turns_before:
		GameState.consume_mission_turn()
	# Passing discards the unsent draft: the rebuilt widgets start unslotted, so
	# stale _slots entries would ghost (identity check) and mis-pulse the payload.
	if not _slots.is_empty():
		_slots.clear()
		_preview.rebuild_draft(_slots)
	_rebuild_hand()
	_refresh_committed()
	if _run.is_over():
		_handle_outcome()


# Staggered reveal: step the bars through each card's post-effect snapshot and
# flash the acting card. The engine has already resolved everything; this is a
# cosmetic catch-up, so an interrupted animation never desyncs state.
func _start_reveal(cards: Array) -> void:
	_revealing = true
	_refresh_controls()
	var steps: Array = _run.last_mail_steps
	if steps.is_empty():
		_finish_reveal(cards)
		return
	var tween := create_tween()
	for step in steps:
		tween.tween_callback(_reveal_step.bind(step))
		tween.tween_interval(REVEAL_STEP_TIME)
	tween.tween_callback(_finish_reveal.bind(cards))


func _reveal_step(step: Dictionary) -> void:
	_bars.show_values(step["suspicion"], step["pressure"])
	var widget = _find_widget(step["id"])
	if widget != null:
		widget.flash()


func _finish_reveal(cards: Array) -> void:
	_revealing = false
	for card in cards:
		if not Pool.is_generic(card.id):
			_consumed[card.id] = true
	_slots.clear()
	# Seal the sent mail into the thread, then Hannes replies from the new state.
	_preview.seal_draft()
	_preview.add_reply(tr(_hannes_reply_key()))
	_check_probe_flip()
	_boss_react(cards)
	if _run.is_over():
		# No hand rebuild on this path: refresh the surviving widgets so the
		# payload pulse/arrow stop and every card disables with the dead run.
		for widget in _cards:
			widget.refresh(_run)
		_refresh_committed()
		_handle_outcome()  # records the result now; the advance follows the reply
	else:
		_preview.begin_new_draft()
		_rebuild_hand()
		_refresh_committed()


# Picks Hannes' reply key for his current state, rotating through the variants so
# a repeated state does not repeat the same line.
func _hannes_reply_key() -> String:
	var state_name: String = Pool.HannesState.keys()[_run.hannes_state()]
	var seen: int = _reply_rotation.get(state_name, 0)
	_reply_rotation[state_name] = seen + 1
	return "HANNES_REPLY_%s_%d" % [state_name, (seen % REPLY_VARIANTS) + 1]


# --- probe: flip the flag + toast (the hand rebuild swaps the unlocked card) --

func _check_probe_flip() -> void:
	if _run.probe_done and not _last_probe_done:
		_last_probe_done = true
		GameState.probe_signature_obtained = true
		_show_toast(tr("MAIL_TOAST_PROBE"))


# --- handler chat: one state-triggered line per mail, each fires once ---------

func _boss_react(cards: Array) -> void:
	if _has_schrott(cards) and _fire("schrott"):
		_boss.say("MAIL_BOSS_SCHROTT")
	elif _run.suspicion >= Pool.SPAM_THRESHOLD and _fire("sus_crit"):
		_boss.say("MAIL_BOSS_SUSPICION_CRITICAL")
	elif _run.suspicion >= Pool.SUSPICION_TARGET + 2 and _fire("sus_high"):
		_boss.say("MAIL_BOSS_SUSPICION_HIGH")
	elif _run.payload_would_win() and _fire("ready"):
		_boss.say("MAIL_BOSS_PAYLOAD_READY")
	elif _run.payload_gate_open() and _fire("pressure_ok"):
		_boss.say("MAIL_BOSS_PRESSURE_OK")


func _has_schrott(cards: Array) -> bool:
	for card in cards:
		if card.type == MailCard.Type.SCHROTT:
			return true
	return false


func _fire(key: String) -> bool:
	if _boss_fired.has(key):
		return false
	_boss_fired[key] = true
	return true


# --- live controls -----------------------------------------------------------

func _refresh_committed() -> void:
	_bars.update(_run)
	_turn_label.text = tr("OSCHROME_TURNS") % [_run.turns_left, GameState.mission_turn_budget]
	_refresh_controls()


func _refresh_controls() -> void:
	_count_label.text = tr("MAIL_DRAFT_COUNT") % _slots.size()
	_send_button.disabled = _revealing or _run.is_over() or _slots.is_empty()
	_pass_button.disabled = _revealing or _run.is_over()


# --- outcome: hand the run to Resolve ----------------------------------------

# Records the finished run for Resolve, lets Hannes' final reply read for a
# beat, then advances. Resolve now owns the whole outcome presentation, so
# there is no result popup here anymore — this just hands off.
func _handle_outcome() -> void:
	var name: String = MailRun.Outcome.keys()[_run.outcome]
	GameState.set_mail_result({
		"outcome": name,
		"suspicion": _run.suspicion,
		"pressure": _run.pressure,
		"turns_used": _run.turns_used(),
		"played": _run.played.duplicate(),
	})
	var tween := create_tween()
	tween.tween_interval(REPLY_HOLD)
	tween.tween_callback(func() -> void: advance_requested.emit())


# --- probe toast: a brief note that floats in and fades out -------------------

func _show_toast(message: String) -> void:
	var toast := PanelContainer.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -220
	toast.offset_top = 20
	toast.offset_right = 220
	var box := DarkMailPalette.flat_box(
		DarkMailPalette.BG_PANEL, DarkMailPalette.GREEN_BRIGHT, DarkMailPalette.BORDER_WIDTH)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	toast.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DarkMailPalette.apply_mono_label(label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN_BRIGHT)
	label.text = message
	toast.add_child(label)
	add_child(toast)

	var tween := create_tween()
	tween.tween_interval(TOAST_HOLD)
	tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	tween.tween_callback(toast.queue_free)
