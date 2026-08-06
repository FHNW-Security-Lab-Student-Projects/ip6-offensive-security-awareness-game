# Headless test for the study's data collection: the PromptClock that measures
# decision times, the EventBus graded/ungraded helpers, the canonical event
# schema every emitted event has to satisfy, and the Recon junk grading that the
# error rate is computed from. Plain SceneTree script, no test framework.
#
# Run:
#   godot --headless --path . -s tests/test_telemetry.gd
#
# Every check compares an expected value against the actual one and prints
# "ok" or "FAIL". The run ends with TEST DONE and exit code 0 when every check
# passed, otherwise with the failure count and exit code 1.
extends SceneTree

const PromptClock := preload("res://scenarios/base/prompt_clock.gd")
const Check := preload("res://tests/check.gd")

# Event contract: these keys must exist on EVERY event, or
# the post-hoc analysis cannot read the file as one table.
const CANONICAL_KEYS := [
	"phase", "scenario_id", "action", "is_correct", "latency_ms", "payload",
]

var _events: Array = []
var _recon: Control
var _done := false
var _c := Check.new()


func _initialize() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)
	_test_prompt_clock()
	_test_event_bus_helpers()
	_ensure_translations()
	var scene: PackedScene = load("res://scenarios/spear_phishing/states/recon.tscn")
	_recon = scene.instantiate()
	root.add_child(_recon)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _events_of(action: String) -> Array:
	var out: Array = []
	for e in _events:
		if e.get("action") == action:
			out.append(e)
	return out


# --- PromptClock -------------------------------------------------------------

func _test_prompt_clock() -> void:
	var clock := PromptClock.new()
	_c.eq("unmarked clock reports UNKNOWN", -1, clock.take())
	_c.eq("unmarked elapsed reports UNKNOWN", -1, clock.elapsed())

	clock.mark()
	_c.ok("marked clock elapsed is measurable", clock.elapsed() >= 0)
	_c.ok("elapsed does NOT consume the mark", clock.elapsed() >= 0)
	_c.ok("take returns a measurement", clock.take() >= 0)
	_c.eq("take consumed the mark", -1, clock.take())


# --- EventBus helpers --------------------------------------------------------

func _test_event_bus_helpers() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus == null:
		_c.ok("EventBus autoload present", false)
		return

	bus.emit_decision("t_scenario", "graded_wrong", false, 1234, {"k": "v"})
	var graded: Array = _events_of("graded_wrong")
	_c.eq("emit_decision produced one event", 1, graded.size())
	_c.eq("emit_decision phase is action", "action", graded[0]["phase"])
	_c.eq("emit_decision keeps is_correct false", false, graded[0]["is_correct"])
	_c.eq("emit_decision carries latency", 1234, graded[0]["latency_ms"])
	_c.eq("emit_decision passes extras through", "v", graded[0]["payload"].get("k"))

	bus.emit_action("t_scenario", "ungraded", 42)
	var ungraded: Array = _events_of("ungraded")
	_c.eq("emit_action produced one event", 1, ungraded.size())
	# The whole point of the ungraded helper: it must never pollute the error
	# rate, so is_correct has to stay null rather than default to false.
	_c.ok("emit_action leaves is_correct null", ungraded[0]["is_correct"] == null)
	_c.eq("emit_action carries latency", 42, ungraded[0]["latency_ms"])


# --- Recon grading -----------------------------------------------------------

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var finds: Array[ReconFind] = ReconPool.get_finds()
	var junk := _find_by_id(finds, &"q6x_lob")
	var good := _find_by_id(finds, &"q6_kununu")
	var noise := _find_by_id(finds, &"n_kmunu_neutral")

	_recon.collect(good)
	var good_events := _events_of("recon_find_collected")
	_c.ok("collecting a real lead is graded correct",
		good_events.size() == 1 and good_events[0]["is_correct"] == true)

	_recon.collect(junk)
	good_events = _events_of("recon_find_collected")
	_c.eq("collecting junk is graded WRONG", false, good_events[1]["is_correct"])
	_c.eq("junk event flags is_junk", true, good_events[1]["payload"].get("is_junk"))
	_c.eq("collect event names the find", "q6x_lob", good_events[1]["payload"].get("find_id"))

	# Noise is not collectable at all, so it must not produce a graded event and
	# must not count against the player.
	_recon.collect(noise)
	_c.eq("noise emits no collect event", 2, _events_of("recon_find_collected").size())

	_recon.uncollect(junk)
	var undone := _events_of("recon_find_uncollected")
	_c.eq("uncollect is recorded", 1, undone.size())
	_c.ok("uncollect stays ungraded", undone[0]["is_correct"] == null)

	_recon._on_advance_button_pressed()
	var summary := _events_of("recon_completed")
	_c.eq("advance emits one summary", 1, summary.size())
	_c.eq("summary counts the kept finds", 1, summary[0]["payload"].get("collected_count"))
	_c.eq("summary counts visited sources", 1, summary[0]["payload"].get("sources_opened"))

	_test_schema()
	quit(_c.finish())
	return true


# --- schema conformance ------------------------------------------------------

# Guards the event contract across every event this run
# produced, so a new emit site cannot quietly ship a half-filled event.
func _test_schema() -> void:
	var missing := 0
	var bad_grade := 0
	for e in _events:
		for key in CANONICAL_KEYS:
			if not e.has(key):
				missing += 1
		var graded = e.get("is_correct")
		if graded != null and typeof(graded) != TYPE_BOOL:
			bad_grade += 1
	# 2 helper probes + 2 collects + 1 uncollect + 1 summary; noise emits nothing.
	_c.eq("events captured", 6, _events.size())
	_c.eq("all events carry the canonical keys", 0, missing)
	_c.eq("is_correct is bool or null everywhere", 0, bad_grade)


# --- helpers -----------------------------------------------------------------

func _find_by_id(finds: Array[ReconFind], id: StringName) -> ReconFind:
	for f in finds:
		if f.id == id:
			return f
	return null


func _ensure_translations() -> void:
	if TranslationServer.get_loaded_locales().size() > 0:
		return
	var i18n := root.get_node_or_null("I18n")
	if i18n != null and i18n.has_method("reload"):
		i18n.reload()
