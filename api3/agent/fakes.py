"""In-memory stand-ins for the contract and the fetch script.

FakeChain follows the contract rules of docs/SUPPLIERPULSE_PLUS.md §4.5 (v1.1):
freshness, replay, newer-only, the buyer's rules, permits for permitTtl, due
dates, holds, the refund grace period, the no-data exit, verification history
(base status only, forward only) and the supplier-wide stop. It skips signature
checks. With FakeFetcher it lets the agent run end to end with a simulated
clock before the real contract and fetch tools exist:
  python3 pulse_agent.py run --fake --ticks 45
"""
from __future__ import annotations

import copy
import json
from typing import Callable, Dict, Iterable, List, Optional

from chain import Reverted
from evidence import NoData
from model import ACTIVE, CLOSED, FAIL_BASE, HELD, SOURCE_IDS, Evidence, Order, Snapshot, Supplier, evaluate

TRUSTED_STREAK, PREMIUM_STREAK = 3, 6

# the local registry of §4.8: same supplier ids and outcomes as api3/x402/local-registry.json
LOCAL_REGISTRY = {
    "ch:01234567": {"accounts_overdue": False, "confirmation_overdue": False, "status": "active"},
    "ch:07654321": {"accounts_overdue": True, "confirmation_overdue": False, "status": "liquidation"},
    "gleif:TESTLEI0000000000000": {"entity_status": "ACTIVE", "registration_status": "ISSUED"},
    "gleif:TESTLEI0000000000001": {"entity_status": "ACTIVE", "registration_status": "LAPSED"},
}  # anything else, e.g. ch:99999999, has no data


def fake_request_hash(source: int, supplier_id: str) -> str:
    return "req:%d:%s" % (source, supplier_id)


def fake_supplier_key(source: int, supplier_id: str) -> str:
    return "key:%d:%s" % (source, supplier_id)


