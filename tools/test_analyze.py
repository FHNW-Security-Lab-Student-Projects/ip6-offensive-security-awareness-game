#!/usr/bin/env python3
"""Test for analyze.py. Builds a synthetic log folder, runs the analysis and
checks the resulting tables.

Plain script with printed expect/actual lines, matching the convention of the
GDScript tests in tests/. No test framework needed.

Run:
    python3 tools/test_analyze.py
"""

from __future__ import annotations

import csv
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import analyze  # noqa: E402

BASE_MS = 1_785_000_000_000.0

failures = 0


def check(label: str, expected, actual) -> None:
    global failures
    ok = expected == actual
    if not ok:
        failures += 1
    print(f"{'ok ' if ok else 'FAIL'} {label} (expect {expected!r}): {actual!r}")


def event(seq, phase, scenario, action, correct, latency, payload=None, offset=0):
    return {
        "seq": seq,
        "timestamp_ms": BASE_MS + offset,
        "session_uuid": "PLACEHOLDER",
        "participant_code": "",
        "phase": phase,
        "scenario_id": scenario,
        "action": action,
        "is_correct": correct,
        "latency_ms": latency,
        "payload": payload or {},
    }


def full_session(uuid: str) -> list[dict]:
    """A complete run: recon with one junk pick, a won mail, then bad_usb."""
    events = [
        event(1, "scenario_start", "spear_phishing", None, None, 0, offset=0),
        event(2, "action", "spear_phishing", "recon_find_collected", True, 4000,
              {"find_id": "q6_kununu", "is_junk": False}, offset=4_000),
        event(3, "action", "spear_phishing", "recon_find_collected", False, 2000,
              {"find_id": "q6x_lob", "is_junk": True}, offset=6_000),
        event(4, "action", "spear_phishing", "recon_completed", None, 30_000,
              {"collected_count": 2, "junk_count": 1, "sources_opened": 4},
              offset=30_000),
        event(5, "mail_card_played", "spear_phishing", "dringlichkeit", True, None,
              {"principle": "knappheit"}, offset=45_000),
        event(6, "mail_sent", "spear_phishing", "mail_sent", None, 12_000,
              {"card_count": 1}, offset=45_500),
        event(7, "scenario_debrief", "spear_phishing", "WIN", True, None,
              {"outcome": "WIN", "turns_used": 3, "suspicion": 2, "pressure": 8,
               "cards_played": ["dringlichkeit", "payload_link"]}, offset=60_000),
        event(8, "scenario_start", "bad_usb", None, None, 0, offset=70_000),
        event(9, "action", "bad_usb", "dialogue_choice", False, 5000,
              {"step": 10, "choice": 1, "path": "stressed"}, offset=75_000),
        event(10, "action", "bad_usb", "dialogue_choice", True, 3000,
              {"step": 10, "choice": 2, "path": "stressed"}, offset=90_000),
        event(11, "action", "bad_usb", "usb_inserted", True, 2000, {}, offset=120_000),
        event(12, "scenario_debrief", "bad_usb", "USB_PLANTED", True, None,
              {"outcome": "USB_PLANTED", "failures": 1, "restricted_attempts": 2,
               "reception_path": "stressed"}, offset=150_000),
    ]
    for item in events:
        item["session_uuid"] = uuid
    return events


def replayed_session(uuid: str) -> list[dict]:
    """A lost first run followed by a replay that wins.

    A replay appends to the SAME session file (the autoloads survive the scene
    change), so this is what one participant who pressed "Nochmal spielen"
    actually produces.
    """
    events = [
        # --- attempt 1: two wrong picks, ends in SPAM ---
        event(1, "scenario_start", "spear_phishing", None, None, 0, offset=0),
        event(2, "action", "spear_phishing", "recon_find_collected", False, 3000,
              {"find_id": "q6x_lob", "is_junk": True}, offset=3_000),
        event(3, "action", "spear_phishing", "recon_completed", None, 20_000,
              {"collected_count": 3, "junk_count": 2, "sources_opened": 2},
              offset=20_000),
        event(4, "mail_card_played", "spear_phishing", "schrott_floskel", False, None,
              {"principle": "keine", "card_type": "SCHROTT"}, offset=30_000),
        event(5, "scenario_debrief", "spear_phishing", "SPAM", False, None,
              {"outcome": "SPAM", "turns_used": 6, "suspicion": 9, "pressure": 4,
               "cards_played": ["schrott_floskel"]}, offset=40_000),
        # --- attempt 2: the informed replay, everything right ---
        event(6, "scenario_start", "spear_phishing", None, None, 0, offset=50_000),
        event(7, "action", "spear_phishing", "recon_find_collected", True, 1500,
              {"find_id": "q6_kununu", "is_junk": False}, offset=52_000),
        event(8, "action", "spear_phishing", "recon_completed", None, 12_000,
              {"collected_count": 5, "junk_count": 0, "sources_opened": 6},
              offset=62_000),
        event(9, "mail_card_played", "spear_phishing", "dringlichkeit", True, None,
              {"principle": "knappheit", "card_type": "EPIC"}, offset=70_000),
        event(10, "mail_card_played", "spear_phishing", "payload_link", True, None,
              {"principle": "autoritaet", "card_type": "PAYLOAD"}, offset=71_000),
        event(11, "scenario_debrief", "spear_phishing", "WIN", True, None,
              {"outcome": "WIN", "turns_used": 3, "suspicion": 2, "pressure": 8,
               "cards_played": ["dringlichkeit", "payload_link"]}, offset=80_000),
    ]
    for item in events:
        item["session_uuid"] = uuid
    return events


