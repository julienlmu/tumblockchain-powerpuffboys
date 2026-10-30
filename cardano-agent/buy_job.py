#!/usr/bin/env python3
"""Buyer side: hire the agent, pay in tADA on preprod, get the result or a refund.

This is the scripted alternative to hiring the agent in the Sokosumi UI. If the
work passes, the escrow releases to the seller. If it does not pass, this
script requests a refund, the seller's refund guard authorizes it, and the
escrowed tADA returns to the buyer. Every Cardano tx hash of the purchase goes
into proofs/ as qualification evidence.

Usage:
  python buy_job.py --input '{"task": "demo", "outcome": "pass"}'   # apps/mock.json
  python buy_job.py --input '{"threshold_usd": 3000}'               # apps/eth-vault.json
"""
import argparse
import asyncio
import datetime
import json
import os
import pathlib
import secrets
import time

import aiohttp
from dotenv import load_dotenv
from masumi import Config, Purchase

PROOFS = pathlib.Path(__file__).parent / "proofs"
REFUNDED = {"RefundWithdrawn"}
POLL_S = 15


async def get_json(session, url, **kw):
    async with session.get(url, **kw) as r:
        r.raise_for_status()
        return await r.json()


async def find_purchase(session, payment_url, headers, network, blockchain_identifier):
    data = await get_json(
        session,
        f"{payment_url}/purchase/",
        headers=headers,
        params={"network": network, "limit": "50", "includeHistory": "true"},
    )
    for p in data.get("data", {}).get("Purchases", []):
        if p.get("blockchainIdentifier") == blockchain_identifier:
            return p
    return None


def tx_hashes(purchase):
    hashes = []
    for tx in [purchase.get("CurrentTransaction")] + (purchase.get("TransactionHistory") or []):
        if tx and tx.get("txHash") and tx["txHash"] not in hashes:
            hashes.append(tx["txHash"])
    return hashes


async def request_refund(purchase, deadline):
    """The buyer's node accepts the request once it sees the funds locked; retry until then."""
    while time.time() < deadline:
        try:
            await purchase.request_refund()
            return True
        except Exception as e:
            print("refund request not accepted yet:", str(e)[:200])
            await asyncio.sleep(POLL_S)
    return False


async def main():
    load_dotenv(pathlib.Path(__file__).with_name(".env"))
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="job input as JSON, matching the app's input schema")
    ap.add_argument("--agent-url", default=os.getenv("AGENT_URL", "http://localhost:8080"))
    ap.add_argument("--timeout", type=int, default=1800, help="seconds to wait for the result or refund")
    ap.add_argument("--no-refund", action="store_true", help="do not request a refund if the job fails")
    args = ap.parse_args()

    network = os.getenv("NETWORK", "Preprod")
    payment_url = os.environ["BUYER_PAYMENT_SERVICE_URL"]
    api_key = os.environ["BUYER_PAYMENT_API_KEY"]
    headers = {"token": api_key}
    purchaser_id = secrets.token_hex(13)  # Masumi requires 14-26 chars
    input_data = json.loads(args.input)
    deadline = time.time() + args.timeout

    async with aiohttp.ClientSession() as session:
        async with session.post(
            f"{args.agent_url}/start_job",
            json={"identifier_from_purchaser": purchaser_id, "input_data": input_data},
        ) as r:
            if r.status != 200:
                raise SystemExit(f"start_job failed: {r.status} {await r.text()}")
            job = await r.json()
        print("job started:", job["id"])

        purchase = Purchase(
            config=Config(payment_service_url=payment_url, payment_api_key=api_key),
            blockchain_identifier=job["blockchainIdentifier"],
            seller_vkey=job["sellerVKey"],
            agent_identifier=job["agentIdentifier"],
            pay_by_time=job["payByTime"],
            submit_result_time=job["submitResultTime"],
            unlock_time=job["unlockTime"],
            external_dispute_unlock_time=job["externalDisputeUnlockTime"],
            identifier_from_purchaser=purchaser_id,
            network=network,
            input_data=input_data,
        )
        await purchase.create_purchase_request()
        print("purchase created, funds will be locked in escrow")

        status = {}
        while time.time() < deadline:
            status = await get_json(session, f"{args.agent_url}/status", params={"job_id": job["id"]})
            print("job status:", status.get("status"))
            if status.get("status") in ("completed", "failed"):
                break
            await asyncio.sleep(POLL_S)

        outcome = {"completed": "paid", "failed": "not passed"}.get(status.get("status"), "timed out")
        if status.get("status") == "failed" and not args.no_refund:
            if await request_refund(purchase, deadline):
                print("refund requested, waiting for the seller to authorize and the escrow to pay back")
                outcome = "refund requested"
                while time.time() < deadline:
                    p = await find_purchase(session, payment_url, headers, network, job["blockchainIdentifier"])
                    state = p and p.get("onChainState")
                    print("purchase state:", state)
                    if state in REFUNDED:
                        outcome = "refunded"
                        break
                    await asyncio.sleep(POLL_S)

        p = await find_purchase(session, payment_url, headers, network, job["blockchainIdentifier"])

    hashes = tx_hashes(p) if p else []
    proof = {
        "time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "network": network,
        "outcome": outcome,
        "jobId": job["id"],
        "agentIdentifier": job["agentIdentifier"],
        "blockchainIdentifier": job["blockchainIdentifier"],
        "input": input_data,
        "jobStatus": status.get("status"),
        "result": status.get("result"),
        "purchaseOnChainState": p and p.get("onChainState"),
        "cardanoTxHashes": hashes,
        "explorer": [f"https://preprod.cardanoscan.io/transaction/{h}" for h in hashes],
    }
    PROOFS.mkdir(exist_ok=True)
    out = PROOFS / f"job-{job['id']}.json"
    out.write_text(json.dumps(proof, indent=2))
    print(json.dumps(proof, indent=2))
    print("saved", out)


if __name__ == "__main__":
    asyncio.run(main())
