#!/usr/bin/env bash
# Entry point for the Cardano/Masumi agent (cardano-agent/apps/supplier-pulse.json).
# Before the next milestone of a SupplierPulse order: fetch the supplier's signed Companies House status,
# submit it with checkAndRelease, and report the decision. Logs go to stderr; the LAST stdout line is JSON:
#   {"outcome":"Paid"|"AwaitingApproval"|"Held","txHash":"0x..","orderId":0,"milestone":0,"status":"active",
#    "chainId":11155111,"contract":"0x..","evidence":{"requestHash","timestamp","paymentTx"}}
#   {"outcome":"NoData"|"Rejected","reason":"..."}       (no decision was made)
# env: ORDER_ID, [COMPANY_NUMBER=the order's], EVM_RPC_URL, EVM_PRIVATE_KEY, PULSE_ADDRESS,
#      [PAYER_PRIVATE_KEY=EVM_PRIVATE_KEY] [RESPONSE_FILE=skip the fetch]
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
source "$dir/pulse-lib.sh"
: "${ORDER_ID:?}" "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${PULSE_ADDRESS:?}"
rpc=(--rpc-url "$EVM_RPC_URL")
none() { jq -nc --arg o "$1" --arg r "$2" '{outcome:$o, reason:$r}'; exit 0; }

# the order fixes the company; refuse a job for a different one
order_number="$(cast call "${rpc[@]}" "$PULSE_ADDRESS" "companyNumberOf(uint256)(string)" "$ORDER_ID" 2>/dev/null | tr -d '"')" \
  || none Rejected "order $ORDER_ID not found"
number="$(echo "${COMPANY_NUMBER:-$order_number}" | tr '[:lower:]' '[:upper:]')"
[[ "$number" == "$order_number" ]] || none Rejected "order $ORDER_ID is for company $order_number, not $number"
st="$(cast call "${rpc[@]}" "$PULSE_ADDRESS" \
  "orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint256,bool,string,uint256)" "$ORDER_ID")"
[[ "$(echo "$st" | sed -n 1p)" == "0" ]] || none Rejected "order $ORDER_ID is not active (held or closed)"
milestone="$(echo "$st" | sed -n 4p)"

resp="${RESPONSE_FILE:-}"
if [[ -z "$resp" ]]; then
  resp="$(mktemp)"; trap 'rm -f "$resp"' EXIT
  "$dir/supplier-fetch.sh" "$number" "$resp" || none NoData "no signed registry data for $number"
fi
echo "signed evidence for $number: $(jq -r .raw "$resp") (signed at $(jq -r .timestamp "$resp"), payment $(jq -r '.paymentTx // "none"' "$resp"))" >&2
args=("$ORDER_ID" "$(jq -r .requestHash "$resp")" "$(jq -r .timestamp "$resp")" "$(jq -r .data "$resp")" "$(jq -r .signature "$resp")")
fn="checkAndRelease(uint256,bytes32,uint256,bytes,bytes)"

# dry run: the contract's verdict, without spending gas on a rejection
if ! out="$(cast call "${rpc[@]}" --from "$(cast wallet address --private-key "$EVM_PRIVATE_KEY")" "$PULSE_ADDRESS" "$fn" "${args[@]}" 2>&1)"; then
  none Rejected "contract refused the evidence: $(pulse_error "$out")"
fi
outcomes=(Paid AwaitingApproval Held)
outcome="${outcomes[$(cast to-dec "$out")]}"
rc="$(pulse_send "$PULSE_ADDRESS" "$fn" "${args[@]}")"
[[ "$(echo "$rc" | jq -r .status)" == "0x1" ]] || { echo "tx failed: $rc" >&2; exit 1; }
echo "decision: $outcome" >&2

jq -nc --arg o "$outcome" --arg tx "$(echo "$rc" | jq -r .transactionHash)" --argjson id "$ORDER_ID" \
  --argjson m "$milestone" --arg s "$(jq -r .raw "$resp" | jq -r .status)" --argjson c "$(cast chain-id "${rpc[@]}")" \
  --arg a "$PULSE_ADDRESS" --slurpfile r "$resp" \
  '{outcome:$o, txHash:$tx, orderId:$id, milestone:$m, status:$s, chainId:$c, contract:$a,
    evidence:{requestHash:$r[0].requestHash, timestamp:$r[0].timestamp, paymentTx:$r[0].paymentTx}}'
