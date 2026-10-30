"""The agent's decisions (policy.plan), case by case. Run: cd api3/agent && python3 -m unittest discover -s tests"""
import dataclasses
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import config  # noqa: E402
from ledger import Ledger  # noqa: E402
from model import ACTIVE, HELD, Order, Snapshot, Supplier  # noqa: E402
from policy import plan  # noqa: E402

NOW = 1_800_000_000


def cfg(**overrides):
    return dataclasses.replace(config.Config(profile="demo", contract="0xc", rpc_urls=["http://rpc"]), **overrides)


def order(oid=0, **kw):
    base = dict(id=oid, source=0, supplier_id="0000000%d" % oid, supplier_key="k%d" % oid, rules=6, state=ACTIVE,
                remaining=1000, permit_valid=False, permit_valid_until=0, next_due_date=NOW + 5000,
                next_approved=True, auto_refund_at=0, tier=0)
    base.update(kw)
    if "supplier_key" in kw:  # the same key always means the same supplier, as on chain
        base["supplier_id"] = "sup-" + kw["supplier_key"]
    return Order(**base)


def snapshot(*orders, last_check_at=NOW, tiers=None):
    """Suppliers checked just now (no monitoring due) unless last_check_at says otherwise."""
    tiers = tiers or {}
    suppliers = {o.supplier_key: Supplier(o.supplier_key, tiers.get(o.supplier_key, 0), last_check_at) for o in orders}
    return Snapshot(NOW, list(orders), suppliers)


class PolicyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ledger = Ledger(pathlib.Path(self.tmp.name) / "state.json")

    def tearDown(self):
        self.tmp.cleanup()

    def kinds(self, p):
        return [(a.kind, a.order_id) for a in p.actions]

    def test_due_check_inside_the_lead_time(self):
        p = plan(snapshot(order(next_due_date=NOW + 200)), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("due_check", 0)])

    def test_nothing_outside_the_lead_time(self):
        p = plan(snapshot(order(next_due_date=NOW + 1000)), self.ledger, cfg())
        self.assertEqual(p.actions, [])

    def test_permit_that_covers_the_due_date_needs_no_check(self):
        o = order(next_due_date=NOW + 200, permit_valid=True, permit_valid_until=NOW + 3000)
        self.assertEqual(plan(snapshot(o), self.ledger, cfg()).actions, [])

    def test_permit_expiring_before_the_due_date_is_renewed(self):
        o = order(next_due_date=NOW + 200, permit_valid=True, permit_valid_until=NOW + 100)
        self.assertEqual(self.kinds(plan(snapshot(o), self.ledger, cfg())), [("due_check", 0)])

    def test_release_when_due_with_permit_and_approval(self):
        o = order(next_due_date=NOW - 1, permit_valid=True, permit_valid_until=NOW + 100)
        self.assertEqual(self.kinds(plan(snapshot(o), self.ledger, cfg())), [("release", 0)])

    def test_no_paid_check_while_a_due_milestone_waits_for_the_buyer(self):
        o = order(next_due_date=NOW - 10, next_approved=False)
        self.assertEqual(plan(snapshot(o), self.ledger, cfg()).actions, [])

    def test_check_ahead_of_the_due_date_even_without_approval(self):
        o = order(next_due_date=NOW + 100, next_approved=False)
        self.assertEqual(self.kinds(plan(snapshot(o), self.ledger, cfg())), [("due_check", 0)])

    def test_refund_only_after_the_grace_period(self):
        held = order(state=HELD, auto_refund_at=NOW)
        self.assertEqual(self.kinds(plan(snapshot(held), self.ledger, cfg())), [("refund", 0)])
        early = order(state=HELD, auto_refund_at=NOW + 1)
        self.assertEqual(plan(snapshot(early), self.ledger, cfg()).actions, [])

    def test_monitor_interval_depends_on_the_tier(self):
        o = order()
        standard = plan(snapshot(o, last_check_at=NOW - 700), self.ledger, cfg())
        self.assertEqual(self.kinds(standard), [("monitor", 0)])
        trusted = plan(snapshot(o, last_check_at=NOW - 700, tiers={"k0": 1}), self.ledger, cfg())
        self.assertEqual(trusted.actions, [])
        premium = plan(snapshot(o, last_check_at=NOW - 3601, tiers={"k0": 2}), self.ledger, cfg())
        self.assertEqual(self.kinds(premium), [("monitor", 0)])

    def test_a_never_checked_supplier_is_monitored(self):
        self.assertEqual(self.kinds(plan(snapshot(order(), last_check_at=0), self.ledger, cfg())), [("monitor", 0)])

    def test_monitor_targets_the_order_with_the_nearest_due_date(self):
        far = order(0, supplier_key="k", next_due_date=NOW + 9000)
        near = order(1, supplier_key="k", next_due_date=NOW + 4000)
        p = plan(snapshot(far, near, last_check_at=0), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("monitor", 1)])

    def test_budget_reserve_blocks_monitoring_but_keeps_due_checks(self):
        self.ledger.add_spend(NOW, 0.85)
        due = order(0, next_due_date=NOW + 100)
        idle = order(1, next_due_date=NOW + 9000)
        p = plan(snapshot(due, idle, last_check_at=0), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("due_check", 0)])
        self.assertIn(("monitor", "daily budget"), [(a.kind, r) for a, r in p.skipped])

    def test_exhausted_budget_blocks_due_checks_too(self):
        self.ledger.add_spend(NOW, 1.00)
        p = plan(snapshot(order(next_due_date=NOW + 100)), self.ledger, cfg())
        self.assertEqual(p.actions, [])
        self.assertEqual(p.skipped[0][1], "daily budget")

    def test_free_local_fetches_ignore_the_budget(self):
        self.ledger.add_spend(NOW, 5.00)
        p = plan(snapshot(order(next_due_date=NOW + 100)), self.ledger, cfg(fetch_cost_usd=0.0))
        self.assertEqual(self.kinds(p), [("due_check", 0)])

    def test_backoff_after_a_failed_fetch(self):
        self.ledger.record_failure(0, NOW, max_attempts=3, exhausted_wait=1800)
        p = plan(snapshot(order(next_due_date=NOW + 100)), self.ledger, cfg())
        self.assertEqual(p.actions, [])
        self.assertEqual(p.skipped[0][1], "retry backoff")
        later = Snapshot(NOW + 30, [order(next_due_date=NOW + 100)], {"k0": Supplier("k0", 0, NOW)})
        self.assertEqual(self.kinds(plan(later, self.ledger, cfg())), [("due_check", 0)])

    def test_quarantined_orders_are_left_alone(self):
        self.ledger.quarantine(0, "WrongRequest")
        p = plan(snapshot(order(next_due_date=NOW + 100), last_check_at=0), self.ledger, cfg())
        self.assertEqual(p.actions, [])

    def test_paused_paid_fetches_are_skipped(self):
        self.ledger.pause_paid(NOW, 900)
        p = plan(snapshot(order(next_due_date=NOW + 100)), self.ledger, cfg())
        self.assertEqual(p.skipped[0][1], "paid fetches paused")

    def test_one_fetch_per_supplier_per_tick(self):
        a = order(0, supplier_key="k", next_due_date=NOW + 100)
        b = order(1, supplier_key="k", next_due_date=NOW + 200)
        p = plan(snapshot(a, b), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("due_check", 0)])
        self.assertEqual(p.skipped[0][1], "supplier already checked this tick")

    def test_fetch_cap_per_tick(self):
        orders = [order(i, next_due_date=NOW + 100 + i) for i in range(4)]
        p = plan(snapshot(*orders), self.ledger, cfg(max_fetches_per_tick=3))
        self.assertEqual(len(p.actions), 3)
        self.assertEqual([r for _, r in p.skipped], ["fetch cap per tick"])

    def test_a_supplier_failure_on_another_order_holds_this_one_without_a_fetch(self):
        o = order(next_due_date=NOW + 100, last_check=NOW - 50)
        snap = Snapshot(NOW, [o], {"k0": Supplier("k0", 0, NOW - 10, last_base_failure_at=NOW - 10)})
        p = plan(snap, self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("stop", 0)])  # no due check: the stop needs no data

    def test_an_older_failure_does_not_stop_a_newer_check(self):
        o = order(next_due_date=NOW + 9000, last_check=NOW - 5)
        snap = Snapshot(NOW, [o], {"k0": Supplier("k0", 0, NOW - 5, last_base_failure_at=NOW - 60)})
        self.assertEqual(plan(snap, self.ledger, cfg()).actions, [])

    def test_no_data_exit_refunds_after_a_failed_last_try(self):
        o = order(next_due_date=NOW - 200, auto_refund_at=NOW - 1)
        p = plan(snapshot(o), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("due_check", 0)])  # the data may be back: try once more first
        self.assertEqual(p.actions[0].reason, "last try before the no-data refund")
        self.ledger.record_failure(0, NOW, max_attempts=3, exhausted_wait=1800)
        p = plan(snapshot(o), self.ledger, cfg())
        self.assertEqual(self.kinds(p), [("refund", 0)])
        self.assertEqual(p.actions[0].reason, "no verified data since the due date")

    def test_the_last_try_ignores_a_backoff_from_before_the_due_date(self):
        self.ledger.record_failure(0, NOW - 300, max_attempts=1, exhausted_wait=1800)  # exhausted until NOW + 1500
        o = order(next_due_date=NOW - 200, auto_refund_at=NOW - 1)
        self.assertEqual(self.kinds(plan(snapshot(o), self.ledger, cfg())), [("due_check", 0)])

    def test_a_failed_payment_is_no_reason_for_the_no_data_refund(self):
        self.ledger.pause_paid(NOW, 900)  # the agent could not pay: the data may well exist
        o = order(next_due_date=NOW - 200, auto_refund_at=NOW - 1)
        p = plan(snapshot(o), self.ledger, cfg())
        self.assertEqual(p.actions, [])
        self.assertEqual(p.skipped[0][1], "paid fetches paused")

    def test_a_short_permit_ttl_moves_the_check_closer_to_the_due_date(self):
        # lead time 300 s, but a permit lives only 120 s: a check 200 s early would expire before the due date
        early = order(next_due_date=NOW + 200, permit_ttl=120)
        self.assertEqual(plan(snapshot(early), self.ledger, cfg()).actions, [])
        close = order(next_due_date=NOW + 60, permit_ttl=120)
        self.assertEqual(self.kinds(plan(snapshot(close), self.ledger, cfg())), [("due_check", 0)])

    def test_a_long_permit_ttl_keeps_the_lead_time(self):
        o = order(next_due_date=NOW + 290, permit_ttl=3600)
        self.assertEqual(self.kinds(plan(snapshot(o), self.ledger, cfg())), [("due_check", 0)])

    def test_no_monitoring_while_a_due_milestone_waits_for_the_buyer(self):
        waiting = order(next_due_date=NOW - 10, next_approved=False)
        self.assertEqual(plan(snapshot(waiting, last_check_at=0), self.ledger, cfg()).actions, [])

    def test_a_due_check_in_backoff_is_not_skipped_again_as_monitoring(self):
        # seen in the real C2 run: every tick logged order 5 twice, as due check and as monitor
        self.ledger.record_failure(0, NOW, max_attempts=3, exhausted_wait=1800)
        p = plan(snapshot(order(next_due_date=NOW + 100), last_check_at=0), self.ledger, cfg())
        self.assertEqual([(a.kind, r) for a, r in p.skipped], [("due_check", "retry backoff")])

    def test_no_monitoring_of_an_order_refunded_this_tick(self):
        self.ledger.record_failure(0, NOW - 100, max_attempts=3, exhausted_wait=1800)  # backoff over at NOW - 70
        o = order(next_due_date=NOW - 200, auto_refund_at=NOW - 1)
        p = plan(snapshot(o, last_check_at=0), self.ledger, cfg())  # a never-verified supplier is due for monitoring
        self.assertEqual(self.kinds(p), [("refund", 0)])  # no paid fetch for an order that closes this tick

    def test_quarantine_blocks_release_and_refund(self):
        pay = order(0, next_due_date=NOW - 1, permit_valid=True, permit_valid_until=NOW + 100)
        held = order(1, state=HELD, auto_refund_at=NOW)
        self.ledger.quarantine(0, "WrongSigner")
        self.ledger.quarantine(1, "WrongRequest")
        self.assertEqual(plan(snapshot(pay, held), self.ledger, cfg()).actions, [])

    def test_refunds_and_releases_come_before_fetches(self):
        held = order(0, state=HELD, auto_refund_at=NOW)
        due = order(1, next_due_date=NOW + 100)
        pay = order(2, next_due_date=NOW - 1, permit_valid=True, permit_valid_until=NOW + 50)
        p = plan(snapshot(due, pay, held), self.ledger, cfg())
        self.assertEqual([a.kind for a in p.actions], ["release", "refund", "due_check"])


if __name__ == "__main__":
    unittest.main()
