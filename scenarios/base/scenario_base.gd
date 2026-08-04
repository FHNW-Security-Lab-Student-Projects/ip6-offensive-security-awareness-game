# Abstract base for all scenarios. Template Method pattern: the public
# methods (start_scenario, complete_scenario) own the lifecycle and emit
# telemetry; subclasses MUST override the protected hooks below to provide
# scenario-specific behaviour.
#
# Subclass contract:
#   MUST override: _on_start, _on_complete
#   MAY  override: _setup
# All three hooks default to push_error/no-op so missing overrides fail
# loudly during development instead of silently doing nothing.
#
# Player input is NOT routed through this class. Both scenarios wire their
# own signals (buttons, Area2D triggers, dialogue choices) and emit through
# EventBus at the interaction site — a single action_id string cannot carry
# what a hotspot click or a card play needs to report.
class_name ScenarioBase
extends Node2D

var scenario_id: String = ""
var _started_at_ms: int = 0

# ---- Public lifecycle (do NOT override) ----

func start_scenario(id: String) -> void:
	scenario_id = id
	_started_at_ms = Time.get_ticks_msec()
	# Menu music belongs to the menus only; silence it once gameplay begins.
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

# Optional one-time setup before _on_start. Default: no-op.
func _setup() -> void:
	pass

# Required: scenario start logic.
func _on_start() -> void:
	push_error("ScenarioBase._on_start must be overridden by %s" % scenario_id)

# Required: scenario end logic (cleanup, final emits).
func _on_complete() -> void:
	push_error("ScenarioBase._on_complete must be overridden by %s" % scenario_id)
