# Headless test for the bad_usb decision logging. The level grades positionally:
# on the opening step of each path the FIRST option blows the cover, on the
# follow-up step the SECOND one does. That mapping is what the study's error
# rate rests on, so it is asserted here against the real scene.
#
# Run:
#   godot --headless --path . -s tests/test_bad_usb_telemetry.gd
extends SceneTree

const Check := preload("res://tests/check.gd")

var _events: Array = []
var _usb: Node
var _done := false
var _c := Check.new()


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

	# SceneTransition.launch_scenario does this in the game; a test loads the
	# scene directly and has to start the lifecycle itself. Not in _initialize:
	# add_child() defers the ready notification there, so the @onready node
	# references _setup() needs would still be null.
	_usb.start_scenario("bad_usb")

	_test_grading()
	_test_failure_counting()
	_test_reception_paths()
	_test_dead_end()
	_test_debrief()
	_test_chrome_visibility()
	_test_music()

	quit(_c.finish())
	return true


# --- the grading tables ------------------------------------------------------

func _test_grading() -> void:
	# Opening steps: option 1 blows the cover, option 2 is the safe answer.
	for step in [10, 20, 30]:
		var wrong := _answer(step, 1)
		_c.eq("step %d choice 1 graded wrong" % step, false, wrong.get("is_correct"))
		var right := _answer(step, 2)
		_c.eq("step %d choice 2 graded right" % step, true, right.get("is_correct"))

	# Follow-up steps: the polarity flips.
	for step in [11, 21, 31]:
		var right := _answer(step, 1)
		_c.eq("step %d choice 1 graded right" % step, true, right.get("is_correct"))
		var wrong := _answer(step, 2)
		_c.eq("step %d choice 2 graded wrong" % step, false, wrong.get("is_correct"))

	# Closing steps only offer one option and it is always the safe one.
	for step in [12, 22, 32]:
		var event := _answer(step, 1)
		_c.eq("step %d closing answer graded right" % step, true, event.get("is_correct"))

	var sample := _answer(10, 1)
	_c.eq("choice event names its path", "stressed", sample["payload"].get("path"))
	_c.eq("choice event records the step", 10, sample["payload"].get("step"))
	_c.eq("choice event records the option", 1, sample["payload"].get("choice"))
	_c.eq("office path labelled", "office_npc", _answer(30, 2)["payload"].get("path"))


# --- failure counting --------------------------------------------------------

func _test_failure_counting() -> void:
	_usb._failure_count = 0
	_answer(10, 2)  # safe answer, must not count
	_c.eq("a right answer leaves the failure count at 0", 0, _usb._failure_count)
	_answer(10, 1)  # blown cover
	_answer(21, 2)  # blown cover on another path
	_c.eq("two blown covers counted", 2, _usb._failure_count)
	# attempt is the run the decision was made in: the second blown cover
	# happened during attempt 2, and only afterwards does attempt 3 begin.
	_c.eq("attempt number rides along", 2, _last_choice()["payload"].get("attempt"))

	# A blown cover now ends the run instead of resetting to the entrance, and
	# without the popup that used to sit in between. Counted relative to what the
	# grading test already produced: every wrong answer there ends a run too.
	var before := _events_of("run_failed").size()
	_usb._fail_run()
	# _fail_run hands the substate change to SceneTransition, which fades for
	# 350ms first, so the debrief does not exist yet in this synchronous test.
	# The telemetry below fires immediately; the screen is forced in afterwards.
	var failed := _events_of("run_failed")
	_c.eq("blown cover recorded", 1, failed.size() - before)
	_c.eq("no failure popup is shown", false, _usb._ui_failure_popup.visible)
	_c.ok("failure event stays ungraded", failed[-1]["is_correct"] == null)
	_usb._change_substate(7)  # what the fade would have done
	_c.eq("run is marked as failed", true, _usb._run_failed)


# --- reception approach ------------------------------------------------------

