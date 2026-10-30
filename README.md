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
2. **Amendable agreement with full history (built, branch `orhun/doc-hash`).** Real contracts change: delivery dates move and quantities are adjusted. An order can therefore be created in amendable mode (`createAmendableOrder`, or `ORDER_DOC_MODE=amendable scripts/plus-create-order.sh`). Its document hash may only change when BOTH the buyer and the supplier sign the new hash (`scripts/plus-amend-doc.sh sign` for each party, then `scripts/plus-amend-doc.sh submit`). Every version stays on chain (`documentHistory`), and signatures cannot be replayed: the signed digest binds the chain id, the contract, the order id, the version and the previous hash. Locked mode (`createOrder`) stays the default, and there the hash can never change.
3. **Change report.** `scripts/plus-verify-doc.sh <orderId> <file> <salt> [agreed file]` prints MATCH or MISMATCH. On a mismatch with the agreed file given, it runs `scripts/plus-doc-diff.sh`, which shows a line diff and, if an optional language-model API key is set in `api3/.env`, a short plain-language summary of what changed. The report is informational only and never affects payments.

Note: this two-mode version is on branch `orhun/doc-hash` and is NOT deployed. The live v2 contract (`0xf25Aae1772326C95294D1923399D55c658493DfC`) has locked mode only, via `orderRef`.

## License

MIT
