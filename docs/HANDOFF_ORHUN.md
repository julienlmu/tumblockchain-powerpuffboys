# Handoff for Orhun's coding agent: what is left on Orhun's side

*Written Sat 31 Oct 2026, 10:20 CET, from Julien's side. Repo: `julienlmu/tumblockchain-powerpuffgirls`; the conflict notes below were checked against `main` at `05b185a`.*

You work for Orhun on the SupplierPulse project (API3 track, TUM Blockchain & AI Hackathon). This file lists only the work that depends on Orhun: his branches, his scripts, and the demo steps that need the keys in his local `api3/.env`. Everything else is covered by other people.

## Ground rules for this session

- **Freeze at 11:00.** Code lands before 11:00. After that, only docs, evidence and demo runs. Hard deadline 15:00, submission 14:30, live judging 15:00–17:00.
- **Land** means: merge into `main`, push `main`, then push the same commit to `supplierpulse-plus` so the two stay equal. Plain pushes only. If `main` moved, merge again. Run `git rev-parse --show-toplevel` before every `git add` and confirm it is the repo root.
- **The contract stays as deployed:** v2 `0xf25Aae1772326C95294D1923399D55c658493DfC` on Ethereum Sepolia.
- **The live agent runs on Julien's laptop.** Test agent behaviour on a local anvil chain (`api3/scripts/plus-local.sh`). A second agent on the v2 contract would buy duplicate records and send duplicate transactions.
- **Keys stay in `api3/.env`:** `BUYER_PRIVATE_KEY`, `PAYER_PRIVATE_KEY`. Read them into the environment; never print or commit them.
- **Ask Orhun before every paid call.** `fetch-evidence.sh` pays $0.01 in aUSD on Base Sepolia.
- **Visible name is "SupplierPulse"** (no "+"). The contract keeps its name `SupplierPulsePlus`.

## Part 1. Code, before the 11:00 freeze (in this order)

Tasks 1 and 2 are required. Task 3 is strongly wanted. Tasks 4 and 5 are docs and may land after 11:00.

### Task 1. Land `orhun/lab-interactive` (the "edit the signed data yourself" lab)

It merges into `main` without conflicts. Julien's side already tested it merged on top of `main` against local anvil:
- the untouched record gives "Every check passed";
- `"active"` → `"liquidation"` gives `WrongSigner` at "Signed by the expected Airnode";
- no console errors.

**Done when** it is landed and the same check passes again from `main` (`demo/control.html#lab` on the local chain).

### Task 2. Land `orhun/final-fixes`

This branch is what the demo depends on:
- `judge-tamper.sh` (the one-command tamper test);
- `plus-quick-orders.sh` (orders due in 2 minutes) and `plus-warp.sh`;
- F07 (`airnode-fetch.mjs` capped at $0.01);
- the x402 tools fixed for paths with spaces;
- F10 on the buyer dashboard.

It conflicts with current `main` in three files. Resolve them like this:

| File | Resolution |
|---|---|
| `docs/PROGRESS.md` | Keep both sides' entries |
| `README.md` | Keep `main`'s text and add the branch's one judge paragraph (`judge-tamper.sh`), with "SupplierPulse+" changed to "SupplierPulse" |
| `demo/index.html` | Start from **`main`'s version**: it holds Batu's redesigned dashboard and tonight's security fixes. Re-apply only the F10 change from the branch: `failedAt`, `supplierRecovered`, the new `supplierStopped` (`o.lastCheck <= failedAt(o)`), `pastFailure`, the extra message branch for a recovered supplier, the "Earlier failure on record" strip, and the `.past-failure` CSS. On `main`, `supplierStopped` is at about line 750, still the old one-liner. |

`orhun/plus-ui-f10` carries the same F10 fix on an older dashboard. Task 2 replaces it, so leave that branch unmerged.

**Done when:**
- `api3/scripts/judge-tamper.sh` prints "All cases behaved as expected" on anvil;
- `demo/index.html?sample=1` shows a supplier whose newer clean record came after a failure as "Earlier failure on record", and a still-failing supplier as stopped;
- `demo/index.html` still has the security fixes (`P.safeRpc`, `P.walletSigner` and the `integrity` attributes are present);
- it is landed.

### Task 3. Quick demo orders show their names on the website

`plus-quick-orders.sh` sets `ORDER_REF="PO-Q<HHMM>-A Motor supply"`, and `plus-create-order.sh` stores `keccak(ORDER_REF)`. The website can only name an order when either:
- the hash matches its fixed list `DEMO_NAMES` in `demo/common.js`, or
- `orderRef` is a readable bytes32 string. It then splits the name with `/^([A-Z]+-\d+)\s+(.+)$/`, so the reference must be letters, a hyphen and digits (`PO-1001`), then a space, then the name.

