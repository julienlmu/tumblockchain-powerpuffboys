# SupplierPulse: pitch handbook

*For whoever presents at the API3 booth (Sat 31 Oct 2026, 15:00–17:00). Written 11:00 on Saturday. Read it once fully. Before the pitch, re-read §1 (checklist), §3 (script) and §5 (demo plans).*

Items marked **†** came with Orhun's merge at 11:04 (lab editor, `judge-tamper.sh`, `plus-quick-orders.sh`). They are on `main`; pull before the pitch.

---

## 0. The whole project in 30 seconds

> "Companies check a supplier once, when they sign it up, and then keep paying it for months. If the supplier goes bust in between, the next payment is lost. **SupplierPulse** locks the order money in a smart contract and pays each instalment only after a fresh check of the official company register. That check comes as a record **signed by API3**, so nobody can fake it. Our agent buys that record for one cent and hands it to the contract. A healthy supplier gets paid; a supplier in liquidation gets nothing more, and the rest goes back to the buyer."

Tagline: **"Your supplier was approved last month. That should not approve today's payment."**

---

## Judging format (official site, checked Sat 11:35)

- **Live, Sat 15:00–17:00, at the partner booths.** "Each partner judges its own track for two hours. Present your project to the judges of every track you entered. TUM Blockchain Club judges every project for the TUM Blockchain Track." The 15:00 submission deadline comes first; winners are announced at 17:30.
- **No fixed pitch length is published.** Expect a conversation at the booth. Have three lengths ready (1 min, 3 min with demo, about 8 min with questions) and ask the judges at the start how long they have.
- **Two juries:** the API3 judges (Matej Falat, Software Engineer; Ugur Schenk, Strategy Lead) at their booth, and the TUM Blockchain Club for the general track.
- **API3 guidance, verbatim:** "Show a real use case where authenticated data matters to the core workflow. Judges look at execution and originality. The tamper test is a pass/fail qualification requirement. An autonomous agent adds value when it selects data, pays through x402 when required, and acts on-chain over repeated cycles. Payment alone or one-off MCP discovery does not demonstrate that workflow."

---

## 1. Checklist before every pitch

| # | Check | Why |
|---|---|---|
| 1 | **Julien's laptop: lid open, plugged in** | The agent runs on it. On Friday night it slept when the lid was closed on battery, and the agent stopped. |
| 2 | Agent alive: Control Room → **Agent** → "last on-chain action" is recent (a few minutes to an hour, never "hours ago") | The live story is "it works on its own" |
| 3 | Website served: `python3 -m http.server 8765 --bind 127.0.0.1 --directory demo` (repo root), then open `http://localhost:8765/control.html` | The Control Room is the pitch screen |
| 3b | Backup: the hosted copy at https://julienlmu.github.io/tumblockchain-powerpuffboys/ (same pages, live Sepolia; no local chain there) | If the laptop server fails |
| 4 | Network pill top right says **Sepolia** and the strip says "Live contract · read …" | Shows you are on the real testnet, not sample data |
| 5 | View: **Simple** (switch top right). Window about 1280 px wide | Simple is the cleanest for a pitch |
| 6 | Tabs ready: the contract on [Etherscan](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC), the agent's data payments on [BaseScan](https://sepolia.basescan.org/address/0xED3418aE93669a640650728E70f7aA712083253a#tokentxns), the GitHub repo | For "show me on chain" |
| 7 | If you do Plan A (§5): fresh orders created **about 3 minutes before**, by the operator on **the laptop that holds `BUYER_PRIVATE_KEY`** (Orhun's, as far as we know; Julien's checkout has no buyer key) | Held orders are refunded by the agent about 10 minutes after the hold |
| 8 | Phone hotspot ready | Booth Wi-Fi can drop; everything except Plan C needs the internet |

**Two roles:**
- **Presenter:** talks and clicks the website.
- **Operator:** runs terminal commands on the laptop with the keys. One person can do both, but it's calmer with two.

