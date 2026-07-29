#!/usr/bin/env python3
"""Turn the collected session logs into two CSV tables for the user study.

The game writes one append-only JSONL file per session. This script reads a
folder of those files and produces:

  events.csv    one row per event, flattened. The raw behavioural trace.
  summary.csv   one row per session. This is the table for R / SPSS / Excel:
                error rate, decision times and per-scenario outcomes.

Standard library only, so it runs on any Python 3.9+ without installing
anything.

Usage:
    python3 tools/analyze.py <log-folder> [-o out] [-p participants.csv]

    <log-folder>        folder holding session_*.jsonl (copy them off the
                        study machines first)
    -o / --out          output folder, default "analysis"
    -p / --participants optional CSV mapping sessions to participant codes,
                        so the game data can be joined to the pre/post
                        questionnaires. Two columns, with header:

                            session_uuid,participant_code
                            20260727_141833_a3f1,P07

                        Sessions sort chronologically by uuid, which makes
                        filling this in after a study day straightforward.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path

# Phases that grade a single player decision. The error rate is computed over
# these and nothing else.
GRADED_DECISION_PHASES = {"action", "mail_card_played", "mail_payload_attempt"}

# Also graded, but each row summarises a whole run rather than one choice.
# Including them would put an aggregate into the per-decision denominator and
# count the decisions that produced the outcome a second time. The outcomes
# still reach the summary through the sp_/usb_ columns.
OUTCOME_PHASES = {"scenario_debrief", "mail_outcome"}

# Phases carrying a time-to-decide. scenario_complete also has a latency_ms, but
# it is the total scenario duration and would swamp the average.
LATENCY_PHASES = {"action", "mail_sent", "mail_pass"}

# Actions whose latency is a duration rather than a deliberation: a whole phase
# (recon_completed) or a reading time (debrief_advanced). They stay in
# events.csv, they just do not belong in the decision-time statistic.
NON_DECISION_ACTIONS = {"recon_completed", "debrief_advanced"}

# A latency below zero is the engine's "no clock was running" sentinel
# (PromptClock.UNKNOWN / MailRun.UNKNOWN_LATENCY), not a fast answer.
UNKNOWN_LATENCY = -1

EVENT_COLUMNS = [
    "participant_code",
    "session_uuid",
    "seq",
    "attempt",
    "iso_time",
    "timestamp_ms",
    "phase",
    "scenario_id",
    "action",
    "is_correct",
    "latency_ms",
    "payload_json",
]

# Columns without a suffix describe the FIRST attempt. Replaying a scenario
# appends to the same session, and a second, better-informed run would otherwise
# flatter the numbers, so the first attempt is the primary measure and the
# _all columns keep the full picture next to it.
SUMMARY_COLUMNS = [
    "participant_code",
    "session_uuid",
    "started_at",
    "ended_at",
    "duration_s",
    "scenarios_played",
    "events_total",
    # A run that was started but never reached its debrief screen: the
    # participant quit mid-scenario. Without this the row looks like "scenario
    # not played", and an abandoned session cannot be excluded on purpose.
    "runs_started",
    "runs_finished",
    "runs_aborted",
    # first attempt of each scenario
    "decisions_graded",
    "decisions_correct",
    "decisions_wrong",
    "error_rate",
    "decision_ms_median",
    "decision_ms_mean",
    # every attempt, replays included
    "decisions_graded_all",
    "decisions_wrong_all",
    "error_rate_all",
    "decision_ms_median_all",
    # spear_phishing
    "sp_attempts",
    "sp_outcome",
    "sp_outcomes_all",
    "sp_turns_used",
    "sp_suspicion",
    "sp_pressure",
    "sp_cards_played",
    "sp_cards_played_all",
    "sp_recon_collected",
    "sp_recon_junk",
    "sp_recon_sources_opened",
    # bad_usb
    "usb_attempts",
    "usb_outcome",
    "usb_outcomes_all",
    "usb_failures",
    "usb_restricted_attempts",
    "usb_reception_path",
]


def iso(timestamp_ms: float) -> str:
    """Unix epoch milliseconds to a readable UTC timestamp."""
    try:
        return datetime.fromtimestamp(
            timestamp_ms / 1000.0, tz=timezone.utc
        ).isoformat(timespec="seconds")
    except (OverflowError, OSError, ValueError):
        return ""


def read_session(path: Path) -> list[dict]:
    """Parse one JSONL file, skipping unreadable lines rather than aborting.

    A crashed run can leave a truncated final line; losing that one line must
    not cost us the participant's whole session.
    """
    events: list[dict] = []
    with path.open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError as exc:
                print(f"  ! {path.name}:{number} skipped ({exc.msg})", file=sys.stderr)
                continue
            if not isinstance(event, dict):
                print(f"  ! {path.name}:{number} skipped (not an object)", file=sys.stderr)
                continue
            events.append(event)
    events.sort(key=lambda e: (e.get("seq") or 0))
    return events


def load_participants(path: Path | None) -> dict[str, str]:
    """session_uuid -> participant_code, for joining game data to the surveys."""
    if path is None:
        return {}
    mapping: dict[str, str] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            uuid = (row.get("session_uuid") or "").strip()
            code = (row.get("participant_code") or "").strip()
            if uuid and code:
                mapping[uuid] = code
    if not mapping:
        print(f"  ! {path} produced no mappings, check the header row", file=sys.stderr)
    return mapping


def attempt_index(events: list[dict]) -> list:
    """Per-event attempt number, aligned one-to-one with `events`.

    A replay does NOT start a new session file: the autoloads survive the scene
    change, so the log just gains a second scenario_start block under the same
    session_uuid. Counting scenario_start per scenario_id recovers which run an
    event belongs to. Events before the first scenario_start (menu navigation)
    belong to no run and get an empty value.
    """
    out: list = []
    counts: dict[str, int] = {}
    current: object = ""
    for event in events:
        if event.get("phase") == "scenario_start":
            scenario = event.get("scenario_id", "")
            counts[scenario] = counts.get(scenario, 0) + 1
            current = counts[scenario]
        out.append(current)
    return out


def first_attempt_events(events: list[dict], attempts: list) -> list[dict]:
    """Only the events from each scenario's first run."""
    return [event for event, attempt in zip(events, attempts) if attempt == 1]


