# API3-only review and product directions

Research date: 30 October 2026 (Europe/Berlin). Prepared by Codex at Orhun's request.

**Status: analysis and recommendations for discussion.** This review does not change the team's scope, ownership, frozen interfaces, or implementation plan. The current chat asks about moving to API3 only; `SUPPLIERPULSE_PLUS.md` already describes that scope as decided. Confirm the team's shared status rather than treating this review as a new decision.

## Recommendation

Continue SupplierPulse. Its strongest API3 story is **a payment authorization that is bound to a particular signed registry record, expires, and is checked by the contract before funds move**. Prioritize the autonomous payment calendar, explicit evidence-to-payment receipts, judge tooling, and an exit path when data cannot be obtained.

The most useful new mechanisms are shared supplier evidence with revocation of affected permits, and a scheduler that prioritizes payments and amounts at risk. Repeated clean registry checks should be called verification history rather than a credit or reliability score. Do not extend the hard payment evidence window solely because a supplier has been checked many times.

A complete pivot to another product has a higher delivery risk now that SupplierPulse has live evidence and passing tests. PatchGuard and InvoiceGuard remain credible alternatives; neither requires Cardano.

## 1. Repository snapshot and independently checked evidence

| Ref | Head inspected | What exists |
|---|---|---|
| `main` | `68762a5` | Price vault and Cardano pay-on-pass implementation; main is behind the supplier branches |
| `supplier-pulse` | `56530d5` | SupplierPulse v1 contract, 19 tests, x402 fetch, scripts, deployment and paid/held evidence |
| `supplierpulse-plus` | `864fe18` | v1 plus a detailed API3-only v2 build specification; no SupplierPulsePlus implementation in this snapshot |
| `batu/demo-screen` | `a812789` | v1 static order dashboard |
| `batu/api3-setup` | `4ee7772` | Decision sheet, upgrade analysis, real one-field Companies House samples |
| `brainstorm/mining-payout-settlement` | `a981c81` | Exploratory mining settlement document |

SupplierPulse is already in GitHub. Its first plan is attributed to Orhun in `08408f4`, contract/tests in `9bef289`, and further on-chain company binding/scripts in `f611aa5`. Julien added the Cardano application and the SupplierPulse+ specification. The name and expanded permit proposal originated in the earlier Orhun/Codex discussion; Git commit authorship establishes who committed a file, not necessarily who pushed it or conceived every part.

Checks run from an isolated copy of `864fe18`:

- `forge test --root api3 --offline`: **36 passed**, comprising 19 SupplierPulse tests and 17 price-vault tests.
- SupplierPulse v1 code exists at `0x91d7dbae109029b2b1245179a68ac362799674d7` on Ethereum Sepolia.
- Public RPC receipt of `0x40d395d728f5700756fd55117ef59fd501dca3a86cbb161f30d2a20b80d13f05` has status `0x1` and that destination.
- `orderStatus(1)` returned Held, zero paid, 2,000,000,000,000 wei remaining, and `liquidation`.
- The Companies House and GLEIF request-hash vectors in the v2 specification reproduced with `cast keccak`.

These checks confirm the inspected v1 behavior, not a full audit or a functioning v2 deployment. No paid API calls, wallet signing, deployment or value transfers were performed for this review. The original working checkout was left untouched.

## 2. Why API3-only is coherent

The application funds already live on an EVM chain. API3 authenticates the input that permits a payout or holds it. Cardano is not required for that feature. Removing the Cardano service-payment layer reduces the number of runtime components in the product demo.

Two networks can still appear: Ethereum Sepolia for the application and Base Sepolia for API3 x402 data access. That does not require a cross-chain funds bridge. Application gas and data-access aUSD balances are separate budgets.

The official challenge scores real use case 40, signed data 30, execution 20, novelty 10, plus up to 10 for an autonomous workflow. A useful deterministic scheduler can demonstrate that workflow; adding an LLM is not a substitute for repeated autonomous decisions, spending limits and failure handling.

First customer hypothesis: a crypto-native company or DAO paying registered legal vendors from an on-chain treasury. Traditional manufacturers may need bank/ERP integrations and crypto custody changes; those integrations do not exist in this MVP. Demand has not been validated by customer interviews.

## 3. Data research that changes the plan

### Companies House

