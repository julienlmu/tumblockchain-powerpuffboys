#!/usr/bin/env python3
"""Masumi seller agent with pay-on-pass escrow.

A customer hires this agent on Sokosumi (or via buy_job.py) and pays in ADA on
Cardano preprod. Masumi locks the payment in escrow. Once the funds are
locked, process_job runs the selected app's executor through the gate
(gate.py):

- passed: the result is returned, Masumi submits its hash on chain, and the
  escrow releases to us after the unlock time.
- not passed (after any retries, before the deadline): no result goes on
  chain. The job is recorded as refundable and refunds.py authorizes the
  buyer's refund request, so the customer only pays for a delivered result.

What counts as passed is the app's call. For SupplierPulse, any verified
decision passes, including a held payment (see executors/supplier_pulse.py).
APP_CONFIG selects the app (default apps/mock.json).
"""
import json
import logging
import os
import pathlib
import time

from dotenv import load_dotenv

load_dotenv(pathlib.Path(__file__).with_name(".env"))

from masumi import run  # noqa: E402

import masumi_v2  # noqa: E402
import refunds  # noqa: E402
from gate import deadline_for, load_app, run_gate  # noqa: E402

masumi_v2.install()

logger = logging.getLogger("pay-on-pass-agent")

APP = load_app(os.getenv("APP_CONFIG", "apps/mock.json"))
INPUT_SCHEMA = APP.input_schema
STORE = refunds.RefundStore()


class GateFailed(RuntimeError):
    pass


async def current_job():
    """The SDK's record of the running job, or None in standalone mode."""
    try:
        from masumi.hitl import _job_context  # masumi 1.2.0 sets this before calling process_job
    except ImportError:
        return None
    ctx = _job_context.get()
    if not ctx:
        return None
    return await ctx["job_manager"].get_job(ctx["job_id"])


async def process_job(identifier_from_purchaser: str, input_data: dict) -> str:
    job = await current_job()
    payment_id = job.get("payment_id") if job else None
    deadline = deadline_for(APP, job.get("submit_result_time") if job else None)
    logger.info("job %s: app %s, input %s", identifier_from_purchaser, APP.name, json.dumps(input_data)[:300])
    try:
        verdict, attempts = await run_gate(APP, input_data, deadline, log=logger.info)
        if not verdict.passed:
            raise GateFailed(f"did not pass after {len(attempts)} attempt(s): {verdict.summary}")
    except Exception as e:
        # Raising makes the SDK mark the job failed without an on-chain result.
        if payment_id:
            STORE.mark(payment_id, str(e))
        raise
    result = {
        "app": APP.name,
        "passed": True,
        "summary": verdict.summary,
        "evidence": verdict.evidence,
        "attempts": len(attempts),
        "checkedAt": int(time.time()),
    }
    # Masumi expects a string result; it hashes it and submits the hash on chain.
    return json.dumps(result)


if __name__ == "__main__":
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
    if os.getenv("MASUMI_STANDALONE") != "1" and os.getenv("PAYMENT_API_KEY"):
        refunds.start_guard_thread(
            os.getenv("PAYMENT_SERVICE_URL", "http://localhost:3001/api/v1"),
            os.environ["PAYMENT_API_KEY"],
            os.getenv("NETWORK", "Preprod"),
            STORE,
            int(os.getenv("REFUND_GUARD_INTERVAL_S", "15")),
        )
    logger.info("selling app %s: %s", APP.name, APP.description)
    run(start_job_handler=process_job, input_schema_handler=INPUT_SCHEMA)
