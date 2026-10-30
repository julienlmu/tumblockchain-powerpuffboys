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

## Future work

### Privacy of order documents

Today the contract stores the order reference as a hash (`orderRef`), so the order itself is never written on chain. A production version would extend this to the full set of order documents: the contract text, PO line items and delivery terms stay off chain with the buyer and supplier, and only a salted hash of each document is anchored on chain. The salt matters, because short or predictable documents could otherwise be guessed and checked against the hash. Either party can later prove what was agreed by revealing the document and its salt.

The scripts already support this today, with no contract change, because `orderRef` is a free 32-byte field:

```
scripts/plus-doc-hash.sh contract.pdf          # prints ORDER_DOC_HASH and a new random ORDER_DOC_SALT
ORDER_DOC_HASH=0x… scripts/plus-create-order.sh ch 03778796 0xSupplier 500,1000 +1200,+3600
scripts/plus-verify-doc.sh <order id> contract.pdf <salt>   # MATCH or MISMATCH against the chain
```

Keep the salt with the document: without it the agreement cannot be proven.

Some data stays public by design:
- **Amounts:** the contract locks and pays the money itself, so the escrowed and released amounts are visible on chain.
- **Supplier payout wallet:** payments go to it, so it is visible.
- **Registry ID:** the Companies House number or LEI comes from a public register, so hiding it adds nothing.

Stronger privacy, such as hiding amounts and counterparties, would need zero-knowledge proofs or a private settlement layer. That is out of scope for this prototype.

### Two levels of document integrity

1. **Salted document hash (built).** The order's `orderRef` is written once, in `createOrder`, and no function can change it afterwards, so the anchored hash is fixed for the life of the order. The document itself stays off chain; if anyone edits it, `plus-verify-doc.sh` reports a mismatch. This already gives tamper evidence: a changed document can never be passed off as the agreed one.
2. **Amendable agreement with full history (future work).** Real contracts change: delivery dates move and quantities are adjusted, so a document that can never be amended is impractical. The next step is an amendment function that accepts a new document hash only when both the buyer and the supplier sign it, and appends it next to the previous hashes instead of replacing them. A one-sided change is then impossible, and every agreed change stays visible on chain. This needs a contract change and a redeploy, so it is not part of the live demo.

## License

MIT
