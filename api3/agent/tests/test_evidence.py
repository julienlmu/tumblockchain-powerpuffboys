import json
import pathlib
import subprocess
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from evidence import Fetcher, FetchFailed, NoData, PaymentFailed, VerificationFailed  # noqa: E402

RESPONSE = {
    "source": "ch", "supplierId": "09729896", "airnode": "0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF",
    "requestHash": "0xde8d697c8cd5e5ead92f39da40c08b65459caf8ba0b60d4543b39369c65e7775", "timestamp": "1793371032",
    "data": "0x7b7d", "raw": "{}", "signature": "0xsig", "paymentTx": "0xpay", "priceUsd": "0.01",
}


def fetcher(stdout="", code=0, stderr=""):
    calls = []

    def run(cmd, **kw):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, code, stdout, stderr)

    f = Fetcher(["api3/scripts/fetch-evidence.sh"], cwd=pathlib.Path("."), runner=run)
    return f, calls


class FetcherTest(unittest.TestCase):
    def test_parses_the_signed_response_file(self):
        f, calls = fetcher(json.dumps(RESPONSE) + "\n")
        ev = f.fetch("ch", "09729896")
        self.assertEqual(calls[0], ["api3/scripts/fetch-evidence.sh", "ch", "09729896"])
        self.assertEqual((ev.timestamp, ev.price_usd, ev.payment_tx), (1793371032, 0.01, "0xpay"))
        self.assertEqual(ev.args, [RESPONSE["requestHash"], "1793371032", "0x7b7d", "0xsig"])

    def test_pretty_printed_json_also_works(self):
        f, _ = fetcher(json.dumps(RESPONSE, indent=2))
        self.assertEqual(f.fetch("ch", "09729896").supplier_id, "09729896")

    def test_exit_codes(self):
        for code, error in ((3, NoData), (4, PaymentFailed), (5, VerificationFailed), (1, FetchFailed)):
            f, _ = fetcher(code=code, stderr="Airnode responded 400\n")
            with self.assertRaises(error) as ctx:
                f.fetch("ch", "09729896")
            self.assertIn("400", str(ctx.exception))

    def test_garbage_output_is_a_fetch_failure(self):
        f, _ = fetcher("not json")
        with self.assertRaises(FetchFailed):
            f.fetch("ch", "09729896")


if __name__ == "__main__":
    unittest.main()