---

## 2. What the project is (understand this, don't recite it)

### The problem
- A buyer (say a German machine maker) orders custom parts from a UK supplier and pays in instalments: an advance, then payments at each delivery.
- The supplier was checked once at onboarding. Nobody checks the company register again before the next payment.
- If the supplier goes into liquidation in between, the register shows it within days, but the buyer pays anyway, and in a UK liquidation a trade creditor usually gets little or nothing back.
- It's common:
  - **1 in 190** companies in England and Wales became insolvent in 2025 (Insolvency Service, *Company Insolvency Statistics, Dec 2025*);
  - Germany had **24,064** company insolvencies with **€47.9 bn** owed to creditors (Destatis, 13 Mar 2026).

### The solution
1. The buyer creates an order in our smart contract on **Ethereum Sepolia**. The order holds the supplier's register ID, the instalments ("milestones"), the due dates and the rules to check. The full amount is locked in the contract.
2. Before each due date, our **agent** buys a **signed register record** from **API3 AirnodeHub**: UK **Companies House**, or **GLEIF** for companies with an LEI. It pays **$0.01 over x402** (a pay-per-request web standard) in test dollars (aUSD) on Base Sepolia.
3. The agent submits the record. The **contract checks it itself**:
   - the order is active;
   - the record is about this order's supplier;
   - it's fresh (≤ 5 minutes old);
   - it was never used before and is newer than the last check;
   - it's signed by the API3 Airnode the contract trusts.
4. The contract applies the buyer's rules: the company is active, and optionally its accounts and confirmation statement are filed on time, or its LEI is current.
5. **Clean** → a time-limited **payment permit** for the next milestone. It pays when the milestone is due **and** the buyer has approved delivery.
6. **Failed** → the order is **held**, and the remaining money can only go back to the buyer.

### Who it's for
- **Buyers**: procurement and finance teams paying advances.
- **Honest suppliers**: paid on time, no chasing.
- **Auditors**: every payment has a public reason.

It is **not** a credit score and not a delivery guarantee.

### Why API3 is essential (the API3 judges care most about this)
Without the signed record, nothing can be paid. A plain API answer could be edited by whoever forwards it. The Airnode's signature lets the contract prove the data came unchanged from the register's API. Remove API3 and the product has no input.

### Why a blockchain at all
The money sits with a neutral program whose rules anyone can read and nobody can bend. Every check, payment, hold and refund is public. And it doesn't depend on us: anyone can submit a record, release a due payment or trigger a refund after the grace period.

---

## 3. The pitch script (about 3 minutes)

Speak the quoted lines in your own words. Each **Click** cue says what to show at that moment.

| Time | Say | Click |
|---|---|---|
| 0:00–0:25 | "Last year, one in 190 companies in England and Wales became insolvent. Buyers check a supplier once, at onboarding, then keep paying it for months. If it fails in between, the next advance is gone. Your supplier was approved last month; that should not approve today's payment." | Operations, Simple. "Supplier payments" headline. |
| 0:25–0:55 | "SupplierPulse locks the order in a smart contract. Before every instalment, our agent buys a fresh company-register record from API3 AirnodeHub, signed by the Airnode, for one cent. The contract checks the signature, the company, the age and that it was never used, and only then releases the money." | Point at **Release conditions** in the open card: Buyer approval, Registry rules, Payment permit, Milestone due. |
| 0:55–1:35 | **Live orders** (§5 Plan A or B): "This supplier is active in Companies House: the signed record passed, the buyer approved, and the contract paid the moment it fell due. This one is in liquidation: the contract held the order; the money can only go back to the buyer." | Next decisions: a **Paid / Permit valid** order, then a **Held** one (**Inspect** opens its conditions in the card). Open one payment on Etherscan from the **Agent** screen (↗). |
| 1:35–2:25 | **Tamper test:** "Can you fool it? Let's forge records." Fresh record → permit. Edited value → `WrongSigner`. Genuine old record → `StaleResponse`. Other company → `WrongRequest`. Wrong signing key → `WrongSigner`. "Each answer is the live contract's own." | **Verification lab**. Press the scenarios, or **Run the tamper test** → 4/4 rejected. † Optionally type `active` → `liquidation` in **Edit the signed data yourself** and show **Where the contract stopped**. |
| 2:25–2:50 | "Nobody pressed a button for any of this. The agent has run on its own since Friday evening: over a thousand cycles, paying one cent per record. Here are its data payments." | **Agent** screen → **Data it buys ↗** (BaseScan). |
| 2:50–3:00 | "A signature proves what the register said, not that the goods arrive; that stays the buyer's approval. SupplierPulse makes sure you never pay a supplier that has already failed." | Back to Operations. |

