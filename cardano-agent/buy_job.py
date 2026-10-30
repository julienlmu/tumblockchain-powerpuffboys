#!/usr/bin/env python3
"""Buyer side: hire the agent, pay in tADA on preprod, wait for the result.

This is the scripted alternative to hiring the agent in the Sokosumi UI. It
records every Cardano tx hash of the purchase into proofs/ so we have the
qualification evidence (>= 1 paid job on preprod).

Usage: python buy_job.py --threshold 3000
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


async def main():
    load_dotenv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--threshold", type=float, required=True)
    ap.add_argument("--agent-url", default=os.getenv("AGENT_URL", "http://localhost:8080"))
    ap.add_argument("--timeout", type=int, default=1800, help="seconds to wait for the result")
    args = ap.parse_args()

    network = os.getenv("NETWORK", "Preprod")
    payment_url = os.environ["BUYER_PAYMENT_SERVICE_URL"]
    api_key = os.environ["BUYER_PAYMENT_API_KEY"]
    headers = {"token": api_key}
    purchaser_id = secrets.token_hex(13)  # Masumi requires 14-26 chars
    input_data = {"threshold_usd": args.threshold}

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
        deadline = time.time() + args.timeout
        while time.time() < deadline:
            status = await get_json(session, f"{args.agent_url}/status", params={"job_id": job["id"]})
            print("status:", status.get("status"))
            if status.get("status") in ("completed", "failed"):
                break
            await asyncio.sleep(15)

        p = await find_purchase(session, payment_url, headers, network, job["blockchainIdentifier"])

    proof = {
        "time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "network": network,
        "jobId": job["id"],
        "agentIdentifier": job["agentIdentifier"],
        "blockchainIdentifier": job["blockchainIdentifier"],
        "jobStatus": status.get("status"),
        "result": status.get("result"),
        "purchaseOnChainState": p and p.get("onChainState"),
        "cardanoTxHashes": tx_hashes(p) if p else [],
        "explorer": [f"https://preprod.cardanoscan.io/transaction/{h}" for h in (tx_hashes(p) if p else [])],
    }
    PROOFS.mkdir(exist_ok=True)
    out = PROOFS / f"job-{job['id']}.json"
    out.write_text(json.dumps(proof, indent=2))
    print(json.dumps(proof, indent=2))
    print("saved", out)


if __name__ == "__main__":
    asyncio.run(main())
