# Base for all scenarios, Template Method: start_scenario and complete_scenario
# own the lifecycle and the telemetry, subclasses fill the hooks.
#   MUST override: _on_start, _on_complete   (default to push_error, so a
#                                             missing override fails loudly)
#   MAY  override: _setup                    (default no-op)
#
# Started by SceneTransition.launch_scenario, never by the scenario itself.
#
# Player input does NOT route through here: the scenarios wire their own signals
# and emit at the interaction site, because one action_id string cannot carry
# what a hotspot click or a card play reports.
class_name ScenarioBase
extends Node2D

var scenario_id: String = ""
var _started_at_ms: int = 0

# ---- Public lifecycle (do NOT override) ----

func start_scenario(id: String) -> void:
	scenario_id = id
	_started_at_ms = Time.get_ticks_msec()
	# Menu music belongs to the menus only.
	MusicPlayer.stop_menu_music()
	GameState.current_scenario_id = id
	GameState.transition_to(GameState.State.IN_SCENARIO)
	EventBus.generic_event.emit({
		"phase": "scenario_start",
		"scenario_id": id,
		"action": null,
		"is_correct": null,
		"latency_ms": 0,
		"payload": {},
	})
	_setup()
	_on_start()

func complete_scenario() -> void:
	_on_complete()
	var elapsed: int = Time.get_ticks_msec() - _started_at_ms
	EventBus.generic_event.emit({
		"phase": "scenario_complete",
		"scenario_id": scenario_id,
		"action": null,
		"is_correct": null,
		"latency_ms": elapsed,
		"payload": {},
	})
	GameState.transition_to(GameState.State.FEEDBACK)

# ---- Protected hooks (override in subclasses) ----

func _setup() -> void:
	pass

func _on_start() -> void:
	push_error("ScenarioBase._on_start must be overridden by %s" % scenario_id)

func _on_complete() -> void:
	push_error("ScenarioBase._on_complete must be overridden by %s" % scenario_id)
