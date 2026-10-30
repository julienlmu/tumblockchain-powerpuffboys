"""The Sepolia acceptance check (c3_check.py), on hand-made chain state and logs."""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from c3_check import DEMO, checks  # noqa: E402
from model import ACTIVE, CLOSED, HELD  # noqa: E402


def order(i, state, paid=0, paid_count=0, failed=0, tier=0):
    return {"id": i, "state": state, "paid": paid, "paid_count": paid_count, "failed": failed, "tier": tier}


MORNING = {  # what §2.5 expects after the night
    DEMO["A"]: order(0, ACTIVE, 500, 1, 0, 2), DEMO["B"]: order(1, CLOSED, failed=0x86),
    DEMO["C"]: order(2, CLOSED, failed=0x02), DEMO["D"]: order(3, ACTIVE, 500, 1), DEMO["E"]: order(4, HELD, failed=0x08)}
LOG = [{"cycle": c, "action": "idle", "outcome": "nothing due"} for c in range(1, 12)] + [
    {"cycle": 3, "orderId": 0, "action": "checkAndRelease", "outcome": "Paid"},
    {"cycle": 4, "orderId": 3, "action": "release", "outcome": "Paid"},
    {"cycle": 30, "orderId": 1, "action": "refundRemaining", "outcome": "Refunded"},
    {"cycle": 31, "action": "read", "outcome": "error", "error": "timeout on ethereum-sepolia-rpc.publicnode.com"}]


class C3CheckTest(unittest.TestCase):
    def test_the_expected_morning_passes(self):
        results = checks(MORNING, LOG)
        self.assertEqual([name for name, ok, _ in results if not ok], [])
        self.assertIn("RPC read errors 1", results[-1][2])  # a transient read error does not fail the run

    def test_nothing_passes_before_the_orders_exist(self):
        failing = [name for name, ok, _ in checks({}, []) if not ok]
        self.assertEqual(len(failing), 8)  # all but "no failed order actions"

    def test_a_payment_must_come_from_the_agent(self):
        log = [e for e in LOG if e.get("orderId") != 0]  # A paid by someone else
        self.assertIn("A: milestone 1 paid by the agent", [n for n, ok, _ in checks(MORNING, log) if not ok])

    def test_a_paid_order_is_not_counted_as_held(self):
        state = dict(MORNING, **{DEMO["C"]: order(2, ACTIVE, 500, 1)})
        self.assertIn("C: held with accounts overdue", [n for n, ok, _ in checks(state, LOG) if not ok])


if __name__ == "__main__":
    unittest.main()
