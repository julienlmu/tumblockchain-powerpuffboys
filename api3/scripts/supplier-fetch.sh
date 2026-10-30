#!/usr/bin/env bash
# Fetch a signed Companies House status for one company (getCompanyProfile, $0.01 paid over x402 in aUSD
# on Base Sepolia) and write it as JSON: {"airnode","requestHash","timestamp","data"(hex),"signature","raw","paymentTx"}
# Usage: scripts/supplier-fetch.sh <company number> [out.json]
# env: PAYER_PRIVATE_KEY (Base Sepolia wallet with aUSD; defaults to EVM_PRIVATE_KEY)
set -euo pipefail
dir="$(cd "$(dirname "$0")/../x402" && pwd)"
[[ -d "$dir/node_modules" ]] || (cd "$dir" && npm install --silent --no-audit --no-fund >&2)
json="$(PAYER_PRIVATE_KEY="${PAYER_PRIVATE_KEY:-${EVM_PRIVATE_KEY:-}}" node "$dir/ch-fetch.mjs" "$1")"
if [[ $# -ge 2 ]]; then echo "$json" > "$2"; else echo "$json"; fi
