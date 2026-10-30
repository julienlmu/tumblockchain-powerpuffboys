#!/usr/bin/env bash
# Buyer: approve a milestone (order accepted, stage reached, delivery accepted).
# Usage: scripts/pulse-approve.sh <order id> <milestone index, from 0>
# env: EVM_RPC_URL, EVM_PRIVATE_KEY (the buyer), PULSE_ADDRESS
set -euo pipefail
source "$(dirname "$0")/pulse-lib.sh"
: "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${PULSE_ADDRESS:?}"
pulse_send "$PULSE_ADDRESS" "approveMilestone(uint256,uint256)" "$1" "$2" | jq '{txHash: .transactionHash, status}'
