# Event Schema

This file is the **contract** between the engine (EventBus, Telemetry)
and scenarios. Any field listed under "canonical" MUST be present on
every event emitted via `EventBus.generic_event`. Telemetry stamps
`timestamp_ms` and `session_uuid` automatically — scenarios should NOT
set them.

Consumers (Telemetry, FeedbackEngine, post-hoc analysis scripts) MUST
tolerate unknown keys on `payload` for forward compatibility.

## Canonical fields

| field           | type            | required | notes                                                                  |
|-----------------|-----------------|----------|------------------------------------------------------------------------|
| `timestamp_ms`  | float (ms)      | yes      | Stamped by Telemetry. Unix epoch milliseconds.                         |
| `session_uuid`  | string          | yes      | Stamped by Telemetry. Format `YYYYMMDD_HHMMSS_xxxx` (see ADR-0002).    |
| `phase`         | string enum     | yes      | One of: `state_change`, `scenario_start`, `substate_change`, `action`, `scenario_complete`. |
| `scenario_id`   | string          | yes      | Empty string for pre-scenario `state_change`.                          |
| `action`        | string \| null  | yes      | Action id for `action` phase, `null` for others.                       |
| `is_correct`    | bool \| null    | yes      | Decision correctness for graded `action` events; `null` for plain event-style actions and for all non-action phases. |
| `latency_ms`    | int \| null     | yes      | Time-to-decision for `action`; total elapsed for `scenario_complete`.  |
| `payload`       | object          | yes      | Free-form scenario-specific extras. May be `{}` but must exist.        |

## Phases

- **`state_change`** — emitted by `GameState.transition_to`.
  `payload = {from: <state-name>, to: <state-name>}`.
- **`scenario_start`** — emitted by `ScenarioBase.start_scenario`.
  Marks IN_SCENARIO state.
- **`substate_change`** — emitted by a scenario when it swaps internal
  phases (e.g., Briefing → Recon). `payload = {from: <name>, to: <name>}`
  using scenario-defined sub-state identifiers. `action`, `is_correct`,
  `latency_ms` are `null`.
- **`action`** — emitted by `EventBus.emit_decision` for graded
  decisions, or directly by a scenario for plain event-style actions
  (e.g., `briefing_advanced`). `action` and `latency_ms` MUST be set.
  `is_correct` is `bool` for graded decisions, `null` for event-style
  actions. `payload` carries action-specific extras (e.g.,
  `{lines_shown: 4}` for `briefing_advanced`).
- **`scenario_complete`** — emitted by `ScenarioBase.complete_scenario`.
  `latency_ms` is total elapsed time since start.

## Example (one JSONL file)

```json
{"phase":"state_change","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":null,"payload":{"from":"MENU","to":"IN_SCENARIO"},"timestamp_ms":1745672313050.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"scenario_start","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":0,"payload":{},"timestamp_ms":1745672313060.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"action","scenario_id":"_helloworld","action":"demo_correct","is_correct":true,"latency_ms":0,"payload":{},"timestamp_ms":1745672313070.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"scenario_complete","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":5012,"payload":{},"timestamp_ms":1745672318072.0,"session_uuid":"20260426_141833_a3f1"}
```

## Adding a new event type

1. Pick a phase name (kebab-case, all lowercase).
2. Decide which canonical fields are non-null; others stay `null`.
3. Document the phase here in this file in the same PR that emits it.
4. Update `FeedbackEngine` if the new phase needs to participate in
   evaluation.

Schema breaking changes (renaming a canonical field, narrowing a type)
require a new ADR and a migration plan for existing JSONL files.