AirnodeHub serves `getCompanyProfile`, currently listed at **0.01 test aUSD per call**. The repository contains real signed `active` and `liquidation` one-field responses. The four-field request in the v2 specification still needs live verification for the selected companies.

The official current Companies House resource schema says:

- `accounts.overdue` is deprecated; it points consumers to `accounts.next_accounts.overdue`.
- `has_insolvency_history` is deprecated; it points consumers to `links.insolvency`.
- Many nested fields, including the newer overdue field and the confirmation-statement overdue flag, are optional.

Deprecated does not mean that a field is absent today. Schema existence also does not establish that every selected company returns it. An Airnode projection fails when a requested pointer is missing; a disabled rule does not prevent that failure if its optional field is still included in the fixed request.

Do not interpret `links.insolvency` as a boolean declaration of current insolvency. An absent optional link is not authenticated proof of a clean history. If richer fields are unreliable, retain the verified status-only request and show NoData/Unsupported for the extra policy. Changing projection paths changes requestHash, requiring a coordinated interface change with Emre and Orhun.

An overdue filing is a specific administrative condition, not a validated prediction of bankruptcy. Historic insolvency, present legal status and creditworthiness are different concepts. The buyer should understand exactly which policy they selected.

### GLEIF

The AirnodeHub listing offers exact-LEI lookup, entity status and registration status at 0.01 test aUSD. GLEIF explicitly explains that **LAPSED does not mean the entity is inactive**; it means renewal/reverification was not completed in the planned interval.

A buyer may choose an ISSUED-only policy, but the screen should say “LEI renewal condition not met,” not “supplier bankrupt.” Entity status and LEI registration status need separate labels.

Supporting Companies House orders and GLEIF orders is not the same as corroborating one company with two independent sources. Cross-register identity matching is a separate problem. Both listings also use operator-run Airnodes, rather than independent first-party provider signatures.

### Missing data and source time

A fresh Airnode signature says when a response was served; it does not establish that the register itself just discovered or published the underlying fact. The system cannot detect a real-world change before the chosen source reflects it.

Use distinct outcomes: verified eligible, verified policy failure, and data unavailable. Missing information must not silently become `false`, eligible, or an authenticated negative fact. Explain the timeout/cancellation route to users.

## 4. Four observed v1 behaviors

The supplemental reproducer is `docs/reviews/SupplierPulseScenarios.t.sol`. Copy it to `api3/test/ReviewScenarios.t.sol`, run `forge test --root api3 --offline --match-test test_review -vv`, then remove the copied test. All four checks passed in the isolated review. A passing reproducer means the behavior was observed; it is not a certificate that the behavior is safe for every product promise.

| Observation | Evidence | Interpretation |
|---|---|---|
| One signed response cannot serve two orders | Global `usedDigests` rejects the second use | Data-reuse/scalability limitation; replay protection can instead guard the business action |
| New liquidation evidence on order B does not revoke order A's earlier permit for the same company | A still paid 0.5 test ETH in a local scenario | Current protection is order-specific; avoid claiming supplier-wide revocation |
| A permit can be used after response `maxAge` has elapsed | Valid one-day permit still pays after 301 seconds | Policy choice: submission freshness and payment freshness are distinct |
| Buyer cannot timeout-refund an Active order | `refundRemaining` still reverts NotHeld after 365 simulated days | Liveness risk if source data stays unavailable; a no-data exit needs explicit terms |

The second and fourth observations are especially relevant to the next design. No change to deployed v1 is proposed here; preserve it as a fallback.

## 5. SupplierPulse+ specification: changes worth discussing before implementation

### A. Verification history is not counterparty trust

A supplier staying `active` for six queries does not prove delivery reliability, solvency, or repayment capacity. A five-minute gap slows rapid tier farming but does not make the evidence richer. A clean streak can be accumulated with inexpensive small orders over time.

The written v2 design also shares a supplier record across orders while computing `clean` using each order's enabled rules. A record can pass a lenient order and fail a stricter one. Counting those as one global reliability history mixes policy standards.

If tiers remain, call them verification-history tiers, label their limited meaning, and avoid letting them expand the hard evidence-age limit for payments. Longer monitoring intervals are an explicit buyer risk preference, not a safety conclusion from repeated signatures.

### B. Supplier-wide freshness and revocation

The specification checks `timestamp > order.lastCheck`, then overwrites shared `supplierRecord.lastCheckAt`. It does not specify a supplier-wide monotonicity check. Older unused evidence on a different order can therefore move the shared record backwards under the described rules. This is a specification finding; no v2 implementation was present to execute it against.