Today the quick orders appear as bare `#12`, `#13`, … in the Control Room. One fix that stays inside Orhun's scripts:
- `plus-create-order.sh` passes an `ORDER_REF` that is already 32-byte hex through unchanged;
- `plus-quick-orders.sh` sends `cast format-bytes32-string "PO-<HHMM><n> Motor supply"` (and "Gearbox", "Cable harness (DE)"). This stays unique per run and under 31 characters.

These are dummy demo names, so having them readable on chain is fine.

**Done when** a run on local anvil shows the three new orders in the Control Room's Operations screen with their PO number and name, distinct from PO-1001 to PO-1005. Then land it.

### Task 4. README for judges (`orhun/readme-final`)

Merging this branch replaces `main`'s longer README with Orhun's one-page version. Only `docs/PROGRESS.md` conflicts. Before landing:
- confirm with Julien that the one-page version is the final README;
- rename "SupplierPulse+" to "SupplierPulse" (README and `docs/DEVFOLIO.md`);
- name the Control Room as the main screen: `http://localhost:8765/control.html`, served with `python3 -m http.server 8765 --bind 127.0.0.1 --directory demo`;
- point to `judge-tamper.sh` only once Task 2 is on `main`.

**Done when** a fresh clone of `main` can follow the README to the Control Room and to `judge-tamper.sh` without guessing.

### Task 5. Land `orhun/pitch-customer` (`docs/PITCH_CUSTOMER.md`)

Only `docs/PROGRESS.md` conflicts; keep both entries. Rename "SupplierPulse+" in the title.

**Done when** it is landed, so Ulaş's pitch and video can use the persona and the sourced numbers.

The branches `orhun/change-report-page`, `orhun/doc-tools` and `orhun/doc-hash` are outside the pitch requirements. Leave them unmerged before the freeze.

## Part 2. Demo runs on Orhun's machine (video 11:00–13:00, booth 15:00–17:00)

These steps need `BUYER_PRIVATE_KEY` and `PAYER_PRIVATE_KEY`, which only Orhun's `api3/.env` holds.

### Step 1. Check the wallets (read-only)

- **Buyer:** Sepolia ETH for every run of `plus-quick-orders.sh` (0.002 ETH plus gas each). Plan for about 8 runs: video takes plus booth pitches.
- **Payer:** aUSD on Base Sepolia (`0xbeA34973e5f67F18F656A2C6070C64326C791808`) for about 10 fresh records at $0.01. Top-up: https://api3dao.github.io/airnodehub-hackathon/faucet/

**Done when** both balances cover the plan, or Orhun has been told the shortfall.

### Step 2. Before each video take and each booth pitch: fresh orders

Run `api3/scripts/plus-quick-orders.sh`. It needs `EVM_RPC_URL`, `BUYER_PRIVATE_KEY`, `PULSE_PLUS_ADDRESS`, `DEMO_SUPPLIER_1` and `DEMO_SUPPLIER_2`. It creates three orders:
- **QA:** healthy UK company, paid by the agent about 2 minutes later;
- **QB:** UK company in liquidation, held at the agent's first check;
- **QD:** healthy LEI company, paid by the agent.

Run it about 3 minutes before the pitch. The agent refunds held orders by itself about 10 minutes after the hold, so QB has to be fresh when it is shown.

**Done when** the three order ids and the printed timeline are noted for the presenter.

### Step 3. The buyer refunds QB live

Only the buyer can refund immediately. Pick one route and rehearse it once:
- the Control Room's Refund button, with the buyer's test account imported into MetaMask by Orhun himself;
- `api3/scripts/plus-refund.sh <QB id>` in a terminal.

**Done when** one rehearsal refund succeeded and its transaction link opens on Sepolia Etherscan.

### Step 4. The live tamper scene

Follow `docs/LAB_RECORDING.md` (on `orhun/lab-interactive`). One timing rule beyond it:
- the fresh record must be newer than the agent's last check of the order you show, so fetch it **after** the agent has checked that order;
- use it within 5 minutes, or the contract answers `StaleResponse` instead of `WrongSigner`.

**Done when** the scene shows the untouched record passing, the edited record rejected with `WrongSigner`, and the tamper test at 4/4.

### Step 5. Evidence

Add every transaction used in the video to `docs/evidence.md`, with its explorer link: order creation, payments, hold, refund, and any tamper transactions sent for real.

**Done when** every transaction shown in the video has a line there.
