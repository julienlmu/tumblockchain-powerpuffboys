# Status: Batu (role E: product & pitch)

Newest on top.

### 2026-10-30 ~12:56 · branch `batu/api3-setup`
- Done: the three open checks for #6 (mining). Batu ran a scratch script that asks for the keystore password and keeps the key in memory only. The x402 client is copied from the official starter.
- Spent: 0.01 aUSD, payment tx `0xf54d7b05d806a0e246472f3380438710f85020441797dca6cd5ec44b43eeaa91`. Balance now 9.99 aUSD.
- Results:
  - `historicalPrices` signs the price together with the requested moment (ISO 8601). Signer verified.
  - The request-hash formula with array parameters matches (`cast keccak`).
  - `nonEvmWalletBalances` for bitcoin returned 502 / upstream 404, not charged.
- Details in `docs/decision-sheet.md`, section "Results of the paid checks".

### 2026-10-30 ~13:00 · branch `batu/api3-setup`
- Done: API3 review of the mining payout idea (`docs/BRAINSTORMING.md` on `brainstorm/mining-payout-settlement`), added as section "#6" in `docs/decision-sheet.md`.
- Checked: AirnodeHub catalogue (no mining pool, hashrate or block reward data). Two free live calls, no aUSD spent: Nodary `latestFeeds` (DOGE, LTC, BTC, ADA in USD) and dRPC `priceSymbols` (621 symbols for `historicalPrices`, incl. DOGE, BTC, LTC, ADA). Read the request-hash rules in `/docs/from-api-to-contract`.
- Finding: the signed price covers only the valuation. The reward amount would be unsigned or simulated, which is weak on "signed data matters" (30%). The strong mechanism is `historicalPrices` at the reward's own timestamp, with the request hash built on-chain (anti-cherry-picking), plus the agent loop.
- Next: share with Ulaş and Orhun. Three open checks need one paid call each ($0.01 aUSD), and only with Batu's OK.

### 2026-10-30 ~12:46 · branch `batu/api3-setup`
- Done: Base Sepolia ETH from the Coinbase CDP faucet (0.0001 ETH). Minted 10 aUSD with `mintFromFaucet(10000000)`.
- Mint tx: `0xce7765c73a861212876f59dcf5968aeed3f52344321fe4de5b56a60c9b51216f`, https://sepolia.basescan.org/tx/0xce7765c73a861212876f59dcf5968aeed3f52344321fe4de5b56a60c9b51216f
- Verified on chain (`cast receipt`, `cast call`): status success, sender `0xA54506DcE89ff9561534c76C043505a1a484FB4c`, balance now 10 aUSD and 0.0000994 ETH. The mint cost about 0.0000006 ETH.
- Wallet `batu-test` is ready as x402 payer and for testnet transactions. Faucet limit reached (10 aUSD per account).
- Next: wait for Ulaş's idea branch. Meanwhile, read the AirnodeHub listings it will need (free GET only).

### 2026-10-30 ~12:45 · branch `batu/api3-setup`
- Done: Batu created an encrypted Foundry keystore `batu-test` (`~/.foundry/keystores/batu-test`, password known only to Batu).
- Address (public): `0xA54506DcE89ff9561534c76C043505a1a484FB4c` (Base Sepolia). https://sepolia.basescan.org/address/0xA54506DcE89ff9561534c76C043505a1a484FB4c
- Checked: balance 0 ETH, 0 aUSD.
- Next: Batu gets Base Sepolia ETH from a faucet, then mints 10 aUSD.

