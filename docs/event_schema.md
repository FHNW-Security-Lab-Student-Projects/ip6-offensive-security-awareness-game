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
| `seq`           | int             | yes      | Stamped by Telemetry, starts at 1 per session. `timestamp_ms` only has millisecond resolution, so events emitted in the same frame tie; `seq` gives the analysis a total order. |
| `timestamp_ms`  | float (ms)      | yes      | Stamped by Telemetry. Unix epoch milliseconds.                         |
| `session_uuid`  | string          | yes      | Stamped by Telemetry. Format `YYYYMMDD_HHMMSS_xxxx` (see ADR-0002).    |
| `participant_code` | string       | yes      | Stamped by Telemetry. The study pseudonym entered on the title screen; empty string when nobody filled it in. Free text, trimmed and capped at 32 characters. |
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
- **`scenario_debrief`** — one row per finished run, emitted at the debrief
  screen (`resolve.gd` for spear_phishing, `_on_complete` for bad_usb).
  `action` and `payload.outcome` carry the outcome name. A session with more
  than one debrief for the same `scenario_id` means the player replayed it.
- **MailBuilder phases** — the MailRun engine emits its own phases:
  `mail_card_played`, `mail_sent`, `mail_pass`, `mail_payload_attempt`,
  `mail_outcome`, `hannes_state`. Documented here so the analysis knows they
  are not `action`-phase events.

## Grading: which events count towards the error rate

The study reports an error rate ("Fehlerquote"), so it matters exactly which
events carry a verdict.

- **Graded decisions** (`is_correct` is a bool): a single choice that is
  genuinely right or wrong. Emitted via `EventBus.emit_decision`, plus the
  engine phases `mail_card_played` and `mail_payload_attempt`. These, and only
  these, form the error-rate denominator.
- **Ungraded interactions** (`is_correct` is `null`): navigation, opening a
  page, advancing a debrief, reconsidering a pick. Emitted via
  `EventBus.emit_action`. Recorded for the behavioural trace, never scored.
- **Outcome rows** (`scenario_debrief`, `mail_outcome`): graded, but they
  summarise a whole run. `tools/analyze.py` deliberately excludes them from the
  error rate so a run's outcome is not counted on top of the decisions that
  produced it.

What counts as an error per scenario:

| Scenario | Graded as wrong |
|---|---|
| Recon | Collecting an `is_junk` find. It looks like a lead, carries nothing usable and costs one of the seven deck slots. Noise is not collectable and never graded. |
| MailBuilder | Playing a `SCHROTT` card (the post-run review calls it a mistake too), and a payload fired against bars that cannot win. |
| bad_usb | The dialogue answer that blows the cover, and taking the badge-protected elevator dead end. |

## Did the feedback get read?

Research question 3 asks how the closing feedback has to be built, so both
scenarios record whether it was actually looked at:

| Action | Meaning | `latency_ms` |
|---|---|---|
| `debrief_advanced` (bad_usb) | one stage of the closing screen was read | how long the finished stage stood |
| `resolve_left` (spear_phishing) | the debrief was left | how long the finished debrief stood |
| `review_opened` (spear_phishing) | the optional turn-by-turn review was opened | delay before opening it |
| `review_closed` (spear_phishing) | that review was closed again | time spent inside it |
| `resolve_reveal_skipped` | the staged reveal was clicked through | none |

`resolve_left.payload.review_opened` says whether the review was seen at all, so
a single row answers "did this participant look at the detailed feedback".

## Abandoned runs

Both scenarios emit `scenario_debrief` when their closing screen **appears**,
not when the player leaves it. A `scenario_start` without a matching
`scenario_debrief` therefore means the participant quit mid-scenario.

`tools/analyze.py` surfaces this as `runs_started`, `runs_finished` and
`runs_aborted`. Without those columns an abandoned run is indistinguishable from
a scenario that was never launched, which makes it impossible to exclude
participants on a stated rule.

## Decision times

`latency_ms` on a graded decision is the time from the choice becoming
actionable on screen to the player committing, measured by
`scenarios/base/prompt_clock.gd`. It is deliberately not measured from scene
entry: the interesting number is deliberation, not how long someone walked
around first.

