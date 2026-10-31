# SupplierPulse screens

**Control Room:** `control.html` combines Operations, Verification lab, Agent, Judge kit and Settings, each with Simple and Complex views. The selected [Paper visual treatment](../docs/ui/paper/README.md) uses locally hosted IBM Plex Sans and a warm light palette. Run the server below and open `/control.html?sample=1` for sample data, or `/control.html` for the existing live-data flow.

Static pages for `api3/src/SupplierPulsePlus.sol` (spec: `docs/SUPPLIERPULSE_PLUS.md` v1.1, §6.4). No build step: HTML plus ethers 6.13.5.

| Page | For | What it does |
|---|---|---|
| `index.html` | buyers, the demo video | One card per order: protected remaining balance, milestones (paid, permit valid until, awaiting approval, not due, held, refunded), permit countdown, verification history, last check with failed rules in plain words, refund countdown and "Refund to buyer (MetaMask)" when held or open to anyone, the supplier-wide stop and the no-data exit, and the audit trail with the decoded signed data. Above the cards: the agent's autonomous transactions. |
| `simple.html` | judges, the demo video | "Try to break it", simple view: one signed record (signed in the browser on the local test chain, pasted or uploaded elsewhere), **Run the tamper test**, and five rows: the real record accepted, (a)–(d) rejected with the contract's error, then **Send for real, then replay**. Same `eth_call` of `submitEvidence` from `0x…dEaD` as `judge.html`. The **Simple / Detailed** switch in the header moves between the two views and keeps `contract`, `rpc` and `order`. |
| `judge.html` | judges | "Try to break it", detailed view: pick an order, paste or load a signed response, press **Submit as is**, **(a) Edit value**, **(b) Too old**, **(c) Different request**, **(d) Wrong key** or **Replay**, plus the real inputs **(b) Real old record** and **(c) Real, other company** (untouched signed records). The tampered response is built in the browser (same rules as `api3/x402/tamper.mjs`, §4.7). The verdict is the contract's own: an `eth_call` of `submitEvidence` from `0x…dEaD`, no wallet, no gas. A checklist shows each check in the contract's order and where it stops; a scoreboard keeps every attempt. |
| `v1.html` | fallback | The v1 order screen for `SupplierPulse.sol` (`0x91d7…74d7` on Sepolia). |

## Run

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory demo
```

| What | URL |
|---|---|
| **Live, Ethereum Sepolia (no address needed)** | `http://localhost:8765/` and `http://localhost:8765/judge.html` |
| Sample data, no chain | `http://localhost:8765/?sample=1` |
| Live, a given contract | `http://localhost:8765/?contract=<v2 address>&from=<deploy block>` |
| Local test chain (after `api3/scripts/plus-local.sh`) | `http://localhost:8765/?contract=<PULSE_PLUS_ADDRESS>&rpc=http://127.0.0.1:8545&from=0` |
| Judge page | `http://localhost:8765/judge.html?contract=<address>` (same `rpc` parameter) |

**Without an address, both pages find the contract themselves.** They look at the last 80 transactions of Orhun's deployer `0xEb3E…ce41` (§3.2), compute the address each one would have created, and take the newest contract that returns the v1.1 test vector for `requestHashFor(0, "09729896")` (§4.2). Only SupplierPulse v1.1 returns it. So after the C3 deploy the pages show v2 with no edit, and a later redeploy is picked up too. The dashboard then puts the address in the URL, so the link can be shared. While no v2 exists on Sepolia, the dashboard links to the v1 screen, and the judge page runs against the live v1 contract (§7 fallback).

Opening the files straight from disk also works (`file://`); sample data is a `.js` file for that reason.

### Dashboard parameters (also in the Settings panel)

| Parameter | Default | Meaning |
|---|---|---|
| `contract` | none | SupplierPulsePlus address |
| `rpc` | `https://ethereum-sepolia-rpc.publicnode.com` | any JSON-RPC URL that allows browser requests |
| `orders` | all | order ids, comma-separated |
| `agent` | Sepolia: `0xED34…253a` (Julien), local: anvil #3 | address whose transactions count as the agent's |
| `from` | latest block − 9000 | first block searched for events. Set the deploy block. Longer ranges are read in 9000-block steps (publicnode refuses 20000) |
| `unit` | `1000000000000` | wei per token (§2.5) |
| `names` | the demo order names | extra order names, comma-separated. Orders store `orderRef = keccak256(name)` (`plus-create-order.sh`), which cannot be decoded, so the page matches known names by hash. `LOCAL-<id>` from `plus-local.sh` is matched too |
| `sample` | off | `1` shows the sample data |

The dashboard reads the chain every 12 s; countdowns move every second. Light and dark follow the system; the **Theme** button (auto, light, dark) overrides it.

## Sample mode

`?sample=1` renders eight orders from `sample/sample.js`: snapshots in the shape of the view functions, plus their events. Every state appears: paid, permit valid, awaiting approval, not due, permit expired, held (refund pending and open to anyone), supplier-wide stop, no-data exit, refunded, fully paid, and the histories Standard, Trusted and Premium. Suppliers and signed fields are Emre's real demo suppliers; amounts, wallets and times are illustrative, and a purple banner says so.

If the CDN is unreachable, both pages load the bundled copy in `vendor/ethers.umd.min.js` (ethers 6.13.5, MIT, `vendor/ethers-LICENSE.md`), so sample mode works offline.

## Judge page notes

