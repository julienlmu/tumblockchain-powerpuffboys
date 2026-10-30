#!/usr/bin/env python3
"""Complete a job proof with the escrow's outcome and the on-chain receipt.

buy_job.py writes proofs/job-<id>.json when the job ends, but the escrow keeps
going: after the unlock time the seller's node collects the payment, or after
a refund request the buyer's node takes the tADA back. This script reads both
sides of the job from the payment service (the seller's payment, the buyer's
purchase), lists every Cardano tx of the job, and checks on chain (Koios) how
much the final tx moved into the selling wallet (seller paid) or the
purchasing wallet (refund).

Usage:
  python receipt.py proofs/job-<id>.json [...]              # update now
  python receipt.py --wait 3600 proofs/job-<id>.json        # poll until settled
"""
import argparse
import asyncio
import datetime
import json
import os
import pathlib
import time

import aiohttp
from dotenv import load_dotenv

from masumi_v2 import SOURCE_TYPE

KOIOS = "https://preprod.koios.rest/api/v1"
EXPLORER = "https://preprod.cardanoscan.io/transaction/"
SETTLED = {"Withdrawn", "RefundWithdrawn", "DisputedWithdrawn"}
POLL_S = 30

# side: (list endpoint, response key, service URL env, API key env)
SIDES = {
    "payment": ("/payment/", "Payments", "PAYMENT_SERVICE_URL", "PAYMENT_API_KEY"),
    "purchase": ("/purchase/", "Purchases", "BUYER_PAYMENT_SERVICE_URL", "BUYER_PAYMENT_API_KEY"),
}


async def find(session, side, network, blockchain_identifier):
    """The seller's payment or the buyer's purchase of a job, or None if that side is not configured."""
    path, key, url_env, key_env = SIDES[side]
    if not os.getenv(url_env) or not os.getenv(key_env):
        return None
    async with session.get(
        f"{os.environ[url_env]}{path}",
        headers={"token": os.environ[key_env]},
        params={"network": network, "limit": "100", "includeHistory": "true", "filterPaymentSourceType": SOURCE_TYPE},
    ) as r:
        r.raise_for_status()
        data = await r.json()
    for p in data.get("data", {}).get(key, []):
        if p.get("blockchainIdentifier") == blockchain_identifier:
            return p
    return None


def transactions(*records):
    """All txs of the given payment/purchase records, without duplicates, oldest first."""
    txs = {}
    for rec in records:
        if not rec:
            continue
        for tx in [rec.get("CurrentTransaction")] + (rec.get("TransactionHistory") or []):
            if tx and tx.get("txHash"):
                txs.setdefault(tx["txHash"], tx)
    return sorted(txs.values(), key=lambda t: t.get("blockTime") or float("inf"))


async def payout(session, tx_hash, wallet, escrow):
    """Lovelace the tx took out of the escrow contract, its fee, and the wallet's net change."""
    async with session.post(f"{KOIOS}/tx_info", json={"_tx_hashes": [tx_hash], "_inputs": True}) as r:
        r.raise_for_status()
        found = await r.json()
    if not found:
        return {}
    tx = found[0]

    def total(utxos, address):
        return sum(int(u["value"]) for u in utxos or [] if (u.get("payment_addr") or {}).get("bech32") == address)

    net = total(tx.get("outputs"), wallet) - total(tx.get("inputs"), wallet)
    return {
        "fromEscrowLovelace": total(tx.get("inputs"), escrow),
        "feeLovelace": int(tx["fee"]),
        "netLovelace": net,
        "netAda": net / 1e6,
    }


def _iso(ms):
    return datetime.datetime.fromtimestamp(int(ms) / 1000, datetime.timezone.utc).isoformat() if ms else None


async def complete(session, proof):
    network = proof.get("network", "Preprod")
    bid = proof["blockchainIdentifier"]
    payment = await find(session, "payment", network, bid)
    purchase = await find(session, "purchase", network, bid)
    txs = transactions(purchase, payment)
    # The seller's node settles the escrow, so its view is the most current one.
    state = (payment or purchase or {}).get("onChainState")
    rec = payment or purchase or {}

    proof["purchaseOnChainState"] = purchase and purchase.get("onChainState")
    proof["paymentOnChainState"] = payment and payment.get("onChainState")
    proof["escrow"] = {
        "onChainState": state,
        "settled": state in SETTLED,
        "price": rec.get("RequestedFunds") or rec.get("PaidFunds"),
        "unlockTime": _iso(rec.get("unlockTime")),
        "withdrawnForSeller": rec.get("WithdrawnForSeller"),
        "withdrawnForBuyer": rec.get("WithdrawnForBuyer"),
    }
    proof["transactions"] = [
        {"txHash": t["txHash"], "onChainState": t.get("newOnChainState"), "explorer": EXPLORER + t["txHash"]}
        for t in txs
    ]
    proof["cardanoTxHashes"] = [t["txHash"] for t in txs]
    proof["explorer"] = [EXPLORER + t["txHash"] for t in txs]

    final = next((t for t in reversed(txs) if t.get("newOnChainState") == state), None)
    # SmartContractWallet is the node's own hot wallet for this job: selling wallet
    # on the payment, purchasing wallet on the purchase.
    for key, wanted, side in (("sellerReceipt", "Withdrawn", payment), ("buyerRefund", "RefundWithdrawn", purchase)):
        wallet = side and (side.get("SmartContractWallet") or {}).get("walletAddress")
        if state != wanted or not final or not wallet:
            continue
        escrow = (rec.get("PaymentSource") or {}).get("smartContractAddress")
        try:
            amounts = await payout(session, final["txHash"], wallet, escrow)
        except aiohttp.ClientError as e:
            print("koios lookup failed:", e)
            amounts = {}
        proof[key] = {"wallet": wallet, "txHash": final["txHash"], **amounts, "explorer": EXPLORER + final["txHash"]}
    if state == "RefundWithdrawn":
        proof["outcome"] = "refunded"
    proof["checkedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return proof


async def main():
    load_dotenv(pathlib.Path(__file__).with_name(".env"))
    ap = argparse.ArgumentParser()
    ap.add_argument("proofs", nargs="+", type=pathlib.Path, help="proofs/job-<id>.json files to complete")
    ap.add_argument("--wait", type=int, default=0, metavar="SECONDS", help="poll until the escrow is settled, up to SECONDS")
    args = ap.parse_args()
    deadline = time.time() + args.wait

    async with aiohttp.ClientSession() as session:
        for path in args.proofs:
            while True:
                proof = await complete(session, json.loads(path.read_text()))
                path.write_text(json.dumps(proof, indent=2))
                print(f"{path.name}: {proof['escrow']['onChainState']}, {len(proof['cardanoTxHashes'])} tx")
                if proof["escrow"]["settled"] or time.time() >= deadline:
                    break
                await asyncio.sleep(POLL_S)
            for key in ("sellerReceipt", "buyerRefund"):
                if key in proof:
                    r = proof[key]
                    print(f"  {key}: {r.get('fromEscrowLovelace', 0) / 1e6} tADA out of escrow, "
                          f"wallet net {r.get('netAda')} tADA after fees, tx {r['explorer']}")


if __name__ == "__main__":
    asyncio.run(main())
