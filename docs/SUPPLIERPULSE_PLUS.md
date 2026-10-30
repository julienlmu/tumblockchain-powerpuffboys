# SupplierPulse+: build spec (API3 track)

> **For:** Orhun, Emre, Julien, Batu, Ulaş, and the coding agent each of you uses.
> **Status:** decided Fri 30 Oct, ~16:00. We enter the **API3 track only** and build **SupplierPulse+ with trust tiers** (since v1.1: verification-history tiers, §2.4).
> This file is the single source of truth until submission. It replaces the scope of `docs/SUPPLIER_PULSE_SPEC.md`
> (its "out of scope: multiple registries, credit scoring" no longer applies). Its demo ideas are included here (§2.5, §6.4).
> `docs/SUPPLIERPULSE.md` keeps describing v1, the contract that is live today.
> **Branch:** `supplierpulse-plus` is the integration branch for this build (§5.1).
> **v1.1 (Fri ~17:00, before kickoff):** interface update after two reviews (`codex/api3-only-research`, `claude/project-thread-0habue`). It brings:
> - current Companies House fields, with the insolvency rule dropped (§4.2, §4.3);
> - tiers as verification history, without longer permits (§2.4);
> - a supplier-wide stop and a no-data exit (§2.4a);
> - real signed responses for the tamper demo (§4.7);
> - an agent hedge on v1 tonight (§6.3).
>
> Code against this version.

## How to use this file

- **Everyone:** read §0 to §5 (about 15 minutes), then your own workstream in §6.
- **Coding agents:** start with this prompt, with your section and name filled in:

```text
Read docs/SUPPLIERPULSE_PLUS.md completely, then CLAUDE.md §7 (security rules).
You implement workstream §6.<N> for <name>. Work only in the files listed under "You own" in that section.
Section §4 (interfaces) is frozen: code against it exactly. Until the other workstreams deliver, use the
mocks and fixtures your section describes. Never edit files owned by someone else (§3.3).
Before every push: git pull --rebase origin supplierpulse-plus, run your tests, add an entry to docs/PROGRESS.md.
Never commit .env files, private keys or API keys. Testnets only. Ask a human before any paid call that is
not described in your section.
```

---

## 0. Summary

### What we build

SupplierPulse+ releases milestone payments to a supplier only with **fresh, signed registry evidence**.

- **The agent** checks each supplier before every due date. It also re-checks between due dates, less often for suppliers with a clean track record. Each check pays $0.01 over x402 for a signed record from API3 AirnodeHub and submits it to the contract.
- **The contract** verifies signer, request and freshness, then applies the buyer's rules:
  - UK supplier (Companies House): the company is active, and its accounts and confirmation statement are not overdue.
  - Supplier with an LEI (GLEIF): the entity is active and the LEI registration is issued.
- **The result:** the contract either issues a payment permit for exactly the next milestone, or holds the remaining balance for the buyer.
- **Verification history (tiers):** every accepted record updates the supplier's on-chain history of register checks. A supplier with a long clean history is re-checked less often, so the agent needs fewer paid checks. Permits are never extended.
- **Supplier-wide stop:** one failed register status stops payments on every order of that supplier. If data stays unavailable, the buyer gets the money back after a grace period.
- **Screens:** a dashboard shows the protected balance and the audit trail. A "Try to break it" page lets judges attack the contract themselves.

### Who does what

| Person | Workstream | Main deliverable | First hand-off |
|---|---|---|---|
| **Orhun** | §6.1 Contract | `SupplierPulsePlus.sol`, Forge tests, deploy script, buyer scripts, local test chain, Sepolia launch | 19:00: contract and tests green, `plus-local.sh` |
| **Emre** | §6.2 Data layer and judge CLI | x402 fetch for Companies House and GLEIF, request-hash library, local signer, verify and tamper tools, `plus-submit.sh`, real demo suppliers | 18:30: live fields verified, fixtures, local signer |
| **Julien** | §6.3 Autonomous agent | Python agent (schedule, daily budget, failure handling), overnight run on Sepolia, `docs/agent.md` | 19:00: planning logic and tests with fakes |
| **Batu** | §6.4 Dashboard and judge page | `demo/index.html` (v2 dashboard), `demo/judge.html` ("Try to break it"), sample mode | 19:00: dashboard in sample mode |
| **Ulaş** | §6.5 Story and submission | research, root README, Devfolio text, video, pitch and Q&A, judge-style QA | 19:00: research notes and video storyboard |

### Checkpoints (CET)

| When | Checkpoint | Done when |
|---|---|---|
| Fri 16:45 | **C0 Kickoff** | Everyone is on their own branch with a working environment, and has a "started" entry in PROGRESS |
| Fri 18:30 | **C1a Data verified** | Emre: real responses for both registries are fetched and the field paths confirmed (or §4.2 updated). `requests.mjs`, `sign-local.mjs` and `fetch-local.sh` are pushed |
| Fri 19:00 | **C1 Parts work alone** | Contract tests green and `plus-local.sh` works. Agent planning tests green. Dashboard runs in sample mode. Research and storyboard drafted |
| Fri 22:00 | **C2 Local integration** | The full loop runs on a local chain (§7.1) |
| Fri 23:30 | **C2.5 Cross-review** | Every part has been reviewed by someone who didn't write it (§7.1b), and blocking findings are fixed |
| Sat 00:00 | **C3 Sepolia launch** | v2 deployed, demo orders created, agent running (§7.2) |
| Sat 08:00 | **C4 Morning QA** | Ulaş has run the project as a judge from a fresh clone, and the bug list is assigned |
| Sat 11:00 | **C5 Feature freeze** | Only bug fixes from here on |
| Sat 13:00 | **C6 Video done** | Video uploaded and linked |
| Sat 14:30 | **C7 Submitted** | Devfolio submitted, `main` updated, repo public |

---

## 1. Context

### 1.1 Hackathon facts

- **Deadlines:** the hard deadline is **Sat 31 Oct, 15:00**. We submit at 14:30.
- **Judging:** live, Sat 15:00 to 17:00 at the API3 booth, with a queue. Winners are announced at 17:30.
- **Submission:** one Devfolio submission per team, entered in **one partner track: API3, "Any API in your contract"**. The TUM Blockchain track judges every submission automatically.
- **Cardano is not entered.** `cardano-agent/` stays in the repo untouched and is not part of the pitch.
- **Video:** at most 2:30, one for the whole submission.
- **Testnets only:** Ethereum Sepolia and Base Sepolia.

### 1.2 The API3 track: requirements and scoring

These are official, checked on 30 Oct.

**Qualification (all must hold):**
1. An AirnodeHub integration is essential to a core feature. Removing it must materially impair the app.
2. A signed response is submitted to a **deployed contract** that verifies the expected signer, the intended request and the timing.
3. A value bound to the exact signed response drives a meaningful on-chain action, with protection against duplicate execution.
4. **Tamper test (pass/fail):** first a valid, timely response triggers the action. Then four responses are rejected before that action:
   - (a) a real response with one value edited
   - (b) a real response that is too old
   - (c) a real response to a different request
   - (d) a response signed by the wrong key

   "Rejecting everything does not pass."

**Required in the submission:**
- the contract address and network
- a way for judges to submit their own responses (an app or a documented script)
- in the description: who relies on the data, what goes wrong if it is forged, and what data we wanted but could not find

**Scoring (out of 100, plus up to 10 bonus):**

| Criterion | Weight | How we earn it |
|---|---|---|
| Real use case | 40 | Supplier insolvency costs real money. Several signed risk signals, two registries, an audit trail (§2) |
| Signed data matters | 30 | The signed record *is* the payment decision. The request hash is built on-chain from source and supplier |
| Execution | 20 | Deployed contract, tamper tests, judge page and CLI, a dashboard on live data |
| Novelty | 10 | Permits that expire per stage, a supplier-wide stop from one verified record, verification history from signed records, rules the buyer picks per order |
| **Agent bonus** | **+10** | "Demonstrate repeated autonomous cycles and explain the schedule, spending limits and failure handling. x402 payment alone is not sufficient." See §6.3 |

**Judges:** Matej Falat (Software Engineer, API3) and Ugur Schenk (Strategy Lead, API3).

### 1.3 What exists today (v1, live)

**Contract:**
- `api3/src/SupplierPulse.sol` is live on Ethereum Sepolia at `0x91d7dbae109029b2b1245179a68ac362799674d7`.
- It checks only the Companies House `status` field.
- The paid run, the held run and all four tamper cases are recorded in `docs/evidence.md`.
- **v1 stays deployed and is not edited.** SupplierPulse+ is a new contract next to it, and v1 is the fallback.

**Libraries:**
- `api3/src/AirnodeVerifier.sol` builds the digest, recovers the EIP-191 signer and rejects high-s signatures.
- `api3/src/PriceParser.sol` provides `parse`, `parseUint` and `parseString`.

**Scripts:**
- In `api3/scripts/`: `pulse-*.sh`, `supplier-fetch.sh`, `supplier-agent.sh`, `sign-response.sh`, and `pulse-local-demo.sh` (the local-chain pattern we reuse).
- `api3/x402/ch-fetch.mjs` makes the paid fetch. It needs Node ≥ 22.18 and pins `@x402/fetch` and `@x402/evm` 2.28.0 and `viem` 2.57.3. **Do not upgrade them.**

**Tests:**
- `api3/test/SupplierPulse.t.sol` uses the custom `api3/test/utils/Vm.sol` (no forge-std, `libs = []`).
- `forge test` passes 36/36.

**Not yet merged into `supplierpulse-plus`:**
- Branch `batu/demo-screen`: `demo/index.html`, the v1 order screen (static HTML, ethers 6.13.5).
- Branch `batu/api3-setup`:
  - `docs/drafts/devfolio.md`, `docs/drafts/video-script.md`
  - `docs/decision-sheet.md`, `docs/supplierpulse-upgrades.md`
  - real Companies House samples in `docs/samples/companies-house/`

### 1.4 Out of scope

- Cardano and Masumi
- credit scores beyond the tier rule
- more than two registries
- free-amount withdrawals
- a React or Next build: we keep static HTML, so judges need no build step
- mainnet
- Cardano. The office-hours review suggests keeping one Masumi job; the team keeps its focus on one track (decided 16:00, confirmed 17:00).
- the subcontractor-agent design (`docs/designs/subcontractor-agent.md` on branch `claude/top-starred-llm-repos-49fd68`). It targets the Cardano track with nested Masumi escrow, which we don't enter. Its process ideas are adopted here: the hero frame and the pre-run proofs (§6.5, §7.4), the cross-review (§7.1b), prior art and claim limits (§6.5), and the contrast pitch line (§2.6).

---

## 2. The product

### 2.1 Problem, customer, data

**Problem.** Companies vet a supplier once, at onboarding, then pay advances and instalments for months. If the supplier goes into liquidation, stops filing accounts, or lets its LEI lapse, the next payment still goes out. Money paid to a company in liquidation is hard to get back.

**Customer.**
- Small manufacturers and procurement or accounts-payable teams that pay several suppliers in stages and have no compliance team.
- Crypto-native companies and DAOs that already pay vendors in stablecoins. That is where an on-chain escrow runs natively.

**Who relies on the data.** The buyer's money. The signed register record is the only input that decides whether a stage is paid.

**What goes wrong if it is forged.**
- A forged record that says "active, accounts filed" pays the next instalment to a company that is being wound up.
- A forged negative record blocks an honest supplier.

**Data we wanted but could not find on AirnodeHub:**
- the German Handelsregister and German insolvency notices (Insolvenzbekanntmachungen)
- delivery confirmations from ERP systems

GLEIF covers German companies only when they have an LEI.

### 2.2 How it works

1. **The buyer creates an order.** It names the supplier by registry source and id, the payout wallet, the milestones (amount and due date), the permit lifetime and the rules. The buyer locks the full amount.
2. **The buyer approves each milestone:** order accepted, stage reached, delivery accepted. This is the "dual lock": the registry check plus the buyer.
3. **The agent fetches evidence** before each due date, and between due dates depending on the tier. It pays $0.01 over x402 for a fresh signed record:
   - Companies House `getCompanyProfile`, projected to 3 fields, or
   - GLEIF `getLegalEntity`, projected to 2 fields.

   It then submits the record.
4. **The contract verifies it:**
   - the signer is the expected Airnode for this source;
   - the request matches the one built on chain from source and id;
   - the record is fresh (`maxAge`, 300 s);
   - it is not a replay, and it is newer than the order's last record.

   Then it evaluates the order's rules.
5. **A clean record** issues a permit for exactly the next milestone. The permit is valid for `permitTtl`, counted from the evidence time.
6. **A failed record** holds the order and protects the remaining balance. The buyer can claim it at once. After a grace period, anyone (the agent) can trigger the refund, which always goes to the buyer. If the register status itself failed, every other order of that supplier stops too (§2.4a).
7. **Payment.** At or after the due date, with a valid permit and the buyer's approval, the milestone is paid (`release`). The permit is used up.
8. **Every accepted record updates the supplier's verification history** (§2.4).
9. **If data stays unavailable** after an approved milestone is overdue by the grace period, the buyer gets the remaining balance back (§2.4a).

