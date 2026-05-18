extends ScenarioBase

func _on_start() -> void:
	# Wird automatisch aufgerufen, wenn das Level über das Menü gestartet wird
	print("Szenario Spear-Phishing gestartet.")
	# Hier baust du später das Fake-E-Mail-Postfach auf und aktivierst die Buttons

func _on_action(action_id: String) -> void:
	# Diese Funktion rufst du auf, wenn der Spieler im Level eine Entscheidung trifft
	# action_id könnte z.B. "link_geklickt" oder "mail_gemeldet" sein
	
	var correct: bool = (action_id == "mail_gemeldet")
	
	# Sendet die Daten automatisch in euer Tracking-Log (jsonl)
	EventBus.emit_decision(scenario_id, action_id, correct, 0) 
	
	if correct:
		print("Korrekt gehandelt! Phishing gemeldet.")
	else:
		print("Falsch gehandelt! Auf Link geklickt.")
		
	# Beendet das Szenario und leitet den Spieler in den Feedback-Screen weiter
	complete_scenario()

func _on_complete() -> void:
	# Aufräumen, bevor das Feedback geladen wird
	print("Spear-Phishing wird aufgeräumt...")
