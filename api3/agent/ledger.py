"""What the agent remembers between ticks and restarts: spend, retries, quarantine.

Stored in <state_dir>/state.json and written atomically, so a crash or a
restart in the supervised loop resumes where it stopped.
"""
from __future__ import annotations

import datetime
import json
import os
from pathlib import Path
from typing import Optional, Tuple

from config import BACKOFF_SECONDS


def utc_day(ts: int) -> str:
    return datetime.datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d")


class Ledger:
    def __init__(self, path: Path):
        self.path = Path(path)
        self.data = {"spend": {}, "failures": {}, "quarantine": {}, "paused_until": 0, "cycle": 0, "tiers": {}}
        if self.path.exists():
            self.data.update(json.loads(self.path.read_text()))

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.data, indent=2, sort_keys=True))
        os.replace(tmp, self.path)

    # ---- cycles
    def next_cycle(self) -> int:
        self.data["cycle"] += 1
        return self.data["cycle"]

    # ---- spending (per UTC day of chain time)
    def spent(self, now: int) -> float:
        return round(self.data["spend"].get(utc_day(now), 0.0), 6)

    def add_spend(self, now: int, usd: float) -> None:
        day = utc_day(now)
        self.data["spend"][day] = round(self.data["spend"].get(day, 0.0) + usd, 6)

    def pause_paid(self, now: int, seconds: int) -> None:
        self.data["paused_until"] = now + seconds

    def paid_paused(self, now: int) -> bool:
        return now < self.data.get("paused_until", 0)

    # ---- retries per order
    def backoff_ok(self, order_id: int, now: int) -> bool:
        entry = self.data["failures"].get(str(order_id))
        return entry is None or now >= entry["next_at"]

    def record_failure(self, order_id: int, now: int, max_attempts: int, exhausted_wait: int,
                       kind: str = "fetch_error") -> Tuple[int, bool]:
        """Count a failed attempt. Returns (attempt number, exhausted). Exhausted waits for the next window."""
        entry = dict(self.data["failures"].get(str(order_id), {"count": 0, "next_at": 0}), at=now, kind=kind)
        if kind == "no_data":
            entry["no_data_at"] = now
        count = entry["count"] + 1
        if count >= max_attempts:
            entry.update(count=0, next_at=now + exhausted_wait)
        else:
            entry.update(count=count, next_at=now + BACKOFF_SECONDS[min(count - 1, len(BACKOFF_SECONDS) - 1)])
        self.data["failures"][str(order_id)] = entry
        return count, count >= max_attempts

    def failed_since(self, order_id: int, ts: int) -> bool:
        """An attempt for this order failed at or after ts, for any reason, and nothing succeeded since."""
        entry = self.data["failures"].get(str(order_id))
        return entry is not None and entry.get("at", 0) >= ts

    def no_data_since(self, order_id: int, ts: int) -> bool:
        """The registry answered "no data" for this order at or after ts, and nothing succeeded since."""
        entry = self.data["failures"].get(str(order_id))
        return entry is not None and entry.get("no_data_at", 0) >= ts

    def clear_failures(self, order_id: int) -> None:
        self.data["failures"].pop(str(order_id), None)

    # ---- quarantine: stop acting on an order (config mismatch or tampering)
    def quarantine(self, order_id: int, reason: str) -> None:
        self.data["quarantine"][str(order_id)] = reason

    def is_quarantined(self, order_id: int) -> bool:
        return str(order_id) in self.data["quarantine"]

    # ---- tier changes (for the log)
    def tier_change(self, supplier_key: str, tier: int) -> Optional[int]:
        """Remember the supplier's tier. Returns the previous tier if it changed."""
        old = self.data["tiers"].get(supplier_key)
        self.data["tiers"][supplier_key] = tier
        return old if old is not None and old != tier else None
