# The two target bars. Pure view: values, targets and the spam threshold are read
# straight off the run, nothing is decided here.
#
# The current value IS shown as a number — it is state, not a hidden card effect.
# Only the card effects themselves stay numberless.
extends VBoxContainer

const Pool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

const CELL_SIZE := Vector2(26, 18)
const CELL_GAP := 3
const NAME_WIDTH := 200

var _sus_cells: Array[Panel] = []
var _pre_cells: Array[Panel] = []
var _sus_value: Label
var _pre_value: Label
# Last painted values, so the blip fires only when a bar actually moves.
var _last_suspicion := -1
var _last_pressure := -1


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_sus_value = Label.new()
	_pre_value = Label.new()
	_sus_cells = _add_bar_row(
		tr("MAIL_BAR_SUSPICION"), Pool.SUSPICION_BAR_MAX, Pool.SUSPICION_TARGET,
		"%s%d" % [tr("MAIL_BAR_TARGET_LOW"), Pool.SUSPICION_TARGET], _sus_value)
	_pre_cells = _add_bar_row(
		tr("MAIL_BAR_PRESSURE"), Pool.PRESSURE_BAR_MAX, Pool.PRESSURE_TARGET,
		"%s%d" % [tr("MAIL_BAR_TARGET_HIGH"), Pool.PRESSURE_TARGET], _pre_value)


# Returns the cells so update() can recolour them. The target cell carries a
# bright top border notch.
func _add_bar_row(name_text: String, cell_count: int, target: int, target_hint: String,
		value_label: Label) -> Array[Panel]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var name_label := Label.new()
	name_label.custom_minimum_size.x = NAME_WIDTH
	DarkMailPalette.apply_mono_label(
		name_label, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_GREEN)
	name_label.text = name_text
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var cells_box := HBoxContainer.new()
	cells_box.add_theme_constant_override("separation", CELL_GAP)
	cells_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var cells: Array[Panel] = []
	for i in cell_count:
		var cell := Panel.new()
		cell.custom_minimum_size = CELL_SIZE
		var is_target := i == target - 1
		cell.add_theme_stylebox_override("panel", _cell_box(DarkMailPalette.BG_FIELD, is_target))
		cells_box.add_child(cell)
		cells.append(cell)
	row.add_child(cells_box)

	DarkMailPalette.apply_mono_label(
		value_label, DarkMailPalette.FONT_SIZE_MONO, DarkMailPalette.GREEN)
	value_label.custom_minimum_size.x = 34
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	var hint := Label.new()
	DarkMailPalette.apply_mono_label(
		hint, DarkMailPalette.FONT_SIZE_MONO_SMALL, DarkMailPalette.TEXT_DIM)
	hint.text = target_hint
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	add_child(row)
	return cells


func _cell_box(fill: Color, is_target: bool) -> StyleBoxFlat:
	var sb := DarkMailPalette.flat_box(fill)
	if is_target:
		sb.border_width_top = DarkMailPalette.BORDER_WIDTH
		sb.border_color = DarkMailPalette.GREEN_BRIGHT
	return sb


# Repaints both bars from the run's committed state.
func update(run) -> void:
	show_values(run.suspicion, run.pressure)


# Takes explicit values, because the staggered reveal paints the intermediate
# per-card snapshots through here too. Suspicion fills green up to its target,
# amber in the tolerated zone, red past the spam threshold; pressure fills amber
# while building and green once the gate is open.
func show_values(suspicion: int, pressure: int) -> void:
	_paint_suspicion(suspicion)
	_paint_pressure(pressure)
	_sus_value.text = str(suspicion)
	_pre_value.text = str(pressure)
	_sus_value.add_theme_color_override("font_color", _suspicion_color(suspicion))
	_pre_value.add_theme_color_override(
		"font_color",
		DarkMailPalette.GREEN if pressure >= Pool.PRESSURE_TARGET else DarkMailPalette.WARN_AMBER)

	# Rising suspicion means the card backfired: its own warning sound INSTEAD of
	# the neutral blip, never both.
	var had_previous: bool = _last_suspicion != -1
	var moved: bool = had_previous \
		and (suspicion != _last_suspicion or pressure != _last_pressure)
	var suspicion_rose: bool = had_previous and suspicion > _last_suspicion
	_last_suspicion = suspicion
	_last_pressure = pressure
	if moved:
		if suspicion_rose:
			SfxPlayer.play_suspicion()
		else:
			SfxPlayer.play_notification()


func _paint_suspicion(value: int) -> void:
	for i in _sus_cells.size():
		var filled := i < value
		var fill := DarkMailPalette.BG_FIELD
		if filled:
			fill = _suspicion_color(i + 1)
		_sus_cells[i].add_theme_stylebox_override(
			"panel", _cell_box(fill, i == Pool.SUSPICION_TARGET - 1))


func _paint_pressure(value: int) -> void:
	for i in _pre_cells.size():
		var filled := i < value
		var fill := DarkMailPalette.BG_FIELD
		if filled:
			fill = DarkMailPalette.GREEN if i + 1 >= Pool.PRESSURE_TARGET else DarkMailPalette.WARN_AMBER
		_pre_cells[i].add_theme_stylebox_override(
			"panel", _cell_box(fill, i == Pool.PRESSURE_TARGET - 1))


func _suspicion_color(value: int) -> Color:
	if value > Pool.SPAM_THRESHOLD:
		return DarkMailPalette.ALERT_RED
	if value > Pool.SUSPICION_TARGET:
		return DarkMailPalette.WARN_AMBER
	return DarkMailPalette.GREEN
