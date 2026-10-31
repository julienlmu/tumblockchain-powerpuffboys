# Devfolio submission: SupplierPulse+

## Project name

SupplierPulse+

## Tagline

Your supplier was approved last month. That should not approve today's payment.

## Tracks

- API3: "Any API in your contract"
- TUM Blockchain Track (automatic)

## The problem

Companies check a supplier once, at onboarding, and then pay it in milestones for months on the strength of that one check. In between, the supplier can go into liquidation, stop filing its accounts or let its legal-entity registration lapse. The public register shows it the same week, but nobody looks before the next payment goes out.

This is not rare. In 2025, 23,938 companies became insolvent in England and Wales, about 1 in 190 (Insolvency Service). German courts recorded 24,064 company insolvencies with €47.9 billion owed to creditors (Destatis). An unsecured trade creditor of a liquidated UK company usually gets little or nothing back, so a milestone paid one week too late is usually lost.

Example customer (fictional): a mid-size machinery maker near Augsburg buys gearbox housings from a UK supplier and pays 30% upfront, 40% at first delivery and 30% at final delivery. Between the first and second payment the supplier goes into liquidation. Today the second payment goes out anyway.

## What we built

SupplierPulse+ makes every milestone payment depend on a fresh, signed record from the official company register.

1. **Order.** The buyer creates an order in our contract on Ethereum Sepolia: the supplier's register ID (Companies House number or LEI), its payout wallet, milestones with amounts and due dates, and the rules to check. The whole amount is locked.
2. **Signed register check.** Before each due date, our agent buys a signed record for the supplier from API3 AirnodeHub. It pays $0.01 in aUSD over x402 on Base Sepolia.
3. **Pay or stop.** The contract verifies the record and applies the buyer's rules. A clean record lets the next milestone pay when it is due and the buyer has approved delivery. A failing record (in liquidation, accounts overdue, LEI lapsed) stops the order and the remaining money goes back to the buyer.
4. **Tamper rejected.** An edited, old, swapped or wrongly signed record is rejected, and no money moves.

It runs live on Ethereum Sepolia at `0xf25Aae1772326C95294D1923399D55c658493DfC` (source verified on Etherscan). We ran five orders against real companies: two clean suppliers were paid, and three failing ones (a UK company in liquidation, one with overdue accounts, one German company with a lapsed LEI) were stopped and refunded. Every transaction is listed in `docs/evidence.md`.

## How it's built

- **Contract** (Solidity, Foundry, 115 tests). Before it reads any value, `submitEvidence` checks, in this order: the order is active; the request hash is exactly this order's request (supplier and fields); the record is at most 300 s old and not from the future; it was never used before and is newer than the order's last record; and it is signed by the Airnode the contract stores for that register. The contract recovers the signer itself and never trusts a signer address that comes with the data. Then it reads the signed JSON fields and applies the rules.
- **Data.** API3 AirnodeHub listings for Companies House (company status, accounts and confirmation statement due dates) and GLEIF (entity status, LEI registration status). The agent requests a projection of only the fields the contract needs, so the signed bytes are small enough to parse on chain.
- **Agent** (Python). It runs on its own: it checks before every due date and between due dates as often as the supplier's tier says, pays for records within a daily budget, simulates every transaction before sending it, releases due milestones and triggers refunds once they are allowed. It backs off on errors instead of buying again, and quarantines a record whose signer or request does not match. On Sepolia it ran 226 cycles in its first two hours and spent $0.15 on records.
- **Screens** (static HTML and ethers.js). A buyer dashboard that shows every order, its locked balance and the agent's transactions, and "Try to break it", a judge page that runs each tamper case against the live contract with `eth_call` (no wallet, no gas).
- **Judge tools.** `api3/scripts/judge-tamper.sh` runs the whole tamper test in one command on a local chain, or against the live contract with `--live`.

Also in the project: a salted document hash in each order, so the order documents stay private but provable; supplier tiers (Standard, Trusted, Premium) that lower how often a trusted supplier is re-checked without ever relaxing the freshness limit; and GLEIF as a second register for suppliers outside the UK.

## Who relies on the data, and what goes wrong if it is forged

The buyer's money relies on it: the signed register record is the only input that decides whether a milestone can pay. A forged "active, accounts filed" record would pay a company that is being wound up. A forged negative record would block an honest supplier and refund the buyer. That is why the contract binds the exact signed bytes to the expected Airnode, the exact request and a narrow time window.

## Tamper test

| Attempt | Contract answer |
|---|---|
| Valid, fresh record | accepted, milestone paid |
| (a) one signed value edited | rejected, `WrongSigner` |
| (b) record too old | rejected, `StaleResponse` |
| (c) record for another company | rejected, `WrongRequest` |
| (d) signed by a different key | rejected, `WrongSigner` |
| Same record a second time | rejected, `Replayed` |

Judges can run it themselves with `api3/scripts/judge-tamper.sh` (local, no keys) or on the "Try to break it" page against the live contract.

## Challenges we ran into

- **Parsing signed JSON on chain.** The contract must read fields from the exact bytes that were signed, never from a re-serialized copy. We request a projection of only the needed fields and read them with a small on-chain JSON reader.
- **Freshness versus real payment dates.** A record must be at most 300 s old when it is submitted, but milestones fall due later. We solved it with a short-lived payment permit for the next milestone only, issued by a clean record.
- **Gas.** Clean records with all rules cost about 680k gas. Our first agent sends ran out of gas at a 600k limit, which we found in the live run and fixed by raising the limit.
- **Making tiers safe.** A trust tier must not be farmable by sending many checks quickly. Only newer records count, at most one per 300 s, and one failed status resets the streak and stops the supplier on all its orders.
- **Telling the truth about what a signature proves.** It proves the register said this at this time, not that the supplier will deliver. So every milestone also needs the buyer's approval.

## Honest limits

- In the demo the deployer can change the trusted Airnode address and the maximum record age. In production this would sit behind a timelock and a multisig.
- The contract does not prove the payout wallet belongs to the company. The buyer takes it from a supplier it has already vetted, as it takes an IBAN today.
- Data we wanted but could not find on AirnodeHub: the German Handelsregister and German insolvency notices. GLEIF covers German companies only when they have an LEI.
- Testnets only. Already paid milestones cannot be clawed back.

## Links

- Repository: https://github.com/julienlmu/tumblockchain-powerpuffgirls
- Contract: https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC#code
- Evidence (every transaction): `docs/evidence.md`

## Team

Orhun (contract), Emre (data layer and judge tools), Julien (agent and specification), Batu (dashboard and judge page), Ulaş (story, pitch and video).
