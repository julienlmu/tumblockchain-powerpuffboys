# SupplierPulse — Time-Bound Payment Permits (API3-focused MVP)

> Status: ideas for the next iteration. Not built yet. The current contract and scripts are described in [SUPPLIERPULSE.md](SUPPLIERPULSE.md).

**Tagline:** "Just because your supplier was approved last month doesn't mean today's payment should be approved automatically."

## 1. Problem and value

Companies usually check a supplier once, when the contract starts. After that they keep paying installments, advances or subscriptions for months. In that time the supplier's legal or registry status can change.

SupplierPulse issues time-bound payment permits. Every payment milestone needs fresh, signed registry proof through API3. If the conditions have changed, the outgoing payment stops and the remaining balance stays secured.

## 2. Demo scenario (3,000 test tokens)

A robot manufacturer pays a motor supplier 3,000 tokens over 3 milestones.

| Milestone | Amount | Required condition (dual lock) | Demo outcome |
|---|---|---|---|
| 1. Order advance | 500 | Fresh API3 registry proof + buyer order approval | Paid |
| 2. Second payment | 1,000 | Fresh API3 registry proof + buyer milestone approval | Blocked (registry status invalid) |
| 3. Final payment | 1,500 | Fresh API3 registry proof + delivery acceptance | Locked (2,500 secured) |

## 3. Smart contract: time-bound payment permit

Each permit stored in the contract fixes these parameters:

| Field | Meaning |
|---|---|
| `companyId` | Supplier company (Companies House registry number) |
| `orderId` | Purchase order or invoice |
| `recipient` | Wallet that receives the payout |
| `maxAmount` | Maximum payout allowed by this permit |
| `milestoneId` | Payment stage |
| `expiresAt` | Expiry timestamp |
| `api3Signature` | Signed API3 registry proof behind the permit |

## 4. Demo features

### A. "Secured remaining balance" dashboard

The user sees how the unspent funds are protected, not just a green "active" badge:

| | |
|---|---|
| Order | Industrial motor supply |
| Paid | 500 tokens |
| Secured remaining balance | 2,500 tokens |
| Payment permit | Expired |
| Last check | API3 registry condition failed (company status invalid) |
| Next action | Buyer review / refund |

### B. "Try to hack the system" simulator (4 tamper tests)

Four red buttons in the UI let the judges attack the contract themselves:

| Button | Attack | Expected rejection |
|---|---|---|
| Reuse expired approval | Use the milestone 1 proof for milestone 2 | `PermitExpired` |
| Send fake signature | Submit data without a valid Airnode signature | `InvalidSignature` |
| Use another company's registry | Submit an active record of an unrelated company | `CompanyMismatch` |
| Tamper with amount | Withdraw 2,500 instead of the permitted 1,000 | `AmountExceedsPermit` |

### C. Dual lock and 3D model

- A payout needs a legal lock (API3 registry proof) and a physical lock (buyer approval).
- The UI shows a 3D model of the motor part, made in SolidWorks. At milestone 1 the first part turns green. At milestone 2, when the registry check fails, a red lock appears over the model.

### D. Auto-refund countdown

When the supplier fails the registry check, the order is held and the buyer can claim the remaining balance immediately. The buyer can also cancel an active order before approving its next milestone. Separately, after the 48-hour approval grace, anyone can trigger a refund if the approved next milestone has no current valid permit; the refund always returns funds to the buyer. A still-valid permit blocks this no-data exit.

## 5. MVP scope

- **Data source:** one registry (Companies House through API3).
- **Architecture:** EVM escrow contract, a background scheduler agent (Node.js or Python), and a React/Next.js dashboard.
- **Out of scope:** cross-chain bridging, credit scoring, multiple registries.

## 6. Gap to the current build

| Spec | Current contract (`api3/src/SupplierPulse.sol`) |
|---|---|
| `InvalidSignature` | `WrongSigner` |
| `CompanyMismatch` | `WrongRequest` (the request hash includes the company number) |
| `PermitExpired` | `PermitExpired` (already there) |
| `AmountExceedsPermit` | Not needed today: amounts are fixed per milestone at order creation. Would need a free-amount `release`. |
| `recipient`, `maxAmount` in the permit | Supplier and amounts live on the order, not the permit |
| Active-order recovery | Buyer may cancel before approving the next milestone. After the 48-hour approval grace, anyone may trigger a refund if an approved milestone has no current valid permit; `noDataRefundAt` exposes the no-data refund time |
