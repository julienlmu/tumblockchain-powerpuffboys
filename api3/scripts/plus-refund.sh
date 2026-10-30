#!/usr/bin/env bash
# The buyer claims the remaining balance of a held order (anyone may trigger it after the grace period;
# the money always goes to the buyer).
# Usage: scripts/plus-refund.sh <order id>
# env: EVM_RPC_URL, BUYER_PRIVATE_KEY, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${BUYER_PRIVATE_KEY:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -eq 1 ]] || { sed -n '4p' "$0" >&2; exit 2; }
if ! rc="$(plus_send "$BUYER_PRIVATE_KEY" "$PULSE_PLUS_ADDRESS" "refundRemaining(uint256)" "$1" 2>&1)"; then
  echo "refund failed: $(plus_error "$rc")" >&2; exit 1
fi
echo "$rc" | jq '{txHash: .transactionHash, status}'
