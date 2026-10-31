# SupplierPulse+ FAQ: trust and exception handling

## What happens in each scenario?

| Scenario | What the service should do | Trust signal |
|---|---|---|
| Fresh signed evidence passes the buyer's rules | Pay only the approved, due milestone amount. Show the registry, fields checked, evidence time, and transaction. | Every payment has its own verifiable basis; approval does not exceed the agreed stage. |
| Buyer has not approved the milestone | Do not pay, even if the registry check passes. | Registry status is not treated as proof of delivery or buyer acceptance. |
| Fresh signed evidence fails a configured rule | Hold the order; explain exactly which rule failed. Let the buyer claim the remaining escrow immediately. Do not label the supplier fraudulent. | A rule-based hold is visible and actionable without making claims beyond the evidence. |
| A valid record is challenged as wrong or misleading | Freeze any unpaid milestone. Mark the case **“contested—not a finding of fault.”** Under the agreed policy, let the buyer trigger an immediate refund of the remaining escrow and close the order. | The agent and contract do not pretend to decide who is legally right. The refund is an agreed exit, not a judgment against the supplier. |
| Signature, supplier, request, timestamp, or replay check fails | Reject that record and do not pay against it. Log the rejection reason and seek fresh evidence. A bad submission alone should not automatically move funds. | Invalid evidence cannot force a refund; rejection is not evidence that the supplier failed. |
| Registry/API data is unavailable or incomplete | Report **“no verified data,”** not “supplier failed.” Do not pay without a valid permit. Retry within the spending policy; if data remains unavailable through the agreed grace period, refund the remaining escrow. | Separates a service/data outage from an adverse supplier finding. |
| Evidence is later corrected or contradicted | Preserve the original record in the audit trail. Require new, valid evidence for any future order; do not silently rewrite history or reopen a refunded order. | Customers can see what the contract knew at the time and what changed later. |
| Permit expires before payment | Do not release funds on the expired permit. Require fresh evidence and buyer approval; use the no-data exit if evidence does not arrive within the agreed period. | Old approval cannot quietly authorize a later payment. |
| Supplier status fails on another order | Stop unpaid milestones for that supplier when the new signed failure applies; show the source and time. Let each buyer decide what to do with their remaining escrow under the agreed terms. | A verified failure is acted on consistently, while each buyer retains control of their own order. |
| Delivery or contract performance is disputed | Do not claim the registry resolves the dispute. Keep payment subject to buyer milestone approval; handle any disagreement under the buyer-supplier agreement. | SupplierPulse checks configured registry conditions; it does not pretend to verify physical delivery or decide legal disputes. |
| Agent, Cardano job, or network fails | Do not report a successful check or payment without proof. Keep funds in escrow, show the error, and follow the no-data policy if it persists. | No success-shaped fallback: every claimed result is backed by evidence or a transaction. |

## Important limits

- **A refund means the remaining escrow goes back to the buyer.** It cannot reverse milestones already paid.
- A refund does not establish that the supplier did anything wrong or resolve a dispute over goods already delivered.
- “Contested = immediate refund” is a proposed policy. The current contract supports an immediate buyer refund after a valid adverse record puts an order on hold, but it does not provide a general immediate refund for a contested record while an order is active. Invalid evidence is rejected, and the active-order no-data path has a grace period.
- SupplierPulse checks configured registry conditions. A signed registry response proves what the source returned, not that the data is complete, current in the real world, or proof of delivery or future performance.

For the proposed supplier-wallet binding and its trust boundary, see [Wallet verification](./WALLET-VERIFICATION.md).
