# Headless test for the study's data collection: the PromptClock that measures
# decision times, the EventBus graded/ungraded helpers, the canonical event
# schema every emitted event has to satisfy, and the Recon junk grading that the
# error rate is computed from. Plain SceneTree script, no test framework.
#
# Run:
#   godot --headless --path . -s tests/test_telemetry.gd
#
# Every line prints the expected value next to the actual one; a run passes
# when all "expect" values match and it ends with TEST DONE.
extends SceneTree

const PromptClock := preload("res://scenarios/base/prompt_clock.gd")

# Contract from docs/event_schema.md: these keys must exist on EVERY event, or
# the post-hoc analysis cannot read the file as one table.
const CANONICAL_KEYS := [
	"phase", "scenario_id", "action", "is_correct", "latency_ms", "payload",
]

var _events: Array = []
var _recon: Control
var _done := false


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
	print("unmarked clock reports UNKNOWN (expect -1): ", clock.take())
	print("unmarked elapsed reports UNKNOWN (expect -1): ", clock.elapsed())

	clock.mark()
	print("marked clock elapsed is measurable (expect true): ", clock.elapsed() >= 0)
	print("elapsed does NOT consume the mark (expect true): ", clock.elapsed() >= 0)
	print("take returns a measurement (expect true): ", clock.take() >= 0)
	print("take consumed the mark (expect -1): ", clock.take())


# --- EventBus helpers --------------------------------------------------------

func _test_event_bus_helpers() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus == null:
		print("EventBus autoload missing (expect present): false")
		return

	bus.emit_decision("t_scenario", "graded_wrong", false, 1234, {"k": "v"})
	var graded: Array = _events_of("graded_wrong")
	print("emit_decision produced one event (expect 1): ", graded.size())
	print("emit_decision phase is action (expect action): ", graded[0]["phase"])
	print("emit_decision keeps is_correct false (expect false): ", graded[0]["is_correct"])
	print("emit_decision carries latency (expect 1234): ", graded[0]["latency_ms"])
	print("emit_decision passes extras through (expect v): ", graded[0]["payload"].get("k"))

	bus.emit_action("t_scenario", "ungraded", 42)
	var ungraded: Array = _events_of("ungraded")
	print("emit_action produced one event (expect 1): ", ungraded.size())
	# The whole point of the ungraded helper: it must never pollute the error
	# rate, so is_correct has to stay null rather than default to false.
	print("emit_action leaves is_correct null (expect true): ", ungraded[0]["is_correct"] == null)
	print("emit_action carries latency (expect 42): ", ungraded[0]["latency_ms"])


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
	print("collecting a real lead is graded correct (expect true): ",
		good_events.size() == 1 and good_events[0]["is_correct"] == true)

	_recon.collect(junk)
	good_events = _events_of("recon_find_collected")
	print("collecting junk is graded WRONG (expect false): ", good_events[1]["is_correct"])
	print("junk event flags is_junk (expect true): ", good_events[1]["payload"].get("is_junk"))
	print("collect event names the find (expect q6x_lob): ", good_events[1]["payload"].get("find_id"))

	# Noise is not collectable at all, so it must not produce a graded event and
	# must not count against the player.
	_recon.collect(noise)
	print("noise emits no collect event (expect 2): ", _events_of("recon_find_collected").size())

	_recon.uncollect(junk)
	var undone := _events_of("recon_find_uncollected")
	print("uncollect is recorded (expect 1): ", undone.size())
	print("uncollect stays ungraded (expect true): ", undone[0]["is_correct"] == null)

	_recon._on_advance_button_pressed()
	var summary := _events_of("recon_completed")
	print("advance emits one summary (expect 1): ", summary.size())
	print("summary counts the kept finds (expect 1): ", summary[0]["payload"].get("collected_count"))
	print("summary counts visited sources (expect 1): ", summary[0]["payload"].get("sources_opened"))

	_test_schema()
	print("TEST DONE")
	quit()
	return true


# --- schema conformance ------------------------------------------------------

# Guards the contract in docs/event_schema.md across every event this run
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
	print("events captured (expect 6): ", _events.size())
	print("all events carry the canonical keys (expect 0 missing): ", missing)
	print("is_correct is bool or null everywhere (expect 0 bad): ", bad_grade)


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