### 2.3 What "+" adds to v1

| | v1 (live) | SupplierPulse+ |
|---|---|---|
| Registries | Companies House | Companies House + GLEIF (LEI) |
| Signed fields | `status` | Companies House: status, accounts overdue, confirmation statement overdue. GLEIF: entity status, registration status |
| Rules | status is `active` | The buyer picks rules per order (bitmask, §4.3) |
| Schedule | none | A due date per milestone, enforced by `release` |
| Trust | none | On-chain verification history from signed records: fewer paid re-checks for suppliers with a long clean history. Permits are not extended |
| After a hold | the buyer refunds | The buyer claims at any time; after the grace period anyone can trigger the refund to the buyer |
| A supplier fails | only the order that received the record | Every order of that supplier: no payment on an older permit, and anyone can hold its other orders without a new fetch |
| Data stays unavailable | the order stays locked | After an approved milestone is overdue by the grace period without a permit, the buyer gets the remaining balance back |
| Agent | one-shot script | Autonomous loop: schedule by due dates and tier, daily budget, failure handling |
| Judges | CLI tamper script | CLI plus a "Try to break it" page that simulates each attack against the live contract |
| Dashboard | v1 order screen | Protected balance, tiers, failed rules in plain words, an audit trail showing the signed records, agent activity |

### 2.4 Verification-history tiers

The contract keeps a **verification history per supplier** (source plus id), shared across all orders and buyers:
`cleanStreak`, `checks`, `failures`, `lastCountedAt`, `lastCheckAt`, `lastBaseFailureAt`, `tier`.

**What counts.** Only the **base check**: the register status (`active` for Companies House, `ACTIVE` for GLEIF). The buyer-specific rules (accounts or confirmation statement overdue, LEI renewal) don't count, because buyers enable different rules and one history must mean the same thing for everyone.

**Counting:**
- A record only updates the history if it is **newer than anything seen for that supplier** (`timestamp > lastCheckAt`). An older record can still serve its own order, but it never moves the history backwards.
- A record whose base check passes raises `cleanStreak` by 1, but only if at least `tierCountGap` has passed since the last counted one (production 1 day, demo 5 minutes). This stops anyone from farming a tier with rapid checks.
- A record whose base check fails resets `cleanStreak` to 0 and sets `lastBaseFailureAt`. That stops payments on every order of the supplier (§2.4a).

| Tier | `cleanStreak` | Agent re-check interval, production | Demo |
|---|---|---|---|
| Standard | 0 to 2 | 1 day | 10 min |
| Trusted | 3 to 5 | 3 days | 30 min |
| Premium | 6 or more | 7 days | 60 min |

**What a tier changes:** only how often the agent re-checks between due dates, so a supplier with a long clean history costs fewer paid checks.
- **Permits are never extended.** A permit is always valid for the order's `permitTtl`, counted from the evidence time.
- `maxAge` (300 s) never changes.
- Before every due date the agent checks again anyway (§6.3).

**What a tier is not:** a credit score. It is a history of register checks, and an active company can still fail to deliver. Screens and the pitch say "verification history".

### 2.4a Supplier-wide stop and no-data exit

**Supplier-wide stop.** When any order receives a valid record whose base check fails (for example `liquidation`), the contract stores `lastBaseFailureAt` for that supplier. From then on:
- no order of that supplier can be paid on a permit whose evidence is older than the failure (`release` reverts `SupplierFailed`);
- a clean record older than the failure is refused (`SupplierFailed`);
- anyone (the agent) can call `applySupplierFailure(orderId)` to hold another order of that supplier **without a new paid fetch**, because the failure is already verified on chain.

Rule-specific failures (accounts or confirmation statement overdue, LEI renewal) only hold the order that received the record, because other buyers may not have enabled that rule.

**No-data exit.** The buyer gets the remaining balance back when all three hold:
- the buyer has approved the next milestone;
- there is no valid permit;
- the due date has passed by more than `refundGrace`.

`refundRemaining` can then be called by anyone, and the money always goes to the buyer. This covers data that stays unavailable: the register or the Airnode is down, or a field is missing. Milestones already paid stay paid. Without approval there is no exit, because then it is the buyer who has not released the payment.

### 2.5 Demo scenario

**Units:** 1 token = 10¹² wei (0.000001 ETH). An order of 500 + 1,000 + 1,500 tokens costs 0.003 Sepolia ETH.

**Orders.** Orhun creates them on Sepolia at C3. Emre supplies the real suppliers (§6.2).

| Order | Supplier | Registry | Rules | Milestones (tokens), due | Expected |
|---|---|---|---|---|---|
| **A** "PO-1001 Motor supply" | `03778796` Electric Motors International Ltd (clean on every field) | Companies House | `0x06` | 500 (C3 + 20 min), 1,000 (Sat 11:45), 1,500 (Sat 15:30) | M1 paid overnight. Tier rises to Premium. M2 is paid live while we record the video. M3 falls in the judging slot |
| **B** "PO-1002 Gearbox" | `07418033` (liquidation) | Companies House | `0x06` | 1,000 (C3 + 20 min), 2,000 | Held at the first check. The agent triggers the refund after the grace period |
| **C** "PO-1003 Sensors" | `09729896` (active, **accounts and confirmation statement overdue**) | Companies House | `0x02` | 500, 500 | Held with "accounts overdue", although the status alone would have paid |
| **D** "PO-1004 Cable harness (DE)" | `391200JI69LS8L648F30` ASR Component GmbH, `ACTIVE`/`ISSUED` | GLEIF | `0x08` | 500 (C3 + 30 min), 1,000 (Sat 12:00) | Paid overnight, and again live in the video |
| **E** "PO-1005 Castings" | `52990092KBQJF8QBGJ50` MoKa Projekt GmbH, registration **LAPSED** | GLEIF | `0x08` | 500, 500 | Held with "LEI renewal overdue (LAPSED)" |
| **B2** (created live in the video) | `07418033` | Companies House | `0x06` | 1,000, 2,000 (due in 2 minutes) | Held at once by the **supplier-wide stop** (order B already showed `liquidation`), without a new fetch. The refund countdown and the "Claim now" option appear on screen |

Demo suppliers found and verified live by Emre at C1a, with the v1.0 fields. Before C3 they need one check each with the v1.1 fields (`/accounts/next_accounts/overdue`), about $0.05.

**Approvals at creation:** A: M1 and M2. B: M1. C: M1. D: M1 and M2. E: M1. The buyer approves A's M3 live, as the "dual lock" moment.

### 2.6 Shared pitch wording (use it everywhere)

- **Tagline:** *Your supplier was approved last month. That should not approve today's payment.*
- **One-liner:** *Every supplier payment carries its own proof: a fresh, signed register record the contract checked before the money moved.*
- **Verification history:** *Suppliers with a long clean record are re-checked less often. The history is computed from signed records, so nobody can fake it. It is a history of register checks, not a credit score.*
- **Supplier-wide stop:** *One failed register record stops payments to that supplier on every order.*
- **Status quo:** *An alert tells a person, who usually reads it after the payment went out. Here the register itself stops the money, stage by stage.*
- **Agent:** *The agent pays a cent per check, before every due date, within a daily budget, and stops the money the moment a supplier fails.*
- **Honest limit:** *A signature proves the register said it, not that the supplier will deliver. Delivery stays the buyer's approval.*
- **Contrast:** *Today a person checks a supplier once, at onboarding. Here the arbiter is the register itself: signed, fresh, at every payment.*
- **Bigger picture:** *Any register on AirnodeHub can become a payment condition, so every scheduled B2B payment can carry its own proof.*
- **Claim limits:** never say "first". API3's own idea list names registry-condition payments. Our novelty is the mechanism: permits that expire per stage, rules the buyer picks per order, a supplier-wide stop from one verified record, and an autonomous agent with a budget.

---

## 3. Architecture

### 3.1 Components

```text
              AirnodeHub, third-party Airnodes (each response signed)
              ├─ Companies House  getCompanyProfile  $0.01  signer 0x3922…4bFF
              └─ GLEIF            getLegalEntity     $0.01  signer 0x26d8…C20c
                         ▲  POST + x402 payment (aUSD on Base Sepolia)
                         │
 ┌──────────────────┐ FETCH_CMD ┌──────────────────────────────┐
 │ Agent (Python)   │──────────▶│ Data layer (Node)            │  Emre
 │ api3/agent/      │◀──────────│ fetch / verify / tamper /    │
 │ Julien           │ signed    │ local signer                 │
 └────────┬─────────┘ JSON §4.1 └──────────────┬───────────────┘
          │ cast call / cast send               │ same JSON files
          ▼                                     ▼
 ┌──────────────────────────────┐   ┌──────────────────────────┐
 │ SupplierPulsePlus (Sepolia)  │◀──│ Judge CLI plus-submit.sh │  Emre
 │ api3/src/  Orhun             │   └──────────────────────────┘
 └────────────▲─────────────────┘
              │ read-only RPC + eth_call simulation
 ┌────────────┴─────────────────┐
 │ demo/index.html  (dashboard) │  Batu
 │ demo/judge.html  (break it)  │
 └──────────────────────────────┘
```

### 3.2 Networks, addresses, signers

| Item | Value |
|---|---|
| Contract chain | Ethereum Sepolia, chain id `11155111`. RPCs: `https://ethereum-sepolia-rpc.publicnode.com` (also works from browsers) and `https://sepolia.gateway.tenderly.co`. **Tenderly refused bursts on 30 Oct ~16:20** (`-32603 Internal server error`), so use publicnode when that happens |
| Payment chain | Base Sepolia `eip155:84532`. aUSD is `0xbeA34973e5f67F18F656A2C6070C64326C791808` (6 decimals). The payer needs no ETH |
| Companies House Airnode | `https://airnode-companies-house.fly.dev/`, signer `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` |
| GLEIF Airnode | `https://airnode-gleif.fly.dev/`, signer `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c` |
| v1 contract (fallback) | `0x91d7dbae109029b2b1245179a68ac362799674d7` |
| **v2 contract** | *set at C3 by Orhun (also in `docs/evidence.md` and `api3/.env.example`)* |
| Agent wallet | `0xED3418aE93669a640650728E70f7aA712083253a` (Julien). Funded at ~16:55: 0.047 Sepolia ETH, and 10 aUSD minted by the wallet itself on Base Sepolia (mint tx `0xa0cf7101…0c70`) |
| Buyer wallet (demo orders) | Orhun's deployer `0xEb3EB6da882798062b30CeC11AAaDe306287ce41` |
| Supplier payout wallets | Fresh addresses the team controls. **Never anvil test addresses on Sepolia**, because anyone can sweep them |

### 3.3 Repository layout and file ownership

Only edit files you own. That rule is what keeps everyone from blocking each other.

| Path | Owner | Notes |
|---|---|---|
| `api3/src/ISupplierPulsePlus.sol`, `api3/src/SupplierPulsePlus.sol`, `api3/src/JsonFields.sol` (boolean parser) | Orhun | New files. Do not edit `SupplierPulse.sol` or `PriceParser.sol` |
| `api3/test/SupplierPulsePlus.t.sol` | Orhun | |
| `api3/script/DeploySupplierPulsePlus.s.sol` | Orhun | |
| `api3/scripts/plus-lib.sh`, `plus-local.sh`, `plus-create-order.sh`, `plus-approve.sh`, `plus-refund.sh`, `plus-status.sh`, `plus-demo-orders.sh` | Orhun | |
| `api3/.env.example` | Orhun | Others ask in PROGRESS for a line to be added |
| `api3/x402/requests.mjs`, `airnode-fetch.mjs`, `verify.mjs`, `tamper.mjs`, `sign-local.mjs`, `local-registry.json`, `test-requests.mjs` | Emre | `ch-fetch.mjs` stays as the v1 fetcher |
| `api3/scripts/fetch-evidence.sh`, `fetch-local.sh`, `plus-submit.sh` | Emre | |
| `api3/fixtures/**`, `docs/data-sources.md` | Emre | Real signed responses and the supplier research |
| `api3/agent/**` (including `api3/agent/.env.example` and `.gitignore`), `docs/agent.md` | Julien | |
| `demo/**` | Batu | Merge `batu/demo-screen` first |
| `README.md` (root), `docs/research.md`, `docs/pitch.md`, `docs/drafts/**` | Ulaş | Merge Batu's `docs/drafts/` first |
| `docs/SUPPLIERPULSE_PLUS.md` (this file) | Julien | Each owner may edit their own §6 section. Interface changes follow §4.9 |
| `docs/PROGRESS.md`, `docs/evidence.md` | everyone | Append only: your own log entries and your own evidence section. On a merge conflict, keep both sides |

---

## 4. Interfaces (frozen at C0)

Everything another workstream depends on is in this section. Code against it exactly. To change it, follow §4.9.

