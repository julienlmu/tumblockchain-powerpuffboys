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

### 2026-10-30 · Orhun · security review findings → docs/TODO.md
- Changed: `docs/TODO.md`, the to-do list before submission with an owner for each item (public repo, README, Devfolio/video texts, agent order allowlist, x402 limit, dashboard stop label, merge of `orhun/doc-tools`), pitch wording and known limits.
- Notes: each finding checked against `main`. Document-tool fixes are on `orhun/doc-tools` (71be4ed). No contract change, no deploy.
- Next: each owner ticks their items.

### 2026-10-30 · Orhun · v2 source verified on Etherscan
- Changed: Etherscan exact match for `0xf25Aae1772326C95294D1923399D55c658493DfC` (built from `c668c51`); `docs/evidence.md` updated.
- Notes: for the video, fresh held orders are opened right before filming, because the agent's 10-minute monitoring holds and refunds a new order within minutes.

### 2026-10-30 · Orhun · README: privacy of order documents (future work)
- Changed: appended a "Privacy of order documents" subsection to the README (salted document hashes on chain; amounts, payout wallet and registry ID stay public by design; ZK as future work). No code or ABI change.
- Next: Ulaş, feel free to reword it in the README's voice.

### 2026-10-30 · Orhun · C2.5 review of `tamper.mjs`, `verify.mjs`, `requests.mjs`, `plus-submit.sh` → Emre
- Changed: nothing in Emre's files. Reviewed against §4.7 and the contract's check order (§4.5).
- **No blocking findings.** The four tamper modes produce exactly the contract errors (value/key → `WrongSigner`, stale → `StaleResponse`, request → `WrongRequest`, replay → `Replayed`). `verify.mjs` uses the same freshness rule as the contract (`maxAge`, 60 s future skew). `plus-submit.sh` reuses `plus-lib.sh` (`plus_send`, `plus_error`, `plus_num`) correctly.
- Minor notes (no action needed for the demo):
  - `requests.mjs` uppercases supplier ids; the contract rejects lowercase ids anyway, so the result is the same.
  - The JS label check treats a missing field as "not clean", while the contract reverts `KeyNotFound`. This only shows after a simulation has already succeeded, so the verdict never differs.
  - With `--send` and a fixed gas limit, check that `cast send` exits non-zero when the tx is mined as failed, so the CLI never prints success for a red tx.
- Also checked: Julien's agent (`chain.py`) and Batu's dashboard (`common.js`) match the compiled v1.1 ABI exactly (all functions, events and the 4-byte selectors of all 33 errors).

### 2026-10-30 · Orhun · live outcomes of demo orders A–E, source verified
- Changed: A and D were paid at their due dates (A m0 at 20:03:48, D m0 at 20:16:48). The agent held B, C and E and then refunded them (tx in `docs/evidence.md`, "Outcomes"). Sourcify exact match for v2.
- Also: `plus-local.sh` + `c2_check.py` rehearsed with the fixed contract: 8/8 PASS in 183 s, no changes needed.
- Next: C2 at 22:00; Etherscan verification once an API key is in `api3/.env`.
- Notes: for the video, open fresh held orders on Saturday morning, because B/C/E are already refunded.

### 2026-10-30 · Orhun · demo orders A–E on v2 (Sepolia)
- Changed: the five demo orders exist on v2 `0xf25A…3DfC` (`ordersLength()` = 5). Details and tx hashes in `docs/evidence.md`.
  - A = 0: CH `03778796`, supplier 1, rules 0x06, 500/1,000/1,500, milestones 0 and 1 approved.
  - B = 1: CH `07418033` (liquidation), supplier 2, rules 0x06, 1,000/2,000, milestone 0 approved.
  - C = 2: CH `09729896` (accounts overdue), supplier 1, rules 0x02, 500/500, milestone 0 approved.
  - D = 3: LEI `391200JI69LS8L648F30` (ISSUED), supplier 1, rules 0x08, 500/1,000, milestones 0 and 1 approved.
  - E = 4: LEI `52990092KBQJF8QBGJ50` (LAPSED), supplier 2, rules 0x08, 500/500, milestone 0 approved.
- Next:
  - **Emre:** real fetches + `plus-submit.sh` against ids 0–4.
  - **Julien:** the agent already acts on v2 (held B with 0x86 and C with 0x02 within a minute). Keep it running: the first milestones are due at creation + 1200 s (A/B/C) or + 1800 s (D/E), so the no-data exit opens at due + 600 s, from ~20:13 CET tonight.
- Notes: 0.0095 ETH locked in the orders plus 0.00009 ETH gas (buyer 0.0493 → 0.0398 ETH). One publicnode RPC error after C's create; the rest was sent step by step, no duplicate orders.

