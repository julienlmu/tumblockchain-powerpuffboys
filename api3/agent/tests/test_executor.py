"""Ticks against the in-memory contract (fakes.py): failure handling and a full simulated run."""
import dataclasses
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import config  # noqa: E402
import fakes  # noqa: E402
from evidence import NoData, PaymentFailed  # noqa: E402
from executor import Executor  # noqa: E402
from journal import Journal  # noqa: E402
from ledger import Ledger  # noqa: E402
from model import ACTIVE, CLOSED, HELD  # noqa: E402


class ExecutorTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        state = pathlib.Path(self.tmp.name)
        self.cfg = dataclasses.replace(config.Config(profile="demo", contract="0xc", rpc_urls=["x"]), state_dir=state)
        self.chain, self.fetcher = fakes.local_world()
        self.ledger = Ledger(state / "state.json")
        self.journal = Journal(state / "cycles.jsonl", echo=None)
        self.agent = Executor(self.chain, self.fetcher, self.ledger, self.journal, self.cfg)

    def tearDown(self):
        self.tmp.cleanup()

    def entries(self, **match):
        return [e for e in self.journal.read() if all(e.get(k) == v for k, v in match.items())]

    def run_ticks(self, n):
        for _ in range(n):
            self.agent.tick()
            self.chain.advance(self.cfg.tick_seconds)

    def test_first_tick_checks_due_suppliers_and_holds_the_failing_one(self):
        self.agent.tick()
        held = self.entries(orderId=1, action="submitEvidence")[0]
        self.assertEqual(held["outcome"], "held")
        self.assertEqual(held["labels"], ["registry status not active", "accounts overdue"])
        self.assertEqual(self.entries(orderId=0, action="submitEvidence")[0]["outcome"], "clean")
        self.assertAlmostEqual(self.ledger.spent(self.chain.now()), 0.03)  # 3 fetches: the cap per tick

    def test_full_simulated_run(self):
        self.run_ticks(45)  # 22.5 simulated minutes: every milestone of the local test chain is due
        states = {oid: o["state"] for oid, o in self.chain.orders.items()}
        # order 0's last milestone is not approved by the buyer (§4.8), so it waits; all others are settled
        self.assertEqual(states, {0: ACTIVE, 1: CLOSED, 2: CLOSED, 3: CLOSED, 4: CLOSED, 5: CLOSED})
        # order 4 shares order 1's supplier: held by the supplier-wide stop, with a single fetch for both
        self.assertEqual(self.entries(orderId=4, action="applySupplierFailure")[0]["outcome"], "Held (supplier-wide stop)")
        self.assertEqual(self.fetcher.calls.count("ch:07654321"), 1)
        self.assertEqual(self.chain.orders[4]["paid"], 0)
        # order 5 never had data: the money went back through the no-data exit
        refund5 = self.entries(orderId=5, action="refundRemaining")[0]
        self.assertTrue(refund5["noDataExit"])
        self.assertEqual(self.chain.orders[0]["paid"], 1500)
        self.assertEqual(self.chain.orders[1]["paid"], 0)  # held at the first check, then refunded
        self.assertEqual(len(self.entries(action="refundRemaining", outcome="Refunded")), 4)
        self.assertTrue(self.entries(action="tier"))
        self.assertLessEqual(self.ledger.spent(self.chain.now()), self.cfg.daily_budget_usd)
        # alerts only for the supplier without data (order 5), and no paid fetch for it once it is refunded
        # (the refund tick used to monitor it too: a third, wasted fetch)
        self.assertLessEqual({e["orderId"] for e in self.entries(outcome="alert")}, {5})
        self.assertEqual([e for e in self.entries(orderId=5, action="fetch") if e["cycle"] >= refund5["cycle"]], [])

        spent = self.ledger.spent(self.chain.now())
        self.run_ticks(10)  # past due and unapproved: no paid checks while the buyer decides
        self.assertEqual(self.ledger.spent(self.chain.now()), spent)

        self.chain.approve(0, 2)  # the buyer's lock opens: the agent pays within the next ticks
        self.run_ticks(3)
        self.assertEqual(self.chain.orders[0]["state"], CLOSED)
        self.assertEqual(self.chain.orders[0]["paid"], 3000)
        # the permit from the check before the due date still covers it: paid without a new paid check
        paid = [e for e in self.entries(orderId=0) if e.get("outcome") == "Paid"]
        self.assertEqual(paid[-1]["action"], "release")
        self.assertEqual(self.ledger.spent(self.chain.now()), spent)

    def test_no_data_backs_off_then_alerts(self):
        self.fetcher.fail["ch:01234567"] = NoData("Airnode responded 400")
        self.agent.tick()
        self.assertEqual(self.entries(orderId=0, action="fetch")[0]["outcome"], "no_data")
        self.run_ticks(1)  # 30 s later: backoff has passed, second attempt
        self.run_ticks(5)  # 2 min backoff, third attempt -> exhausted
        outcomes = [e["outcome"] for e in self.entries(orderId=0, action="fetch")]
        self.assertEqual(outcomes, ["no_data", "no_data", "alert"])

    def test_payment_failure_pauses_paid_fetches(self):
        self.fetcher.fail["ch:01234567"] = PaymentFailed("insufficient aUSD")
        self.agent.tick()
        self.assertTrue(self.ledger.paid_paused(self.chain.now()))
        self.assertEqual(self.entries(orderId=0, action="fetch")[0]["outcome"], "alert")
        self.chain.advance(30)
        self.agent.tick()
        self.assertTrue(self.entries(outcome="skipped", reason="paid fetches paused"))

    def test_wrong_request_quarantines_the_order(self):
        original = self.fetcher.fetch

        def wrong_request(source, supplier_id):
            ev = original(source, supplier_id)
            if supplier_id == "01234567":
                ev.request_hash = fakes.fake_request_hash(0, "00000001")  # another company's lookup
            return ev

        self.fetcher.fetch = wrong_request
        self.agent.tick()
        self.assertEqual(self.entries(orderId=0)[-1]["outcome"], "quarantined")
        self.assertTrue(self.ledger.is_quarantined(0))
        self.run_ticks(5)
        self.assertEqual(len(self.entries(orderId=0, outcome="quarantined")), 1)  # never touched again

    def test_stale_record_is_retried(self):
        original = self.fetcher.fetch

        def stale(source, supplier_id):
            ev = original(source, supplier_id)
            ev.timestamp -= 3600
            return ev

        self.fetcher.fetch = stale
        self.agent.tick()
        self.assertEqual(self.entries(orderId=0, action="submitEvidence")[0]["outcome"], "retry")
        self.assertIn("StaleResponse", self.entries(orderId=0, action="submitEvidence")[0]["error"])

    def test_an_older_permit_is_not_paid_after_the_supplier_failed(self):
        chain = fakes.FakeChain()
        a = chain.add_order(0, "01234567", 0x06, [500, 500], [600, 1200], approved=[0, 1])
        b = chain.add_order(0, "01234567", 0x06, [500], [5000], approved=[0])
        fetcher = fakes.FakeFetcher(chain.now)
        agent = Executor(chain, fetcher, self.ledger, self.journal, self.cfg)
        agent.tick()  # monitoring: a gets a permit for its first milestone
        self.assertTrue(chain.snapshot().order(a).permit_valid)
        fetcher.registry["ch:01234567"] = {"accounts_overdue": False, "confirmation_overdue": False, "status": "liquidation"}
        chain.advance(30)
        chain.send("submitEvidence", b, *fetcher.fetch("ch", "01234567").args)  # someone checks b: liquidation
        chain.advance(600)  # a's milestone is due and its old permit is still valid
        with self.assertRaises(Exception) as ctx:
            chain.simulate("release", a)
        self.assertEqual(str(ctx.exception).split("(")[0], "SupplierFailed")
        agent.tick()  # the agent holds a instead of paying it
        self.assertEqual(chain.orders[a]["state"], HELD)
        self.assertEqual(chain.orders[a]["paid"], 0)

    def test_history_only_moves_forward(self):
        chain = fakes.FakeChain()
        a = chain.add_order(0, "01234567", 0x06, [500], [5000], approved=[0])
        b = chain.add_order(0, "01234567", 0x06, [500], [5000], approved=[0])
        fetcher = fakes.FakeFetcher(chain.now)
        old = fetcher.fetch("ch", "01234567")  # signed now, used later
        chain.advance(60)
        chain.send("submitEvidence", a, *fetcher.fetch("ch", "01234567").args)
        checked = chain.suppliers["key:0:01234567"]["last_check_at"]
        chain.send("submitEvidence", b, *old.args)  # valid for order b, but older than the history
        self.assertEqual(chain.suppliers["key:0:01234567"]["last_check_at"], checked)

    def test_high_gas_price_skips_all_writes(self):
        self.chain.gas_gwei = 500
        self.agent.tick()
        self.assertEqual(self.fetcher.calls, [])
        self.assertTrue(self.entries(action="gas", outcome="skipped"))

    def test_held_order_is_refunded_after_the_grace_period(self):
        self.run_ticks(1)
        self.assertEqual(self.chain.orders[1]["state"], HELD)
        self.run_ticks(4)  # grace 120 s
        self.assertEqual(self.chain.orders[1]["state"], CLOSED)


if __name__ == "__main__":
    unittest.main()
