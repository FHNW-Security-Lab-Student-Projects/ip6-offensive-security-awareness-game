# Scenario 1: spear phishing. The shell over four phases (Briefing -> Recon ->
# MailBuilder -> Resolve), each a Control child of the CanvasLayer, one visible
# at a time. It owns the routing and the run handoff; the phases own their
# screens and stay ignorant of what comes before or after them.
extends ScenarioBase

const SCENARIO_ID: String = "spear_phishing"
# Resolve's exits. The next scenario comes from the Config registry.
const NEXT_SCENARIO_ID: StringName = &"bad_usb"
const HOME_SCENE: String = "res://scenes/StartScreen.tscn"

const BriefingState := preload("res://scenarios/spear_phishing/states/briefing.gd")
# For TURN_BUDGET, which the briefing .tres mirrors in its display text.
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

# The phase handoff, created per scene load: a replay starts clean by
# construction, without anything having to be reset.
var _run := RunState.new()

func _setup() -> void:
	for state in _states.values():
		state.visible = false
		# Handed over before any phase becomes visible, because the phases build
		# themselves on visibility_changed rather than in _ready.
		if state.has_method("configure_run"):
			state.configure_run(_run)
		# Progression rides advance_requested, which Resolve does not emit; its
		# three exits are separate intents. Hence the guards.
		if state.has_signal("advance_requested"):
			state.advance_requested.connect(_advance)
		if state.has_signal("next_requested"):
			state.next_requested.connect(_next_scenario)
		if state.has_signal("home_requested"):
			state.home_requested.connect(_go_home)
		if state.has_signal("replay_requested"):
			state.replay_requested.connect(_replay)
	_setup_os_chrome()

# Mission facts from the BriefingResource, live phase and turns via GameState.
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
	# A replay drops straight into Recon. The one-shot hint is consumed here.
	if GameState.replay_skip_briefing:
		GameState.replay_skip_briefing = false
		_change_substate(SubState.RECON)
	else:
		_change_substate(SubState.BRIEFING)

func _on_complete() -> void:
	pass

# The routing lives here so the phases stay ignorant of what comes next.
func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			# Both of these change the screen, so they get a black beat instead of
			# a hard cut. Mail -> Resolve stays on the same screen.
			SceneTransition.flash(_change_substate.bind(SubState.RECON))
		SubState.RECON:
			SceneTransition.flash(_change_substate.bind(SubState.MAIL))
		SubState.MAIL:
			_change_substate(SubState.RESOLVE)

# --- Resolve exits -----------------------------------------------------------

# Closes this run, then loads the next scenario.
func _next_scenario() -> void:
	complete_scenario()
	var cfg: ScenarioConfig = Config.get_scenario(NEXT_SCENARIO_ID)
	if cfg == null:
		push_error("%s: next scenario '%s' missing from Config" % [SCENARIO_ID, NEXT_SCENARIO_ID])
		return
	SceneTransition.launch_scenario(cfg)

# Closes this run, then returns to the start screen.
func _go_home() -> void:
	complete_scenario()
	SceneTransition.change_scene(HOME_SCENE)

# Reloads the scenario, so every phase rebuilds from scratch and the handoff
# dies with the scene. reset_scenario only clears the HUD counters, which live
# on the autoload and would otherwise survive.
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
	# Drives the OSChrome stepper; the ids match the configure() steps.
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
