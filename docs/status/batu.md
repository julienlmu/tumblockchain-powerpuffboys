# Status: Batu (role E: product & pitch)

Newest on top.

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
