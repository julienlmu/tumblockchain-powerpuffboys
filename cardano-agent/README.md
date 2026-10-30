# Cardano paid agent (Masumi, preprod)

"Conditional Vault Executor": a customer pays tADA to hire the agent with a
condition like "if ETH/USD < 3000, execute the vault action". Masumi locks the
payment in escrow, the agent runs the API3 leg (signed ETH/USD from AirnodeHub
submitted to the vault on Base Sepolia), returns the EVM tx hash as the result,
and the escrow releases to us.

```
buyer ──start_job──▶ agent.py ──payment request──▶ Masumi payment service
buyer ──purchase (tADA locked in escrow)──▶ Cardano preprod
agent.py ◀─FundsLocked─ payment service
agent.py ──API3_SUBMIT_CMD──▶ api3/scripts/agent-run.sh ──▶ vault (Base Sepolia)
agent.py ──result hash──▶ Cardano ──▶ escrow releases to seller
```

## Files

- `agent.py`: seller agent (MIP-003 API via the `masumi` SDK). Input: `threshold_usd`.
- `buy_job.py`: buyer script. Starts a job, pays, waits, and writes the Cardano
  tx hashes to `proofs/job-<id>.json` (qualification evidence).
- `.env.example`: all settings.

## Interface with the API3 side

The agent runs `API3_SUBMIT_CMD` with env `THRESHOLD_USD` (plus `EVM_RPC_URL`,
`EVM_PRIVATE_KEY`, `VAULT_ADDRESS`). The script's last stdout line is JSON:
`{"txHash","price","executed","chainId","vault","orderId"}`; non-zero exit means
the job fails.

## Run it (needs a Blockfrost preprod key and Docker)

1. Start Masumi locally:
   ```bash
   git clone https://github.com/masumi-network/masumi-services-dev-quickstart
   cd masumi-services-dev-quickstart && cp .env.example .env
   # set ADMIN_KEY, ENCRYPTION_KEY (openssl rand -hex 32), BLOCKFROST_API_KEY_PREPROD
   docker compose up -d
   docker logs masumi-payment-setup   # save the generated wallet mnemonics
   ```
2. Open http://localhost:3001/admin (log in with ADMIN_KEY). Fund the
   **purchase** wallet and the **selling** wallet with tADA from the faucet:
   https://docs.cardano.org/cardano-testnets/tools/faucet (choose Preprod).
3. Agent setup:
   ```bash
   cd cardano-agent
   python3 -m venv venv && source venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env   # fill PAYMENT_API_KEY, SELLER_VKEY, EVM vars
   ```
4. Expose the agent publicly (needed for Sokosumi), e.g.
   `cloudflared tunnel --url http://localhost:8080`, and register the agent in
   the admin UI with that URL and a price (e.g. 5 ADA). Copy the agent
   identifier into `AGENT_IDENTIFIER`.
5. Run the agent: `python agent.py` (Swagger at http://localhost:8080/docs).
6. Paid job, scripted: `python buy_job.py --threshold 3000`. Or hire it on
   Sokosumi preprod and pay there.
7. Commit `proofs/job-*.json` and paste the tx hash into the submission.

Quick test without the EVM side: `ALLOW_DRY_RUN=1 masumi run agent.py --standalone --input '{"threshold_usd": 3000}'`.
