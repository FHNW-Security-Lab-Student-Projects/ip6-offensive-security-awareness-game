extends ScenarioBase

func _on_start() -> void:
	print("Szenario Bad USB gestartet.")
	# Hier zeigst du später den gefundenen USB-Stick auf dem Schreibtisch an

func _on_action(action_id: String) -> void:
	# action_id könnte z.B. "stick_eingesteckt" oder "stick_abgegeben" sein
	var correct: bool = (action_id == "stick_abgegeben")
	
	EventBus.emit_decision(scenario_id, action_id, correct, 0)
	
	# Egal ob richtig oder falsch, nach der Entscheidung ist das Level vorbei
	complete_scenario()

func _on_complete() -> void:
	pass
