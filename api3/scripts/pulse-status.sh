#!/usr/bin/env bash
# The "protected remaining balance" view of one order.
# Usage: scripts/pulse-status.sh <order id>      env: EVM_RPC_URL, PULSE_ADDRESS
set -euo pipefail
: "${EVM_RPC_URL:?}" "${PULSE_ADDRESS:?}"
r=(); while IFS= read -r l; do r+=("$l"); done < <(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_ADDRESS" \
  "orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint256,bool,string,uint256)" "$1")
states=(active held closed)
until_ts="${r[5]%% *}"
refund_at="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_ADDRESS" "noDataRefundAt(uint256)(uint256)" "$1")"
echo "Order:            $1"
echo "State:            ${states[${r[0]}]}"
echo "Paid:             ${r[1]%% *} wei"
echo "Remaining:        ${r[2]%% *} wei"
echo "Next milestone:   ${r[3]} of ${r[4]}"
if [[ "${r[6]}" == "true" ]]; then echo "Payment permit:   valid until $(date -u -r "$until_ts" 2>/dev/null || date -u -d "@$until_ts")"
elif [[ "$until_ts" != "0" ]]; then echo "Payment permit:   expired"
else echo "Payment permit:   none (needs fresh evidence)"; fi
if [[ "$refund_at" != "0" ]]; then
  echo "No-data refund:   available at $(date -u -r "$refund_at" 2>/dev/null || date -u -d "@$refund_at")"
else
  echo "No-data refund:   unavailable"
fi
echo "Last status:      ${r[7]} (signed at ${r[8]%% *})"
