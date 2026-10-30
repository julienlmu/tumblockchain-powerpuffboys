"""Data shapes shared by the agent's modules.

The contract side is fixed in docs/SUPPLIERPULSE_PLUS.md §4. Enums travel as
uint8, so they are plain ints here.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Dict, List, Optional

SOURCES = {0: "ch", 1: "gleif"}  # contract source id -> fetch CLI name
SOURCE_IDS = {name: sid for sid, name in SOURCES.items()}

ACTIVE, HELD, CLOSED = 0, 1, 2
STATE_NAMES = {ACTIVE: "Active", HELD: "Held", CLOSED: "Closed"}
OUTCOME_NAMES = {0: "Paid", 1: "AwaitingApproval", 2: "NotDue", 3: "Held"}
TIER_NAMES = {0: "Standard", 1: "Trusted", 2: "Premium"}

# §4.3: rule bits, plus 0x80 when the base status check failed
RULE_LABELS = {
    0x01: "insolvency history",
    0x02: "accounts overdue",
    0x04: "confirmation statement overdue",
    0x08: "LEI registration not issued",
}
BASE_LABELS = {0: "registry status not active", 1: "LEI entity not active"}
FAIL_BASE = 0x80


def failed_labels(source: int, failed_rules: int) -> List[str]:
    labels = [BASE_LABELS[source]] if failed_rules & FAIL_BASE else []
    return labels + [label for bit, label in RULE_LABELS.items() if failed_rules & bit]


def evaluate(source: int, rules: int, raw: str) -> int:
    """failedRules for a signed record, the same way the contract computes it (§4.3)."""
    fields = json.loads(raw)
    failed = 0
    if source == 0:
        if fields.get("status") != "active":
            failed |= FAIL_BASE
        for bit, key in ((0x01, "insolvency"), (0x02, "accounts_overdue"), (0x04, "confirmation_overdue")):
            if rules & bit and fields.get(key) is not False:
                failed |= bit
    else:
        if fields.get("entity_status") != "ACTIVE":
            failed |= FAIL_BASE
        if rules & 0x08 and fields.get("registration_status") != "ISSUED":
            failed |= 0x08
    return failed


@dataclass
class Order:
    id: int
    source: int
    supplier_id: str
    supplier_key: str
    rules: int
    state: int
    remaining: int
    permit_valid: bool
    permit_valid_until: int
    next_due_date: int
    next_approved: bool
    auto_refund_at: int
    tier: int
    last_check: int = 0
    last_failed_rules: int = 0

    @property
    def supplier(self) -> str:
        """Readable supplier name for logs, e.g. ch:09729896."""
        return "%s:%s" % (SOURCES[self.source], self.supplier_id)


@dataclass
class Supplier:
    key: str
    tier: int
    last_check_at: int
    clean_streak: int = 0


@dataclass
class Snapshot:
    now: int
    orders: List[Order]
    suppliers: Dict[str, Supplier] = field(default_factory=dict)

    def order(self, order_id: int) -> Optional[Order]:
        return next((o for o in self.orders if o.id == order_id), None)


@dataclass
class Evidence:
    """One signed response file (§4.1)."""

    source: str
    supplier_id: str
    request_hash: str
    timestamp: int
    data: str
    signature: str
    raw: str = ""
    payment_tx: Optional[str] = None
    price_usd: float = 0.0

    @property
    def args(self) -> list:
        return [self.request_hash, str(self.timestamp), self.data, self.signature]


@dataclass
class Action:
    kind: str  # refund | release | due_check | monitor
    order_id: int
    supplier: str
    reason: str
    cost_usd: float = 0.0

    @property
    def fetches(self) -> bool:
        return self.kind in ("due_check", "monitor")
