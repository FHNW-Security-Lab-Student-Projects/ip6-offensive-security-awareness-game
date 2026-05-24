# Typed data for Scenario 1's boss briefing. One .tres per scenario
# under resources/scenarios/<scenario>/. Edit copy in the Godot
# inspector; no code changes needed.
class_name BriefingResource
extends Resource

@export var speaker_name: String = ""
@export var intro_lines: PackedStringArray = PackedStringArray()
@export_multiline var mission_text: String = ""
@export_multiline var reward_text: String = ""
@export var turn_budget: int = 8
