# Idea decision sheet

Status: **no idea decided yet** (confirmed by Batu, Fri 30 Oct ~11:20). Julien decides.
Author: Batu (role E). Docs only, no code changed.

Legend: **[F]** = fact, checked against a source today. **[I]** = inference or judgement, not verified.

## Facts checked today that change the comparison

1. **[F] Masumi escrow does not release "only if a check passes" by itself.** After the seller submits a result, funds unlock automatically when `unlockTime` passes. Before that, the buyer can call `POST /purchase/request-refund`, and the seller can accept with `POST /payment/authorize-refund`. Unresolved disputes go to the Masumi team.
   Source: https://www.masumi.network/dev/masumi/core-concepts/refunds-and-disputes.md
   → To make "payment tied to result" real, **our code must trigger the refund**: either the seller agent authorizes its own refund when its output fails the check, or a buyer-side verifier agent requests it.
2. **[F] The current vault code does not do this.** In `cardano-agent/agent.py`, a result is returned even when `executed=false`, so the escrow releases either way.
   **Outdated (30 Oct, 12:10):** Julien's commit `af864ac` on `main` makes the agent pay-on-pass. With `apps/eth-vault.json`, a result is delivered only if the vault executed, and otherwise `refunds.py` authorizes the buyer's refund. See `cardano-agent/README.md`.
