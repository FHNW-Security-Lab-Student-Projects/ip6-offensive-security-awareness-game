# Scene 2 scenario. See scenarios/scene1/scene1.gd for the same template
# with detailed comments.
extends ScenarioBase


func _setup() -> void:
	pass


func _on_start() -> void:
	# TODO: build scenario UI and present the prompt.
	pass


func _on_action(action_id: String) -> void:
	var correct: bool = false
	EventBus.emit_decision(scenario_id, action_id, correct, 0)
	if correct:
		complete_scenario()


func _on_complete() -> void:
	pass
