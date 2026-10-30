"""The agent's cycle log (<state_dir>/cycles.jsonl) and the summary built from it.

One JSON line per action, so the overnight run can be shown and counted as
evidence of repeated autonomous cycles.
"""
from __future__ import annotations

import collections
import datetime
import json
from pathlib import Path
from typing import Callable, List, Optional


def utc_now() -> str:
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


class Journal:
    def __init__(self, path: Path, echo: Optional[Callable[[str], None]] = print):
        self.path = Path(path)
        self.echo = echo

    def write(self, **entry) -> dict:
        entry = {"ts": utc_now(), **{k: v for k, v in entry.items() if v is not None}}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a") as f:
            f.write(json.dumps(entry, sort_keys=False) + "\n")
        if self.echo:
            self.echo(format_entry(entry))
        return entry

    def read(self) -> List[dict]:
        if not self.path.exists():
            return []
        return [json.loads(line) for line in self.path.read_text().splitlines() if line.strip()]


def format_entry(e: dict) -> str:
    parts = ["%s #%s" % (e.get("ts", ""), e.get("cycle", "-")), e.get("action", "")]
    if "orderId" in e:
        parts.append("order %s" % e["orderId"])
    if e.get("supplier"):
        parts.append(e["supplier"])
    parts.append("-> %s" % e.get("outcome", ""))
    for key in ("labels", "reason", "error", "tx"):
        if e.get(key):
            parts.append("%s=%s" % (key, ", ".join(e[key]) if isinstance(e[key], list) else e[key]))
    return " ".join(parts)


def report(entries: List[dict], spend: dict) -> str:
    """Plain-text summary of a run, for the README, docs/agent.md and the video."""
    if not entries:
        return "no cycles logged yet"
    cycles = {e.get("cycle") for e in entries if e.get("cycle") is not None}
    by_action = collections.Counter((e.get("action"), e.get("outcome")) for e in entries)
    lines = [
        "cycles:        %d (%s -> %s)" % (len(cycles), entries[0]["ts"], entries[-1]["ts"]),
        "spend per day: %s" % (", ".join("%s $%.2f" % kv for kv in sorted(spend.items())) or "none"),
        "actions:",
    ]
    for (action, outcome), n in sorted(by_action.items(), key=lambda kv: (-kv[1], str(kv[0]))):
        lines.append("  %-16s %-18s %d" % (action, outcome, n))
    tiers = [e for e in entries if e.get("action") == "tier"]
    if tiers:
        lines.append("tier changes:")
        lines += ["  %s %s: %s" % (e["ts"], e.get("supplier"), e.get("outcome")) for e in tiers]
    txs = [e for e in entries if e.get("tx")]
    if txs:
        lines.append("transactions: %d (last %s)" % (len(txs), txs[-1]["tx"]))
    alerts = [e for e in entries if e.get("outcome") in ("alert", "quarantined")]
    lines.append("alerts:        %d" % len(alerts))
    return "\n".join(lines)