### 4.1 The signed response file (every tool reads and writes this)

```json
{
  "source": "ch",
  "supplierId": "09729896",
  "airnode": "0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF",
  "requestHash": "0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f",
  "timestamp": "1793371032",
  "data": "0x7b226163636f756e74735f6f766572647565223a66616c73652c…",
  "raw": "{\"accounts_overdue\":false,\"confirmation_overdue\":false,\"status\":\"active\"}",
  "signature": "0x…65 bytes…",
  "paymentTx": "0x… or null",
  "priceUsd": "0.01",
  "fetchedAt": "2026-10-30T18:00:00Z"
}
```

- `source` is `"ch"` (Companies House, contract source 0) or `"gleif"` (contract source 1).
- `data` is the hex of the **exact signed bytes**. `raw` is the same bytes as a UTF-8 string. Submit `data`, never a re-serialised `raw`.
- `timestamp` is a decimal string in unix seconds.
- The format is a superset of v1 (`airnode`, `requestHash`, `timestamp`, `data`, `signature`, `raw`, `paymentTx`). Consumers must ignore fields they don't know.

### 4.2 Requests and request hashes

**Canonical rule.** This is the starter's `deriveRequestHash`, and it is verified: the v1 template reproduces the real signed sample.

```text
requestHash = keccak256(utf8(JSON.stringify([operation, sortedParameters, sortedProjection])))
```

- `sortedParameters` is `[[key, value], …]` sorted by key in UTF-8 byte order.
- `sortedProjection` is `[[field, pointer], …]` sorted by field.
- There is no whitespace.

**Companies House (source 0).** Replace `<ID>`:

```text
["getCompanyProfile",[["company_number","<ID>"]],[["accounts_overdue","/accounts/next_accounts/overdue"],["confirmation_overdue","/confirmation_statement/overdue"],["status","/company_status"]]]
```

HTTP body:

```json
{"operation":"getCompanyProfile","parameters":{"company_number":"<ID>"},"responseProjection":{"accounts_overdue":"/accounts/next_accounts/overdue","confirmation_overdue":"/confirmation_statement/overdue","status":"/company_status"}}
```

**GLEIF (source 1):**

```text
["getLegalEntity",[["lei","<ID>"]],[["entity_status","/data/attributes/entity/status"],["registration_status","/data/attributes/registration/status"]]]
```

HTTP body:

```json
{"operation":"getLegalEntity","parameters":{"lei":"<ID>"},"responseProjection":{"entity_status":"/data/attributes/entity/status","registration_status":"/data/attributes/registration/status"}}
```

**Supplier ids:**
- Companies House: 1 to 10 characters `[0-9A-Z]`, uppercase, leading zeros kept (`09729896`, `SC193794`).
- GLEIF: exactly 20 characters `[0-9A-Z]`.

**Supplier key:** `supplierKey = keccak256(abi.encodePacked(uint8 source, bytes(supplierId)))`.

**Test vectors.** Computed with cast 1.8.7. Every implementation (Solidity, JS, Python) must reproduce them.

| Input | Value |
|---|---|
| `requestHash` Companies House `09729896` | `0x6e84889a218993dcdaaa5e41a15b5b1bba283e48ca36763248620abbe2f17f0f` |
| `requestHash` GLEIF `TESTLEI0000000000000` | `0x82e8da1da50a59eb4941e8461f35869cb1a4a95183dc1ea84075b99af97d790f` |
| `supplierKey(0, "09729896")` | `0xabf8d9a610a62d829c8b4ecdf8bee9db7988e3386692f4e1667c46a4698b3d2a` |
| `supplierKey(1, "TESTLEI0000000000000")` | `0x31b072a73946faf810268129043fd17faebcf51b0756ab720dffc03eaaefe0f6` |
| Reference: the v1 one-field template for `09729896` (equals the real signed sample) | `0xcae416f2dce5fb6bb595eafe8c5f11ce9df4b33f8664042e10f8f776739fab48` |

> ⚠️ **Not yet verified live:** the Companies House pointers `/accounts/next_accounts/overdue` and `/confirmation_statement/overdue`, and both GLEIF pointers.
> **v1.1:** these replace the deprecated `/accounts/overdue` and `/has_insolvency_history` from the official Companies House schema. Both nested fields are optional in that schema, so some companies may not return them.
> Emre verifies them with real calls by **C1a (18:30)**. Fallback, decided by Emre and Orhun at C1a:
> 1. If a field is missing for a demo company, choose a demo company that has it.
> 2. If it is missing for most companies, drop that field and its rule from the template.
> 3. In the worst case, fall back to status only, which is v1's verified request.
>
> Any change follows §4.9: update this section and the vectors in the same commit, then write a PROGRESS entry starting with `INTERFACE CHANGE:`. On the contract side that is two string constants.
> Until then, use the pointers exactly as written.

### 4.3 Signed fields and rules

The signed `data` is a flat JSON object containing exactly the projected fields. **Key order is not guaranteed**, so always parse by key.

```json
{"accounts_overdue":false,"confirmation_overdue":false,"status":"active"}
{"entity_status":"ACTIVE","registration_status":"ISSUED"}
```

| Bit | Name | Source | Field | Clean when | Label for screens |
|---|---|---|---|---|---|
| base (always on) | none | Companies House | `status` (string) | `== "active"` | registry status not active |
| base (always on) | none | GLEIF | `entity_status` (string) | `== "ACTIVE"` | LEI entity not active |
| `0x01` | reserved | | | Removed in v1.1: the "insolvency history" field is deprecated, and current insolvency already shows in the status (liquidation, administration) | |
| `0x02` | `RULE_ACCOUNTS_CURRENT` | Companies House | `accounts_overdue` (bool) | `false` | accounts overdue |
| `0x04` | `RULE_CONFIRMATION_CURRENT` | Companies House | `confirmation_overdue` (bool) | `false` | confirmation statement overdue |
| `0x08` | `RULE_LEI_ISSUED` | GLEIF | `registration_status` (string) | `== "ISSUED"` | LEI renewal overdue (e.g. LAPSED) |

- **`failedRules`** (uint8) holds the bits of the enabled rules that failed, OR `0x80` if the base check failed. A record is **clean exactly when `failedRules == 0`**.
- **Valid `rules` per order:** Companies House ⊆ `0x06`, GLEIF ⊆ `0x08`. Anything else, including `0x01`, reverts with `BadRules`.
- **LAPSED is not inactive.** For GLEIF, `LAPSED` means the LEI was not renewed on time. It does not mean the entity is inactive or insolvent, so screens say "LEI renewal overdue".
- **Three outcomes for screens:**
  - **verified eligible** (clean);
  - **verified policy failure** (held, with labels);
  - **data unavailable**: no signed record. Never show this as a negative fact.
- **Missing field:** if a profile lacks a projected field, the Airnode answers HTTP 400 and signs nothing. The agent reports "no data" and retries. Without evidence there is no payment, and the no-data exit applies (§2.4a).
- **Parsing in Solidity:**
  - strings with `PriceParser.parseString(data, '"status":')`;
  - booleans with the new `JsonFields.parseBool(data, '"accounts_overdue":')`: skip spaces, accept the literals `true` or `false`, otherwise revert `NoBool()`.
  - Key patterns always include the leading quote, so `"status":` can never match inside `"entity_status":`.

### 4.4 Contract interface: `api3/src/ISupplierPulsePlus.sol`

Orhun copies this verbatim at C0 (v1.1), and `SupplierPulsePlus` implements it.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// SupplierPulse+ interface, frozen in docs/SUPPLIERPULSE_PLUS.md §4.4 (v1.1).
/// Enums travel as uint8:
///   source  0 CompaniesHouse, 1 Gleif
///   state   0 Active, 1 Held, 2 Closed
///   outcome 0 Paid, 1 AwaitingApproval, 2 NotDue, 3 Held
///   tier    0 Standard, 1 Trusted, 2 Premium
/// rules / failedRules bits: 0x01 reserved (unused), 0x02 accounts current (CH),
///   0x04 confirmation statement current (CH), 0x08 LEI registration issued (GLEIF),
///   0x80 (failedRules only) base status check failed.
interface ISupplierPulsePlus {
    event OrderCreated(
        uint256 indexed orderId,
        address indexed buyer,
        bytes32 indexed supplierKey,
        address supplier,
        uint8 source,
        string supplierId,
        bytes32 requestHash,
        bytes32 orderRef,
        uint256 total,
        uint8 rules
    );
    event MilestoneApproved(uint256 indexed orderId, uint256 milestone);
    event EvidenceAccepted(
        uint256 indexed orderId,
        bytes32 indexed supplierKey,
        bool clean,
        uint8 failedRules,
        uint256 timestamp,
        bytes32 digest,
        address submitter,
        bytes data
    );
    event PermitIssued(uint256 indexed orderId, uint256 milestone, uint256 amount, uint64 validUntil, bytes32 evidence);
    event MilestonePaid(uint256 indexed orderId, uint256 milestone, address supplier, uint256 amount, bytes32 evidence);
    event OrderHeld(uint256 indexed orderId, uint8 failedRules, uint256 remaining, uint64 autoRefundAt);
    event OrderRefunded(uint256 indexed orderId, address buyer, uint256 amount, address triggeredBy, bool noDataExit);
    event TierChanged(bytes32 indexed supplierKey, uint8 oldTier, uint8 newTier, uint32 cleanStreak);
    event ConfigUpdated(uint8 source, address airnode, uint256 maxAgeSeconds);

    error WrongSigner(address recovered);
    error WrongRequest(bytes32 got, bytes32 expected);
    error StaleResponse(uint256 timestamp, uint256 nowTs);
    error FutureResponse(uint256 timestamp, uint256 nowTs);
    error Replayed(bytes32 digest);
    error NotNewer(uint256 timestamp, uint256 lastCheck);
    error NoValidPermit(uint256 milestone);
    error PermitExpired(uint256 validUntil, uint256 nowTs);
    error NotApproved(uint256 milestone);
    error NotDue(uint256 dueDate, uint256 nowTs);
    error NotActive(uint8 state);
    error NotRefundable();
    error RefundNotYet(uint256 refundableAt);
    error SupplierFailed(uint256 failedAt);
    error NoNewerFailure();
    error BadOrder();
    error BadSource();
    error BadSupplierId();
    error BadRules();
    error NotAuthorized();
    error TransferFailed();

    // ---- buyer
    function createOrder(
        uint8 source,
        string calldata supplierId,
        address payable supplier,
        bytes32 orderRef,
        uint256[] calldata amounts,
        uint64[] calldata dueDates,
        uint64 permitTtl,
        uint8 rules
    ) external payable returns (uint256 orderId);
    function approveMilestone(uint256 orderId, uint256 milestone) external;
    /// Held: the buyer any time, anyone from heldAt + refundGrace. Active (no-data exit): anyone, once the next
    /// milestone is approved, has no valid permit and is overdue by refundGrace. The money always goes to the buyer.
    function refundRemaining(uint256 orderId) external;

