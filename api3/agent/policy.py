"""The agent's decisions, as a pure function of chain state, ledger and config.

plan() returns what to do this tick, in priority order (docs/SUPPLIERPULSE_PLUS.md §6.3):
  P0 stop     the supplier's register status failed on another order: hold this order too (no fetch)
  P1 refund   a held order after its grace period, or the no-data exit once the agent's own try after
              the due date failed (until then P3 tries once more, ignoring the retry backoff)
  P2 release  a due milestone with a valid permit and the buyer's approval: pay it
  P3 due      a milestone due within the lead time without a permit that covers it: fetch and submit
  P4 monitor  a supplier not checked for its tier's interval: fetch and submit to its nearest order
Fetches respect the daily budget (P4 keeps a reserve for P3), a cap per tick, one fetch per
supplier per tick, retry backoff and quarantine. A quarantined order gets no action at all, and no
paid check runs for a milestone that is due but waits for the buyer's approval. Nothing here does I/O.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Tuple

from config import Config
from ledger import Ledger
from model import ACTIVE, HELD, Action, Order, Snapshot


@dataclass
class Plan:
    actions: List[Action] = field(default_factory=list)
    skipped: List[Tuple[Action, str]] = field(default_factory=list)


PERMIT_MARGIN_S = 60  # check this long before the permit would stop covering the due date


def check_window_start(o: Order, cfg: Config) -> int:
    """Earliest time for the check before a due date: within the lead time, and late enough that the
    permit (valid for permitTtl from the evidence time) still covers the due date, so one paid check is enough."""
    lead = cfg.due_lead_seconds
    if o.permit_ttl:
        lead = min(lead, max(o.permit_ttl - PERMIT_MARGIN_S, 0))
    return o.next_due_date - lead


def waiting_for_buyer(o: Order, now: int) -> bool:
    return bool(o.next_due_date) and now >= o.next_due_date and not o.next_approved


def needs_due_check(o: Order, now: int, cfg: Config) -> bool:
    if o.state != ACTIVE or not o.next_due_date:
        return False
    if now < check_window_start(o, cfg):
        return False
    if o.permit_valid and o.permit_valid_until >= max(now, o.next_due_date):
        return False  # the current permit already covers the due date
    if waiting_for_buyer(o, now):
        return False  # due, but the buyer has not approved: no point paying for a check
    return True


def plan(snap: Snapshot, ledger: Ledger, cfg: Config) -> Plan:
    now = snap.now
    out = Plan()
    due: List[Action] = []
    for o in snap.orders:
        if ledger.is_quarantined(o.id):
            continue  # config mismatch or tampering: a human looks first
        sup = snap.suppliers.get(o.supplier_key)
        failed_at = sup.last_base_failure_at if sup else 0
        refund_due = bool(o.auto_refund_at) and now >= o.auto_refund_at and o.remaining > 0
        if o.state == ACTIVE and failed_at > o.last_check:
            out.actions.append(Action("stop", o.id, o.supplier, "supplier failed on another order"))
        elif refund_due and o.state == HELD:
            out.actions.append(Action("refund", o.id, o.supplier, "grace period over"))
        elif refund_due and ledger.failed_since(o.id, o.next_due_date):
            out.actions.append(Action("refund", o.id, o.supplier, "no verified data since the due date"))
        elif o.state == ACTIVE and o.next_due_date and o.permit_valid and o.next_approved and now >= o.next_due_date:
            out.actions.append(Action("release", o.id, o.supplier, "milestone due"))
        elif needs_due_check(o, now, cfg):
            reason = "last try before the no-data refund" if refund_due else "milestone due soon"
            action = Action("due_check", o.id, o.supplier, reason, cfg.fetch_cost_usd)
            if refund_due or ledger.backoff_ok(o.id, now):  # the last try does not wait for the backoff
                due.append(action)
            else:
                out.skipped.append((action, "retry backoff"))

    spent = ledger.spent(now)
    paused = ledger.paid_paused(now)
    fetched_suppliers = set()

    def try_fetch(action: Action, budget: float) -> bool:
        nonlocal spent
        if action.supplier in fetched_suppliers:
            out.skipped.append((action, "supplier already checked this tick"))
        elif len(fetched_suppliers) >= cfg.max_fetches_per_tick:
            out.skipped.append((action, "fetch cap per tick"))
        elif action.cost_usd > 0 and paused:
            out.skipped.append((action, "paid fetches paused"))
        elif action.cost_usd > 0 and spent + action.cost_usd > budget + 1e-9:
            out.skipped.append((action, "daily budget"))
        else:
            out.actions.append(action)
            fetched_suppliers.add(action.supplier)
            spent += action.cost_usd
            return True
        return False

    order_by_id = {o.id: o for o in snap.orders}
    for action in sorted(due, key=lambda a: (order_by_id[a.order_id].next_due_date, a.order_id)):
        try_fetch(action, cfg.daily_budget_usd)
    decided = list(out.actions) + [a for a, _ in out.skipped]  # P0-P3, run or skipped: P4 leaves these alone
    decided_orders = {a.order_id for a in decided}
    due_suppliers = {a.supplier for a in decided if a.kind == "due_check"}  # their due check covers monitoring

    for key, sup in sorted(snap.suppliers.items(), key=lambda kv: (kv[1].last_check_at, kv[0])):
        open_orders = [o for o in snap.orders
                       if o.supplier_key == key and o.state == ACTIVE and not ledger.is_quarantined(o.id)
                       and not waiting_for_buyer(o, now) and o.id not in decided_orders]
        if not open_orders:
            continue
        if sup.last_check_at and now - sup.last_check_at < cfg.monitor_interval(sup.tier):
            continue
        target = min(open_orders, key=lambda o: (o.next_due_date or float("inf"), o.id))
        action = Action("monitor", target.id, target.supplier, "re-check by tier", cfg.fetch_cost_usd)
        if action.supplier in fetched_suppliers or action.supplier in due_suppliers:
            continue
        if not ledger.backoff_ok(target.id, now):
            out.skipped.append((action, "retry backoff"))
            continue
        try_fetch(action, cfg.daily_budget_usd - cfg.due_reserve_usd)
    return out
