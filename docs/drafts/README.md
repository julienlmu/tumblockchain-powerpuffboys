# SupplierPulse

> Your supplier was approved last month. That should not approve today's payment.

**DRAFT (Batu, 30 Oct).** This will replace the root `README.md` once the team agrees. Everything marked `TODO` does not exist yet. Facts and hashes come from `docs/evidence.md`, `docs/decision-sheet.md` and `docs/samples/`.

SupplierPulse pays a supplier in stages. Before **every** stage, an agent fetches the supplier's current, signed company status from the official register through API3 AirnodeHub. A smart contract checks that evidence and only then releases the money.
- Supplier still active: the stage is paid.
- Supplier in liquidation or dissolved: the rest of the money stays locked and goes back to the buyer.

The buyer hires the agent on Cardano. The agent is paid per check through Masumi escrow, and only if the check really ran.

Built at the TUM Blockchain & AI Hackathon 2026 for the **Cardano** and **API3** tracks.

## The problem

A company checks a supplier once, at onboarding. After that, advances and instalments run for months. If the supplier goes into liquidation in the meantime, nobody re-checks before the next transfer, and the money is gone.

## How it works

```
Buyer ──hires agent, pays tADA into Masumi escrow──▶ Cardano agent (preprod)
                                                        │
                       before each payment stage:       ▼
                       AirnodeHub (Companies House) ──signed {"status":"active"}──▶ agent
                       (paid per call via x402, aUSD on Base Sepolia)
                                                        │ submits evidence
                                                        ▼
                       SupplierPulse contract (EVM testnet)
                         checks signer, request (this company), freshness, replay
                         "active"  → permit for this stage only → stage paid to the supplier wallet
                         otherwise → order held → buyer refunds the rest
                                                        │
                       check ran and was verified on chain
                                                        ▼
                       Masumi escrow releases the tADA to the agent (else: refund to the buyer)
```

What the contract enforces (`api3/src/SupplierPulse.sol`):
- **Signer:** the response must be signed by the Companies House Airnode `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF`.
- **Request:** the response must answer *this order's* company. Another company's valid record is rejected.
- **Freshness:** responses older than `maxAge` are rejected. `TODO`: final value.
- **No replay:** each signed response is usable once, and only newer evidence is accepted.
- **Permit:** an "active" status unlocks exactly one stage, for one supplier wallet, until the permit expires. Paying uses it up, so the next stage needs new evidence.

## Tracks

| Track | What qualifies us | Where |
|---|---|---|
| Cardano: Agentic Commerce | Paid jobs through Masumi escrow on preprod, pay-on-pass with automatic refund | `cardano-agent/`, `docs/evidence.md` |
| API3: Any API in your contract | Signed Companies House data decides every payment; tamper test | `api3/`, `docs/samples/companies-house/` |

## Repository

```
api3/            Solidity contracts (Foundry): SupplierPulse, plus the earlier ETH/USD vault
cardano-agent/   Masumi seller agent (Python): pay-on-pass gate, refunds, proofs
docs/            plan and log (PROGRESS.md), evidence, decision sheet, signed response samples
```

## Quick start

Needs: Node.js 24, Foundry, Python 3, `jq`. The Cardano part also needs Docker, a Blockfrost preprod key and test ADA.

```bash
git clone https://github.com/julienlmu/tumblockchain-powerpuffgirls.git
cd tumblockchain-powerpuffgirls/api3
forge test -vv
```

`TODO`: the exact SupplierPulse run commands (local demo, testnet deploy) once they exist. Today `api3/README.md` covers the ETH/USD vault.

Cardano agent: see `cardano-agent/README.md` (Masumi setup, `agent.py`, `buy_job.py`, `receipt.py`).

## For judges

### API3: run the tamper test yourself

`TODO`: judge script for SupplierPulse (submit a response, optionally tampered). The vault version is `api3/scripts/submit.sh`.

Real signed responses to start from are in `docs/samples/companies-house/`:

| Company | Signed status | Expected |
|---|---|---|
| `09729896` | active | stage paid |
| `07418033` | liquidation | order held, buyer refunded |
| `12493325` | dissolved | order held |

| Tamper | Expected rejection |
|---|---|
| (a) status edited, e.g. `liquidation` → `active` | `WrongSigner` |
| (b) response older than `maxAge` | `StaleResponse` |
| (c) another company's response | `WrongRequest` |
| (d) signed with a different key | `WrongSigner` |
| same response twice | `Replayed` |

Deployed contract: `TODO` address and network.

### Cardano: paid jobs on preprod

See `docs/evidence.md` for every tx hash with explorer links. Examples:
- Paid job that passed: lock `cef9996c…49370a2`, result `4d622fc4…d6e9a34`.
- Job that failed its check and was refunded automatically: lock `457707ea…5194820`, refund withdrawn `0fefbb1b…bd89ffe2b`.

SupplierPulse app on Cardano (`apps/supplier-pulse.json`, branch `supplier-pulse`): tested on preprod with a simulated EVM side. A held supplier pays the agent (job `09fa4cf7…`); no data refunds the buyer (job `79293455…`). `TODO`: a paid job against the deployed contract.

## Trust assumptions and limits

- **The agent is the bridge between the two chains.** The Cardano escrow and the EVM payment are each verifiable on their own explorer, but they are linked by our agent, not trustlessly.
- **A signature proves where the data came from, not that it is true.** The status is exactly what the UK register (Companies House) says, delivered unaltered by the Airnode.
- **Registry status is not delivery.** The buyer still approves each stage, for example delivery accepted.
- **UK companies only in v1.** AirnodeHub has no German register (Handelsregister, insolvency notices).
- Testnets only: Cardano preprod, Base Sepolia (aUSD for x402), and the contract's EVM testnet.

## Team

powerpuffgirls: Julien, Ulaş (Cardano), Orhun, Batu (API3). `TODO`: fifth team member and final roles. MIT license.
