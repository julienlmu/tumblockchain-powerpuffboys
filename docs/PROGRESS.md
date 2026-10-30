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

**Cardano agent to SupplierPulse agent script** (`cardano-agent/executors/supplier_pulse.py`, app `apps/supplier-pulse.json`)
- The agent runs `api3/scripts/supplier-agent.sh` (cwd `cardano-agent/`) with `ORDER_ID` and `COMPANY_NUMBER` set from the job input (`order_id`, `company_number`). The EVM and x402 vars come from `cardano-agent/.env`.
- The script fetches the signed company profile, calls `checkAndRelease` and logs to stderr. The last stdout line is JSON:
  - decision: `{"outcome": "Paid" | "AwaitingApproval" | "Held", "txHash": "0x…", "orderId": 0, "milestone": 0, "status": "active", "chainId": 11155111, "contract": "0x…"}`. The agent is paid.
  - no decision: `{"outcome": "NoData", "reason": "…"}` or exit ≠ 0 (retried until the job deadline), or `{"outcome": "Rejected", "reason": "WrongRequest"}` for a verification revert (final). The buyer is refunded.

**Cardano agent to EVM script (ETH vault, fallback)**
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

### 2026-10-30 · Emre · C1a: live fields verified, paid fetch, fixtures
- Changed: **All §4.2 pointers verified live** (Companies House and GLEIF): request hashes and signers match, no interface change. `api3/scripts/fetch-evidence.sh <ch|gleif> <id> [out.json]` (paid, x402) with the §4.7 exit codes. Real signed fixtures in `api3/fixtures/`. Results in `docs/data-sources.md`.
- Next: a clean UK company for order A, then `plus-submit.sh` (needs Foundry).
- Notes:
  - **Orhun / Ulaş: `09729896` is NOT clean.** Its signed record has accounts and confirmation statement overdue, so order A with rules `0x07` would be held. It fits order C (rules `0x02`) instead. Order A still needs a clean company; I'm looking.
  - `12493325` has no `/accounts/overdue` → HTTP 400, no data (the §9 risk is real for some companies). 4xx answers are not charged.
  - Demo picks: B `07418033`, C `09729896`, D `391200JI69LS8L648F30` (ASR Component GmbH, ACTIVE/ISSUED), E `52990092KBQJF8QBGJ50` (MoKa Projekt GmbH, LAPSED).
  - Spent $0.04 of the $0.60 budget.

### 2026-10-30 · Emre · verify and tamper tools (§6.2)
- Changed: `node api3/x402/verify.mjs <file> [--max-age 300] [--local]` runs the contract's checks off chain (signer per source, request hash, age, projected fields) and prints a table; exit 0 valid, 1 invalid. `node api3/x402/tamper.mjs <file> <value|stale|request|key|replay>` writes the tampered record with the §4.7 semantics (value edits only the one field, the other bytes stay as signed). Tests: 11/11 in `test-requests.mjs`.
- Next: live calls (C1a), `fetch-evidence.sh`, `plus-submit.sh`.
- Notes: Batu, the judge page can copy `tamper.mjs` logic 1:1 (it only uses viem functions that have ethers equivalents).

### 2026-10-30 · Emre · SupplierPulse+ data layer, local signer (§6.2)
- Changed: started §6.2 on `emre/plus-data`.
  - `api3/x402/requests.mjs`: sources, request bodies, request hashes, supplier keys and the §4.3 rule evaluation. `node api3/x402/test-requests.mjs` asserts all §4.2 vectors (8/8 pass).
  - Local signer for everyone, free: `api3/scripts/fetch-local.sh <ch|gleif> <id> [out.json]` (from `api3/x402/local-registry.json`, §4.8) and `node api3/x402/sign-local.mjs <ch|gleif> <id> '<data json>' [timestamp]`. Output is the §4.1 format, signed by anvil #1 (CH) / #2 (GLEIF). Unknown id exits 3.
- Next: live calls to verify the §4.2 pointers (C1a, ~$0.04, needs team OK and aUSD), fixtures, then `airnode-fetch.mjs`/`fetch-evidence.sh`, `verify.mjs`, `tamper.mjs`, `plus-submit.sh`.
- Notes: the §4.2 pointers are still unverified live. Until then everything matches the spec as written.

### 2026-10-30 · Julien · SupplierPulse+ build spec
- Changed: `docs/SUPPLIERPULSE_PLUS.md` is the complete build spec for SupplierPulse+ (API3 track only, decided ~16:00). It contains:
  - frozen interfaces: contract ABI, request templates with test vectors, signed fields and rules, CLI tools, a local test chain;
  - five workstreams that don't block each other: Orhun the contract, Emre the data layer and judge CLI, Julien the agent, Batu the dashboard and judge page, Ulaş the story and submission;
  - checkpoints C0 to C7, the Sepolia launch runbook, the submission checklist and the risks.

  It supersedes the scope of `docs/SUPPLIER_PULSE_SPEC.md`; that file's demo ideas are included. Process ideas from Batu's subcontractor-agent design are adopted: the hero frame, a cross-review, pre-run proofs, claim limits. **New integration branch: `supplierpulse-plus`.** Also adds a grill-me skill under `.claude/skills/grillme/`.
