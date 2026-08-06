# Offensive Security Awareness Game

A 2D serious game in **Godot 4.7** for cybersecurity awareness training.
Two attacker scenarios (phishing solitaire, physical infiltration). Bachelor
thesis project, FHNW Security Lab.

## Setup

1. Install [Godot 4.7](https://godotengine.org/download) (standard, not Mono).
2. Clone this repo.
3. Open `project.godot` in Godot.
4. Press **F5** to run. The entry point is `scenes/StartScreen.tscn`
   (title screen → level select → scenarios).
5. Inspect logs at the path printed in the console — typically
   `%APPDATA%\Godot\app_userdata\Offensive Security Awareness Game\logs\session_*.jsonl`
   on Windows.

## Running a study session

Every run writes one append-only JSONL file with the player's decisions,
errors and decision times.

Before handing the machine to a participant, type their code into the
**Teilnehmer-Code** field in the corner of the title screen. It is stamped onto
every event and is what joins the game data to the pre/post questionnaires, so
the same code has to go into both forms. The field is optional, so internal test
runs can leave it blank.

After a session:

1. Copy the `logs/` folder off the machine (path is printed at startup).
2. Turn the logs into tables:

   ```
   python tools/analyze.py <log-folder> -o analysis
   ```

   On macOS/Linux the command is `python3`; on Windows only `python` resolves
   (`python3` hits the Microsoft Store stub and does nothing).

   This writes `analysis/events.csv` (full trace, one row per event) and
   `analysis/summary.csv` (one row per session: error rate, decision times,
   per-scenario outcomes) and prints a per-run overview so an empty or
   aborted session is spotted immediately.

3. If a session was played without a code, the run warns about it. Fill those
   in afterwards with a `participants.csv` (`session_uuid,participant_code`)
   and pass it with `-p`. Sessions sort chronologically by uuid, which makes
   that reconstruction straightforward.

Every event carries the same flat set of fields: `phase`, `scenario_id`,
`action`, `is_correct`, `latency_ms`, `payload`, plus `seq`, `timestamp_ms`,
`session_uuid` and `participant_code` stamped by `Telemetry`. Only events with
`is_correct` set to a real bool count towards the error rate; `EventBus.emit_action`
forces it to `null` for interactions that have no right answer.

## Folder layout

```
autoloads/              singletons: EventBus, GameState, Telemetry, Config, I18n,
                        SceneTransition, MusicPlayer, SfxPlayer, Settings, SettingsMenu
scenarios/              one folder per scenario, scripts + scenes co-located
  base/                 ScenarioBase (Template Method lifecycle)
  spear_phishing/       scenario 1: recon → mail builder → resolve
  bad_usb/              scenario 2: on-site infiltration
resources/scenarios/    typed ScenarioConfig .tres files (one per scenario)
scenes/                 menu scenes (StartScreen, LevelAuswahl, settings)
assets/                 audio, fonts, sprites
tests/                  headless tests, one file per area
  fixtures/             a recorded session log used by tools/test_analyze.py
```

## Tests

Plain headless scripts, no framework. Each file runs on its own:

```
godot --headless --path . -s tests/test_mail_builder.gd
python tools/test_analyze.py
```

Every check prints `ok` or `FAIL` with the expected value next to the actual
one. A file ends with `TEST DONE (n checks passed)` and exit code 0, or with
`n CHECK(S) FAILED` and exit code 1 — so a failure is visible in the exit code
and does not depend on anyone reading the output.

`tests/check.gd` holds the comparison helper; `tools/test_analyze.py` uses the
same convention on the Python side.

Note that a test run writes a real session log into the same `logs/` folder as
a study session. Clear it before handing the machine to a participant.

## Adding a scenario

Three new files: a `.gd` extending `ScenarioBase`, a `.tscn` with a Node2D
root, and a `.tres` config under `resources/scenarios/` that `Config` picks up
on its startup scan. Override `_on_start` and `_on_complete`, optionally
`_setup`. The scenario is started by `SceneTransition.launch_scenario(cfg)`;
it must not start itself. To reach it from the menu, add a button in
`scenes/LevelAuswahl.tscn` and a handler in `scenes/levelAuswahl.gd`.

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
