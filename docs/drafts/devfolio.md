# Devfolio submission draft — API3 track

> **Not submission-ready (30 October 2026, 17:02 CET).** The v2 feature description below is the intended design, not a deployed product claim. The only live contract evidence in this branch is SupplierPulse v1, which checks Companies House status only. Keep this as a draft until the v2 contract, data tools, judge experience, and live evidence are integrated and verified.

## Project name

SupplierPulse+

## Tagline

Your supplier was approved last month. That should not approve today's payment.

## Problem

Buyers commonly qualify suppliers at onboarding, then pay advances and milestone instalments over time. A later registry change—such as liquidation or an overdue statutory filing—may not be reflected in the buyer's next payment decision. In England and Wales, the Insolvency Service reported 1,882 company insolvencies in September 2026; 1,761 were compulsory or creditors' voluntary liquidations. That is a monthly aggregate, not a forecast of supplier failures.

## SupplierPulse+ v2 design (not yet deployed)

The intended SupplierPulse+ v2 system gates supplier milestone payments on fresh, signed registry evidence. An agent would pay for a projected Companies House or GLEIF response through API3 AirnodeHub and submit the exact signed bytes to an Ethereum contract. This v2 flow is specified but is not yet integrated or deployed in this branch.

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

If a configured signing key were compromised or signed false data, a false clean record could permit a milestone or a false failing record could hold payment. An unsigned edit cannot pass as-is: the contract binds the exact bytes to the expected Airnode, request, and time, and rejects edited data, stale responses, wrong requests, wrong signers, and replays.

## What data did we want but could not find?

We did not find German Handelsregister records or German insolvency notices among the AirnodeHub sources we checked. GLEIF can represent German entities when they have an LEI, but it does not replace those national-register records. Delivery confirmation from buyer ERP systems is also outside the prototype.

## Contract and network

- **SupplierPulse+ v2:** Ethereum Sepolia, chain ID `11155111`; address and deployment transaction: **[insert verified v2 address and explorer link from `docs/evidence.md`]**.
- **Currently deployed SupplierPulse v1:** [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7), [deployment transaction](https://sepolia.etherscan.io/tx/0x21731862868abbc5394aa72799db6e03881eb8cf59d300493e1d782f6e596871). V1 checks only the Companies House status field; it is not the v2 feature set.
- **Data-payment network:** Base Sepolia, chain ID `84532`; x402 payments use aUSD.

## How judges can test it

The v2 judge experience is not available in this branch. The current v1 run and scripts are documented in [`docs/evidence.md`](../evidence.md); the v1 tamper attempts were `eth_call` simulations, not mined reverted transactions. Before submission, add the real v2 deployment and judge links here:

- Dashboard: **[pending: verify published URL or integrated repository path]**
- “Try to break it” judge page: **[pending: verify published URL or integrated repository path]**
- CLI: **[pending: verify v2 judge CLI path and invocation]**

The v2 demonstration must first show an accepted fresh response that causes the intended outcome, then reject the edited value, stale response, different request, and wrong signer. Replay is an additional rejection case. Distinguish simulations from transactions actually sent on the testnet.

## Autonomous agent bonus

The agent implementation and documentation exist in `api3/agent/` and `docs/agent.md`. Its updated 54-test suite ran locally: 53 passed and one was skipped because `cast` is not installed. A 45-tick `--fake` workflow also ran against an in-memory chain and registry; its synthetic transactions and spend are not live evidence. The overnight Sepolia run, real-cycle count, and verified spend are still pending. The intended demo limits are a $1.00 daily data budget, $0.20 reserved for due checks, at most three fetches per tick, and a $0.01 target cost per call; confirm these against the deployed v2 agent configuration before submission.

**Before submission:** replace the above with the live cycle count, measured spend, overnight log, and Base Sepolia payment / Ethereum Sepolia action links—or state plainly that the agent bonus was not demonstrated.

## Honest limitations

- Testnets only; the prototype is not a production escrow or financial product.
- A signed record proves what the configured Airnode signed, not that the source is infallible, that the supplier will deliver, or that the supplier will remain solvent.
- The contract can hold remaining funds but cannot reverse milestones already paid.
- Registry, jurisdiction, and field coverage is limited. Missing data does not count as a clean record.
- The v2 specification proposes a five-minute tier-count gap and ten-minute refund grace period; verify actual deployment parameters before claiming these as live settings.
- The UK insolvency and Carillion context and the current research limits are in [`docs/research.md`](../research.md).

## Links

- Source repository: https://github.com/julienlmu/tumblockchain-powerpuffgirls
- Build specification: [`docs/SUPPLIERPULSE_PLUS.md`](../SUPPLIERPULSE_PLUS.md)
- Evidence log: [`docs/evidence.md`](../evidence.md)
- Research: [`docs/research.md`](../research.md)
- Agent documentation: [`docs/agent.md`](../agent.md)