- Next: everyone reads §0 to §5 and their own §6 section, then creates a personal branch from `supplierpulse-plus` (C0).
- Notes: two open points.
  - The Companies House and GLEIF field paths in §4.2 are not yet verified live. Emre checks them by C1a (18:30).
  - The agent wallet `0xED34…253a` needs at least 2 aUSD by C3.

### 2026-10-30 · Orhun
- Changed: docs/SUPPLIER_PULSE_SPEC.md: next-iteration spec (3-milestone demo, permit fields, dashboard, hack simulator, 48h refund, gap to the current contract). Ideas only, no code change.
- Next: decide which spec items to build before feature freeze.

### 2026-10-30 · Orhun
- Changed: docs/SUPPLIERPULSE.md lists the insolvency-history and overdue-accounts rules as ideas for later (not built).
- Next: decide after the demo works whether to build them.

### 2026-10-30 · Orhun
- Changed: **SupplierPulse live paid run on Ethereum Sepolia** (contract `0x91d7dbae109029b2b1245179a68ac362799674d7`). Order 0 (`09729896`, signed `active`): **Paid**, milestone 0 released. Order 1 (`07418033`, signed `liquidation`): **Held**, balance refundable to the buyer. Each check paid $0.01 aUSD over x402 on Base Sepolia. All 4 tampers (value, stale, request, key) rejected by the deployed contract. All tx hashes in `docs/evidence.md`.
- Next: connect the Cardano executor to the live contract (`PULSE_ADDRESS` in `cardano-agent/.env`); record the demo.

### 2026-10-30 · Julien (Cardano) · held supplier paid, team setup files
- Changed: **a held payment earns the agent's fee, verified on chain.** SupplierPulse job `09fa4cf7…` (supplier dissolved, payment held): the escrow paid 5 tADA into the selling wallet (payout tx `3ddd27bd…`, `docs/evidence.md`). `docs/SUBMISSION-cardano.md`: my Cardano section for Devfolio, meant as input for Batu's `docs/drafts/devfolio.md`, not a second draft. Its proof table uses the seller payout txs, which are stronger than the result tx alone. Team setup: `.nvmrc` (Node 24), `.mcp.json` (AirnodeHub MCP), `.claude/` (Cardano dev plugin, Masumi skills), root README prerequisites, `.gitignore` (`.local/`, `cache/`, `*.skey`, `.claude/settings.local.json`). Fixed the result tx typo Batu found below (`…d6e9a34`).
- Next: switch the SupplierPulse stand-in to the real sample companies (`09729896` active, `07418033` liquidation, `12493325` dissolved); then the real job: Orhun's `supplier-agent.sh` (f611aa5) matches the Cardano executor's interface, so it only waits for the Sepolia deployment (`PULSE_ADDRESS` in `cardano-agent/.env`) and aUSD for the agent wallet `0xED3418aE93669a640650728E70f7aA712083253a` (has 0.05 Sepolia ETH for gas). Sokosumi questions (does our proof count, how to get listed, stable URL) go to the Masumi team on Telegram.
- Notes: Batu's `batu/api3-setup` also adds `.local/` and `cache/` to `.gitignore` and many `PROGRESS.md` entries, so expect merge conflicts there; keep both sides. Open with Orhun: Batu's upgrade #2 (agent loop over a payment calendar). Proposal from the Cardano side: one paid Masumi job per payment stage, and the job waits until the stage is due (the gate already supports waiting until a deadline).