def abandoned_session(uuid: str) -> list[dict]:
    """Started the level and quit halfway: no scenario_debrief, so no outcome.

    Without an explicit abort count this looks identical in the summary to a
    participant who never launched the scenario at all.
    """
    events = [
        event(1, "scenario_start", "bad_usb", None, None, 0, offset=0),
        event(2, "action", "bad_usb", "enter_building", None, 4000, {}, offset=4_000),
        event(3, "action", "bad_usb", "dialogue_choice", True, 3000,
              {"step": 10, "choice": 2, "path": "stressed"}, offset=9_000),
        # ...and here the participant closed the game.
    ]
    for item in events:
        item["session_uuid"] = uuid
    return events


def stamp_code(events: list[dict], code: str) -> list[dict]:
    """A session where the player entered the code in-game, so every line
    carries it. Returns new dicts; the input is left alone."""
    return [dict(e, participant_code=code) for e in events]


def write_session(folder: Path, uuid: str, events: list[dict], junk_line=False) -> None:
    path = folder / f"session_{uuid}.jsonl"
    with path.open("w", encoding="utf-8") as handle:
        for item in events:
            handle.write(json.dumps(item) + "\n")
        if junk_line:
            # A hard crash can leave the last line half-written. Losing that one
            # line must not cost the whole session.
            handle.write('{"seq": 99, "phase": "action", "scen')


