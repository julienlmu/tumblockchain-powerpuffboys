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

### 2026-10-30 · Julien (agent) · C2 check passes against Orhun's v1.1 contract; v1.1 checklist for Batu
- Changed:
  - `api3/agent/c2_check.py` runs the C2 integration (§7.1) as one command. It runs `plus-local.sh`, then the agent at 10 s ticks with the local fetch, and checks the 8 expected outcomes on chain and in the agent log. `--fake` runs the same checks in memory.
  - **First real integration passed (~17:22):** the agent with Orhun's v1.1 contract on anvil, all 8 checks in 180 s. Payments, holds with labels, the supplier-wide stop without a fetch, the no-data exit, and the tier rising. Emre's `fetch-local.sh` was still v1.0 then, so a scratchpad v1.1 signer stood in.
  - **The check found a real agent bug:** functions without return values (`release`, `applySupplierFailure`, `refundRemaining`) print a bare `0x`, which the agent read as an error. Fixed, with a test (55 tests).
  - Spec §2.5/§7.2 now has Emre's demo suppliers: A `03778796`, B `07418033`, C `09729896`, D `391200JI69LS8L648F30`, E `52990092KBQJF8QBGJ50`.
- **Batu (UI, built on v1.0): v1.1 checklist**
  1. `common.js` ABI = §4.6 v1.1:
     - `supplierRecord` has 7 fields (`lastBaseFailureAt` before `tier`);
     - add `applySupplierFailure` and `OrderRefunded(…, bool noDataExit)`;
     - errors `NotRefundable`, `SupplierFailed` and `NoNewerFailure` instead of `NotHeld`;
     - no `effectivePermitTtl`.
  2. The Companies House template in the browser = §4.2 v1.1 (vector `0x6e84…7f0f`). Labels: no insolvency (`0x01` is reserved), and `0x08` = "LEI renewal overdue".
  3. Dashboard (§6.4 v1.1):
     - drop `effectivePermitTtl`;
     - the tier becomes "verification history";
     - a supplier-wide stop banner from `lastBaseFailureAt`;
     - a no-data exit line when `autoRefundAt` is set on an active order;
     - refunds show `noDataExit`.
  4. Judge page: (b) and (c) with real inputs from `api3/fixtures/` (§4.7). The tamper logic itself is correct (reviewed, C2.5).
  5. Sample data with the v1.1 fields.
