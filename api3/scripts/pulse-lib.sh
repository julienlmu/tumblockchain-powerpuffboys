#!/usr/bin/env bash
# Shared helpers for the SupplierPulse scripts (sourced, not run).

# The only request an order accepts: getCompanyProfile for the company number, projected to its status.
# Same as SupplierPulse.companyRequestHash() on chain.
pulse_request_hash() {
  cast keccak "$(jq -nc --arg n "$1" '["getCompanyProfile",[["company_number",$n]],[["status","/company_status"]]]')"
}

# newer Foundry wraps --json output as {"success","data",...}; unwrap it so both formats work
pulse_send() {
  cast send --rpc-url "$EVM_RPC_URL" --private-key "$EVM_PRIVATE_KEY" --json "$@" \
    | jq '(if type == "object" and has("success") and has("data") then .data else . end)'
}

# Name of the custom error in a failed cast call/send output
pulse_error() {
  local sel name="unknown" e
  # older cast prints "custom error 0x<sel>", newer prints the revert data as data: "0x<sel>..."
  sel="$(echo "$1" | grep -oE '(custom error |data: "?)0x[0-9a-f]{8}' | head -1 | grep -oE '0x[0-9a-f]{8}' || true)"
  for e in "WrongSigner(address)" "WrongRequest(bytes32,bytes32)" "BadCompanyNumber()" \
           "StaleResponse(uint256,uint256)" "FutureResponse(uint256,uint256)" "Replayed(bytes32)" \
           "NotNewer(uint256,uint256)" "NoValidPermit(uint256)" "PermitExpired(uint256,uint256)" \
           "NotApproved(uint256)" "NotActive(uint8)" "NotHeld()" "BadOrder()" "NotAuthorized()" \
           "InvalidSignatureS()" "InvalidSignatureLength()" "KeyNotFound()" "NoString()"; do
    [[ "$(cast sig "$e")" == "$sel" ]] && name="$e"
  done
  echo "$name"
}
