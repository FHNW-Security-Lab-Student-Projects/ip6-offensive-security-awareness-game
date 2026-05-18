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
