# Progress

Living project doc. Read it before you start; update it with every push.

## Plan

**Idea:** a customer hires our agent on Sokosumi with a conditional job, e.g. "if ETH < $3000, execute the vault action". The ADA payment sits in Masumi escrow.

1. Agent receives the job (Masumi/Sokosumi, Cardano preprod).
2. Agent fetches a signed ETH/USD response from API3 AirnodeHub.
3. Agent submits the signed response to our vault contract on an EVM testnet.
4. The contract checks signer, request id, freshness and replay, then acts or refuses.
5. Agent returns the EVM tx hash as the job result and escrow releases the ADA.

**Tracks**
- Cardano "Agentic Commerce": at least 1 paid job on preprod, keep the tx hash. Video: customer, problem, business model, full paid job.
- API3 "Any API in your contract": contract verifies AirnodeHub signed data. Tamper-test video (modified value, stale, other request, wrong key). Judges can submit their own responses via a script.
- TUM track: audit credit, automatic.

**Who does what**
- Cardano payments: Masumi agent, Sokosumi listing, escrow, preprod tx hashes.
- API3 contract: Foundry vault, verification, tamper tests, submit script.
- Video / presentation.

## Interfaces

**Cardano agent to EVM script**
- The agent runs `api3/scripts/agent-run.sh` with `THRESHOLD_USD` set (from the job input `threshold_usd`).
- The last stdout line is JSON: `txHash`, `price`, `executed`, `chainId`, `vault`, `orderId`. The agent returns it as the job result.

**Vault contract** (`api3/src/PriceTriggeredVault.sol`, details in `api3/README.md`)

```solidity
function submitAndTryExecute(
    uint256 orderId,
    bytes32 requestHash,  // AirnodeHub request hash, must be the ETH/USD request
    uint256 timestamp,    // signed timestamp, max 300 s old
    bytes   data,         // exact signed data string, e.g. {"price":2443.95,"updatedAt":1792403240691}
    bytes   signature     // must come from the configured airnode
) external returns (uint256 price, bool executed);
```

Reverts on wrong signer, other request, stale or future timestamp, replayed or older response, edited data. `executed=false` means the price was valid but the condition was not met. `agent-run.sh` creates the order and calls this.

## Proposals to discuss (Julien, 30 Oct)

I checked the plan against the judging criteria in `CLAUDE.md`. The API3 fit is strong. Cardano qualifies, but misses the two things the Cardano judges said they want most: a clear customer, and payment tied to the result. Nothing here is decided. Reply in the log or in person.

1. **Pay only on execution.** `process_job` in `cardano-agent/agent.py` returns a result whatever `executed` is, so the escrow pays us even when nothing happened. Proposal: deliver a result only when `executed=true`. Otherwise let the job run out so the buyer can claim the refund. To ask Masumi: how the refund works when the seller never submits.
2. **Name the customer.** `agent-run.sh` creates and funds the vault order from our own EVM wallet, so the customer's ADA and the vault payout aren't connected. Judges will ask who pays and why on Cardano. Proposed framing: a Cardano-native treasury or user wants an action on an EVM chain when a price condition holds, without running a bot or holding EVM keys and gas. They pay in ADA per job, and only if it executes. Consider taking the beneficiary address from the job input so the payout is theirs.
3. **Watch until a deadline instead of checking once.** Today the job checks the price once and ends if the condition isn't met. A conditional order should wait. Proposal: re-check at a modest interval until the job deadline (Nodary has no rate limit, but cache and don't hammer it). API3 judges reward agents that "act on chain over repeated cycles", and it gives point 1 its meaning.
4. **State the trust assumption in the pitch.** The Cardano escrow and the EVM action are linked only through our agent, not trustlessly (`CLAUDE.md` asks us to say so). Suggested line: "Both legs are verifiable on their explorers, but the agent is the trusted bridge between them."
5. **De-risk the infrastructure.** We need Docker, a public tunnel, two chains and two wallets. To ask Masumi: can a MIP-003 agent registered through our local Masumi node be hired on Sokosumi preprod? The track says "Masumi on Sokosumi". `buy_job.py` stays the fallback for payment evidence.

Points 1 and 3 are a small change in `agent.py`. Points 2 and 4 are mostly pitch. Julien can make the `agent.py` change once Orhun agrees.

## Rules
- Add a log entry below with every push (newest on top).
- No secrets in git (Blockfrost key, private keys, mnemonics). Use `.env`.

## Log

```md
### YYYY-MM-DD · Name
- Changed:
- Next:
- Notes: (tx hashes, addresses, blockers)
```

