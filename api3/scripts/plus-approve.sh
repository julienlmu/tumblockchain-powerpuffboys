#!/usr/bin/env bash
# Buyer: approve a milestone (order accepted, stage reached, delivery accepted).
# Usage: scripts/plus-approve.sh <order id> <milestone index, from 0>
# env: EVM_RPC_URL, BUYER_PRIVATE_KEY, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${BUYER_PRIVATE_KEY:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -eq 2 ]] || { sed -n '3p' "$0" >&2; exit 2; }
if ! rc="$(plus_send "$BUYER_PRIVATE_KEY" "$PULSE_PLUS_ADDRESS" "approveMilestone(uint256,uint256)" "$1" "$2" 2>&1)"; then
  echo "approve failed: $(plus_error "$rc")" >&2; exit 1
fi
echo "$rc" | jq '{txHash: .transactionHash, status}'