def graded_decisions(events: list[dict]) -> list[dict]:
    """The events the error rate is computed from: one graded choice each."""
    return [
        e
        for e in events
        if e.get("phase") in GRADED_DECISION_PHASES
        and isinstance(e.get("is_correct"), bool)
    ]


def session_codes(events: list[dict]) -> list[str]:
    """Distinct non-empty participant codes stamped in this session, in order.

    Normally exactly one. Zero means nobody filled the field in. More than one
    means the code was edited after events had already been logged, which makes
    the session ambiguous and has to be surfaced rather than silently resolved.
    """
    seen: list[str] = []
    for event in events:
        code = event.get("participant_code")
        if isinstance(code, str) and code.strip() and code.strip() not in seen:
            seen.append(code.strip())
    return seen


def decision_latencies(events: list[dict]) -> list[int]:
    out: list[int] = []
    for event in events:
        if event.get("phase") not in LATENCY_PHASES:
            continue
        if event.get("action") in NON_DECISION_ACTIONS:
            continue
        latency = event.get("latency_ms")
        if isinstance(latency, (int, float)) and latency > UNKNOWN_LATENCY:
            out.append(int(latency))
    return out


def debriefs_for(events: list[dict], scenario_id: str) -> list[dict]:
    """Every finished run of one scenario, in order. More than one means the
    participant replayed it; the summary reports the last (final) attempt."""
    return [
        e
        for e in events
        if e.get("phase") == "scenario_debrief" and e.get("scenario_id") == scenario_id
    ]


def summarise(uuid: str, events: list[dict], code: str) -> dict:
    timestamps = [
        e["timestamp_ms"]
        for e in events
        if isinstance(e.get("timestamp_ms"), (int, float))
    ]
    first = min(timestamps) if timestamps else 0.0
    last = max(timestamps) if timestamps else 0.0

    attempts = attempt_index(events)
    first_run = first_attempt_events(events, attempts)

    graded = graded_decisions(first_run)
    correct = sum(1 for e in graded if e["is_correct"])
    wrong = len(graded) - correct
    latencies = decision_latencies(first_run)

    graded_all = graded_decisions(events)
    wrong_all = sum(1 for e in graded_all if not e["is_correct"])
    latencies_all = decision_latencies(events)

    scenarios = sorted(
        {e.get("scenario_id") for e in events if e.get("scenario_id")} - {""}
    )

    # Both scenarios emit scenario_debrief when their debrief screen appears, so
    # a start without a debrief means the player left before reaching the end.
    started = sum(1 for e in events if e.get("phase") == "scenario_start")
    finished = sum(1 for e in events if e.get("phase") == "scenario_debrief")

    row = {
        "participant_code": code,
        "session_uuid": uuid,
        "started_at": iso(first),
        "ended_at": iso(last),
        "duration_s": round((last - first) / 1000.0, 1) if timestamps else "",
        "scenarios_played": ";".join(scenarios),
        "events_total": len(events),
        "runs_started": started,
        "runs_finished": finished,
        "runs_aborted": started - finished,
        "decisions_graded": len(graded),
        "decisions_correct": correct,
        "decisions_wrong": wrong,
        "error_rate": round(wrong / len(graded), 3) if graded else "",
        "decision_ms_median": round(statistics.median(latencies)) if latencies else "",
        "decision_ms_mean": round(statistics.fmean(latencies)) if latencies else "",
        "decisions_graded_all": len(graded_all),
        "decisions_wrong_all": wrong_all,
        "error_rate_all": round(wrong_all / len(graded_all), 3) if graded_all else "",
        "decision_ms_median_all": (
            round(statistics.median(latencies_all)) if latencies_all else ""
        ),
    }
    row.update(_spear_phishing_columns(events, first_run))
    row.update(_bad_usb_columns(events, first_run))
    return row


