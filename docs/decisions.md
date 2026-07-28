# Architecture Decisions

Each entry is a short record of a load-bearing decision: what we picked,
why, and what we accept as a consequence. Append new ADRs at the bottom.

---

## ADR-0001: Engine foundation — autoloads, .tres, .jsonl, no backend

**Status:** Accepted (Phase 1, 2026-04-26)
**Context:** Bachelor thesis serious game in Godot 4.6 for cybersecurity
awareness training. Two attacker scenarios (phishing, physical infiltration),
~30 study participants, lab/classroom deployment, no central server.
Two-person team — engine and scenarios must stay loosely coupled so we can
work in parallel.

### Decision 1 — Autoloads as the cross-cutting service spine
Five Node-based singletons registered as Godot autoloads:
`EventBus`, `GameState`, `Telemetry`, `Config`, `FeedbackEngine`.

**Why:** Autoloads are Godot-idiomatic, zero dependencies, available from
every scene without import boilerplate. They give us global signals, a
session-state machine, telemetry, and config without inventing a service
locator or DI container. Load order in `project.godot` is explicit so
initialization sequencing is easy to reason about.

**Consequence:** Singletons are global state — we accept that and mitigate
by making each one own a single concern, exposing read-only views where
possible (`Config.get_scenario` returns duplicates), and routing all
cross-singleton communication through `EventBus` signals rather than
direct method calls.

### Decision 2 — Scenario data as `.tres` Resource files
Scenario configuration (`id`, `display_name`, `scene_path`, `description`,
`tags`) lives in `res://resources/scenarios/*.tres` typed as `ScenarioConfig`.

**Why:** `.tres` resources are editor-friendly (designers can edit in the
inspector without writing GDScript), type-safe via a `class_name Resource`,
loaded by the engine's normal import pipeline, and trivially version-
controllable as plain text. Adding a new scenario is "drop a `.tres` in
the folder" — no code change in `Config`.

**Consequence:** We need to keep `ScenarioConfig` schema stable; breaking
field changes require migrating every existing `.tres`. Mitigation:
small fixed schema, `@export` discipline, additive evolution.

### Decision 3 — Telemetry as append-only JSONL
One file per session at `user://logs/session_{uuid}.jsonl`, one JSON
object per line, never rewritten.

**Why:** Append-only is crash-safe (a partial write loses one line, not
the file). JSONL is trivially loadable into pandas / DuckDB / `jq` for
post-hoc analysis. Each line is self-describing (carries `session_uuid`
and `timestamp_ms`), so files can be concatenated across participants
without losing provenance. No schema migration tooling needed.

**Consequence:** Larger on-disk footprint than a binary log, and
schema-validation is the consumer's job. Acceptable at our scale
(~30 participants, two short scenarios per session).

### Decision 4 — No backend, local persistence only
All session data stays under `user://`. No HTTP, no cloud, no auth.
Researchers collect logs out-of-band (USB stick, shared network folder)
after sessions.

**Why:** Privacy by construction (data never leaves the participant's
machine until the researcher copies it), no infrastructure to maintain,
no GDPR/network hassle for a thesis project, runs offline in a classroom.
Pre/post surveys live outside the game in Google Forms.

**Consequence:** No real-time dashboard, no cross-device sync. We accept
this; scope is single-machine, single-session.

---

## ADR-0002: Session UUID format `YYYYMMDD_HHMMSS_xxxx`

**Status:** Accepted (Phase 1, 2026-04-26)

**Decision:** Session ids are timestamp-prefixed with a 4-hex-char suffix,
e.g. `20260426_141833_a3f1`.

