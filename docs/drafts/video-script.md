# SupplierPulse+ video storyboard and script

**Target runtime:** 2:30 maximum
**Recording plan:** capture real Sepolia interactions and real signed registry evidence. Local-chain steps may be used for development only; never present them as live/testnet proof.

## Preconditions before recording

- [ ] Confirm the v2 contract address and deployment transaction from `docs/evidence.md`.
- [ ] Verify all demo order IDs, supplier IDs, payout wallets, due times, and rule flags.
- [ ] Have fresh signed registry responses ready; do not reuse an expired response for the valid case.
- [ ] Confirm a clean order with an approved, due milestone for the valid action.
- [ ] Confirm a failing order for the hold demonstration and a live-created order for the buyer-approval moment.
- [ ] Confirm the dashboard and judge page show the Sepolia v2 contract.
- [ ] Prepare the overnight agent log, spend summary, and x402 Base Sepolia transaction links.
- [ ] Record pre-run proof transactions so a slow RPC or live timing issue does not erase the demo.
- [ ] Have a backup screen recording; keep the final cut at or under 2:30.

## Timed storyboard and narration

| Time | Picture / action | Narration |
|---|---|---|
| 0:00–0:15 | Title over the held-balance dashboard; show the tagline and one sourced Insolvency Service figure. | “Your supplier was approved last month. That should not approve today's payment. In September 2026, England and Wales recorded 1,882 company insolvencies. SupplierPulse+ asks for fresh registry proof before each milestone.” |
| 0:15–0:35 | Architecture graphic: Companies House and GLEIF → API3 AirnodeHub → agent → Sepolia contract. Highlight buyer approval separately. | “The agent pays a cent for a signed Companies House or GLEIF response through API3 AirnodeHub. The contract checks the signer, the exact supplier request, freshness, and replay protection. Registry evidence is one lock; buyer approval for delivery is the other.” |
| 0:35–1:05 | Sepolia dashboard. Show clean order A's latest agent check, its permit, then M2 payment. Briefly show order B2 held by the supplier-wide stop, without a new fetch. | “A clean record grants a permit for only the next milestone. The buyer still approves that stage. Here the agent checked the supplier and the approved milestone was paid. A verified status failure on another order stops older permits for this supplier too, without another fetch. If data stays unavailable past an approved due date and the grace period, the buyer gets the remaining balance back.” |
| 1:05–1:45 | Judge page: first submit a valid fresh response and show the contract's accepted verdict/action. Then run edited value, too old, different request, wrong key; show errors. If time, show replay. | “First, a real fresh response succeeds. Now we change one field without changing its signature: rejected. We make the signed timestamp too old: rejected. We substitute another supplier request: rejected. We sign with a different key: rejected. The contract is not rejecting everything; the valid response worked first.” |
| 1:45–2:10 | Agent activity/log panel; show several timestamped cycles, tier, daily spend, and one x402 payment link on Base Sepolia. | “The agent runs repeatedly. It checks near due dates, monitors less often as verified history earns a higher tier, stays within a daily budget, simulates writes before sending, and backs off or quarantines on errors. Tiers change monitoring frequency, never permit lifetime. Data payments are on Base Sepolia; supplier orders are on Ethereum Sepolia.” |
| 2:10–2:30 | Limitation text, unavailable data, repo and contract link. | “A signature proves what the registry returned, not that goods were delivered or that a supplier will remain solvent. We could not find German Handelsregister and insolvency-notice data in the sources checked. SupplierPulse+ makes fresh public evidence a payment condition. Explore the contract and judge tools in the repository.” |

## On-screen source and evidence notes

- Put a small source caption beside the opening figure: **Insolvency Service, Company insolvencies, September 2026**.
- The research note reports 1,882 insolvencies in England and Wales; do not label it a UK-wide count.
- Use a screenshot or visible link to the Sepolia contract, accepted valid-response transaction, payment transaction, and the four tamper rejections.
- Show an agent cycle log with actual measured timestamps and spend. Replace generic narration with the final recorded counts; do not stage a fake overnight log.
- For the Carillion example, if used instead of the monthly figure, label £148m as the NAO's estimate of taxpayer cost in 2018—not a private supplier loss.

## Recording checklist

- [ ] The valid response and intended action are shown before any tamper rejection.
- [ ] The edited value, stale timestamp, different request, and wrong signer all show the actual contract verdict.
- [ ] Distinguish simulated `eth_call` results from transactions actually sent on Sepolia.
- [ ] Show the correct v2 address; do not accidentally show the v1 fallback as v2.
- [ ] Do not use any Anvil key, address, or local-chain data on a public network.
- [ ] Keep the final export no longer than 2:30 and upload unlisted; add its link to the README and submission.
