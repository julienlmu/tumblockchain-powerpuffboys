"""One agent tick: read the chain, plan, act, log. Failure handling per docs/SUPPLIERPULSE_PLUS.md §6.3.

Every write is simulated first (eth_call) and only sent if the simulation passes,
so a refused record costs no gas. One failing action never stops the others.
"""
from __future__ import annotations

from typing import Optional

import policy
from chain import ChainError, Reverted
from config import Config
from evidence import FetchFailed, PaymentFailed, VerificationFailed
from journal import Journal
from ledger import Ledger
from model import ACTIVE, OUTCOME_NAMES, SOURCES, TIER_NAMES, Action, Evidence, Order, Snapshot, evaluate, failed_labels

RETRY_REVERTS = {"StaleResponse", "FutureResponse"}
DROP_REVERTS = {"Replayed", "NotNewer"}
QUARANTINE_REVERTS = {"WrongRequest", "WrongSigner", "InvalidSigner", "InvalidSignatureS",
                      "InvalidSignatureV", "InvalidSignatureLength"}
EXPECTED_REVERTS = {"NotActive", "NotDue", "NotApproved", "NoValidPermit", "PermitExpired", "RefundNotYet", "NotHeld",
                    "NotRefundable", "SupplierFailed", "NoNewerFailure"}
WRITE_ONLY = {"stop": "applySupplierFailure", "refund": "refundRemaining", "release": "release"}


