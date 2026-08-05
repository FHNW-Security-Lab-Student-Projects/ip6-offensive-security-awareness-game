# Scenario 1: Phishing (Phase 1 sub-state shell).
#
# Owns four sub-states (Briefing -> Recon -> MailBuilder -> Resolve) and
# the advance wiring between them. Each sub-state scene is a Control
# child of CanvasLayer; only one is visible at a time. The real UI for
# each sub-state arrives in later phases — this file is the plumbing.
extends ScenarioBase

const SCENARIO_ID: String = "spear_phishing"
# Resolve's exit routing (shell owns "what comes next"). The next scenario is
# resolved through the Config registry; home is the start screen.
const NEXT_SCENARIO_ID: StringName = &"bad_usb"
const HOME_SCENE: String = "res://scenes/StartScreen.tscn"

# Single source for the briefing resource path (defined by the briefing state).
const BriefingState := preload("res://scenarios/spear_phishing/states/briefing.gd")
# The mail turn budget is a MailBuilder balancing knob (Pool.TURN_BUDGET); the
# briefing .tres mirrors the number for its display text.
const MailPool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")
const RunState := preload("res://scenarios/spear_phishing/data/run_state.gd")

enum SubState { BRIEFING, RECON, MAIL, RESOLVE }

@onready var _states: Dictionary = {
	SubState.BRIEFING: $CanvasLayer/Briefing,
	SubState.RECON:    $CanvasLayer/Recon,
	SubState.MAIL:     $CanvasLayer/MailBuilder,
	SubState.RESOLVE:  $CanvasLayer/Resolve,
}

@onready var _os_chrome: OSChrome = $CanvasLayer/OSChrome

var _current: SubState = SubState.BRIEFING
var _initialised: bool = false

# The run's phase handoff. Owned here and created per scene load, so a replay
# starts clean without wiping anything.
var _run := RunState.new()

func _setup() -> void:
	for state in _states.values():
		state.visible = false
		# Handed over before any phase becomes visible; the sub-states build
		# themselves on visibility_changed, not in _ready.
		if state.has_method("configure_run"):
			state.configure_run(_run)
		# Phase progression (Briefing/Recon/Mail) rides advance_requested; Resolve
		# does not emit it, so guard the connect. Resolve's three exits are its
		# own intents, each connected where present.
		if state.has_signal("advance_requested"):
			state.advance_requested.connect(_advance)
		if state.has_signal("next_requested"):
			state.next_requested.connect(_next_scenario)
		if state.has_signal("home_requested"):
			state.home_requested.connect(_go_home)
		if state.has_signal("replay_requested"):
			state.replay_requested.connect(_replay)
	_setup_os_chrome()

# Feeds the persistent OS shell: mission facts from the BriefingResource,
# live phase / turn budget via GameState. Presentation wiring only.
func _setup_os_chrome() -> void:
	var briefing := load(BriefingState.BRIEFING_PATH) as BriefingResource
	if briefing == null:
		push_error("%s: failed to load %s" % [SCENARIO_ID, BriefingState.BRIEFING_PATH])
		return
	GameState.begin_mission(MailPool.TURN_BUDGET)
	var steps: Array[Dictionary] = [
		{"id": &"RECON", "label": tr("SPEAR_PHASE_RECON")},
		{"id": &"MAIL", "label": tr("SPEAR_PHASE_MAIL")},
		{"id": &"RESOLVE", "label": tr("SPEAR_PHASE_RESOLVE")},
	]
	_os_chrome.configure(briefing, steps)

func _on_start() -> void:
	# A replay skips the intro and drops straight into Recon; a normal launch
	# opens on the briefing. The one-shot hint is consumed here.
	if GameState.replay_skip_briefing:
		GameState.replay_skip_briefing = false
		_change_substate(SubState.RECON)
	else:
		_change_substate(SubState.BRIEFING)

func _on_complete() -> void:
	pass

# Sub-states emit advance_requested when the player wants to move on.
# Routing lives here so sub-states stay ignorant of what comes next.
func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			# Intro -> gameplay: a black fade acts as a "loading" beat.
			SceneTransition.flash(_change_substate.bind(SubState.RECON))
		SubState.RECON:
			# Recon -> Mail is a change of screen like the intro, so it gets the
			# same black beat instead of a hard cut.
			SceneTransition.flash(_change_substate.bind(SubState.MAIL))
		SubState.MAIL:
			_change_substate(SubState.RESOLVE)

# --- Resolve exits: three routes, all owned by the shell ---------------------

# "Next Scenario": close this run (telemetry + FEEDBACK state), then load the
# next scenario from the Config registry.
func _next_scenario() -> void:
	complete_scenario()
	var cfg: ScenarioConfig = Config.get_scenario(NEXT_SCENARIO_ID)
	if cfg == null:
		push_error("%s: next scenario '%s' missing from Config" % [SCENARIO_ID, NEXT_SCENARIO_ID])
		return
	SceneTransition.launch_scenario(cfg)

# "Back to Home": close this run, then return to the start screen.
func _go_home() -> void:
	complete_scenario()
	SceneTransition.change_scene(HOME_SCENE)

# "Retry": reload this scenario from the Config registry so every sub-state
# rebuilds from scratch. The phase handoff dies with the scene; reset_scenario
# only clears the mission HUD counters, which live on the autoload. The intro
# briefing is skipped on a retry — straight into Recon.
func _replay() -> void:
	GameState.reset_scenario()
	GameState.replay_skip_briefing = true
	var cfg: ScenarioConfig = Config.get_scenario(StringName(SCENARIO_ID))
	if cfg == null:
		push_error("%s: cannot replay, scenario missing from Config" % SCENARIO_ID)
		return
	SceneTransition.launch_scenario(cfg)

func _change_substate(new_state: SubState) -> void:
	var from_name: String = (
		SubState.keys()[_current] if _initialised else "INIT"
	)
	if _initialised and _states.has(_current):
		_states[_current].visible = false
	_states[new_state].visible = true
	_current = new_state
	_initialised = true
	# Drive the OSChrome phase stepper; ids match the configure() steps.
	GameState.set_mission_phase(StringName(SubState.keys()[new_state]))
	EventBus.generic_event.emit({
		"phase": "substate_change",
		"scenario_id": scenario_id,
		"action": null,
		"is_correct": null,
		"latency_ms": null,
		"payload": {
			"from": from_name,
			"to": SubState.keys()[new_state],
		},
	})