A newer negative record resets a tier but only holds the order receiving it. Other orders can retain permits. A tier downgrade also does not necessarily shorten permits already issued.

If the product promises a supplier-wide stop, use latest authenticated supplier facts plus a version/epoch checked at payment time. Evaluate each buyer's rules against those facts. A policy failure such as overdue accounts should not automatically invalidate an order whose buyer did not enable that rule.

### C. No-data exit is different from held-order refund

The planned grace-period refund still requires Held. An outage does not create a signed negative record, so an Active order may never enter Held. Add a pre-agreed evidence deadline and an explicit fallback/cancellation route, preserving the parties' already-earned obligations. Do not call a countdown an automatic refund unless a transaction actually executes it.

### D. Required tamper cases need real semantic inputs

The current scripts and planned v2 tools subtract from a signed timestamp for stale mode and replace requestHash for different-request mode. Those are useful mutation tests, but also demonstrate an untouched truly expired signed response and an untouched signed response for another company. Verify the contract receives and rejects them for the intended reason. Start with a fresh valid response producing the intended action.

## 6. Product directions, ranked for this team

### 1. SupplierPulse: proof attached to every payment (recommended base)

Buyer locks a bounded milestone order. An agent fetches evidence shortly before due payments. The contract enforces the buyer's explicit policy and records which signed response justified each payment. The buyer sees paid, held, and unavailable-data outcomes with exact reasons.

Differentiator: independently reproducible evidence and enforcement on application funds. Preserve the current contract concept, add the payment calendar, an evidence viewer/judge kit, and the no-data exit. Existing code and real source samples make this the lowest-risk useful direction.

Demo: one active vendor is paid, one liquidation record holds an order, the judge edits the record and gets rejected, and the autonomous log shows a second cycle plus its aUSD payment.

### 2. Shared evidence and affected-permit revocation (strongest mechanism extension)

Authenticate a supplier record once per freshness window. Several orders reference it, while their recipient, amount, milestone and policy remain separate. Newer authenticated facts supersede older facts. At release, the order evaluates its own policy against the latest applicable facts; affected old permits cannot authorize a payment after a newer disqualifying fact.

Replay protection belongs to `(order, milestone)` or a scoped permit, while supplier evidence is monotonic and deliberately reusable. Avoid scanning all orders in one transaction; each release can check the latest supplier version.

Hypothetical data-cost example at the listed test price: ten orders for the same supplier in the same window need ten 0.01-aUSD fetches without reuse (0.10 aUSD), versus one (0.01 aUSD). This excludes application gas and is not a guaranteed production saving.

Demo: two orders share one clean fact; a newer negative fact blocks the affected next payment on both; an old clean fact cannot roll back the supplier snapshot. This extension requires a deliberate interface review rather than an unannounced patch to the frozen spec.

### 3. Agent scheduled by money at risk (best small extension)

Prioritize suppliers with an approved payment approaching its due time and a large amount requiring fresh evidence. Reserve data budget for those checks. Monitoring other suppliers is lower priority. Do not buy a new record while a valid policy-compliant one already covers the action, or repeatedly poll while waiting for buyer approval.

The dashboard shows “these next payments lack current evidence,” the next planned check, the budget remaining, and the last action. This is a practical autonomous decision policy rather than an unvalidated trust score. Estimates of exposure mean the amount governed by a potentially stale authorization, not predicted losses.

A pure planner can be tested using synthetic time and balances, while the live demo shows two successive scheduled actions and bounded x402 spending. Fetch-cost and application-gas budgets should both be bounded and persisted across process restarts.

### 4. PatchGuard: vulnerability-triggered agent spending control (full-pivot alternative)

The owner registers exact software versions/CPEs. A signed NVD query with fixed product and risk filters drives a limited agent-spending quarantine. A zero result never proves software safe; installed-version truth is supplied separately. Reopening needs an explicit owner or patch-verification policy.

NVD operations and filters exist, but this team has not established a live paid signed fixture for the intended query in this review. Start with one CPE and one positive known-exploited query. The proof controls spending authority; it does not patch software or assert complete protection.

More mechanism novelty than another price vault, but loses the existing registry implementation and customer demo work. Choose only if the team deliberately pivots.

### 5. InvoiceGuard: fiat-denominated invoices with bounded crypto payment (fallback alternative)

