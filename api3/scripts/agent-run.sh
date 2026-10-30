#!/usr/bin/env bash
# Entry point for the Cardano/Masumi agent (API3_SUBMIT_CMD).
# Creates a vault order "pay out if ETH/USD < THRESHOLD_USD", fetches a signed ETH/USD from AirnodeHub,
# submits it and executes if the condition holds. Logs go to stderr; the LAST stdout line is JSON:
#   {"txHash":"0x..","price":"2987.41","executed":true,"chainId":11155111,"vault":"0x..","orderId":3}
# env: THRESHOLD_USD (int), EVM_RPC_URL, EVM_PRIVATE_KEY, VAULT_ADDRESS
#      [BELOW=true] [ORDER_VALUE_WEI=1000000000000] [BENEFICIARY=sender] [RESPONSE_FILE=skip fetch]
set -euo pipefail
: "${THRESHOLD_USD:?}" "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${VAULT_ADDRESS:?}"
dir="$(cd "$(dirname "$0")" && pwd)"
rpc=(--rpc-url "$EVM_RPC_URL")
sender="$(cast wallet address --private-key "$EVM_PRIVATE_KEY")"
chain_id="$(cast chain-id "${rpc[@]}")"
below="${BELOW:-true}"
threshold="$(cast to-wei "$THRESHOLD_USD" ether)"

# newer Foundry wraps --json output as {"success","data",...}; unwrap it so both formats work
send() {
  cast send "${rpc[@]}" --private-key "$EVM_PRIVATE_KEY" --json "$@" \
    | jq '(if type == "object" and has("success") and has("data") then .data else . end)'
}

echo "creating order: pay ${ORDER_VALUE_WEI:-1000000000000} wei if ETH/USD $([[ $below == true ]] && echo '<' || echo '>') $THRESHOLD_USD" >&2
rc="$(send --value "${ORDER_VALUE_WEI:-1000000000000}" "$VAULT_ADDRESS" \
  "createOrder(address,uint256,bool)" "${BENEFICIARY:-$sender}" "$threshold" "$below")"
created_topic="$(cast keccak 'OrderCreated(uint256,address,address,uint256,uint256,bool)')"
order_id="$(echo "$rc" | jq -r --arg t "$created_topic" '.logs[] | select(.topics[0]==$t) | .topics[1]' | head -1)"
order_id="$(cast to-dec "$order_id")"
echo "order $order_id created in $(echo "$rc" | jq -r .transactionHash)" >&2

resp="${RESPONSE_FILE:-}"
if [[ -z "$resp" ]]; then resp="$(mktemp)"; trap 'rm -f "$resp"' EXIT; "$dir/fetch-eth-usd.sh" "$resp"; fi
echo "signed response: $(jq -c '{airnode,timestamp,raw}' "$resp")" >&2

rc="$(send "$VAULT_ADDRESS" "submitAndTryExecute(uint256,bytes32,uint256,bytes,bytes)" "$order_id" \
  "$(jq -r .requestHash "$resp")" "$(jq -r .timestamp "$resp")" "$(jq -r .data "$resp")" "$(jq -r .signature "$resp")")"
[[ "$(echo "$rc" | jq -r .status)" == "0x1" ]] || { echo "submit tx failed" >&2; echo "$rc" >&2; exit 1; }

executed_topic="$(cast keccak 'OrderExecuted(uint256,uint256,uint256,address,uint256)')"
executed="$(echo "$rc" | jq --arg t "$executed_topic" '[.logs[] | select(.topics[0]==$t)] | length > 0')"
price="$(cast from-wei "$(cast call "${rpc[@]}" "$VAULT_ADDRESS" 'latestPrice()(uint256)' | awk '{print $1}')" | sed -E 's/0+$//; s/\.$//')"

jq -nc --arg tx "$(echo "$rc" | jq -r .transactionHash)" --arg p "$price" --argjson e "$executed" \
  --argjson c "$chain_id" --arg v "$VAULT_ADDRESS" --argjson o "$order_id" \
  '{txHash:$tx, price:$p, executed:$e, chainId:$c, vault:$v, orderId:$o}'
