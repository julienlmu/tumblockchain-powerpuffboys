"""Tests for the pay-on-pass gate and the refund store.

Run from cardano-agent/: venv/bin/python -m unittest -v
"""
import dataclasses
import sys
import tempfile
import unittest

from gate import ExecutorError, deadline_for, load_app, parse_verdict, run_gate
from refunds import RefundStore

MOCK = load_app("apps/mock.json")


def app(**overrides):
    return dataclasses.replace(MOCK, **{"timeout_s": 10, "retry_interval_s": 0, "max_wait_s": 5, **overrides})


async def gate(a, outcome):
    return await run_gate(a, {"task": "t", "outcome": outcome}, deadline_for(a), log=lambda *_: None)


class GateTest(unittest.IsolatedAsyncioTestCase):
    async def test_pass_on_first_attempt(self):
        verdict, attempts = await gate(app(), "pass")
        self.assertTrue(verdict.passed)
        self.assertEqual(len(attempts), 1)

    async def test_fail_is_final(self):
        verdict, attempts = await gate(app(), "fail")
        self.assertFalse(verdict.passed)
        self.assertEqual(len(attempts), 1)

    async def test_retry_then_pass(self):
        verdict, attempts = await gate(app(), "retry")
        self.assertTrue(verdict.passed)
        self.assertEqual(len(attempts), 2)

    async def test_no_retry_after_deadline(self):
        verdict, attempts = await gate(app(max_wait_s=0), "retry")
        self.assertFalse(verdict.passed)
        self.assertEqual(len(attempts), 1)

    async def test_crashing_executor_does_not_pass(self):
        crash = app(executor=[sys.executable, "-c", "import sys; sys.exit(3)"], max_wait_s=0)
        verdict, _ = await gate(crash, "pass")
        self.assertFalse(verdict.passed)
        self.assertIn("exited 3", verdict.summary)

    async def test_option_given_as_index_list(self):
        verdict, _ = await gate(app(), [1])  # index 1 = "fail"
        self.assertFalse(verdict.passed)


class ParseAndDeadlineTest(unittest.TestCase):
    def test_last_json_line_wins(self):
        self.assertTrue(parse_verdict('log line\n{"passed": true}\n').passed)

    def test_passed_must_be_boolean(self):
        with self.assertRaises(ExecutorError):
            parse_verdict('{"passed": "yes"}')

    def test_deadline_capped_by_masumi_time_in_ms(self):
        a = app(max_wait_s=3600, submit_margin_s=300)
        now = 1_793_000_000.0  # 30 Oct 2026 in unix seconds
        self.assertEqual(deadline_for(a, submit_result_time=(now + 600) * 1000, now=now), now + 300)


class RefundStoreTest(unittest.TestCase):
    def test_pending_until_authorized(self):
        with tempfile.TemporaryDirectory() as d:
            store = RefundStore(f"{d}/refundable.json")
            store.mark("bid1", "did not pass")
            store.mark("bid2", "did not pass")
            store.mark_authorized("bid1")
            self.assertEqual(store.pending(), {"bid2"})


if __name__ == "__main__":
    unittest.main()
