"""The agent's decisions, as a pure function of chain state, ledger and config.

plan() returns what to do this tick, in priority order (docs/SUPPLIERPULSE_PLUS.md §6.3):
  P0 stop     the supplier's register status failed on another order: hold this order too (no fetch)
  P1 refund   a held order after its grace period, or the no-data exit: return the money to the buyer
  P2 release  a due milestone with a valid permit and the buyer's approval: pay it
  P3 due      a milestone due within the lead time without a permit that covers it: fetch and submit
  P4 monitor  a supplier not checked for its tier's interval: fetch and submit to its nearest order
Fetches respect the daily budget (P4 keeps a reserve for P3), a cap per tick, one fetch per
supplier per tick, retry backoff and quarantine. Nothing here does I/O.
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


def needs_due_check(o: Order, now: int, cfg: Config) -> bool:
    if o.state != ACTIVE or not o.next_due_date:
        return False
    if now < o.next_due_date - cfg.due_lead_seconds:
        return False
    if o.permit_valid and o.permit_valid_until >= max(now, o.next_due_date):
        return False  # the current permit already covers the due date
    if not o.next_approved and now >= o.next_due_date:
        return False  # due, but the buyer has not approved: no point paying for a check
    return True


def plan(snap: Snapshot, ledger: Ledger, cfg: Config) -> Plan:
    now = snap.now
    out = Plan()
    due: List[Action] = []
    for o in snap.orders:
        sup = snap.suppliers.get(o.supplier_key)
        failed_at = sup.last_base_failure_at if sup else 0
        if o.state == ACTIVE and failed_at > o.last_check and not ledger.is_quarantined(o.id):
            out.actions.append(Action("stop", o.id, o.supplier, "supplier failed on another order"))
        elif o.auto_refund_at and now >= o.auto_refund_at and o.remaining > 0:
            reason = "grace period over" if o.state == HELD else "no verified data since the due date"
            out.actions.append(Action("refund", o.id, o.supplier, reason))
        elif o.state == ACTIVE and o.next_due_date and o.permit_valid and o.next_approved and now >= o.next_due_date:
            out.actions.append(Action("release", o.id, o.supplier, "milestone due"))
        elif needs_due_check(o, now, cfg) and not ledger.is_quarantined(o.id):
            action = Action("due_check", o.id, o.supplier, "milestone due soon", cfg.fetch_cost_usd)
            if ledger.backoff_ok(o.id, now):
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
    due_suppliers = {a.supplier for a in due}  # their due check covers monitoring too, run or not

    for key, sup in sorted(snap.suppliers.items(), key=lambda kv: (kv[1].last_check_at, kv[0])):
        open_orders = [o for o in snap.orders
                       if o.supplier_key == key and o.state == ACTIVE and not ledger.is_quarantined(o.id)]
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
