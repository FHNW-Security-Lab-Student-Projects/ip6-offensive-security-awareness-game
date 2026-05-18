# Scene 1 scenario.
#
# Override the protected hooks from ScenarioBase to implement scenario
# logic. See scenarios/base/scenario_base.gd for the contract.
#
# Public API used by callers (do NOT override):
#   start_scenario(id)   - call once after instantiating
#   submit_action(id)    - call on every player decision; routes to _on_action
#   complete_scenario()  - call when scenario is finished
extends ScenarioBase


func _setup() -> void:
	# Optional: one-time setup before _on_start (wire UI signals, prefetch
	# resources). Default is no-op, override only if needed.
	pass


func _on_start() -> void:
	# TODO: build the scenario UI, present the prompt, arm interactive
	# elements. This runs once at scenario start.
	pass


func _on_action(action_id: String) -> void:
	# TODO: evaluate the player's decision and emit a telemetry event.
	# action_id is whatever string you choose when calling submit_action().
	var correct: bool = false
	EventBus.emit_decision(scenario_id, action_id, correct, 0)
	if correct:
		complete_scenario()


func _on_complete() -> void:
	# TODO: cleanup and final UI updates before transitioning to feedback.
	pass
