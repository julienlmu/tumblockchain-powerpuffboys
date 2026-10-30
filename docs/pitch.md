# SupplierPulse+ pitch and judge Q&A

> **Readiness gate (30 October 2026, 17:02 CET):** This is the intended v2 pitch, not a claim that v2 is live. The current deployed and evidenced contract is v1, which checks Companies House status only. Use the v2 claims below only after the integration and its evidence are verified; otherwise describe the v1 demo and say v2 is still in development.

## 90-second pitch

Your supplier was approved last month. That should not approve today's payment.

Supplier payments are often split into advances and milestones. A buyer can approve a supplier at onboarding, then continue releasing instalments even if a public registry later records liquidation or a required filing becomes overdue.

SupplierPulse+ makes each milestone carry its own proof. Before a payment, an agent requests a fresh, signed Companies House or GLEIF record from API3 AirnodeHub. The buyer's Ethereum contract checks the Airnode signature, the exact supplier/request, the timestamp, and replay protection, then applies the buyer's rules. A clean record grants a permit for only the next milestone. The buyer still approves delivery. A failed registry rule holds the remaining balance for the buyer.

The agent also monitors between due dates. A supplier's shared verification history sets how often it is re-checked: trusted suppliers cost fewer paid monitoring checks, but tiers never extend permits or relax the evidence freshness limit. A failed base status resets the streak and stops older permits across that supplier's orders. Each data check costs one cent over x402 in aUSD on Base Sepolia; supplier orders and contract decisions are on Ethereum Sepolia.

This is not a credit score or a delivery oracle. A signed response proves what the registry returned, not that the supplier will deliver or remain healthy. We could not find German Handelsregister and insolvency-notice data in the AirnodeHub sources we checked. SupplierPulse+ demonstrates a narrower idea: make fresh public evidence part of the payment rule, not just a one-time onboarding document.

## Judge Q&A

### Why not query Companies House directly?

A direct unsigned response can be changed by the script or service that submits it. Here the contract verifies the expected Airnode's signature over the exact data and request, along with freshness and replay constraints. AirnodeHub is therefore a core input to the payment decision.

### What exactly does a signature establish?

It establishes that the configured Airnode signed these bytes for this request at this timestamp. It does not establish that the source is infallible, that a supplier will perform, or that the supplier's broader financial condition is sound.

For the threat model, describe an edited response or compromised/misconfigured signer as the risk. An attacker cannot make an arbitrary unsigned response pass the contract's signature check.

### Why does the buyer still approve a milestone?

Registry status cannot confirm that goods were delivered or accepted. SupplierPulse+ uses a dual condition: registry evidence plus buyer approval.

### Can an old clean response be reused?

No. The contract checks a maximum response age, rejects future timestamps outside its skew allowance, tracks used digests, and requires a newer response for an order. The evidence binds to the request hash for that supplier and source.

### Can a supplier farm a better trust tier with rapid checks?

Only newer verified base-status records count, at most once per configured tier gap. Buyer-specific filing rules do not affect the shared history. A failing base status resets the clean streak and blocks older permits across that supplier's orders. Tiers change only the agent's re-check interval; permits are never extended, and the freshness limit does not change.

### What happens if a field is missing or the API is unavailable?

The Airnode projection may return no signed answer when a requested field is missing. Without evidence, the contract cannot issue a permit. The agent reports the failure and retries according to its backoff policy. If the buyer approved the next milestone but there is still no valid permit after the due date plus the refund grace period, anyone can return the remaining balance to the buyer. A failed record can also be claimed by the buyer, with the agent able to trigger the refund after the grace period.

### What does the agent spend and how does it handle failures?

Each check is specified at $0.01. The agent has a daily budget, a per-tick fetch cap, and a reserve for due checks. It simulates writes before sending, backs off on transient/no-data errors, pauses paid fetches after payment failures, and quarantines an order if signer or request validation indicates a mismatch. Use the measured `docs/agent.md` and overnight log for exact run results; do not claim cycles or totals that have not been recorded.

### Why two chains?

The payment-per-data request uses aUSD on Base Sepolia through x402. The escrow-like milestone contract is on Ethereum Sepolia. This is a prototype split between the API3 data-payment path and EVM order settlement; it is not a trustless cross-chain bridge.

### Why not describe this as the first registry-gated payment product?

We do not claim “first.” Existing supplier-risk platforms monitor financial and operational signals, generic smart-contract escrow is established, and API3 documents signed API data for contracts. Our claim is limited to this prototype's mechanism: fresh signed registry evidence, buyer-approved milestone permits, trust tiers, and an agent with a spending policy.

### What data is not covered?

We did not find German Handelsregister and German insolvency notices among the AirnodeHub sources checked. GLEIF only covers entities with an LEI. The prototype also does not model delivery confirmations, exchange/credit data, or every jurisdiction.

### Where can we verify the contract and tamper cases?

Use the v2 address and transaction links in [`docs/evidence.md`](evidence.md) once deployment is complete. The judge page and `api3/scripts/plus-submit.sh` are intended for independent submissions; the testnet contract must first accept a valid fresh response before the edited-value, stale, different-request, and wrong-key attempts are demonstrated.

## Claims to keep bounded

- Say **“registry evidence”**, not “financial health score” or “insolvency prediction.”
- Say the contract can **hold the next unpaid balance after it receives a failed fresh record**; do not imply it can claw back an already released milestone.
- A signature proves the Airnode signed the response; it does not prove the registry's underlying data is complete or that delivery happened.
- Attribute the £148 million Carillion figure to the NAO's estimate of taxpayer cost, not private supplier losses.
- State the LEI 37.8% figure only with its precise denominator: the queried `LAPSED` and `ISSUED` records in the 30 October 2026 GLEIF API snapshot.
