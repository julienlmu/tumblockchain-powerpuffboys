# SupplierPulse demo screen

One static page (`index.html`) that shows each order the way the buyer sees it: the **protected remaining balance**, which stages are paid or held, whether a payment permit is valid and until when, the last signed register status, and the next step. Below each order is its on-chain history with links to the explorer.

It is read-only: it calls the view functions `orderStatus` and `orderInfo` of `api3/src/SupplierPulse.sol` and reads the contract's events. No wallet, no keys.

## Run

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory demo
```

Then open one of:

| What | URL |
|---|---|
| Live, Ethereum Sepolia | `http://localhost:8765/?contract=<SupplierPulse address>&orders=0,1` |
| Sample data (no chain) | `http://localhost:8765/?sample=1` |

The settings panel on the page sets the same values.

| Parameter | Default | Meaning |
|---|---|---|
| `contract` | none | SupplierPulse address |
| `rpc` | `https://ethereum-sepolia-rpc.publicnode.com` | any JSON-RPC URL that allows browser requests |
| `orders` | `0,1` | order IDs to show, in this order |
| `companies` | `09729896,07418033,12493325` | Companies House numbers. The page computes each one's request hash and shows the number instead of the hash. |
| `from` | latest block − 9000 | first block searched for events. publicnode refuses ranges of 20000 blocks, so set the deploy block if the contract is older than ~30 h. |

The page reads the chain every 12 s. The permit countdown updates every second.

## Sample mode

`?sample=1` shows two orders without a chain, with a purple banner saying so. The register statuses are the real signed Companies House records in `docs/samples/companies-house/` (`09729896` active, `07418033` liquidation). Amounts, wallets and times are made up. Use it only as a fallback, and say so in the video.

## Checked (30 Oct 2026, ~14:30)

- Live mode on a local anvil chain against `SupplierPulse.sol` from branch `supplier-pulse`. The contract trusted the real Companies House Airnode `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` and received the real signed responses from `docs/samples/companies-house/`:
  - order 0 (`09729896`, `active`): stage 1 paid, then the screen showed the permit as used up
  - order 1 (`07418033`, `liquidation`): order held, 0.003 protected
  - order 2 (`12493325`): no evidence yet
- Sample mode, desktop and phone width, light and dark theme. No console errors.
- publicnode Sepolia RPC allows browser requests (`access-control-allow-origin: *`). `eth_getLogs` works for 10000 blocks and is refused for 20000.
- **Not checked yet:** a SupplierPulse contract on Sepolia, because it is not deployed yet.

Note from the local test: a permit's lifetime starts at the timestamp of the evidence, not at submission (`SupplierPulse.sol`, `submitEvidence`). If the evidence is already older than `permitTtl`, `checkAndRelease` reverts with `PermitExpired` instead of paying. With `maxAge` well below `permitTtl` this cannot happen.
