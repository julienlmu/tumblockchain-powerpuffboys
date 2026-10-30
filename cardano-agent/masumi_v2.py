"""Compatibility patch: masumi SDK 1.2.0 with V2 agent registrations.

Agents registered through the current Masumi payment service (0.29) get a V2
registry entry, whose payment options are priced independently. The service
then requires supportedPaymentSourceIndex on every payment request, which SDK
1.2.0 (the latest release) never sends. V2Payment adds it, and install() makes
the SDK's server use it.

The seller signs the job terms including that index, and the service rebuilds
the terms from the buyer's purchase request to check the signature. So the
buyer must send the same index: use V2Purchase instead of Purchase. Both sides
read PAYMENT_SOURCE_INDEX (default 0, the registration's first payment option).
"""
import os
from datetime import datetime, timedelta, timezone

import aiohttp
import masumi.server
from masumi.payment import Payment
from masumi.purchase import Purchase

SOURCE_INDEX = int(os.getenv("PAYMENT_SOURCE_INDEX", "0"))  # position in the registration's payment options
# List endpoints (GET /payment/, /purchase/) default to V1 unless filtered by this.
SOURCE_TYPE = "Web3CardanoV2"


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def _minutes(name: str):
    value = os.getenv(name, "").strip()
    return timedelta(minutes=int(value)) if value else None


class V2Payment(Payment):
    """Payment request with the V2 source index and configurable deadlines.

    Service rules (0.29): submit result >= now + 15 min, pay by <= submit - 5 min,
    unlock >= submit + 15 min, external dispute >= unlock + 15 min. Without
    UNLOCK_AFTER_RESULT_MINUTES the service unlocks 6 h after the result
    deadline, so the seller only gets paid hours later.
    """

    pay_by = _minutes("PAY_BY_MINUTES") or timedelta(hours=12)  # SDK default
    submit_result_by = _minutes("SUBMIT_RESULT_MINUTES") or timedelta(hours=24)  # SDK default
    unlock_after_result = _minutes("UNLOCK_AFTER_RESULT_MINUTES")
    dispute_after_unlock = _minutes("DISPUTE_AFTER_UNLOCK_MINUTES")

    async def create_payment_request(self, metadata=None):
        now = datetime.now(timezone.utc)
        submit = now + self.submit_result_by
        payload = {
            "agentIdentifier": self.agent_identifier,
            "network": self.network,
            "payByTime": _iso(now + self.pay_by),
            "submitResultTime": _iso(submit),
            "identifierFromPurchaser": self.identifier_from_purchaser,
            "supportedPaymentSourceIndex": SOURCE_INDEX,
        }
        if self.unlock_after_result:
            unlock = submit + self.unlock_after_result
            payload["unlockTime"] = _iso(unlock)
            payload["externalDisputeUnlockTime"] = _iso(unlock + (self.dispute_after_unlock or timedelta(minutes=15)))
        if self.input_hash:
            payload["inputHash"] = self.input_hash
        if metadata:
            payload["metadata"] = metadata
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.config.payment_service_url}/payment/", headers=self._headers, json=payload
            ) as r:
                if r.status != 200:
                    raise ValueError(f"Payment request failed: {r.status} {await r.text()}")
                result = await r.json()
        self.payment_ids.add(result["data"]["blockchainIdentifier"])
        result["time_values"] = {
            k: result["data"][k] for k in ("payByTime", "submitResultTime", "unlockTime", "externalDisputeUnlockTime")
        }
        return result


class V2Purchase(Purchase):
    async def create_purchase_request(self):
        payload = {
            "identifierFromPurchaser": self.identifier_from_purchaser,
            "network": self.network,
            "sellerVkey": self.seller_vkey,
            "paymentSourceType": SOURCE_TYPE,
            "blockchainIdentifier": self.blockchain_identifier,
            "payByTime": str(self.pay_by_time),
            "submitResultTime": str(self.submit_result_time),
            "unlockTime": str(self.unlock_time),
            "externalDisputeUnlockTime": str(self.external_dispute_unlock_time),
            "agentIdentifier": self.agent_identifier,
            "supportedPaymentSourceIndex": SOURCE_INDEX,
        }
        if self.input_hash:
            payload["inputHash"] = self.input_hash
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.config.payment_service_url}/purchase/", headers=self._headers, json=payload
            ) as r:
                if r.status != 200:
                    raise ValueError(f"Purchase request failed: {r.status} {await r.text()}")
                return await r.json()


def install() -> None:
    """Make the SDK's /start_job create V2 payment requests."""
    masumi.server.Payment = V2Payment
