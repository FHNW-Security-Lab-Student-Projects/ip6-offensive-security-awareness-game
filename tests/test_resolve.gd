# Headless smoke test for the RESOLVE debrief: instantiate the real scene per
# outcome and assert the view reads GameState.mail_result correctly — the right
# outcome feedback, the twist and statistic ALWAYS present (even on WIN), the
# scenario_debrief telemetry firing once with the run's metrics, and the replay
# reset actually wiping the per-run handoff state.
#
# The staged reveal is time-based; the test drives the synchronous reveal_all()
# seam instead of the tween.
#
# Run:
#   godot --headless --path . -s tests/test_resolve.gd
extends SceneTree

const SCENE := "res://scenarios/spear_phishing/states/resolve.tscn"
const Check := preload("res://tests/check.gd")
const RunState := preload("res://scenarios/spear_phishing/data/run_state.gd")

var _events: Array = []
var _done := false
var _run   # the RunState handed to the phase under test
var _c := Check.new()


func _initialize() -> void:
	var bus := root.get_node_or_null("EventBus")
	if bus != null:
		bus.connect("generic_event", _capture)


func _capture(payload: Dictionary) -> void:
	_events.append(payload)


func _debriefs() -> Array:
	var out: Array = []
	for e in _events:
		if e.get("phase", "") == "scenario_debrief":
			out.append(e)
	return out


# Recursively collect every Label's text under a node, so checks do not
# depend on the exact child layout.
func _label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_label_texts(child, out)


# Same, for Button labels (the three exit buttons).
func _button_texts(node: Node, out: Array) -> void:
	if node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_button_texts(child, out)


func _build_resolve(outcome: String):
	# The scenario shell hands the run over before the phase becomes visible;
	# here the scene is visible on add_child, so configure_run comes first.
	_run = RunState.new()
	_run.set_mail_result({
		"outcome": outcome,
		"suspicion": 2,
		"pressure": 8,
		"turns_used": 3,
		"played": [],
	})
	var r = load(SCENE).instantiate()
	r.configure_run(_run)
	root.add_child(r)  # visible by default -> _ready runs _build()
	return r


func _has(texts: Array, key: String) -> bool:
	return texts.has(tr(key))


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# --- 1. Outcome-specific feedback maps from mail_result.outcome -----------
	var cases := {
		"WIN": "RESOLVE_WIN_TITLE",
		"SPAM": "RESOLVE_SPAM_TITLE",
		"KOLLEGEN_RUECKFRAGE": "RESOLVE_KOLLEGEN_TITLE",
		"IGNORIERT": "RESOLVE_IGNORIERT_TITLE",
	}
	for outcome in cases:
		var r = _build_resolve(outcome)
		var texts: Array = []
		_label_texts(r, texts)
		_c.ok("%s shows its title" % outcome, _has(texts, cases[outcome]))
		# Twist + statistic + source appear for EVERY outcome, WIN included.
		_c.ok("%s shows the twist" % outcome, _has(texts, "RESOLVE_TWIST"))
		_c.ok("%s shows the statistic" % outcome, _has(texts, "RESOLVE_STAT"))
		_c.ok("%s shows the source line" % outcome, _has(texts, "RESOLVE_STAT_SOURCE"))
		r.queue_free()

	# --- 2. Unknown/empty result fails safe to the IGNORIERT feedback ---------
	var ru = _build_resolve("")
	var utexts: Array = []
	_label_texts(ru, utexts)
	_c.ok("empty result falls back to IGNORIERT title",
		_has(utexts, "RESOLVE_IGNORIERT_TITLE"))
	_c.ok("empty result still shows twist + stat",
		_has(utexts, "RESOLVE_TWIST") and _has(utexts, "RESOLVE_STAT"))
	ru.queue_free()

	# --- 3. scenario_debrief telemetry: once per build, carrying the metrics --
	var debriefs := _debriefs()
	_c.eq("one debrief event per build so far", 5, debriefs.size())
	var win_debrief: Dictionary = debriefs[0]
	_c.eq("debrief action carries the outcome", "WIN", win_debrief.get("action", ""))
	_c.eq("debrief flags WIN as correct", true, win_debrief.get("is_correct"))
	var wp: Dictionary = win_debrief["payload"]
	_c.eq("debrief payload has outcome", "WIN", wp.get("outcome", ""))
	_c.eq("debrief payload has turns_used", 3, wp.get("turns_used"))
	_c.eq("debrief payload has final bars", "2/8",
		"%s/%s" % [wp.get("suspicion"), wp.get("pressure")])
	var empty_debrief: Dictionary = debriefs[4]
	_c.eq("empty-result debrief logs UNKNOWN", "UNKNOWN", empty_debrief.get("action", ""))

	# --- 4. reveal_all() shows the buttons synchronously ----------------------
	var rb = _build_resolve("WIN")
	_c.eq("buttons hidden before reveal", 0.0, rb._button_row.modulate.a)
	rb.reveal_all()
	_c.eq("reveal_all shows the buttons", 1.0, rb._button_row.modulate.a)
	_c.eq("reveal_all is marked revealed", true, rb._revealed)

	# The three exit buttons, the review button, and the intent signals.
	var btns: Array = []
	_button_texts(rb, btns)
	_c.eq("four buttons present incl. review", 4, btns.size())
	_c.ok("review button labelled", btns.has(tr("RESOLVE_REVIEW_BUTTON")))
	_c.ok("next-scenario button labelled", btns.has(tr("RESOLVE_NEXT")))
	_c.ok("home button labelled", btns.has(tr("RESOLVE_HOME")))
	_c.ok("retry button labelled", btns.has(tr("RESOLVE_RETRY")))
	_c.ok("next_requested signal present", rb.has_signal("next_requested"))
	_c.ok("home_requested signal present", rb.has_signal("home_requested"))
	_c.ok("replay_requested signal present", rb.has_signal("replay_requested"))

	# Review button opens the overlay as a child of Resolve (no flow change).
	var before: int = rb.get_child_count()
	rb._open_review()
	_c.ok("review overlay added on open", rb.get_child_count() > before)
	var overlay = rb.get_child(rb.get_child_count() - 1)
	# No history was handed in, so the overlay lists no turns.
	_c.eq("review overlay exposes a turn count", 0, overlay._turn_count)
	_c.ok("review overlay can close back", overlay.has_signal("close_requested"))
	rb.queue_free()

	# --- 5. A fresh run starts clean, without an explicit wipe ----------------
	# The handoff lives on a shell-owned RunState that dies with the scene, so a
	# replay is clean by construction. Guards against moving it back onto the
	# autoload, which would reintroduce the stale-state problem.
	var run = RunState.new()
	_c.eq("fresh run has no collected finds", 0, run.collected_find_ids.size())
	_c.eq("fresh run has no mail result", 0, run.mail_result.size())
	_c.eq("fresh run has the probe flag down", false, run.probe_done)
	var gs := root.get_node("GameState")
	_c.ok("GameState carries no phase handoff", not gs.has_method("set_mail_result")
		and not gs.has_method("set_collected_finds"))

	quit(_c.finish())
	return true