def _outcomes(runs: list[dict]) -> str:
    """Every attempt's outcome in order, e.g. "SPAM;WIN" for a replayed run."""
    return ";".join(str(r.get("payload", {}).get("outcome", "")) for r in runs)


def _cards_per_run(runs: list[dict]) -> str:
    """Cards per attempt, runs separated by "|" and cards within a run by ";".

    So "schrott_floskel|dringlichkeit;payload_link" reads as: attempt 1 played
    one junk card, attempt 2 played two. For per-card detail (principle, card
    type, bar movement) use events.csv, where every row carries its attempt.
    """
    return "|".join(
        ";".join(run.get("payload", {}).get("cards_played", []) or []) for run in runs
    )


def _spear_phishing_columns(events: list[dict], first_run: list[dict]) -> dict:
    all_runs = debriefs_for(events, "spear_phishing")
    first = debriefs_for(first_run, "spear_phishing")
    payload = first[0]["payload"] if first else {}
    recon = [e for e in first_run if e.get("action") == "recon_completed"]
    recon_payload = recon[0].get("payload", {}) if recon else {}
    return {
        "sp_attempts": len(all_runs),
        "sp_outcome": payload.get("outcome", ""),
        "sp_outcomes_all": _outcomes(all_runs),
        "sp_turns_used": payload.get("turns_used", ""),
        "sp_suspicion": payload.get("suspicion", ""),
        "sp_pressure": payload.get("pressure", ""),
        "sp_cards_played": ";".join(payload.get("cards_played", []) or []),
        "sp_cards_played_all": _cards_per_run(all_runs),
        "sp_recon_collected": recon_payload.get("collected_count", ""),
        "sp_recon_junk": recon_payload.get("junk_count", ""),
        "sp_recon_sources_opened": recon_payload.get("sources_opened", ""),
    }


def _bad_usb_columns(events: list[dict], first_run: list[dict]) -> dict:
    all_runs = debriefs_for(events, "bad_usb")
    first = debriefs_for(first_run, "bad_usb")
    payload = first[0]["payload"] if first else {}
    return {
        "usb_attempts": len(all_runs),
        "usb_outcome": payload.get("outcome", ""),
        "usb_outcomes_all": _outcomes(all_runs),
        "usb_failures": payload.get("failures", ""),
        "usb_restricted_attempts": payload.get("restricted_attempts", ""),
        "usb_reception_path": payload.get("reception_path", ""),
    }


def event_rows(uuid: str, events: list[dict], code: str):
    attempts = attempt_index(events)
    for event, attempt in zip(events, attempts):
        yield {
            "participant_code": code,
            "session_uuid": uuid,
            "seq": event.get("seq", ""),
            "attempt": attempt,
            "iso_time": iso(event.get("timestamp_ms", 0.0)),
            "timestamp_ms": event.get("timestamp_ms", ""),
            "phase": event.get("phase", ""),
            "scenario_id": event.get("scenario_id", ""),
            "action": event.get("action", ""),
            "is_correct": event.get("is_correct", ""),
            "latency_ms": event.get("latency_ms", ""),
            "payload_json": json.dumps(
                event.get("payload", {}), ensure_ascii=False, sort_keys=True
            ),
        }


