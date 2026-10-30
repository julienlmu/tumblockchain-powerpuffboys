"""Fresh signed records through FETCH_CMD (docs/SUPPLIERPULSE_PLUS.md §4.7).

The command is api3/scripts/fetch-evidence.sh (paid, x402) or fetch-local.sh
(local signer, free). Both print the §4.1 JSON and signal failures by exit code.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Callable, List, Optional, Sequence

from model import Evidence


class FetchFailed(Exception):
    """Any other failure (exit 1, timeout, unreadable output). The payment may have settled first."""

    kind = "fetch_error"
    maybe_paid = True  # count the price against the budget


class SetupFailed(FetchFailed):
    """Exit 2, or the command cannot run: usage or a missing PAYER_PRIVATE_KEY. Nothing was paid."""

    kind = "setup_error"
    maybe_paid = False


class NoData(FetchFailed):
    """Exit 3: the Airnode answered with an error, the supplier is unknown or a field is missing.
    The only failure that counts towards the no-data refund. Error answers are not charged."""

    kind = "no_data"
    maybe_paid = False


class PaymentFailed(FetchFailed):
    """Exit 4: the x402 payment did not go through (for example no aUSD left)."""

    kind = "payment_failed"
    maybe_paid = False


class VerificationFailed(FetchFailed):
    """Exit 5: unexpected request hash or signer, found after paying. Never submit such a record."""

    kind = "verification_failed"


EXIT_CODES = {2: SetupFailed, 3: NoData, 4: PaymentFailed, 5: VerificationFailed}


def parse_evidence(text: str) -> Evidence:
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        raise FetchFailed("fetch printed nothing")
    try:
        d = json.loads(lines[-1]) if lines[-1].lstrip().startswith("{") else json.loads(text)
        return Evidence(
            source=d["source"],
            supplier_id=d["supplierId"],
            request_hash=d["requestHash"],
            timestamp=int(d["timestamp"]),
            data=d["data"],
            signature=d["signature"],
            raw=d.get("raw") or "",
            payment_tx=d.get("paymentTx"),
            price_usd=float(d.get("priceUsd") or 0),
        )
    except (ValueError, KeyError, TypeError) as e:
        raise FetchFailed("fetch output is not a signed response file: %s" % e)


class Fetcher:
    def __init__(self, cmd: Sequence[str], cwd: Path, timeout: int = 180,
                 runner: Optional[Callable[..., subprocess.CompletedProcess]] = None):
        self.cmd: List[str] = list(cmd)
        self.cwd = cwd
        self.timeout = timeout
        self._run = runner or subprocess.run

    def fetch(self, source: str, supplier_id: str) -> Evidence:
        try:
            res = self._run(self.cmd + [source, supplier_id], capture_output=True, text=True,
                            cwd=str(self.cwd), timeout=self.timeout)
        except subprocess.TimeoutExpired:
            raise FetchFailed("fetch timed out after %ss" % self.timeout)  # not "no data": it may have paid
        except OSError as e:
            raise SetupFailed("cannot run %s: %s" % (self.cmd[0], e))
        if res.returncode != 0:
            reason = ((res.stderr or "").strip().splitlines() or ["exit %d" % res.returncode])[-1][:300]
            raise EXIT_CODES.get(res.returncode, FetchFailed)(reason)
        return parse_evidence(res.stdout)