### 2026-10-30 · Batu · design pass on both screens (no behaviour change)
- Changed, `demo/` only: same data, contract calls, tamper semantics and URL parameters; new look and hierarchy. One type family (IBM Plex Sans, Plex Mono for hashes; system fonts if offline), one SVG icon set instead of emoji, focus rings, dark-mode button contrast fixed, loading / empty / error states, inline favicon (the `favicon.ico` 404 was the only console error).
  - **Judge page:** at 1280×720 the attack buttons and the verdict are on screen together (the verdict column is sticky). **Passed** is a large card; each tile says in words what happened (*Rejected: own error*, *Rejected earlier*, *Not rejected*), so green vs amber also reads without colour. Order details sit behind "Details +"; the scoreboard says Pass / Fail / n/a.
  - **Dashboard:** each card reads state → protected balance → supplier-wide stop → next step or hold → milestones (one status line each) → facts → audit trail. The supplier-wide stop is one red-outlined strip on both cards, with link chips "Stopped by #1 …" and "This record also stops #5 …" that jump to the other card and flash it.
- Verified (local anvil, fresh `plus-local.sh` contract `0x5bf5…528a`): Run the full tamper test → Passed (valid + 6 rejections), then Send-and-replay → `Replayed`; sample mode shows all states, filter strip and the jump link work; live Sepolia `0xf25A…3DfC` loads without errors (still 0 orders at 19:00); `v1.html` renders; no horizontal scroll at 375 px; 0 text elements below 4.5:1 contrast in light and dark; keyboard-only path through the judge page works.
- **For the video:** record the judge page at 1280×720 or larger; press Run, keep the Passed card and the tiles in frame. On the dashboard, click "Stopped by #1" on the B2 card to show the jump. Theme button = "Theme: auto/light/dark".
- Not checked: a real screen reader, a real MetaMask extension (code paths unchanged).

### 2026-10-30 · Julien (agent) · Sepolia acceptance passed (§6.3)
- `c3_check.py` gives **PASSED** at 20:17:
  - A M1 and D M1 were paid by the agent at their due dates (20:03:52 and 20:16:52).
  - B, C and E were held with the expected rules, then refunded by the agent after their grace periods.
  - A's supplier rose to Trusted at 20:13.
  - 226 autonomous cycles on v2.
- The v2 transactions are in `docs/evidence.md` ("v2 run"), with the 6 out-of-gas sends from before the fix stated openly. `c3_check.py` lists such failures as a note; they are not part of the §6.3 acceptance.
- Both agents keep running overnight (v1 hedge and v2). Next: the morning report (C4). A M2 at 11:45 and D M2 at 12:00 follow the same path live in the video.

### 2026-10-30 · Julien (agent) · demo orders: B, C, E held; clean records needed more gas (fixed)
- **The agent picked up Orhun's demo orders within a minute.** It held B (`0x86`), C (`0x02`) and E (`0x08`) at their first checks.
- **Bug, fixed:** the clean records of **A and D ran out of gas** (6 reverted sends, 3 each, 18:44–18:50 UTC, ~$0.06 of paid records lost). On v2 a clean `submitEvidence` needs **682,737** gas (A) and **645,837** (D), measured by re-estimating the failed transactions at the block before. A held one used 595,724, so the 600k limit from Batu's local test was too low for real records. The limit is now **2,000,000** (`9a0d4d7`). Unused gas is refunded, so it costs nothing.
- The review fixes did their job meanwhile: the agent backed off instead of buying records every tick, and it never treated the failures as "no data", so A was not refunded.
- The agent was restarted at 18:51 UTC, and the backoff these bug failures caused was cleared. **A and D are verified now** (clean, 18:52 UTC). A's permit covers its due date, so **A M1 is released at 19:03 UTC**, and D's at its due date.
- **Batu:** your fix was right, only the number was local. The 234k you measured on anvil is about a third of what real records need on Sepolia.

### 2026-10-30 · Julien (agent) · Sepolia acceptance check; heads-up on C and E for the video
- Changed: `python3 api3/agent/c3_check.py` checks the Sepolia acceptance of §6.3 against the live v2 contract and the agent's log. It is read-only and costs nothing. It finds the demo orders by supplier id, so B2 and dry-run orders don't confuse it. It prints PASS or WAIT for each point: A and D milestone 1 paid by the agent, B held then refunded, C and E held, A's tier risen, ≥ 10 cycles, no failed actions. Live now: 20 cycles, clean, the order lines wait for orders A–E.
- **Heads-up for the video (Ulaş, Orhun, Batu):** the agent refunds *every* held order once its grace period is over (P1, §6.3), not only B. Overnight, **C and E will also be refunded** 10 minutes after they are held. On Saturday the dashboard shows them as refunded, with their failed rules.
  - If the video needs an order that is still *held* (0:35 – 1:05, "C held: accounts overdue"), create a fresh one shortly before recording: the agent holds it at its first check, and it stays held for 10 minutes. Or use B2, which is created live.
  - If you would rather have the agent leave C and E alone overnight, tell me; that is a small change.

