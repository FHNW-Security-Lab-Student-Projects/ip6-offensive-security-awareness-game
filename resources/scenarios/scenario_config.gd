# One .tres per scenario, top level of res://resources/scenarios/, picked up by
# the Config autoload at startup. Only id and scene_path are read by the game.
class_name ScenarioConfig
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene_path: String = ""
@export_multiline var description: String = ""
@export var tags: PackedStringArray = PackedStringArray()
