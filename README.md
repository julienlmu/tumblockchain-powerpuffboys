# SupplierPulse+

**Your supplier was approved last month. That should not approve today's payment.**

SupplierPulse+ pays a supplier's milestones only against a fresh, signed record from the official company register. The buyer locks the order amount in a smart contract on Ethereum Sepolia. Before each payment, an agent buys a signed register record from **API3 AirnodeHub** ($0.01 over x402) and hands it to the contract. A clean record lets the next milestone pay. A failing record stops the payment and sends the rest of the money back to the buyer. A forged record is rejected.

> Built for the **API3 track "Any API in your contract"** at the TUM Blockchain & AI Hackathon, Munich, 30–31 October 2026. Testnets only. Not a credit score and not a promise that a supplier will deliver.

## The problem

Companies check a supplier once, at onboarding, and then pay it for months on the strength of that one check. In between, the supplier can go into liquidation, stop filing its accounts or let its legal-entity registration lapse. The public register shows it the same week, but nobody looks before the next payment.

It happens often. In 2025, **23,938 companies** became insolvent in England and Wales, about **1 in 190** ([Insolvency Service](https://www.gov.uk/government/statistics/company-insolvencies-december-2025/commentary-company-insolvency-statistics-december-2025)). German courts recorded **24,064 company insolvencies** with **€47.9 billion** owed to creditors ([Destatis](https://www.destatis.de/DE/Presse/Pressemitteilungen/2026/03/PD26_085_52411.html)). An unsecured trade creditor of a liquidated UK company usually gets little or nothing back.

**Example customer** (fictional): a machinery maker near Augsburg buys gearbox housings from a UK supplier and pays in three milestones. Between the first and second payment the supplier goes into liquidation. With SupplierPulse+, the agent's next register check returns `liquidation`, the contract refuses to pay, and the buyer gets the rest back. That is order B in our live demo, a real UK company.

## How it works

```text
1. Order    buyer locks the amount: supplier register ID, payout wallet, milestones, rules
2. Check    agent pays $0.01 (x402) → API3 AirnodeHub → signed Companies House or GLEIF record
3. Verify   contract checks signer, request, freshness and replay before it reads a single value
4. Decide   clean  → the next milestone pays when it is due and the buyer has approved delivery
            failed → the order stops, the remaining money goes back to the buyer
5. Tamper   an edited, old, swapped or wrongly signed record is rejected and nothing moves
```

- **Who signs.** Each register has its own Airnode key stored in the contract. The contract recovers the signer itself and never trusts a signer address sent with the data.
- **What it checks.** Companies House: company `active`, accounts and confirmation statement filed on time. GLEIF: entity `ACTIVE`, LEI `ISSUED`. The buyer picks the rules per order.
- **The agent** ([`api3/agent/`](api3/agent/), [docs/agent.md](docs/agent.md)) runs on its own: it checks before every due date, pays for records within a daily budget, simulates each transaction before sending it, releases due milestones and triggers refunds. On Sepolia it ran 226 cycles in its first two hours and spent $0.15 on records.
- **Anyone can call.** `submitEvidence`, `release` and the refund are open, so if our agent stops, the supplier or a judge can make the same call.

## Live on Ethereum Sepolia

| What | Value |
|---|---|
| Contract (SupplierPulse+ v2) | [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC#code), source verified on Etherscan and Sourcify |
| Trusted Airnodes | Companies House `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, GLEIF `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c` |
| Agent wallet | `0xED3418aE93669a640650728E70f7aA712083253a` |
| Record payments (x402) | aUSD on Base Sepolia, $0.01 per record |

Five demo orders against real companies (30 Oct 2026). The buyer created and approved them; the agent did every check, payment, stop and refund.

| Order | Supplier | Result |
|---|---|---|
| A | Companies House `03778796`, active | clean checks, milestone 1 paid, supplier moved up to Trusted |
| B | Companies House `07418033`, in liquidation | stopped at the first check, refunded |
| C | Companies House `09729896`, accounts overdue | stopped, refunded |
| D | GLEIF `391200JI69LS8L648F30`, LEI issued | clean checks, milestone 1 paid, supplier moved up to Trusted |
| E | GLEIF `52990092KBQJF8QBGJ50`, LEI lapsed | stopped, refunded |

Every transaction, with its x402 payment and explorer link: **[docs/evidence.md](docs/evidence.md)**.

## Run the demo in 3 commands

Needs [Foundry](https://getfoundry.sh/), Node.js 22.18 or newer, Python 3, `jq` and `curl`.

```sh
git clone https://github.com/julienlmu/tumblockchain-powerpuffgirls.git && cd tumblockchain-powerpuffgirls
python3 -m http.server 8765 --bind 127.0.0.1 --directory demo
api3/scripts/judge-tamper.sh
```

- The second command serves the screens against the live contract, no keys needed. `http://localhost:8765/` is the buyer dashboard, `http://localhost:8765/judge.html` is "Try to break it", `http://localhost:8765/?sample=1` shows sample data without a chain.
- The third command runs the tamper test on a local chain (in a second terminal).

## Judges: try to break it

`api3/scripts/judge-tamper.sh` starts a local chain, deploys the contract with local Airnode keys and submits one fresh signed record plus tampered copies of it. No keys, no money.

| Attempt | Contract answer |
|---|---|
| (a) one signed value edited (`active` → `liquidation`) | rejected, `WrongSigner` |
| (b) record too old | rejected, `StaleResponse` |
| (c) record for another company | rejected, `WrongRequest` |
| (d) signed by a key that is not the Airnode's | rejected, `WrongSigner` |
| the valid, fresh record | accepted, milestone paid |
| the same record again | rejected, `Replayed` |

Against the live contract (simulated with `eth_call`, no wallet, no gas):

```sh
api3/scripts/judge-tamper.sh --live <orderId> <fresh record.json>
```

A fresh record costs $0.01 in test aUSD ([API3 faucet](https://api3dao.github.io/airnodehub-hackathon/faucet/)): `PAYER_PRIVATE_KEY=0x… api3/scripts/fetch-evidence.sh ch 03778796 response.json` from `api3/`. Genuine old and other-company records are bundled in [`api3/fixtures/`](api3/fixtures/), and the browser page `demo/judge.html` runs the same attempts with one click each. The contract has 115 Foundry tests (`cd api3 && forge test`), including every tamper case with real signed records.

## Also in the project

- **Document hash.** The order's documents (contract text, PO lines, delivery terms) stay off chain. Only a salted hash is written into the order, once, at creation. Either side can later prove what was agreed by showing the document and its salt (`api3/scripts/plus-doc-hash.sh`, `api3/scripts/plus-verify-doc.sh`).
- **Supplier tiers.** Clean checks in a row move a supplier from Standard to Trusted (3) and Premium (6). Trusted suppliers are re-checked less often, so the agent buys fewer records. A tier never extends a payment permit or relaxes the freshness limit. One failed status stops payments to that supplier on all of its orders.
- **Second register: GLEIF.** For suppliers outside the UK, the contract checks the global LEI register. Orders D and E use real German LEIs.

## Honest limits

- **The admin manages the signer.** In this demo the deployer can change the trusted Airnode address and the maximum record age. Only each order's document hash is locked for good. In production this would sit behind a timelock and a multisig.
- **A signature proves the source, not the truth.** It proves the register's API returned exactly this answer at this time. It does not prove the register is complete, that the supplier will deliver or that it stays solvent. That is why every milestone also needs the buyer's approval.
- **The wallet is the buyer's input.** The contract does not prove the payout wallet belongs to the company. The buyer gets it from a supplier it has already vetted, the same way it gets an IBAN today, and it cannot change after the order is created.
- **Data we wanted but could not find on AirnodeHub:** the German Handelsregister and German insolvency notices. GLEIF covers German companies only when they have an LEI.
- Already paid milestones cannot be clawed back. Testnets only.

## Team

Orhun (contract), Emre (data layer and judge tools), Julien (agent and specification), Batu (dashboard and judge page), Ulaş (story, pitch and video).

More: [specification](docs/SUPPLIERPULSE_PLUS.md) · [agent](docs/agent.md) · [screens](demo/README.md) · [team log](docs/PROGRESS.md)

## License

MIT
