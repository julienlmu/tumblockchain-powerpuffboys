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

## Order documents

### Privacy of order documents

Today the contract stores the order reference as a hash (`orderRef`), so the order itself is never written on chain. This extends to the full set of order documents: the contract text, PO line items and delivery terms stay off chain with the buyer and supplier, and only a salted hash of each document is anchored on chain. The salt matters, because short or predictable documents could otherwise be guessed and checked against the hash. Either party can later prove what was agreed by revealing the document and its salt.

The scripts support this today, with no contract change, because `orderRef` is a free 32-byte field (run from `api3/`):

```
scripts/plus-doc-hash.sh contract.pdf          # prints ORDER_DOC_HASH and a new random ORDER_DOC_SALT
ORDER_DOC_HASH=0x… scripts/plus-create-order.sh ch 03778796 0xSupplier 500,1000 +1200,+3600
scripts/plus-verify-doc.sh <order id> contract.pdf <salt>   # MATCH or MISMATCH against the chain
```

Keep the salt with the document: without it the agreement cannot be proven. `plus-doc-hash.sh` exits non-zero if the file cannot be hashed, and `plus-create-order.sh` refuses an `ORDER_DOC_HASH` that is set but not a 32-byte hash instead of falling back to `ORDER_REF`. Large files are streamed with OpenSSL 3.2+; without it (e.g. macOS LibreSSL) files up to about 1 MiB work.

Some data stays public by design:
- **Amounts:** the contract locks and pays the money itself, so the escrowed and released amounts are visible on chain.
- **Supplier payout wallet:** payments go to it, so it is visible.
- **Registry ID:** the Companies House number or LEI comes from a public register, so hiding it adds nothing.

### Two levels of document integrity

1. **Locked document hash (works on the live v2 contract today).** The salted hash goes into the order's `orderRef`, which is written once in `createOrder` and can never change afterwards. Create it with `scripts/plus-doc-hash.sh`, pass it as `ORDER_DOC_HASH` to `scripts/plus-create-order.sh`, and check a document later with `scripts/plus-verify-doc.sh`. If anyone edits the document, the check reports a mismatch, so a changed document can never be passed off as the agreed one.
2. **Amendable agreement with full history (built and tested on branch `orhun/doc-hash`, not deployed).** Real contracts change: delivery dates move and quantities are adjusted. In amendable mode the document hash may only change when BOTH the buyer and the supplier sign the new hash, and every version is kept on chain. This needs a contract change, so the live v2 contract does not have it.
3. **Change report.** `scripts/plus-verify-doc.sh <order id> <file> <salt> [agreed file]`: on a mismatch with the agreed file given, it runs `scripts/plus-doc-diff.sh`, which prints a line diff computed locally, so the document never leaves the machine. Only `scripts/plus-doc-diff.sh --summary <agreed> <presented>` sends the diff (which can contain prices and parties) to a language model for a short plain-language summary, using `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` from `api3/.env`. The report is informational only and never affects payments.

## Future work

Stronger privacy, such as hiding amounts and counterparties, would need zero-knowledge proofs or a private settlement layer. That is out of scope for this prototype.

## License

MIT
