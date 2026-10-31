#!/usr/bin/env python3
"""Executor for SupplierPulse (docs/SUPPLIERPULSE.md): paid for a verified decision.

Input: {"order_id": number, "company_number": str} for the legacy app, or
{"order_id": number, "supplier_id": str} for SupplierPulse+.
Usage (from an app config): supplier_pulse.py AGENT_CMD [ARG ...]

AGENT_CMD is the SupplierPulse agent script. It gets ORDER_ID and
COMPANY_NUMBER in its environment, fetches the signed registry profile,
submits it with checkAndRelease, and prints as its last stdout line:
  {"outcome": "Paid" | "AwaitingApproval" | "NotDue" | "Held", "txHash": "0x…", "orderId": 0,
   "milestone": 0, "status": "active", "chainId": 11155111, "contract": "0x…"}
or {"outcome": "NoData" | "Rejected", "reason": "…"} when it reached no decision.

The agent sells the check, not an approval: Paid, AwaitingApproval and Held
are all delivered decisions and pass the gate. A held payment is the job done
right. If paying depended on "active", the agent would have a reason to approve.
NoData (or a failed script) retries until the deadline; Rejected (the contract
refused the evidence) is final. Both end without a result, so the buyer is refunded.
"""
import json
import math
import os
import subprocess
import sys

DECISIONS = {
    "Paid": "milestone {milestone} paid to the supplier",
    "AwaitingApproval": "payment permit issued, waiting for the buyer's approval",
    "NotDue": "fresh evidence accepted; the next milestone is not due yet",
    "Held": "payment held, the remaining balance stays locked for the buyer",
}
EXPLORERS = {11155111: "https://sepolia.etherscan.io/tx/"}
FIELDS = ("outcome", "txHash", "orderId", "milestone", "status", "chainId", "contract", "simulated", "evidence")


def verdict(passed, retryable, summary, evidence):
    print(json.dumps({"passed": passed, "retryable": retryable, "summary": summary, "evidence": evidence}))


def main():
    try:
        data = json.load(sys.stdin)
        raw_order_id = data["order_id"]
        if (
            isinstance(raw_order_id, bool)
            or not isinstance(raw_order_id, (int, float))
            or (
                isinstance(raw_order_id, float)
                and (not math.isfinite(raw_order_id) or not raw_order_id.is_integer())
            )
        ):
            raise ValueError("order_id must be an integer")
        order_id = int(raw_order_id)
        raw_supplier_id = data.get("supplier_id", data.get("company_number", ""))
        if not isinstance(raw_supplier_id, str) or not raw_supplier_id.strip():
            raise ValueError("supplier identifier is required")
        supplier_id = raw_supplier_id.strip().upper()
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        return verdict(False, False, f"invalid job input: {error}", {"outcome": "Rejected"})
    job = f"order {order_id}, supplier {supplier_id}"
    try:
        proc = subprocess.run(
            sys.argv[1:],
            env={**os.environ, "ORDER_ID": str(order_id), "COMPANY_NUMBER": supplier_id,
                 "SUPPLIER_ID": supplier_id},
            capture_output=True,
            text=True,
        )
    except OSError as e:
        return verdict(False, True, f"{job}: no verified decision (cannot run agent script: {e})", {"outcome": "NoData"})
    sys.stderr.write(proc.stderr)
    lines = [l for l in proc.stdout.splitlines() if l.strip()]
    if proc.returncode != 0 or not lines:
        reason = (proc.stderr.strip().splitlines() or ["agent script failed"])[-1]
        return verdict(False, True, f"{job}: no verified decision ({reason[:200]})", {"outcome": "NoData"})

    out = json.loads(lines[-1])
    outcome = out.get("outcome")
    evidence = {k: out[k] for k in FIELDS if k in out}
    if out.get("txHash") and out.get("chainId") in EXPLORERS:
        evidence["explorer"] = EXPLORERS[out["chainId"]] + out["txHash"]
    if outcome in DECISIONS:
        what = DECISIONS[outcome].format(milestone=out.get("milestone"))
        return verdict(True, False, f"{job}: registry status '{out.get('status')}', {what}", evidence)
    reason = out.get("reason", "no decision")
    return verdict(False, outcome != "Rejected", f"{job}: {outcome or 'NoData'} ({reason})", evidence)


if __name__ == "__main__":
    main()
