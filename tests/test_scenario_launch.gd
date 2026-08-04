# Headless test for the scenario launch path: SceneTransition.launch_scenario
# loads the scene AND starts its lifecycle. Nothing else does — a scenario no
# longer bootstraps itself in _ready().
#
# Guards a regression the other tests cannot see, because they instantiate the
# scenario scene directly instead of going through the launcher:
# change_scene_to_file is deferred, so current_scene still points at the old
# scene one frame later. Reading it too early silently skipped start_scenario,
# which left the menu music running and the turn budget at 0/0.
#
# Run:
#   godot --headless --path . -s tests/test_scenario_launch.gd
#
# Every check compares an expected value against the actual one and prints
# "ok" or "FAIL". The run ends with TEST DONE and exit code 0 when every check
# passed, otherwise with the failure count and exit code 1.
extends SceneTree

const Check := preload("res://tests/check.gd")

# The launcher fades out and back in (0.35s each) around a deferred scene swap,
# so the result is several frames away rather than available on the next one.
const TIMEOUT_FRAMES := 400

var _events: Array = []
var _frames := 0
var _launched := false
var _c := Check.new()


func _initialize() -> void:
	# Autoloads reached by node path: the globals are not resolvable in a bare
	# `-s` script's compile scope (same reason test_os_chrome does it).
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _starts() -> Array:
	var out: Array = []
	for e in _events:
		if e.get("phase") == "scenario_start":
			out.append(e)
	return out


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var config := root.get_node_or_null("Config")
		var transition := root.get_node_or_null("SceneTransition")
		if config == null or transition == null:
			print("FAIL autoloads Config/SceneTransition missing")
			quit(1)
			return true
		transition.launch_scenario(config.get_scenario(&"spear_phishing"))
		_launched = true
		return false
	if not _launched:
		return false
	if _starts().is_empty() and _frames < TIMEOUT_FRAMES:
		return false

	_test_launch()

	quit(_c.finish())
	return true


func _test_launch() -> void:
	var starts := _starts()
	_c.eq("launch_scenario emits exactly one scenario_start", 1, starts.size())
	if starts.is_empty():
		return
	_c.eq("scenario_start carries the id from the ScenarioConfig",
		"spear_phishing", starts[0].get("scenario_id"))

	var gs = root.get_node_or_null("GameState")
	_c.eq("GameState knows the running scenario",
		"spear_phishing", gs.current_scenario_id)
	_c.eq("session state moved to IN_SCENARIO", gs.State.IN_SCENARIO, gs.state)
	# _setup() ran: the shell seeds the mission HUD from the card pool budget.
	# This is the "0/0 turns" symptom.
	_c.ok("turn budget was seeded by _setup()", gs.mission_turn_budget > 0)
	# start_scenario() silences the menu music before gameplay begins. Read off
	# the player itself because the fade-out only stops it half a second later.
	var music = root.get_node_or_null("MusicPlayer")
	_c.ok("menu music was stopped", not music._player.playing or music._fading_out)
