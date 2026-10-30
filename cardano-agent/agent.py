#!/usr/bin/env python3
"""Masumi seller agent: "Conditional Vault Executor".

A customer hires this agent on Sokosumi (or via buy_job.py) and pays in ADA on
Cardano preprod. The Masumi escrow holds the payment. Once the payment is
confirmed, process_job runs: it asks the API3 side to fetch a signed ETH/USD
value from AirnodeHub and submit it to the EVM vault, which only acts when the
condition holds. The EVM tx hash is returned as the job result, the result hash
is submitted on Cardano, and the escrow releases to the seller.
"""
import asyncio
import json
import logging
import os
import shlex

from masumi import run

logger = logging.getLogger("vault-agent")

INPUT_SCHEMA = {
    "input_data": [
        {
            "id": "threshold_usd",
            "type": "number",
            "name": "ETH/USD threshold",
            "data": {"description": "Execute the vault action if ETH/USD is below this value"},
            "validations": [{"validation": "min", "value": "1"}],
        }
    ]
}


async def run_api3_submit(threshold_usd: int) -> dict:
    """Run the API3 submit CLI and parse the JSON line it prints last.

    Contract with the API3 side: env THRESHOLD_USD in, last stdout line is
    {"txHash", "price", "executed", "chainId", "vault"}; non-zero exit on failure.
    """
    cmd = os.getenv("API3_SUBMIT_CMD")
    if not cmd:
        if os.getenv("ALLOW_DRY_RUN") == "1":
            return {"txHash": None, "price": None, "executed": False, "dryRun": True}
        raise RuntimeError("API3_SUBMIT_CMD is not set (set ALLOW_DRY_RUN=1 to test without the EVM side)")

    env = {**os.environ, "THRESHOLD_USD": str(threshold_usd)}
    proc = await asyncio.create_subprocess_exec(
        *shlex.split(cmd),
        env=env,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=int(os.getenv("API3_TIMEOUT_S", "300")))
    if proc.returncode != 0:
        raise RuntimeError(f"API3 submit failed ({proc.returncode}): {stderr.decode()[-2000:]}")
    lines = [l for l in stdout.decode().splitlines() if l.strip()]
    if not lines:
        raise RuntimeError("API3 submit printed nothing")
    return json.loads(lines[-1])


async def process_job(identifier_from_purchaser: str, input_data: dict) -> str:
    threshold = int(float(input_data["threshold_usd"]))
    logger.info("job %s: threshold %s", identifier_from_purchaser, threshold)
    evm = await run_api3_submit(threshold)
    result = {
        "condition": f"ETH/USD < {threshold}",
        "ethUsd": evm.get("price"),
        "vaultExecuted": evm.get("executed"),
        "evmTxHash": evm.get("txHash"),
        "chainId": evm.get("chainId"),
        "vault": evm.get("vault"),
        "orderId": evm.get("orderId"),
        "dryRun": evm.get("dryRun", False),
    }
    # Masumi expects a string result; it hashes it and submits the hash on-chain.
    return json.dumps(result)


if __name__ == "__main__":
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
    run(start_job_handler=process_job, input_schema_handler=INPUT_SCHEMA)
