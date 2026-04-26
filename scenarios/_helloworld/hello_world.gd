# Engine smoke test. Auto-emits a few events and ends after 5 seconds
# so we can verify the full pipeline (EventBus -> Telemetry JSONL,
# state transitions, ScenarioBase lifecycle) without any UI input.
extends ScenarioBase

const AUTO_END_SECONDS: float = 5.0

@onready var _label: Label = $Label

func _on_start() -> void:
	_label.text = "Hello World — auto-ending in %ds" % int(AUTO_END_SECONDS)
	# Fire a couple of demo decisions so the JSONL has something to chew on.
	EventBus.emit_decision(scenario_id, "demo_correct", true, 0)
	EventBus.emit_decision(scenario_id, "demo_incorrect", false, 123)
	get_tree().create_timer(AUTO_END_SECONDS).timeout.connect(complete_scenario)

func _on_action(action_id: String) -> void:
	# HelloWorld has no real interactions; just log whatever arrives.
	EventBus.emit_decision(scenario_id, action_id, true, 0)

func _on_complete() -> void:
	_label.text = "Hello World — done"
