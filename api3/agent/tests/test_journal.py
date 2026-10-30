"""The run summaries: plain text and the Markdown table for docs/evidence.md."""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from journal import report, report_markdown  # noqa: E402

PAY, TX = "0x" + "9" * 64, "0x" + "1" * 64
ENTRIES = [
    {"ts": "2026-10-30T16:03:38Z", "cycle": 1, "action": "submitEvidence", "reason": "re-check by tier", "orderId": 0,
     "supplier": "ch:09729896", "outcome": "clean", "paymentTx": PAY, "tx": TX},
    {"ts": "2026-10-30T16:04:08Z", "cycle": 2, "action": "idle", "outcome": "nothing due"},
    {"ts": "2026-10-30T16:04:38Z", "cycle": 3, "action": "refundRemaining", "reason": "grace period over", "orderId": 1,
     "supplier": "ch:07418033", "outcome": "Refunded", "tx": TX},
    {"ts": "2026-10-30T16:05:08Z", "cycle": 4, "action": "fetch", "orderId": 5, "supplier": "ch:99999999", "outcome": "alert"},
]


class ReportTest(unittest.TestCase):
    def test_markdown_lists_every_transaction_with_explorer_links(self):
        md = report_markdown(ENTRIES, {"2026-10-30": 0.01})
        rows = [line for line in md.splitlines() if line.startswith("| ") and "---" not in line][1:]
        self.assertEqual(len(rows), 2)  # the paid check and the refund; idle cycles and alerts are not transactions
        self.assertIn("https://sepolia.basescan.org/tx/" + PAY, rows[0])
        self.assertIn("https://sepolia.etherscan.io/tx/" + TX, rows[0])
        self.assertIn("| – |", rows[1])  # a refund has no x402 payment
        self.assertIn("4 cycles", md)
        self.assertIn("2 transactions, $0.01 spent on paid checks, 1 alerts, 0 errors", md)

    def test_plain_report_counts_cycles_and_alerts(self):
        text = report(ENTRIES, {"2026-10-30": 0.01})
        self.assertIn("cycles:        4", text)
        self.assertIn("alerts:        1", text)


if __name__ == "__main__":
    unittest.main()
