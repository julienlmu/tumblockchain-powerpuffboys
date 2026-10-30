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

### 2026-10-30 · Batu (14:05)
- Changed: drafts for README, Devfolio text and the 2:30 video script in `docs/drafts/`. The root README is unchanged for now.
- Next: please review, especially the "How it works" flow (does the Cardano job match what the agent will really do?). The `TODO`s need a SupplierPulse deploy address, a judge script and a SupplierPulse app in `cardano-agent/`.
- Notes: the result tx of the first paid job is `4d622fc4…d6e9a34` (full hash in `docs/evidence.md`). The Julien "first paid job" entry below writes it as `…a6e9a34`.

### 2026-10-30 · Batu (13:55)
- Changed: rebased `batu/api3-setup` onto `68762a5`. Log sorted by time, and Batu's time labels corrected to the real commit times. No entry removed.
- Next: force push of `batu/api3-setup` (Batu), then Orhun picks up the issues and samples for SupplierPulse.

### 2026-10-30 · Batu (13:50)
- Changed: added `docs/samples/companies-house/` with three real signed Companies House responses (active `09729896`, liquidation `07418033`, dissolved `12493325`), plus their request hashes and payment txs in `docs/decision-sheet.md`.
- Next: Orhun can use these as fixtures, e.g. a `test_realCompaniesHouse*` test like `test_realNodaryResponse`.
- Notes: a scratch Forge test (not committed) ran `SupplierPulse.sol` against the real responses, 6/6 pass. Cost 0.03 aUSD.

### 2026-10-30 · Batu (13:46)
- Changed: `docs/decision-sheet.md` has a new section "SupplierPulse (#3 extended): API3 review". Docs only.
- Next: Orhun looks at the issues list. Batu can fetch real `getCompanyProfile` responses for the test companies ($0.01 each).
- Notes:
  - `forge test` on `supplier-pulse` passes 31/31.
  - **Test hashes use `companyNumber`, but the Companies House listing's parameter is `company_number`.** A script built from the tests would fail every real response with `WrongRequest`.
  - Free `advancedSearchCompanies` test candidates: active `09729896`, `10092605`; liquidation `07418033`; dissolved `12493325`.
  - One company won't change status during a live demo, so show two orders (paid vs held).

### 2026-10-30 · Julien (Cardano) · refund path works
- Changed: **Pay-on-pass is proven on preprod in both directions.** Fail job `a81464d0…`: check failed, no result on chain, buyer requested a refund, our refund guard authorized it 44 s later, and the 5 tADA went from escrow back to the buyer, 4.5 min after the job started (4 txs, in `docs/evidence.md`). Pass job `c00c4fcf…` with short deadlines: result on chain, escrow unlocks 13:47, then the seller's node collects. New `receipt.py` completes a proof after the escrow settles. It lists every tx from both sides and checks on chain (Koios) how much left escrow into the selling or purchasing wallet. `buy_job.py` now waits for the result tx before writing the proof.
- Next: confirm the seller payout of `c00c4fcf…` (receipt), then a paid job with the real `eth-vault` app (needs the Sepolia `EVM_*` vars in `cardano-agent/.env`).
- Notes: our agent is not on Sokosumi's agent list (`sokosumi --preprod agents list` shows 20 curated agents). Registering on Masumi does not list it there, so ask the Masumi team on site how to get listed. Qualification does not depend on it: the paid job runs through Masumi escrow on preprod.

### 2026-10-30 · Julien (Cardano) · first paid job
- Changed: **Cardano qualification done.** Agent registered on Masumi preprod (`ppb pay-on-pass agent`, 5 tADA per job, escrow). First paid job: 5 tADA locked in escrow (tx `cef9996c…49370a2`), check passed, result submitted (tx `4d622fc4…a6e9a34`). Full hashes and links are in `docs/evidence.md`. New `masumi_v2.py`: SDK 1.2.0 doesn't support the V2 registrations the current payment service creates (missing `supportedPaymentSourceIndex`, lists default to V1). Job deadlines are now configurable so the escrow pays the seller ~36 min after a job instead of ~30 h.
- Next: a pass job with short deadlines for a real seller receipt, and a fail job for the refund path (both running). Then hire through Sokosumi.
- Notes: `agent-run.sh` changes are compatible with `apps/eth-vault.json`. For your "agent loop (repeated cycles)": the gate already retries an executor that returns `"retryable": true` until a deadline, so a loop only needs `agent-run.sh` to reuse one order instead of creating one per call.

