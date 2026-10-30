# SupplierPulse+

**Your supplier was approved last month. That should not approve today's payment.**

SupplierPulse+ is a prototype for milestone-based supplier payments gated by fresh, signed public-registry evidence. Before a milestone can be released, an agent fetches a signed Companies House or GLEIF record from API3 AirnodeHub, and an Ethereum contract checks the signer, request, timestamp, replay status, and buyer-selected rules. The buyer separately approves the milestone; registry evidence does not prove delivery.

> **Hackathon prototype — testnets only.** SupplierPulse+ is not a production escrow, credit score, insolvency prediction, or guarantee of supplier performance.

## Try it

The v2 integration is in progress on the `supplierpulse-plus` branch. Use the existing v1 test flow until the v2 contract and demo tools are merged.

### Existing v1 test flow

Requires [Foundry](https://getfoundry.sh/) and `jq`:

```sh
cd api3
forge test
./scripts/pulse-local-demo.sh
```

The existing v1 contract is deployed on Ethereum Sepolia at [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7). It checks a Companies House status field only. See [`api3/README.md`](api3/README.md) and [the v1 evidence](docs/evidence.md#supplierpulse-live-run-ethereum-sepolia-2026-10-30).

### SupplierPulse+ demo (when integration is merged)

The planned v2 dashboard and judge page are `demo/index.html` and `demo/judge.html`. The judge CLI is `api3/scripts/plus-submit.sh`. The intended local flow:

```sh
cd api3
./scripts/plus-local.sh
source .local/plus-local.env
./scripts/fetch-local.sh ch 01234567 response.json
./scripts/plus-submit.sh 0 response.json
```

The local signer and registry fixtures are explicitly test-only. Never use Anvil keys or addresses on a public network. To try the tamper cases, use the value, stale, request, key, and replay modes documented in [`docs/SUPPLIERPULSE_PLUS.md`](docs/SUPPLIERPULSE_PLUS.md#47-command-line-tools).

**v2 contract:** deployment address and transaction are pending; this README must be updated from [`docs/evidence.md`](docs/evidence.md) after the Sepolia deployment. Do not treat the v1 address above as the v2 contract.

## How it works

1. A buyer creates an order with a supplier registry ID, payout wallet, milestones, due dates, rules, and a permit lifetime. The full balance is locked in the contract.
2. Before a payment, the agent pays $0.01 over x402 on Base Sepolia for a signed projected registry response from API3 AirnodeHub.
3. The Ethereum Sepolia contract verifies the expected Airnode, request hash, freshness, timestamp order, and that the signed digest has not been used.
4. A clean record grants a permit for exactly the next milestone. The buyer must also approve that milestone before anyone can release it.
5. A failed record holds the order. A verified base-status failure also blocks older permits across that supplier's other orders. If data stays unavailable after an approved milestone is overdue beyond the grace period, anyone can return the remaining balance to the buyer.
6. Accepted base-status records update the supplier's shared verification history. Higher tiers reduce monitoring frequency; they never extend permits or relax the evidence freshness limit.

```text
Companies House / GLEIF
          │ signed response; x402 payment on Base Sepolia
          ▼
 API3 AirnodeHub ─────► Agent ─────► SupplierPulse+ contract (Ethereum Sepolia)
                                        │
                              fresh evidence + buyer approval
                                        ▼
                              milestone paid or balance held
```

## Registries and rules

- **Companies House:** company status must be `active`. Optional buyer rules require accounts and the confirmation statement not to be overdue. Current insolvency is reflected by company status; the deprecated insolvency-history field is not used.
- **GLEIF:** entity status must be `ACTIVE`. The optional rule requires LEI registration status `ISSUED`.
- The request hash binds the signed response to the requested supplier and projected fields. The contract submits the exact signed bytes, not a reconstructed JSON object.

The selected registries do not cover every business or risk. For example, the prototype does not directly cover the German Handelsregister or German insolvency notices; GLEIF applies only to entities with an LEI. A registry signature proves what the registry API returned, not that the data is complete, that a supplier will deliver, or that a company will remain solvent.

## Trust tiers and demo parameters

| Tier | Clean base-check streak | Production re-check interval | Demo monitoring interval |
|---|---:|---:|---:|
| Standard | 0–2 | 1 day | 10 minutes |
| Trusted | 3–5 | 3 days | 30 minutes |
| Premium | 6+ | 7 days | 60 minutes |

Only newer verified base-status records update a supplier's history, and a clean record counts at most once per tier gap. Buyer-specific filing rules do not affect the shared tier; a failed base status resets the streak and stops older permits across the supplier's orders. Tiers change only the agent's monitoring interval, not permit lifetime. The demo uses a **5-minute tier-count gap** and **10-minute refund grace period**; these are demo settings, not recommended production settings. Evidence remains subject to the 300-second freshness limit.

The demo denomination is `1 token = 10^12 wei = 0.000001 ETH`. These amounts are deliberately tiny testnet values.

## Agent and data costs

The agent implementation is in [`api3/agent/`](api3/agent/) and its schedule, budgets, and failure handling are documented in [`docs/agent.md`](docs/agent.md). It checks before due dates and less often between them based on the supplier's tier, enforces spend and gas limits, retries transient failures, quarantines request/signer mismatches, and simulates writes before sending. The overnight Sepolia run still needs verified evidence before being claimed as demonstrated.

Each registry check is specified at $0.01 in aUSD on **Base Sepolia**. The supplier-payment contract runs on **Ethereum Sepolia**, so data payment and supplier settlement are separate testnet flows.

## Network and contracts

| Contract | Network | Address |
|---|---|---|
| SupplierPulse v1 (fallback) | Ethereum Sepolia, chain `11155111` | [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7) |
| SupplierPulse+ v2 | Ethereum Sepolia, chain `11155111` | Pending deployment; see [`docs/evidence.md`](docs/evidence.md) |
| x402 data payment | Base Sepolia, chain `84532` | aUSD contract: `0xbeA34973e5f67F18F656A2C6070C64326C791808` |

## Setup

For the API3/Foundry v1 flow:

- Node.js 24 (`nvm use`)
- [Foundry](https://getfoundry.sh/)
- `jq` and `curl`

The full SupplierPulse+ workflow also uses Python 3.8+ for the agent, Node.js 22.18+ for the x402 data tools, and environment values copied from the committed `*.env.example` files. Never commit `.env` files, API keys, mnemonics, or private keys. Do not make paid calls outside the approved hackathon budgets.

```sh
git clone --branch supplierpulse-plus https://github.com/julienlmu/tumblockchain-powerpuffgirls.git
cd tumblockchain-powerpuffgirls
nvm use
cd api3
forge test
```

For environment variables and deploy/test instructions, see [`api3/README.md`](api3/README.md), [`docs/SUPPLIERPULSE_PLUS.md`](docs/SUPPLIERPULSE_PLUS.md), and the workstream guides as they become available.

## Repository map

| Path | Contents |
|---|---|
| `api3/src/` | Solidity contracts and signature/data verification |
| `api3/test/` | Foundry tests |
| `api3/scripts/` | Contract, fetch, judge, and local-demo scripts |
| `api3/agent/` | Autonomous agent implementation |
| `demo/` | Planned dashboard and judge tamper page |
| `docs/SUPPLIERPULSE_PLUS.md` | Frozen build specification and integration runbook |
| `docs/evidence.md` | Testnet transaction evidence |
| `docs/research.md` | Sourced context and prior-art notes |
| `cardano-agent/` | Earlier experiment; not part of this API3-track submission |

## Evidence and submission

- [Build plan and status](docs/PROGRESS.md)
- [Build specification](docs/SUPPLIERPULSE_PLUS.md)
- [On-chain evidence](docs/evidence.md)
- [Research notes](docs/research.md)
- [90-second pitch and judge Q&A](docs/pitch.md)
- [Devfolio draft](docs/drafts/devfolio.md)
- [Video script](docs/drafts/video-script.md)

This project is entered in the API3 **“Any API in your contract”** track. Do not claim it is the first registry-gated escrow or supplier-risk product. The intended contribution is the combination of signed, fresh registry evidence with milestone-scoped permits, buyer rules, trust tiers, and a budgeted agent.

## License

MIT. See [`LICENSE`](LICENSE).