### 2026-10-30 ~12:45 · branch `batu/api3-setup`
- Context: Ulaş is working on an idea that uses Cardano and API3 together, on his own branch. Until then Batu prepares what every option needs: an EVM test wallet with Base Sepolia ETH and aUSD.
- Checked (read-only `cast call` on `https://sepolia.base.org`, chain id 84532):
  - aUSD token: `0xbeA34973e5f67F18F656A2C6070C64326C791808`, symbol `aUSD`, 6 decimals. Source: the faucet page bundle (https://api3dao.github.io/airnodehub-hackathon/faucet/) and the chain.
  - `faucetLimit()` = 10000000, i.e. **10 aUSD per account**. Minting is `mintFromFaucet(uint256)` sent from the wallet itself, so the wallet **needs Base Sepolia ETH for gas first**.
  - The x402 payment itself needs no ETH (https://api3dao.github.io/airnodehub-hackathon/docs/).
- Base Sepolia ETH faucets (https://docs.base.org/base-chain/network-information/network-faucets): Coinbase CDP (up to 0.1 ETH / 24 h), Alchemy (free account), QuickNode, thirdweb, ethfaucet.com.
- Next: Batu creates an encrypted Foundry keystore (`cast wallet new batu-test`, password typed by Batu, key never in chat or git), gets ETH from a faucet, then mints aUSD.

### 2026-10-30 ~12:20 · branch `batu/api3-setup`
- Done: `git fetch origin && git rebase origin/main`, no conflicts. Main had a new commit from Julien (`af864ac`, pay-on-pass Cardano agent).
- Done: after the rebase, moved Batu's PROGRESS entries back to the top of the log. Marked decision-sheet fact 2 as outdated, because `af864ac` now delivers a result only when the vault executed.
- Next: push `batu/api3-setup` after Batu's OK. The branch also carries the four `batu/decision-sheet` commits, since those are not on `main` yet.

### 2026-10-30 ~12:25 · branch `batu/api3-setup`
- Done: installed Foundry 1.8.7 (forge, anvil, cast; official `foundryup`, binaries hash-verified) into `~/.foundry/bin`, and pnpm 12.16.1 via `npm install -g pnpm`.
- Verified: `cd api3 && forge test` passes 15/15. `./scripts/local-demo.sh` runs on anvil: tamper `value`, `stale` and `request` are rejected, the valid response executes, the replay is rejected, and `agent-run.sh` returns `executed: true`.
- **Bug (for Orhun):** the wrong-key tamper case does not run with Foundry 1.8.7. `api3/scripts/submit.sh:24` reads `cast wallet new --json | jq -r '.[0].private_key'`, but 1.8.7 wraps the output as `{"schema_version":1,"success":true,"data":[...]}`. jq fails with `Cannot index object with number`, so tamper case (d) is never submitted. Possible fix that works with old and new Foundry: `jq -r '(.data // .)[0].private_key'`. Not changed yet, since it is Orhun's script. `cast send --json` is not affected.
- Resolved (~12:13): Batu added `~/.foundry/bin` to `~/.zshenv`. Checked in a new shell: `forge --version` gives 1.8.7.
- Wrong-key bug left to Orhun (Batu's call).

### 2026-10-30 ~12:10 · branch `batu/api3-setup` (from `origin/batu/decision-sheet`)
- Role: API3 track with Orhun (tentative). Ulaş + Julien own Cardano.
- Waiting: idea decision with Orhun, #0 price vault vs #3 supplier approval gate (see `docs/decision-sheet.md`). No feature code until both confirm.
- Found: Batu's laptop has Node v24.19.0, but no Foundry (`forge`, `anvil`, `cast`) and no `pnpm`. Both are needed for `api3/` and the API3 starter. Not installed yet, waiting for Batu's OK.
- Found: `.gitignore` lacked `.local/` and `cache/`, which `CLAUDE.md` §7 requires. Added both (`out` was already there).
- Next: once the idea is confirmed, install Foundry, run `forge test` in `api3/`, then fetch one live signed response.

### 2026-10-30 ~11:50
- Team split (tentative): Batu + Orhun on API3, Ulaş + Julien on Cardano.

### 2026-10-30 ~11:40 · branch `batu/decision-sheet`
- Done: added API3 judging weights (real use case 40%, novelty 10% "beyond the unchanged starter") and the projections answer to `docs/decision-sheet.md`.
- Finding: the official starter is already a Nodary ETH/USD consumer, so the price vault (#0) sits close to the starter. Company-registry escrow (#3) is on API3's own idea list.
- Blocked: push to GitHub fails with 403 (Claude GitHub App access). Commits are local only.

### 2026-10-30 ~11:20 · branch `batu/decision-sheet`
- Done: `docs/decision-sheet.md`, comparing ideas #0–#5 (customer, payment tied to result, real vs mocked, build risk, Cardano/API3 fit).
- Verified: Masumi refund flow (no automatic "pay only if check passes"); AirnodeHub listings and prices for GLEIF, Companies House, Nodary, CoinGecko and AeroDataBox.
- Blocked: the setup patch `0001-config-PR-only-workflow-...patch` was not found (not in the cloud container, Google Drive, Gmail, or any GitHub branch/PR). It is probably only on Batu's laptop.
- Next: wait for Julien's idea and track decision, then write the README skeleton, Devfolio text, video script, pitch and judge Q&A.