- **Samples** (`sample/responses.js`): the five real Airnode records from `api3/fixtures/` (Emre, fetched 30 Oct 16:07 to 16:14, old by now) and four records signed with the public local test keys at a fixed time. The real-input buttons use them untouched: (b) a record of the order's own supplier, (c) a record of another company of the same registry. Off the local chain the real Airnode records are preferred. A new fixture: regenerate the file or use "Upload file".
- **Fresh local record** (local chain only) signs a record in the browser with the anvil key of the order's registry, using the fields of `api3/x402/local-registry.json`.
- **Order of attempts for the video:** run all six as simulations first (nothing changes on chain), then **Send for real** with the valid record, then **Replay**. After a real send, (a) and (d) stop at an earlier check (`NotNewer`, `Replayed`), because they reuse the same timestamp or digest; the checklist shows this.
- **Send for real** uses MetaMask, or on the local chain the public anvil #3 agent key. After a rejected simulation the button reads **Send anyway as a real transaction**: it sends with a fixed gas limit (gas estimation would refuse), so the attempt appears as a failed transaction on Etherscan with the same error, as §4.7 wants for the video. It costs a little Sepolia gas.
- **v1 mode.** Against `SupplierPulse.sol` (detected automatically: v1 has `airnode()`, v2 has `airnodeOf`) the page reads orders through v1's views, uses v1's status-only request for (c), and picks the real v1 records (status only, fetched 30 Oct ~13:48) for the real-input buttons.
- On the local chain the page mines one empty block before each simulation. `eth_call` runs against the latest block, and anvil only mines on transactions, so its clock can lag minutes behind and a fresh record would look like `FutureResponse`.

## Video and launch checklist (for whoever runs it)

**C3 (Sat 00:00).** Nothing to do for these pages: once Orhun deploys v2, `http://localhost:8765/` and `judge.html` find it. Check that the meta line says "Live on Ethereum Sepolia" with the new address. If GitHub Pages is on, the same pages work there, because they only need a browser and a public RPC.

**Video (Sat 11:00 to 13:00), tamper part.**
1. Open `judge.html`, pick order A.
2. **(b) Real old record** and **(c) Real, other company**: genuine records, untouched, rejected with `StaleResponse` and `WrongRequest`.
3. Load a fresh record of A (`api3/scripts/fetch-evidence.sh ch 03778796 r.json`, then "Upload file"). **Submit as is**: accepted. **(a)** and **(d)**: rejected with `WrongSigner`.
4. For each rejection that should show on Etherscan, press **Send anyway as a real transaction** (MetaMask on Sepolia), and keep the tx links for `docs/evidence.md`.
5. **Send for real** the valid record, then **Replay**: `Replayed`.

**Keep that order (Emre's note).** Attack a fresh record *before* it is sent for real. Once it is accepted, (a) reuses its timestamp and gets `NotNewer`, and (d) reuses its digest and gets `Replayed`, instead of `WrongSigner`. That is correct, but not what the video should show. The same happens if **the agent** submits a newer record for A between your fetch and your attacks (it re-checks A on its own). So run steps 3 and 4 right after the fetch, which also stays inside the 300 s `maxAge`. If (a) shows `NotNewer`, fetch a new record and repeat. The checklist on the page marks where the contract stopped.

**If something looks wrong.** The page shows the RPC error in a red banner. publicnode is the default RPC; `?rpc=https://sepolia.gateway.tenderly.co` is the alternative (it refuses bursts). With no network at all, use `?sample=1` and say in the video that it is sample data.

## Checked (30 Oct 2026, ~17:40, spec v1.1)

On **Ethereum Sepolia** (read only):
- Without an address, the dashboard searched Orhun's deployer, found no v2 yet and linked to v1; the judge page fell back to the live v1 contract `0x91d7…74d7`, read its 2 orders and the real Companies House Airnode as signer.
- Real v1 records against live v1 order 0: **(b) Real old record → `StaleResponse`**, **(c) Real, other company (`07418033`) → `WrongRequest`**; the signature recovers to the real Airnode `0x3922…4bFF`.

On a test chain with Sepolia's chain id (anvil `--chain-id 11155111 --block-time 2`), v1.1 deployed **from Orhun's deployer address** (impersonated) between other transactions:
- Both pages found the contract with no address given; the dashboard decoded the order names.
- **MetaMask flows**, with an EIP-1193 test wallet in the page that forwards to the chain (the same calls MetaMask gets: `eth_requestAccounts`, `eth_estimateGas`, `eth_sendTransaction`, receipts): judge **Send for real** included (status 1); **Replay** then **Send anyway** reverted on chain (status 0), as simulated; dashboard **Refund to buyer (MetaMask)** by the buyer on a held order refunded it (simulation first, then the transaction).

Local anvil chain (31337), `SupplierPulsePlus` v1.1 from `supplierpulse-plus` (`plus-local.sh`, 6 orders), records from Emre's `sign-local.mjs`:

- Judge page on order 0: valid record accepted (permit); (a) `WrongSigner`, (b) `StaleResponse`, (c) `WrongRequest`, (d) `WrongSigner`; real (b) `StaleResponse`, real (c) `WrongRequest`. A clean record signed before the supplier's failure gives `SupplierFailed` (cast). Earlier, on v1.0: Replay after **Send for real** gives `Replayed`.
- The §4.2 test vectors match in the browser, including the v1.1 Companies House vector `0x6e84…7f0f`, and so does the request hash of Emre's real fixture for `03778796`.
- Dashboard live: order 1 held with the supplier-wide stop, order 4 (same supplier) with the stop and the no-data exit, order 5 (no data) with the no-data countdown; earlier on v1.0 also paid, refunded and the agent panel. Desktop and 375 px phone width without horizontal scroll. Offline fallback to `vendor/` checked with an unreachable CDN.
- Sample mode, dark and light.

**Not checked yet:** v2 on Sepolia itself (not deployed until C3) and a real MetaMask extension (the test wallet speaks the same interface).
