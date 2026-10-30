# To do before submission (Sat 31 Oct, 15:00 Berlin)

From the security review findings of 30 Oct, each item checked against the code on `main` (aa031ad, same as the live v2 `0xf25Aae1772326C95294D1923399D55c658493DfC`). Tick an item and add a line to `docs/PROGRESS.md` when it is done.

Rule for tonight: no contract change, no new deployment, no dependency upgrade.

## Submission (blocks qualification)

- [ ] **Julien:** make the repository public and check it with a fresh public clone.
- [ ] **Julien + Ulaş:** rewrite the root `README.md` for SupplierPulse+ (API3): live v2 address, setup, demo and judge commands. It still describes the earlier Cardano / price-vault project. Update the "current status" in `CLAUDE.md` as well.
- [ ] **Ulaş:** bring the Devfolio, pitch and video texts from `ulas/plus-story` to `main` and update them. They still say v2 is not deployed and there is no agent evidence; both are no longer true (A and D paid, B, C and E refunded).
- [ ] **Team:** video of at most 2.5 minutes, Devfolio submission, contract address and network, judge script, tamper test.
- [ ] **Ulaş / Batu (optional):** the public dashboard and judge URLs return 404. If we link them, publish them from the current branch.

## Code fixes (small, no deployment)

- [ ] **Julien (F01):** the agent reads every order in `ordersLength` (`api3/agent/chain.py`, `snapshot`) and has no buyer or order filter, so anyone's orders can use up its paid fetches. Add an allowlist (e.g. `AGENT_ORDER_IDS` or the buyer address) and skip all other orders.
- [ ] **Julien / Emre (F07):** `api3/x402/airnode-fetch.mjs` allows up to `$0.05` per payment but records a fixed `priceUsd: '0.01'`. Set the limit to `$0.01` so both match.
- [ ] **Batu (F10):** `demo/index.html` treats a supplier as stopped whenever `lastBaseFailureAt > 0` (also on `batu/plus-ui`), even after newer clean evidence lets the contract pay again. Show "earlier failure on record" separately from "payment blocked now".
- [ ] **Julien:** merge `orhun/doc-tools` (document hash, verify and change report; works with the live v2). The hash script now fails on errors instead of printing an empty hash, and the language-model summary runs only with `--summary`.

## Say it correctly in the pitch (no code change)

- **Admin:** the admin can change the expected Airnode address and `maxAge` (`setAirnode`, `setMaxAge`). Only the order's document hash is locked, not the whole contract. In production: timelock or multisig.
- **Freshness:** `maxAge` (300 s) is the evidence age when it is submitted. The payment permit then stays valid for `permitTtl`, so the data can be older than 300 s at payment time.
- **No-data refund:** it means "no valid evidence within the agreed time", not "the API was proven to be down".
- **Agent:** `submitEvidence` and `release` are open to anyone, so if our agent stops, the supplier or a judge can make the same call.
- **Tamper video:** use a fresh held order and an unused signed response. A reused response gives `Replayed` or `NotNewer` instead of the intended error.

## Known limits, after the hackathon

- Agent spend is saved at the end of a tick, so a crash right after a paid fetch can lose it (F06).
- On an RPC failover the agent can send the same transaction a second time with a new nonce (F08). The contract's replay checks prevent a double payment.
- The `permitValid` view does not check the supplier-wide stop, which `release` does (F09).
- One signed response is accepted once across all orders, so another order can use it first (F19).
- No cancellation for an order that was never approved (F16). No bounds on order or milestone counts (F20). No zero or range checks on admin settings (F21).
- `zod` in the x402 dependency tree has a known advisory (GHSA-mrhx-c7xc-m3w5). Test x402 2.29.0 on a separate branch with a real paid fetch first (F03).
- `orhun/doc-hash` (two-party amendments, not deployed) still has the old hash-script bug. An amendment changes only the document hash, not the amount, due date or wallet.
