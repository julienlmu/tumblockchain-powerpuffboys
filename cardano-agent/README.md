# Cardano agent: paid per verified result (Masumi, preprod)

A Masumi seller agent that only gets paid when it delivers a verified result.
The customer pays tADA into Masumi escrow. The agent runs the job through a gate:

- **passed:** the result hash goes on chain and the escrow releases to the seller.
- **not passed:** no result goes on chain. The buyer requests a refund, the
  agent authorizes it automatically, and the tADA goes back to the buyer.

What "passed" means is up to the app. For SupplierPulse (`docs/SUPPLIERPULSE.md`)
the agent sells the supplier check before a milestone payment. A paid, waiting
or **held** payment is a delivered decision and passes. Only "no verified
decision" (no signed registry data, evidence rejected) ends in a refund. If the
agent were paid only when the supplier is active, it would have a reason to approve.

The work itself is pluggable. An **app** (`apps/*.json`) names an executor
command and the job's input schema. The Cardano side never changes when the
app does.

```
buyer ──start_job──▶ agent.py ──payment request──▶ Masumi payment service
buyer ──purchase (tADA locked in escrow)──▶ Cardano preprod
agent.py ◀─FundsLocked─ payment service
agent.py ──job input──▶ executor (app) ──▶ {"passed": true|false, ...}
  passed:     agent.py ──result hash──▶ Cardano ──▶ escrow releases to seller
  not passed: buyer ──request refund──▶ agent.py authorizes ──▶ tADA back to buyer
```

## Files

- `agent.py`: the seller (MIP-003 API via the `masumi` SDK). `APP_CONFIG` picks the app.
- `gate.py`: runs the executor, retries while it asks to and the deadline allows.
- `refunds.py`: records failed jobs and authorizes their refund requests.
- `masumi_v2.py`: makes `masumi` SDK 1.2.0 work with V2 registrations (what the
  payment service 0.29 creates). It adds `supportedPaymentSourceIndex` to payment and
  purchase requests, and sets the job deadlines from `.env` (`PAY_BY_MINUTES`,
  `SUBMIT_RESULT_MINUTES`, `UNLOCK_AFTER_RESULT_MINUTES`). With the SDK defaults
  the escrow only pays the seller ~30 h after a job; the `.env.example` values make it ~36 min.
- `buy_job.py`: the buyer. Starts a job, pays, waits, requests the refund if the
  job failed, and writes all Cardano tx hashes to `proofs/job-<id>.json`.
- `receipt.py`: completes a proof once the escrow settles. Reads both sides
  (seller's payment, buyer's purchase), lists every tx of the job, and checks on
  chain (Koios) how much the final tx took out of escrow into the selling wallet
  (`sellerReceipt`) or back to the purchasing wallet (`buyerRefund`).
- `apps/mock.json` + `executors/mock.py`: test app. The buyer picks the outcome.
- `apps/supplier-pulse.json` + `executors/supplier_pulse.py`: SupplierPulse. Runs
  the agent script `api3/scripts/supplier-agent.sh` (env `ORDER_ID`,
  `COMPANY_NUMBER`) and maps its outcome to the gate. The script's output format
  is in the executor's docstring.
- `apps/supplier-pulse-sim.json` + `executors/supplier_agent_sim.py`: the same app
  with a **simulated** agent script (no registry call, no EVM tx), to run the
  Cardano side before the contract is deployed. Company `01234567` is active,
  `07654321` dissolved, anything else has no data.
- `apps/eth-vault.json` + `executors/api3_vault.py`: the API3 ETH/USD vault (`api3/`), the fallback.
- `test_gate.py`: tests for the gate and the refund store.

## Executor contract

An executor is any command. It reads the job input as JSON on stdin (env
`ATTEMPT` is the attempt number) and prints, as its last stdout line:

```json
{"passed": true, "retryable": false, "summary": "one line", "evidence": {"txHash": "0x…"}}
```

- `passed` (required): deliver the result and get paid, or not.
- `retryable`: not passed yet, but try again later (for example a condition
  that may still become true). The gate retries every `retry.interval_s` until
  `retry.max_wait_s`, and always stops `submit_margin_s` before Masumi's result deadline.
- A non-zero exit is a technical error. It counts as not passed and retryable.

A new app is one executor plus one `apps/<name>.json` with its `input_schema`
(MIP-003 format).

## Run it (needs Docker, a Blockfrost preprod key and test ADA)

1. Start Masumi locally (payment service and registry):
   ```bash
   git clone https://github.com/masumi-network/masumi-services-dev-quickstart
   cd masumi-services-dev-quickstart && cp .env.example .env
   # set ADMIN_KEY, ENCRYPTION_KEY (openssl rand -hex 32), BLOCKFROST_API_KEY_PREPROD
   docker compose up -d
   docker logs masumi-payment-setup   # save the generated wallet mnemonics offline
   ```
   The compose file binds port 5432. Stop any local PostgreSQL first.
2. Open http://localhost:3001/admin (log in with `ADMIN_KEY`). Fund the
   **purchase** wallet (pays for jobs) and the **selling** wallet (network fees)
   with tADA from the faucet: https://docs.cardano.org/cardano-testnets/tools/faucet (Preprod).
3. Agent setup:
   ```bash
   cd cardano-agent
   python3 -m venv venv && source venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env   # fill PAYMENT_API_KEY, SELLER_VKEY; keep APP_CONFIG=apps/mock.json for the first run
   python -m unittest -v
   ```
4. Expose the agent publicly (needed for Sokosumi), e.g.
   `cloudflared tunnel --url http://localhost:8080`, and register the agent in
   the admin UI with that URL and a price (e.g. 5 ADA). Copy the agent
   identifier into `AGENT_IDENTIFIER`.
5. Run the agent: `python agent.py` (Swagger at http://localhost:8080/docs).
6. Paid job that passes, then one that is refunded:
   ```bash
   python buy_job.py --input '{"task": "demo", "outcome": "pass"}'
   python buy_job.py --input '{"task": "demo", "outcome": "fail"}'
   ```
   SupplierPulse with the simulated script:
   ```bash
   APP_CONFIG=apps/supplier-pulse-sim.json python agent.py
   python buy_job.py --input '{"order_id": 0, "company_number": "07654321"}'   # held: agent paid
   python buy_job.py --input '{"order_id": 0, "company_number": "99999999"}'   # no data: refunded
   ```
   Or hire the agent on Sokosumi preprod and pay there. The refund settles within
   minutes. The seller's payout waits for the unlock time (~36 min with the
   `.env.example` deadlines):
   ```bash
   python receipt.py --wait 3600 proofs/job-<id>.json
   ```
7. Commit `proofs/job-*.json` and copy the tx hashes into `docs/evidence.md`.

Quick test without Masumi: `masumi run agent.py --standalone --input '{"task": "x", "outcome": "pass"}'`.

## Limits

- The agent links the Cardano escrow to the app's work off chain. Both sides
  are verifiable on their explorers, but the agent is trusted to run the check.
- Only failed jobs get automatic refund authorization. A refund request on a
  passed job stays a dispute for a human (Masumi escalates it after the refund time).
- If the on-chain result submission itself fails after a pass, the job is
  marked failed but not recorded as refundable. Authorize that refund in the admin UI.
- `eth-vault` creates a new vault order per attempt, so it does not retry.
- `supplier-pulse` needs `api3/scripts/supplier-agent.sh`, which is not written
  yet. Until then the app retries and refunds every job ("cannot run agent
  script"). Use `supplier-pulse-sim` to test.