An invoice fixes EUR amount, recipient, due time and maximum token spend. Signed EUR/USD and token/USD observations determine the permitted token amount. Each invoice is paid once. The current price-verifier and native-ETH vault can be reused, with precise fixed-point conversion and observation-time checks.

Example formula: ETH owed = EUR invoice amount × EUR/USD ÷ ETH/USD. This does not create liquidity or protect the recipient from later ETH volatility. Easy positive live demo without waiting for a market threshold, but less distinctive than the shared-evidence mechanism.

## 7. Prior art and defensible positioning

| Existing capability | Primary source | Implication |
|---|---|---|
| Ongoing business-registration/bankruptcy monitoring and webhooks | Middesk documentation | Monitoring a company's status is an established product category |
| Configurable KYB monitoring | Trulioo developer documentation | Continuous business checking alone is not a global novelty claim |
| Payment blocking for suppliers | SAP documentation | Holding a vendor payment is also established |
| Scheduled/cancellable on-chain token distribution | Sablier documentation | Time-based payments and remaining-balance refunds are established components |

A defensible claim is: **SupplierPulse binds each on-chain vendor payment to authenticated registry evidence and a precommitted buyer policy, with an inspectable record of the decision.** The shared-evidence/revocation extension is a proposed mechanism improvement, not a claim of global first invention. A blockchain is useful here when the customer already wants shared on-chain fund enforcement; for an ordinary bank-only workflow, existing ERP/KYB integrations may be the easier product.

## 8. Scope and execution recommendation

Keep: deployed v1 fallback; one verified registry request; due-time checks; meaningful payment and hold actions; replay protection per action; the official four tamper cases; a budgeted autonomous loop; a readable payment/evidence trail; setup instructions and video.

Prioritize before adding another registry: no-data exit, accurate age-at-payment semantics, genuine stale/different-company evidence, and clarity about order-specific versus supplier-wide holds.

Cut first if delivery slips: trust-tier claims/multipliers, extra policy flags without real fixtures, a second registry, 3D polish, and discretionary frontend features. A second registry is useful coverage, not automatically stronger verification of the same entity. A 3D model may illustrate the order but cannot prove delivery.

Five-person responsibilities already proposed in the current spec fit API3-only: Orhun contracts; Emre data and judge CLI; Julien autonomous agent; Batu dashboard; Ulaş source-backed story, README and demo. These are repository assignments, not new assignments made by this review.

Use the team's existing checkpoint plan, with a hard integration check before midnight, feature freeze Saturday morning, video by 13:00, and submission by 14:30 before the official 15:00 deadline. If the larger extension threatens integration, ship the verified base plus the scheduler and explain the extension as future work. No scoring outcome or win probability is promised.

## Sources (accessed 30 October 2026)

- [API3 challenge and judging](https://api3dao.github.io/airnodehub-hackathon/docs/)
- [Projection rules](https://api3dao.github.io/airnodehub-hackathon/docs/projections)
- [Attestation scheme](https://airnodehub-docs.api3.org/airnode/attestation)
- [Event schedule](https://hackathon.tum-blockchain.com/schedule)
- [Companies House listing](https://airnodehub.api3.org/explore/companies-house)
- [Official companyProfile schema](https://developer-specs.company-information.service.gov.uk/companies-house-public-data-api/resources/companyprofile?v=latest)
- [GLEIF listing](https://airnodehub.api3.org/explore/gleif)
- [GLEIF explanation of LAPSED](https://www.gleif.org/en/lei-data/lei-search/about-lei-search/how-to-use-lei-search)
- [NVD listing](https://airnodehub.api3.org/explore/nvd)
- [Nodary listing](https://airnodehub.api3.org/explore/nodary)
- [Middesk monitoring](https://docs.middesk.com/reference/monitor)
- [Trulioo KYB monitoring](https://developer.trulioo.com/reference/business-kyb-monitoring)
- [SAP supplier payment blocks](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/3cb1182b4a184bdd93f8d62e3f1f0741/1be9d353ca9f4408e10000000a174cb4.html)
- [Sablier distribution FAQ](https://docs.sablier.com/support/faq)
- Repository refs listed in section 1, especially `api3/src/SupplierPulse.sol`, `docs/evidence.md`, `docs/SUPPLIERPULSE_PLUS.md`, and Batu's `docs/supplierpulse-upgrades.md`.
