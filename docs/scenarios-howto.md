# Building a Scenario

Every playable scenario plugs into the engine the same way. This is the
contract; follow it and the scenario will run, log telemetry, and route
the player back to feedback automatically.

## The three pieces

A scenario consists of three files:

```
scenarios/<id>/<id>.gd      # script extending ScenarioBase
scenarios/<id>/<id>.tscn    # Node2D scene with the script attached
resources/scenarios/<id>.tres   # ScenarioConfig metadata
```

`<id>` is a short snake_case identifier (`scene1`, `phishing_inbox`, …).
It must match the `id` field inside the `.tres`. `Config` discovers
scenarios by scanning `resources/scenarios/` at startup — no
registration code needed.

## The script: override three hooks

`ScenarioBase` (in `scenarios/base/scenario_base.gd`) is the Template
Method base. It owns the lifecycle and the telemetry emits; you fill in
the gaps.

```gdscript
extends ScenarioBase

func _on_start() -> void:
	# Build the scenario UI, present the prompt, arm interactive elements.
	pass

func _on_action(action_id: String) -> void:
	# Called by submit_action(). Evaluate the decision, emit telemetry,
	# call complete_scenario() when the scenario is over.
	var correct: bool = (action_id == "good_choice")
	EventBus.emit_decision(scenario_id, action_id, correct, 0)
	if correct:
		complete_scenario()

func _on_complete() -> void:
	# Cleanup before the engine transitions to FEEDBACK state.
	pass
```

`_setup()` is an optional fourth hook that runs once before `_on_start()`
— use it for wiring signals or prefetching resources.

**Do not override** `start_scenario`, `submit_action`, or
`complete_scenario`. Those are public lifecycle methods; the menu and
the engine call them, and they handle GameState transitions and
scenario_start / scenario_complete telemetry for you.

## The scene: Node2D root

`ScenarioBase extends Node2D`, so the scene's root must be a Node2D with
the script attached. If you need UI, add a `CanvasLayer` or `Control` as
a child — not as the root.

## The config: one `.tres` per scenario

```
[gd_resource type="Resource" script_class="ScenarioConfig" load_steps=2 format=3]

[ext_resource type="Script" uid="uid://cc7nr2ywmkeaj" path="res://resources/scenarios/scenario_config.gd" id="1_cfg"]

[resource]
script = ExtResource("1_cfg")
id = &"scene1"
display_name = "Scene 1"
scene_path = "res://scenarios/scene1/scene1.tscn"
description = "What the player has to do here."
tags = PackedStringArray()
```

Edit in the Godot inspector if you prefer — the file is auto-generated
from the `ScenarioConfig` schema (see
`resources/scenarios/scenario_config.gd`).

## Wiring the scenario into the menu

Already handled. `LevelAuswahl` calls `Config.get_scenario(&"<id>")` and
loads the resulting `scene_path`. Adding a new scenario id to the menu
only requires extending `scenes/levelAuswahl.gd` (or adding a button
that calls the same `_launch_scenario(&"<id>")` helper).

## What you get for free

- Telemetry: `scenario_start`, `scenario_complete`, and every
  `EventBus.emit_decision()` call land in
  `user://logs/session_*.jsonl` automatically.
- State machine: `GameState` flips to `IN_SCENARIO` on start and
  `FEEDBACK` on complete; other code can subscribe to
  `GameState.state_changed`.
- Latency: `complete_scenario()` records elapsed ms from
  `start_scenario()` and emits it in the payload.

## Conventions

- One scenario per folder under `scenarios/`.
- `class_name` only when another file needs to reference the type —
  most scenarios don't need it.
- Snake_case file names. The folder name, file names, and `id` should
  all match.
- Keep scenario scripts focused on scenario logic; shared helpers go in
  `autoloads/` or a dedicated module.