### 2026-10-30 · Batu · one-click tamper test; dashboard states eligible / rule failed / no data
- Changed, `demo/judge.html`: **▶ Run the full tamper test** runs the valid record and all six attacks ((a)–(d), real old record, real other company) as `eth_call` simulations and shows a pass/fail card with one tile per attempt (green: the attack's own error, amber: stopped by an earlier check). On the local chain it signs a fresh record first; on Sepolia a stale record gets a warning with the fetch command. **Send the valid record, then replay it** is the last step (one real tx). Local test: passed, valid + 7 rejections incl. `Replayed`.
- Changed, `demo/index.html` (from the team's research notes on Middesk, Sablier, HubPal, SLAStream): each card's badge is now **Eligible / Rule failed / No data** (plus awaiting check, fully paid, refunded); a strip above the cards counts the three states, defines them and filters on click. New row **Agent's last decision** per order (the agent's latest transaction on it). The supplier-wide stop now names the order whose record caused it, both ways ("Stopped by #1 PO-1002" ↔ "This record also stops #5"), with a link that jumps to the card.
- Notes: the Sepolia v2 found automatically is `0xf25A…3DfC`; it had **no orders** at 18:15, so the judge page says so instead of running. For the video: create the orders first, then fetch a fresh record (≤ 300 s) before pressing the button.

### 2026-10-30 · Julien · C2.5: judge page tamper code reviewed; agent material for the video
- **C2.5 review of the judge page's tamper code against §4.7: passes, nothing to change.** I ran `demo/common.js` and Emre's `api3/x402/tamper.mjs` side by side on all 5 real fixtures in `api3/fixtures/`. (a) value, (b) stale, (c) request and replay give byte-identical records. (d) key re-signs the untouched digest with a random key that is not an Airnode, in both. The request templates match §4.2 v1.1, and the v1 fallback uses v1's template. The comparison is a 40-line Node script; Batu or Emre, I can add it to your folder as a test if you want it.
- `docs/agent.md` now shows real log lines from the live Sepolia run instead of the example. A new section, "For the video (1:45 – 2:10)", gives **Ulaş** four shots and a 60-word voice-over for the agent part.
- Next: watch the agent's first v2 actions once Orhun creates orders A–E; the C4 report in the morning.

### 2026-10-30 · Julien (agent) · C3: the agent runs on v2
- Changed:
  - **The agent runs on v2 [`0xf25A…3DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC) since 18:18**, with the demo profile (30 s ticks, $1/day budget) under `api3/agent/run-forever.sh`. A dry run (`plan`) first: v2 reachable, 0 orders, `maxAge` 300, agent wallet `0xED34…253a`.
  - It idles until the demo orders exist. **Once Orhun creates orders A–E, it starts on its own within 30 s:** due-date checks, monitoring by tier, the supplier-wide stop, refunds. Its log is `api3/agent/state/cycles.jsonl` on my laptop.
  - The v1 hedge keeps running next to it (`state/v1/`). Both use the agent wallet: 0.047 Sepolia ETH, about 9.9 aUSD, and each has its own $1/day budget.
- **Emre, Batu, Ulaş:** the agent also checks every v2 supplier by itself. For a tamper demo, use a fresh record that the agent has not submitted yet (Batu's note in `demo/README.md`).
- Next: overnight cycles on v2. At C4, `python3 api3/agent/pulse_agent.py report --markdown` → `docs/evidence.md`.

### 2026-10-30 · Julien (agent) · independent review of the agent: 5 findings fixed
- An independent review of `api3/agent/` (fresh reviewer, its own throwaway anvil with Orhun's contract) found 5 issues, 2 of them high. All are fixed in `3265a3f`:
  1. **High: a broken fetch setup refunded clean orders.** Keys in `api3/agent/.env` never reached `FETCH_CMD` (exit 2), and *any* failed fetch counted towards the no-data refund. Now `.env` is exported, and only a "no data" answer (exit 3) after the due date can lead to the refund. A setup error, failed payment, timeout, mismatch or RPC problem alerts instead. The agent key no longer falls back to `EVM_PRIVATE_KEY` (the buyer/admin wallet).
  2. **High: after a paid fetch, a failed write bought a new record every tick** (for example without gas). Every failure after a fetch now backs off, and no action runs while the wallet cannot pay for two writes (one alert).
  3. Failed fetches that may have paid (exit 5, timeout, crash) now count against the daily budget.
  4. A transaction is broadcast once (`cast send --async`) and then followed by its hash, so an RPC failover never sends it twice.
  5. Exit 2 pauses paid fetches like exit 4. Logged errors no longer carry the agent key or full RPC URLs, and one agent per state directory (lock).
- **Batu's finding (blocking for Sepolia), fixed in `aadf973`:** `cast send` used the exact gas estimate as the gas limit. On a chain that mines in intervals, 18 of 24 sends ran out of gas in Batu's test; anvil's automine hid it. Every write now has a fixed limit of 600,000, the change Batu tested. Unused gas is refunded.
- Checks: 80 tests (Python 3.8 and 3.13), `c2_check.py --fake` 8/8. **Real C2 8/8 twice**: with automine (188 s, 15 transactions through the new send path, 0 errors), and on an anvil that mines a block every 2 s like Sepolia (183 s, 15 writes, 0 errors, 0 out of gas).
- New for the overnight run: `api3/agent/run-forever.sh` restarts the agent after a crash, but stops on a config error or a second agent on the same state. `pulse_agent.py report --markdown` prints every transaction with explorer links for `docs/evidence.md`.
- The v1 hedge was restarted on the new code at 18:09 (cycle 127). Nothing was lost: its state and cycle count continue.
- **Orhun's note:** `fakes.py` now opens the no-data exit at `max(due date, first approval) + grace`, and refuses `permitTtl < maxAge`, like the contract. 2 tests, 82 in total.
- **Batu's note, repo visibility:** confirmed, the repo is **private** (`gh api`, Fri 18:12). I scanned the whole history of every branch for secrets: no `.env` was ever committed; no private keys, Blockfrost ids or seed phrases; only anvil's public test keys. Switching it to public is my decision as the owner (needed by Sat 14:30). Spec §7.4 corrected.
- `docs/agent.md` and §6.3 are updated (failure table, refund rule, gas limit, runner).
- **Emre**, for later: `airnode-fetch.mjs` exits 4 for any thrown error, including an unreachable Airnode before payment, so an Airnode outage pauses both registries for 15 min. A separate exit code for "Airnode unreachable, nothing paid" would let the agent pause one source only. Not urgent.
### 2026-10-30 · Orhun · SupplierPulse+ v2 live on Ethereum Sepolia (C3 deploy)
- Changed:
  - `SupplierPulsePlus` v2 deployed at [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC), tx [`0x2db57f1f6e10acfe03f8eb31712b168e1e4278d20b182e7160cfe07b83684e99`](https://sepolia.etherscan.io/tx/0x2db57f1f6e10acfe03f8eb31712b168e1e4278d20b182e7160cfe07b83684e99), block 12028086.
  - Constructor: CH airnode `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, GLEIF airnode `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c`, maxAge 300, tierCountGap 300, refundGrace 600. Values checked on chain with `cast call`.
  - Recorded in `docs/evidence.md` (SupplierPulse+ live), `docs/SUPPLIERPULSE_PLUS.md` §3.2 and `api3/.env.example` (`PULSE_PLUS_ADDRESS`).
- Next:
  - **Emre:** real fetches + `plus-submit.sh` against this address.
  - Demo orders A–E after Orhun's OK.
- Notes: includes the C2.5 fixes; `forge test` 115/115 on source commit `c668c51`.

### 2026-10-30 · Orhun · C2.5 review fixes in `SupplierPulsePlus.sol` (Emre's findings 1 and 2)
- Changed (storage and checks only, no ABI change):
  - **Finding 1:** `approveMilestone` stores the time of the first approval per milestone (`approvedAt`). The no-data exit now opens at `max(dueDate, approvedAt) + refundGrace`, in `refundRemaining` and in `orderSchedule.autoRefundAt`. A buyer who approves late can no longer approve and refund in the same block; the supplier always gets the full grace. Re-approving does not move the time.
  - **Finding 2:** `createOrder` reverts `BadOrder` when `permitTtl < maxAge`, so the oldest record the contract accepts still gives a usable permit and `checkAndRelease` cannot fail with `PermitExpired`. `plus-local.sh` (300) and `plus-demo-orders.sh` (1800) already comply.
  - 4 new tests (late approval, refund after the full grace, re-approval, TTL bound). `forge test`: 115/115.
- Notes:
  - **Julien:** `fakes.py` still computes the no-data exit from the due date only. The real contract now reports the later time in `orderSchedule.autoRefundAt`, which the agent already reads.
  - **Emre:** v2 is not deployed yet. I deploy it at C3 with the demo constants 300/300/600 and send the address.
- Next: Orhun's OK to merge into `supplierpulse-plus`; C3 deploy.

### 2026-10-30 · Batu · C2/C3 done for the screens; agent gas finding; I may be offline tonight
- **Blocking for C3, Julien: the agent's sends run out of gas on a chain with block intervals.** With the latest `supplierpulse-plus` (`955cb15`) on anvil with interval mining (`evm_setIntervalMining 1`, like Sepolia's 12 s blocks), **18 of the agent's sends in 24 ticks reverted with `OutOfGas`** (e.g. `submitEvidence` tx limit 234369 = gasUsed 234369; `cast run` ends in `EvmError: OutOfGas`). `cast send` takes the estimate as the limit, and the estimate is exactly the gas used, so it sometimes falls short when the transaction lands in a later block. Your C2 passed because anvil's default automine executes each tx right where it was estimated. On Sepolia every failed send costs gas and another $0.01 fetch. **Fix:** `"--gas-limit", "600000"` in `Chain.send` (`api3/agent/chain.py`). With that one change the same run had 0 failed sends and reached every §7.1 state (0 and 2 paid, 1/3/4 refunded, 4 held by the supplier-wide stop without a fetch, 5 refunded by the no-data exit, two suppliers Trusted), 19 transactions. Tested in a scratch copy only; your file is unchanged. The `0x` parsing bug I hit on the way you had already fixed in parallel.
- **Julien (repo owner): the repository is private** (`gh api repos/julienlmu/tumblockchain-powerpuffgirls` → `"visibility":"private"`), while §7.4 says it is already public. The track needs a public repo by 14:30 Sat. GitHub Pages is not enabled; the pages don't need it (they run from `python3 -m http.server`).
- Changed (`demo/`, merged):
  - **C3 needs nothing from me.** Without an address, both pages find the newest SupplierPulse+ v1.1 among the last 80 transactions of Orhun's deployer `0xEb3E…ce41` (by the v1.1 test vector), so after the deploy `http://localhost:8765/` and `judge.html` show v2. Until then the dashboard links to v1 and the judge page runs against the live v1 contract (§7 fallback), with the real v1 records.
  - Judge page: **"Send anyway as a real transaction"** after a rejection, with a fixed gas limit, so the video's tamper cases show as failed transactions on Etherscan (§4.7). The agent panel now also counts `applySupplierFailure` ("supplier-wide stop, no fetch").
  - `demo/README.md`: a launch and video checklist for whoever runs it.
- Verified:
  - **Ethereum Sepolia, read only:** no v2 found yet → v1 fallback; real v1 records on live v1 order 0: (b) `StaleResponse`, (c) `WrongRequest`, signer the real Companies House Airnode.
  - **Test chain with Sepolia's chain id**, v1.1 deployed from Orhun's (impersonated) deployer between other txs: both pages found it. **MetaMask flows** with an EIP-1193 test wallet: judge Send for real (status 1), Replay + Send anyway (status 0 on chain), dashboard Claim now by the buyer (refunded).
  - **C2 step 4:** the dashboard showed the agent's run live (19 agent transactions = the agent's report). **Judge page = `plus-submit.sh`** on the same record: accepted; (a) `WrongSigner(0xe19F…f958)` in both, the same recovered address; (b) the same timestamp; (c) the same request hash; (d) `WrongSigner`.
