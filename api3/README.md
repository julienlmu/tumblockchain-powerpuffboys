# API3 track: PriceTriggeredVault

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
