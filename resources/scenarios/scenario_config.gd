# Typed configuration for a scenario, stored as a .tres resource.
# One file per scenario under res://resources/scenarios/.
# Loaded at startup by the Config autoload.
class_name ScenarioConfig
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene_path: String = ""
@export_multiline var description: String = ""
@export var tags: PackedStringArray = PackedStringArray()