    // ---- anyone (agent, judges)
    function submitEvidence(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (bool clean);
    function release(uint256 orderId) external;
    function checkAndRelease(
        uint256 orderId,
        bytes32 requestHash,
        uint256 timestamp,
        bytes calldata data,
        bytes calldata signature
    ) external returns (uint8 outcome);
    /// Hold this order because its supplier's register status failed on another order (no new evidence needed).
    function applySupplierFailure(uint256 orderId) external;

    // ---- views
    function requestHashFor(uint8 source, string calldata supplierId) external pure returns (bytes32);
    function supplierKeyOf(uint8 source, string calldata supplierId) external pure returns (bytes32);
    function ordersLength() external view returns (uint256);
    function orderInfo(uint256 orderId)
        external
        view
        returns (
            address buyer,
            address supplier,
            uint8 source,
            string memory supplierId,
            bytes32 requestHash,
            bytes32 orderRef,
            uint64 permitTtl,
            uint8 rules
        );
    function orderMilestones(uint256 orderId)
        external
        view
        returns (uint256[] memory amounts, uint64[] memory dueDates, bool[] memory approved);
    function orderStatus(uint256 orderId)
        external
        view
        returns (
            uint8 state,
            uint256 paid,
            uint256 remaining,
            uint256 nextMilestone,
            uint256 milestones,
            uint64 permitValidUntil,
            bool permitValid,
            uint256 lastCheck
        );
    function orderSchedule(uint256 orderId)
        external
        view
        returns (
            uint64 nextDueDate,
            bool nextApproved,
            uint8 lastFailedRules,
            uint64 heldAt,
            uint64 autoRefundAt,
            uint8 tier
        );
    function supplierRecord(bytes32 supplierKey)
        external
        view
        returns (
            uint32 cleanStreak,
            uint32 checks,
            uint32 failures,
            uint64 lastCountedAt,
            uint64 lastCheckAt,
            uint64 lastBaseFailureAt,
            uint8 tier
        );
    function airnodeOf(uint8 source) external view returns (address);
    function maxAge() external view returns (uint256);
    function tierCountGap() external view returns (uint64);
    function refundGrace() external view returns (uint64);
    function usedDigests(bytes32 digest) external view returns (bool);
    function admin() external view returns (address);

    // ---- admin
    function setAirnode(uint8 source, address airnode) external;
    function setMaxAge(uint256 newMaxAge) external;
}
```

The library errors can also surface and must be decodable by the tools:
- `AirnodeVerifier`: `InvalidSignatureLength()`, `InvalidSignatureS()`, `InvalidSignatureV()`, `InvalidSigner()`
- `PriceParser` and `JsonFields`: `KeyNotFound()`, `NoNumber()`, `NoString()`, `NoBool()`

### 4.5 Contract behaviour (exact, v1.1)

**Constructor:** `constructor(address chAirnode, address gleifAirnode, uint256 maxAge, uint64 tierCountGap, uint64 refundGrace)`. `admin` is the deployer.

**Constants:** `MAX_FUTURE_SKEW = 60`, `TRUSTED_STREAK = 3`, `PREMIUM_STREAK = 6`. There are no permit multipliers.

**Deploy values:**

| Deployment | `maxAge` | `tierCountGap` | `refundGrace` |
|---|---|---|---|
| Production-like | 300 | 86400 | 172800 |
| **Sepolia demo** | 300 | 300 | 600 |
| Local test chain | 300 | 60 | 120 |

**`createOrder`.** Validations, in this order:
1. `source ≤ 1`, otherwise `BadSource`.
2. The id format from §4.2, otherwise `BadSupplierId`.
3. `rules` is valid for the source (Companies House ⊆ `0x06`, GLEIF ⊆ `0x08`), otherwise `BadRules`.
4. `supplier != 0`, `amounts.length ≥ 1`, `amounts.length == dueDates.length`, every amount > 0, due dates are non-decreasing, `permitTtl > 0`, and `msg.value == sum(amounts)`. Otherwise `BadOrder`.

Effects:
- Store `requestHash = requestHashFor(source, id)` and `supplierKey = supplierKeyOf(source, id)`.
- `approved = new bool[](n)`.
- Emit `OrderCreated`.

**`approveMilestone`.** Only the buyer (`NotAuthorized`); the milestone must be `< n` (`BadOrder`). Sets `approved[m] = true` and emits `MilestoneApproved`.

**`submitEvidence`.** The order of checks matters, because it decides which error each tamper case produces:
1. The order exists (`BadOrder`).
2. `state == Active` (`NotActive(state)`).
3. `requestHash == order.requestHash` (`WrongRequest`).
4. `timestamp ≤ now + MAX_FUTURE_SKEW` (`FutureResponse`).
5. `now − timestamp ≤ maxAge` (`StaleResponse`).
6. The digest is unused (`Replayed`).
7. `timestamp > order.lastCheck` (`NotNewer`).
8. The signer recovered with `AirnodeVerifier` equals `airnodeOf(order.source)` (`WrongSigner(recovered)`).
9. Parse the fields of the order's source and compute `failedRules` (§4.3).
10. If the record is clean but `timestamp ≤ supplier.lastBaseFailureAt`, revert `SupplierFailed(lastBaseFailureAt)`: a clean record that is older than a known failure.

Then the effects:
- `usedDigests[d] = true`, `order.lastCheck = timestamp`, `order.lastFailedRules = failedRules`.
- **Supplier history, only if `timestamp > supplier.lastCheckAt`.** Then `checks++` and `lastCheckAt = timestamp`.
  - Base check passed, and (`lastCountedAt == 0` or `timestamp ≥ lastCountedAt + tierCountGap`): `cleanStreak++` and `lastCountedAt = timestamp`.
  - Base check failed: `failures++`, `cleanStreak = 0`, `lastBaseFailureAt = timestamp`.
  - Recompute the tier, and emit `TierChanged` if it changed. Rule-only failures don't touch the history.
- Emit `EvidenceAccepted(orderId, supplierKey, clean, failedRules, timestamp, d, msg.sender, data)`.
- **Not clean:** `state = Held`, `heldAt = now`, clear the permit, emit `OrderHeld(orderId, failedRules, remaining, heldAt + refundGrace)`, and return `false`.
- **Clean:** set the permit to `(validUntil = timestamp + permitTtl, milestone = paidCount, evidence = d, evidenceAt = timestamp)`, emit `PermitIssued`, and return `true`. A new clean record replaces an older permit.

**`release`.** Anyone may call it. Checks:
- `state == Active` (`NotActive`)
- `m = paidCount`, and the permit exists for `m` (`NoValidPermit(m)`)
- `now ≤ validUntil` (`PermitExpired`)
- `approved[m]` (`NotApproved(m)`)
- `now ≥ dueDates[m]` (`NotDue(dueDates[m], now)`)
- `permit.evidenceAt > supplier.lastBaseFailureAt` (`SupplierFailed(lastBaseFailureAt)`): a newer failure on any order stops this payment

Effects:
- Clear the permit, `paidCount++`, `paid += amount`, and set `state = Closed` after the last milestone.
- Emit `MilestonePaid`.
- Transfer to the supplier (`TransferFailed`).

State changes happen before the transfer, as in v1.

**`checkAndRelease`.** `clean = submitEvidence(…)`, then:
- not clean: return `3` (Held);
- `!approved[m]`: return `1` (AwaitingApproval);
- `now < dueDates[m]`: return `2` (NotDue);
- otherwise call `release` and return `0` (Paid).

It reverts only on verification failures and on `SupplierFailed`.

**`applySupplierFailure`.** Anyone may call it.
- Checks: `state == Active` (`NotActive`), and `supplier.lastBaseFailureAt > order.lastCheck` (`NoNewerFailure`).
- Effects: `state = Held`, `heldAt = now`, `lastFailedRules = 0x80`, clear the permit, and emit `OrderHeld(orderId, 0x80, remaining, heldAt + refundGrace)`.

**`refundRemaining`.**
- **Held:** `msg.sender == buyer` or `now ≥ heldAt + refundGrace` (`RefundNotYet(heldAt + refundGrace)`). `noDataExit = false`.
- **Active (no-data exit):** with `m = paidCount`:
  - `approved[m]` (`NotApproved(m)`);
  - no valid permit for `m` (`NotRefundable`);
  - `now ≥ dueDates[m] + refundGrace` (`RefundNotYet(dueDates[m] + refundGrace)`).

  Anyone may call it. `noDataExit = true`.
- **Closed:** `NotRefundable`.
- Effects: `state = Closed`, emit `OrderRefunded(orderId, buyer, remaining, msg.sender, noDataExit)`, and transfer the remaining balance **to the buyer**.

A hold is final: there is no un-hold.

**Views:**
- `orderSchedule.nextDueDate` is `dueDates[paidCount]`, or `0` when closed.
- `autoRefundAt`:
  - `heldAt + refundGrace` when held;
  - `dueDates[m] + refundGrace` when active, the next milestone is approved and there is no valid permit (the no-data exit);
  - otherwise `0`.
- `tier` is the supplier's current tier.
- `orderStatus.permitValid` follows v1: active, permit exists for `paidCount`, and `now ≤ validUntil`.

**Admin:** `setAirnode` and `setMaxAge` are admin only and emit `ConfigUpdated`.

### 4.6 The ABI for tools

**cast signatures** (for bash and the Python agent; `cast call` prints one value per line, `cast call --json` prints a JSON array):

| Purpose | Signature |
|---|---|
| order count | `ordersLength()(uint256)` |
| order info | `orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)` |
| milestones | `orderMilestones(uint256)(uint256[],uint64[],bool[])` |
| status | `orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint64,bool,uint256)` |
| schedule | `orderSchedule(uint256)(uint64,bool,uint8,uint64,uint64,uint8)` |
| supplier | `supplierRecord(bytes32)(uint32,uint32,uint32,uint64,uint64,uint64,uint8)` |
| key | `supplierKeyOf(uint8,string)(bytes32)` |
| evidence | `submitEvidence(uint256,bytes32,uint256,bytes,bytes)` returns `(bool)` |
| check and pay | `checkAndRelease(uint256,bytes32,uint256,bytes,bytes)` returns `(uint8)` |
| pay | `release(uint256)` |
| supplier-wide stop | `applySupplierFailure(uint256)` |
| refund | `refundRemaining(uint256)` |
| create | `createOrder(uint8,string,address,bytes32,uint256[],uint64[],uint64,uint8)` |
| approve | `approveMilestone(uint256,uint256)` |

cast prints numbers like `1793371032 [1.793e9]`, so strip everything after the first space. Strings come back quoted. With `--json`, `uint256` values come as strings.

**ethers v6 human-readable ABI** (for the browser pages):

```js
export const PULSE_PLUS_ABI = [
  "function ordersLength() view returns (uint256)",
  "function orderInfo(uint256) view returns (address buyer, address supplier, uint8 source, string supplierId, bytes32 requestHash, bytes32 orderRef, uint64 permitTtl, uint8 rules)",
  "function orderMilestones(uint256) view returns (uint256[] amounts, uint64[] dueDates, bool[] approved)",
  "function orderStatus(uint256) view returns (uint8 state, uint256 paid, uint256 remaining, uint256 nextMilestone, uint256 milestones, uint64 permitValidUntil, bool permitValid, uint256 lastCheck)",
  "function orderSchedule(uint256) view returns (uint64 nextDueDate, bool nextApproved, uint8 lastFailedRules, uint64 heldAt, uint64 autoRefundAt, uint8 tier)",
  "function supplierRecord(bytes32) view returns (uint32 cleanStreak, uint32 checks, uint32 failures, uint64 lastCountedAt, uint64 lastCheckAt, uint64 lastBaseFailureAt, uint8 tier)",
  "function supplierKeyOf(uint8 source, string supplierId) pure returns (bytes32)",
  "function requestHashFor(uint8 source, string supplierId) pure returns (bytes32)",
  "function airnodeOf(uint8) view returns (address)",
  "function maxAge() view returns (uint256)",
  "function tierCountGap() view returns (uint64)",
  "function refundGrace() view returns (uint64)",
  "function usedDigests(bytes32) view returns (bool)",
  "function createOrder(uint8 source, string supplierId, address supplier, bytes32 orderRef, uint256[] amounts, uint64[] dueDates, uint64 permitTtl, uint8 rules) payable returns (uint256)",
  "function approveMilestone(uint256 orderId, uint256 milestone)",
  "function submitEvidence(uint256 orderId, bytes32 requestHash, uint256 timestamp, bytes data, bytes signature) returns (bool clean)",
  "function release(uint256 orderId)",
  "function checkAndRelease(uint256 orderId, bytes32 requestHash, uint256 timestamp, bytes data, bytes signature) returns (uint8 outcome)",
  "function applySupplierFailure(uint256 orderId)",
  "function refundRemaining(uint256 orderId)",
  "event OrderCreated(uint256 indexed orderId, address indexed buyer, bytes32 indexed supplierKey, address supplier, uint8 source, string supplierId, bytes32 requestHash, bytes32 orderRef, uint256 total, uint8 rules)",
  "event MilestoneApproved(uint256 indexed orderId, uint256 milestone)",
  "event EvidenceAccepted(uint256 indexed orderId, bytes32 indexed supplierKey, bool clean, uint8 failedRules, uint256 timestamp, bytes32 digest, address submitter, bytes data)",
  "event PermitIssued(uint256 indexed orderId, uint256 milestone, uint256 amount, uint64 validUntil, bytes32 evidence)",
  "event MilestonePaid(uint256 indexed orderId, uint256 milestone, address supplier, uint256 amount, bytes32 evidence)",
  "event OrderHeld(uint256 indexed orderId, uint8 failedRules, uint256 remaining, uint64 autoRefundAt)",
  "event OrderRefunded(uint256 indexed orderId, address buyer, uint256 amount, address triggeredBy, bool noDataExit)",
  "event TierChanged(bytes32 indexed supplierKey, uint8 oldTier, uint8 newTier, uint32 cleanStreak)",
  "error WrongSigner(address recovered)", "error WrongRequest(bytes32 got, bytes32 expected)",
  "error StaleResponse(uint256 timestamp, uint256 nowTs)", "error FutureResponse(uint256 timestamp, uint256 nowTs)",
  "error Replayed(bytes32 digest)", "error NotNewer(uint256 timestamp, uint256 lastCheck)",
  "error NoValidPermit(uint256 milestone)", "error PermitExpired(uint256 validUntil, uint256 nowTs)",
  "error NotApproved(uint256 milestone)", "error NotDue(uint256 dueDate, uint256 nowTs)",
  "error NotActive(uint8 state)", "error NotRefundable()", "error RefundNotYet(uint256 refundableAt)",
  "error SupplierFailed(uint256 failedAt)", "error NoNewerFailure()",
  "error BadOrder()", "error BadSource()", "error BadSupplierId()", "error BadRules()",
  "error NotAuthorized()", "error TransferFailed()",
  "error InvalidSignatureLength()", "error InvalidSignatureS()", "error InvalidSignatureV()", "error InvalidSigner()",
  "error KeyNotFound()", "error NoNumber()", "error NoString()", "error NoBool()",
];
```

### 4.7 Command-line tools

All paths are from the repo root.

| Command | Owner | Does | Output | Exit codes |
|---|---|---|---|---|
| `api3/scripts/fetch-evidence.sh <ch\|gleif> <id> [out.json]` | Emre | Paid fetch over x402, then a check of request hash and signer | §4.1 JSON | `0` ok, `2` usage, `3` no data (HTTP error, unknown supplier, missing field), `4` payment failed (no aUSD, x402 error), `5` verification failed |
| `api3/scripts/fetch-local.sh <ch\|gleif> <id> [out.json]` | Emre | Same interface, but signed locally from `api3/x402/local-registry.json` with the anvil keys (§4.8). Costs $0 | §4.1 JSON (`priceUsd` `"0"`) | same codes. An unknown id gives `3` |
| `node api3/x402/sign-local.mjs <ch\|gleif> <id> '<data json>' [timestamp]` | Emre | Signs any data with the local key of that source | §4.1 JSON | `0`, `2` |
| `node api3/x402/verify.mjs <file> [--max-age 300] [--local]` | Emre | Off-chain checks: signer per source (`--local` also accepts the anvil signers), request hash against §4.2, age | table on stdout | `0` valid, `1` invalid |
| `node api3/x402/tamper.mjs <file> <value\|stale\|request\|key\|replay>` | Emre | Writes the tampered response to stdout and explains it on stderr | §4.1 JSON | `0`, `2` |
| `api3/scripts/plus-submit.sh <orderId> <file> [tamper] [--send]` | Emre | Judge CLI. Simulates `submitEvidence` with `cast call`; `--send` also sends it | `ACCEPTED clean` / `ACCEPTED held: <labels>` / `REJECTED <Error>(args)` | `0` accepted, `1` rejected, `2` usage |
| `api3/scripts/plus-local.sh` | Orhun | Starts the local test chain, deploys the contract, creates sample orders (§4.8) | writes `api3/.local/plus-local.env` | `0` |
| `api3/scripts/plus-create-order.sh <ch\|gleif> <id> <supplier> <amounts csv, tokens> <due csv: +seconds or unix> [rules] [permitTtl]` | Orhun | The buyer creates an order (env `BUYER_PRIVATE_KEY`, `ORDER_REF`) | the order id | `0`, `1` |
| `api3/scripts/plus-approve.sh <orderId> <milestone>` | Orhun | Buyer approval | tx | |
| `api3/scripts/plus-refund.sh <orderId>` | Orhun | The buyer claims the remaining balance of a held order | tx | |
| `api3/scripts/plus-status.sh <orderId>` | Orhun | Text view: state, protected balance, milestones with due dates, permit, tier, failed rules as labels, refund countdown | text | |
| `api3/scripts/plus-demo-orders.sh` | Orhun | Creates the Sepolia demo orders A to E (§2.5). Supplier ids come from env | the ids | |
| `python3 api3/agent/pulse_agent.py run\|once\|plan\|report` | Julien | The autonomous agent (§6.3) | JSONL log | |

**Tamper semantics.** `tamper.mjs` and the judge page must behave identically:

| Mode | Change | Expected rejection |
|---|---|---|
| `value` | Companies House: `status` `active` → `liquidation`, any other value → `active`; with no status field, flip the first boolean. GLEIF: `entity_status` `ACTIVE` ↔ `INACTIVE`. `data` is re-encoded; the signature is unchanged | `WrongSigner` |
| `stale` | `timestamp − 3600` | `StaleResponse` |
| `request` | `requestHash := requestHashFor(same source, other id)`: Companies House `00000001`, GLEIF `TESTLEI0000000000001` | `WrongRequest` |
| `key` | The untouched response, re-signed with a random key | `WrongSigner(random address)` |
| `replay` | Unchanged; submitted after the original was accepted | `Replayed` |

**Real inputs for the video and for judges (v1.1).** The mutation modes are good tests, but for (b) and (c) a judge should see untouched, genuinely signed records:
- **(b) too old:** a real signed response for the order's company that is older than `maxAge`, submitted unchanged. Emre keeps one from C1a in `api3/fixtures/`.
- **(c) different request:** a real, fresh signed response for **another** company (e.g. `12493325`), submitted unchanged to order A.

In the video, send the four tamper cases as **real transactions** (`plus-submit.sh … --send`), so each one shows a red "Fail" on Etherscan. They cost a few cents of Sepolia gas.

### 4.8 Local development environment (no money, no waiting)

These are anvil's public default keys. **Never send value to them on a public network.**

| Role | Address | Private key |
|---|---|---|
| buyer / deployer (#0) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| local Companies House Airnode (#1) | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| local GLEIF Airnode (#2) | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| agent (#3) | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| supplier wallet 1 (#4) | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | none needed |
| supplier wallet 2 (#5) | `0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc` | none needed |

**`plus-local.sh` (Orhun):**
- Starts `anvil` on port 8545 unless it is already running, and keeps it running.
- Deploys `SupplierPulsePlus(#1 address, #2 address, 300, 60, 120)` from #0.
- Creates these orders from #0:

| Local order | Source and id | Rules | Milestones (tokens) | Due | Approved |
|---|---|---|---|---|---|
| 0 | Companies House `01234567` | `0x06` | 500, 1000, 1500 | +60 s, +600 s, +1200 s | 0, 1 |
| 1 | Companies House `07654321` | `0x06` | 1000, 2000 | +60 s, +600 s | 0 |
| 2 | GLEIF `TESTLEI0000000000000` | `0x08` | 500, 1000 | +60 s, +600 s | 0, 1 |
| 3 | GLEIF `TESTLEI0000000000001` | `0x08` | 500, 500 | +60 s, +600 s | 0 |
| 4 | Companies House `07654321` | `0x06` | 500, 500 | +60 s, +600 s | 0 |
| 5 | Companies House `99999999` (no data) | `0x06` | 500, 500 | +60 s, +600 s | 0 |

- Writes `api3/.local/plus-local.env` (`.local/` is gitignored):

```sh
export EVM_RPC_URL=http://127.0.0.1:8545
export PULSE_PLUS_ADDRESS=0x…
export BUYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export AGENT_PRIVATE_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
export LOCAL_CH_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export LOCAL_GLEIF_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
export FETCH_CMD=api3/scripts/fetch-local.sh
```

**`local-registry.json` (Emre)** has these entries:

| Key | Fields |
|---|---|
| `ch:01234567` | all clean: `active`, nothing overdue |
| `ch:07654321` | `{"accounts_overdue":true,"confirmation_overdue":false,"status":"liquidation"}` |
| `gleif:TESTLEI0000000000000` | `ACTIVE` / `ISSUED` |
| `gleif:TESTLEI0000000000001` | `ACTIVE` / `LAPSED` |

Any other id exits with `3` (no data).

**Before C1**, when these files don't exist yet, use the mocks your section describes.

### 4.9 Changing an interface

§4 is frozen from C0. If you really must change it:
1. Prefer an additive change.
2. Update §4 in this file **in the same commit** as your code.
3. Write a PROGRESS entry that starts with `INTERFACE CHANGE:`.
4. Tell the affected owners directly.

After C2 (22:00) there are no breaking changes unless the whole team agrees.

---

## 5. Ways of working

### 5.1 Git

- **Branches.** The integration branch is `supplierpulse-plus`. It was created from `supplier-pulse` at Orhun's `56530d5`, so it contains everything so far. Personal branches: `orhun/plus-contract`, `emre/plus-data`, `julien/plus-agent`, `batu/plus-ui`, `ulas/plus-story`.
- **Ownership.** Only touch files you own (§3.3). In `docs/PROGRESS.md` and `docs/evidence.md`, add your own entry or section. On a conflict, keep both sides.
- **Merging.** At C1, C2, C3, C4 and C5, every owner merges their own branch:

  ```sh
  git checkout supplierpulse-plus && git pull
  git merge --no-ff <your-branch>
  # run your tests
  git push
  ```

- **`main`.** It stays identical to `supplierpulse-plus`: every change that can affect someone else's code is merged to `main` right away (Julien's rule, 30 Oct). You can base your branch on either.
- **Repo root check.** Before any `git add`, `git rev-parse --show-toplevel` must print the repo root (CLAUDE.md §7). Never run `git add .` outside it.

