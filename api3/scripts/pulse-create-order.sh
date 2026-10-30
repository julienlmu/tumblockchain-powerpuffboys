#!/usr/bin/env bash
# Buyer: lock an order for one supplier. Prints the order id.
# Usage: scripts/pulse-create-order.sh <company number> <supplier address> <amounts wei, comma separated>
#   e.g. scripts/pulse-create-order.sh 09729896 0xSupplier 500000000000,1500000000000
# env: EVM_RPC_URL, EVM_PRIVATE_KEY, PULSE_ADDRESS, [PERMIT_TTL=86400] [ORDER_REF="PO-1"]
set -euo pipefail
source "$(dirname "$0")/pulse-lib.sh"
: "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${PULSE_ADDRESS:?}"
number="$1"; supplier="$2"; amounts="$3"
total=0; for a in ${amounts//,/ }; do total=$((total + a)); done
rc="$(pulse_send --value "$total" "$PULSE_ADDRESS" "createOrder(address,string,bytes32,uint256[],uint64)" \
  "$supplier" "$number" \
  "$(cast keccak "${ORDER_REF:-PO-1}")" "[$amounts]" "${PERMIT_TTL:-86400}")"
[[ "$(echo "$rc" | jq -r .status)" == "0x1" ]] || { echo "createOrder failed: $rc" >&2; exit 1; }
topic="$(cast keccak 'OrderCreated(uint256,address,address,bytes32,bytes32,uint256,uint256)')"
id="$(cast to-dec "$(echo "$rc" | jq -r --arg t "$topic" '.logs[] | select(.topics[0]==$t) | .topics[1]' | head -1)")"
echo "order $id created in $(echo "$rc" | jq -r .transactionHash) (total $total wei, company $number)" >&2
echo "$id"