### 2026-10-30 · Julien (Cardano)
- Changed: `cardano-agent/` is now a generic pay-on-pass agent. What it sells is pluggable: `apps/*.json` plus an executor that prints `{"passed": …}`. Passed: the result goes on chain and the escrow releases. Not passed: no result; the buyer requests a refund and `refunds.py` authorizes it. Apps: `mock` (the buyer picks the outcome, for testing) and `eth-vault` (wraps `api3/scripts/agent-run.sh` and passes only if the vault executed, which is proposal 1). Retry until a deadline is built in (proposal 3), but `eth-vault` doesn't use it because `agent-run.sh` creates a new order per call. `buy_job.py` takes `--input JSON` and requests the refund when a job fails. 10 unit tests (`python -m unittest` in `cardano-agent/`).
- Next: Docker and Masumi services, register the agent, then a first paid job (mock, pass) and one refund (mock, fail) on preprod.
- Notes: the `agent-run.sh` interface is unchanged. A new API3 use case is a new app (executor + config) and needs no Cardano changes; see "Executor contract" in `cardano-agent/README.md`. `ALLOW_DRY_RUN` is gone; use `APP_CONFIG=apps/mock.json` to test without the EVM side.

### 2026-10-30 · Julien
- Changed: added "Proposals to discuss" above (pay on execution, customer story, watch until deadline, trust assumption, infra risk). Earlier push: `CLAUDE.md` with team rules, tracks and coding-agent context.
- Next: agree on the proposals with Orhun, then implement 1 and 3 in `cardano-agent/agent.py`.
- Notes: Sokosumi preprod: CLI 1.0.4 is broken (`404 route_not_found` on Personal Workspace commands), use 1.1.0. Vendor `powerpuffboys` and Coworker `powerpuffboys-agent` are registered on Julien's account (quickstart path, may not be needed for the MIP-003 agent). Julien's laptop: Node 24, Postgres 17, Foundry; no Docker or cloudflared yet.

### 2026-10-30 · Orhun
- Changed: Deployed PriceTriggeredVault on Ethereum Sepolia at 0xBC68DB972A62cFf3161e600d92C475c29c22886A (Nodary signer, max age 300s). Live checks: real ETH/USD response accepted, replay and all four tampered responses (value, stale, request, key) rejected on-chain, agent-run created and executed order 0. Deploy needs `--slow --gas-estimate-multiplier 800`. submit.sh now reads revert errors from newer cast output. README has a Deployment section; .env.example points at Sepolia (Tenderly RPC).
- Next: agent loop (repeated cycles), README "why this data matters" section, tamper-test video.

### 2026-10-30 · Orhun
- Changed: API3: vault now matches the official AirnodeHub starter. Data comes from the Nodary Airnode (free, ETH/USD, signer `0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0`). The contract also rejects a fresh signature over an old price (`updatedAt` check). Deploy uses Nodary defaults. 16 tests pass.
- Notes: a real Nodary ETH/USD response (price 2246.485) was fetched and verified against the Nodary signer; it is now a test (`test_realNodaryResponse`), 17 tests pass. Fixed the `key` tamper mode for Foundry 1.8.x.
- Next: choose the API3 use case (ETH vault, parametric insurance or esports escrow), deploy to Base Sepolia, add a timed loop to the agent for the agent bonus.

### 2026-10-30 · Orhun
- Changed: API3: added `api3/`, a Foundry vault that verifies AirnodeHub signed ETH/USD (signer, request hash, freshness, no replay) and pays out when the price crosses the threshold. 15 tests incl. all tamper cases; `scripts/local-demo.sh` runs the full flow on anvil. `scripts/submit.sh` for judges (tamper modes: value, stale, request, key), `scripts/agent-run.sh` for the Cardano agent.
- Next: fetch a real AirnodeHub response, deploy to Base Sepolia (steps in `api3/README.md`), set `VAULT_ADDRESS` for the agent. Confirm the signing format at the API3 workshop.

### 2026-10-30 · Orhun
- Changed: Cardano: added `cardano-agent/`, a Masumi seller agent (input `threshold_usd`) that runs `api3/scripts/agent-run.sh` after escrow payment and returns the EVM tx hash. `buy_job.py` pays on preprod and saves Cardano tx hashes to `cardano-agent/proofs/`.
- Next: Blockfrost preprod key, Masumi quickstart (Docker), faucet tADA, one paid job.

### 2026-10-30 · Orhun
- Changed: project doc with plan, interfaces and this log; optional pre-push reminder.
- Next: API3: Foundry starter and vault contract draft.
- Notes: turn the reminder on with `git config core.hooksPath .githooks`