- **I may be offline tonight.** `demo/` needs no action at C3. If something in `demo/` must change while I'm away, anyone may edit it; the README explains the parts. The agent wallet already has 9.96 aUSD (entry below), so §7.2 step 4 is done.
- **Ulaş, hero frame (C1):** I agree with the spec's proposal. Concretely on the judge page: **(b) Real old record** → red `StaleResponse`, then **Send anyway** → the failed tx on Etherscan, then the dashboard's protected balance on order B. All three are one click each.
- Note: I switched the local anvil on :8545 on my laptop to interval mining for this test; it only affects my machine.

### 2026-10-30 · Julien (spec) · Emre's contract findings 1 and 2 accepted → Orhun
- Changed (spec, **no ABI change**, header note "Amendment"):
  1. **No-data exit after a late approval** (§2.4a, §4.5): `approveMilestone` stores `approvedAt[m]` on the first approval (internal storage). The exit and the `autoRefundAt` view count from `max(dueDates[m], approvedAt[m]) + refundGrace`. Without this, a buyer who never approved could approve and refund in the same block, and the supplier never got a chance to bring evidence. New Forge case in §6.1: late approval → `RefundNotYet(approvedAt + refundGrace)`.
  2. **`createOrder` requires `permitTtl ≥ maxAge`** (`BadOrder`). This replaces `permitTtl > 0`, so a fresh record can no longer give an already expired permit (`PermitExpired` in `checkAndRelease`). The demo orders already use ≥ 300.