def write_csv(path: Path, columns: list[str], rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def print_report(summaries: list[dict]) -> None:
    """Per-run overview, so a test session can be checked at a glance."""
    print()
    print(
        f"{'participant':<12}{'session':<22}{'min':>5}{'err':>7}"
        f"{'runs':>6}{'sp':>10}{'usb':>8}"
    )
    print("-" * 70)
    for row in summaries:
        duration = row["duration_s"]
        minutes = f"{duration / 60:.1f}" if isinstance(duration, float) else "?"
        error = row["error_rate"]
        error_text = f"{error:.0%}" if isinstance(error, float) else "-"
        # A star marks a session with replays, where the headline error rate is
        # the first attempt only and the _all columns differ.
        runs = row["runs_started"]
        runs_text = f"{runs}*" if runs > len(row["scenarios_played"].split(";")) else str(runs)
        if row["runs_aborted"]:
            runs_text += "!"
        print(
            f"{row['participant_code'] or '-':<12}"
            f"{row['session_uuid']:<22}"
            f"{minutes:>5}"
            f"{error_text:>7}"
            f"{runs_text:>6}"
            # Outcome names run long (KOLLEGEN_RUECKFRAGE); clip so the columns
            # stay aligned. The untruncated value is in summary.csv.
            f"{(row['sp_outcome'] or '-')[:9]:>10}"
            f"{(row['usb_outcome'] or '-')[:7]:>8}"
        )
    graded = [r["error_rate"] for r in summaries if isinstance(r["error_rate"], float)]
    if graded:
        print("-" * 70)
        print(f"{'mean error rate (first attempts)':<40}{statistics.fmean(graded):.1%}")
    if any(str(r["runs_started"]) != str(len(r["scenarios_played"].split(";")))
           for r in summaries):
        print("* session contains a replay; err is the first attempt, see *_all columns")
    if any(r["runs_aborted"] for r in summaries):
        print("! session has a run that never reached its debrief (quit mid-scenario)")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build events.csv and summary.csv from the session logs."
    )
    parser.add_argument("logs", type=Path, help="folder containing session_*.jsonl")
    parser.add_argument("-o", "--out", type=Path, default=Path("analysis"))
    parser.add_argument(
        "-p",
        "--participants",
        type=Path,
        default=None,
        help="CSV mapping session_uuid to participant_code",
    )
    args = parser.parse_args()

    if not args.logs.is_dir():
        print(f"error: {args.logs} is not a folder", file=sys.stderr)
        return 1
    if args.participants is not None and not args.participants.is_file():
        print(f"error: {args.participants} not found", file=sys.stderr)
        return 1

    files = sorted(args.logs.glob("session_*.jsonl"))
    if not files:
        print(f"error: no session_*.jsonl in {args.logs}", file=sys.stderr)
        return 1

    codes = load_participants(args.participants)
    all_events: list[dict] = []
    summaries: list[dict] = []
    uncoded: list[str] = []

    for path in files:
        events = read_session(path)
        if not events:
            print(f"  ! {path.name} is empty, skipped", file=sys.stderr)
            continue
        uuid = events[0].get("session_uuid") or path.stem.replace("session_", "")
        # The code the game stamped wins over the manual mapping: it cannot
        # drift out of sync with the session it belongs to.
        stamped = session_codes(events)
        if len(stamped) > 1:
            print(
                f"  ! {path.name} carries several participant codes "
                f"({', '.join(stamped)}), using the first",
                file=sys.stderr,
            )
        code = stamped[0] if stamped else codes.get(uuid, "")
        if not code:
            uncoded.append(uuid)
        all_events.extend(event_rows(uuid, events, code))
        summaries.append(summarise(uuid, events, code))

    if not summaries:
        print("error: no readable sessions", file=sys.stderr)
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    write_csv(args.out / "events.csv", EVENT_COLUMNS, all_events)
    write_csv(args.out / "summary.csv", SUMMARY_COLUMNS, summaries)

    print(f"{len(summaries)} session(s), {len(all_events)} events")
    print(f"wrote {args.out / 'events.csv'}")
    print(f"wrote {args.out / 'summary.csv'}")
    if uncoded:
        # Named explicitly: an unidentified session cannot be joined to the
        # questionnaires, and it is far cheaper to notice that on the study day
        # than during the analysis weeks later.
        print(
            f"\nwarning: {len(uncoded)} session(s) without a participant code:",
            file=sys.stderr,
        )
        for uuid in uncoded:
            print(f"  {uuid}", file=sys.stderr)
        print(
            "  add them to a participants.csv (session_uuid,participant_code) "
            "and pass it with -p",
            file=sys.stderr,
        )
    print_report(summaries)
    return 0


if __name__ == "__main__":
    sys.exit(main())