class FakeChain:
    def __init__(self, now: int = 1_800_000_000, max_age: int = 300, tier_gap: int = 60, refund_grace: int = 120):
        self.t = now
        self.max_age, self.tier_gap, self.refund_grace = max_age, tier_gap, refund_grace
        self.orders: Dict[int, dict] = {}
        self.suppliers: Dict[str, dict] = {}
        self.used = set()
        self.sent: List[tuple] = []
        self.gas_gwei = 1.0
        self.address = "0xagent"

    # ---- setup and clock
    def add_order(self, source: int, supplier_id: str, rules: int, amounts: Iterable[int],
                  due_offsets: Iterable[int], approved: Iterable[int] = (), permit_ttl: int = 3600) -> int:
        amounts, dues = list(amounts), [self.t + d for d in due_offsets]
        oid = len(self.orders)
        key = fake_supplier_key(source, supplier_id)
        self.orders[oid] = dict(
            source=source, supplier_id=supplier_id, key=key, rules=rules, amounts=amounts, due=dues,
            approved=[i in set(approved) for i in range(len(amounts))], state=ACTIVE, paid_count=0,
            permit_until=0, permit_milestone=0, permit_evidence_at=0, last_check=0, held_at=0, last_failed=0,
            ttl=permit_ttl, paid=0)
        self.suppliers.setdefault(key, dict(streak=0, checks=0, failures=0, last_counted=0, last_check_at=0,
                                            last_base_failure=0, tier=0))
        return oid

    def approve(self, order_id: int, milestone: int) -> None:
        """What the buyer does with approveMilestone."""
        self.orders[order_id]["approved"][milestone] = True

    def advance(self, seconds: int) -> None:
        self.t += seconds

    def now(self) -> int:
        return self.t

    def gas_price_gwei(self) -> float:
        return self.gas_gwei

    # ---- reads
    def _remaining(self, o: dict) -> int:
        return 0 if o["state"] == CLOSED else sum(o["amounts"][o["paid_count"]:])

    def _permit_valid(self, o: dict) -> bool:
        return (o["state"] == ACTIVE and o["permit_until"] != 0 and o["permit_milestone"] == o["paid_count"]
                and self.t <= o["permit_until"])

    def _auto_refund_at(self, o: dict) -> int:
        if o["state"] == HELD:
            return o["held_at"] + self.refund_grace
        m = o["paid_count"]
        if o["state"] == ACTIVE and o["approved"][m] and not self._permit_valid(o):
            return o["due"][m] + self.refund_grace  # the no-data exit
        return 0

    def snapshot(self) -> Snapshot:
        orders = []
        for oid, o in self.orders.items():
            if o["state"] == CLOSED:
                continue
            m = o["paid_count"]
            orders.append(Order(
                id=oid, source=o["source"], supplier_id=o["supplier_id"], supplier_key=o["key"], rules=o["rules"],
                state=o["state"], remaining=self._remaining(o), permit_valid=self._permit_valid(o),
                permit_valid_until=o["permit_until"], next_due_date=o["due"][m], next_approved=o["approved"][m],
                auto_refund_at=self._auto_refund_at(o), tier=self.suppliers[o["key"]]["tier"],
                last_check=o["last_check"], last_failed_rules=o["last_failed"], permit_ttl=o["ttl"]))
        suppliers = {k: Supplier(key=k, tier=s["tier"], last_check_at=s["last_check_at"], clean_streak=s["streak"],
                                 last_base_failure_at=s["last_base_failure"])
                     for k, s in self.suppliers.items()}
        return Snapshot(self.t, orders, suppliers)

    # ---- writes (simulate = apply to a copy)
    def simulate(self, fn: str, *args) -> list:
        saved = copy.deepcopy((self.orders, self.suppliers, self.used))
        try:
            return self._apply(fn, args)
        finally:
            self.orders, self.suppliers, self.used = saved

    def send(self, fn: str, *args) -> str:
        self._apply(fn, args)
        self.sent.append((fn, args))
        return "0xfake%04d" % len(self.sent)

    def _apply(self, fn: str, args) -> list:
        oid = int(args[0])
        if oid not in self.orders:
            raise Reverted("BadOrder")
        o = self.orders[oid]
        if fn == "submitEvidence":
            return [self._submit(o, *args[1:])]
        if fn == "checkAndRelease":
            if not self._submit(o, *args[1:]):
                return [3]
            m = o["paid_count"]
            if not o["approved"][m]:
                return [1]
            if self.t < o["due"][m]:
                return [2]
            self._release(o)
            return [0]
        if fn == "release":
            self._release(o)
            return []
        if fn == "applySupplierFailure":
            if o["state"] != ACTIVE:
                raise Reverted("NotActive", detail="(%d)" % o["state"])
            if self.suppliers[o["key"]]["last_base_failure"] <= o["last_check"]:
                raise Reverted("NoNewerFailure")
            self._hold(o, FAIL_BASE)
            return []
        if fn == "refundRemaining":
            return self._refund(o)
        raise ValueError(fn)

    def _hold(self, o: dict, failed: int) -> None:
        o["state"], o["held_at"], o["permit_until"], o["last_failed"] = HELD, self.t, 0, failed

    def _submit(self, o: dict, request_hash: str, timestamp, data: str, signature: str) -> bool:
        ts = int(timestamp)
        if o["state"] != ACTIVE:
            raise Reverted("NotActive", detail="(%d)" % o["state"])
        if request_hash != fake_request_hash(o["source"], o["supplier_id"]):
            raise Reverted("WrongRequest")
        if ts > self.t + 60:
            raise Reverted("FutureResponse")
        if self.t - ts > self.max_age:
            raise Reverted("StaleResponse")
        digest = (request_hash, ts, data)
        if digest in self.used:
            raise Reverted("Replayed")
        if ts <= o["last_check"]:
            raise Reverted("NotNewer")
        if signature != "0xsig":
            raise Reverted("WrongSigner")
        failed = evaluate(o["source"], o["rules"], bytes.fromhex(data[2:]).decode())
        sup = self.suppliers[o["key"]]
        if failed == 0 and ts <= sup["last_base_failure"]:
            raise Reverted("SupplierFailed", detail="(%d)" % sup["last_base_failure"])
        self.used.add(digest)
        o["last_check"], o["last_failed"] = ts, failed
        if ts > sup["last_check_at"]:  # the history only moves forward and counts the base status only
            sup["checks"] += 1
            sup["last_check_at"] = ts
            if failed & FAIL_BASE:
                sup["failures"] += 1
                sup["streak"] = 0
                sup["last_base_failure"] = ts
            elif sup["last_counted"] == 0 or ts >= sup["last_counted"] + self.tier_gap:
                sup["streak"] += 1
                sup["last_counted"] = ts
            sup["tier"] = 2 if sup["streak"] >= PREMIUM_STREAK else 1 if sup["streak"] >= TRUSTED_STREAK else 0
        if failed:
            self._hold(o, failed)
            return False
        o["permit_until"] = ts + o["ttl"]  # never extended by the tier
        o["permit_milestone"] = o["paid_count"]
        o["permit_evidence_at"] = ts
        return True

    def _release(self, o: dict) -> None:
        m = o["paid_count"]
        if o["state"] != ACTIVE:
            raise Reverted("NotActive", detail="(%d)" % o["state"])
        if o["permit_until"] == 0 or o["permit_milestone"] != m:
            raise Reverted("NoValidPermit", detail="(%d)" % m)
        if self.t > o["permit_until"]:
            raise Reverted("PermitExpired")
        if not o["approved"][m]:
            raise Reverted("NotApproved", detail="(%d)" % m)
        if self.t < o["due"][m]:
            raise Reverted("NotDue")
        failed_at = self.suppliers[o["key"]]["last_base_failure"]
        if o["permit_evidence_at"] <= failed_at:
            raise Reverted("SupplierFailed", detail="(%d)" % failed_at)
        o["permit_until"] = 0
        o["paid"] += o["amounts"][m]
        o["paid_count"] += 1
        if o["paid_count"] == len(o["amounts"]):
            o["state"] = CLOSED

    def _refund(self, o: dict) -> list:
        """The agent is never the buyer, so it can only use the timed paths."""
        if o["state"] == HELD:
            if self.t < o["held_at"] + self.refund_grace:
                raise Reverted("RefundNotYet")
        elif o["state"] == ACTIVE:
            m = o["paid_count"]
            if not o["approved"][m]:
                raise Reverted("NotApproved", detail="(%d)" % m)
            if self._permit_valid(o):
                raise Reverted("NotRefundable")
            if self.t < o["due"][m] + self.refund_grace:
                raise Reverted("RefundNotYet")
        else:
            raise Reverted("NotRefundable")
        o["state"] = CLOSED
        return []


