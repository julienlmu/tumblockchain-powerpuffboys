# tumblockchain-powerpuffgirls

TUM Blockchain hackathon project: a paid Cardano agent (Masumi/Sokosumi) that fetches signed ETH/USD data from API3 AirnodeHub and executes a verified action on an EVM vault contract.

**Plan, status and team log: [docs/PROGRESS.md](docs/PROGRESS.md).** Update it with every push.

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

## License

MIT
