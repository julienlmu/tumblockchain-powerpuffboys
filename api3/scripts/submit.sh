#!/usr/bin/env bash
# Submit a signed AirnodeHub response to the vault. Judges: use this with your own response.
# Usage: scripts/submit.sh response.json [tamper]
#   response.json  output of fetch-eth-usd.sh or sign-response.sh
#   tamper         optional: value | stale | request | key   (each must be rejected)
# env: EVM_RPC_URL, EVM_PRIVATE_KEY, VAULT_ADDRESS, [ORDER_ID] (if set, calls submitAndExecute)
set -euo pipefail
f="$1"; tamper="${2:-}"
: "${EVM_RPC_URL:?}" "${EVM_PRIVATE_KEY:?}" "${VAULT_ADDRESS:?}"

req="$(jq -r .requestHash "$f")"; ts="$(jq -r .timestamp "$f")"
data="$(jq -r .data "$f")";       sig="$(jq -r .signature "$f")"

case "$tamper" in
  "") ;;
  value)   # change one price digit in the signed bytes
           raw="$(cast to-utf8 "$data")"
           new="$(echo -n "$raw" | sed -E 's/[0-9]/1/')"
           [[ "$new" == "$raw" ]] && new="$(echo -n "$raw" | sed -E 's/[0-9]/2/')"
           data="0x$(echo -n "$new" | od -An -v -tx1 | tr -d ' \n')"
           echo "tampered data: $new" >&2 ;;
  stale)   ts=$((ts - 3600)); echo "tampered timestamp: $ts" >&2 ;;
  request) req="$(cast keccak "some-other-request")"; echo "tampered requestHash: $req" >&2 ;;
  key)     k="$(cast keccak "random-key-$RANDOM-$(date +%s)")"   # throwaway key, not the Airnode's
           d="$(cast keccak "$(cast concat-hex "$req" "$(cast to-uint256 "$ts")" "$data")")"
           sig="$(cast wallet sign --private-key "$k" "$d")"
           echo "re-signed with random key $(cast wallet address --private-key "$k")" >&2 ;;
  *) echo "unknown tamper mode: $tamper" >&2; exit 2 ;;
esac

if [[ -n "${ORDER_ID:-}" ]]; then
  fn="submitAndExecute(uint256,bytes32,uint256,bytes,bytes)"; args=("$ORDER_ID" "$req" "$ts" "$data" "$sig")
else
  fn="submitPrice(bytes32,uint256,bytes,bytes)"; args=("$req" "$ts" "$data" "$sig")
fi

# dry run first so a rejection shows the decoded custom error
if ! out="$(cast call --rpc-url "$EVM_RPC_URL" --from "$(cast wallet address --private-key "$EVM_PRIVATE_KEY")" \
     "$VAULT_ADDRESS" "$fn" "${args[@]}" 2>&1)"; then
  # older cast prints "custom error 0x<sel>", newer prints the revert data as data: "0x<sel>..."
  sel="$(echo "$out" | grep -oE '(custom error |data: "?)0x[0-9a-f]{8}' | head -1 | grep -oE '0x[0-9a-f]{8}' || true)"
  name="unknown"
  for e in "WrongSigner(address)" "WrongRequest(bytes32)" "StaleResponse(uint256,uint256)" \
           "FutureResponse(uint256,uint256)" "StalePrice(uint256,uint256)" "Replayed(bytes32)" "NotNewer(uint256,uint256)" \
           "ConditionNotMet(uint256,uint256,bool)" "InvalidSignatureS()" "InvalidSignatureLength()" "BadOrder()"; do
    [[ "$(cast sig "$e")" == "$sel" ]] && name="$e"
  done
  echo "REJECTED by vault: $name" >&2
  echo "$out" | grep -m1 -oE '(custom error|execution reverted).*' >&2 || echo "$out" >&2
  exit 1
fi
cast send --rpc-url "$EVM_RPC_URL" --private-key "$EVM_PRIVATE_KEY" "$VAULT_ADDRESS" "$fn" "${args[@]}" --json \
  | jq '(if type == "object" and has("success") and has("data") then .data else . end)
        | {txHash: .transactionHash, status: .status}'
echo "latestPrice (1e18): $(cast call --rpc-url "$EVM_RPC_URL" "$VAULT_ADDRESS" 'latestPrice()(uint256)')"
