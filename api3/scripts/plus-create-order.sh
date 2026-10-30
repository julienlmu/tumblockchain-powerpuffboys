#!/usr/bin/env bash
# Buyer: lock an order for one supplier. Prints the order id.
# Usage: scripts/plus-create-order.sh <ch|gleif> <id> <supplier> <amounts csv, tokens> <due csv: +seconds or unix> [rules] [permitTtl]
#   e.g. scripts/plus-create-order.sh ch 09729896 0xSupplier 500,1000,1500 +1200,+3600,+7200 0x07 3600
# rules default: 0x07 (ch), 0x08 (gleif). permitTtl default: 3600 s. 1 token = 10^12 wei.
# env: EVM_RPC_URL, BUYER_PRIVATE_KEY, PULSE_PLUS_ADDRESS, [ORDER_REF="PO-1"]
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${BUYER_PRIVATE_KEY:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -ge 5 ]] || { sed -n '3,7p' "$0" >&2; exit 2; }
source_id="$(plus_source "$1")"; id="$2"; supplier="$3"
amounts="$(plus_amounts_wei "$4")"; total="$(plus_total_wei "$4")"; dues="$(plus_dues "$5")"
rules="${6:-$([[ "$source_id" == 0 ]] && echo 0x07 || echo 0x08)}"; ttl="${7:-3600}"
if ! rc="$(plus_send "$BUYER_PRIVATE_KEY" --value "$total" "$PULSE_PLUS_ADDRESS" \
  "createOrder(uint8,string,address,bytes32,uint256[],uint64[],uint64,uint8)" \
  "$source_id" "$id" "$supplier" "$(cast keccak "${ORDER_REF:-PO-1}")" "$amounts" "$dues" "$ttl" "$rules" 2>&1)" \
  || [[ "$(echo "$rc" | jq -r .status 2>/dev/null)" != "0x1" ]]; then
  echo "createOrder failed: $(plus_error "$rc")" >&2; echo "$rc" >&2; exit 1
fi
topic="$(cast keccak 'OrderCreated(uint256,address,bytes32,address,uint8,string,bytes32,bytes32,uint256,uint8)')"
order="$(cast to-dec "$(echo "$rc" | jq -r --arg t "$topic" '.logs[] | select(.topics[0]==$t) | .topics[1]' | head -1)")"
echo "order $order created in $(echo "$rc" | jq -r .transactionHash) ($1 $id, rules $rules, total $total wei)" >&2
echo "$order"