def read_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        logs = Path(tmp) / "logs"
        logs.mkdir()
        out = Path(tmp) / "analysis"

        uuid_a = "20260727_141833_a3f1"
        uuid_b = "20260727_151200_b2c3"
        uuid_c = "20260727_161500_c4d5"
        write_session(logs, uuid_a, full_session(uuid_a))
        write_session(logs, uuid_b, full_session(uuid_b), junk_line=True)
        write_session(logs, uuid_c, replayed_session(uuid_c))
        # Entered in-game: no mapping row exists for it, and none is needed.
        uuid_d = "20260727_171000_d6e7"
        write_session(logs, uuid_d, stamp_code(full_session(uuid_d), "P99"))
        # Entered in-game AND present in the mapping, with a conflicting value.
        uuid_e = "20260727_181000_e8f9"
        write_session(logs, uuid_e, stamp_code(full_session(uuid_e), "P50"))

        uuid_f = "20260727_191000_f0a1"
        write_session(logs, uuid_f, stamp_code(abandoned_session(uuid_f), "P42"))

        participants = Path(tmp) / "participants.csv"
        participants.write_text(
            "session_uuid,participant_code\n"
            f"{uuid_a},P01\n{uuid_b},P02\n{uuid_c},P03\n{uuid_e},WRONG\n",
            encoding="utf-8",
        )

        sys.argv = [
            "analyze.py", str(logs), "-o", str(out), "-p", str(participants),
        ]
        code = analyze.main()
        check("analyze exits cleanly", 0, code)

        summary = read_csv(out / "summary.csv")
        events = read_csv(out / "events.csv")

        check("one summary row per session", 6, len(summary))
        # 12 good events in each of the four full sessions (the truncated 13th
        # line is dropped) plus 11 in the replayed one.
        check("all readable events kept", 62, len(events))

        # --- participant code ------------------------------------------------
        stamped = next(r for r in summary if r["session_uuid"] == uuid_d)
        check("in-game code used without any mapping", "P99", stamped["participant_code"])

        conflict = next(r for r in summary if r["session_uuid"] == uuid_e)
        # The stamped value cannot drift out of sync with its own session, so it
        # wins over a hand-maintained row that says otherwise.
        check("stamped code beats the mapping", "P50", conflict["participant_code"])

        check(
            "code reaches every event row",
            True,
            all(
                e["participant_code"] == "P99"
                for e in events
                if e["session_uuid"] == uuid_d
            ),
        )

        row = next(r for r in summary if r["session_uuid"] == uuid_a)
        check("participant code joined", "P01", row["participant_code"])
        check("graded decisions counted", "6", row["decisions_graded"])
        check("wrong decisions counted", "2", row["decisions_wrong"])
        check("error rate computed", "0.333", row["error_rate"])
        check("session duration in seconds", "150.0", row["duration_s"])
        check("both scenarios listed", "bad_usb;spear_phishing", row["scenarios_played"])

        # Decision times come only from phase=action events with a real latency:
        # 4000, 2000, 30000, 5000, 3000, 2000 -> median 3500.
        check("median decision time", "3500", row["decision_ms_median"])

        check("spear phishing outcome", "WIN", row["sp_outcome"])
        check("turns used", "3", row["sp_turns_used"])
        check("cards played flattened", "dringlichkeit;payload_link", row["sp_cards_played"])
        check("junk picks surfaced", "1", row["sp_recon_junk"])
        check("bad usb outcome", "USB_PLANTED", row["usb_outcome"])
        check("bad usb failures", "1", row["usb_failures"])
        check("bad usb detours", "2", row["usb_restricted_attempts"])

        truncated = next(r for r in summary if r["session_uuid"] == uuid_b)
        check("truncated file still summarised", "P02", truncated["participant_code"])
        check("truncated file kept its events", "12", truncated["events_total"])

        # --- the replay: one session, two runs of the same scenario ----------
        rep = next(r for r in summary if r["session_uuid"] == uuid_c)
        check("replay stays one session row", "P03", rep["participant_code"])
        check("both attempts counted", "2", rep["sp_attempts"])
        check("both starts counted", "2", rep["runs_started"])
        check("both runs finished", "2", rep["runs_finished"])
        check("nothing aborted", "0", rep["runs_aborted"])

        # --- abandoned run ----------------------------------------------------
        gone = next(r for r in summary if r["session_uuid"] == uuid_f)
        check("abandoned run counted as started", "1", gone["runs_started"])
        check("abandoned run never finished", "0", gone["runs_finished"])
        check("abandoned run flagged", "1", gone["runs_aborted"])
        # No debrief means no outcome; the abort column is the only thing that
        # distinguishes this from "never played the scenario".
        check("abandoned run has no outcome", "", gone["usb_outcome"])
        # Its decisions are still there and still count.
        check("decisions before the abort kept", "1", gone["decisions_graded"])

        # Headline numbers describe the FIRST run: it lost, with 2 graded
        # decisions of which 2 were wrong.
        check("headline outcome is the first run", "SPAM", rep["sp_outcome"])
        check("first run error rate", "1.0", rep["error_rate"])
        check("first run graded decisions", "2", rep["decisions_graded"])
        check("first run recon junk", "2", rep["sp_recon_junk"])

        # ...while the _all columns keep the replay visible. Across both runs
        # there are 5 graded decisions, 2 of them wrong.
        check("every outcome listed in order", "SPAM;WIN", rep["sp_outcomes_all"])
        check("all-runs error rate differs", "0.4", rep["error_rate_all"])
        check("all-runs graded decisions", "5", rep["decisions_graded_all"])

        # Which cards belong to which run.
        check("first run cards", "schrott_floskel", rep["sp_cards_played"])
        check(
            "cards split per run",
            "schrott_floskel|dringlichkeit;payload_link",
            rep["sp_cards_played_all"],
        )

        # events.csv must attribute every card row to its run.
        cards = [
            e
            for e in events
            if e["session_uuid"] == uuid_c and e["phase"] == "mail_card_played"
        ]
        check("all card plays logged across runs", 3, len(cards))
        check(
            "card rows carry their attempt",
            [("schrott_floskel", "1"), ("dringlichkeit", "2"), ("payload_link", "2")],
            [(c["action"], c["attempt"]) for c in cards],
        )
        # Menu events before the first scenario_start belong to no run.
        starts = [
            e for e in events if e["session_uuid"] == uuid_c and e["phase"] == "scenario_start"
        ]
        check("run boundaries numbered", ["1", "2"], [e["attempt"] for e in starts])

    print()
    if failures:
        print(f"{failures} CHECK(S) FAILED")
        return 1
    print("TEST DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