- **Orhun:** both are small contract changes, ideally before the 22:00 C2 and the C3 deploy. The agent and Batu's dashboard need nothing: both read `autoRefundAt` from the view, and the agent does not fetch while a due milestone waits for the buyer.
- Note 3 (admin `setAirnode`/`setMaxAge` on live orders) is for Ulaş's pitch as a trust assumption. Note 4 (one record per order) is how the agent already works.

### 2026-10-30 · Julien (agent) · C2 with Emre's real fetch-local passes; agent evidence
- Changed:
  - **C2 with Emre's real `fetch-local.sh` passed (17:39, 8/8 in 181 s).** It ran in a local test worktree: `supplierpulse-plus` `2b6ca9c` + `emre/plus-data` `8a1bedd`, not pushed. The agent reads Emre's records as they are, and unknown ids exit 3 ("no data") as specified.
  - The run showed one more agent issue: monitoring (P4) could pay for a fetch on an order refunded in the same tick, and it logged a waiting due check twice. Fixed in `29d35c3`: P4 now skips orders that P0–P3 already decided on. 63 tests pass, and the C2 rerun with the fix passed 8/8 again (17:45).
  - `docs/evidence.md` has a new section, "SupplierPulse+ autonomous agent": the v1 hedge's paid cycles with both tx links per cycle (x402 payment on Base Sepolia, contract tx on Sepolia), checked on chain, plus the C2 runs.
  - v1 hedge: 74 cycles since 17:03, 4 paid checks ($0.04), 0 alerts, 0 errors.