**60-second version** (if time is short): §0, then Operations (one paid order, one held order), then the lab's **Run the tamper test**, then "the agent did all of this on its own".

---

## 4. The website, screen by screen

The main page is the **Control Room** (`control.html`), in Orhun's light "Paper" design.

**Top bar:**
- the SupplierPulse logo;
- five screens: **Operations · Verification lab · Agent · Judge kit · Settings**;
- **Guide**: a guided tour of the current screen, with Back and Next. Use it if a judge wants to explore alone;
- **Dark**: dark colours until the page is reloaded (every load starts light);
- the network pill (**Sepolia**, **Local** or **Sample**).

The logo (top left) always returns to Operations.

**Under the bar:** the source strip ("Live contract · read 10:42") and the **Simple / Complex** switch, available on every screen. Simple shows what needs a decision; Complex adds the details.

### 4.1 Operations ("Supplier payments")

- **Stats row:**
  - **Escrow remaining**: money still locked in open orders;
  - **Open / total** orders, and how many were refunded;
  - **Registries** in use: Companies House + GLEIF.
- **"N checks needed" pill**: open orders without a valid permit.
- **Next decisions** (Simple): one card per open order:
  - order number and registry (`PO-1001 / CH`) and name (Motor supply);
  - one sentence saying why it pays or waits ("Milestone 2 pays when due, Sat 31 Oct, 11:45 (in 1 h 02 min)");
  - status chips, for example `Buyer approved → Permit valid`.

  | Chip | Meaning |
  |---|---|
  | **Permit valid** | A fresh signed record passed; the next milestone can pay when due |
  | **Fresh check needed** | No valid permit; the agent will buy a record |
  | **Held** | A record failed the rules; the money can only go back to the buyer |
  | **Supplier stopped** | This supplier failed on *another* order; payments stop on all its orders |
  | **No data** | No valid record after the due date; the buyer can get the money back after the grace period |
  | **Refund to buyer** | A refund is possible now |
  | **Fully paid** / **Refunded** | The order is closed |

  **Inspect** opens the order's release conditions inside its card, right under the button; **Hide details** closes them. The first order starts open.
- **Release conditions** (inside the card after Inspect; in Complex, the panel on the right, named by order): the four facts the contract needs, each with its state:
  - **Buyer approval**;
  - **Registry rules** ("Last check passed");
  - **Payment permit** ("Valid until 10:57");
  - **Milestone due** ("In 63 min").

  The button below acts on chain: **Release milestone** when everything holds, **Refund to buyer** when that's allowed, otherwise **Payment unavailable** with the reason. It opens MetaMask; read-only until pressed.
- **Agent policy**: profile, tick interval (30 s), fetches per tick, wallet, **Data it buys: $0.01 each · x402 ↗**.
- **What happens when…** (FAQ, bottom), seven questions:
  1. fresh evidence passes;
  2. the buyer hasn't approved;
  3. evidence fails a rule;
  4. a signature, supplier, request, time or replay check fails;
  5. data unavailable;
  6. the permit expires;
  7. the supplier failed on another order.

  Plus "Important limits".