### 5.2 Secrets, wallets, money

- **`.env` files are gitignored.** `api3/.env` serves the contract scripts and the data layer; `api3/agent/.env` serves the agent. Commit only `*.env.example`.
- **Each developer** uses their own Sepolia key for gas and their own Base Sepolia aUSD for paid calls.
- **The agent wallet** is Julien's. **The buyer** for the demo orders is Orhun's deployer.
- **Never** use anvil keys or addresses on Sepolia. Never paste a key into chat or a doc. Testnets only.

### 5.3 Paid calls ($0.01 each)

- **Budgets:**
  - Emre: up to $0.60 for verification, fixtures and supplier research.
  - The agent: up to $1.00 per day, enforced in code.
  - Everyone else: up to $0.20 for testing.
- **Bulk calls:** announce any scripted bulk calls in PROGRESS first (CLAUDE.md: paid calls need a human's OK).
- **Getting aUSD:** the faucet at <https://api3dao.github.io/airnodehub-hackathon/faucet/> (minting needs Base Sepolia ETH for gas), or ask Batu, who holds about 9.99 aUSD. Without anyone's help:
  1. Bridge a little Sepolia ETH to Base Sepolia through Base's official bridge `0xfd0Bf71F60660E2f608ed56e1659C450eB113120` (`depositETH(200000, 0x)` on Ethereum Sepolia, verified from chain).
  2. Call `mintFromFaucet(uint256)` on the aUSD contract yourself.

### 5.4 Definition of done (for every task)

Code, plus passing tests, plus docs in your own files, plus a PROGRESS entry, merged into `supplierpulse-plus`.

### 5.5 Logging

- **PROGRESS:** use the existing format, `### 2026-10-30 · <Name>` with Changed / Next / Notes. Newest on top.
- **Evidence:** at C3, Orhun creates the section "SupplierPulse+ live (Ethereum Sepolia)" in `docs/evidence.md`. Everyone adds their tx links there.

---

## 6. Workstreams

Each section is complete on its own. **Phase A** needs nothing from anyone else. **Phase B** is integration.

### 6.1 Orhun: contract

**Goal.** `SupplierPulsePlus` implements §4.4 and §4.5 (v1.1) exactly: tamper-safe, fully tested, deployable, with buyer scripts and a local test chain. You also own the Sepolia launch.

**You own:**
- `api3/src/ISupplierPulsePlus.sol`, `api3/src/SupplierPulsePlus.sol`, `api3/src/JsonFields.sol`
- `api3/test/SupplierPulsePlus.t.sol`
- `api3/script/DeploySupplierPulsePlus.s.sol`
- `api3/scripts/plus-{lib,local,create-order,approve,refund,status,demo-orders}.sh`
- `api3/.env.example`

**You depend on:** nothing to start. Real fixtures from Emre at C1a are only needed for one optional test.

**Phase A**

1. **(→ +30 min)** Copy §4.4 verbatim into `ISupplierPulsePlus.sol`. Push a skeleton `SupplierPulsePlus` that compiles and implements the interface, even if the bodies are still empty.
2. **(→ 19:00)** Implement:
   - **Storage.** An `Order` with `buyer`, `supplier`, `source`, `supplierId`, `supplierKey`, `requestHash`, `orderRef`, `permitTtl`, `rules`, `paidCount`, `state`, `paid`, `amounts[]`, `dueDates[]`, `approved[]`, `permit` (`validUntil`, `milestone`, `evidence`, `evidenceAt`), `lastFailedRules`, `lastCheck` and `heldAt`.
   - `mapping(bytes32 => SupplierRecord)` with `cleanStreak`, `checks`, `failures`, `lastCountedAt`, `lastCheckAt`, `lastBaseFailureAt` and `tier`; `mapping(bytes32 => bool) public usedDigests`; the Airnode per source.
   - **`requestHashFor`.** The two templates from §4.2 via `abi.encodePacked`, with id validation like v1 `companyRequestHash`. GLEIF ids are exactly 20 characters.
   - **`supplierKeyOf`**, the rule evaluation (§4.3) and `JsonFields.parseBool`.
   - **Verification history** that counts only the base check and only moves forward, the supplier-wide stop (`lastBaseFailureAt`, the `SupplierFailed` checks, `applySupplierFailure`), `release` with `NotDue`, the `checkAndRelease` outcomes, `refundRemaining` with both paths (§4.5), all views, and admin.
3. **Forge tests.** Use the same style as `SupplierPulse.t.sol` (custom `Vm`, `vm.sign`). At least these:
   - **Hashes and keys:** `requestHashFor` and `supplierKeyOf` reproduce the §4.2 vectors.
   - **Bad input:** `BadSupplierId` (empty, too long, lowercase, a GLEIF id of 19 characters). `BadRules` (`0x01` and `0x08` on a Companies House order, `0x02` on a GLEIF order). `BadOrder` (wrong value, empty list, a zero amount, length mismatch, decreasing due dates, `permitTtl` of 0). `BadSource`.
   - **Companies House:** a clean record issues a permit valid for exactly `permitTtl`. `0x02` and `0x04` fail alone. Status `liquidation` gives `0x80` plus whatever else is enabled. A disabled rule is ignored.
   - **GLEIF:** clean; `LAPSED` with `0x08` is held; `INACTIVE` gives `0x80`.
   - **Tamper:** an edited value (`WrongSigner`), stale, future, another request (`WrongRequest`), a wrong key (`WrongSigner`), replay (`Replayed`), not newer (`NotNewer`), a high-s signature (`InvalidSignatureS`). A Companies House response on a GLEIF order gives `WrongRequest`. A held order rejects new evidence (`NotActive`).
   - **Permits:** `PermitExpired`; the permit is used up after `release`; the next milestone gives `NoValidPermit`; the tier never changes how long a permit lives.
   - **Payment:** `NotDue` before the due date; paid after it; `NotApproved`; `checkAndRelease` returns 0, 1, 2 and 3 in the right cases.
   - **Verification history:**
     - the streak counts only base-clean records, only after `tierCountGap`;
     - an older record does not change the history (`lastCheckAt` never decreases);
     - rule-only failures don't reset the streak;
     - a base failure resets it and sets `lastBaseFailureAt`;
     - the thresholds 3 and 6 emit `TierChanged`;
     - two orders of the same supplier share one record.
   - **Supplier-wide stop:**
     - order A has a permit, order B gets `liquidation`: A's `release` reverts `SupplierFailed`;
     - `applySupplierFailure(A)` holds A;
     - a second `applySupplierFailure` gives `NotActive`;
     - on an order whose last check is newer than the failure, `NoNewerFailure`;
     - a clean record older than the failure gives `SupplierFailed`;
     - a rule-only failure on B does not stop A.
   - **Refund:**
     - Held: the buyer at once; a stranger before the grace period gets `RefundNotYet`, after it the refund reaches the buyer.
     - No-data exit: approved, no permit, overdue by the grace period, so anyone can refund to the buyer with `noDataExit = true`. It gives `NotApproved` when the milestone is not approved, `NotRefundable` with a valid permit, `RefundNotYet` before due date + grace, and `NotRefundable` on a closed order.
   - **Events:** every event fires with the exact arguments.
4. **Deploy script.** `DeploySupplierPulsePlus.s.sol` reads env `EVM_PRIVATE_KEY`, `CH_AIRNODE` (default the real one), `GLEIF_AIRNODE` (default the real one), `MAX_AGE=300`, `TIER_COUNT_GAP=300` and `REFUND_GRACE=600`.
5. **Scripts.**
   - `plus-lib.sh`: a send helper with the Foundry JSON unwrap (copy `pulse_send`), and error-name decoding for every error in §4.6 (extend `pulse_error`).
   - `plus-local.sh` (§4.8). Create the orders with inline `cast`, so it does not depend on Emre's tools.
   - The buyer scripts from §4.7. Amounts are given in tokens; convert with 1 token = 10¹² wei.
   - `plus-demo-orders.sh`: orders A to E from §2.5. It reads the supplier ids from env `DEMO_CH_A`, `DEMO_CH_B`, `DEMO_CH_C`, `DEMO_LEI_D` and `DEMO_LEI_E`, and the supplier wallets from `DEMO_SUPPLIER_1` and `DEMO_SUPPLIER_2`.
   - Use `EVM_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com` when Tenderly answers `-32603`.

**Phase B**
- **C1a:** add tests with Emre's real Companies House and GLEIF fixtures (`vm.warp(timestamp + 10)`, like v1's real-response test).
- **C2:** support the integration session (§7.1).
- **C3:** the Sepolia launch (§7.2): deploy with `--slow --gas-estimate-multiplier 800` as for v1, record the address in §3.2, `docs/evidence.md` and `api3/.env.example`, then create the demo orders and approvals.

