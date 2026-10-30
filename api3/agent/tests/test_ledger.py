import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from ledger import Ledger  # noqa: E402

MIDNIGHT = 1_793_404_800  # 2026-10-31 00:00:00 UTC


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = pathlib.Path(self.tmp.name) / "state.json"
        self.ledger = Ledger(self.path)

    def tearDown(self):
        self.tmp.cleanup()

    def test_budget_resets_at_utc_midnight(self):
        self.ledger.add_spend(MIDNIGHT - 1, 0.50)
        self.assertEqual(self.ledger.spent(MIDNIGHT - 1), 0.50)
        self.assertEqual(self.ledger.spent(MIDNIGHT), 0.0)

    def test_backoff_grows_then_waits_for_the_next_window(self):
        self.assertEqual(self.ledger.record_failure(7, 1000, 3, 1800), (1, False))
        self.assertFalse(self.ledger.backoff_ok(7, 1029))
        self.assertTrue(self.ledger.backoff_ok(7, 1030))
        self.assertEqual(self.ledger.record_failure(7, 1030, 3, 1800), (2, False))
        self.assertTrue(self.ledger.backoff_ok(7, 1150))
        self.assertEqual(self.ledger.record_failure(7, 1150, 3, 1800), (3, True))
        self.assertFalse(self.ledger.backoff_ok(7, 1150 + 1799))
        self.assertTrue(self.ledger.backoff_ok(7, 1150 + 1800))
        self.ledger.clear_failures(7)
        self.assertTrue(self.ledger.backoff_ok(7, 0))

    def test_state_survives_a_restart(self):
        self.ledger.add_spend(MIDNIGHT, 0.03)
        self.ledger.quarantine(2, "WrongRequest")
        self.ledger.pause_paid(MIDNIGHT, 900)
        self.ledger.next_cycle()
        self.ledger.save()
        again = Ledger(self.path)
        self.assertEqual(again.spent(MIDNIGHT), 0.03)
        self.assertTrue(again.is_quarantined(2))
        self.assertTrue(again.paid_paused(MIDNIGHT + 899))
        self.assertFalse(again.paid_paused(MIDNIGHT + 900))
        self.assertEqual(again.next_cycle(), 2)

    def test_tier_change_is_reported_once(self):
        self.assertIsNone(self.ledger.tier_change("k", 0))
        self.assertIsNone(self.ledger.tier_change("k", 0))
        self.assertEqual(self.ledger.tier_change("k", 1), 0)
        self.assertIsNone(self.ledger.tier_change("k", 1))


if __name__ == "__main__":
    unittest.main()