**Why:** Pure-random UUIDs are painful to debug ("which session was
participant 7?"). Timestamp prefix sorts in the file explorer, embeds
when-this-ran in the name, and 4 hex chars (~65k space) is plenty of
collision resistance for a study with ~30 participants. `Crypto.generate_random_bytes`
would be overkill — there is no security requirement.

**Consequence:** Sessions started in the same second on the same machine
have a 1-in-65k collision chance. Acceptable for this study.

---

## ADR-0003: Local persistence over a collection backend

**Status:** Accepted (2026-07-27). Confirms and scopes ADR-0001 Decision 4.

**Context:** The project agreement (section B, Technisches Konzept) requires the
tracking data to be stored asynchronously "entweder über eine leichtgewichtige
Backend-Datenbank **oder** eine sichere lokale Zwischenspeicherung". Both
options satisfy the agreement. A collection server was designed (ingest endpoint
with per-session JSONL append, idempotent by `seq`, plus CSV export endpoints)
and evaluated against the local-only variant.

**Decision:** Keep local JSONL persistence. Data is collected off the study
machines after the sessions and analysed with `tools/analyze.py`.

**Why:**
- The study runs supervised on a small number of machines with 20 to 30
  participants. Transport was never the bottleneck; collecting the files is a
  folder copy.
- The value the server would have added was the aggregated export, and that is
  what `tools/analyze.py` produces directly from the log folder. Same tables, no
  network, no deployment, no uptime dependency during a session.
- Privacy by construction: no personal data leaves the machine. The session id
  is a pseudonym; the mapping to participants lives in a separate
  `participants.csv` held by the study lead, which is exactly the pseudonymised
  handling the agreement commits to.
- A shipped client cannot hold a real API secret, so a token in the game would
  have been a spam gate rather than authentication. Not building the endpoint
  avoids claiming a protection we could not deliver.

**Consequence:** No real-time view of a running session, and a machine whose
files are never copied loses its data. Mitigated by copying the log folder at
the end of each session and running `tools/analyze.py`, which prints a per-run
overview so a missing or empty session is noticed immediately.

**Ausblick (for the thesis):** the backend variant remains the right design for
an unsupervised or distributed rollout, where participants play on their own
machines and no one can collect the files by hand.

---

## ADR-0004: Correctness is graded at the decision, not at the outcome

**Status:** Accepted (2026-07-27)

**Context:** The agreement promises error rates ("Fehlerquoten") and decision
times ("Entscheidungszeiten") as telemetry for the descriptive analysis. Events
carry an `is_correct` field, but not every event that can carry one should
count: run outcomes (`scenario_debrief`, `mail_outcome`) are graded as well.

**Decision:** The error rate is computed only over graded single decisions
(`EventBus.emit_decision`, plus the engine phases `mail_card_played` and
`mail_payload_attempt`). Outcome rows are excluded from the denominator.
Interactions with no right answer use `EventBus.emit_action`, which forces
`is_correct` to `null`.

**Why:** Counting an outcome row alongside the decisions that produced it counts
the same behaviour twice and lets a scenario's aggregate distort a per-decision
rate. Splitting the two emit helpers makes the distinction impossible to get
wrong by accident at the call site, rather than relying on discipline.

**Consequence:** Which choices are "wrong" is a modelling decision that has to be
defensible in the thesis. It is stated per scenario in `docs/event_schema.md`
and anchored to something the game itself already treats as a mistake (junk
finds waste a deck slot, SCHROTT cards get a negative verdict in the post-run
review, a blown cover resets the level).

---

## ADR-0005: The language is chosen in the menu, not mid-scenario

**Status:** Accepted (2026-07-28)

**Context:** Godot re-translates a `Control`'s `text` when the locale changes,
but only if the stored `text` is a translation key. The menu scenes keep raw
keys in their `.tscn` (`text = "MENU_LEVELS"`), so they switch live. Scenario
code resolves through `tr()` at build time and stores the finished string, at 67
call sites across 11 files. Switching mid-scenario therefore left the running
screen in the previous language while the menus flipped.

**Decision:** The language row in the settings overlay is only enabled while
`GameState.is_in_menu()`. During a scenario the buttons are disabled with a
visible reason. Scenarios pick up whatever locale is active when they start.

**Why not rebuild every screen on `NOTIFICATION_TRANSLATION_CHANGED`:** the two
screens with the most text also carry run state. `mail_builder._build()`
constructs a fresh `MailRun`, so re-running it mid-turn would reset the game;
`mail_preview` accumulates the mail thread incrementally and would lose it;
`bad_usb._play_story_step()` would restart its typewriter tween. Making those
safe means separating text construction from state construction in each one,
which is the riskiest kind of change to make shortly before the study.

**Why it is also the better rule for the study:** a participant who switches
language halfway through has played a run in two languages, which the dataset
cannot represent cleanly. One run, one language.

**Consequence:** Participants must be told the language before starting, which
they are anyway. Live switching everywhere remains possible later; it needs the
text/state split described above.

**Side effect worth noting:** nothing previously returned `GameState` to `MENU`,
so the session state stayed on `FEEDBACK` after the first scenario and the
`state_change` telemetry never showed the way back. The menu scenes now announce
themselves, which both unlocks the language row again and makes the navigation
trace in the logs complete.