- **Complex** adds:
  - **Order monitor**: a table of every order with filters;
  - the selected order's **Evidence** (the signed record's values and signer);
  - **Milestones and policy**;
  - the **Decision trail** (every on-chain event for the order).

### 4.2 Verification lab ("Verify a signed record")

The tamper test of the API3 track. Pick an order with the chips (PO-1001 …), then a scenario:

| Scenario | What it does | Contract answer |
|---|---|---|
| **Fresh, matching record** | The real, untouched record | accepted (a permit would be issued) |
| **Edited value** | One signed value changed, original signature kept | `WrongSigner` |
| **Genuine old record** | A real record, signed too long ago | `StaleResponse` |
| **Other company** | A real record of a different company | `WrongRequest` |
| **Wrong signing key** | Signed by a key that isn't the Airnode | `WrongSigner` |
| **Previously used record** | The same record a second time | `Replayed` |

- **Run the tamper test** runs the valid record plus the four forgeries in one press and gives a verdict: **passed**, **not tested** or **broken**.
- Every answer is the **live contract's own** answer to a simulation (`eth_call`). Nothing is sent and no gas is spent. The only exception is **Previously used record**, which sends the valid record once for real, then tries it again.
- **Signed record** panel (right):
  - **Signed here**: on the local test chain, the page signs a record itself;
  - **My own**: paste or upload a record fetched with `fetch-evidence.sh` (Judge kit).
- **On live Sepolia without a fresh record,** only *Genuine old record* and *Other company* can run, using genuine records bundled in the repo. The other four say **"Record needed"**. A fresh record costs $0.01 and must be used within 5 minutes (§5).
- † **Edit the signed data yourself:** a text box with the exact signed bytes. Change `"active"` to `"liquidation"` and press **Ask the contract: edited record**. **Where the contract stopped** lists the checks in the contract's order: order active ✓, request ✓, signed recently ✓, not used ✓, newer ✓, **signed by the expected Airnode ✗**, order's rules (not reached). This is the most convincing moment of the demo.
- **Complex** adds the verification checks, what each scenario changed, and the submitted record.

### 4.3 Agent ("Agent activity")

- **Simple:**
  - **Latest actions**, newest first: "Register check passed → payment permit for milestone 2", "Paid", "Held", "Refunded";
  - each row has the order and time, and ↗ to the Etherscan transaction;
  - **All N transactions** switches to Complex.
- **Complex:**
  - a table of every agent transaction, with filter chips per order;
  - **In the loaded history**: transactions, registry checks, milestones paid, orders held, refunds, data bought.
- **Agent policy** (right):
  - **Data it buys: $0.01 each · x402 ↗** opens the agent wallet's aUSD payments on BaseScan (Base Sepolia). That is proof the agent pays for data itself.
  - The line under it says when the last on-chain action happened.
- **What to say:** "Nobody pressed a button for these."

### 4.4 Judge kit ("Judge tools")

