# SupplierPulse+ video storyboard and script

**Target runtime:** 2:30 maximum
**Recording plan:** capture real Sepolia interactions and real signed registry evidence. Local-chain steps may be used for development only; never present them as live/testnet proof.

> **Not record-ready (30 October 2026, 17:02 CET):** this storyboard requires a deployed v2 contract, integrated dashboard and judge page, and a real agent run. None is evidenced in this branch yet. Current v1 evidence is in `docs/evidence.md`; its four tamper rejections were simulations, not mined revert transactions. Do not narrate the v2 storyboard as an accomplished live demo until each precondition below is met.

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
- [ ] Time the narration aloud and confirm the finished export is no longer than 2:30.

## Timed storyboard and narration

| Time | Picture / action | Narration |
|---|---|---|
| 0:00–0:15 | Title over the held-balance dashboard; show the tagline and one sourced Insolvency Service figure. | “Your supplier was approved last month. That should not approve today's payment. In September 2026, England and Wales recorded 1,882 company insolvencies. SupplierPulse+ checks registry evidence before a milestone.” |
| 0:15–0:35 | Architecture graphic: Companies House and GLEIF → API3 AirnodeHub → agent → Sepolia contract. Highlight buyer approval separately. | “The agent pays for a signed Companies House or GLEIF response through API3. The contract checks the signer, supplier request, freshness, and replay. Buyer approval remains separate: registry data cannot confirm delivery.” |
| 0:35–1:05 | Sepolia dashboard. Show clean order A's latest agent check, its permit, then M2 payment. Briefly show order B2 held by the supplier-wide stop, without a new fetch. | “A clean record permits only the next milestone. After buyer approval, this milestone was paid. A verified failed status on another order blocks older permits for the same supplier, without another fetch. If data stays unavailable past an approved due date and grace period, funds return to the buyer.” |
| 1:05–1:45 | Judge page: first submit a valid fresh response and show the contract's accepted verdict/action. Then run edited value, too old, different request, wrong key; show errors. If time, show replay. | “First, a fresh signed response succeeds. Edit its value: rejected. Submit stale data: rejected. Change the supplier request: rejected. Use a wrong signer: rejected. Each failure protects the payment rule, not just the demo page.” |
| 1:45–2:10 | Agent activity/log panel; show several timestamped cycles, tier, daily spend, and one x402 payment link on Base Sepolia. | “The agent checks near due dates and monitors less often as verified history improves. It limits spend and gas, simulates writes, and handles errors. Tiers change monitoring frequency, never permit lifetime. Data payments run on Base Sepolia; orders settle on Ethereum Sepolia.” |
| 2:10–2:30 | Limitation text, unavailable data, repo and contract link. | “A signature proves what the registry returned—not delivery or future solvency. We could not find German Handelsregister or insolvency-notice data in the sources checked. Explore the contract and evidence in the repository.” |

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
