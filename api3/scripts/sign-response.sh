#!/usr/bin/env bash
# Build a response signed the AirnodeHub way with YOUR key (for local demos / judges' own Airnode).
# Usage: SIGNER_KEY=0x... scripts/sign-response.sh '{"price":2950.1,"updatedAt":<ms>}' [requestHash] [timestamp] > response.json
# digest = keccak256(abi.encodePacked(bytes32 requestHash, uint256 timestamp, bytes data)), EIP-191 signed.
set -euo pipefail
: "${SIGNER_KEY:?}"
body="$1"
req="${2:-$(cast keccak '["latestFeeds",[["name","ETH/USD"]],[["price","/ETH~1USD/value"],["updatedAt","/ETH~1USD/timestamp"]]]')}"
ts="${3:-$(date +%s)}"
data="0x$(echo -n "$body" | od -An -v -tx1 | tr -d ' \n')"
digest="$(cast keccak "$(cast concat-hex "$req" "$(cast to-uint256 "$ts")" "$data")")"
sig="$(cast wallet sign --private-key "$SIGNER_KEY" "$digest")"
jq -n --arg a "$(cast wallet address --private-key "$SIGNER_KEY")" --arg r "$req" --arg t "$ts" \
  --arg d "$data" --arg s "$sig" --arg raw "$body" \
  '{airnode:$a, requestHash:$r, timestamp:$t, data:$d, signature:$s, raw:$raw}'
