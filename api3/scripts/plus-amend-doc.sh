#!/usr/bin/env bash
# Amend the document of an amendable order (IOrderDocuments): buyer and supplier each sign, then anyone submits.
# The new salted hash is appended; earlier versions stay readable (plus-status.sh / documentHistory).
# Usage:
#   scripts/plus-amend-doc.sh sign   <order id> <new doc hash>                     (key: SIGNER_PRIVATE_KEY)
#   scripts/plus-amend-doc.sh submit <order id> <new doc hash> <buyer sig> <supplier sig>   (key: EVM_PRIVATE_KEY)
#   new doc hash: ORDER_DOC_HASH from scripts/plus-doc-hash.sh for the amended document
# env: EVM_RPC_URL, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -ge 3 ]] || { sed -n '2,8p' "$0" >&2; exit 2; }
d="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "amendmentDigest(uint256,bytes32)(bytes32)" "$2" "$3")"
case "$1" in
  sign)
    : "${SIGNER_PRIVATE_KEY:?}"
    echo "signer $(cast wallet address --private-key "$SIGNER_PRIVATE_KEY") signs amendment digest $d" >&2
    cast wallet sign --private-key "$SIGNER_PRIVATE_KEY" "$d" ;;
  submit)
    : "${EVM_PRIVATE_KEY:?}"; [[ $# -eq 5 ]] || { sed -n '2,8p' "$0" >&2; exit 2; }
    if ! rc="$(plus_send "$EVM_PRIVATE_KEY" "$PULSE_PLUS_ADDRESS" "amendDocument(uint256,bytes32,bytes,bytes)" \
      "$2" "$3" "$4" "$5" 2>&1)" || [[ "$(echo "$rc" | jq -r .status 2>/dev/null)" != "0x1" ]]; then
      echo "amendDocument failed: $(plus_error "$rc")" >&2; exit 1
    fi
    echo "order $2 document amended in $(echo "$rc" | jq -r .transactionHash)"
    cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "documentHistory(uint256)(bytes32[])" "$2" ;;
  *) sed -n '2,8p' "$0" >&2; exit 2 ;;
esac
