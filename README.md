# Offensive Security Awareness Game

A 2D serious game in **Godot 4.6** for cybersecurity awareness training.
Two attacker scenarios (phishing solitaire, physical infiltration). Bachelor
thesis project, FHNW Security Lab.

## Setup

1. Install [Godot 4.6](https://godotengine.org/download) (standard, not Mono).
2. Clone this repo.
3. Open `project.godot` in Godot.
4. Press **F5** to run. The Phase 1 entry point is `scenes/main.tscn`,
   which auto-runs the `_helloworld` smoke-test scenario and then enters
   FEEDBACK state after 5 seconds.
5. Inspect logs at the path printed in the console — typically
   `%APPDATA%\Godot\app_userdata\Offensive Security Awareness Game\logs\session_*.jsonl`
   on Windows.

## Folder layout

```
autoloads/              5 singletons: EventBus, GameState, Telemetry, Config, FeedbackEngine
scenarios/              one folder per scenario, scripts + scenes co-located
  base/                 ScenarioBase (Template Method lifecycle)
  _helloworld/          engine smoke test
resources/scenarios/    typed ScenarioConfig .tres files (one per scenario)
scenes/                 top-level scenes (main.tscn entry point)
  ui/      Person B     title screen
  shared/  Person B     shared UI elements
assets/                 audio, fonts, sprites
tests/                  test framework TBD (Phase 2)
```

## Ownership

| Area | Owner |
|---|---|
| `autoloads/`, `scenarios/`, `resources/`, `tests/` | Person A (engine + scenarios) |
| `scenes/ui/`, `scenes/shared/` | Person B (title screen + scenario select) |
| `assets/`, `project.godot` (autoloads section) | Shared — coordinate before edits |

`project.godot`'s `[autoload]` section is shared territory: ping before
adding/removing/reordering an autoload.

## Branching

- `main` — protected, only merged work lands here.
- `feat/<topic>` — feature branches (e.g. `feat/engine-foundation`).

Conventional commit prefixes: `feat`, `fix`, `chore`, `refactor`, `docs`,
`test`, `perf`, `ci`.
