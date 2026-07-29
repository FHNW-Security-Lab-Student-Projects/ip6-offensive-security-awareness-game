# Headless test for the bad_usb decision logging. The level grades positionally:
# on the opening step of each path the FIRST option blows the cover, on the
# follow-up step the SECOND one does. That mapping is what the study's error
# rate rests on, so it is asserted here against the real scene.
#
# Run:
#   godot --headless --path . -s tests/test_bad_usb_telemetry.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

var _events: Array = []
var _usb: Node
var _done := false


func _initialize() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)
	var scene: PackedScene = load("res://scenarios/bad_usb/bad_usb.tscn")
	_usb = scene.instantiate()
	root.add_child(_usb)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _events_of(action: String) -> Array:
	var out: Array = []
	for e in _events:
		if e.get("action") == action:
			out.append(e)
	return out


func _last_choice() -> Dictionary:
	var all := _events_of("dialogue_choice")
	return all[-1] if all.size() > 0 else {}


# Drives one dialogue answer and returns the event it produced.
func _answer(step: int, choice: int) -> Dictionary:
	_usb._dialogue_step = step
	if choice == 1:
		_usb._on_dialog_choice_1_pressed()
	else:
		_usb._on_dialog_choice_2_pressed()
	return _last_choice()


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	_test_grading()
	_test_failure_counting()
	_test_reception_paths()
	_test_dead_end()
	_test_debrief()

	print("TEST DONE")
	quit()
	return true


# --- the grading tables ------------------------------------------------------

func _test_grading() -> void:
	# Opening steps: option 1 blows the cover, option 2 is the safe answer.
	for step in [10, 20, 30]:
		var wrong := _answer(step, 1)
		print("step %d choice 1 graded wrong (expect false): " % step, wrong.get("is_correct"))
		var right := _answer(step, 2)
		print("step %d choice 2 graded right (expect true): " % step, right.get("is_correct"))

	# Follow-up steps: the polarity flips.
	for step in [11, 21, 31]:
		var right := _answer(step, 1)
		print("step %d choice 1 graded right (expect true): " % step, right.get("is_correct"))
		var wrong := _answer(step, 2)
		print("step %d choice 2 graded wrong (expect false): " % step, wrong.get("is_correct"))

	# Closing steps only offer one option and it is always the safe one.
	for step in [12, 22, 32]:
		var event := _answer(step, 1)
		print("step %d closing answer graded right (expect true): " % step, event.get("is_correct"))

	var sample := _answer(10, 1)
	print("choice event names its path (expect stressed): ", sample["payload"].get("path"))
	print("choice event records the step (expect 10): ", sample["payload"].get("step"))
	print("choice event records the option (expect 1): ", sample["payload"].get("choice"))
	print("office path labelled (expect office_npc): ", _answer(30, 2)["payload"].get("path"))


# --- failure counting --------------------------------------------------------

func _test_failure_counting() -> void:
	_usb._failure_count = 0
	_answer(10, 2)  # safe answer, must not count
	print("a right answer leaves the failure count at 0 (expect 0): ", _usb._failure_count)
	_answer(10, 1)  # blown cover
	_answer(21, 2)  # blown cover on another path
	print("two blown covers counted (expect 2): ", _usb._failure_count)
	# attempt is the run the decision was made in: the second blown cover
	# happened during attempt 2, and only afterwards does attempt 3 begin.
	print("attempt number rides along (expect 2): ", _last_choice()["payload"].get("attempt"))

	# A blown cover now ends the run instead of resetting to the entrance, and
	# without the popup that used to sit in between. Counted relative to what the
	# grading test already produced: every wrong answer there ends a run too.
	var before := _events_of("run_failed").size()
	_usb._fail_run()
	var failed := _events_of("run_failed")
	print("blown cover recorded (expect 1 more): ", failed.size() - before)
	print("no failure popup is shown (expect false): ", _usb._ui_failure_popup.visible)
	print("failure event stays ungraded (expect true): ", failed[-1]["is_correct"] == null)
	print("run is marked as failed (expect true): ", _usb._run_failed)


# --- reception approach ------------------------------------------------------

func _test_reception_paths() -> void:
	_usb._on_stressed_pressed()
	var approaches := _events_of("reception_approach")
	print("reception approach recorded (expect 1): ", approaches.size())
	# Both pretexts are viable, so this must not be scored as right or wrong.
	print("reception approach is ungraded (expect true): ", approaches[0]["is_correct"] == null)
	print("stressed pretext labelled (expect stressed): ", approaches[0]["payload"].get("path"))

	_usb._on_confident_pressed()
	approaches = _events_of("reception_approach")
	print("confident pretext labelled (expect confident): ", approaches[1]["payload"].get("path"))


# --- dead end ----------------------------------------------------------------

func _test_dead_end() -> void:
	_usb._restricted_attempts = 0
	_usb._on_restricted_btn_pressed()
	var attempts := _events_of("restricted_elevator_attempt")
	print("elevator dead end recorded (expect 1): ", attempts.size())
	print("elevator dead end graded wrong (expect false): ", attempts[0]["is_correct"])
	print("elevator attempt numbered (expect 1): ", attempts[0]["payload"].get("attempt"))


# --- run summary -------------------------------------------------------------

func _debriefs() -> Array:
	var out: Array = []
	for e in _events:
		if e.get("phase") == "scenario_debrief" and e.get("scenario_id") == "bad_usb":
			out.append(e)
	return out


# The debrief row is emitted when the screen is built, not on the exit button,
# so this drives that instead of complete_scenario.
func _debrief_outcome() -> String:
	return String(_debriefs()[-1]["payload"].get("outcome", ""))


func _debrief_correct():
	return _debriefs()[-1]["is_correct"]


func _test_debrief() -> void:
	# _test_failure_counting left the run in the failed state; a failed run must
	# never be reported as a planted stick.
	print("failed run reports COVER_BLOWN (expect COVER_BLOWN): ", _debrief_outcome())
	print("failed run is graded wrong (expect false): ", _debrief_correct())
	print("failed run gets the short debrief (expect 2): ", _usb._debrief._stages.size())
	# The notice the popup used to carry now opens the fail screen.
	print("fail screen opens with the level's notice (expect true): ",
		String(_usb._debrief._stages[0]["text"]) == tr("BADUSB_FAILURE_TEXT"))

	# Now the successful path: a fresh debrief has to be built for the row to
	# fire again, mirroring what a replay does.
	_usb._run_failed = false
	_usb._failure_count = 3
	_usb._restricted_attempts = 2
	_usb._reception_path = "confident"
	_usb._debrief = null
	_usb._start_resolve_story()

	var debriefs: Array = _debriefs()
	print("one debrief row per completion (expect 2): ", debriefs.size())
	var payload: Dictionary = debriefs[-1]["payload"]
	print("successful run reports USB_PLANTED (expect USB_PLANTED): ", payload.get("outcome"))
	print("debrief carries the failures (expect 3): ", payload.get("failures"))
	print("debrief carries the detours (expect 2): ", payload.get("restricted_attempts"))
	print("debrief carries the pretext (expect confident): ", payload.get("reception_path"))
