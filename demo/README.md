# SupplierPulse+ screens

Two static pages for `api3/src/SupplierPulsePlus.sol` (spec: `docs/SUPPLIERPULSE_PLUS.md` §6.4). No build step: HTML plus ethers 6.13.5.

| Page | For | What it does |
|---|---|---|
| `index.html` | buyers, the demo video | One card per order: protected remaining balance, milestones (paid, permit valid until, awaiting approval, not due, held, refunded), permit countdown, trust tier, last check with failed rules in plain words, refund countdown and "Claim now" when held, and the audit trail with the decoded signed data. Above the cards: the agent's autonomous transactions. |
| `judge.html` | judges | "Try to break it": pick an order, paste or load a signed response, press **Submit as is**, **(a) Edit value**, **(b) Too old**, **(c) Different request**, **(d) Wrong key** or **Replay**. The tampered response is built in the browser (same rules as `api3/x402/tamper.mjs`, §4.7). The verdict is the contract's own: an `eth_call` of `submitEvidence` from `0x…dEaD`, no wallet, no gas. A checklist shows each check in the contract's order and where it stops; a scoreboard keeps every attempt. |
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

## GitHub Pages

The branch includes [a workflow](../.github/workflows/pages.yml) that publishes a labeled sample landing page, dashboard, and judge console at `https://julienlmu.github.io/tumblockchain-powerpuffgirls/`. The repository does not currently have GitHub Pages enabled, so [the first workflow run](https://github.com/julienlmu/tumblockchain-powerpuffgirls/actions/runs/41105403302) failed before publishing. A repository administrator must go to **Settings → Pages → Build and deployment**, select **GitHub Actions**, and then push a change under `demo/` to trigger deployment.

After deployment, the sample dashboard will be at `https://julienlmu.github.io/tumblockchain-powerpuffgirls/demo/?sample=1` and the judge console at `https://julienlmu.github.io/tumblockchain-powerpuffgirls/demo/judge.html`. These pages do not imply that v2 is deployed; live contract verdicts require a configured v2 address.

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

`?sample=1` renders six orders from `sample/sample.js`: snapshots in the shape of the view functions, plus their events. Every state appears: paid, permit valid, awaiting approval, not due, permit expired, held (refund pending and open to anyone), refunded, fully paid, and the tiers Standard, Trusted and Premium. Amounts, wallets, ids and times are illustrative, and a purple banner says so.

If the CDN is unreachable, both pages load the bundled copy in `vendor/ethers.umd.min.js` (ethers 6.13.5, MIT, `vendor/ethers-LICENSE.md`), so sample mode works offline.

## Judge page notes

- **Samples** (`sample/responses.js`) are records signed with the public local test keys at a fixed time, so they are stale on purpose. Real fixtures come from `api3/fixtures/` (Emre) via "Upload file".
- **Fresh local record** (local chain only) signs a record in the browser with the anvil key of the order's registry, using the fields of `api3/x402/local-registry.json`.
- **Order of attempts for the video:** run all six as simulations first (nothing changes on chain), then **Send for real** with the valid record, then **Replay**. After a real send, (a) and (d) stop at an earlier check (`NotNewer`, `Replayed`), because they reuse the same timestamp or digest; the checklist shows this.
- **Send for real** uses MetaMask, or on the local chain the public anvil #3 agent key.
- CLI alternative: `api3/scripts/plus-submit.sh <order-id> response.json [value|stale|request|key|replay]` simulates by default. Add `--send` to broadcast; sending a tampered record creates a reverted transaction and spends gas.
- On the local chain the page mines one empty block before each simulation. `eth_call` runs against the latest block, and anvil only mines on transactions, so its clock can lag minutes behind and a fresh record would look like `FutureResponse`.

## Validation status

The current branch was exercised against a fresh local Anvil deployment:

- A clean signed record was accepted and submitted; replay and the `value`, `stale`, `request`, and `key` tamper cases were rejected.
- A buyer-approved milestone released **500 demo tokens** to the supplier after fresh clean evidence.
- A held order was refunded to the buyer and closed with no remaining balance.
- CLI status labels correctly distinguished clean and failed-rule booleans.
- The autonomous Python agent completed four local cycles: two milestone payouts, three holds including the supplier-wide stop, and four refunds. It used the free local registry and reported $0.00 spend; detailed local-only results are in [`docs/evidence.md`](../docs/evidence.md#autonomous-local-anvil-agent-run-30-october-2026).

These are local-chain results only. They are not Sepolia transactions and do not establish public-network deployment or paid live-agent behavior.

Current browser validation of this branch covers the no-chain sample mode and static judge data: the dashboard renders six orders without horizontal overflow at 375 px; the Companies House request-hash vector matches v1.1; all four judge samples recover to their expected local signers and match their request hashes; and the Companies House/GLEIF sample rules match their displayed failed-rule bits.

**Still unverified:** loading Emre's live fixtures against a v1.1 contract, Sepolia v2 (not deployed), and MetaMask transaction flows.