### 2026-10-30 · Orhun
- Changed: SupplierPulse takes the company number in `createOrder` and builds the Companies House request hash on chain (`companyRequestHash`), so an order only accepts that company's `getCompanyProfile` (projection `status`). Batu's three real signed responses are tests (active paid, liquidation held, another company's response rejected); 36 tests. New: `api3/scripts/supplier-agent.sh` (the script `cardano-agent/apps/supplier-pulse.json` calls; `Paid`/`AwaitingApproval`/`Held`/`NoData`/`Rejected`), `supplier-fetch.sh` + `api3/x402/` (paid fetch, $0.01 aUSD), judge script `pulse-submit.sh` (4 tamper modes), `pulse-create-order.sh`, `pulse-approve.sh`, `pulse-status.sh`, `pulse-local-demo.sh`, `DeploySupplierPulse.s.sol`.
- Next: deploy on Ethereum Sepolia, live run with an active and a liquidation company; the payer wallet needs a few aUSD on Base Sepolia.
- Notes: `orderInfo` and the events are unchanged, so the demo screen still reads them; `companyNumberOf(orderId)` and `OrderCompany` are new.

### 2026-10-30 · Julien (Cardano) · SupplierPulse on the Cardano side
- Changed: the Cardano side is ready for SupplierPulse. New app `apps/supplier-pulse.json` + `executors/supplier_pulse.py`, paid for a verified decision as in the plan: `Paid`, `AwaitingApproval` and `Held` put the result on chain and the escrow pays the agent. `NoData` retries until the deadline and `Rejected` is final; both refund the buyer. Tested on preprod with a simulated EVM side (`apps/supplier-pulse-sim.json`): a held supplier means the agent is paid (job `09fa4cf7…`), no data means 5 tADA back to the buyer (job `79293455…`). Seller receipt verified on chain for job `c00c4fcf…`: 5 tADA from escrow into the selling wallet (tx `1929a3d1…`). 16 tests.
- **Orhun:** the agent script the Cardano side calls is specified under "Interfaces" above (`api3/scripts/supplier-agent.sh`, env `ORDER_ID` + `COMPANY_NUMBER`, one JSON line out). Once it exists, the only change is `APP_CONFIG=apps/supplier-pulse.json`.
- Next: seller payout of the held job (~14:40). A real SupplierPulse job once the script and the Sepolia deployment exist; it needs the EVM gas key and the aUSD payer key in `cardano-agent/.env` on Julien's laptop. Rename the Masumi registration to SupplierPulse. Cardano Devfolio text.
- Notes: Masumi collects the seller's payment 10 min after the unlock time, so with the `.env.example` deadlines the agent is paid ~46 min after a job. In payment service 0.29 a buyer can release early only through the dispute path.

### 2026-10-30 · Orhun
- Changed: `api3/src/SupplierPulse.sol`: milestone payments to a supplier. Each payment needs a permit from fresh signed registry evidence (status `active`), bound to one order, supplier wallet, stage and amount, expiring after `permitTtl` and used up by the payment. Any other status holds the rest; the buyer can take it back. 14 tests (pay, hold + refund, expiry, approval, edited status, stale, other company, wrong key, replay). `PriceParser.parseString` added.
- Next: Companies House listing details on AirnodeHub, scripts (fetch, agent, judge), deploy to Ethereum Sepolia.

### 2026-10-30 · Orhun
- Changed: API3 idea chosen: SupplierPulse (#3 extended). Milestone payments to a supplier, each one needs fresh signed Companies House evidence and a permit that expires. Plan in `docs/SUPPLIERPULSE.md`. Branch `supplier-pulse`.
- Next: contract + tests on `supplier-pulse`; find the Companies House listing details on AirnodeHub; new Cardano app that is paid for a correct decision (paid or held).
- Notes: the ETH vault on Ethereum Sepolia stays as the fallback.

### 2026-10-30 · Julien (Cardano) · refund path works
- Changed: **Pay-on-pass is proven on preprod in both directions.** Fail job `a81464d0…`: check failed, no result on chain, buyer requested a refund, our refund guard authorized it 44 s later, and the 5 tADA went from escrow back to the buyer, 4.5 min after the job started (4 txs, in `docs/evidence.md`). Pass job `c00c4fcf…` with short deadlines: result on chain, escrow unlocks 13:47, then the seller's node collects. New `receipt.py` completes a proof after the escrow settles. It lists every tx from both sides and checks on chain (Koios) how much left escrow into the selling or purchasing wallet. `buy_job.py` now waits for the result tx before writing the proof.
- Next: confirm the seller payout of `c00c4fcf…` (receipt), then a paid job with the real `eth-vault` app (needs the Sepolia `EVM_*` vars in `cardano-agent/.env`).
- Notes: our agent is not on Sokosumi's agent list (`sokosumi --preprod agents list` shows 20 curated agents). Registering on Masumi does not list it there, so ask the Masumi team on site how to get listed. Qualification does not depend on it: the paid job runs through Masumi escrow on preprod.

### 2026-10-30 · Julien (Cardano) · first paid job
- Changed: **Cardano qualification done.** Agent registered on Masumi preprod (`ppb pay-on-pass agent`, 5 tADA per job, escrow). First paid job: 5 tADA locked in escrow (tx `cef9996c…49370a2`), check passed, result submitted (tx `4d622fc4…d6e9a34`). Full hashes and links are in `docs/evidence.md`. New `masumi_v2.py`: SDK 1.2.0 doesn't support the V2 registrations the current payment service creates (missing `supportedPaymentSourceIndex`, lists default to V1). Job deadlines are now configurable so the escrow pays the seller ~36 min after a job instead of ~30 h.
- Next: a pass job with short deadlines for a real seller receipt, and a fail job for the refund path (both running). Then hire through Sokosumi.
- Notes: `agent-run.sh` changes are compatible with `apps/eth-vault.json`. For your "agent loop (repeated cycles)": the gate already retries an executor that returns `"retryable": true` until a deadline, so a loop only needs `agent-run.sh` to reuse one order instead of creating one per call.

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
