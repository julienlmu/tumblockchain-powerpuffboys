"""Seller-side refunds for work that did not pass the gate.

When a job fails, agent.py records its Masumi payment id (blockchainIdentifier)
here. The buyer then requests a refund (buy_job.py does this automatically).
The guard loop finds those payments in state RefundRequested on our payment
service and authorizes the refund, so the buyer gets the escrowed ADA back.

Only recorded payments are authorized. A refund request on work that passed
stays a dispute for a human to look at.
"""
import asyncio
import json
import logging
import pathlib
import threading
import time

import aiohttp

from masumi_v2 import SOURCE_TYPE

logger = logging.getLogger("refunds")

STATE = pathlib.Path(__file__).resolve().parent / "state" / "refundable.json"


class RefundStore:
    """Small JSON file: {blockchainIdentifier: {reason, markedAt, authorizedAt}}."""

    def __init__(self, path=STATE):
        self.path = pathlib.Path(path)
        self._lock = threading.Lock()

    def _read(self) -> dict:
        return json.loads(self.path.read_text()) if self.path.exists() else {}

    def _write(self, data: dict) -> None:
        self.path.parent.mkdir(exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, indent=2))
        tmp.replace(self.path)

    def mark(self, payment_id: str, reason: str) -> None:
        with self._lock:
            data = self._read()
            data.setdefault(payment_id, {"reason": reason[:500], "markedAt": time.time(), "authorizedAt": None})
            self._write(data)

    def pending(self) -> set:
        with self._lock:
            return {k for k, v in self._read().items() if not v.get("authorizedAt")}

    def mark_authorized(self, payment_id: str) -> None:
        with self._lock:
            data = self._read()
            if payment_id in data:
                data[payment_id]["authorizedAt"] = time.time()
                self._write(data)


async def authorize_requested(session, payment_url: str, api_key: str, network: str, store: RefundStore) -> int:
    """One pass: authorize every recorded payment that the buyer asked to refund."""
    pending = store.pending()
    if not pending:
        return 0
    headers = {"token": api_key}
    async with session.get(
        f"{payment_url}/payment/",
        headers=headers,
        params={
            "network": network,
            "filterOnChainState": "RefundRequested",
            "filterPaymentSourceType": SOURCE_TYPE,
            "limit": "100",
        },
    ) as r:
        r.raise_for_status()
        payments = (await r.json()).get("data", {}).get("Payments", [])
    done = 0
    for p in payments:
        bid = p.get("blockchainIdentifier")
        action = (p.get("NextAction") or {}).get("requestedAction")
        if bid not in pending or action != "WaitingForExternalAction":
            continue
        async with session.post(
            f"{payment_url}/payment/authorize-refund",
            headers=headers,
            json={"network": network, "blockchainIdentifier": bid},
        ) as r:
            if r.status == 200:
                store.mark_authorized(bid)
                done += 1
                logger.info("refund authorized for %s…", bid[:16])
            else:
                logger.warning("authorize-refund %s… failed: %s %s", bid[:16], r.status, (await r.text())[:300])
    return done


async def guard(payment_url: str, api_key: str, network: str, store: RefundStore, interval_s: int) -> None:
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                await authorize_requested(session, payment_url, api_key, network, store)
            except Exception as e:  # keep guarding; the payment service may be restarting
                logger.warning("refund guard pass failed: %s", e)
            await asyncio.sleep(interval_s)


def start_guard_thread(payment_url: str, api_key: str, network: str, store: RefundStore, interval_s: int) -> None:
    """masumi.run() owns the main event loop, so the guard gets its own thread and loop."""
    t = threading.Thread(
        target=lambda: asyncio.run(guard(payment_url, api_key, network, store, interval_s)),
        name="refund-guard",
        daemon=True,
    )
    t.start()
    logger.info("refund guard running every %ss", interval_s)
