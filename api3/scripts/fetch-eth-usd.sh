#!/usr/bin/env bash
# Fetch a signed ETH/USD response from the Nodary Airnode on AirnodeHub (free, no rate limit) and write it as JSON:
#   {"airnode","requestHash","timestamp","data"(hex of the exact signed bytes),"signature","raw"}
# Usage: scripts/fetch-eth-usd.sh [out.json]     (default: stdout)
# env: AIRNODE_URL (default https://airnode-nodary.fly.dev/), FEED (default ETH/USD)
set -euo pipefail
URL="${AIRNODE_URL:-https://airnode-nodary.fly.dev/}"
FEED="${FEED:-ETH/USD}"
ptr="/${FEED//\//~1}"   # JSON pointer: "/" becomes "~1"
body="$(jq -nc --arg f "$FEED" --arg p "$ptr" \
  '{operation:"latestFeeds", parameters:{name:$f}, responseProjection:{price:($p+"/value"), updatedAt:($p+"/timestamp")}}')"

resp="$(curl -sS --fail -X POST "$URL" -H 'Content-Type: application/json' --data "$body")"
data="$(echo "$resp" | jq -j .data)"   # the exact string the Airnode signed
[[ -n "$data" && "$data" != "null" ]] || { echo "unexpected response: $resp" >&2; exit 1; }

json="$(echo "$resp" | jq --arg d "0x$(printf '%s' "$data" | od -An -v -tx1 | tr -d ' \n')" \
  '{airnode, requestHash, timestamp:(.timestamp|tostring), data:$d, signature, raw:.data}')"
if [[ $# -ge 1 ]]; then echo "$json" > "$1"; else echo "$json"; fi