class Executor:
    def __init__(self, chain, fetcher, ledger: Ledger, journal: Journal, cfg: Config):
        self.chain, self.fetcher, self.ledger, self.journal, self.cfg = chain, fetcher, ledger, journal, cfg

    def tick(self) -> Optional[policy.Plan]:
        cycle = self.ledger.next_cycle()
        try:
            snap = self.chain.snapshot()
        except (ChainError, Reverted) as e:
            self.journal.write(cycle=cycle, action="read", outcome="error", error=str(e)[:300])
            self.ledger.save()
            return None
        self._log_tier_changes(cycle, snap)
        plan = policy.plan(snap, self.ledger, self.cfg)
        for action, reason in plan.skipped:
            self.journal.write(cycle=cycle, action=action.kind, orderId=action.order_id,
                               supplier=action.supplier, outcome="skipped", reason=reason)
        if plan.actions and self._gas_ok(cycle):
            for action in plan.actions:
                try:
                    self._execute(action, snap, cycle)
                except Exception as e:  # one broken action must not stop the loop
                    self.journal.write(cycle=cycle, action=action.kind, orderId=action.order_id,
                                       supplier=action.supplier, outcome="error", error=repr(e)[:300])
        elif not plan.actions:
            self.journal.write(cycle=cycle, action="idle", outcome="nothing due",
                               orders=len(snap.orders), spentTodayUsd=self.ledger.spent(snap.now))
        self.ledger.save()
        return plan

    # ---- helpers
    def _gas_ok(self, cycle: int) -> bool:
        try:
            gwei = self.chain.gas_price_gwei()
        except ChainError as e:
            self.journal.write(cycle=cycle, action="gas", outcome="error", error=str(e)[:300])
            return False
        if gwei > self.cfg.max_gas_price_gwei:
            self.journal.write(cycle=cycle, action="gas", outcome="skipped",
                               reason="gas price %.1f gwei above %.1f" % (gwei, self.cfg.max_gas_price_gwei))
            return False
        return True

    def _log_tier_changes(self, cycle: int, snap: Snapshot) -> None:
        names = {o.supplier_key: o.supplier for o in snap.orders}
        for key, sup in snap.suppliers.items():
            old = self.ledger.tier_change(key, sup.tier)
            if old is not None:
                self.journal.write(cycle=cycle, action="tier", supplier=names.get(key, key),
                                   outcome="%s -> %s" % (TIER_NAMES.get(old), TIER_NAMES.get(sup.tier)),
                                   cleanStreak=sup.clean_streak)

    def _execute(self, action: Action, snap: Snapshot, cycle: int) -> None:
        order = snap.order(action.order_id)
        base = dict(cycle=cycle, reason=action.reason, orderId=order.id, supplier=order.supplier,
                    tier=TIER_NAMES.get(order.tier))
        if action.kind in WRITE_ONLY:
            fn = WRITE_ONLY[action.kind]
            try:
                self.chain.simulate(fn, order.id)
                tx = self.chain.send(fn, order.id)
            except Reverted as r:
                self.journal.write(action=fn, outcome="expected" if r.name in EXPECTED_REVERTS else "reverted",
                                   error=str(r), **base)
                return
            except ChainError as e:
                self.journal.write(action=fn, outcome="error", error=str(e)[:300], **base)
                return
            outcome = {"applySupplierFailure": "Held (supplier-wide stop)", "release": "Paid",
                       "refundRemaining": "Refunded"}[fn]
            no_data_exit = fn == "refundRemaining" and order.state == ACTIVE
            self.journal.write(action=fn, outcome=outcome, tx=tx, noDataExit=no_data_exit or None, **base)
            return

        evidence = self._fetch(order, snap.now, base)
        if evidence is None:
            return
        fn = "checkAndRelease" if action.kind == "due_check" and snap.now >= order.next_due_date else "submitEvidence"
        args = [order.id] + evidence.args
        entry = dict(base, action=fn, costUsd=evidence.price_usd, spentTodayUsd=self.ledger.spent(snap.now),
                     paymentTx=evidence.payment_tx)
        try:
            result = self.chain.simulate(fn, *args)
            tx = self.chain.send(fn, *args)
        except Reverted as r:
            self._handle_revert(r, order, snap.now, entry)
            return
        except ChainError as e:
            self.journal.write(outcome="error", error=str(e)[:300], **entry)
            return
        self.ledger.clear_failures(order.id)
        outcome = self._outcome(fn, result, getattr(self.chain, "outcome_names", OUTCOME_NAMES))
        labels = None
        if outcome in ("Held", "held") and evidence.raw:
            labels = failed_labels(order.source, evaluate(order.source, order.rules, evidence.raw))
        self.journal.write(outcome=outcome, tx=tx, labels=labels, **entry)

    def _fetch(self, order: Order, now: int, base: dict) -> Optional[Evidence]:
        try:
            evidence = self.fetcher.fetch(SOURCES[order.source], order.supplier_id)
        except PaymentFailed as e:
            self.ledger.pause_paid(now, self.cfg.payment_pause_seconds)
            self.journal.write(action="fetch", outcome="alert",
                               error="payment failed, paid fetches paused for %ss: %s" % (self.cfg.payment_pause_seconds, e),
                               **base)
            return None
        except FetchFailed as e:
            count, exhausted = self.ledger.record_failure(order.id, now, self.cfg.max_fetch_attempts,
                                                          self.cfg.exhausted_wait_seconds)
            outcome = "alert" if exhausted or isinstance(e, VerificationFailed) else e.kind
            self.journal.write(action="fetch", outcome=outcome, attempt=count, error=str(e), **base)
            return None
        self.ledger.add_spend(now, evidence.price_usd)
        return evidence

    def _handle_revert(self, r: Reverted, order: Order, now: int, entry: dict) -> None:
        if r.name in RETRY_REVERTS:
            _, exhausted = self.ledger.record_failure(order.id, now, self.cfg.max_fetch_attempts,
                                                      self.cfg.exhausted_wait_seconds)
            outcome = "alert" if exhausted else "retry"
        elif r.name in DROP_REVERTS:
            outcome = "dropped"
        elif r.name in QUARANTINE_REVERTS:
            self.ledger.quarantine(order.id, str(r))
            outcome = "quarantined"
        elif r.name in EXPECTED_REVERTS:
            outcome = "expected"
        else:
            self.ledger.record_failure(order.id, now, self.cfg.max_fetch_attempts, self.cfg.exhausted_wait_seconds)
            outcome = "alert"
        self.journal.write(outcome=outcome, error=str(r), **entry)

    @staticmethod
    def _outcome(fn: str, result, names: dict) -> str:
        value = result[0] if isinstance(result, list) and result else result
        if fn == "checkAndRelease":
            return names.get(int(str(value).split()[0]), str(value))
        return "clean" if value is True or str(value).lower() == "true" else "held"
