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


PAYMENT_TX_URL = "https://sepolia.basescan.org/tx/"  # x402 payments in aUSD (Base Sepolia)
CONTRACT_TX_URL = "https://sepolia.etherscan.io/tx/"  # SupplierPulse(+) transactions (Ethereum Sepolia)


def _local(ts: str) -> datetime.datetime:
    return datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).astimezone()


def _link(tx: Optional[str], base: str) -> str:
    return "[`%s…%s`](%s%s)" % (tx[:8], tx[-4:], base, tx) if tx else "–"


def report_markdown(entries: List[dict], spend: dict) -> str:
    """Every transaction of a run as a Markdown table with explorer links, for docs/evidence.md."""
    if not entries:
        return "no cycles logged yet"
    zone = _local(entries[0]["ts"]).strftime("%Z")
    rows = ["| Cycle | Time (%s) | Order / supplier | Why | Action | x402 payment (Base Sepolia) | Contract tx (Sepolia) | Outcome |" % zone,
            "|---|---|---|---|---|---|---|---|"]
    for e in entries:
        if not e.get("tx"):
            continue
        rows.append("| %s | %s | %s / `%s` | %s | `%s` | %s | %s | %s |" % (
            e.get("cycle"), _local(e["ts"]).strftime("%d %b %H:%M:%S"), e.get("orderId"), e.get("supplier"),
            e.get("reason", ""), e.get("action"), _link(e.get("paymentTx"), PAYMENT_TX_URL),
            _link(e["tx"], CONTRACT_TX_URL), e.get("outcome")))
    cycles = {e.get("cycle") for e in entries if e.get("cycle") is not None}
    outcomes = collections.Counter(e.get("outcome") for e in entries)
    summary = ("%d cycles from %s to %s (%s): %d transactions, $%.2f spent on paid checks, %d alerts, %d errors."
               % (len(cycles), _local(entries[0]["ts"]).strftime("%d %b %H:%M"),
                  _local(entries[-1]["ts"]).strftime("%d %b %H:%M"), zone, len(rows) - 2, sum(spend.values()),
                  outcomes["alert"] + outcomes["quarantined"], outcomes["error"]))
    return "\n".join(rows + ["", summary])
