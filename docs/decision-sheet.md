# Idea decision sheet

Status: **no idea decided yet** (confirmed by Batu, Fri 30 Oct ~11:20). Julien decides.
Author: Batu (role E). Docs only, no code changed.

Legend: **[F]** = fact, checked against a source today. **[I]** = inference or judgement, not verified.

## Facts checked today that change the comparison

1. **[F] Masumi escrow does not release "only if a check passes" by itself.** After the seller submits a result, funds unlock automatically when `unlockTime` passes. Before that, the buyer can call `POST /purchase/request-refund`, and the seller can accept with `POST /payment/authorize-refund`. Unresolved disputes go to the Masumi team.
   Source: https://www.masumi.network/dev/masumi/core-concepts/refunds-and-disputes.md
   → To make "payment tied to result" real, **our code must trigger the refund**: either the seller agent authorizes its own refund when its output fails the check, or a buyer-side verifier agent requests it.
2. **[F] The current vault code does not do this.** In `cardano-agent/agent.py`, a result is returned even when `executed=false`, so the escrow releases either way.
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
