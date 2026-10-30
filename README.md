# tumblockchain-powerpuffgirls

TUM Blockchain hackathon project: a paid Cardano agent (Masumi/Sokosumi) that fetches signed ETH/USD data from API3 AirnodeHub and executes a verified action on an EVM vault contract.

**Plan, status and team log: [docs/PROGRESS.md](docs/PROGRESS.md).** Update it with every push.

**Judges, SupplierPulse+ tamper test in one command** (Foundry, Node.js and jq; no keys, no money): `api3/scripts/judge-tamper.sh` deploys the contract on a local anvil chain, rejects four tampered records (edited value, too old, other request, wrong key), pays one valid record and rejects its replay. Against the live v2 on Sepolia: `api3/scripts/judge-tamper.sh --live <orderId> <fresh record.json>` (simulated, no gas). In the browser: [demo/judge.html](demo/judge.html).

## Prerequisites

- Node.js 24 (`nvm use` picks it up from `.nvmrc`)
- Sokosumi CLI 1.1.0: `npm install --global @masumi_network/sokosumi@1.1.0` (1.0.4 no longer works against preprod)
- PostgreSQL ≥ 13 (only for the Masumi Payment Service)
- A Cardano preprod wallet with test ADA ([faucet](https://docs.cardano.org/cardano-testnets/tools/faucet)) and a free [Blockfrost](https://blockfrost.io/) preprod key
- API3 contracts: [Foundry](https://getfoundry.sh/) and pnpm

## Setup

```sh
git clone https://github.com/julienlmu/tumblockchain-powerpuffgirls.git
cd tumblockchain-powerpuffgirls
nvm use
```

Run commands and on-chain evidence: [docs/evidence.md](docs/evidence.md).

## Future work

### Privacy of order documents

Today the contract stores the order reference as a hash (`orderRef`), so the order itself is never written on chain. A production version would extend this to the full set of order documents: the contract text, PO line items and delivery terms stay off chain with the buyer and supplier, and only a salted hash of each document is anchored on chain. The salt matters, because short or predictable documents could otherwise be guessed and checked against the hash. Either party can later prove what was agreed by revealing the document and its salt.

Some data stays public by design:
- **Amounts:** the contract locks and pays the money itself, so the escrowed and released amounts are visible on chain.
- **Supplier payout wallet:** payments go to it, so it is visible.
- **Registry ID:** the Companies House number or LEI comes from a public register, so hiding it adds nothing.

Stronger privacy, such as hiding amounts and counterparties, would need zero-knowledge proofs or a private settlement layer. That is out of scope for this prototype.

## License

MIT
