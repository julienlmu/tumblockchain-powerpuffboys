"""Tests for the pay-on-pass gate, the SupplierPulse executor, the refund store and the proof's tx list.

Run from cardano-agent/: venv/bin/python -m unittest -v
"""
import dataclasses
import sys
import tempfile
import time
import unittest
from unittest.mock import AsyncMock, patch

from gate import ExecutorError, Verdict, deadline_for, load_app, parse_verdict, run_gate
from receipt import transactions
from refunds import RefundStore

MOCK = load_app("apps/mock.json")
PULSE_SIM = load_app("apps/supplier-pulse-sim.json")
PULSE_PLUS = load_app("apps/supplier-pulse-plus.json")


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


def pulse(**overrides):
    return dataclasses.replace(PULSE_SIM, **{"retry_interval_s": 0, "max_wait_s": 1, **overrides})


async def check_supplier(a, company):
    return await run_gate(a, {"order_id": 3, "company_number": company}, deadline_for(a), log=lambda *_: None)


class SupplierPulseTest(unittest.IsolatedAsyncioTestCase):
    async def test_active_supplier_paid_is_a_delivered_decision(self):
        verdict, _ = await check_supplier(pulse(), "01234567")
        self.assertTrue(verdict.passed)
        self.assertEqual(verdict.evidence["outcome"], "Paid")

    async def test_held_payment_is_a_delivered_decision(self):
        verdict, _ = await check_supplier(pulse(), "07654321")
        self.assertTrue(verdict.passed)
        self.assertEqual(verdict.evidence["outcome"], "Held")

    async def test_no_data_retries_then_fails(self):
        no_data = Verdict(False, True, "no data", {"outcome": "NoData"})
        with patch("gate.run_executor", new=AsyncMock(return_value=no_data)):
            verdict, attempts = await run_gate(
                pulse(retry_interval_s=0.01),
                {"order_id": 3, "company_number": "99999999"},
                deadline=time.time() + 0.03,
                log=lambda *_: None,
            )
        self.assertFalse(verdict.passed)
        self.assertGreater(len(attempts), 1)
        self.assertEqual(verdict.evidence["outcome"], "NoData")

    async def test_supplier_executor_marks_no_data_retryable(self):
        verdict, attempts = await check_supplier(pulse(max_wait_s=0), "99999999")
        self.assertFalse(verdict.passed)
        self.assertTrue(verdict.retryable)
        self.assertEqual(len(attempts), 1)
        self.assertEqual(verdict.evidence["outcome"], "NoData")

    async def test_rejected_evidence_is_final(self):
        rejected = 'echo \'{"outcome": "Rejected", "reason": "WrongRequest"}\''
        a = pulse(executor=[sys.executable, "executors/supplier_pulse.py", "/bin/sh", "-c", rejected])
        verdict, attempts = await check_supplier(a, "01234567")
        self.assertFalse(verdict.passed)
        self.assertEqual(len(attempts), 1)

    async def test_missing_agent_script_is_no_data(self):
        a = pulse(executor=[sys.executable, "executors/supplier_pulse.py", "./no-such-script.sh"], max_wait_s=0)
        verdict, _ = await check_supplier(a, "01234567")
        self.assertFalse(verdict.passed)
        self.assertTrue(verdict.retryable)


class SupplierPulsePlusTest(unittest.IsolatedAsyncioTestCase):
    async def test_fractional_order_id_is_rejected_without_retry(self):
        helper = "import json; print(json.dumps({'outcome': 'Held'}))"
        configured = dataclasses.replace(
            PULSE_PLUS,
            executor=[sys.executable, "executors/supplier_pulse.py", sys.executable, "-c", helper],
        )
        verdict, _ = await run_gate(
            configured,
            {"order_id": 7.5, "supplier_id": "07654321"},
            deadline_for(configured),
            log=lambda *_: None,
        )
        self.assertFalse(verdict.passed)
        self.assertFalse(verdict.retryable)
        self.assertEqual(verdict.evidence["outcome"], "Rejected")
        self.assertIn("order_id must be an integer", verdict.summary)

    async def test_not_due_verified_result_is_a_paid_job(self):
        result = {
            "outcome": "NotDue",
            "txHash": "0xethereum",
            "orderId": 7,
            "status": "active",
            "contract": "0xcontract",
            "evidence": {"paymentTx": "0xbase"},
        }
        helper = "import json; print(json.dumps(%r))" % result
        configured = dataclasses.replace(
            PULSE_PLUS,
            executor=[sys.executable, "executors/supplier_pulse.py", sys.executable, "-c", helper],
        )
        verdict, attempts = await run_gate(
            configured,
            {"order_id": 7, "supplier_id": "07654321"},
            deadline_for(configured),
            log=lambda *_: None,
        )
        self.assertTrue(verdict.passed)
        self.assertEqual(len(attempts), 1)
        self.assertEqual(verdict.evidence["outcome"], "NotDue")
        self.assertEqual(verdict.evidence["evidence"]["paymentTx"], "0xbase")


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



class TransactionsTest(unittest.TestCase):
    def test_merges_both_sides_oldest_first(self):
        lock = {"txHash": "a", "blockTime": 1, "newOnChainState": "FundsLocked"}
        result = {"txHash": "b", "blockTime": 2, "newOnChainState": "ResultSubmitted"}
        pending = {"txHash": "c", "blockTime": None, "newOnChainState": "Withdrawn"}
        purchase = {"CurrentTransaction": result, "TransactionHistory": [lock]}
        payment = {"CurrentTransaction": pending, "TransactionHistory": [result]}
        self.assertEqual([t["txHash"] for t in transactions(purchase, payment, None)], ["a", "b", "c"])


if __name__ == "__main__":
    unittest.main()