func _test_reception_paths() -> void:
	_usb._on_stressed_pressed()
	var approaches := _events_of("reception_approach")
	_c.eq("reception approach recorded", 1, approaches.size())
	# Both pretexts are viable, so this must not be scored as right or wrong.
	_c.ok("reception approach is ungraded", approaches[0]["is_correct"] == null)
	_c.eq("stressed pretext labelled", "stressed", approaches[0]["payload"].get("path"))

	_usb._on_confident_pressed()
	approaches = _events_of("reception_approach")
	_c.eq("confident pretext labelled", "confident", approaches[1]["payload"].get("path"))


# --- dead end ----------------------------------------------------------------

func _test_dead_end() -> void:
	_usb._restricted_attempts = 0
	_usb._on_restricted_btn_pressed()
	var attempts := _events_of("restricted_elevator_attempt")
	_c.eq("elevator dead end recorded", 1, attempts.size())
	_c.eq("elevator dead end graded wrong", false, attempts[0]["is_correct"])
	_c.eq("elevator attempt numbered", 1, attempts[0]["payload"].get("attempt"))


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
	_c.eq("failed run reports COVER_BLOWN", "COVER_BLOWN", _debrief_outcome())
	_c.eq("failed run is graded wrong", false, _debrief_correct())
	_c.eq("failed run gets the short debrief", 2, _usb._debrief._stages.size())
	# The notice the popup used to carry now opens the fail screen.
	_c.ok("fail screen opens with the level's notice",
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
	_c.eq("one debrief row per completion", 2, debriefs.size())
	var payload: Dictionary = debriefs[-1]["payload"]
	_c.eq("successful run reports USB_PLANTED", "USB_PLANTED", payload.get("outcome"))
	_c.eq("debrief carries the failures", 3, payload.get("failures"))
	_c.eq("debrief carries the detours", 2, payload.get("restricted_attempts"))
	_c.eq("debrief carries the pretext", "confident", payload.get("reception_path"))


# --- OS bar visibility ---------------------------------------------------------

# The bar frames the two DarkMail screens; over the pixel-art world it reads as
# a foreign overlay, so it is hidden during the playable phases.
func _test_chrome_visibility() -> void:
	var chrome: Control = _usb.get_node("BadUSBScenario/CanvasLayer/OSChrome")
	_usb._change_substate(0)  # BRIEFING
	_c.eq("bar shown in the briefing", true, chrome.visible)
	# Checked per substate instead of bailing out on the first offender, so a
	# regression names the phase it happened in.
	for playable in [1, 2, 3, 4, 5, 6]:  # STREET .. OFFICE
		_usb._change_substate(playable)
		_c.eq("bar hidden in playable substate %d" % playable, false, chrome.visible)
	_usb._change_substate(7)  # RESOLVE
	_c.eq("bar shown again on the debrief", true, chrome.visible)


# --- music ---------------------------------------------------------------------

func _first_player(host: Node) -> AudioStreamPlayer:
	for child in host.get_children():
		if child is AudioStreamPlayer:
			return child as AudioStreamPlayer
	return null


# The world bed hangs off its own holder so it survives a change of area. Tying
# it to the world nodes would restart the track at every doorway.
func _test_music() -> void:
	var host: Control = _usb.get_node("BadUSBScenario/CanvasLayer/WorldMusicHost")
	var world := _first_player(host)
	_c.ok("world music has a track", world != null and world.stream != null)
	# Routed through the Music bus, so the settings slider reaches it.
	_c.eq("world music on the Music bus", "Music", world.bus)

	# Checked via the holder, not via `playing`: fade_out stops playback from a
	# tween half a second later, which no headless test ever reaches.
	_usb._change_substate(0)  # BRIEFING brings its own track
	_c.eq("holder hidden in the briefing", false, host.visible)

	_usb._change_substate(3)  # Lobby
	_c.eq("plays once gameplay starts", true, world.playing)
	_usb._change_substate(6)  # Office, still a playable phase
	_c.eq("keeps playing across areas", true, world.playing)

	_usb._change_substate(7)  # Debrief
	_c.eq("holder hidden on the debrief", false, host.visible)
	var debrief_music := _first_player(_usb._debrief)
	_c.ok("debrief brings its own track",
		debrief_music != null and debrief_music.stream != null)