### 2026-10-30 · Batu (12:57)
- Changed: `docs/decision-sheet.md` #6 now has the results of the paid checks. Docs only.
- Next: Ulaş, Orhun and Batu decide. If #6: one coin, simulated pool rewards, credit = reward × signed `historicalPrices` at the reward time, hash built on-chain.
- Notes:
  - dRPC `historicalPrices` returns a signed `{"price":…,"timestamp":"2026-10-30T08:00:00+00:00"}` for the requested moment.
  - The request hash is `keccak256('["historicalPrices",[["symbols",["DOGE"]],["timestamps",[<ms>]]]]')`.
  - Signed Bitcoin balances failed (502), so the reward amount stays unsigned.
  - Cost 0.01 aUSD, tx `0xf54d7b05d806a0e246472f3380438710f85020441797dca6cd5ec44b43eeaa91`.

### 2026-10-30 · Orhun
- Changed: Deployed PriceTriggeredVault on Ethereum Sepolia at 0xBC68DB972A62cFf3161e600d92C475c29c22886A (Nodary signer, max age 300s). Live checks: real ETH/USD response accepted, replay and all four tampered responses (value, stale, request, key) rejected on-chain, agent-run created and executed order 0. Deploy needs `--slow --gas-estimate-multiplier 800`. submit.sh now reads revert errors from newer cast output. README has a Deployment section; .env.example points at Sepolia (Tenderly RPC).
- Next: agent loop (repeated cycles), README "why this data matters" section, tamper-test video.

### 2026-10-30 · Orhun
- Changed: API3: vault now matches the official AirnodeHub starter. Data comes from the Nodary Airnode (free, ETH/USD, signer `0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0`). The contract also rejects a fresh signature over an old price (`updatedAt` check). Deploy uses Nodary defaults. 16 tests pass.
- Notes: a real Nodary ETH/USD response (price 2246.485) was fetched and verified against the Nodary signer; it is now a test (`test_realNodaryResponse`), 17 tests pass. Fixed the `key` tamper mode for Foundry 1.8.x.
- Next: choose the API3 use case (ETH vault, parametric insurance or esports escrow), deploy to Base Sepolia, add a timed loop to the agent for the agent bonus.

### 2026-10-30 · Batu (12:52)
- Changed: `docs/decision-sheet.md` has a new section "#6 Mining payout settlement: API3 review" for Ulaş's brainstorm branch. Docs only.
- Next: Ulaş, Orhun and Batu discuss it. Three open checks (one $0.01 call each) are listed at the end of the section.
- Notes:
  - AirnodeHub has no mining pool or reward data, so only the price would be signed.
  - dRPC `historicalPrices` gives a signed price at a past timestamp ($0.01) for DOGE, BTC, LTC, ADA and more.
  - Nodary serves DOGE/USD, LTC/USD, BTC/USD and ADA/USD for free.

### 2026-10-30 · Batu (12:46)
- Changed: nothing in code. Batu has a Base Sepolia test wallet `0xA54506DcE89ff9561534c76C043505a1a484FB4c` (encrypted Foundry keystore `batu-test`) with 10 aUSD and ~0.0001 ETH. Mint tx `0xce7765c73a861212876f59dcf5968aeed3f52344321fe4de5b56a60c9b51216f`.
- Next: wait for Ulaş's Cardano + API3 idea branch, then the API3 contract work with Orhun.
- Notes: aUSD on Base Sepolia (chain 84532) is `0xbeA34973e5f67F18F656A2C6070C64326C791808`, 6 decimals, faucet limit 10 aUSD per account, minted via `mintFromFaucet(uint256)` from the wallet itself (needs a little Base Sepolia ETH; Coinbase CDP faucet works). RPC `https://sepolia.base.org`.

