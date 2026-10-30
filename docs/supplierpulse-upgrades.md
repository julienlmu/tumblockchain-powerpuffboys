# SupplierPulse: how to make it stronger

Author: Batu (role E), 30 Oct ~14:10. These are proposals for Orhun, Julien and Ulaş. Nothing here is decided or built.
Base: `docs/SUPPLIERPULSE.md` and `api3/src/SupplierPulse.sol` on branch `supplier-pulse`, plus the review in `docs/decision-sheet.md`.

Legend: **[F]** = checked today, with a source. **[I]** = judgement, not verified.

## The one-sentence pitch

> Every supplier payment carries its own proof: a fresh, signed register record that the contract checked before the money moved.

The strongest angle we are not using yet is **auditability** [I]:
- Today a company cannot prove to its auditor that someone re-checked the supplier before a transfer.
- With SupplierPulse, every `MilestonePaid` event already carries the `evidence` digest of the signed record it was based on [F: `SupplierPulse.sol`, event `MilestonePaid(..., bytes32 evidence)`].
- That gives a payment-by-payment audit trail for free. Say it in the pitch.

## Upgrades, by value for the judges

| # | Upgrade | Helps | Effort [I] | Owner (suggested) |
|---|---|---|---|---|
| 1 | Cardano executor "paid for a correct decision" | Cardano: payment tied to result | small | Julien + Orhun |
| 2 | Agent loop over a payment calendar | API3 agent bonus (+10), Cardano "acts in the real world" | small–medium | Orhun |
| 3 | Company number on-chain, request hash built in the contract | API3 signed data (30%), tamper (c) clarity | small | Orhun |
| 4 | Richer rule from the same $0.01 call (insolvency history, overdue accounts) | API3 real use case (40%), novelty | small, but needs one check first | Orhun, Batu verifies |
| 5 | "Protected remaining balance" screen | demo, UX | small | Batu + agent |
| 6 | Supplier wallet sanctions screening (PublicAML) | real-world compliance | medium, risky | v2, not for the demo |

### 1. Cardano: paid for a correct decision, refunded when there is no evidence

**Update 14:15: already built by Julien** (`dd4bc16` on `supplier-pulse`, 14:04).
- New files: `apps/supplier-pulse.json` and `executors/supplier_pulse.py`.
- `Paid`, `AwaitingApproval` and `Held` pay the agent. `NoData` retries until the deadline; `Rejected` is final. Both of those refund the buyer.
- Tested on preprod with a **simulated** EVM side (`docs/evidence.md`, on that branch):
  - job `09fa4cf7…`: held, agent paid
  - job `79293455…`: no data, 5 tADA refunded
- Still missing: the real script `api3/scripts/supplier-agent.sh` (Orhun) and the Sepolia deployment.

The original proposal follows.

- `cardano-agent/` already runs any executor that prints `{"passed": …}` [F: `cardano-agent/README.md`, "Executor contract"].
- New app `apps/supplier-pulse.json` + `executors/supplier_pulse.py`:
  - **`passed: true`** when the contract call `checkAndRelease` succeeded with `Paid`, `AwaitingApproval` **or `Held`**. Blocking a payment to a company in liquidation is a correct, verified decision, so the agent earns its fee.
  - **`passed: false`** when there is no verifiable evidence: AirnodeHub down, HTTP 400, or verification reverted. Then the buyer is refunded automatically (already proven on preprod [F: `docs/evidence.md`, job `a81464d0…`]).
  - `retryable: true` while the API is unreachable and the deadline allows (the gate already supports it).
- Why it matters: Cardano judges ask for "payment tied to the result" and "escrow, refunds, pay only for work that passed a check" [F: CLAUDE.md §2]. This is it, with a reason the agent cannot game: it gets paid whether it says "pay" or "hold", but only with proof.

### 2. Agent loop over a payment calendar

