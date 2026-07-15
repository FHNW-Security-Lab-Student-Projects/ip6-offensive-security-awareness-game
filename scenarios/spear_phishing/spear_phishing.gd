# Scenario 1: Phishing (Phase 1 sub-state shell).
#
# Owns four sub-states (Briefing -> Recon -> MailBuilder -> Resolve) and
# the advance wiring between them. Each sub-state scene is a Control
# child of CanvasLayer; only one is visible at a time. The real UI for
# each sub-state arrives in later phases — this file is the plumbing.
extends ScenarioBase

const SCENARIO_ID: String = "spear_phishing"

# Single source for the briefing resource path (defined by the briefing state).
const BriefingState := preload("res://scenarios/spear_phishing/states/briefing.gd")
# The mail turn budget is a MailBuilder balancing knob (Pool.TURN_BUDGET); the
# briefing .tres mirrors the number for its display text.
const MailPool := preload("res://scenarios/spear_phishing/data/mail_card_pool.gd")

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

# LevelAuswahl change_scene_to_file()s into this scene without calling
# start_scenario, so we bootstrap here. Promote to ScenarioBase if/when
# other scenarios need the same treatment.
func _ready() -> void:
	start_scenario(SCENARIO_ID)

func _setup() -> void:
	for state in _states.values():
		state.visible = false
		state.advance_requested.connect(_advance)
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
	_change_substate(SubState.BRIEFING)

func _on_action(_action_id: String) -> void:
	pass

func _on_complete() -> void:
	pass

# Sub-states emit advance_requested when the player wants to move on.
# Routing lives here so sub-states stay ignorant of what comes next.
func _advance() -> void:
	match _current:
		SubState.BRIEFING:
			_change_substate(SubState.RECON)
		SubState.RECON:
			_change_substate(SubState.MAIL)
		SubState.MAIL:
			_change_substate(SubState.RESOLVE)
		SubState.RESOLVE:
			complete_scenario()

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
