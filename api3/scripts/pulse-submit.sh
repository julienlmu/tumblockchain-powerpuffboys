#!/usr/bin/env bash
# Judges: submit a signed Companies House response for an order, optionally tampered (each tamper must be rejected).
# Usage: ORDER_ID=<id> scripts/pulse-submit.sh response.json [tamper]
#   response.json  output of supplier-fetch.sh (or sign-response.sh with your own key)
#   tamper         optional: value | stale | request | key
#     value    flip the signed status ("dissolved" -> "active", anything else -> "dissolved")
#     stale    move the signature timestamp back one hour
#     request  claim it answers another request (another company's lookup)
#     key      re-sign the untouched response with a random key
# env: EVM_RPC_URL, EVM_PRIVATE_KEY, PULSE_ADDRESS, ORDER_ID
set -euo pipefail
source "$(dirname "$0")/pulse-lib.sh"
: "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${PULSE_ADDRESS:?}" "${ORDER_ID:?}"
f="$1"; tamper="${2:-}"
req="$(jq -r .requestHash "$f")"; ts="$(jq -r .timestamp "$f")"
data="$(jq -r .data "$f")";       sig="$(jq -r .signature "$f")"

case "$tamper" in
  "") ;;
  value)   raw="$(cast to-utf8 "$data")"
           if grep -q '"status":"active"' <<<"$raw"; then new="${raw/\"active\"/\"dissolved\"}"
           else new="$(echo -n "$raw" | sed -E 's/"status":"[^"]*"/"status":"active"/')"; fi
           data="0x$(echo -n "$new" | od -An -v -tx1 | tr -d ' \n')"
           echo "tampered data: $new" >&2 ;;
  stale)   ts=$((ts - 3600)); echo "tampered timestamp: $ts" >&2 ;;
  request) req="$(pulse_request_hash 00000001)"; echo "tampered requestHash (company 00000001): $req" >&2 ;;
  key)     k="$(cast keccak "random-key-$RANDOM-$(date +%s)")"   # throwaway key, not the Airnode's
           d="$(cast keccak "$(cast concat-hex "$req" "$(cast to-uint256 "$ts")" "$data")")"
           sig="$(cast wallet sign --private-key "$k" "$d")"
           echo "re-signed with random key $(cast wallet address --private-key "$k")" >&2 ;;
  *) echo "unknown tamper mode: $tamper" >&2; exit 2 ;;
esac

fn="checkAndRelease(uint256,bytes32,uint256,bytes,bytes)"; args=("$ORDER_ID" "$req" "$ts" "$data" "$sig")
if ! out="$(cast call --rpc-url "$EVM_RPC_URL" --from "$(cast wallet address --private-key "$EVM_PRIVATE_KEY")" \
     "$PULSE_ADDRESS" "$fn" "${args[@]}" 2>&1)"; then
  echo "REJECTED by contract: $(pulse_error "$out")" >&2
  echo "$out" | grep -m1 -oE '(custom error|execution reverted).*' >&2 || echo "$out" >&2
  exit 1
fi
outcome=(paid awaiting_approval held)
echo "accepted, outcome: ${outcome[$(cast to-dec "$out")]}" >&2
pulse_send "$PULSE_ADDRESS" "$fn" "${args[@]}" | jq '{txHash: .transactionHash, status}'