**Acceptance:**
- `forge test` is green, including v1's 36 tests.
- `plus-local.sh` works from a clean clone.
- The Sepolia contract is deployed and reads correctly with `plus-status.sh`.
- v1's files are unchanged.

**Pitfalls:**
- **Stack too deep:** keep the views split as in §4.4.
- **Reentrancy:** change state before transferring.
- **Event signatures** must match §4.4 exactly, because the dashboard and agent decode them.
- **Templates:** no stray spaces in the template strings.

### 6.2 Emre: data layer and judge CLI

**Goal.** Fresh signed records for both registries, paid over x402, with request hashing identical to the contract. Plus local signing so everyone can work for free, verify and tamper tools, the judge CLI, and the real demo suppliers.

**You own:**
- `api3/x402/{requests,airnode-fetch,verify,tamper,sign-local,test-requests}.mjs`
- `api3/x402/local-registry.json`
- `api3/scripts/{fetch-evidence,fetch-local,plus-submit}.sh`
- `api3/fixtures/**`, `docs/data-sources.md`

**You depend on:**
- §4 only.
- Until Orhun's contract exists, test `plus-submit.sh` against v1 on `api3/scripts/pulse-local-demo.sh`. v1 has the same `submitEvidence` ABI, and `tamper.mjs` is pure data.

**Phase A**

1. **(16:45 → 17:30) `requests.mjs`.**
   - The `SOURCES` config: `ch` = 0 and `gleif` = 1, each with URL, signer, operation, parameter name and projection.
   - `buildRequest(source, id)` returns the HTTP body.
   - `requestHash(source, id)` canonicalises like the starter's `deriveRequestHash`.
   - `supplierKey(source, id)` via `solidityPackedKeccak256(["uint8","string"], …)`.
   - `node api3/x402/test-requests.mjs` asserts all §4.2 vectors.
2. **(→ 18:30, C1a) Live verification.** Get approval from the team for about $0.10 first, then:
   - Make one paid Companies House v2 call each for `09729896`, `07418033` and `12493325`, and one GLEIF call for a real LEI. Find the LEI with the free `searchLegalEntities`, for example `filter[entity.registeredAs]` with a German HRB number and `filter[entity.jurisdiction]=DE`.
   - Check that the Airnode's `requestHash` equals `requestHash()`, and that every projected field is present.
   - Save the responses as fixtures named `api3/fixtures/<source>-<id>-<YYYYMMDDHHMM>.json`.
   - If anything differs, update §4.2, §4.3 and the vectors, then follow §4.9. If a field is missing, apply the fallback in §4.2.
   - **Keep two genuine tamper inputs** (§4.7):
     - one real response for `09729896` that you leave until it is older than `maxAge` (a genuinely stale record);
     - one real fresh response for another company (`12493325`) to submit against order A (a genuinely different request).
3. **(→ 18:30) For everyone:** `sign-local.mjs`, `local-registry.json` (§4.8) and `fetch-local.sh`, all producing the §4.1 format.
4. **`airnode-fetch.mjs` and `fetch-evidence.sh`.**
   - Generalise `ch-fetch.mjs` to both sources.
   - Keep the spend controls (at most $0.05 per payment, aUSD only).
   - Verify the request hash and signer before printing, and use the exit codes from §4.7.
   - Record `priceUsd` and `paymentTx`. Note in `docs/data-sources.md` whether a payment settles even when the Airnode answers 4xx.
5. **`verify.mjs` and `tamper.mjs`**, with the semantics of §4.7.
6. **`plus-submit.sh`.**
   - Simulate `submitEvidence` with `cast call --from <any address>`.
   - If the simulation succeeds, decode the returned `bool clean`. Print `ACCEPTED clean`, or `ACCEPTED held: <labels>`. To get the labels, evaluate `raw` against the order's `rules` (from `orderInfo`) with the §4.3 table; that is the same logic the contract runs.
   - If it reverts, print `REJECTED <ErrorName>(args)`.
   - Decode errors by selector for every error in §4.6.
   - `--send` sends the transaction with `EVM_PRIVATE_KEY`. Use it for the video: real reverted transactions show as a red "Fail" on Etherscan.
7. **(→ 21:00) Demo suppliers.** Find real entities for orders A to E (§2.5) and document them in `docs/data-sources.md`, with links to the register pages and the expected flags:
   - Companies House active and clean (check `09729896`).
   - Companies House in liquidation (`07418033`).
   - Companies House **active but with accounts overdue**. Hint: a company incorporated about 2 to 3 years ago that never filed. Use `advancedSearchCompanies` at $0.01 to list candidates, then profile a few. If you can't find one, use an active company with an overdue confirmation statement instead.
   - A German LEI that is `ACTIVE`/`ISSUED`, and an LEI with registration `LAPSED`. The free search returns full records with `registration.status`, so filter them there. Only the final `getLegalEntity` is paid.

**Phase B**
- **C2:** check that `plus-submit.sh` against `plus-local.sh` gives:
  - order 0 with a fresh `fetch-local` record: `ACCEPTED clean`;
  - order 1: `ACCEPTED held: registry status not active, accounts overdue`;
  - all five tamper modes rejected with the expected errors.
- **C3:** real fetches for the demo suppliers right before their due dates. Then the judge CLI against Sepolia v2. Add the tx links to evidence.

**Acceptance:**
- `test-requests.mjs` passes.
- A live fetch works for both sources.
- `verify.mjs` passes on the real fixtures.
- The tamper results match §4.7 on the local test chain and on Sepolia.
- `docs/data-sources.md` lists the verified pointers, the possible status values, the demo suppliers and the cost per call.

**Pitfalls:**
- **Pinned versions:** keep `@x402/*` at 2.28.0 and `viem` at 2.57.3.
- **Canonical form:** no whitespace, sorted keys.
- **Submit `data` exactly as signed**, never a re-serialised `raw`.
- **Registry formats:**
  - Companies House answers 502 for a number it doesn't know.
  - GLEIF statuses are uppercase.
  - Companies House numbers keep their leading zeros.

### 6.3 Julien: autonomous agent

**Goal.** An agent that runs the whole workflow without a person starting each cycle. It decides which supplier to check and when, pays for the data over x402, acts on-chain, enforces spending limits and handles failures. It earns the **+10 bonus**, and `docs/agent.md` explains the schedule, the spending limits and the failure handling, as the bonus requires.

**You own:** `api3/agent/**` and `docs/agent.md`.

**You depend on:**
- §4.6 (cast signatures) and §4.7 (the output of `FETCH_CMD`) only.
- Until C1/C2, use `FakeChain` and `FakeFetcher` in-memory implementations behind the same adapter interfaces.

