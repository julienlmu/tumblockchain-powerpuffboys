"""cast adapter: parsing, revert decoding and RPC failover, with recorded cast output."""
import json
import pathlib
import shutil
import subprocess
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from chain import ERROR_SELECTORS, Chain, ChainError, Reverted, input_signature, revert_from_text  # noqa: E402
from chain_v1 import ChainV1  # noqa: E402

# recorded from cast 1.8.7 against Sepolia (v1 contract), 30 Oct 2026
REVERT_ENVELOPE = json.dumps({"schema_version": 1, "success": False, "data": None, "errors": [
    {"level": "error", "code": "cast.error", "message": "execution reverted: NotActive(1)"},
    {"level": "error", "code": "cast.error.context", "message":
        'server returned an error response: error code 3: execution reverted, data: '
        '"0x1d61e8ee0000000000000000000000000000000000000000000000000000000000000001"'}], "warnings": []})
TX = "0x" + "ab" * 32
RPC_ERROR_ENVELOPE = json.dumps({"schema_version": 1, "success": False, "data": None, "errors": [
    {"level": "error", "code": "cast.error", "message": "server returned an error response: error code -32603: Internal server error"}],
    "warnings": []})

FULL_SIGNATURES = [
    "WrongSigner(address)", "WrongRequest(bytes32,bytes32)", "StaleResponse(uint256,uint256)",
    "FutureResponse(uint256,uint256)", "Replayed(bytes32)", "NotNewer(uint256,uint256)", "NoValidPermit(uint256)",
    "PermitExpired(uint256,uint256)", "NotApproved(uint256)", "NotDue(uint256,uint256)", "NotActive(uint8)",
    "NotHeld()", "NotRefundable()", "RefundNotYet(uint256)", "SupplierFailed(uint256)", "NoNewerFailure()", "BadOrder()", "BadSource()", "BadSupplierId()", "BadRules()",
    "NotAuthorized()", "TransferFailed()", "InvalidSignatureLength()", "InvalidSignatureS()", "InvalidSignatureV()",
    "InvalidSigner()", "KeyNotFound()", "NoNumber()", "NoString()", "NoBool()",
]