- The agent keeps a small schedule: order, stage, due time.
- Shortly before a stage is due, and only then, it fetches a fresh profile, pays x402, submits, and reports.
- For the demo, set stages a few minutes apart, with `permitTtl` also in minutes.
- This matches the API3 bonus wording: "runs the core workflow over time … pays through x402 when required … acts on-chain without a person starting every cycle" [F: API3 docs page].
- It also answers Julien's note that the gate can retry until a deadline [F: PROGRESS, Julien "first paid job"].

### 3. Company number on-chain

- Store `company_number` in the order and build `keccak256('["getCompanyProfile",[["company_number","<n>"]],[["status","/company_status"]]]')` in the contract.
- The hash format is confirmed by three real responses [F: `docs/samples/companies-house/`].
- Then a judge can read *which company* an order is bound to, and the "different request" rejection is easy to explain.
- Also fixes the `companyNumber` vs `company_number` trap from the review.

### 4. Richer rule in the same call

- `getCompanyProfile` also returns these, among others [F: Companies House Airnode OpenAPI, `x-airnode-returns`]:
  - `has_insolvency_history` (boolean)
  - `company_status_detail` (string)
  - `accounts` (object, with what is due next and whether it is overdue)
  - `registered_office_is_in_dispute` (boolean)
- A projection with up to 20 fields costs the same $0.01 [F: projection allows `maxProperties` 20].
- Proposed rule [I]:
  - pay only if `status == "active"` **and** `has_insolvency_history == false`
  - treat overdue accounts as a warning in the report, not a hold
- **Risk:** "A pointer the response does not have is a 400" [F: OpenAPI]. If a field is missing for some companies, the call fails and the order gets "no data".
  - Before building this, Batu fetches one profile per test company with the extra fields ($0.01 each, needs Batu's OK) and checks they are always present.

### 5. Demo screen

- One page reading `orderStatus(orderId)`: paid, remaining, permit valid until, last status, last check time [F: the view exists in the contract].
- The "protected remaining balance" text from `docs/SUPPLIERPULSE.md` §5.
- Show two orders side by side: active (paid) and liquidation (held).

### 6. Later: is the payout wallet itself clean?

- PublicAML on AirnodeHub screens wallets for sanctions exposure, signed by its own Airnode `0xD4F35a6F7bdbB581f714A2d4F812C8334148c47d`, $0.01 per call [F: catalogue].
- Not for the demo [I]:
  - The listing itself says "unknown, unscored or partial results are not clean" [F]. Fresh testnet wallets are likely unscored, so every demo payment would hold.
  - It is also a second Airnode and signer, which means more contract code.
- Good for the "real use" paragraph: company check plus wallet check.

## Questions judges will likely ask (with short answers)

1. **"Why not just call the Companies House API?"** An unsigned answer can be edited by whoever runs the payment script. Here the contract only accepts the Airnode's signature for exactly this company, fresh, once. And the payment records which evidence it used.
2. **"Who pays, and why on Cardano?"**
   - The buyer pays per check, through Masumi escrow.
   - The agent is paid only when the check produced verifiable evidence; otherwise the buyer gets a refund automatically.
3. **"Isn't the agent a trusted bridge?"** Yes, between Cardano and the EVM contract. We say so. Both sides are on public explorers, and the payment decision itself is made by the contract, not the agent.
4. **"Does `active` mean the supplier will deliver?"** No. It means the register says the company exists and is not being wound up. The buyer still approves each stage (delivery accepted).
5. **"Why only UK?"** It is the register AirnodeHub serves. The German Handelsregister and insolvency notices are not on AirnodeHub [F: catalogue search]. That is our "data we wanted" answer.
6. **"What stops the agent from waiting for a good moment?"**
   - `maxAge` keeps the evidence window short.
   - Only newer evidence is accepted.
   - The permit expires and is used up by one payment.

## Suggested order before feature freeze (Sat 11:00)

1. Fri evening: #1 (Cardano executor) and #3 (company number on-chain). Deploy SupplierPulse, then one real paid Cardano job with the SupplierPulse app → `docs/evidence.md`.
2. Fri night: #2 (agent loop), judge script for the tamper test.
3. Sat morning: #5 (demo screen), #4 only if the field check passes, then record the video (target 13:00).
