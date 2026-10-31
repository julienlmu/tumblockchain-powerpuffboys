"""Offline tests for the one-job Cardano to SupplierPulse+ adapter."""
import dataclasses
import pathlib
import sys
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(pathlib.Path(__file__).parent / "executors"))

import supplier_pulse_plus as adapter  # noqa: E402
from chain import OUTCOME_NAMES, Reverted  # noqa: E402
from evidence import NoData, VerificationFailed  # noqa: E402
from model import ACTIVE, Evidence, Order, Snapshot  # noqa: E402


CFG = dataclasses.make_dataclass("Cfg", ["contract", "rpc_urls", "agent_key", "fetch_cmd"])(
    "0xcontract", ["https://sepolia.example"], "key-not-used", ("fetch-evidence.sh",)
)
ORDER = Order(
    id=7,
    source=0,
    supplier_id="07654321",
    supplier_key="supplier-key",
    rules=0,
    state=ACTIVE,
    remaining=500,
    permit_valid=False,
    permit_valid_until=0,
    next_due_date=0,
    next_approved=False,
    auto_refund_at=0,
    tier=0,
)
EVIDENCE = Evidence(
    source="ch",
    supplier_id="07654321",
    request_hash="0xrequest",
    timestamp=123,
    data="0xdata",
    signature="0xsig",
    raw='{"status":"liquidation"}',
    payment_tx="0xbase-payment",
)


class CardanoSupplierPulsePlusTest(unittest.TestCase):
    def setUp(self):
        self.chain = Mock()
        self.chain.snapshot.return_value = Snapshot(123, [ORDER])
        self.chain.outcome_names = OUTCOME_NAMES
        self.chain.simulate.return_value = [3]
        self.chain.send.return_value = "0xethereum-tx"
        self.fetcher = Mock()
        self.fetcher.fetch.return_value = EVIDENCE
        self.chain_factory = Mock(return_value=self.chain)
        self.fetcher_factory = Mock(return_value=self.fetcher)

    def check(self, order_id=7, supplier_id="07654321"):
        return adapter.check_order(
            order_id,
            supplier_id,
            config_loader=lambda: CFG,
            chain_factory=self.chain_factory,
            fetcher_factory=self.fetcher_factory,
        )

    def test_held_result_is_a_delivered_decision(self):
        result = self.check()
        self.assertEqual(result["outcome"], "Held")
        self.assertEqual(result["status"], "liquidation")
        self.assertEqual(result["txHash"], "0xethereum-tx")
        self.assertEqual(result["evidence"]["paymentTx"], "0xbase-payment")
        self.chain.send.assert_called_once_with("checkAndRelease", 7, "0xrequest", "123", "0xdata", "0xsig")

    def test_order_and_supplier_must_match_before_fetching(self):
        result = self.check(supplier_id="01234567")
        self.assertEqual(result["outcome"], "Rejected")
        self.fetcher_factory.assert_not_called()
        self.chain.send.assert_not_called()

    def test_no_data_is_not_reported_as_a_supplier_failure(self):
        self.fetcher.fetch.side_effect = NoData("registry unavailable")
        result = self.check()
        self.assertEqual(result["outcome"], "NoData")
        self.assertIn("unable to verify", result["reason"])
        self.chain.send.assert_not_called()

    def test_bad_signed_data_is_rejected_without_a_transaction(self):
        self.fetcher.fetch.side_effect = VerificationFailed("wrong signer")
        result = self.check()
        self.assertEqual(result["outcome"], "Rejected")
        self.assertIn("signature/request verification", result["reason"])
        self.chain.send.assert_not_called()

    def test_unavailable_order_returns_no_decision(self):
        self.chain.snapshot.return_value = Snapshot(123, [])
        result = self.check()
        self.assertEqual(result["outcome"], "Rejected")
        self.fetcher_factory.assert_not_called()

    def test_stale_record_can_be_retried_but_other_reverts_are_not(self):
        self.chain.simulate.side_effect = Reverted("StaleResponse")
        self.assertEqual(self.check()["outcome"], "NoData")
        self.chain.simulate.side_effect = Reverted("WrongSigner")
        self.assertEqual(self.check()["outcome"], "Rejected")


if __name__ == "__main__":
    unittest.main()