Everything a judge needs to repeat the test outside the page, for the selected order, with **Copy** buttons:
- **Quickest: in this page:** use the Verification lab.
- **Quickest: no cost, no keys:** commands that submit **genuine records bundled in the repo** (an old one → `StaleResponse`, another company's → `WrongRequest`).
- **Get a fresh signed record:** `api3/scripts/fetch-evidence.sh ch 03778796 response.json` (pays $0.01 in test aUSD; free from API3's faucet).
- **The tamper test from a terminal:** `api3/scripts/plus-submit.sh <order> response.json [value|stale|request|key]`, which simulates by default; `--send` sends.
- **Build the request yourself:** the AirnodeHub call and the request hash, so a judge can check that the contract expects exactly this request.
- † `api3/scripts/judge-tamper.sh`: the **whole tamper test in one command** on a local chain, with no keys and no money. It prints "All cases behaved as expected".

### 4.5 Settings ("Data and connections")

- **Data:** live Sepolia (default: the page finds the newest SupplierPulse contract by itself), a **local test chain** (anvil), or **sample data** (illustrative, nothing on chain).
- **Contract details:** address with an Etherscan link, network, trusted Airnodes, maximum record age (300 s), refund grace (600 s).
- **Other screens:**
  - the buyer dashboard (`index.html`);
  - "Try to break it" (`judge.html`, the original tamper page);
  - the simple tamper page (`simple.html`).

### 4.6 Safety built into the pages (if asked)

- Link parameters are validated, and invalid ones are ignored with a note.
- Copyable commands are quoted against shell injection.
- Transactions go only to Sepolia or a local test chain.
- The pages refuse to send when embedded in another site.
- CDN scripts are pinned with integrity hashes.

---

## 5. The live demo: four plans

**Timing rules** (they cause every surprise):
- The agent acts every **30 s**.
- A record must be **≤ 5 minutes** old when submitted.
- The agent refunds a held order **about 10 minutes** after the hold.
- A record must be **newer than the agent's last check** of that order, so fetch it *after* the agent has checked.

### Plan A: live, fresh orders (best)
1. **Operator, about 3 minutes before,** on the laptop with `BUYER_PRIVATE_KEY`: run † `api3/scripts/plus-quick-orders.sh`. It creates three orders due in 2 minutes:
   - a clean UK supplier (paid by the agent);
   - a UK supplier **in liquidation** (held at the agent's first check, within 30 s);
   - a clean LEI supplier (paid).

   Costs 0.002 test ETH and $0.03 of data.
2. **Presenter:** Operations shows the held order at once. The two clean orders show **Permit valid**, then turn **Paid** about 2 minutes after creation.
3. **Live refund** (optional, buyer only): **Refund to buyer** in the Control Room with the buyer's test account in MetaMask, or `api3/scripts/plus-refund.sh <id>` in the terminal.
4. **Tamper scene:** the operator fetches a fresh record *after* the agent's first check, `api3/scripts/fetch-evidence.sh ch 03778796 record.json`. It needs `PAYER_PRIVATE_KEY`; on Julien's laptop that is the agent wallet. Upload it under **Signed record → My own**, then run the lab (and † the edit scene) **within 5 minutes**.

The new orders appear with readable names (`PO-<time>1 Motor supply`, `PO-<time>2 Gearbox`, `PO-<time>3 Cable harness (DE)`). The script prints their ids and a timeline.

### Plan B: live, existing orders (no setup)
Orders from Friday on the live contract, all real companies:

| Order | Supplier | What happened |
|---|---|---|
| PO-1001 Motor supply | UK `03778796`, active | Milestone 1 paid by the agent Fri 20:03, milestone 2 due Sat 11:45, **milestone 3 due Sat 15:30, during judging** |
| PO-1002 Gearbox | UK `07418033`, **in liquidation** | Held at the first check, refunded |
| PO-1003 Sensors | UK `09729896`, accounts **overdue** | Held, refunded |
| PO-1004 Cable harness (DE) | LEI `391200JI69LS8L648F30`, current | Milestone 1 paid Fri 20:16, milestone 2 due Sat 12:00 |
| PO-1005 Castings | LEI `52990092KBQJF8QBGJ50`, **lapsed** | Held, refunded |

Show them on Operations (Complex shows closed orders too) and the Agent screen. In the lab without a fresh record, run **Genuine old record** and **Other company**. They are real rejections by the live contract and cost nothing. For the other four, fetch a record as in Plan A step 4, or switch to Plan C.

### Plan C: local test chain (no internet, instant, free)
1. `api3/scripts/plus-local.sh` starts a local chain, the contract and sample orders, and writes the address to `api3/.local/plus-local.env`.
2. Open `http://localhost:8765/control.html?contract=<that address>&rpc=http://127.0.0.1:8545`, or choose the local chain in Settings.
3. All six lab scenarios work at once. The page signs records with a local test key the local contract trusts.
4. † `api3/scripts/judge-tamper.sh` shows the whole tamper test in one terminal command.
5. **Say so:** "this is a local test chain; the live contract gives the same answers".

### Plan D: sample data (screens only)
`http://localhost:8765/control.html?sample=1`. Every screen works with illustrative data. Say "sample data" out loud; never present it as live.

---

## 6. How it works, in more depth (for follow-up questions)

- **Contract** `SupplierPulsePlus` v1.1 on Ethereum Sepolia, `0xf25Aae1772326C95294D1923399D55c658493DfC`, source verified on Etherscan and Sourcify. It has 115 automated tests, including every tamper case with real signed records.
- **Check order** (the first failure stops everything): order active → request matches → time (≤ 300 s, not in the future) → digest never used → newer than the order's last record → signer is the trusted Airnode → the order's rules.
- **Rules per order:**
  - Companies House: status `active` (always), accounts filed on time, confirmation statement filed on time;
  - GLEIF: entity `ACTIVE` (always), LEI `ISSUED`.
- **Payment permit:** one per milestone, valid for a limited time from the record's signed time and never extended.
- **Dual lock:** payment needs a valid permit **and** the buyer's approval. The register proves the company is alive; the buyer confirms delivery.
- **Supplier-wide stop:** a failed company status stops payments to that supplier on **all** its orders, until a newer clean record arrives.
- **No-data exit:** if no valid record arrives after an approved milestone is due, anyone can return the money to the buyer after the grace period.
- **Verification history:** 3 clean checks in a row → **Trusted**; 6 → **Premium**. Each check counts only if it is at least 5 minutes after the last counted one. A higher tier only means the agent re-checks less often between due dates (10 / 30 / 60 minutes in the demo). It never skips the check before a payment and never relaxes the rules.
- **Agent** (Python, `api3/agent/`):
  - every 30 s it reads all orders and decides: nothing, check before a due date, re-check by tier, release, hold, or refund;
  - it buys records within a daily budget ($1 in the demo, with a reserve kept for due checks) and at most 3 per cycle;
  - it simulates every transaction before sending and sends each only once;
  - on errors it waits longer each time instead of buying again;
  - 86 automated tests, two independent reviews.
- **Two chains:** orders and payments are on Ethereum Sepolia; the data payments (x402, aUSD) are on Base Sepolia. The agent links them. It isn't a cross-chain bridge, and nothing needs to be.

---

## 7. The API3 track requirements, and where we show each

| Requirement | Where |
|---|---|
| AirnodeHub data is essential to a core feature | No milestone pays without a signed Companies House or GLEIF record (Operations → Release conditions) |
| A signed response goes to a **deployed** contract that checks signer, request and time | Live contract above; lab answers; † "Where the contract stopped" |
| A value bound to the signed response drives an on-chain action, with replay protection | Permit → payment, or hold → refund (Agent screen, Etherscan); **Previously used record** → `Replayed` |
| Judges can submit their own responses | Lab → **My own** record; **Judge kit** commands; † `judge-tamper.sh` |
| Tamper test: one valid, then four rejections | Lab scenarios / **Run the tamper test** (and in the video) |
| Who relies on the data | The buyer's money: the signed record is the only input that decides a payment |
| What goes wrong if it's forged | A forged "active" record pays a company being wound up; a forged negative record blocks an honest supplier |
| Data we wanted but couldn't find | The German Handelsregister and German insolvency notices; delivery confirmations from company systems |
| *Bonus:* an agent that picks data, pays via x402 and acts over repeated cycles | Agent screen + **Data it buys ↗** (BaseScan) |

---

## 8. Numbers you may quote

| Number | Source / how to check |
|---|---|
| 1 in 190 companies in England and Wales insolvent in 2025 | Insolvency Service, *Company Insolvency Statistics, Dec 2025* |
| 24,064 German company insolvencies, €47.9 bn creditor claims (2025) | Destatis press release 085, 13 Mar 2026 |
| $0.01 per signed record | x402 price; BaseScan link on the Agent screen |
| Over 1,000 autonomous agent cycles since Fri 18:18, around 40 on-chain transactions, well under $1 spent on data | Agent screen (current count) and `docs/evidence.md`. **Say "over a thousand" rather than an exact number unless you just checked.** |
| 115 contract tests, 86 agent tests | `forge test`, agent `pytest` |
| Records valid ≤ 5 min; refund grace 10 min | Settings → contract details (demo values; in production these would be longer) |

---

## 9. Questions judges will ask

| Question | Answer |
|---|---|
| Why not call Companies House directly? | An unsigned answer can be changed by whoever forwards it. The contract verifies the Airnode's signature over the exact data and request, plus freshness and replay. That is why AirnodeHub is the core input. |
| What exactly does the signature prove? | That this Airnode signed these bytes for this request at this time. Not that the register is complete, or that the supplier will deliver. |
| How do you know the payout wallet belongs to the supplier? | We don't prove it on chain. The buyer gets the wallet when signing the contract with a supplier it has already vetted, the same way it gets an IBAN today. |
| Why does the buyer still approve? | The register can't confirm delivery. Payment needs both the register check and the buyer's approval. |
| Can an old clean record be reused? | No. It must be ≤ 5 min old, newer than the last check, and never used before (`StaleResponse`, `Replayed`). |
| What if the API is down or a field is missing? | No valid record means no permit, so no payment. The agent backs off and retries. After the due date plus the grace period, anyone can return the money to the buyer. |
| What if your agent stops? | Anyone can submit a record, release a due payment or trigger a refund. The agent is a convenience, not a gatekeeper. |
| Can a supplier game the tiers? | Only newer verified records count, at most once per tier gap. One failure resets the streak and stops older permits on all its orders. Tiers only change how often the agent re-checks; they never extend a permit. |
| Can someone drain your agent's budget with fake orders? | The agent serves any order on the contract, but it has a daily budget ($1 in the demo) with a reserve for due checks. An allowlist per buyer is the obvious production step. |
| Can the admin cheat? | The admin can change the trusted Airnode address and the maximum record age. In production those would sit behind a time lock or several signers. The order terms can't be changed. |
| Why two chains? | API3's paid data uses aUSD on Base Sepolia via x402; our escrow is on Ethereum Sepolia. The agent pays on one and acts on the other. |
| What does it cost? | One cent per check plus gas. The live run has spent well under a dollar of data. |
| Is this a credit score? | No. It's fresh registry evidence: is the company alive and up to date with its filings, right now. |
| What's next? | More registers (the German Handelsregister and insolvency notices once a signed source exists), longer production time windows, per-buyer allowlists, and privacy for order documents (only hashes on chain). |
| Is this the first? | We don't claim that. Supplier-risk tools and smart-contract escrow exist. Our mechanism is fresh signed registry evidence inside the payment rule, enforced by the contract. |
| Who is the customer, and would they pay? | A mid-size manufacturer paying advances to foreign suppliers (procurement or treasury). One cent of data per check, against advances worth tens of thousands of euros. |
| Doesn't credit monitoring (Creditsafe, D&B) already do this? | Those alert a person; we gate the payment. A missed alert cannot release money. We don't claim to be first. |
| How fast does the register show trouble? | Usually within days. That's why each milestone needs its own fresh check; last month's approval doesn't count. |
| How would this make money? | Not built. Possible: a small fee per check or per order, or a subscription per buyer. Say it's an idea. |
| Why not a bank escrow? | The rules are public and nobody can bend them, every decision leaves an audit trail, and nobody has to trust us: anyone can trigger the next step. |
| What does a check cost on mainnet? | About 680,000 gas per check: several dollars on Ethereum mainnet, cents on a Layer 2. Production would run on an L2. |
| Privacy: are amounts and suppliers public? | Amounts and the payout wallet are public (the contract moves the money); the order reference is stored only as a hash. Hiding amounts needs zero-knowledge proofs: future work. |
| What if the Airnode's key is compromised? | The admin can switch to a new Airnode address. That's exactly why it belongs behind a time lock or several signers in production. |
| How did you test it? | 115 contract tests (every tamper case with real signed records), 86 agent tests, two independent reviews, and the live run since Friday. |
| What was hardest / what would you do with another week? | Hardest: real signed records cost ~680,000 gas, more than expected. Next week: more registers, production time windows, per-buyer allowlists, document hashes. |
| Who built what? | See §13. |
| Can I try it myself, right now? | Yes: the hosted Control Room → Verification lab, or `api3/scripts/judge-tamper.sh` (one command, no keys). |

---

## 10. Say it precisely (claims to keep bounded)

- Say **"registry evidence"**, never "financial health score" or "insolvency prediction".
- The contract **holds the remaining balance** after a failed record. It can't claw back a milestone that was already paid.
- Lab answers are **simulations of the live contract** (except the replay). The agent's payments, holds and refunds are **real testnet transactions**.
- Everything is **testnet**: Sepolia ETH and test aUSD, worth nothing.
- Never say "726,735 companies failed". That number counts mostly voluntary dissolutions.
- Don't show the Cardano work (`cardano-agent/`). It's an earlier experiment and not part of this entry.
- GLEIF covers only companies with an LEI. Many small German firms have none.

---

## 11. Words on the screen

| Term | Meaning |
|---|---|
| **Airnode** | API3's signing node for one data source (here Companies House and GLEIF) |
| **AirnodeHub** | API3's catalogue of signed data sources the agent buys from |
| **Signed record** | The register's answer plus the Airnode's signature, timestamp and request hash |
| **x402** | Pay-per-request standard; the agent pays $0.01 per record |
| **aUSD** | API3's test dollar on Base Sepolia |
| **Permit** | A time-limited OK for one milestone, issued by the contract after a clean record |
| **Held** | The order failed a rule; the remaining money can only go back to the buyer |
| **Grace period** | 10 minutes in the demo; after it, anyone can trigger the refund |
| **Tier** | Standard / Trusted / Premium, a history of clean checks; changes only the re-check interval |
| `WrongSigner` / `StaleResponse` / `WrongRequest` / `Replayed` | The contract's rejection names: bad signature or edited data / too old / different company or request / already used |
| `eth_call` | Asking the contract what it would do, without sending anything |

---

## 12. Addresses and links

| What | Value |
|---|---|
| Contract (Ethereum Sepolia) | `0xf25Aae1772326C95294D1923399D55c658493DfC`, [Etherscan](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC#code) |
| Trusted Airnodes | Companies House `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, GLEIF `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c` |
| Agent wallet | `0xED3418aE93669a640650728E70f7aA712083253a`, data payments on [BaseScan](https://sepolia.basescan.org/address/0xED3418aE93669a640650728E70f7aA712083253a#tokentxns) |
| Repository (public) | https://github.com/julienlmu/tumblockchain-powerpuffboys |
| Hosted Control Room (GitHub Pages) | https://julienlmu.github.io/tumblockchain-powerpuffboys/ |
| Every transaction with links | `docs/evidence.md` |

## 13. Who built what (if asked)

| Part | Who |
|---|---|
| Smart contract, Control Room design | Orhun |
| Data layer: paid fetching, signature and tamper tools | Emre |
| Autonomous agent, specification, coordination | Julien |
| Dashboard and "Try to break it" page | Batu |
| Story, pitch, Devfolio text, video | Ulaş |
