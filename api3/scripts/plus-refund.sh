#!/usr/bin/env bash
# Refund the remaining balance to the buyer. Held order: the buyer at once, anyone after the grace period.
# Active order with no data (no-data exit): anyone, once the next milestone is approved, has no valid permit
# and the grace period has passed since its due date or its approval, whichever is later. The money always goes to the buyer.
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
