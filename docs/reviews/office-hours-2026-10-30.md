# Office-hours review: SupplierPulse+

Format: office-hours review (problem, customer, premises, alternatives, next steps), hackathon mode, with the harder customer questions from startup mode.
Reviewed: branch `supplierpulse-plus` at `864fe18` (Fri 30 Oct, 16:18 CET). Read-only review, no code changed.
Time left: about 22 hours (target submit Sat 14:30, hard deadline 15:00).

---

## 1. Summary

1. **The idea is strong, and v1 works today.** v1 is live on Sepolia with one real "paid" run, one real "held" run and four tamper rejections on record. The technical part of the API3 qualification is largely done.
2. **The biggest risk is scope.** The 1,397-line SupplierPulse+ spec plans a five-person parallel build in one night: a new contract, two registries, trust tiers, an autonomous agent and two web pages. If one stage slips, the whole integration slips.
3. **The decision to question most: dropping Cardano.** Cardano already qualifies (real escrow payout and refund on preprod), and its prize pool is three times API3's (€6,000 vs €2,000). Dropping it may throw away a free chance (see §4, premise 1).

---

## 2. What the project is (context)

**Problem:** companies check a supplier once, at onboarding, then pay instalments for months. Meanwhile the supplier can go into liquidation, and the next payment still goes out.

**Solution (v1, live):** the contract needs a fresh, signed Companies House record for every payment stage (API3 AirnodeHub, $0.01 over x402). It verifies signer, request and freshness. `active` issues an expiring permit for that stage. Anything else locks the remaining balance for the buyer.

**SupplierPulse+ (decided ~16:00, not written yet):**
- GLEIF as a second registry
- rules the buyer picks per order (insolvency history, overdue accounts, overdue confirmation statement)
- due dates and trust tiers from signed history
- an autonomous agent with a budget
- a dashboard and a "Try to break it" judge page

Entry: API3 track only.

**State of the repo:**

| Part | State |
|---|---|
| `SupplierPulse.sol` v1 | Sepolia `0x91d7…4d7`, 36/36 tests (per docs) |
| Live paid / held | order 0 paid `0x40d3…3f05`, order 1 held `0x5e6a…009b` |
| Tamper test | 4/4 rejected, but only in an `eth_call` simulation, with no tx sent |
| Cardano agent | registered on Masumi preprod. 5 paid jobs (payout, refund, "held but agent paid") |
| SupplierPulse+ code | none yet, spec only |

---

## 3. Customer diagnostic (six questions, short)

| Question | State | Note |
|---|---|---|
| Demand reality | Weak | "Small manufacturers" is a category, not a person. Nobody has said "I want this" yet. |
| Status quo | Not mentioned | Creditsafe, D&B and Companies House's free "follow" alerts already report liquidations. Judges will ask: "Why a contract and not an alert?" |
| Desperate specificity | Missing | It needs a concrete persona: a name, a company, the amount paid, the money lost. |
| Narrowest wedge | Good | "One supplier, one order, two stages" is v1 itself, and it exists. |
| Observation and surprise | Present | "The agent is paid even when it stops the payment" is a very good insight: it removes the incentive to approve. Lead the pitch with it. |
| Future fit | Good | "Any register on AirnodeHub can become a payment condition" is a strong bigger picture. |

**Suggested answer to the status quo:** *"An alert tells a person, who usually reads it after the payment went out. Here the register itself stops the money, stage by stage."* This could replace the spec's "Contrast" line, which never names the alternative.

**Suggested persona:** build the story around the part the SolidWorks model will show. For example: "A 12-person robot maker in Munich pays a UK motor supplier €30k in 3 instalments. Two weeks before instalment 2, the supplier enters liquidation." That gives the video a 10-second opening.

---

## 4. Premise challenge

Discuss these as a team and answer agree or disagree to each.

**Premise 1: "Dropping Cardano and entering only API3 is right."** I disagree.
- Cardano qualification is **done**: a real escrow payout `1929a3d1…`, a real refund `0fefbb1b…`, and the "supplier held, agent still paid" job `09fa4cf7…`. That is exactly the "payment tied to the result" the Cardano judges ask for.
- A team can enter up to 3 tracks. Cardano's pool is €6,000, API3's €2,000.
- **Cost:**
  - one video has to serve both tracks;
  - you present at two booths;
  - the Cardano judges want one paid job end to end in the video.
- **The one gap:** the SupplierPulse Cardano jobs ran with a **simulated EVM side** (`supplier-pulse-sim.json`). One Masumi job with the real `supplier-agent.sh` (about 1 hour) links the two tracks: *"The buyer hires the agent on Cardano. The agent fetches API3 evidence, then releases or holds the payment on Sepolia, and is paid for the decision itself."*
- Suggestion: keep Cardano at **minimal effort**. Write nothing new in `cardano-agent/`. Do only that one real job, and give it 15 seconds in the video.

