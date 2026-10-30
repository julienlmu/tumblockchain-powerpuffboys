#!/usr/bin/env python3
"""Executor for the API3 ETH/USD vault (api3/scripts/agent-run.sh).

Input: {"threshold_usd": number}. Passes if the vault executed the order.
Needs EVM_RPC_URL, EVM_PRIVATE_KEY and VAULT_ADDRESS (see api3/README.md).
agent-run.sh creates a new order on every call, so this executor never asks
for a retry.
"""
import json
import os
import pathlib
import subprocess
import sys

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "api3" / "scripts" / "agent-run.sh"
FIELDS = ("txHash", "price", "executed", "chainId", "vault", "orderId")


def main():
    threshold = int(float(json.load(sys.stdin)["threshold_usd"]))
    proc = subprocess.run(
        [str(SCRIPT)],
        env={**os.environ, "THRESHOLD_USD": str(threshold)},
        capture_output=True,
        text=True,
    )
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        sys.exit(proc.returncode)
    lines = [l for l in proc.stdout.splitlines() if l.strip()]
    evm = json.loads(lines[-1])
    executed = bool(evm.get("executed"))
    print(json.dumps({
        "passed": executed,
        "retryable": False,
        "summary": f"ETH/USD {evm.get('price')} vs threshold {threshold}: vault {'executed' if executed else 'not executed'}",
        "evidence": {k: evm.get(k) for k in FIELDS},
    }))


if __name__ == "__main__":
    main()