- **Orhun:** please start anvil with `--block-time 1` in `plus-local.sh` (Batu's finding: an idle anvil lags, and fresh records then simulate as `FutureResponse`). The C2 check mines a block before every tick as a safety net.
- Next: C2 again with Emre's v1.1 `fetch-local.sh` instead of the stand-in, then Batu's pages against the same chain once they are on v1.1.

### 2026-10-30 · Orhun · demo suppliers and real GLEIF tests (C1a, part 1)
- Changed:
  - `plus-demo-orders.sh` and `api3/.env.example` now use Emre's verified demo suppliers: A `03778796`, B `07418033`, C `09729896`, D `391200JI69LS8L648F30`, E `52990092KBQJF8QBGJ50`.
  - 4 new tests run Emre's real signed GLEIF records against the contract. D is paid and E is held with `0x08`. The untouched D record is rejected when too old (`StaleResponse`) and on another LEI's order (`WrongRequest`). `forge test`: 104 passed.
- Next: the real Companies House tests are blocked. See the notes.
- Notes: **open interface question for Emre and Orhun (§4.2 fallback).** Emre's live Companies House records use the v1.0 projection: 4 fields, `/accounts/overdue`, including `insolvency`. Spec v1.1 changed it to 3 fields and `/accounts/next_accounts/overdue`. That pointer has not been called live yet. So no real Companies House record matches the v1.1 request hash, and the contract rejects them with `WrongRequest`.
  - Proposal: one paid call ($0.01) for `03778796` with the v1.1 projection.
  - If it signs, v1.1 stays, and I add the Companies House tests with that record.
  - If not, we keep 3 fields but go back to the verified `/accounts/overdue` pointer. That changes two constants on the contract side.

### 2026-10-30 · Batu · screens on spec v1.1 (C1), policy review (C2.5)
- **Orhun, re your open question above:** Emre's `4267d11` (on `emre/plus-data`) already replaced the Companies House fixtures with v1.1 records (3 fields, `/accounts/next_accounts/overdue`) and verified them live. I checked in the browser that the request hash of `api3/fixtures/ch-03778796-202610301614.json` equals the v1.1 template (`0xa6d1…f452`), signer `0x3922…4bFF`. So v1.1 stays, no extra paid call needed; the CH tests can use those fixtures.
- Changed: `demo/` moved to spec v1.1 and merged into `supplierpulse-plus`.
  - ABI, Companies House template (3 fields, `/accounts/next_accounts/overdue`) and labels from v1.1; no permit multiplier, no `effectivePermitTtl`, rule `0x01` gone, `0x08` reads "LEI renewal overdue".
  - Dashboard: "verification history" instead of trust, the supplier-wide stop banner (`lastBaseFailureAt`), the no-data exit box with countdown and "Return to buyer", `noDataExit` in the audit trail. Sample mode uses Emre's five demo suppliers and shows both new states.
  - Judge page: buttons for the real inputs (b) and (c), untouched records from `api3/fixtures/` (bundled in `demo/sample/responses.js`); the checklist includes the `SupplierFailed` check.
  - Tested on a local chain with the v1.1 contract (`plus-local.sh`, 6 orders): valid → accepted; (a) `WrongSigner`, (b) `StaleResponse`, (c) `WrongRequest`, (d) `WrongSigner`; real (b) `StaleResponse`, real (c) `WrongRequest`. A clean record older than the supplier's failure → `SupplierFailed`. Dashboard rendered held + supplier-wide stop (order 1), the stop on the supplier's other order (4), and the no-data exit countdown (5).
- Next: C2 with the agent and `plus-submit.sh`. C3: Sepolia v2 address in the pages.
- Notes, **C2.5 review of `api3/agent/policy.py` for Julien** (54/54 tests pass; the P0 to P4 order matches §6.3). Nothing blocking, three points:
  1. **P4 pays while waiting for the buyer.** A supplier whose only active order is past due and unapproved is still monitored: `plan()` returns `monitor` at $0.01 per tier interval. P3 skips exactly this case on purpose. Suggest: leave such orders out of `open_orders` in P4.
  2. **Quarantine does not stop releases and refunds.** A quarantined order that is due with a valid permit gets `release`, and a quarantined held order gets `refund` (only P0 and the fetches check quarantine). Both are safe on chain, but §6.3 says "stop acting on it" and the test is called `test_quarantined_orders_are_left_alone`. Either gate them or document it in `docs/agent.md`.
  3. **Refund before a last try.** If the agent was down past `autoRefundAt`, P1 returns the money to the buyer before P3 tries one more fetch. It matches the spec's priority order; worth one sentence in the pitch Q&A.
  - Both checked with a scratch script against `plan()`, no change to Julien's files. The anvil clock note from my entry below also applies to the agent's `now` on the local chain.

### 2026-10-30 · Batu · dashboard v2 and "Try to break it" (§6.4, Phase A)
- Changed: branch `batu/plus-ui` (from `supplierpulse-plus`, with `batu/demo-screen` merged; v1 is now `demo/v1.html`).
  - `demo/index.html`, dashboard v2: one card per order with the protected balance, milestone timeline (paid, permit valid until, awaiting approval, not due, held, refunded), permit countdown and `effectivePermitTtl`, trust tier and streak, last check with failed rules in words, held banner with refund countdown, "Claim now" (MetaMask) and the `plus-refund.sh` command, audit trail with the decoded signed data. Agent activity panel above the cards. Auto-refresh 12 s, light/dark, phone width.
  - `demo/judge.html`: the five attacks plus "Submit as is", built in the browser with the §4.7 semantics; verdict from an `eth_call` of `submitEvidence` from `0x…dEaD`; checklist in the contract's order of checks; scoreboard; judge kit; "Send for real" (MetaMask, or the anvil agent key locally).
  - Sample mode (`?sample=1`, `demo/sample/sample.js`) shows every state and all three tiers; ethers is bundled in `demo/vendor/` so it also works offline. Usage in `demo/README.md`.
  - Tested on a local chain with Orhun's `plus-local.sh` and Emre's `sign-local.mjs`: judge page valid → accepted, (a) `WrongSigner`, (b) `StaleResponse`, (c) `WrongRequest`, (d) `WrongSigner`, Replay after a real send → `Replayed`. The four §4.2 test vectors match in the browser. Dashboard showed paid, held, refunded and the agent's transactions.
- Next: C2, both pages against `plus-local.sh` and the agent; compare judge verdicts with Emre's `plus-submit.sh`. Load Emre's real fixtures. C3: point both pages at Sepolia v2; send ≥ 2 aUSD to the agent wallet. C2.5: review the agent's `policy.py`.
- Notes:
  - **Orhun:** `plus-create-order.sh` stores `orderRef = keccak256(name)`, which cannot be decoded. The dashboard matches the demo names by hash (and `LOCAL-<id>`), so A to E show their names. If you create other orders, either tell me the names (URL `names=`) or use `cast format-bytes32-string`, which the page decodes directly.
  - **Orhun, Julien (C2):** on anvil, `eth_call` uses the latest block's timestamp, and anvil only mines on transactions. After a minute idle, a fresh record simulates as `FutureResponse` (seen here: block time 513 s behind the clock). The agent simulates every write, so it would hit this locally. Fix: start anvil with `--block-time 1` in `plus-local.sh`, or `cast rpc evm_mine` before simulating. Sepolia is not affected. The judge page mines one block before each local simulation.
  - After a record was sent for real, (a) and (d) on the same record stop earlier (`NotNewer`, `Replayed`). For the video: run all simulations first, then send, then Replay.

### 2026-10-30 · Orhun · SupplierPulse+ contract (§6.1, Phase A, spec v1.1)
- Changed: the contract part (§6.1) is built against spec v1.1. It is on `orhun/plus-contract` and merged into `supplierpulse-plus`.
  - `api3/src/ISupplierPulsePlus.sol` (§4.4 v1.1 verbatim), `SupplierPulsePlus.sol`, `JsonFields.sol` (`parseBool`).
  - Contract features:
    - Companies House rules `0x02`/`0x04` (`0x01` is reserved and reverts `BadRules`);
    - a verification history that counts only the base status and only moves forward;
    - permits that are never extended;
    - the supplier-wide stop: `lastBaseFailureAt`, `SupplierFailed` in `submitEvidence` and `release`, and `applySupplierFailure`;
    - `refundRemaining` with the held path and the no-data exit (`NotRefundable`, `OrderRefunded.noDataExit`);
    - `autoRefundAt` for both paths.
  - `api3/test/SupplierPulsePlus.t.sol`: 64 tests. They cover the §4.2 v1.1 vectors, every bad-input error, each rule, every tamper case (edited value, stale, future, other request, CH response on a GLEIF order, wrong key, replay, not newer, high-s), permits, `NotDue`, all four `checkAndRelease` outcomes, the history (gap, older records, rule-only failures, base failures, `TierChanged`, shared record), every supplier-wide stop case, both refund paths with all their errors, and event arguments. `forge test`: 100 passed, including v1's 36. v1 files are unchanged.
  - `api3/script/DeploySupplierPulsePlus.s.sol`, the `api3/scripts/plus-{lib,local,create-order,approve,refund,status,demo-orders}.sh` scripts, and new lines in `api3/.env.example`.
  - `plus-local.sh` creates the six §4.8 orders. Tested on anvil:
    - a cast-signed clean record paid order 0 M1;
    - liquidation held order 1 with labels, and the buyer refunded it;
    - `applySupplierFailure(4)` held order 4 without new evidence;
    - order 5 (no data) was refunded through the no-data exit after due + grace;
    - errors decode by name (`WrongSigner`, `NotRefundable`, `BadSupplierId`).
- Next:
  - C1a: tests with Emre's real fixtures. If a Companies House field is dropped (§4.2 fallback), I change the two constants.
  - C2: `plus-local.sh` for the integration.
  - C3: Sepolia deploy and `plus-demo-orders.sh`.
- Notes:
  - Local orders use `permitTtl` 300; demo orders use `PERMIT_TTL` (default 1800).
  - Demo due dates are fixed for Saturday CET: A M2 at 11:45, A M3 at 15:30, the others at 12:00.
  - A missing field of an enabled rule makes `submitEvidence` revert with `KeyNotFound` or `NoBool`. That never pays, and the no-data exit covers it.

### 2026-10-30 · Julien · v1.0 → v1.1 checklists for Orhun and Emre
- Changed: nothing in code. `orhun/plus-contract` and `emre/plus-data` were built on spec v1.0 (`864fe18`), before v1.1 (`3181439`, ~17:00). Great speed. These are the exact deltas so both fit the agent and each other at C2.
- **Orhun (contract):**
  1. `ISupplierPulsePlus.sol` = §4.4 v1.1 verbatim.
     - New: `applySupplierFailure`, `SupplierFailed(uint256)`, `NoNewerFailure()`, `NotRefundable()` (replaces `NotHeld`), `OrderRefunded(…, bool noDataExit)`, and `supplierRecord(…)` with `uint64 lastBaseFailureAt` before `tier`.
     - Removed: `effectivePermitTtl`. Bit `0x01` is reserved.
  2. Companies House template with 3 fields (§4.2): `accounts_overdue` `/accounts/next_accounts/overdue`, `confirmation_overdue` `/confirmation_statement/overdue`, `status` `/company_status`. The vector for `09729896` is `0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f`. Companies House rules ⊆ `0x06`, and `0x01` gives `BadRules`.
  3. Verification history (§2.4, §4.5):
     - Only the base status counts.
     - The record is updated only if `timestamp > lastCheckAt`.
     - A base failure sets `lastBaseFailureAt`.
     - **No permit multiplier:** `validUntil = timestamp + permitTtl`, and `Permit` gets `evidenceAt`.
  4. Supplier-wide stop (§4.5):
     - `submitEvidence` step 10: a clean record with `timestamp ≤ lastBaseFailureAt` reverts `SupplierFailed`.
     - `release` requires `permit.evidenceAt > lastBaseFailureAt`.
     - `applySupplierFailure`.
  5. `refundRemaining`: Held, Active (the no-data exit: approved, no valid permit, `now ≥ due + refundGrace`, anyone can call), and Closed gives `NotRefundable`. The `orderSchedule.autoRefundAt` semantics change accordingly.
  6. Tests per §6.1 v1.1: add the supplier-wide stop, the no-data exit and the forward-only history; drop the permit × tier tests.
  7. Scripts:
     - `plus-local.sh`: rules `0x06`, plus local orders 4 (`07654321`) and 5 (`99999999`, no data) (§4.8).
     - `plus-lib.sh`: decode the new error names.
     - `plus-status.sh`: LAPSED = "LEI renewal overdue".
- **Emre (data layer):**
  1. `requests.mjs`: the Companies House projection above (drop `insolvency`, and the rule `0x01` is reserved); the GLEIF `0x08` label is "LEI renewal overdue". In `test-requests.mjs` the vector is `0x6e84…7f0f`.
  2. `local-registry.json`: `ch:07654321` = `{"accounts_overdue":true,"confirmation_overdue":false,"status":"liquidation"}`. `99999999` stays unknown (exit 3).
  3. C1a:
     - verify the new pointers live, applying the fallback in §4.2 if needed;
     - keep two genuine tamper inputs: an old `09729896` response and a fresh `12493325` response (§4.7).
  4. `verify.mjs` checks the 3 fields. `plus-submit.sh` decodes `SupplierFailed`, `NoNewerFailure` and `NotRefundable`; `--send` is for the video.
- Notes: the agent (on `main`) already speaks v1.1 and is running on the live v1 contract as the bonus hedge since 17:03.

### 2026-10-30 · Julien (agent) · v1.1 and the v1 hedge
- Changed: the agent follows spec v1.1.
  - **Priority 0:** it holds other orders of a supplier whose register status failed (`applySupplierFailure`, no new fetch).
  - **Refunds:** they also cover the no-data exit.
  - **Labels:** the insolvency rule is gone, and LAPSED is labelled "LEI renewal overdue".
  - **New: v1 hedge mode** (`AGENT_CONTRACT_VERSION=v1`, `api3/agent/fetch-v1.sh`). The same loop runs against the live v1 contract, so the autonomous-cycle evidence builds up even if v2 is late.
  - 54 tests (Python 3.8+). The simulated run covers the supplier-wide stop and the no-data exit. The live anvil check against v1 still passes.
- Next: start the v1 hedge run on Sepolia tonight, then the C2 integration with v2.
- Notes:
  - `main` now stays identical to `supplierpulse-plus` (Julien's rule: everything that can affect someone else's code goes to `main` right away).
  - **Orhun:** the v1 hedge submits evidence to v1 order 0, which issues permits but pays nothing without your approval of milestone 1. If you test on v1 order 0 yourself, expect `NotNewer` for older responses.

### 2026-10-30 · Julien · INTERFACE CHANGE: spec v1.1 (before kickoff)
- Changed: `docs/SUPPLIERPULSE_PLUS.md` v1.1. It adopts the real findings of Orhun's two reviews (`codex/api3-only-research`, `claude/project-thread-0habue`) **before anyone builds**:
  - **Companies House fields** (§4.2, §4.3): the current pointers `/accounts/next_accounts/overdue` and `/confirmation_statement/overdue`. The insolvency rule is dropped (the field is deprecated; current insolvency already shows in the status). The new test vector is `0x6e84…7f0f`. The fallback if a field is missing is in §4.2.
  - **Tiers as verification history** (§2.4): only the base status counts, the history only moves forward, and **permits are never extended**. The tier only changes how often the agent re-checks.
  - **Supplier-wide stop** (§2.4a): `lastBaseFailureAt` blocks `release` on older permits for every order of the supplier. `applySupplierFailure(orderId)` holds other orders without a new fetch. New errors: `SupplierFailed`, `NoNewerFailure`.
  - **No-data exit** (§2.4a): an approved milestone without a permit, overdue by `refundGrace`, lets the money go back to the buyer. `NotHeld` is replaced by `NotRefundable`, and `OrderRefunded` gets `noDataExit`.
  - Real signed responses for the tamper cases (b) and (c), and real reverted transactions in the video (§4.7).
  - v1 stays the fallback submission (§7); the agent runs against v1 tonight as a hedge (§6.3).
  - `effectivePermitTtl` is removed, and `supplierRecord` gets `lastBaseFailureAt`.
  - Two new local orders (4: same supplier as order 1, 5: no data).
- Next: everyone builds against v1.1. Create your branch from `supplierpulse-plus` now.
- Notes:
  - The agent wallet funded itself: 0.003 ETH bridged to Base Sepolia (tx `0xd700…61f3`) and 10 aUSD minted (tx `0xa0cf…0c70`). How to do the same is in §5.3.
  - Cardano stays out (the office-hours review suggested keeping one job; we keep the focus).

### 2026-10-30 · Julien (agent) · Phase A done
- Changed: `api3/agent/` is the autonomous agent for SupplierPulse+ (spec §6.3).
  - **Schedule:** due checks within the lead time, re-checks by trust tier, releases at the due date, refunds after the grace period.
  - **Spending limits:** a daily budget with a reserve for due checks, a fetch cap per tick, a gas cap, and a pause after failed payments.
  - **Failure handling:** backoff, quarantine on `WrongRequest`/`WrongSigner`, every write simulated before it is sent.
  - **Log:** one JSON line per action, plus `report`.
  - **Tested:** 48 tests (Python 3.8+). `--fake` runs the whole flow against an in-memory contract. The chain adapter was also checked live against v1 on a local anvil.
  - **Docs:** `docs/agent.md` explains the schedule, limits and failure handling, as the agent bonus requires.
- Next: C2 integration with Orhun's `plus-local.sh` and Emre's `fetch-local.sh`, then the overnight Sepolia run from C3.
- Notes:
  - **Tenderly's public Sepolia RPC refuses bursts (`-32603`).** Use publicnode, `https://ethereum-sepolia-rpc.publicnode.com`. The agent fails over by itself (`EVM_RPC_URLS`), but scripts don't.
  - The agent wallet `0xED34…253a` needs at least 2 aUSD by C3.
  - `.claude/skills/grillme/SKILL-2.md` is renamed to `SKILL.md`, so Claude Code loads it.

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
