# API3 track: SupplierPulse

Milestone payments to a supplier where **every payment needs fresh, signed registry evidence**.
Plan: [`docs/SUPPLIERPULSE.md`](../docs/SUPPLIERPULSE.md). Contract: `src/SupplierPulse.sol`.

**Live on Sepolia:** [`0x91d7dbae109029b2b1245179a68ac362799674d7`](https://sepolia.etherscan.io/address/0x91d7dbae109029b2b1245179a68ac362799674d7). Paid run, held run and all four tampers rejected: [`docs/evidence.md`](../docs/evidence.md#supplierpulse-live-run-ethereum-sepolia-2026-10-30).
The no-data refund path below is a source change and is **not present in this already-deployed contract**; it requires a new deployment before it protects live funds. The v1 agent detects this older ABI, logs a warning, and keeps operating without automatic refunds until the updated contract is deployed.

A buyer locks the whole order (e.g. 500 + 1,500) for one supplier, identified by its Companies House number.
Before each milestone the agent fetches the supplier's status from the Companies House Airnode on AirnodeHub
(`getCompanyProfile`, $0.01 paid over x402) and submits it:

- `active`: the contract issues a **payment permit** for exactly the next milestone, this order, this supplier
  wallet and this amount, valid for `permitTtl`. The payment uses it up, so every milestone needs new evidence.
- anything else (`dissolved`, `liquidation`, ...): the remaining balance is **held**; the buyer can take it back
  with `refundRemaining`.
- after the 48-hour grace from first approval, an approved next milestone can be refunded if it has no current
  valid permit. Anyone can trigger that refund, but the funds always go to the buyer. A valid permit prevents
  the no-data exit; `noDataRefundAt(orderId)` exposes the eligibility time.
- before approving the next milestone, the buyer can cancel an active order and recover its remaining balance;
  other callers cannot cancel it.
- a milestone is paid only if the buyer approved it (`approveMilestone`): registry evidence does not prove delivery.

The contract builds the request hash itself from the order's company number
(`companyRequestHash`, `keccak256('["getCompanyProfile",[["company_number","<n>"]],[["status","/company_status"]]]')`),
so an order can only accept that company's profile.

| Check | Error |
|---|---|
| signer is the stored Companies House Airnode `0x392228E5CCA260313e5ed337Ed3561B59A1e4bFF` | `WrongSigner(address)` |
| request is this order's company profile (hash built on chain) | `WrongRequest(bytes32,bytes32)` |
| `now - timestamp <= maxAge` (300 s), max 60 s in the future | `StaleResponse`, `FutureResponse` |
| each signed response once, timestamps increase per order | `Replayed(bytes32)`, `NotNewer` |
| permit exists, is for this milestone, not expired | `NoValidPermit`, `PermitExpired` |

Signed data looks like `{"status":"liquidation"}`. Three real signed responses (active, liquidation, dissolved)
are tests (`test_real*`).

### Run

```sh
forge test                          # contract regression tests
./scripts/pulse-local-demo.sh       # anvil: 4 tampers rejected, milestone paid, replay rejected,
                                    # supplier in liquidation -> held, buyer refund; no-data refund boundary
```

On a testnet (`.env`: `EVM_RPC_URL`, `EVM_PRIVATE_KEY`, `PULSE_ADDRESS`, `PAYER_PRIVATE_KEY` with aUSD on Base Sepolia):

```sh
forge script script/DeploySupplierPulse.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --slow --gas-estimate-multiplier 800
id=$(scripts/pulse-create-order.sh 09729896 <supplier address> 500000000000,1500000000000)
scripts/pulse-approve.sh "$id" 0
ORDER_ID=$id scripts/supplier-agent.sh   # last line: {"outcome":"Paid"|"AwaitingApproval"|"Held"|"NoData"|"Rejected",...}
scripts/pulse-status.sh "$id"            # paid, remaining, permit, last status
```

### For judges: tamper test

```sh
scripts/supplier-fetch.sh 09729896 resp.json            # fresh signed profile ($0.01 aUSD via x402)
ORDER_ID=<id> scripts/pulse-submit.sh resp.json value     # status edited      -> WrongSigner
ORDER_ID=<id> scripts/pulse-submit.sh resp.json stale     # 1 h older          -> StaleResponse
ORDER_ID=<id> scripts/pulse-submit.sh resp.json request   # other company      -> WrongRequest
ORDER_ID=<id> scripts/pulse-submit.sh resp.json key       # random signer      -> WrongSigner
ORDER_ID=<id> scripts/pulse-submit.sh resp.json           # valid              -> paid / held
```

### For the Cardano agent

`cardano-agent/apps/supplier-pulse.json` runs `scripts/supplier-agent.sh` with `ORDER_ID` and `COMPANY_NUMBER`.
`Paid`, `AwaitingApproval` and `Held` are finished jobs: stopping a payment is as correct as making one.

---

# Fallback: PriceTriggeredVault

A vault that pays out ETH when ETH/USD crosses a threshold. The price can only come from an
**AirnodeHub signed response**, which the contract checks on-chain:

| Check | How | Error |
|---|---|---|
| Signer | `ecrecover` must equal the configured `airnode` (low-s enforced) | `WrongSigner(address)` |
| Request | `requestHash` must equal the configured ETH/USD request | `WrongRequest(bytes32)` |
| Freshness | `now - timestamp <= maxAge` (default 300 s), max 60 s in the future | `StaleResponse`, `FutureResponse` |
| Price age | the price's own `updatedAt` must also be within `maxAge` (a fresh signature can carry an old value) | `StalePrice` |
| No replay | each signed digest is usable once, and timestamps must increase | `Replayed(bytes32)`, `NotNewer` |
| Untouched value | the price is parsed from the exact signed bytes, so any edit breaks the signature | `WrongSigner(address)` |

Signature scheme (from the AirnodeHub docs):
`digest = keccak256(abi.encodePacked(bytes32 requestHash, uint256 timestamp, bytes data))`, signed with EIP-191
(`"\x19Ethereum Signed Message:\n32" || digest`). `data` is the signed string, e.g. `{"price":2443.95,"updatedAt":1792403240691}`.
The vault reads `price` (stored with 18 decimals) and `updatedAt` (ms).

Data source: the Nodary Airnode on AirnodeHub (free, no rate limit), signer `0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0`.
Request (request hash `0x180eae9387bb66a72380e61ebe0a00d19f8414a716a37ebe1df124b66acfff66`):

```sh
curl -X POST https://airnode-nodary.fly.dev/ -H 'Content-Type: application/json' \
  --data '{"operation":"latestFeeds","parameters":{"name":"ETH/USD"},"responseProjection":{"price":"/ETH~1USD/value","updatedAt":"/ETH~1USD/timestamp"}}'
```

## Deployment

| | |
|---|---|
| Network | Ethereum Sepolia (chain 11155111) |
| Vault | [`0xBC68DB972A62cFf3161e600d92C475c29c22886A`](https://sepolia.etherscan.io/address/0xBC68DB972A62cFf3161e600d92C475c29c22886A) |
| Airnode (Nodary) | `0xE70f1e8b22a21e4Bb5188918a3033341b281E4c0` |
| Request hash (ETH/USD) | `0x180eae9387bb66a72380e61ebe0a00d19f8414a716a37ebe1df124b66acfff66` |
| Max age | 300 s |

Live checks on 2026-10-30 with real Nodary responses: a valid response was accepted
([tx](https://sepolia.etherscan.io/tx/0x4227aacc11db497a3409d7be3fcda08408acb009a6753b92e013dcf68afbe20a)),
and the replay plus all four tamper cases (value, stale, request, key) were rejected by the contract.
The agent entry point executed an order at ETH/USD 2239.595
([tx](https://sepolia.etherscan.io/tx/0xacc48a007b568e3e953e094a6e59a9249cfeeb61090d2660567411cc2aa67d7b)).

## Layout

```
src/AirnodeVerifier.sol      digest + EIP-191 recover
src/PriceParser.sol          number from the signed JSON bytes
src/PriceTriggeredVault.sol  orders, submitPrice, submitAndExecute, submitAndTryExecute
test/PriceTriggeredVault.t.sol  16 tests incl. every tamper case
script/Deploy.s.sol          deploy (env driven)
scripts/fetch-eth-usd.sh     get a signed ETH/USD response from Nodary on AirnodeHub
scripts/submit.sh            submit a response, optionally tampered (judges use this)
scripts/sign-response.sh     sign your own response with your own key
scripts/agent-run.sh         entry point for the Cardano agent
scripts/local-demo.sh        full flow on anvil, no network needed
```

The tests do not use forge-std (a small cheatcode interface lives in `test/utils/Vm.sol`), so there is nothing to install.

## Run

Needs Foundry, `jq`, `curl`.

```sh
cd api3
forge test -vv            # unit + tamper tests
./scripts/local-demo.sh   # anvil: deploy, 4 tamper attempts rejected, valid submit, replay rejected, agent run
```

## Deploy your own (any EVM testnet)

```sh
cp .env.example .env && $EDITOR .env      # EVM_RPC_URL, EVM_PRIVATE_KEY
set -a; . ./.env; set +a
./scripts/fetch-eth-usd.sh resp.json && cat resp.json   # airnode and requestHash should match the values above
# Nodary signer + ETH/USD request by default; Sepolia needs a high gas multiplier for the deploy
forge script script/Deploy.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --slow --gas-estimate-multiplier 800
```

Put the deployed address in `VAULT_ADDRESS`.

## For judges: submit your own response

```sh
export EVM_RPC_URL=... EVM_PRIVATE_KEY=... VAULT_ADDRESS=...
./scripts/fetch-eth-usd.sh me.json        # your own fresh signed response
./scripts/submit.sh me.json               # accepted, latestPrice updates
./scripts/submit.sh me.json               # replay: rejected
./scripts/submit.sh me.json value         # price digit changed: rejected
./scripts/submit.sh me.json stale         # timestamp moved back 1h: rejected
./scripts/submit.sh me.json request       # other requestHash: rejected
./scripts/submit.sh me.json key           # re-signed with a random key: rejected
```

Or get one by hand with the curl above and fill `me.json` yourself. You can also hand-edit `me.json` (fields `requestHash`, `timestamp`, `data` as hex, `signature`) and submit it.
To use your own signer, deploy a vault with `AIRNODE_ADDRESS` = your address and create responses with
`SIGNER_KEY=0x... ./scripts/sign-response.sh "{\"price\":2950,\"updatedAt\":$(date +%s)000}"`.

## For the Cardano agent

```sh
THRESHOLD_USD=3000 EVM_RPC_URL=... EVM_PRIVATE_KEY=... VAULT_ADDRESS=... ./scripts/agent-run.sh
```

Creates an order "pay `ORDER_VALUE_WEI` (default 1e12 wei) to `BENEFICIARY` (default: sender) if ETH/USD < THRESHOLD_USD"
(`BELOW=false` flips it to >), fetches a signed price, calls `submitAndTryExecute`. Logs go to stderr, the last stdout line is:

```json
{"txHash":"0x...","price":"2950.1","executed":true,"chainId":11155111,"vault":"0x...","orderId":0}
```

Exits non-zero if anything fails, including a rejected signature. `RESPONSE_FILE=resp.json` skips the fetch.

## Notes

- Sepolia ETH for gas: Google Cloud Web3 faucet (Google login, no mainnet balance needed). Some public RPCs are flaky; Tenderly worked.
