# Loads all ScenarioConfig .tres files at startup and exposes a
# read-only registry. Resources are duplicated on access so callers
# cannot mutate the cached copy.
extends Node

const SCENARIOS_DIR: String = "res://resources/scenarios"

var _scenarios: Dictionary = {}  # StringName -> ScenarioConfig

func _ready() -> void:
	_load_scenarios()

func get_scenario(id: StringName) -> ScenarioConfig:
	if not _scenarios.has(id):
		push_error("Config: no scenario with id '%s'" % id)
		return null
	return (_scenarios[id] as ScenarioConfig).duplicate(true)

func list_scenarios() -> Array:
	var out: Array = []
	for cfg in _scenarios.values():
		out.append((cfg as ScenarioConfig).duplicate(true))
	return out

func _load_scenarios() -> void:
	var dir: DirAccess = DirAccess.open(SCENARIOS_DIR)
	if dir == null:
		push_error("Config: cannot open %s" % SCENARIOS_DIR)
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var path: String = "%s/%s" % [SCENARIOS_DIR, name]
			var res: Resource = load(path)
			if res is ScenarioConfig:
				var cfg: ScenarioConfig = res
				_scenarios[cfg.id] = cfg
			else:
				push_warning("Config: %s is not a ScenarioConfig, skipping" % path)
		name = dir.get_next()
	dir.list_dir_end()
	print("Config: loaded %d scenario(s)" % _scenarios.size())