`-1` means no clock was running for that event (`PromptClock.UNKNOWN`). It is a
sentinel, not a fast answer, and the analysis drops it. A few actions carry a
duration rather than a deliberation (`recon_completed` is a whole phase,
`debrief_advanced` is a reading time); `tools/analyze.py` keeps them in
`events.csv` but excludes them from the decision-time statistics.

## Example (one JSONL file)

```json
{"phase":"state_change","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":null,"payload":{"from":"MENU","to":"IN_SCENARIO"},"seq":1,"timestamp_ms":1745672313050.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"scenario_start","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":0,"payload":{},"seq":2,"timestamp_ms":1745672313060.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"action","scenario_id":"_helloworld","action":"demo_correct","is_correct":true,"latency_ms":0,"payload":{},"seq":3,"timestamp_ms":1745672313070.0,"session_uuid":"20260426_141833_a3f1"}
{"phase":"scenario_complete","scenario_id":"_helloworld","action":null,"is_correct":null,"latency_ms":5012,"payload":{},"seq":4,"timestamp_ms":1745672318072.0,"session_uuid":"20260426_141833_a3f1"}
```

## Reading the logs

`tools/analyze.py` turns a folder of session files into two tables:

```
python3 tools/analyze.py <log-folder> -o analysis [-p participants.csv]
```

- `analysis/events.csv` — one row per event, the full trace.
- `analysis/summary.csv` — one row per session: error rate, decision times,
  per-scenario outcomes. This is the table for the statistics.

## Identifying a participant

The pre/post questionnaires live outside the game, so the datasets are joined on
a pseudonym the study team assigns. The code exists before the game runs (the
pre-survey comes first), so it is entered, not generated:

1. The participant gets a code and enters it in the pre-survey form.
2. The code is typed into the field on the title screen. `Telemetry` stamps it
   onto every event from then on.
3. The same code goes into the post-survey form.

The field is optional so ordinary play and internal test runs are unaffected.
When a session was played without one, `tools/analyze.py` falls back to an
optional `participants.csv`:

```
session_uuid,participant_code
20260727_141833_a3f1,P07
```

The stamped code always wins over that file, because it cannot drift out of sync
with the session it belongs to. Sessions that end up with no code at all are
listed as a warning at the end of the run, and a session carrying more than one
code (the field was edited after events had been logged) is reported too.

The code is not persisted between launches. A value left over from the previous
participant would silently mislabel a whole session, which is worse than an
empty field the analysis can flag.

## Replays

A replay does **not** start a new session. `_replay()` resets the run state and
reloads the scene, but the autoloads survive a scene change, so `session_uuid`,
the log file and the `seq` counter all continue. The file simply gains a second
`scenario_start` … `scenario_debrief` block for the same `scenario_id`, with
every decision and every played card recorded again. The same is true if the
player returns to the scenario selection and launches it once more.

Only quitting and relaunching the game produces a new `session_uuid` and a new
file.

`tools/analyze.py` reconstructs the runs by counting `scenario_start` per
scenario and writes an `attempt` column on every row of `events.csv`, so a card
play can always be traced to the run it belongs to.

In `summary.csv` the split matters for the statistics:

| Columns | Cover |
|---|---|
| `error_rate`, `decisions_*`, `decision_ms_*`, `sp_*`, `usb_*` | the **first** attempt of each scenario |
| `error_rate_all`, `decisions_*_all`, `decision_ms_median_all` | every attempt, replays included |
| `sp_outcomes_all`, `usb_outcomes_all` | one outcome per attempt, in order (`SPAM;WIN`) |
| `sp_cards_played_all` | cards per attempt, runs separated by `\|` |

The first attempt is the default because it is the uncontaminated learning
measure: a participant replaying a scenario already knows the answers, and
averaging that into their first run would make replayers look better than
players who went through once.

Not to be confused with a retry *inside* a run: a blown cover in `bad_usb` sends
the player back to the entrance without ending the scenario. That stays one
attempt and is counted by the `retry_after_failure` action instead.

## Adding a new event type

1. Pick a phase name (kebab-case, all lowercase).
2. Decide which canonical fields are non-null; others stay `null`.
3. Document the phase here in this file in the same PR that emits it.
4. Update `FeedbackEngine` if the new phase needs to participate in
   evaluation.

Schema breaking changes (renaming a canonical field, narrowing a type)
require a new ADR and a migration plan for existing JSONL files.
