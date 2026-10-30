#!/usr/bin/env bash
# Prove what was agreed: checks that <file> with <salt> hashes to the order's current document hash on chain.
# Usage: scripts/plus-verify-doc.sh <order id> <file> <salt> [agreed file]   Exit 0 on a match, 1 otherwise.
# With [agreed file] (your copy of the version that matches the chain), a mismatch also prints a change report
# (scripts/plus-doc-diff.sh): what differs between the agreed version and <file>.
# env: EVM_RPC_URL, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -eq 3 || $# -eq 4 ]] || { sed -n '2,6p' "$0" >&2; exit 2; }
# the current version (after amendments); contracts without IOrderDocuments only have orderRef
if ! want="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" \
  "documentOf(uint256)(uint8,bytes32,uint256)" "$1" 2>/dev/null | sed -n 2p)" || [[ -z "$want" ]]; then
  want="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" \
    "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" "$1" | sed -n 6p)"
fi
got="$(plus_doc_hash "$2" "$3")"
if [[ "$(echo "$got" | tr A-F a-f)" == "$(echo "$want" | tr A-F a-f)" ]]; then
  echo "MATCH: this is the current agreed document of order $1 ($got)"
else
  echo "MISMATCH: order $1 has document hash $want, this document and salt give $got" >&2
  if [[ $# -eq 4 ]]; then
    if [[ "$(plus_doc_hash "$4" "$3" | tr A-F a-f)" == "$(echo "$want" | tr A-F a-f)" ]]; then
      "$(dirname "$0")/plus-doc-diff.sh" "$4" "$2"
    else
      echo "the agreed file $4 does not match the chain either, so there is no reference to compare against" >&2
    fi
  fi
  exit 1
fi
