#!/usr/bin/env bash
# Fetch a signed ETH/USD response from AirnodeHub (CoinGecko passthrough) and write it as JSON:
#   {"airnode","requestHash","timestamp","data"(hex of the exact signed bytes),"signature","raw"}
# Usage: scripts/fetch-eth-usd.sh [out.json]     (default: stdout)
# env: AIRNODE_URL (default: CoinGecko passthrough for ethereum/usd)
set -euo pipefail
URL="${AIRNODE_URL:-https://airnode-coingecko.fly.dev/api/simple/price?ids=ethereum&vs_currencies=usd}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

curl -sS --fail -D "$tmp/h" -o "$tmp/body" "$URL"
hdr() { grep -i "^$1:" "$tmp/h" | tail -1 | cut -d: -f2- | tr -d ' \r\n'; }

airnode="$(hdr x-airnode-address)"; req="$(hdr x-airnode-request-hash)"
ts="$(hdr x-airnode-timestamp)"; sig="$(hdr x-airnode-signature)"
if [[ -z "$sig" || -z "$req" || -z "$ts" ]]; then
  echo "no attestation headers in response (payment needed? see AirnodeHub docs)" >&2
  cat "$tmp/h" >&2; exit 1
fi

json="$(jq -n --arg a "$airnode" --arg r "$req" --arg t "$ts" --arg s "$sig" \
  --arg d "0x$(od -An -v -tx1 "$tmp/body" | tr -d ' \n')" --rawfile raw "$tmp/body" \
  '{airnode:$a, requestHash:$r, timestamp:$t, data:$d, signature:$s, raw:$raw}')"
if [[ $# -ge 1 ]]; then echo "$json" > "$1"; else echo "$json"; fi