**Stack:** Python 3.8+ (the default `python3` on Julien's laptop is 3.8.20), standard library only. Chain I/O goes through `cast` subprocesses (Foundry is installed); evidence comes from `FETCH_CMD`.

**Status (Fri ~16:35): Phase A done** on `julien/plus-agent`. 48 tests pass. `pulse_agent.py run --fake` runs the whole flow against an in-memory contract. The chain adapter was also checked live against v1 on a local anvil, which has the same write ABI: simulate and send, receipt parsing, RPC failover, and decoding of `Replayed`, `StaleResponse`, `WrongRequest`, `WrongSigner` and `NoValidPermit`. Details in `docs/agent.md`. **v1.1 done (~17:00):** supplier-wide stop (priority 0), no-data exit refunds, verification history, and the v1 hedge mode (`AGENT_CONTRACT_VERSION=v1`, `api3/agent/fetch-v1.sh`). 54 tests pass. **C2 passed (~17:20)** against Orhun's v1.1 contract on a local chain (`api3/agent/c2_check.py`, 8/8). **C2.5 review fixes (~17:45):** the check window respects `permitTtl`, no monitoring while a due milestone waits for the buyer, quarantine blocks every action, and one last try before the no-data refund. 61 tests pass.

**Modules (`api3/agent/`):**

| File | Purpose |
|---|---|
| `config.py` | Env parsing with `AGENT_PROFILE=demo\|prod` presets (table below). Optionally loads `api3/agent/.env` |
| `chain.py` | `Chain` adapter: `now()` (latest block timestamp), `snapshot()` (all orders and supplier records), `simulate(sig, args)`, `send(sig, args)`, and error-name extraction from cast output |
| `evidence.py` | `Fetcher` adapter: runs `FETCH_CMD <ch\|gleif> <id>`, parses the §4.1 JSON, and maps exit codes to `NoData`, `PaymentFailed` and `VerificationFailed` |
| `policy.py` | **A pure function** `plan(snapshot, now, ledger, config) -> list[Action]`. All decisions live here and are unit-tested |
| `ledger.py` | Persistent state in `api3/agent/state/state.json`: spend per UTC day, attempts and backoff per order, quarantined orders |
| `executor.py` | One tick: snapshot, plan, simulate then send, and the failure handling |
| `journal.py` | The JSONL cycle log and `report` |
| `model.py` | Shared data types, the §4.3 rule evaluation and labels |
| `fakes.py` | An in-memory contract with the §4.5 semantics, a fake fetcher and the local registry of §4.8 (`--fake`) |
| `pulse_agent.py` | CLI: `run` (loop), `once` (one tick), `plan` (prints the planned actions without acting), `report` (summary of the log). `--fake` runs against `fakes.py` |
| `tests/` | `unittest` tests for policy, ledger, cast output parsing (recorded from real calls), the fetcher's exit codes, and the executor with a full simulated run |

**Config:**

| Variable | Demo | Production |
|---|---|---|
| `PULSE_PLUS_ADDRESS`, `EVM_RPC_URLS` (comma-separated, tried in order; `EVM_RPC_URL` also works), `AGENT_PRIVATE_KEY`, `PAYER_PRIVATE_KEY` (used by the fetch script) | required | required |
| `FETCH_CMD` | `api3/scripts/fetch-evidence.sh` (`fetch-local.sh` on the local chain) | same |
| `TICK_SECONDS` | 30 | 300 |
| `DUE_LEAD_SECONDS` | 300 | 86400 |
| `MONITOR_SECONDS_STANDARD` / `_TRUSTED` / `_PREMIUM` | 600 / 1800 / 3600 | 86400 / 259200 / 604800 |
| `DAILY_BUDGET_USD` | 1.00 | 5.00 |
| `DUE_RESERVE_USD` | 0.20 | 1.00 |
| `MAX_FETCHES_PER_TICK` | 3 | 10 |
| `MAX_FETCH_ATTEMPTS` | 3 | 5 |
| `MAX_GAS_PRICE_GWEI` | 50 | 50 |

**Plan, once per tick.** `now` is the chain time. Actions are listed by priority:

```text
            a quarantined order gets no action at all (no fetch, release, refund or stop)
P0 stop     state=Active and supplier.lastBaseFailureAt > order.lastCheck   → applySupplierFailure(order)   (no fetch)
P1 refund   autoRefundAt set and now ≥ autoRefundAt and remaining > 0, and either state=Held (a hold after
            its grace period) or the agent's own try at or after nextDueDate failed (the no-data exit;
            until then P3 tries once more, ignoring the backoff)  → refundRemaining(order)  (no fetch)
P2 release  state=Active and permitValid and nextApproved and now ≥ nextDueDate → release(order)          (no fetch)
P3 due      state=Active and now ≥ nextDueDate − min(DUE_LEAD, permitTtl − 60 s)  # its permit covers the due date
            and not (permitValid and permitValidUntil ≥ max(now, nextDueDate))
            and (nextApproved or now < nextDueDate)        # don't pay for checks while waiting for the buyer
            and backoff elapsed (or P1's last try)       → fetch(source, id) →
                                                          now ≥ nextDueDate ? checkAndRelease : submitEvidence
P4 monitor  per supplierKey with ≥ 1 Active order not waiting for the buyer, and no P3 fetch this tick:
            now − lastCheckAt ≥ interval(tier)            → fetch once → submitEvidence to that supplier's
                                                          Active order with the nearest nextDueDate
Budget      P3 only if spentToday + cost ≤ DAILY_BUDGET_USD
            P4 only if spentToday + cost ≤ DAILY_BUDGET_USD − DUE_RESERVE_USD
Cap         at most MAX_FETCHES_PER_TICK fetches per tick; skip writes if gas price > MAX_GAS_PRICE_GWEI
```

Every write is **simulated first** (`cast call`) and sent only if the simulation succeeds.

**Failure handling.** Explain this exact table in `docs/agent.md`.

| Event | Reaction |
|---|---|
| Fetch exit 3 (no data) | Backoff 30 s, then 2 min, then 8 min. After `MAX_FETCH_ATTEMPTS`: an `alert` entry, wait for the next scheduled window |
| Fetch exit 4 (payment failed, e.g. no aUSD) | Pause all paid fetches for 15 min, `alert` |
| Fetch exit 5 (verification failed) | `alert`, do not submit, retry at the next interval |
| Revert `StaleResponse` / `FutureResponse` | Fetch again next tick (counts as an attempt) |
| Revert `Replayed` / `NotNewer` | Drop the record, no retry |
| Revert `WrongRequest` / `WrongSigner` | `alert` and **quarantine the order** (stop acting on it). This means a config mismatch or tampering |
| Revert `NotActive` | Refresh the snapshot. The order was held or closed |
| Outcome `NotDue` / `AwaitingApproval` | Expected, logged as such |
| RPC or network error | Retry next tick |
| Crash | The process is restarted by its runner (overnight: `while true; do python3 api3/agent/pulse_agent.py run; sleep 5; done`). State comes back from `state.json` |

**Log.** JSONL in `api3/agent/state/cycles.jsonl`, one line per action:

```json
{"ts":"2026-10-31T01:15:02Z","cycle":42,"action":"checkAndRelease","reason":"due","orderId":0,"supplier":"ch:09729896","tier":1,"costUsd":0.01,"spentTodayUsd":0.17,"paymentTx":"0x…","tx":"0x…","outcome":"Paid","error":null}
```

`report` prints the cycles run, the actions by type, the spend per day, tier changes, held and refunded orders, and the first and last cycle time. These numbers go into the README and the video.

**Phase A (until C1)**
- `policy.py` and its tests, with no I/O.
- The adapters, with parsing tested against recorded cast output strings.
- Fakes for an end-to-end `once` run.

Required policy tests:
- a due check before the due date;
- a release once due with a valid permit;
- a refund after the grace period;
- the monitor interval per tier;
- the budget blocks monitoring but keeps due checks;
- backoff after "no data";
- quarantine on `WrongRequest`;
- no paid checks while a past-due milestone waits for approval;
- one fetch per supplier per tick;
- the daily budget resets at 00:00 UTC.

**Phase B**
- **Tonight, the hedge for the bonus:** a v1 mode runs the same loop against the **live v1 contract** (`0x91d7…74d7`, §1.3). It fetches the status only (v1's request, through `api3/scripts/supplier-fetch.sh`) and runs monitoring checks on v1 orders. It makes no refunds, because v1 refunds are buyer-only. The autonomous-cycle evidence then builds up even if v2 is late.
- **C2:** run against `plus-local.sh` with `FETCH_CMD=api3/scripts/fetch-local.sh` (§7.1).
- **C3:** run on Sepolia with the agent wallet (check its aUSD first) and the demo profile. Supervise the first cycles live.
- **Morning:** run `report` and write `docs/agent.md`: purpose, the loop, the schedule (both profiles), the spending limits, the failure handling table, real excerpts from the overnight log, and tx links.

**Acceptance:**
- All unit tests pass.
- The local run reaches the expected states (§7.1).
- On Sepolia the agent pays A M1, holds B, C and E, refunds B after the grace period, raises A's tier, and logs at least 10 autonomous cycles overnight.
- `docs/agent.md` exists.

### 6.4 Batu: dashboard and "Try to break it" page

**Goal.** Make the protection visible to a buyer, and let judges attack the contract themselves. No build step: static HTML plus ethers 6.13.5 from the CDN, as in v1.

**You own:** `demo/**`. Merge `batu/demo-screen` into your branch first. Keep v1 as `demo/v1.html` if you like.

**You depend on:**
- §4.6 (the ethers ABI) only.
- Until the v2 contract exists, build against **sample mode** (`demo/sample/*.json`, snapshots in the shape of the view functions) and against v1 for the shared parts.

**`demo/index.html`: dashboard v2**
- **Config** comes from URL parameters and a settings panel:
  - `contract`, `rpc` (default publicnode Sepolia), `orders` (default: all), `agent` (address to highlight), `from` (block), `unit` (default 1e12 wei = 1 token), `sample=1`.
- **One card per order:**
  - **Title:** `orderRef` decoded, plus the registry badge (`CH` / `GLEIF`), the supplier id linked to its register page:
    - Companies House: `https://find-and-update.company-information.service.gov.uk/company/<number>`
    - GLEIF: `https://search.gleif.org/#/record/<LEI>`
  - The **rules** as chips (§4.3 labels).
  - **Protected remaining balance** as the hero number, with paid / remaining.
  - The **milestone timeline:** amount, due date, and state (paid ✓, permit valid until …, awaiting approval, not due yet, held 🔒).
  - The permit countdown.
  - The **verification history** badge (Standard / Trusted / Premium) with the streak (`supplierRecord`). Label it as a history of register checks, not a credit score.
  - **Supplier-wide stop:** if `lastBaseFailureAt` is set, show a red banner: "register status failed on <date>: payments to this supplier are stopped on every order".
  - **No-data exit:** when `autoRefundAt` is set on an active order, show "no verified data since the due date: the money can go back to the buyer from <time>".
  - **Last check:** time ago, "clean ✓" or the failed-rule chips in plain words.
  - **When held:**
    - a red banner with the failed rules;
    - a countdown to `autoRefundAt`;
    - "Claim now". With MetaMask the buyer can send `refundRemaining`; otherwise show the command `api3/scripts/plus-refund.sh <id>`.
  - The **audit trail:** all events of the order, newest first, with Etherscan links. For `EvidenceAccepted`, show the decoded signed JSON from `data`, the signed time, the digest and the submitter, highlighted when it's the agent.
- **An agent activity panel:** the latest `EvidenceAccepted` / `MilestonePaid` / `OrderRefunded` transactions sent by the agent address. This is the visual proof of autonomous cycles.
- **Auto-refresh** every 12 s. Works on a projector and a phone, in light and dark mode.

**`demo/judge.html`: "Try to break it"**
- **Inputs:**
  - the order (a dropdown over `ordersLength`);
  - a response in the §4.1 format: paste it, upload a file, or "load sample". Samples come from `api3/fixtures/`; they are stale, so judges see `StaleResponse`.
- **Buttons:** "Submit as is", "(a) Edit value", "(b) Too old", "(c) Different request", "(d) Wrong key", "Replay".
  - The tampered response is built **in the browser** with exactly the §4.7 semantics.
  - For the wrong key, use `ethers.Wallet.createRandom().signMessage(getBytes(digest))`.
  - For (b) and (c), **use the real inputs when available** (§4.7): the genuinely old response and another company's real response from `api3/fixtures/`. The mutation buttons stay as extras.
- **Off-chain diagnostics**, shown as a checklist:
  - `digest = keccak256(solidityPacked(["bytes32","uint256","bytes"], [requestHash, timestamp, data]))`
  - the recovered signer against `airnodeOf(order source)`
  - `requestHash` against `orderInfo.requestHash`
  - the age against `maxAge`
  - `usedDigests(digest)`
- **The contract's verdict** comes from an `eth_call` simulation of `submitEvidence`, sent from `0x000000000000000000000000000000000000dEaD`. No wallet, no gas.
  - Success: decode `clean`. Show "✅ ACCEPTED: would issue a payment permit", or "✅ ACCEPTED: would hold the order (accounts overdue …)".
  - Revert: `iface.parseError(data)`, then "❌ REJECTED: WrongSigner(0x…)" with one plain sentence on why.
- Optional "Send for real (MetaMask)".
- **A short "Judge kit" box:**
  - how to get your own fresh response: `api3/scripts/fetch-evidence.sh ch <number>`, or AirnodeHub `call-operation` with x402;
  - the request for each source from §4.2;
  - the contract address and network.

**Optional (cut first):** a 3D motor part via `<model-viewer>`. Orhun may provide a GLB from SolidWorks by 08:00. Green parts for paid milestones, a red lock when held, and the caption "Illustration: the register check does not verify production."

**Phase B**
- **C2:** both pages against the local test chain. Judge verdicts must match Emre's `plus-submit.sh`.
- **C3:** point both pages at Sepolia v2. Optionally publish them through GitHub Pages; Julien enables it in the repo settings.

**Acceptance:**
- Every state renders: paid, permit, awaiting approval, not due, held with labels, refunded, and all three tiers.
- The judge page shows the right verdict for the valid case and all five tamper cases against the live contract.
- Sample mode works offline.
- No console errors.

### 6.5 Ulaş: story, research, README, Devfolio, video, pitch, QA

**Goal.** Judges understand the problem in 10 seconds, can run everything from the README, and the video ticks every API3 requirement within 2:30.

**You own:** `README.md` (root), `docs/research.md`, `docs/pitch.md`, `docs/drafts/**`. Merge `docs/drafts/` from `batu/api3-setup` first.

**You depend on:** nothing until C3. After that, real addresses and tx links come from `docs/evidence.md`.

**Phase A (→ 19:00, then refine)**

1. **`docs/research.md`:** sourced facts only, each with a link and an access date.
   - UK company insolvencies per year (Insolvency Service statistics) and the share that are liquidations.
   - One well-known supplier collapse and its cost to the companies that kept paying it. Carillion (2018) is the classic case; verify the numbers.
   - The share of LEIs that are lapsed (GLEIF statistics).
   - **One real timeline:** a UK company that went into liquidation in 2025/26 (from Companies House filing history, free on the website). The line is "On <date> its status changed. SupplierPulse+ would have held the next payment that day." State facts only, with no judgement about the company.
   - **Prior art:** a short search for registry- or KYB-gated escrow and "continuous supplier monitoring" products, on chain and off. List what exists in one table. This sets the limits of our claims (§2.6): we never say "first".
2. **Root `README.md`, written for judges:**
   - what it is (§2.6 wording);
   - live contracts (v2 and v1) and the network;
   - **how to try it in 2 minutes:** the dashboard link, the judge page, `plus-submit.sh` with the tamper modes;
   - how it works (the diagram from §3.1);
   - the agent (link `docs/agent.md`);
   - setup (Node 24, Foundry, Python 3.11, env vars from the `*.env.example` files);
   - **demo limits:**
     - demo constants (5-minute tier gap, 10-minute refund grace);
     - 1 token = 10¹² wei;
     - only UK and LEI-registered suppliers;
     - a signature proves the register said it, not that it is true;
   - a repo map, including "`cardano-agent/`: earlier experiment, not part of this submission".
3. **Devfolio text** (update `docs/drafts/devfolio.md` for API3 only). Sections:
   - Problem, What we built, How it works
   - **Who relies on the data**, **What goes wrong if it is forged**, **What data we wanted but could not find** (§2.1)
   - the contract address and network, how judges submit their own responses, the agent bonus (schedule, spending limits, failure handling, with a short log excerpt), honest limits, links.
4. **Video storyboard and script** (`docs/drafts/video-script.md`, 2:30).

   **Start from the hero frame.** Agree with Batu at C1 on the single strongest moment and build the video backwards from it. Our proposal: a judge clicks "(a) Edit value" on a real signed liquidation record and the contract refuses; then the agent holds the real payment and the protected balance appears.

   **Everything in the video is real:** Sepolia transactions and real signed register data. Local-chain data never appears, apart from clearly labelled tamper attempts.

| Time | Screen | Must show |
|---|---|---|
| 0:00 – 0:15 | Title, then the problem | the tagline; one sourced statistic |
| 0:15 – 0:35 | Diagram, rules and tiers | two registries, signed fields, permits that expire |
| 0:35 – 1:05 | Dashboard, live | A: the agent's due check, then the permit, then **M2 paid** (11:45). C held: "accounts overdue". B2 held, with the refund countdown |
| 1:05 – 1:45 | Judge page | **First a valid, fresh response triggers the action**, then the rejections: (a) edited value, (b) too old, (c) different request, (d) wrong key (+ replay) |
| 1:45 – 2:10 | Agent | the overnight log, the budget, the failure handling, x402 payments on Basescan |
| 2:10 – 2:30 | Why it matters, limits, end card | data we wanted; the repo URL |

   Record segment by segment between 11:00 and 13:00, check the length with a timer, and upload unlisted.
5. **`docs/pitch.md`:** a 90-second talk for the API3 booth, plus answers to the likely questions:
   - Why not call Companies House directly? Because an unsigned answer can be edited by whoever runs the script.
   - Cherry-picking? `maxAge` of 300 s, "newer only", the permit counted from the evidence time, scheduled checks.
   - Tier gaming? Only verified records count, one per gap, and any failure resets the streak.
   - A field is missing? Then there is no data, and no payment without evidence.
   - Cost? $0.01 plus gas per check, and the tiers cut the number of checks.
   - Privacy? Public register data only.
   - Why two chains? The contract is on Ethereum Sepolia, and API3 takes data payments in aUSD on Base Sepolia.
   - What's missing? The German register and insolvency notices.
6. **Logistics:** create the Devfolio submission on **Sat 09:00**, add all five teammates, select only the API3 track, and keep editing it until 14:30.
7. **Repo hygiene judges will notice** (from the office-hours review):
   - the empty "API3" table at the top of `docs/evidence.md`: fill it with the v1 and v2 addresses, or remove it;
   - v1's demo supplier wallet `0x3C44…93BC` is anvil's public test address: say so next to the evidence, since v2 uses team addresses;
   - one README sentence on `cardano-agent/`.
8. **A persona for the opening** (office-hours suggestion): *a 12-person robot maker in Munich pays a UK motor supplier €30k in three instalments. Two weeks before instalment 2, the supplier enters liquidation.*

**Phase B**
- **C4 (08:00):** QA as a judge. Make a fresh clone and follow only the README. Post the bug list in PROGRESS, with an owner per bug.
- **C6:** the video.
- **C7:** final checks against §8.

---

## 7. Integration and launch

**Fallback at every step (office-hours review).** v1 (live), the agent's v1 mode and the judge page against v1 already make a complete API3 submission. v2 adds to it. If v2 slips, we submit that.

### 7.1 C2: local integration (22:00, run by Julien, everyone joins)

1. **Orhun:** `api3/scripts/plus-local.sh`, then everyone runs `source api3/.local/plus-local.env`.
2. **Emre:** for order 0, run `api3/scripts/fetch-local.sh ch 01234567 /tmp/r.json`, then `api3/scripts/plus-submit.sh 0 /tmp/r.json`, which gives `ACCEPTED clean`. Then run the five tamper modes; all are rejected with the expected errors (§4.7).
3. **Julien:** `python3 api3/agent/pulse_agent.py run` (`FETCH_CMD` comes from the env file). Within about 3 minutes:
   - order 0, M1 paid;
   - order 1 held, then **refunded by the agent** after 120 s;
   - order 2 paid;
   - order 3 held (LEI renewal overdue);
   - order 4 (same supplier as order 1) held by `applySupplierFailure`, **without a fetch**;
   - order 5 (no data) refunded through the no-data exit 120 s after its due date, once the agent's last try failed;
   - order 0's supplier climbs tiers as monitoring checks pass the 60 s gap.
4. **Batu:** the dashboard on `rpc=http://127.0.0.1:8545` shows all of this live, and the judge page verdicts equal step 2.
5. **Ulaş:** follows the README draft against what actually happens, and notes demo moments.

**Exit:** everything passes. Owners fix their issues by 23:30.

### 7.1b C2.5: cross-review (22:30 → 23:30)

A cold read by someone who didn't write the code, before anything goes to Sepolia. Judges are engineers, and execution is 20%.

- **Emre** (or his agent) reviews `SupplierPulsePlus.sol` and its tests against §4.5: the check order, replay and "newer", the signer per source, tier gaming, the refund path, reentrancy, and event arguments.
- **Orhun** reviews `tamper.mjs`, `verify.mjs` and `plus-submit.sh` against §4.7.
- **Batu** reviews the decisions in the agent's `policy.py` against §6.3.
- **Julien** reviews the judge page's tamper code against §4.7.

Findings go to the owner as a PROGRESS entry. Blocking findings are fixed before C3.

### 7.2 C3: Sepolia launch (00:00)

1. **Orhun** deploys v2 with the demo constants and records the address in §3.2, `docs/evidence.md` and `api3/.env.example`.
2. **Emre** confirms the demo supplier ids, re-verified with the v1.1 fields, and exports `DEMO_CH_A=03778796`, `DEMO_CH_B=07418033`, `DEMO_CH_C=09729896`, `DEMO_LEI_D=391200JI69LS8L648F30`, `DEMO_LEI_E=52990092KBQJF8QBGJ50`.
3. **Orhun** runs `plus-demo-orders.sh` (orders A to E plus the approvals in §2.5). The supplier wallets are fresh team addresses.
4. **Batu** sends at least 2 aUSD on Base Sepolia to the agent wallet, and **Julien** checks the balances.
5. **Julien** starts the agent in the supervised loop with `AGENT_PROFILE=demo` and watches the first cycles: A M1 and D M1 paid; B, C and E held.
6. **Batu** points both pages at Sepolia (and GitHub Pages, if used).
7. **Everyone** adds their tx links to the evidence section.

### 7.3 Overnight

- The agent runs, and Julien keeps watching.
- Others polish their own parts. No breaking changes (§4.9).

### 7.4 Saturday

| Time | What |
|---|---|
| 08:00 | C4 QA (Ulaş) and the bug list |
| 09:00 | Ulaş creates the Devfolio submission, adds the team and selects API3 |
| 09:30 – 10:30 | **Dry run** of the whole video flow on Sepolia with separate orders. Save every step's tx as a pre-run proof, in case a live moment fails during recording |
| 11:00 | **Feature freeze** |
| 11:00 – 13:00 | Video (A M2 is due at 11:45, D M2 at 12:00; B2 is created live; the tamper cases are sent as real transactions) |
| 13:00 | Julien merges `supplierpulse-plus` into `main`. The repo is public (it already is) |
| 14:30 | Submit |
| 15:00 – 17:00 | API3 booth: everyone present; who speaks is decided at 08:00 |

---

## 8. Submission checklist (API3)

| Requirement | Artefact | Owner |
|---|---|---|
| The AirnodeHub data is essential | README and Devfolio "How it works" | Ulaş |
| A deployed contract verifies signer, request and timing | v2 address on Sepolia; §4.5 | Orhun |
| A signed value drives an on-chain action, with duplicate protection | milestone payments and holds; `usedDigests`; `NotNewer` | Orhun |
| Tamper test: valid, then (a)–(d) rejected | judge page and `plus-submit.sh`; in the video as real reverted transactions, with a genuinely old response and another company's real response | Batu, Emre, Ulaş |
| Contract address and network | README, Devfolio | Ulaş |
| A way for judges to submit their own responses | `demo/judge.html` and `plus-submit.sh`, documented | Batu, Emre |
| Who relies on the data, what goes wrong if forged, data we couldn't find | Devfolio (§2.1) | Ulaş |
| Agent bonus: repeated cycles, schedule, spending limits, failure handling | `docs/agent.md`, overnight log, video 1:45 | Julien |
| Video ≤ 2:30 | uploaded link | Ulaş |
| Public repo, README with setup and demo limits, `main` up to date | GitHub | Ulaş, Julien |

---

## 9. Risks, fallbacks, cut list

| Risk | Fallback |
|---|---|
| A GLEIF pointer is wrong, or a field is missing (C1a) | Fix §4.2 (two constants). If GLEIF fails completely, drop GLEIF and keep Companies House with all its rules |
| A Companies House field is missing or deprecated (HTTP 400; the official schema deprecates `accounts.overdue` and `has_insolvency_history`, and its nested fields are optional) | v1.1 uses the current pointers. At C1a apply the fallback in §4.2: a demo company that has the field, then drop the field and its rule, down to status only, which is v1's verified request. Never treat missing data as a negative fact |
| AirnodeHub or x402 is down during the demo | Recorded video; the judge page still works with fixtures (stale cases); the v1 and v2 evidence links |
| Sepolia RPC or gas trouble | `--slow --gas-estimate-multiplier 800`, and a second RPC. Tenderly's public gateway refuses bursts with `-32603`; scripts then switch `EVM_RPC_URL` to publicnode, and the agent fails over automatically (`EVM_RPC_URLS`) |
| The agent crashes overnight | Supervised loop; state in `state.json`; Julien watches |
| A needed interface change | §4.9; additive only after C2 |
| Running out of time | Cut list below |

**Cut list**, cut from the top first:
1. the 3D model
2. MetaMask buttons
3. GitHub Pages
4. order E (lapsed LEI)
5. GLEIF entirely
6. tier visuals on the dashboard
7. monitoring checks (keep due checks)

**Never cut:**
- the contract rules, due dates, verification history, supplier-wide stop and no-data exit
- the Companies House multi-field fetch, or its status-only fallback
- the agent loop with budget and failure handling, including the v1 hedge run
- the judge page simulation
- the tamper test in the video, as real reverted transactions
- the README, Devfolio and video

---

## 10. References

- **Track rules:** <https://hackathon.tum-blockchain.com/prizes#api3>. **Submission:** <https://hackathon.tum-blockchain.com/prizes#how-to-submit>
- **API3 challenge and scoring:** <https://api3dao.github.io/airnodehub-hackathon/>. **Projections:** <https://api3dao.github.io/airnodehub-hackathon/docs/projections>
- **AirnodeHub catalogue:** <https://airnodehub.api3.org/llms-full.txt>. **MCP:** `https://airnodehub.api3.org/mcp`. **aUSD faucet:** <https://api3dao.github.io/airnodehub-hackathon/faucet/>
- **Starter (request hash, signature checks):** <https://github.com/api3dao/airnodehub-hackathon-starter>, file `src/airnode-v2.ts`
- **v1 files:** `docs/SUPPLIERPULSE.md` (v1 plan), `docs/SUPPLIER_PULSE_SPEC.md` (Orhun's ideas), `api3/README.md`, `docs/evidence.md` ("SupplierPulse live run")
- **Batu's analysis:** `docs/decision-sheet.md` and `docs/supplierpulse-upgrades.md` on `batu/api3-setup`
- **Security rules:** CLAUDE.md §7