class FakeFetcher:
    def __init__(self, clock: Callable[[], int], registry: Optional[dict] = None, price_usd: float = 0.01):
        self.clock = clock
        self.registry = dict(LOCAL_REGISTRY if registry is None else registry)
        self.price_usd = price_usd
        self.calls: List[str] = []
        self.fail: Dict[str, Exception] = {}  # "ch:01234567" -> exception to raise instead

    def fetch(self, source: str, supplier_id: str) -> Evidence:
        name = "%s:%s" % (source, supplier_id)
        self.calls.append(name)
        if name in self.fail:
            raise self.fail[name]
        if name not in self.registry:
            raise NoData("no signed registry data for %s" % name)
        raw = json.dumps(self.registry[name], separators=(",", ":"))
        return Evidence(source=source, supplier_id=supplier_id,
                        request_hash=fake_request_hash(SOURCE_IDS[source], supplier_id), timestamp=self.clock(),
                        data="0x" + raw.encode().hex(), signature="0xsig", raw=raw, price_usd=self.price_usd)


def local_world(tier_gap: int = 60, refund_grace: int = 120):
    """The local test chain of §4.8: two registries, clean and failing suppliers, a shared supplier, no data."""
    chain = FakeChain(tier_gap=tier_gap, refund_grace=refund_grace)
    chain.add_order(0, "01234567", 0x06, [500, 1000, 1500], [60, 600, 1200], approved=[0, 1])
    chain.add_order(0, "07654321", 0x06, [1000, 2000], [60, 600], approved=[0])
    chain.add_order(1, "TESTLEI0000000000000", 0x08, [500, 1000], [60, 600], approved=[0, 1])
    chain.add_order(1, "TESTLEI0000000000001", 0x08, [500, 500], [60, 600], approved=[0])
    chain.add_order(0, "07654321", 0x06, [500, 500], [60, 600], approved=[0])  # same supplier as order 1
    chain.add_order(0, "99999999", 0x06, [500, 500], [60, 600], approved=[0])  # no data
    return chain, FakeFetcher(chain.now)
