#!/usr/bin/env bash
# Prove what was agreed: checks that <file> with <salt> hashes to the orderRef stored for the order.
# Usage: scripts/plus-verify-doc.sh <order id> <file> <salt>   Exit 0 on a match, 1 otherwise.
# env: EVM_RPC_URL, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -eq 3 ]] || { sed -n '2,4p' "$0" >&2; exit 2; }
want="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" \
  "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" "$1" | sed -n 6p)"
got="$(plus_doc_hash "$2" "$3")"
if [[ "$(echo "$got" | tr A-F a-f)" == "$(echo "$want" | tr A-F a-f)" ]]; then
  echo "MATCH: order $1 was created for this document ($got)"
else
  echo "MISMATCH: order $1 has orderRef $want, this document and salt give $got" >&2; exit 1
fi
