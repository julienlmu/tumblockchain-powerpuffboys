#!/usr/bin/env bash
# Fetch a fresh signed registry record for one supplier ($0.01 paid over x402 in aUSD on Base Sepolia),
# check its request hash and signer, and write it in the §4.1 format.
# Usage: scripts/fetch-evidence.sh <ch|gleif> <id> [out.json]
# env: PAYER_PRIVATE_KEY (Base Sepolia wallet with aUSD); read from api3/.env if not set
# Exit: 0 ok, 2 usage, 3 no data, 4 payment failed, 5 verification failed
set -euo pipefail
dir="$(cd "$(dirname "$0")/../x402" && pwd)"
[[ $# -ge 2 && ( "$1" == ch || "$1" == gleif ) ]] || { echo "usage: $0 <ch|gleif> <id> [out.json]" >&2; exit 2; }
if [[ -z "${PAYER_PRIVATE_KEY:-}" && -f "$dir/../.env" ]]; then set -a; . "$dir/../.env"; set +a; fi
[[ -d "$dir/node_modules" ]] || (cd "$dir" && npm ci --silent --no-audit --no-fund >&2)
json="$(node "$dir/airnode-fetch.mjs" "$1" "$2")"
if [[ $# -ge 3 ]]; then echo "$json" > "$3"; else echo "$json"; fi