### 2026-10-30 · Batu (12:12)
- Changed: nothing in code. Batu's laptop now has Foundry 1.8.7 and pnpm 12.16.1. `forge test` in `api3/` passes 15/15; `local-demo.sh` runs on anvil.
- Next: Orhun to fix the wrong-key tamper case (below), then the idea decision (#0 vs #3).
- Notes: **Foundry 1.8.7 breaks tamper case (d).** `cast wallet new --json` now returns `{"data":[...]}`, so `api3/scripts/submit.sh:24` (`jq -r '.[0].private_key'`) fails with `Cannot index object with number`. Suggested fix, works with old and new Foundry: `jq -r '(.data // .)[0].private_key'`. Judges with a current Foundry would hit this.

### 2026-10-30 · Julien (Cardano)
- Changed: `cardano-agent/` is now a generic pay-on-pass agent. What it sells is pluggable: `apps/*.json` plus an executor that prints `{"passed": …}`. Passed: the result goes on chain and the escrow releases. Not passed: no result; the buyer requests a refund and `refunds.py` authorizes it. Apps: `mock` (the buyer picks the outcome, for testing) and `eth-vault` (wraps `api3/scripts/agent-run.sh` and passes only if the vault executed, which is proposal 1). Retry until a deadline is built in (proposal 3), but `eth-vault` doesn't use it because `agent-run.sh` creates a new order per call. `buy_job.py` takes `--input JSON` and requests the refund when a job fails. 10 unit tests (`python -m unittest` in `cardano-agent/`).
- Next: Docker and Masumi services, register the agent, then a first paid job (mock, pass) and one refund (mock, fail) on preprod.
- Notes: the `agent-run.sh` interface is unchanged. A new API3 use case is a new app (executor + config) and needs no Cardano changes; see "Executor contract" in `cardano-agent/README.md`. `ALLOW_DRY_RUN` is gone; use `APP_CONFIG=apps/mock.json` to test without the EVM side.

### 2026-10-30 · Batu (12:09)
- Changed: new branch `batu/api3-setup` for the API3 track (Batu + Orhun, tentative). Added `.local/` and `cache/` to `.gitignore` (required by `CLAUDE.md` §7). Status log in `docs/status/batu.md`.
- Next: Batu and Orhun pick #0 (price vault) or #3 (supplier approval gate). Then Foundry setup and `forge test` on Batu's laptop.
- Notes: Batu's laptop has no Foundry or pnpm yet.

### 2026-10-30 · Batu
- Changed: added `docs/decision-sheet.md` (ideas #0–#5 compared, facts vs inferences) and `docs/status/batu.md`. Docs only, branch `batu/decision-sheet`.
- Next: Julien picks the idea and API3 scope. After that: README, Devfolio text, video script, pitch.
- Team split (tentative, not yet confirmed by everyone): Batu + Orhun on API3, Ulaş + Julien on Cardano.
- Notes:
  - Re Julien's proposal 1 (refund when the seller never submits): the Masumi refunds doc lists "no response before the deadline" as grounds for the buyer's `POST /purchase/request-refund`, but the seller must then `authorize-refund`, or it escalates to the Masumi team. Safer: our agent calls `POST /payment/authorize-refund` itself when the condition fails by the deadline. Confirm with Masumi. Source: https://www.masumi.network/dev/masumi/core-concepts/refunds-and-disputes.md
  - AirnodeHub: Nodary ETH/USD is free and first-party. The CoinGecko `simplePrice` used in `fetch-eth-usd.sh` costs $0.02 aUSD (x402).
  - API3 judging: real use case 40%, signed data matters 30%, execution 20%, novelty 10% ("beyond the unchanged starter"; the starter is already a Nodary ETH/USD consumer), +10 agent bonus. Projections let a contract read string fields such as Companies House `company_status`. Details in `docs/decision-sheet.md`.

### 2026-10-30 · Julien
- Changed: added "Proposals to discuss" above (pay on execution, customer story, watch until deadline, trust assumption, infra risk). Earlier push: `CLAUDE.md` with team rules, tracks and coding-agent context.
- Next: agree on the proposals with Orhun, then implement 1 and 3 in `cardano-agent/agent.py`.
- Notes: Sokosumi preprod: CLI 1.0.4 is broken (`404 route_not_found` on Personal Workspace commands), use 1.1.0. Vendor `powerpuffboys` and Coworker `powerpuffboys-agent` are registered on Julien's account (quickstart path, may not be needed for the MIP-003 agent). Julien's laptop: Node 24, Postgres 17, Foundry; no Docker or cloudflared yet.

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
