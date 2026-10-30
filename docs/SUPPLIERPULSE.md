# SupplierPulse: payment permits that expire

> "Your supplier was approved last month. That should not automatically approve today's payment."

Status: plan, agreed by Orhun on 2026-10-30. This is the API3 idea (#3 in `docs/decision-sheet.md`) extended from a one-time supplier check to recurring payments. The deployed ETH vault (`api3/`, Ethereum Sepolia `0xBC68DB972A62cFf3161e600d92C475c29c22886A`) stays as the fallback.

## 1. Problem

A company checks a supplier once, at onboarding. After that, advances, instalments or subscription payments run for months. Meanwhile the supplier's registry status can change: dissolved, in liquidation, struck off. Nobody re-checks before the next payment.

SupplierPulse creates a payment permit that needs **current** registry evidence for **every** payment stage.

Target customer: small manufacturers and procurement teams that pay several suppliers on a schedule.

## 2. Example

A robot maker pays a motor supplier 3,000 test tokens in total.

| Stage | Amount | Condition |
|---|---|---|
| Order advance | 500 | fresh registry check + buyer approves the order |
| Second payment | 1,000 | new registry check + buyer approves the stage |
| Final payment | 1,500 | new registry check + buyer accepts delivery |

1. The first check passes, and 500 is paid.
2. When the second payment is due, the signed registry data shows the company no longer meets the condition.
3. The remaining 2,500 stays locked in the contract. The buyer reviews and can take it back through the predefined refund path.

Registry evidence does not prove delivery. Delivery acceptance is a separate condition, set by the buyer.

## 3. Core mechanism: a permit with an expiry

The contract stores a permit that covers:
- which company (the AirnodeHub request hash of that company's profile)
- which order or invoice
- which supplier wallet
- the maximum amount
- which stage
- valid until when
- which signed registry response it is based on

Because of this:
- an old approval cannot be moved to a new invoice
- another company's valid record cannot be used
- the agent cannot change the payout address
- the same stage cannot be paid twice
- an expired permit needs new evidence

The user sees exactly what they allowed, and for how long.

## 4. What the agent does

The agent follows upcoming payment dates:
1. Finds orders with a payment coming up.
2. Checks whether the current permit is still valid.
3. If not, fetches new signed registry data through API3 (AirnodeHub).
4. Submits the evidence to the contract.
5. The contract applies the payment rules.
6. The agent reports the result to the user: **paid**, **held** or **no data**, with the transaction as proof.

Data is fetched only when a payment needs it, not for every company every second.

**Product decision:** the agent's job is to run the right check and apply the decision. Stopping a payment because the supplier failed the check is also a successful job. If the agent were paid only when the company passes, it would have an incentive to approve.

## 5. Demo screen: "protected remaining balance"

The user sees more than a green "company active" badge:

```
Order:            Motor supply
Paid:             500
Remaining:        2,500
Payment permit:   expired
Last check:       registry condition not met
Next step:        buyer review needed
```

The point is to show which rule protects the money that has not been sent yet.

A 3D model of the ordered motor or robot part can help explain the order and the stages. It must not suggest that physical production was verified.

## 6. Hackathon scope (v1)

In:
- one registry source: Companies House (`company_status`)
- one supplier, one order
- two payment stages
- a permit with an expiry, used up by each payment
- one "paid" scenario and one "held" scenario
- a paid follow-up job through Cardano (Masumi/Sokosumi)
- the four API3 tamper tests (modified value, stale, other request, wrong key)

Out (not in the first version): credit scores, automatic fraud detection, more than one registry.

## 7. Contract (planned interface)

`api3/src/SupplierPulse.sol`, reusing the vault's signature checks (`AirnodeVerifier`).

- `createOrder(supplier, companyRequest, orderRef, amounts[], permitTtl)` with the total locked as value
- `approveMilestone(orderId, milestone)`, buyer only
- `submitEvidence(orderId, requestHash, timestamp, data, signature)`: verifies signer, this order's company request, freshness and no replay. Status `active` issues a permit for the next stage. Any other status holds the order.
- `release(orderId)`: pays the next stage only with a valid, unexpired permit for that stage and the buyer's approval. The permit is used up.
- `checkAndRelease(...)`: one call for the agent. Returns `Paid`, `AwaitingApproval` or `Held`. It reverts only when verification fails.
- `refundRemaining(orderId)`: buyer only, after a hold
- `orderStatus(orderId)`: everything the demo screen shows

Tamper cases and the expected rejection:

| Tamper | Rejected as |
|---|---|
| edited status (e.g. `dissolved` changed to `active`) | wrong signer |
| old response | stale response |
| another company's response | wrong request |
| signed with another key | wrong signer |
| same response twice | replayed |

## 8. Open items

- Companies House listing on AirnodeHub: exact endpoint, signer address, operation and parameter names, and response projection (`status` → `/company_status`). The operation is priced ($0.01 aUSD per call, x402 on Base Sepolia), and Batu's wallet holds 9.99 aUSD.
- A real test company number for the "active" case, and a dissolved one for the "held" case.
- Cardano side: a new app/executor in `cardano-agent/` that is paid for a correct decision (paid or held), not only for approvals.
