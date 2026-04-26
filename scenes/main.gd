# Phase 1 entry point. Loads the HelloWorld smoke-test scenario directly,
# bypassing the menu (Person B replaces this with the title-screen +
# scenario-select flow once that branch lands).
extends Node

const HELLOWORLD_ID: StringName = &"_helloworld"

func _ready() -> void:
	var cfg: ScenarioConfig = Config.get_scenario(HELLOWORLD_ID)
	if cfg == null:
		push_error("Main: scenario '%s' missing from Config registry" % HELLOWORLD_ID)
		return
	var packed: PackedScene = load(cfg.scene_path)
	if packed == null:
		push_error("Main: cannot load %s" % cfg.scene_path)
		return
	var scenario: ScenarioBase = packed.instantiate()
	add_child(scenario)
	scenario.start_scenario(String(cfg.id))