- Emre has merged `emre/plus-data` into `supplierpulse-plus` (`fef17a5`), so `plus-local.sh`'s `FETCH_CMD` resolves on the integration branch and C2 needs no stand-in anywhere.
- Next: C3, the agent on the v2 contract on Sepolia once Orhun deploys it (demo profile, next to the v1 hedge).

### 2026-10-30 · Emre · `plus-submit.sh --send`: gas limit 2,000,000
- Changed: `--send` used a fixed 500,000 gas limit. A clean real record needs ~683k on v2 (Julien's finding), so a valid record sent in the video would have failed with out-of-gas instead of being accepted. The limit is now 2,000,000, like the agent's; unused gas is refunded. Tested locally: a valid `--send` gives `ACCEPTED clean`, tx status success.
- Notes: Emre's wallet now has Sepolia ETH for the video's real tamper txs (Coinbase faucet).

### 2026-10-30 · Emre · C3: real records and the judge CLI against live v2
- Changed: verified v2 `0xf25A…3DfC` on chain: config 300/300/600, both signers, and `requestHashFor` equals `requests.mjs` for all five demo suppliers. Fresh real records for A, D and B ($0.03), then `plus-submit.sh` against the live orders: A and D `ACCEPTED clean`; (a) `WrongSigner`, (b) `StaleResponse` (mutated **and** the genuine 17:14 A record), (c) `WrongRequest` (mutated **and** a genuine fresh B record on A), (d) `WrongSigner`; B (closed) `NotActive(2)`. Table, payments and judge commands are in `docs/evidence.md` ("Judge CLI against live v2").
- Next: real `--send` tamper transactions for the video on Saturday (needs Sepolia ETH in Emre's wallet; the faucet hasn't delivered yet).
- Notes: created the two supplier payout wallets for the demo orders (`DEMO_SUPPLIER_1/2`); their keys are only on Emre's laptop (`api3/.local/`, gitignored). Spent $0.11 of aUSD in total.

### 2026-10-30 · Emre · C2 passes with the real v1.1 `fetch-local.sh`
- Changed: merged the latest `supplierpulse-plus` into `emre/plus-data` and re-ran everything on it.
  - `python3 api3/agent/c2_check.py` with **Emre's real `fetch-local.sh`** (no stand-in signer): **8/8 PASS in 244 s**. Orders 0 and 2 paid; 1 held with `0x82` and refunded; 3 held with `0x08` and refunded; 4 held by the supplier-wide stop without a fetch and refunded; 5 refunded through the no-data exit; `01234567` reached Trusted; no quarantine, no errors.
  - `forge test` 111/111; `test-requests.mjs` 11/11.
  - `plus-submit.sh` on the fresh local deploy: order 0 `ACCEPTED clean`, 1 `ACCEPTED held: registry status not active, accounts overdue`, 2 clean, 3 `ACCEPTED held: LEI renewal overdue`; value/stale/request/key → `WrongSigner`/`StaleResponse`/`WrongRequest`/`WrongSigner`; `--send` success; replay → `Replayed`. The real A record on order 1 → `WrongRequest`.
- Next: merge `emre/plus-data` into `supplierpulse-plus` (C1). Julien's C2 then no longer needs a stand-in signer. C3: real fetches + the judge CLI on Sepolia.

### 2026-10-30 · Emre · C2.5 review of `SupplierPulsePlus.sol` (early) → Orhun, Julien
- Changed: nothing in Orhun's files. I reviewed `supplierpulse-plus` at `a1cd45e` against §2.4, §2.4a and §4.5 v1.1. `forge test`: 104/104 pass. The two findings were proven with throwaway Forge tests (not committed).
- **Finding 1 (medium, design, Orhun + Julien): the buyer can bypass "without approval there is no exit".** After `due + refundGrace`, a buyer who never approved can call `approveMilestone(m)` and `refundRemaining()` in the same block. The agent skips unapproved milestones (P3), so there is never a permit at that moment, and the supplier gets no chance to bring evidence. PoC: an order due `NOW`, warp to `NOW + GRACE`, approve then refund → the buyer gets the full amount back, supplier balance 0. **Fix (storage only, no ABI change):** store `approvedAt[m]` and count the no-data exit from `max(dueDates[m], approvedAt[m]) + refundGrace`, in `refundRemaining` and in the `orderSchedule.autoRefundAt` view. The agent then always has the full grace period to fetch after an approval.
- **Finding 2 (low, Orhun): `checkAndRelease` reverts `PermitExpired` when `permitTtl` < the record's age.** `validUntil = timestamp + permitTtl`, so with `permitTtl = 60` and a 120 s old record, `release` reverts and takes the whole call with it (spec: it reverts only on verification failures and `SupplierFailed`). The clean record and its $0.01 are lost. PoC: reverted `PermitExpired(1799999940, 1800000000)`. **Fix:** `createOrder` requires `permitTtl >= maxAge` (`BadOrder`). The demo orders already use ≥ 300.
- Note 3 (pitch, Ulaş): the admin can `setAirnode` / `setMaxAge` on live orders. That's fine for the demo, but state it as a trust assumption (or lock it after deploy).
- Note 4 (demo): `usedDigests` is global, so one signed record serves one order. Two orders of the same supplier (B and B2) need two fetches. That's correct and fits the agent.
- Checked and fine:
  - the check order is exactly §4.5, so the tamper errors match `plus-submit.sh`;
  - the signer per source; replay across orders; "newer only";
  - the forward-only history; the supplier-wide stop and `applySupplierFailure`;
  - state is changed before every transfer (reentrancy);
  - event arguments; `"status":` never matches `"entity_status":`; high-s signatures are rejected.

### 2026-10-30 · Emre · judge CLI `plus-submit.sh`, §6.2 Phase A done
- Changed: `api3/scripts/plus-submit.sh <orderId> <file> [value|stale|request|key|replay] [--send]`. It simulates `submitEvidence` (from `0x…dEaD`, no wallet), prints `ACCEPTED clean` / `ACCEPTED held: <labels>` / `REJECTED <Error>(args)`, and exits 0/1/2. `--send` sends with a fixed gas limit, so a rejected record is mined as a failed tx (red "Fail" on Etherscan). It reads `EVM_RPC_URL`/`PULSE_PLUS_ADDRESS` from the env or `api3/.env` and reuses Orhun's `plus-lib.sh` error decoding.
- Tested against Orhun's contract on `plus-local.sh` (the C2 checks of §6.2): order 0 `ACCEPTED clean`; order 1 `ACCEPTED held: registry status not active, accounts overdue`; order 3 `ACCEPTED held: LEI renewal overdue`; value → `WrongSigner`, stale → `StaleResponse`, request → `WrongRequest`, key → `WrongSigner(random)`, replay → `Replayed`; `--send` gives a success tx and a failed tx.
- Next: C2 integration at 22:00, C2.5 review of the contract, C3 real fetches + judge CLI on Sepolia.
- Notes: **Batu, Ulaş (video and judge page): run the tamper cases on a record that has NOT been accepted yet.** The contract checks replay and "newer" before the signer (§4.5), so tampering an already accepted record gives `NotNewer` (a) or `Replayed` (d) instead of `WrongSigner`. Order: tamper a fresh record (a)–(d) first, then submit it untouched (accepted), then replay it.

### 2026-10-30 · Emre · data layer on spec v1.1, v1.1 pointers verified live (C1a)
- Changed: Julien's v1.1 checklist for the data layer is done on `emre/plus-data` (merged `supplierpulse-plus` in):
  - `requests.mjs`: the Companies House projection has 3 fields (`/accounts/next_accounts/overdue`), the rule `0x01` is gone, and the `0x08` label is "LEI renewal overdue". Tests 11/11 with the vector `0x6e84…7f0f`.
  - `local-registry.json`: `ch:07654321` without `insolvency`; `99999999` stays unknown (exit 3).
  - **The v1.1 pointers were verified live** for `03778796`, `07418033` and `09729896`: request hash and signer match. **No interface change.** The v1.0 Companies House fixtures were replaced by v1.1 ones.
  - Genuine tamper inputs: (b) `api3/fixtures/ch-09729896-202610301614.json` (real, now stale); (c) a fresh `07418033` record against order A.
- Next: `plus-submit.sh` (decodes `SupplierFailed`, `NoNewerFailure`, `NotRefundable`; `--send` for the video), once Foundry is installed.
- Notes: `12493325` has no `/accounts/next_accounts/overdue` either (HTTP 400, not charged), so it cannot be the (c) input; `07418033` is used instead. All demo suppliers have every field, so fallback 1 of §4.2 applies and the template stays. Spent $0.08 in total.

### 2026-10-30 · Emre · demo suppliers complete
- Changed: **Order A supplier: `03778796` ELECTRIC MOTORS INTERNATIONAL LIMITED**, signed record clean on all four fields (fixture in `api3/fixtures/`). All five demo suppliers are now in `docs/data-sources.md`.
- Next: `plus-submit.sh`.
- Notes: Orhun, for C3: `DEMO_CH_A=03778796 DEMO_CH_B=07418033 DEMO_CH_C=09729896 DEMO_LEI_D=391200JI69LS8L648F30 DEMO_LEI_E=52990092KBQJF8QBGJ50`. Spent $0.05 in total.

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
### 2026-10-30 · Julien (agent) · C2 check passes against Orhun's v1.1 contract; C2.5 review fixed
- Changed:
  - `api3/agent/c2_check.py` runs the C2 integration (§7.1) as one command. It runs `plus-local.sh`, then the agent at 10 s ticks with the local fetch, and checks the 8 expected outcomes on chain and in the agent log. `--fake` runs the same checks in memory.
  - **First real integration passed (~17:22):** the agent with Orhun's v1.1 contract on anvil, all 8 checks in 180 s. Payments, holds with labels, the supplier-wide stop without a fetch, the no-data exit, and the tier rising. Emre's v1.1 `fetch-local.sh` is not in `supplierpulse-plus` yet, so a scratchpad v1.1 signer stood in.
  - **The check found a real agent bug:** functions without return values (`release`, `applySupplierFailure`, `refundRemaining`) print a bare `0x`, which the agent read as an error. Fixed, with a test.
  - **Batu's C2.5 review: all three points fixed** (§6.3 and `docs/agent.md` updated):
    1. no monitoring while a due milestone waits for the buyer;
    2. a quarantined order gets no action at all, including release and refund;
    3. the no-data refund comes only after the agent's own try at or after the due date failed. That last try ignores the retry backoff. A failed x402 payment does not count as missing data.
  - **One more fix of my own:** the check before a due date now waits until its permit still covers the due date (`permitTtl − 60 s` if that is shorter than the lead time). Before, a buyer's short `permitTtl` meant a paid fetch every tick.
  - 61 tests pass (Python 3.8 and 3.13); `c2_check.py --fake` passes 8/8.
  - Spec §2.5/§7.2 now has Emre's demo suppliers: A `03778796`, B `07418033`, C `09729896`, D `391200JI69LS8L648F30`, E `52990092KBQJF8QBGJ50`.
- Batu's pages are already on v1.1 (`2c09a7c`), so no checklist for him.
- **Orhun:** please start anvil with `--block-time 1` in `plus-local.sh` (Batu's finding: an idle anvil lags, and fresh records then simulate as `FutureResponse`). The C2 check mines a block before every tick as a safety net.
- Next: C2 again with Emre's real v1.1 `fetch-local.sh` (in a test worktree until `emre/plus-data` is merged).

### 2026-10-30 · Orhun · real Companies House tests (C1a done)
- Changed: 7 new tests run Emre's v1.1 Companies House records (`4267d11`, pointers verified live) against the contract:
  - the three request hashes match;
  - A `03778796` is paid;
  - B `07418033` is held with `0x86` (status, accounts, confirmation);
  - C `09729896` with rules `0x02` is held with `0x02` only;
  - B2: `applySupplierFailure` holds a second order of B without a new fetch;
  - A's record on order C gives `WrongRequest`;
  - B's signature with the status edited to `active` gives `WrongSigner`.

  `forge test`: 111 passed. **This resolves the open question in my previous entry: v1.1 stays, no interface change.**
- Next: C2 integration at 22:00 (`plus-local.sh`), then the C2.5 review of `tamper.mjs`, `verify.mjs` and `plus-submit.sh`.

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
- aUSD for C3 (§7.2 step 4): the agent wallet `0xED34…253a` already holds **9.96 aUSD** and 0.003 ETH on Base Sepolia (read 30 Oct ~17:30), so no transfer is needed. Batu's wallet keeps 9.91 aUSD as a reserve.
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
