# Cardano pay-on-pass agent (Masumi, preprod)

A Masumi seller agent that only gets paid for work that passed a check. The
customer pays tADA into Masumi escrow. The agent runs the job through a gate:

- **passed:** the result hash goes on chain and the escrow releases to the seller.
- **not passed:** no result goes on chain. The buyer requests a refund, the
  agent authorizes it automatically, and the tADA goes back to the buyer.

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
- `buy_job.py`: the buyer. Starts a job, pays, waits, requests the refund if the
  job failed, and writes all Cardano tx hashes to `proofs/job-<id>.json`.
- `apps/mock.json` + `executors/mock.py`: test app. The buyer picks the outcome.
- `apps/eth-vault.json` + `executors/api3_vault.py`: the API3 ETH/USD vault (`api3/`).
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
   Or hire the agent on Sokosumi preprod and pay there.
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