**Premise 2: "Winning needs all of SupplierPulse+."** I partly agree.
- API3 scoring: real use case 40, signed data matters 30, execution 20, novelty 10, agent bonus +10.
- The three things that move the score most:
  - **multi-field Companies House rules** (real use case);
  - **repeated autonomous agent cycles** (the +10 bonus);
  - **a page where judges attack the contract themselves** (execution).
- GLEIF and trust tiers mostly earn novelty, which is the 10-point slice, and they carry high risk. The spec lists tiers as "never cut". I would put them on the cut list, just above GLEIF.

**Premise 3: "Five parallel workstreams don't block each other."** I disagree.
- The agent, the judge page and the dashboard all depend on the new contract's ABI. The ABI is called "frozen at C0", but the contract isn't written yet, so the ABI will very likely change while it is being written.
- If C2 integration (22:00) slips, the Sepolia launch (00:00) and the overnight agent run slip with it. The overnight run is exactly the "repeated cycles" evidence the agent bonus needs.
- Suggestion: run the agent loop **against the v1 contract tonight**, so the bonus evidence builds up independently of v2.

**Premise 4: "A simulated tamper test is enough."** Half true.
- The rules ask for a valid response that triggers the action, then four rejected responses. The simulation shows that.
- Still, a **real reverted transaction** (a red "Fail" on the explorer) is more convincing in the video, and it costs only a few cents of Sepolia gas.

---

## 5. Approaches

```
APPROACH A: "v1+" (minimal viable)
  Summary: add only multi-field Companies House rules to the v1 contract, and build an
           agent loop and a judge page on the v1 scripts. One real Cardano job.
  Effort:  S-M     Risk: Low
  Pros:    can be done tonight. Agent evidence builds up overnight. Two tracks.
  Cons:    no GLEIF, no tiers, a lower novelty score.
  Reuses:  SupplierPulse.sol, pulse-*.sh, supplier-agent.sh, ch-fetch.mjs, cardano-agent

APPROACH B: "Full SupplierPulse+ spec" (ideal architecture)
  Summary: everything in the spec: new contract, GLEIF, tiers, bitmask rules, due dates, two pages.
  Effort:  XL      Risk: High
  Pros:    the richest demo, the highest novelty score.
  Cons:    one night, five people, tight integration. One delay shifts the whole plan.

APPROACH C: "Incremental +" (recommended)
  Summary: build A first and freeze it at 22:00 in a submittable state. Then add spec parts
           in cut-list order: due dates, then tiers, then GLEIF.
  Effort:  M-L     Risk: Medium
  Pros:    a submittable version at the end of every hour. Tiers and GLEIF are pure upside.
  Cons:    some parts get touched twice (v1, then v2).
```

**Recommendation: C.** The goal is to win a hackathon. C leaves a showable version at the end of every hour and moves the riskiest parts to the end.

---

## 6. Success criteria and next steps

**Done means:**
1. the API3 tamper test is in the video, with real reverts;
2. a page or script lets judges submit their own responses;
3. a log of at least 6 overnight autonomous cycles, with a budget limit;
4. one paid Cardano job with the real EVM side;
5. an up-to-date README.

**In order:**
1. **(Tonight, decision)** Keep Cardano or not. A 10-minute team talk is enough.
2. **(Tonight)** Run the agent loop against v1. Julien's `cardano-agent` gate already retries until a deadline.
3. **(Tonight)** Run one Masumi job with the real `supplier-agent.sh` and add its tx hash to `evidence.md`.
4. **(Overnight)** Multi-field rules, then due dates, then tiers. GLEIF last.
5. **(Saturday morning)** Ulaş runs the project as a judge from a fresh clone (already planned as C4, which is good).

---

## 7. What judges will notice in the repo

- **A Sepolia payment went to an anvil test address.** The supplier wallet in `evidence.md`, `0x3C44CdDd…93BC`, is anvil's public account #2. The spec itself says never to use anvil addresses on Sepolia. The amount is trivial, but a careful API3 engineer will notice. Use a fresh address in v2.
- **The README is out of date.** It still describes the "ETH/USD vault + Cardano agent", and mentions neither SupplierPulse nor the contract address.
- **The "API3" table in `evidence.md` is empty.** The real evidence is in the "SupplierPulse live run" section below it, but judges see the empty table first. Fill it or remove it.
- **A local path leaks into the spec:** §10 names `~/tumblockchain/starters/...`.
- **Tests:** this review could not run them (no Foundry, and the `masumi` package isn't installed here). The counts (36/36, 16) come from the repo docs.

---

## 8. Open questions

- The spec names Emre as the fifth person. The data layer depends entirely on that workstream, with a first hand-off at 18:30. Does he have a working environment yet?
- The agent wallet needs at least 2 aUSD by C3 (Batu sends it). Whose checklist is this on?
- If Cardano is dropped, `cardano-agent/` stays in the repo. Judges may ask why it is there, so explain it in one README sentence.

## 9. Observations

- Julien's design "the agent is paid even when it holds the payment" (`09fa4cf7…`) is the most mature product decision in the project. Put it at the centre of the pitch.
- The team writes specs very fast. The risk is not the spec itself but turning it into an all-night commitment.
