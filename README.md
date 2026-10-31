# SupplierPulse

**Your supplier was approved last month. That should not approve today's payment.**

SupplierPulse pays a supplier's milestones only against fresh, signed proof from the official company register. A buyer locks the order amount in a smart contract on Ethereum Sepolia. Before each milestone, an autonomous agent buys a signed register record from **API3 AirnodeHub** ($0.01 over x402) and submits it. The contract checks the record before any money moves. A clean record unlocks one milestone; a failing one holds the rest of the money for the buyer.

> Hackathon prototype for the **API3 track "Any API in your contract"** (TUM Blockchain & AI Hackathon, Munich, October 2026). Testnets only. It is not a credit score or a guarantee that a supplier will deliver.

**Demo video:** [SupplierPulse demo on YouTube](https://youtu.be/zHWpYP_cOgU)

[![SupplierPulse demo video](https://img.youtube.com/vi/zHWpYP_cOgU/hqdefault.jpg)](https://youtu.be/zHWpYP_cOgU)

**Try it live:** [julienlmu.github.io/tumblockchain-powerpuffboys](https://julienlmu.github.io/tumblockchain-powerpuffboys/) opens the Control Room on the live Sepolia contract: the orders and why each pays or waits, the **Verification lab** (the tamper test, simulated against the live contract: no wallet, no gas), the agent's own transactions and a judge kit with every command.

Team log and status: [docs/PROGRESS.md](docs/PROGRESS.md).

## The problem

Companies vet a supplier once, at onboarding, and then pay invoices for months on the strength of that approval. In between, the supplier can go into liquidation, stop filing its accounts or let its legal-entity registration lapse. The public registers know, but nobody looks before the next payment. SupplierPulse looks every time, and makes the contract act on what it finds.

## How it works

```text
buyer ── createOrder(amounts, due dates, rules) ──▶ SupplierPulsePlus (Ethereum Sepolia)
                                                          ▲
agent ── x402 $0.01 ──▶ API3 AirnodeHub ── signed record ─┘ submitEvidence / release
                        (Companies House, GLEIF)
                                                          │
                     clean record ──▶ payment permit for the next milestone ──▶ paid when due AND approved by the buyer
                     failed record ─▶ order held ──▶ refund to the buyer
```

1. **The buyer creates an order:** the supplier's register ID, its payout wallet, milestones with amounts and due dates, and the rules to check. The whole amount is locked in the contract.
2. **The agent buys a signed record** for the supplier from API3 AirnodeHub before each due date. It pays $0.01 in aUSD over x402 on Base Sepolia, then submits the record to the contract.
3. **The contract verifies the record** before it acts, in this order:
   - the order is active;
   - the record answers exactly this order's request (supplier and fields);
   - it is fresh (at most 300 s old) and not dated in the future;
   - it was never used before and is newer than the order's last record;
   - it is signed by the Airnode the contract trusts for that register.
4. **It applies the buyer's rules** to the signed values:
   - Companies House: status `active` (always), accounts filed on time, confirmation statement filed on time;
   - GLEIF: entity `ACTIVE` (always), LEI registration `ISSUED`.
5. **A clean record gives a payment permit** for the next milestone only. It pays when the milestone is due **and** the buyer has approved it: the register proves the company is in good standing, and delivery stays the buyer's call.
6. **A failed record holds the order.** The remaining money can only go back to the buyer: the buyer can refund at once, anyone can after a grace period.

More rules the contract enforces:
- **Supplier-wide stop.** A failed register status stops payments to that supplier on all of its orders. The agent then holds the other orders without buying another record.
- **No-data exit.** If no valid record arrives after an approved milestone is due, anyone can return the money to the buyer after the grace period.
- **Verification history.** Clean checks in a row move a supplier from Standard to Trusted (3) and Premium (6). Trusted suppliers are re-checked less often, so the agent buys fewer records. A tier never extends a permit or relaxes freshness.

**The agent** ([`api3/agent/`](api3/agent/), details in [docs/agent.md](docs/agent.md)) runs on its own:
- it checks before every due date, and between due dates as often as the supplier's tier says;
- it pays for records within a daily budget and gas limits;
- it simulates each transaction before sending it;
- it holds stopped orders, releases due milestones, and triggers refunds when they become possible;
- it backs off on errors instead of buying again, and quarantines a record whose signer or request doesn't match.

## Live on Ethereum Sepolia

| What | Value |
|---|---|
| Contract (SupplierPulse v1.1, `SupplierPulsePlus`) | [`0xf25Aae1772326C95294D1923399D55c658493DfC`](https://sepolia.etherscan.io/address/0xf25Aae1772326C95294D1923399D55c658493DfC#code), source verified on Etherscan and Sourcify |
| Trusted Airnodes | Companies House `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`, GLEIF `0x26d83124541e89ef28B9A5FB012B4B5f4097C20c` |
| Settings | max record age 300 s, refund grace 600 s (demo values) |
| Agent wallet | `0xED3418aE93669a640650728E70f7aA712083253a` |
| Data payments (x402) | aUSD `0xbeA34973e5f67F18F656A2C6070C64326C791808` on Base Sepolia |

Demo orders against real companies from Companies House and GLEIF (A–E created on 30 Oct 2026, F on 31 Oct). The buyer created and approved the orders; the agent did every check, payment, hold and refund:

| Order | Supplier | What happened |
|---|---|---|
| A · PO-1001 | Companies House `03778796`, active | Clean checks; milestones 1 and 2 paid when due (Fri 20:03, Sat 11:45); milestone 3 approved and due Sat 15:30; rose to Trusted, then Premium |
| B · PO-1002 | Companies House `07418033`, in liquidation | Held at the first check, refunded to the buyer |
| C · PO-1003 | Companies House `09729896`, accounts and confirmation statement overdue | Held, refunded |
| D · PO-1004 | GLEIF `391200JI69LS8L648F30`, LEI issued | Clean checks; fully paid (milestones 1 and 2 when due, Fri 20:16 and Sat 12:00); rose to Trusted, then Premium |
| E · PO-1005 | GLEIF `52990092KBQJF8QBGJ50`, LEI lapsed | Held, refunded |
| F · PO-1006 | Companies House `03778796`, A's supplier | Open on purpose: due 31 Oct 18:02 and not approved, so the tamper test always has an active order to run against (order id **5**) |

Every transaction, with its x402 payment and explorer link, is in [docs/evidence.md](docs/evidence.md).

## The tamper test

The contract must reject a manipulated record. Every case below has been run against the live contract (results in [docs/evidence.md](docs/evidence.md)):

| Attempt | Contract answer |
|---|---|
| A valid, fresh record | accepted |
| (a) one signed value edited (`active` → `liquidation`) | `WrongSigner` |
| (b) too old: timestamp moved back, or a genuine old record | `StaleResponse` |
| (c) another request: hash swapped, or a genuine record of another company | `WrongRequest` |
| (d) signed by a key that is not the expected Airnode | `WrongSigner` |
| The same valid record a second time | `Replayed` |

**Fastest, in one command** (Foundry, Node.js and jq; no keys, no money): `api3/scripts/judge-tamper.sh` deploys the contract on a local anvil chain, rejects four tampered records (edited value, too old, other request, wrong key), pays one valid record and rejects its replay. In a fresh clone, run `npm ci` in `api3/x402` first. Against the live v2 on Sepolia: `api3/scripts/judge-tamper.sh --live 5 <fresh record.json>` (simulated, no gas).

Run it yourself in one of three ways:

1. **In the browser.** Open the [Control Room](https://julienlmu.github.io/tumblockchain-powerpuffboys/) → **Verification lab** (locally `demo/control.html#lab`, see "Run it"), pick **PO-1006** (it stays open; PO-1001 closes after its last payment on Sat 15:30) and a scenario, or press **Run the tamper test**. The genuine old and other-company records run with nothing to load; for the other cases, load a fresh record under **Signed record → My own**. The earlier page `demo/judge.html` ("Try to break it") does the same. Each attempt is an `eth_call` of the live contract: no wallet, no gas.
2. **From a terminal, with nothing to buy.** Submit the genuine records bundled in [`api3/fixtures/`](api3/fixtures/). Needs Foundry and Node.js.
   ```sh
   cd api3
   export EVM_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com PULSE_PLUS_ADDRESS=0xf25Aae1772326C95294D1923399D55c658493DfC
   scripts/plus-submit.sh 5 fixtures/ch-03778796-202610301614.json   # genuine but old        -> REJECTED StaleResponse
   scripts/plus-submit.sh 5 fixtures/ch-07418033-202610301910.json   # genuine, other company -> REJECTED WrongRequest
   ```
3. **With a fresh record of your own** ($0.01 in test aUSD on Base Sepolia, free from [API3's faucet](https://api3dao.github.io/airnodehub-hackathon/faucet/)):
   ```sh
   cd api3
   # with EVM_RPC_URL and PULSE_PLUS_ADDRESS exported as in 2.
   PAYER_PRIVATE_KEY=0x… scripts/fetch-evidence.sh ch 03778796 response.json   # pays over x402, checks signer and request
   scripts/plus-submit.sh 5 response.json            # valid -> ACCEPTED clean
   scripts/plus-submit.sh 5 response.json value      # (a)   -> REJECTED WrongSigner
   scripts/plus-submit.sh 5 response.json stale      # (b)   -> REJECTED StaleResponse
   scripts/plus-submit.sh 5 response.json request    # (c)   -> REJECTED WrongRequest
   scripts/plus-submit.sh 5 response.json key        # (d)   -> REJECTED WrongSigner
   ```
   `plus-submit.sh` simulates by default; add `--send` to send a real transaction (then the replay answers `Replayed`). Order 5 (PO-1006) stays active; order 0 (PO-1001) only accepts records until its last milestone is paid on Sat 15:30.

## Screenshots

See the [Control Room screenshot gallery](docs/screenshots/README.md). These are desktop captures in sample mode; no
transaction was submitted.

## Run it

Prerequisites: [Foundry](https://getfoundry.sh/), Node.js 22.18 or newer (`nvm use` picks 24), Python 3.8 or newer, `jq` and `curl`.

```sh
git clone https://github.com/julienlmu/tumblockchain-powerpuffboys.git
cd tumblockchain-powerpuffboys
```

**The screens, against the live contract** (no keys):
```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory demo
```
- `http://localhost:8765/control.html` is the **Control Room**, the main screen: Operations (every order and why it pays or waits), Verification lab (the tamper test), Agent (what the agent did on chain), Judge kit (every command) and Settings. It finds the live v2 contract by itself.
- `http://localhost:8765/control.html?sample=1` shows sample data, with no chain needed.
- `http://localhost:8765/` is the buyer dashboard and `judge.html` is "Try to break it", the earlier screens.
- The same pages are hosted at https://julienlmu.github.io/tumblockchain-powerpuffboys/ (there the buyer dashboard is `dashboard.html`).

See [demo/README.md](demo/README.md) for the local-chain mode.

**Everything on a local chain** (free, public test keys only):
```sh
cd api3 && forge test                          # 115 contract tests, including every tamper case with real signed fixtures
./scripts/plus-local.sh                        # anvil + contract + six sample orders, writes api3/.local/plus-local.env
cd .. && python3 api3/agent/c2_check.py        # the agent end to end on the local chain: holds, payouts, stops, refunds
python3 api3/agent/pulse_agent.py run --fake --ticks 40   # the agent against an in-memory contract, simulated clock
```

**The agent against Sepolia:** copy `api3/agent/.env.example` to `api3/agent/.env` and fill in a key and the contract address. Then run `api3/agent/run-forever.sh`. `python3 api3/agent/c3_check.py` checks the live run read-only. Never commit `.env` files or keys.

## API3 track checklist

| Requirement | Where |
|---|---|
| AirnodeHub data is essential to a core feature | No milestone pays without a signed Companies House or GLEIF record; a failing record holds the money |
| A signed response goes to a deployed contract that checks signer, request and timing | `submitEvidence` in [`api3/src/SupplierPulsePlus.sol`](api3/src/SupplierPulsePlus.sol), live at the address above |
| A value bound to the response drives an on-chain action, with replay protection | Permit, payment, hold or refund; each digest is accepted once, and only records newer than the last count |
| A way for judges to submit their own responses | The Control Room's Verification lab (hosted, or `demo/control.html`), `api3/scripts/judge-tamper.sh` and `api3/scripts/plus-submit.sh` (above) |
| Who relies on the data | The buyer's money: the signed record is the only input that decides whether a milestone is paid |
| What goes wrong if it is forged | A forged "active, accounts filed" record pays a company that is being wound up; a forged negative record blocks an honest supplier |
| Data we wanted but could not find on AirnodeHub | The German Handelsregister and German insolvency notices (GLEIF covers German companies only when they have an LEI), and delivery confirmations from ERP systems |

## What a signature proves, and what it doesn't

The Airnode's signature proves that the register's API returned exactly this answer at this time, unaltered. It does not prove that the register is complete, that the supplier will deliver, or that it stays solvent. That is why every payment also needs the buyer's approval. The contract does not prove that a payout wallet belongs to the company, either: the buyer gets the wallet when it signs the contract with a supplier it has vetted, just as it gets an IBAN today.

## Repository map

| Path | What |
|---|---|
| [`api3/src/`](api3/src/) | The SupplierPulsePlus contract and the signature and JSON verification |
| [`api3/test/`](api3/test/) | Foundry tests |
| [`api3/scripts/`](api3/scripts/) | Deploy, order, fetch and judge scripts, and the local demo |
| [`api3/x402/`](api3/x402/) | Paid AirnodeHub fetch, request hashes, tamper and verify tools |
| [`api3/agent/`](api3/agent/) | The autonomous agent |
| [`demo/`](demo/) | The Control Room (main screen), the buyer dashboard and "Try to break it" |
| [`docs/SUPPLIERPULSE_PLUS.md`](docs/SUPPLIERPULSE_PLUS.md) | The full specification |
| [`docs/evidence.md`](docs/evidence.md) | Every on-chain transaction and test run |
| [`cardano-agent/`](cardano-agent/) | An earlier Cardano/Masumi experiment, not part of this submission |

## Team

Orhun (contract), Emre (data layer and judge tools), Julien (agent and specification), Batu (dashboard and judge page), Ulaş (story, pitch and video).

## Future work

### Privacy of order documents

Today the contract stores the order reference as a hash (`orderRef`), so the order itself is never written on chain. A production version would extend this to the full set of order documents: the contract text, PO line items and delivery terms stay off chain with the buyer and supplier, and only a salted hash of each document is anchored on chain. The salt matters, because short or predictable documents could otherwise be guessed and checked against the hash. Either party can later prove what was agreed by revealing the document and its salt.

Some data stays public by design:
- **Amounts:** the contract locks and pays the money itself, so the escrowed and released amounts are visible on chain.
- **Supplier payout wallet:** payments go to it, so it is visible.
- **Registry ID:** the Companies House number or LEI comes from a public register, so hiding it adds nothing.

Stronger privacy, such as hiding amounts and counterparties, would need zero-knowledge proofs or a private settlement layer. That is out of scope for this prototype.

### Order assistant in the Control Room

A chat panel in the Control Room where a buyer can ask plain questions such as "when was supplier X last paid?", "how much is this order worth?" or "when is the next payment due?". A language model (GPT 6 Luna) would answer only from data the dashboard already reads: the contract's on-chain state and the signed registry records. If the answer is not in that data, it says "not in the data" instead of guessing.

## License

MIT
