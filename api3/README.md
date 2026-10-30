# API3 track: PriceTriggeredVault

A vault that pays out ETH when ETH/USD crosses a threshold. The price can only come from an
**AirnodeHub signed response**, which the contract checks on-chain:

| Check | How | Error |
|---|---|---|
| Signer | `ecrecover` must equal the configured `airnode` (low-s enforced) | `WrongSigner(address)` |
| Request | `requestHash` must equal the configured ETH/USD request | `WrongRequest(bytes32)` |
| Freshness | `now - timestamp <= maxAge` (default 300 s), max 60 s in the future | `StaleResponse`, `FutureResponse` |
| No replay | each signed digest is usable once, and timestamps must increase | `Replayed(bytes32)`, `NotNewer` |
| Untouched value | the price is parsed from the exact signed bytes, so any edit breaks the signature | `WrongSigner(address)` |

Signature scheme (from the AirnodeHub docs):
`digest = keccak256(abi.encodePacked(bytes32 requestHash, uint256 timestamp, bytes data))`, signed with EIP-191
(`"\x19Ethereum Signed Message:\n32" || digest`). `data` is the raw response body, e.g. `{"ethereum":{"usd":2987.41}}`.
The vault reads the number after `"usd":` and stores it with 18 decimals.

## Layout

```
src/AirnodeVerifier.sol      digest + EIP-191 recover
src/PriceParser.sol          number from the signed JSON bytes
src/PriceTriggeredVault.sol  orders, submitPrice, submitAndExecute, submitAndTryExecute
test/PriceTriggeredVault.t.sol  15 tests incl. every tamper case
script/Deploy.s.sol          deploy (env driven)
scripts/fetch-eth-usd.sh     get a signed ETH/USD response from AirnodeHub
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

## Deploy (Base Sepolia, chain 84532)

```sh
cp .env.example .env && $EDITOR .env      # EVM_RPC_URL, EVM_PRIVATE_KEY
set -a; . ./.env; set +a
./scripts/fetch-eth-usd.sh resp.json && cat resp.json   # gives airnode + requestHash
export AIRNODE_ADDRESS=$(jq -r .airnode resp.json) REQUEST_HASH=$(jq -r .requestHash resp.json)
forge script script/Deploy.s.sol --rpc-url "$EVM_RPC_URL" --broadcast
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

You can also hand-edit `me.json` (fields `requestHash`, `timestamp`, `data` as hex, `signature`) and submit it.
To use your own signer, deploy a vault with `AIRNODE_ADDRESS` = your address and create responses with
`SIGNER_KEY=0x... ./scripts/sign-response.sh '{"ethereum":{"usd":2950}}'`.

## For the Cardano agent

```sh
THRESHOLD_USD=3000 EVM_RPC_URL=... EVM_PRIVATE_KEY=... VAULT_ADDRESS=... ./scripts/agent-run.sh
```

Creates an order "pay `ORDER_VALUE_WEI` (default 1e12 wei) to `BENEFICIARY` (default: sender) if ETH/USD < THRESHOLD_USD"
(`BELOW=false` flips it to >), fetches a signed price, calls `submitAndTryExecute`. Logs go to stderr, the last stdout line is:

```json
{"txHash":"0x...","price":"2950.1","executed":true,"chainId":84532,"vault":"0x...","orderId":0}
```

Exits non-zero if anything fails, including a rejected signature. `RESPONSE_FILE=resp.json` skips the fetch.

## Open points

- Not yet tested against the live AirnodeHub endpoint (no network from the build machine). Check that
  `fetch-eth-usd.sh` gets the `X-Airnode-*` headers from the CoinGecko passthrough, and that the signature
  verifies on-chain (`./scripts/submit.sh resp.json`). If the endpoint needs aUSD payment (HTTP 402), get test aUSD
  on Base Sepolia from https://airnodehub.api3.org/faucet.
- The workshop (Fri 11:00, "Building with AirnodeHub") may hand out an official starter; if its signature or
  request format differs, only `AirnodeVerifier.sol` and the scripts need changes.
