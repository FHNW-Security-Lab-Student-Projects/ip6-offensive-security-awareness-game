# Headless test for the study's participant code: the pseudonym that ties a
# session's telemetry to the pre and post questionnaire. Entered on the title
# screen, stamped by Telemetry onto every event.
#
# Run:
#   godot --headless --path . -s tests/test_participant_code.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

var _step := 0
var _events: Array = []
var _game_state: Node
var _bus: Node
var _screen: Control


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _find_field(node: Node) -> LineEdit:
	for child in node.get_children():
		if child is LineEdit and child.name == "ParticipantCode":
			return child
		var found := _find_field(child)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	_step += 1
	if _step == 1:
		_game_state = root.get_node("GameState")
		_bus = root.get_node("EventBus")
		_bus.connect("generic_event", _capture)
		return false
	if _step != 2:
		return false

	_test_normalisation()
	_test_stamping()
	_test_title_screen_field()

	_game_state.set_participant_code("")
	print("TEST DONE")
	quit()
	return true


# --- storage rules -------------------------------------------------------------

func _test_normalisation() -> void:
	_game_state.set_participant_code("P07")
	print("plain code stored as typed (expect P07): ", _game_state.participant_code)

	# A stray space would otherwise split one participant into two rows.
	_game_state.set_participant_code("  P07  ")
	print("surrounding spaces trimmed (expect P07): ", _game_state.participant_code)

	# Free text by design: the study team owns the numbering scheme.
	_game_state.set_participant_code("Gruppe B / 12")
	print("free text kept intact (expect Gruppe B / 12): ", _game_state.participant_code)

	var long_code := "X".repeat(80)
	_game_state.set_participant_code(long_code)
	print("over-long input capped (expect 32): ", _game_state.participant_code.length())

	_game_state.set_participant_code("")
	print("empty code allowed (expect 0): ", _game_state.participant_code.length())


# --- telemetry -----------------------------------------------------------------

# Telemetry enriches on WRITE, not on the signal, so the assertions below read
# the JSONL back off disk. The signal payload deliberately stays the scenario's
# own dictionary; only the persisted line is self-describing.
func _logged_events() -> Array:
	var path: String = root.get_node("Telemetry")._log_path
	var out: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	file.close()
	return out


func _logged_action(action: String) -> Dictionary:
	for e in _logged_events():
		if e.get("action") == action:
			return e
	return {}


func _test_stamping() -> void:
	_game_state.set_participant_code("P42")
	_bus.emit_decision("spear_phishing", "probe_decision", true, 100)
	_bus.emit_action("spear_phishing", "probe_action", 100)
	print("code written on a graded event (expect P42): ",
		_logged_action("probe_decision").get("participant_code"))
	print("code written on an ungraded event (expect P42): ",
		_logged_action("probe_action").get("participant_code"))

	# Changing it must affect only what follows, never rewrite history.
	_game_state.set_participant_code("P43")
	_bus.emit_action("spear_phishing", "later_action", 100)
	print("earlier line keeps the old code (expect P42): ",
		_logged_action("probe_decision").get("participant_code"))
	print("later line carries the new code (expect P43): ",
		_logged_action("later_action").get("participant_code"))

	_game_state.set_participant_code("")
	_bus.emit_action("spear_phishing", "uncoded_action", 100)
	print("blank code writes an empty string (expect true): ",
		_logged_action("uncoded_action").get("participant_code") == "")

	# The raw signal stays untouched; enrichment belongs to the writer.
	print("signal payload is not enriched (expect true): ",
		not _events[-1].has("participant_code"))


# --- title screen field ---------------------------------------------------------

func _test_title_screen_field() -> void:
	_game_state.set_participant_code("P09")
	_screen = (load("res://scenes/StartScreen.tscn") as PackedScene).instantiate()
	root.add_child(_screen)

	var field := _find_field(_screen)
	print("title screen offers the field (expect true): ", field != null)
	if field == null:
		return
	# Returning to the title screen must not wipe a code already entered.
	print("field shows the current code (expect P09): ", field.text)
	print("field is length-capped like the store (expect 32): ", field.max_length)

	field.text = "P11"
	field.text_changed.emit("P11")
	print("typing updates GameState (expect P11): ", _game_state.participant_code)

	_screen.queue_free()
