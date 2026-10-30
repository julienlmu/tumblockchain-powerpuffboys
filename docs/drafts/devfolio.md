# Devfolio submission draft — API3 track

> **Draft for integration.** Replace the v2 deployment, demo, and agent placeholders with the verified facts and links in `docs/evidence.md` and `docs/agent.md` before submission. This is not a claim that the v2 flow is already live.

## Project name

SupplierPulse+

## Tagline

Your supplier was approved last month. That should not approve today's payment.

## Problem

Buyers commonly qualify suppliers at onboarding, then pay advances and milestone instalments over time. A later registry change—such as liquidation or an overdue statutory filing—may not be reflected in the buyer's next payment decision. In England and Wales, the Insolvency Service reported 1,882 company insolvencies in September 2026; 1,761 were compulsory or creditors' voluntary liquidations. That is a monthly aggregate, not a forecast of supplier failures.

## What we built

SupplierPulse+ is a testnet prototype that gates supplier milestone payments on fresh, signed registry evidence. An agent pays for a projected Companies House or GLEIF response through API3 AirnodeHub and submits the exact signed bytes to an Ethereum contract.

The contract verifies the expected Airnode, supplier-specific request hash, response freshness, timestamp ordering, and replay protection. It evaluates buyer-selected rules and either issues an expiring permit for exactly the next milestone or holds the unpaid balance for the buyer. Buyer approval remains required to release a milestone because a registry cannot verify delivery.

Newer signed base-status records update a shared supplier verification history. Higher tiers reduce monitoring frequency, allowing fewer paid checks between due dates; tiers never extend permits or relax the freshness window. A failed base status resets the streak and blocks payments backed by older permits across that supplier's orders.

## How it works

1. A buyer creates and funds an order with a registry source/ID, supplier wallet, milestones, due dates, and rules.
2. The agent fetches a current signed record from API3 AirnodeHub, paying $0.01 per check over x402 in aUSD on Base Sepolia.
3. The Ethereum Sepolia contract validates the response and buyer's policy.
4. A clean record issues a permit for the next milestone. The buyer separately approves it, and the milestone can then be released.
5. A failed record holds the order. A base-status failure also stops older permits across the supplier's other orders. If an approved milestone remains without a valid permit beyond its due date and the refund grace period, anyone can return the remaining balance to the buyer. The agent monitors orders, enforces a daily budget, simulates writes before sending, and handles retries or quarantine according to its policy.

## Who relies on the data?

The buyer relies on the signed registry record to decide whether to permit the next payment. The supplier's payment is conditional on both a valid registry check and the buyer's milestone approval.

## What goes wrong if the data is forged?

A forged clean response could release a milestone to a supplier whose registry record is not clean. A forged failing response could hold an honest supplier's payment. The contract therefore binds the data to the expected Airnode, request, and time, and rejects edits, stale responses, wrong requests, wrong signers, and replays.

## What data did we want but could not find?

We did not find German Handelsregister records or German insolvency notices among the AirnodeHub sources we checked. GLEIF can represent German entities when they have an LEI, but it does not replace those national-register records. Delivery confirmation from buyer ERP systems is also outside the prototype.

## Contract and network

- **SupplierPulse+ v2:** Ethereum Sepolia, chain ID `11155111`; address and deployment transaction: **[insert verified v2 address and explorer link from `docs/evidence.md`]**.
- **SupplierPulse v1 fallback:** [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7). V1 only checks the Companies House status field; it is not the v2 feature set.
- **Data-payment network:** Base Sepolia, chain ID `84532`; x402 payments use aUSD.

## How judges can test it

After replacing the v2 placeholder above with the deployed address, judges can use:

- Dashboard: **[insert published dashboard URL or repository path]**
- “Try to break it” judge page: **[insert published page URL or repository path]**
- CLI: `api3/scripts/plus-submit.sh <orderId> <response.json> [value|stale|request|key|replay]`

The demonstration must first show an accepted fresh response that causes the intended outcome, then reject the edited value, stale response, different request, and wrong signer. Replay is an additional rejection case. The CLI and page simulate the contract call; any real testnet send must be clearly identified and linked.

## Autonomous agent bonus

The agent checks before due dates and monitors between due dates according to the supplier's verification-history tier. Demo limits are a $1.00 daily data budget, $0.20 reserved for due checks, at most three fetches per tick, and a $0.01 target cost per call. The agent simulates each write before submission; no-data responses back off, payment failures pause paid checks, and signer/request mismatches trigger an alert and quarantine.

**Evidence to insert before submission:** `[cycles completed]`, `[verified daily spend]`, `[overnight log excerpt]`, and links to the logged Base Sepolia payment transactions and Ethereum Sepolia agent actions. Do not leave this section as an unverified claim.

## Honest limitations

- Testnets only; the prototype is not a production escrow or financial product.
- A signed record proves what the configured Airnode signed, not that the source is infallible, that the supplier will deliver, or that the supplier will remain solvent.
- The contract can hold remaining funds but cannot reverse milestones already paid.
- Registry, jurisdiction, and field coverage is limited. Missing data does not count as a clean record.
- The demo uses a five-minute tier-count gap and ten-minute refund grace period; these are intentionally shortened demo settings.
- The UK insolvency and Carillion context and the current research limits are in [`docs/research.md`](../research.md).

## Links

- Source repository: https://github.com/julienlmu/tumblockchain-powerpuffgirls
- Build specification: [`docs/SUPPLIERPULSE_PLUS.md`](../SUPPLIERPULSE_PLUS.md)
- Evidence log: [`docs/evidence.md`](../evidence.md)
- Research: [`docs/research.md`](../research.md)
- Agent documentation: [`docs/agent.md`](../agent.md) (add when merged)