def proc(stdout="", returncode=0, stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class ScriptedRunner:
    """Answers cast commands by function name, and records which RPC each call used."""

    def __init__(self, answers, bad_rpcs=(), receipts=(), bad_receipt_rpcs=()):
        self.answers, self.bad_rpcs, self.calls, self.cmds = answers, set(bad_rpcs), [], []
        self.receipts, self.bad_receipt_rpcs = list(receipts), set(bad_receipt_rpcs)

    def __call__(self, cmd):
        url = cmd[cmd.index("--rpc-url") + 1] if "--rpc-url" in cmd else None
        self.calls.append((cmd[1], url))
        self.cmds.append(cmd)
        if url in self.bad_rpcs:
            return proc(RPC_ERROR_ENVELOPE, 1)
        if cmd[1] == "rpc":  # eth_getTransactionReceipt: the next scripted receipt, None while pending
            if url in self.bad_receipt_rpcs:
                return proc(RPC_ERROR_ENVELOPE, 1)
            receipt = self.receipts.pop(0) if self.receipts else None
            return proc(json.dumps({"schema_version": 1, "success": True, "data": receipt, "errors": [], "warnings": []}))
        if cmd[1] == "block":
            return proc("1800000000\n")
        if cmd[1] == "wallet":
            return proc("0x90F79bf6EB2c4f870365E785982E1f101E93b906\n")
        sig = next(a for a in cmd if "(" in a and not a.startswith("0x"))
        args = cmd[cmd.index(sig) + 1:cmd.index("--json")]
        answer = self.answers[sig.split("(")[0]]
        out = answer(*args) if callable(answer) else answer
        return out if isinstance(out, subprocess.CompletedProcess) else proc(json.dumps(out))


class ChainTest(unittest.TestCase):
    def test_input_signature_drops_the_return_types(self):
        self.assertEqual(input_signature("submitEvidence(uint256,bytes32,uint256,bytes,bytes)(bool)"),
                         "submitEvidence(uint256,bytes32,uint256,bytes,bytes)")

    def test_revert_from_the_recorded_envelope(self):
        r = revert_from_text(" ".join(e["message"] for e in json.loads(REVERT_ENVELOPE)["errors"]))
        self.assertEqual((r.name, r.selector, r.detail), ("NotActive", "0x1d61e8ee", "(1)"))

    def test_revert_from_plain_text_custom_error(self):
        self.assertEqual(revert_from_text("Error: custom error 0x4a3ed0da: ...").name, "StaleResponse")

    def test_rpc_errors_are_not_reverts(self):
        self.assertIsNone(revert_from_text("server returned an error response: error code -32603: Internal server error"))

    def test_failover_to_the_next_rpc(self):
        runner = ScriptedRunner({"ordersLength": ["2"]}, bad_rpcs={"http://a"})
        chain = Chain("0xc", ["http://a", "http://b"], runner=runner)
        self.assertEqual(chain.call("ordersLength"), ["2"])
        self.assertEqual([url for _, url in runner.calls], ["http://a", "http://b"])

    def test_the_rpc_that_answered_is_tried_first_next_time(self):
        runner = ScriptedRunner({"ordersLength": ["2"]}, bad_rpcs={"http://a"})
        chain = Chain("0xc", ["http://a", "http://b"], runner=runner)
        chain.call("ordersLength")
        runner.calls.clear()
        chain.call("ordersLength")
        self.assertEqual([url for _, url in runner.calls], ["http://b"])  # no second miss on the dead one
        runner.bad_rpcs = {"http://b"}  # b fails later: a is tried again
        chain.call("ordersLength")
        self.assertEqual([url for _, url in runner.calls][1:], ["http://b", "http://a"])

    def test_a_call_without_return_values_succeeds(self):
        # cast prints a bare "0x" for release / applySupplierFailure / refundRemaining, even with --json
        runner = ScriptedRunner({"release": proc("0x\n")})
        chain = Chain("0xc", ["http://a", "http://b"], private_key="0xk", runner=runner)
        self.assertEqual(chain.simulate("release", 0), ["0x"])
        self.assertEqual([url for name, url in runner.calls if name == "call"], ["http://a"])  # no failover

    def test_a_revert_is_not_retried_on_another_rpc(self):
        runner = ScriptedRunner({"release": proc(REVERT_ENVELOPE, 1)})
        chain = Chain("0xc", ["http://a", "http://b"], private_key="0xk", runner=runner)
        with self.assertRaises(Reverted) as ctx:
            chain.simulate("release", 1)
        self.assertEqual(ctx.exception.name, "NotActive")
        self.assertEqual([url for name, url in runner.calls if name == "call"], ["http://a"])

    def test_all_rpcs_failing_raises_chain_error(self):
        chain = Chain("0xc", ["http://a"], runner=ScriptedRunner({}, bad_rpcs={"http://a"}))
        with self.assertRaises(ChainError):
            chain.call("ordersLength")

    def test_send_broadcasts_once_and_follows_the_hash(self):
        # cast send --async prints the bare hash (cast 1.8.7); the receipt is null while pending
        runner = ScriptedRunner({"release": proc(TX + "\n")}, receipts=[None, {"status": "0x1", "transactionHash": TX}])
        chain = Chain("0xc", ["http://a"], private_key="0xk", runner=runner, receipt_poll=0)
        self.assertEqual(chain.send("release", 1), TX)
        self.assertEqual([c for c, _ in runner.calls], ["send", "rpc", "rpc"])
        send = runner.cmds[0]
        self.assertIn("--async", send)
        # Batu's finding: the exact estimate ran out of gas when the transaction landed a block later
        self.assertEqual(send[send.index("--gas-limit") + 1], "2000000")

    def test_a_receipt_rpc_failure_never_sends_again(self):
        # an RPC error while waiting (Tenderly -32603): the receipt comes from the next RPC, one transaction only
        runner = ScriptedRunner({"release": proc(TX + "\n")}, receipts=[{"status": "0x1", "transactionHash": TX}],
                                bad_receipt_rpcs={"http://a"})
        chain = Chain("0xc", ["http://a", "http://b"], private_key="0xk", runner=runner, receipt_poll=0)
        self.assertEqual(chain.send("release", 1), TX)
        self.assertEqual([c for c, _ in runner.calls].count("send"), 1)

    def test_a_mined_but_reverted_transaction_raises(self):
        runner = ScriptedRunner({"release": proc(TX + "\n")}, receipts=[{"status": "0x0", "transactionHash": TX}])
        with self.assertRaises(ChainError):
            Chain("0xc", ["http://a"], private_key="0xk", runner=runner, receipt_poll=0).send("release", 1)

    def test_a_transaction_not_mined_in_time_is_reported_not_sent_again(self):
        runner = ScriptedRunner({"release": proc(TX + "\n")})  # the receipt stays null
        chain = Chain("0xc", ["http://a"], private_key="0xk", runner=runner, receipt_timeout=0, receipt_poll=0)
        with self.assertRaises(ChainError) as ctx:
            chain.send("release", 1)
        self.assertIn(TX, str(ctx.exception))  # the hash goes to the log, so the transaction can be found
        self.assertEqual([c for c, _ in runner.calls].count("send"), 1)

    def test_errors_carry_neither_the_key_nor_full_rpc_urls(self):
        key, url = "0x" + "11" * 32, "https://eth-sepolia.example.com/v2/SECRETAPIKEY"

        def runner(cmd):  # cast puts the full URL into connection errors
            return proc("", 1, "error sending request for url (%s): connection refused: %s" % (url, " ".join(cmd)))

        with self.assertRaises(ChainError) as ctx:
            Chain("0xc", [url], private_key=key, runner=runner).send("release", 1)
        text = str(ctx.exception)
        self.assertNotIn(key[2:], text)
        self.assertNotIn("SECRETAPIKEY", text)
        self.assertIn("eth-sepolia.example.com", text)

    def test_a_timeout_deriving_the_address_does_not_leak_the_key(self):
        key = "0x" + "22" * 32

        def runner(cmd):
            raise subprocess.TimeoutExpired(cmd, 90)  # its message contains the command, key included

        with self.assertRaises(ChainError) as ctx:
            Chain("0xc", ["http://a"], private_key=key, runner=runner).address
        self.assertNotIn(key[2:], repr(ctx.exception))
        self.assertTrue(ctx.exception.__suppress_context__)  # a printed traceback does not show the command either

    def test_snapshot_parses_cast_json(self):
        answers = {
            "ordersLength": ["3"],
            "orderInfo": lambda i: ["0xbuyer", "0xsupplier", 0 if i == "0" else 1,
                                    "09729896" if i == "0" else "TESTLEI0000000000000", "0xreq", "0xref", "3600", 7 if i == "0" else 8],
            "supplierKeyOf": lambda source, sid: ["0xkey%s" % source],
            "orderStatus": lambda i: [{"0": 0, "1": 1, "2": 2}[i], "500000000000000", "2500000000000000", "1", "3",
                                      "1800003600", i == "0", "1799999990"],
            "orderSchedule": lambda i: ["1800000300", True, 0 if i == "0" else 136, "0", "1800000120" if i == "1" else "0",
                                        2 if i == "0" else 0],
            "supplierRecord": lambda k: [6 if k == "0xkey0" else 0, 9, 0, "1799999000", "1799999990",
                                         "0" if k == "0xkey0" else "1799999500", 2 if k == "0xkey0" else 0],
        }
        runner = ScriptedRunner(answers)
        snap = Chain("0xc", ["http://a"], runner=runner).snapshot()
        self.assertEqual(snap.now, 1800000000)
        self.assertEqual([o.id for o in snap.orders], [0, 1])  # order 2 is closed and dropped
        first, second = snap.orders
        self.assertEqual((first.source, first.supplier_id, first.rules, first.supplier_key), (0, "09729896", 7, "0xkey0"))
        self.assertTrue(first.permit_valid)
        self.assertEqual((first.next_due_date, first.tier, first.remaining), (1800000300, 2, 2500000000000000))
        self.assertEqual((second.state, second.auto_refund_at, second.last_failed_rules), (1, 1800000120, 136))
        self.assertEqual(snap.suppliers["0xkey0"].clean_streak, 6)
        self.assertEqual(snap.suppliers["0xkey1"].last_base_failure_at, 1799999500)

    def test_static_data_is_read_once(self):
        answers = {
            "ordersLength": ["1"],
            "orderInfo": ["0xb", "0xs", 0, "09729896", "0xr", "0xo", "3600", 7],
            "supplierKeyOf": ["0xkey0"],
            "orderStatus": [0, "0", "1", "0", "1", "0", False, "0"],
            "orderSchedule": ["1800000300", True, 0, "0", "0", 0],
            "supplierRecord": [0, 0, 0, "0", "0", "0", 0],
        }
        runner = ScriptedRunner(answers)
        chain = Chain("0xc", ["http://a"], runner=runner)
        chain.snapshot()
        runner.calls.clear()
        chain.snapshot()
        called = [c for c, _ in runner.calls]
        self.assertEqual(called.count("call"), 4)  # ordersLength, orderStatus, orderSchedule, supplierRecord

    def test_v1_snapshot_maps_the_live_contract(self):
        # recorded from the live v1 contract on Sepolia (0x91d7...74d7), 30 Oct 2026
        answers = {
            "ordersLength": ["2"],
            "companyNumberOf": lambda i: ["09729896" if i == "0" else "07418033"],
            "orderStatus": lambda i: [0, "500000000000", "1500000000000", "1", "2", "1793372468", True, "active", "1793368868"]
            if i == "0" else [1, "0", "2000000000000", "0", "2", "0", False, "liquidation", "1793368852"],
            "orderInfo": lambda i: ["0xEb3EB6da882798062b30CeC11AAaDe306287ce41", "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
                                    "0xcae416f2dce5fb6bb595eafe8c5f11ce9df4b33f8664042e10f8f776739fab48" if i == "0" else "0xother",
                                    "0x66a5", "86400", ["500000000000", "1500000000000"],
                                    [True, False] if i == "0" else [True, False]],
        }
        snap = ChainV1("0xv1", ["http://a"], runner=ScriptedRunner(answers)).snapshot()
        active, held = snap.orders
        self.assertEqual((active.supplier_id, active.rules, active.next_due_date, active.next_approved), ("09729896", 0, 0, False))
        self.assertTrue(active.permit_valid)
        self.assertEqual((held.state, held.last_failed_rules, held.auto_refund_at), (1, 0x80, 0))  # no agent refunds on v1
        self.assertEqual(snap.suppliers[active.supplier_key].last_check_at, 1793368868)
        self.assertEqual(ChainV1.outcome_names[2], "Held")  # v1's Outcome enum has no NotDue

    @unittest.skipUnless(shutil.which("cast"), "cast not installed")
    def test_selector_table_matches_cast_sig(self):
        for sig in FULL_SIGNATURES:
            selector = subprocess.run(["cast", "sig", sig], capture_output=True, text=True).stdout.strip()
            self.assertEqual(ERROR_SELECTORS.get(selector), sig.split("(")[0], sig)


if __name__ == "__main__":
    unittest.main()
