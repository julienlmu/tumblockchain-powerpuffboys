#!/usr/bin/env python3
"""Run one paid Cardano job against a SupplierPulse+ v2 order on Ethereum Sepolia.

The Masumi job fee buys a verified decision, not a favorable result. A clean
record can permit or pay a milestone; a valid adverse record can hold it.
Unavailable or rejected evidence produces no decision and the Masumi job can
be refunded.
"""
import json
import sys
from pathlib import Path

API3_AGENT = Path(__file__).resolve().parents[2] / "api3" / "agent"
sys.path.insert(0, str(API3_AGENT))

from chain import Chain, ChainError, Reverted  # noqa: E402
from config import REPO_ROOT, load  # noqa: E402
from evidence import FetchFailed, Fetcher, VerificationFailed  # noqa: E402
from model import ACTIVE, SOURCES  # noqa: E402


RETRYABLE_REVERTS = {"StaleResponse", "FutureResponse"}


def no_decision(outcome, reason):
    return {"outcome": outcome, "reason": reason}


def check_order(order_id, supplier_id, config_loader=load, chain_factory=Chain, fetcher_factory=Fetcher):
    cfg = config_loader()
    chain = chain_factory(cfg.contract, cfg.rpc_urls, cfg.agent_key)

    try:
        order = chain.snapshot().order(order_id)
    except (ChainError, Reverted) as error:
        return no_decision("NoData", f"could not read the order from Ethereum: {error}")
    if order is None:
        return no_decision("Rejected", f"order {order_id} does not exist or is closed")
    if order.state != ACTIVE:
        return no_decision("Rejected", f"order {order_id} is not active")
    if order.supplier_id.strip().upper() != supplier_id.strip().upper():
        return no_decision("Rejected", f"order {order_id} is for a different supplier")

    try:
        fetcher = fetcher_factory(cfg.fetch_cmd, cwd=REPO_ROOT)
        evidence = fetcher.fetch(SOURCES[order.source], order.supplier_id)
    except VerificationFailed as error:
        return no_decision("Rejected", f"registry evidence failed signature/request verification: {error}")
    except FetchFailed as error:
        return no_decision("NoData", f"unable to verify supplier registry data: {error}")

    args = [order.id] + evidence.args
    try:
        result = chain.simulate("checkAndRelease", *args)
        tx_hash = chain.send("checkAndRelease", *args)
    except Reverted as error:
        outcome = "NoData" if error.name in RETRYABLE_REVERTS else "Rejected"
        return no_decision(outcome, f"contract did not accept the evidence: {error}")
    except ChainError as error:
        return no_decision("NoData", f"Ethereum transaction could not be confirmed: {error}")

    value = result[0] if isinstance(result, list) and result else result
    outcome_code = int(str(value).split()[0], 0)
    outcome = chain.outcome_names.get(outcome_code)
    if outcome is None:
        raise ValueError(f"unknown SupplierPulse+ outcome code: {outcome_code}")

    try:
        raw = json.loads(evidence.raw)
    except (TypeError, ValueError):
        raw = {}
    status = raw.get("status", raw.get("entity_status"))
    return {
        "outcome": outcome,
        "txHash": tx_hash,
        "orderId": order_id,
        "status": status,
        "contract": cfg.contract,
        "evidence": {
            "requestHash": evidence.request_hash,
            "timestamp": evidence.timestamp,
            "paymentTx": evidence.payment_tx,
        },
    }


def main():
    try:
        request = json.load(sys.stdin)
        order_id = int(request["order_id"])
        supplier_id = str(request["supplier_id"]).strip().upper()
        if order_id < 0 or not supplier_id:
            raise ValueError("order_id must be non-negative and supplier_id must not be empty")
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps(no_decision("Rejected", f"invalid job input: {error}")))
        return

    print(json.dumps(check_order(order_id, supplier_id)))


if __name__ == "__main__":
    main()