3. **[F] AirnodeHub listings (from https://airnodehub.api3.org/llms-full.txt):**

| Listing | Attestation | Price per call | Relevant field |
|---|---|---|---|
| Nodary (ETH/USD etc.) | first-party | free | latest feed value |
| CoinGecko `simplePrice` (used by `api3/scripts/fetch-eth-usd.sh` today) | third-party | $0.02 aUSD | price |
| GLEIF `getLegalEntity` (`searchLegalEntities` is free) | third-party | $0.01 aUSD | entity status, registration status |
| Companies House `getCompanyProfile` | third-party | $0.01 aUSD | `company_status` (active, dissolved, liquidation) |
| AeroDataBox `flightStatus` | third-party | $0.05 aUSD | status, departure/arrival times |
| PublicAML (wallet sanctions screening) | third-party | quota units | `sanctioned`, risk score |

   aUSD is API3's test dollar on Base Sepolia (free from the faucet).
   GLEIF's own note: an issued LEI does **not** prove solvency, sanctions clearance or authority to transact.
4. **[I] Suggestion for the vault path, owner Orhun's call:** Nodary ETH/USD is free and first-party, so it may be simpler than CoinGecko, which is priced and therefore needs the x402 402-flow. This needs re-checking against the signed response format.
5. **[F] API3 judging weights** (https://api3dao.github.io/airnodehub-hackathon/docs/):
   - **Real use case 40%**
   - Signed data matters 30%
   - Execution 20%
   - Novelty 10%: "beyond the unchanged starter"
   - +10 agent bonus: repeated autonomous cycles in which the agent chooses data, pays via x402 and acts on-chain. x402 alone does not earn it.
   - The tamper test is pass/fail, and a valid response must also work.
6. **[F] The official starter already is a Nodary ETH/USD price consumer.** API3's own idea list names "payment or escrow released when … data meets a condition" with Companies House as an example, and "Conditions → payments … a company meets a registry condition".
   → [I] A price-triggered vault (#0) sits very close to the unchanged starter, which costs points on novelty (10%) and likely on real use case (40%).
7. **[F] Projections answer the open question for #3.**
   - A request can project any JSON pointer, e.g. `status` → `/company_status`, into a top-level field.
   - The Airnode signs only those fields, and the request hash covers the projection.
   - The starter's `ProjectedJson` reads strings, numbers, booleans and ISO 8601 times. A Companies House status therefore reads like a price.
   - A missing field returns HTTP 400 and nothing is signed.
   - Source: https://api3dao.github.io/airnodehub-hackathon/docs/projections
   - [I] The exact GLEIF pointer (likely `/data/attributes/entity/status`) still has to be checked against a live response.
8. **[F] The API3 submission must also state "who relies on the data, what goes wrong if forged, what data you wanted but could not find".** For #3: a forged "active" status would release money to a dissolved or fake company, which is a concrete answer.

## Julien's proposals (PROGRESS.md, 11:17) applied to #0

Julien proposes:
1. Pay only on execution.
2. Name the customer: a Cardano treasury that wants an EVM action without running a bot.
3. Watch until a deadline.
4. State the trust assumption.
5. De-risk the infrastructure.

With 1–3, #0 gets real "payment tied to result" and becomes eligible for the API3 agent bonus (repeated cycles) [I].

**Input on proposal 1 (Julien's open Masumi question):**
- [F] The Masumi doc lists "no response before the deadline" as a valid reason for the buyer's `POST /purchase/request-refund`. The seller then has to `authorize-refund`. If it does not, the dispute escalates to the Masumi team.
- [I] So "let the job run out" may end in an escalation rather than an instant refund. The safer demo is for our seller agent to call `POST /payment/authorize-refund` itself when the condition is not met by the deadline. Confirm with a Masumi engineer.

What proposals 1–3 do **not** fix: real use case (40%) and novelty vs the Nodary starter (10%) [I].

## #6 Mining payout settlement: API3 review (30 Oct, ~12:52)

Idea from `docs/BRAINSTORMING.md` on branch `brainstorm/mining-payout-settlement` (12:37, marked "exploration only"):
- A mining reward is valued at the coin price **at the moment it is earned** and credited in USD to the user's "savings box".
- On withdrawal, the balance is paid out, possibly via Cardano.

This section only looks at the API3 side.

### What AirnodeHub has for this idea

Checked today: the catalogue https://airnodehub.api3.org/llms-full.txt, two free live calls, and the docs https://api3dao.github.io/airnodehub-hackathon/docs/ and `/docs/from-api-to-contract`.

| Data | Listing / operation | Signed by | Price | Status |
|---|---|---|---|---|
| Current DOGE, LTC, BTC, ADA in USD | Nodary `latestFeeds` | first-party (`0xE70f…E4c0`) | free | **[F] live call OK**: DOGE/USD 0.07576, LTC/USD 55.375, BTC/USD 77424.16, ADA/USD 0.19356. BCH/USD and ETC/USD not served. |
| **Price at a past moment** | dRPC `historicalPrices` (symbols + Unix ms timestamps) | third-party (`0x511A…2137`) | $0.01 | **[F]** 621 symbols incl. BTC, DOGE, LTC, BCH, ETC, RVN, ZEC, ADA (free `priceSymbols` call). The docs call it "the one reproducible Data API operation". Response shape **not seen yet** (paid call). |
| Bitcoin wallet balance | dRPC `nonEvmWalletBalances` | third-party | $0.01 | [F] only solana, bitcoin, tron. Not tried. |
| Mining pool shares, rewards, hashrate, block rewards, Dogecoin chain data | — | — | — | **[F] not on AirnodeHub.** The catalogue has zero matches for mining, miner, hashrate, mining pool, block reward. |

### Against the API3 judging criteria

1. **Real use case (40%)**: medium [I].
   - Plausible user: a small miner or hosting customer who wants income booked in USD at the time it was earned, e.g. for accounting.
   - Weak points: the USD credit is backed off-chain until the coins are sold, so the company carries price risk (the brainstorm doc says so itself). Pools already pay out directly. A judge will ask who pays for this and why.
2. **Signed data matters (30%)**: **the weakest point** [I].
   - The contract can verify the price, but the **reward amount**, the other half of the credit, comes from pool data that is not on AirnodeHub. It would be unsigned or simulated.
   - So the agent or operator could still fake the outcome by inflating the reward. That is exactly what this criterion penalises: "With an unsigned API call, anyone could fake the outcome."
   - Partial fix for BTC only: a signed `nonEvmWalletBalances` could show that a pool payout reached the miner's address. It is coarse (balance, not per transaction) and not checked yet.
3. **Novelty (10%)**: a plain "latest price" credit is the starter's Nodary pattern [F: fact 6 above]. But there is a stronger mechanism [I]:
   - Value each reward with `historicalPrices` **at the reward's own timestamp**, and let the contract **build the request hash on-chain** from (symbol, reward timestamp).
   - Then nobody can pick a convenient moment or price. A response for any other moment fails as "different request".
   - This anti-cherry-picking rule goes beyond the starter. It needs checking: the docs show on-chain hash building for `POST /` (operation + canonical parameters + projection) with a Nodary example, but `historicalPrices` takes **arrays** as parameters. That encoding is unverified.
4. **Execution (20%)**: medium [I].
   - Orhun's signer, request, freshness and replay checks carry over.
   - New work: a ledger contract, on-chain hash building for array parameters, a check that the signed data's timestamp equals the reward timestamp ("a fresh signature can cover an old value", per the docs), and simulated pool data.
5. **Agent bonus (+10)**: **good fit** [I]. An agent watches rewards over time, picks coin and moment, pays $0.01 per `historicalPrices` call via x402 (Nodary is free, so it would not need x402), and books on-chain with no human per cycle.

### Tamper test fit

All four cases map cleanly [I]:
- (a) edited price → wrong signer
- (b) old signature → too old
- (c) price for another moment or another coin → different request. This is a strong demo when the hash is built from the reward timestamp.
- (d) other key → wrong signer

### Submission answer "data we wanted but could not find"

[F] Mining pool share and reward data and Dogecoin chain data are not on AirnodeHub. This is an honest, concrete answer.

### Verdict (Batu's view, for the team to challenge)

- **Workable for API3, but weaker than #3 on "signed data matters" (30%) unless the reward amount is attested too** [I]. In #3 the signed register status *is* the decision. Here the signed price is only half of it.
- **Stronger than #0** [I], if it uses the reward-timestamp `historicalPrices` mechanism and the agent loop. Both add novelty and the agent bonus over a plain latest-price trigger.
- Suggested scope if chosen:
  - one coin (DOGE or BTC)
  - simulated pool rewards, clearly labelled
  - contract credits `reward × signed price at reward time` once per reward id
  - the pitch says plainly that the reward amount is a trusted pool report and the valuation is trustless
- Open checks before deciding: **done 30 Oct ~12:56**, see below.

### Results of the paid checks (30 Oct, ~12:56)

Two paid calls from Batu's wallet `0xA545…FB4c`, using the x402 client copied from the official starter (`src/x402.ts`, commit `52933ae`).
- Cost: **0.01 aUSD in total.** Payment tx `0xf54d7b05d806a0e246472f3380438710f85020441797dca6cd5ec44b43eeaa91` on Base Sepolia, checked with `cast receipt`.
- Balance after: 9.99 aUSD. The failed call was not charged.

1. **`historicalPrices` gives a signed price bound to the requested moment: [F] yes.**
   - Request: `{"operation":"historicalPrices","parameters":{"symbols":["DOGE"],"timestamps":[1793347200000]}}`, i.e. 30 Oct 2026 08:00:00 UTC.
   - Signed `data`: `{"data":{"DOGE":[{"price":0.07564,"timestamp":"2026-10-30T08:00:00+00:00"}]}}`
   - The signed data carries the requested moment as ISO 8601. The starter's `IsoTimestamp` reads the `+00:00` form (`contracts/IsoTimestamp.sol`), so the contract can require `data time == reward time`.
   - Signature time 11:56:15 UTC is fresh, while the value is from 08:00. The docs warn exactly about this: "a fresh signature can cover an old value". Here it is intended, so check both.
   - Recovered signer `0x511AcE8648D2f64260d50D036F8f8ce622d92137`, the dRPC Airnode listed in the catalogue.
   - [I] Only one data point was seen. The price granularity (per minute or per hour?) is not known.
2. **Request hash for array parameters: [F] the off-chain formula holds.**
   - The response's `requestHash` `0x59f68cc5…5388f` equals `keccak256('["historicalPrices",[["symbols",["DOGE"]],["timestamps",[1793347200000]]]]')`, checked with `cast keccak`.
   - So the contract has to build exactly that string from (symbol, reward time in ms).
   - [I] This is straightforward string building: a quoted symbol and an unquoted integer below 2^53. The docs build Nodary hashes on-chain for ~5,500 gas. **Not compiled or tested on-chain yet.**
   - A projection (e.g. `price` → `/data/DOGE/0/price`, `time` → `/data/DOGE/0/timestamp`) would flatten the data for `ProjectedJson`. It changes the hash, and the starter has `escapePointerToken` for building it on-chain.
3. **Signed Bitcoin wallet balance: [F] failed, inconclusive.**
   - `nonEvmWalletBalances` for `bitcoin` / `1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa` (genesis address) returned HTTP 502 `{"error":"Upstream responded with 404 ","upstreamStatus":404}`. Not charged.
   - Proof that a pool payout really arrived therefore stays open. The reward amount remains a trusted input.

**Updated verdict [I]:**
- The valuation half of #6 is now technically proven: a signed price bound to the reward's own moment, with a request hash the contract can rebuild.
- The reward-amount half is still unsigned. So #6 stays behind #3 on "signed data matters" (30%), but clearly ahead of #0 on novelty and the agent bonus.

## SupplierPulse (#3 extended): API3 review (30 Oct, ~13:46)

Reviewed:
- `docs/SUPPLIERPULSE.md` (plan, "agreed by Orhun") and `api3/src/SupplierPulse.sol` + `api3/test/SupplierPulse.t.sol`, all on branch `supplier-pulse` (`9bef289`, Orhun, 13:38).
- The idea: every payment stage of a supplier order needs a **fresh** signed Companies House `company_status`. An "active" status issues a permit for one stage that expires. Any other status holds the rest of the order.

### Checked

- [F] **Tests pass.** `forge test` on a scratch copy of `supplier-pulse`: SupplierPulse 14/14, existing vault 17/17.
- [F] **The Companies House listing exists and fits** (https://airnodehub.api3.org/llms-full.txt):
  - URL `https://airnode-companies-house.fly.dev/`, signer `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, third-party attestation.
  - `getCompanyProfile`, parameter **`company_number`**, $0.01 aUSD via x402. The response has `company_status`.
- [F] **Search is free** (`searchCompanies`, `advancedSearchCompanies`) and is signed by the same Airnode. A free call today (`company_name_includes=motor`, `company_type=ltd`) found test candidates:

| Case | Company number | Name | Status (search index) |
|---|---|---|---|
| paid | `09729896` | POOLE BRIDGE MOTOR COMPANY LTD | active |
| paid | `10092605` | JENKINS MOTOR COMPANY LIMITED | active |
| held | `07418033` | A K MOTOR SERVICES (PLYMOUTH) LTD | liquidation |
| held | `12493325` | LUXURY MOTOR RENTAL LTD | dissolved (2020-12-22) |

  These are real public register entries. Confirm with one paid `getCompanyProfile` before the demo, because the search index may lag the profile.
- [F] **No German register on AirnodeHub.** The catalogue has zero matches for Handelsregister, Insolvenz, Unternehmensregister or OpenCorporates. This is a good answer to "what data did you want but could not find" for a German customer.

### Against the API3 judging criteria [I]

- **Real use case (40%):** strong.
  - Concrete customer and money at risk: instalments to a supplier that went into liquidation.
  - API3's own idea list names "payment or escrow released when authenticated external data meets a condition", with Companies House as an example [F, fact 6].
- **Signed data matters (30%):** **strongest of all candidates.** The signed status *is* the payment decision. Forge `active` and money goes to a dead company.
- **Novelty (10%):** good.
  - The permit expires, is bound to one stage, one supplier wallet and one order, and is used up by the payment.
  - "Approval last month ≠ approval today" goes clearly beyond the starter.
- **Execution (20%):** good. The contract and tests exist. The live response and deploy are still open.
- **Agent bonus (+10):** good fit. The agent re-checks before each payment date and pays x402 each time (`getCompanyProfile` is priced).

### Issues to fix or decide

1. **[F] Parameter name.**
   - The test hashes use `["getCompanyProfile",[["companyNumber","01234567"]],[["status","/company_status"]]]`, but the listing's parameter is `company_number`.
   - The contract itself is fine, because it takes the hash as input. But any script that builds `companyRequest` must use `company_number`, or every real response fails with `WrongRequest`.
   - Safest: take the hash from one real response.
2. **[I] The live demo cannot show "status changes between stage 1 and stage 2".** One real company will not change status during the demo. Honest demo:
   - Order A with an active supplier: stage 1 paid, the permit expires, stage 2 needs a new check and is paid.
   - Order B with a supplier in liquidation: held at the first check, buyer refunds.
   - The status-change story stays in the unit test (`test_holdsRemainderWhenStatusChanges`) and in the pitch, never faked in the video.
3. **[I] Make the company visible on-chain.**
   - `companyRequest` is an opaque hash chosen by the buyer, and the docs warn "a hash does not show its request".
   - Better: store the company number and build the hash in the contract. The docs recommend the `POST /` route for this, with a Nodary example at ~5,500 gas. At least emit the company number in `OrderCreated`.
   - This also makes tamper case (c) easy to explain to judges.
4. **[I] Keep the projection mandatory.**
   - `PriceParser.parseString` takes the first `"status":` in the data. That is only safe with the projection `status` → `/company_status`.
   - The request hash covers the projection, so an unprojected response already fails as `WrongRequest`. Document this in the README.
5. **[I] Keep `maxAge` short.**
   - `submitEvidence` is open to anyone. An "active" response fetched just before a status change stays usable for `maxAge`.
   - A narrow window (minutes, not a day) limits this, as the API3 docs advise for cherry-picking. The permit TTL is counted from the evidence time, which is good.
6. **[I] Only `active` passes.**
   - Statuses such as `administration` or `voluntary-arrangement` hold the order. That is probably right, but say it in the README.
   - Possible later rule, not v1: also hold when the profile shows overdue accounts.
7. **[F] One response serves one order.** `usedDigests` is global, so two orders for the same company need two checks ($0.01 each). That is fine.

### Real signed responses (30 Oct, ~13:48)

Three paid `getCompanyProfile` calls from Batu's wallet, through the `POST /` route with projection `status` → `/company_status`. Cost 0.03 aUSD; balance after 9.96 aUSD, checked on chain.
- Signer recovered locally: `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` for all three.
- Each request hash matches `keccak256('["getCompanyProfile",[["company_number","<n>"]],[["status","/company_status"]]]')`.
- The full signed responses are in `docs/samples/companies-house/`.

| Company | Signed `data` | Request hash | Payment tx (Base Sepolia) |
|---|---|---|---|
| `09729896` | `{"status":"active"}` | `0xcae416f2dce5fb6bb595eafe8c5f11ce9df4b33f8664042e10f8f776739fab48` | `0xc3947d9606778d29a7ab9089148e33af1c5dfa45670ad587fc988839b66e6bfc` |
| `07418033` | `{"status":"liquidation"}` | `0x31975e4f7156ae305cc9e62a96e86e78272cf4f44ab7743deb7ec018a0f32456` | `0x36ef68df3d4fed188fc3908f2e3f531b22304a0c52f7919f4215bc92c1241845` |
| `12493325` | `{"status":"dissolved"}` | `0xd9c5302e16e8f4ecaf356e4de82be433306884d416c9b03af5a5927b469437a7` | `0x7718519b38f49b4c2e810012551af07da910f62605aa6b74ff1d029d33fd2c7b` |

**[F] `SupplierPulse.sol` works with the real responses.** Batu ran a scratch Forge test on a copy of `supplier-pulse` (not committed), with signer = the Companies House Airnode, `maxAge` 300 s and `statusKey` `"status":`. Result: 6/6 pass.
- active → milestone paid
- liquidation → held, buyer refunded in full
- dissolved → held
- `liquidation` edited to `active` → `WrongSigner`
- the liquidation response sent to the active company's order → `WrongRequest`
- 301 s later → `StaleResponse`

This confirms issue 1 above: the real parameter is `company_number`.

### Verdict (Batu's view, for the team to challenge)

**SupplierPulse is the strongest API3 candidate so far** [I]:
- It beats #0 on use case and novelty.
- It beats #6 (mining) on "signed data matters", because nothing in the decision is unsigned.

Fix items 1 and 2 before the demo. Item 3 is a cheap upgrade worth doing. Next paid step: one `getCompanyProfile` per test company ($0.01 each, Batu's wallet), to fix the real request hash and confirm the statuses.

## Comparison

| # | Idea | Customer & paid job | Payment tied to result | Real vs mocked | Build risk | Cardano fit | API3 fit |
|---|---|---|---|---|---|---|---|
| 0 | **Conditional Vault Executor** (Orhun, code exists) | DeFi user pays ADA so an agent executes "if ETH < X, pay out" on an EVM vault | Not yet. Fixable: refund if the condition is not met or the tx fails [I] | Real: contract + 15 tests [F]. Not yet real: live AirnodeHub fetch, testnet deploy, paid preprod job [F] | **Lowest**, because the code exists. Live endpoint untested [F] | Medium. The customer is weak: an EVM user would use an EVM keeper (Gelato, Chainlink Automation) directly, not pay in ADA [I] | Strong technically: the signed price drives payout. Low originality: price-triggered payout is the default oracle demo [I] |
| 1 | **8D-report agent + quality gate** | Quality manager pays to get an 8D draft from a supplier complaint | Agent checks D1–D8 completeness and refunds itself if the check fails [I] | Real: LLM draft + deterministic check. Mocked: complaint input | Low–medium. Cardano only, no EVM [I] | Good customer story. The check is structural only: it shows the report is filled in, not that the root cause is right [I] | None |
| 2 | **Quality-gate escrow as dev tool** | Any Sokosumi buyer pays a verifier agent that hires the seller agent and pays only for passed work | Native to the idea [I] | Real: two agents, one hires the other | Medium: needs a second Coworker and an abstract pitch [I] | **Best fit to "agents hire agents" + "payment tied to result"**. Weakest customer story [I] | None |
| 3 | **Supplier approval gate** | Procurement/AP team pays the agent to verify a new supplier before a first payment | Agent is paid on Cardano. EVM contract releases the supplier payment only if the signed GLEIF/CH status is active. Refund if no attested result [I] | Real: GLEIF + Companies House data on AirnodeHub [F]. Mocked: the supplier payment in aUSD stands in for a bank transfer | Medium: vault logic reusable, status parsing instead of price parsing [I]. Unverified: size and shape of the signed JSON, projection support | Clear B2B customer and a real-world action (gate a payment) [I] | **Core**: without the signed register data the gate has no function [I] |
| 4 | **Parametric flight-delay cover** | Traveller pays a premium, payout if the delay exceeds X | Payout fully data-driven [I] | Real: AeroDataBox [F]. Live demo needs a delayed flight, or a past date via `flightStatusOnDate` [F] | Medium–high: $0.05/call and a ~2,000-lookup quota shared by all teams [F]. Insurance framing invites regulatory questions [I] | Good customer story | Core, but a known pattern (e.g. Etherisc) [I] |
| 5 | **Pay-per-call standards API** (x402) | Engineer pays per lookup | Pay per request, no result check | Real x402 payment | Low | Weak: no escrow, no agent logic. ISO/DIN texts are copyrighted [I] | None |

## Judgement (Batu's view, for the team to challenge)

- **Batu's earlier inference: "#3 has the stronger customer story and makes API3 core"** → **partly confirmed**.
  - [F] The data exists on AirnodeHub, is cheap ($0.01 test aUSD) and is signed.
  - [I] The customer story is stronger than #0.
  - [F] Projections make the status field readable on-chain like a price (fact 7). This was the main technical doubt, and it is now resolved on paper. It still needs one live signed response.
  - [F] API3's own idea list points at exactly this pattern (fact 6), and real use case is the heaviest weight at 40%.
- **If API3 stays in scope:** #3, built by reusing Orhun's vault, is the best trade-off between originality and risk [I]. The parser and the condition change; signer, request, freshness and replay checks stay the same.
- **If Cardano only:** #1 + #2 merged. The 8D agent is the seller and a verifier agent pays only for a passed check. This shows "agents hire agents" and "payment tied to result" [I].
- **Regardless of idea, do now:**
  - [I] Get the first paid preprod tx (x402 or Masumi). The idea choice does not block it, and it is the qualification gate.
  - Add the self-refund on failed checks. This is the "payment tied to result" point Cardano judges list explicitly [F: CLAUDE.md §2].

## Questions for Julien

1. Is API3 in scope? Yes → #0 or #3. No → #1/#2.
2. Keep Orhun's vault "as is" (lowest risk) or re-target it to #3 (better story, roughly half a day of change) [I]?
3. Who owns the first paid preprod tx, and by when (target in CLAUDE.md: Fri ~13:00)?
