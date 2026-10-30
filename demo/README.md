# SupplierPulse+ screens

Two static pages for `api3/src/SupplierPulsePlus.sol` (spec: `docs/SUPPLIERPULSE_PLUS.md` v1.1, §6.4). No build step: HTML plus ethers 6.13.5.

| Page | For | What it does |
|---|---|---|
| `index.html` | buyers, the demo video | One card per order: protected remaining balance, milestones (paid, permit valid until, awaiting approval, not due, held, refunded), permit countdown, verification history, last check with failed rules in plain words, refund countdown and "Claim now" when held, the supplier-wide stop and the no-data exit, and the audit trail with the decoded signed data. Above the cards: the agent's autonomous transactions. |
| `judge.html` | judges | "Try to break it": pick an order, paste or load a signed response, press **Submit as is**, **(a) Edit value**, **(b) Too old**, **(c) Different request**, **(d) Wrong key** or **Replay**, plus the real inputs **(b) Real old record** and **(c) Real, other company** (untouched signed records). The tampered response is built in the browser (same rules as `api3/x402/tamper.mjs`, §4.7). The verdict is the contract's own: an `eth_call` of `submitEvidence` from `0x…dEaD`, no wallet, no gas. A checklist shows each check in the contract's order and where it stops; a scoreboard keeps every attempt. |
| `v1.html` | fallback | The v1 order screen for `SupplierPulse.sol` (`0x91d7…74d7` on Sepolia). |

## Run

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory demo
```

| What | URL |
|---|---|
| Sample data, no chain | `http://localhost:8765/?sample=1` |
| Live, Ethereum Sepolia | `http://localhost:8765/?contract=<v2 address>&from=<deploy block>` |
| Local test chain (after `api3/scripts/plus-local.sh`) | `http://localhost:8765/?contract=<PULSE_PLUS_ADDRESS>&rpc=http://127.0.0.1:8545&from=0` |
| Judge page | `http://localhost:8765/judge.html?contract=<address>` (same `rpc` parameter) |

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

The dashboard reads the chain every 12 s; countdowns move every second. Light and dark follow the system; the ◐ button overrides it.

## Sample mode

`?sample=1` renders eight orders from `sample/sample.js`: snapshots in the shape of the view functions, plus their events. Every state appears: paid, permit valid, awaiting approval, not due, permit expired, held (refund pending and open to anyone), supplier-wide stop, no-data exit, refunded, fully paid, and the histories Standard, Trusted and Premium. Suppliers and signed fields are Emre's real demo suppliers; amounts, wallets and times are illustrative, and a purple banner says so.

If the CDN is unreachable, both pages load the bundled copy in `vendor/ethers.umd.min.js` (ethers 6.13.5, MIT, `vendor/ethers-LICENSE.md`), so sample mode works offline.

## Judge page notes

- **Samples** (`sample/responses.js`): the five real Airnode records from `api3/fixtures/` (Emre, fetched 30 Oct 16:07 to 16:14, old by now) and four records signed with the public local test keys at a fixed time. The real-input buttons use them untouched: (b) a record of the order's own supplier, (c) a record of another company of the same registry. Off the local chain the real Airnode records are preferred. A new fixture: regenerate the file or use "Upload file".
- **Fresh local record** (local chain only) signs a record in the browser with the anvil key of the order's registry, using the fields of `api3/x402/local-registry.json`.
- **Order of attempts for the video:** run all six as simulations first (nothing changes on chain), then **Send for real** with the valid record, then **Replay**. After a real send, (a) and (d) stop at an earlier check (`NotNewer`, `Replayed`), because they reuse the same timestamp or digest; the checklist shows this.
- **Send for real** uses MetaMask, or on the local chain the public anvil #3 agent key.
- On the local chain the page mines one empty block before each simulation. `eth_call` runs against the latest block, and anvil only mines on transactions, so its clock can lag minutes behind and a fresh record would look like `FutureResponse`.

## Checked (30 Oct 2026, ~17:25, spec v1.1)

Local anvil chain, `SupplierPulsePlus` v1.1 from `supplierpulse-plus` (`plus-local.sh`, 6 orders), records from Emre's `sign-local.mjs`:

- Judge page on order 0: valid record accepted (permit); (a) `WrongSigner`, (b) `StaleResponse`, (c) `WrongRequest`, (d) `WrongSigner`; real (b) `StaleResponse`, real (c) `WrongRequest`. A clean record signed before the supplier's failure gives `SupplierFailed` (cast). Earlier, on v1.0: Replay after **Send for real** gives `Replayed`.
- The §4.2 test vectors match in the browser, including the v1.1 Companies House vector `0x6e84…7f0f`, and so does the request hash of Emre's real fixture for `03778796`.
- Dashboard live: order 1 held with the supplier-wide stop, order 4 (same supplier) with the stop and the no-data exit, order 5 (no data) with the no-data countdown; earlier on v1.0 also paid, refunded and the agent panel. Desktop and 375 px phone width without horizontal scroll. Offline fallback to `vendor/` checked with an unreachable CDN.
- Sample mode, dark and light.

**Not checked yet:** Sepolia v2 (not deployed), MetaMask flows, real Airnode records against a contract that trusts the real Airnodes (they need Sepolia).
