#!/usr/bin/env bash
# FETCH_CMD for the v1 hedge run: v1's request (Companies House status only, $0.01 over x402) through
# api3/scripts/supplier-fetch.sh, printed as the signed response file of docs/SUPPLIERPULSE_PLUS.md §4.1.
# Usage: api3/agent/fetch-v1.sh ch <company number>
# env: PAYER_PRIVATE_KEY (Base Sepolia wallet with aUSD; defaults to EVM_PRIVATE_KEY)
# Exit codes: 3 no data (passed through from the fetch), 2 usage, anything else a failed fetch.
set -euo pipefail
[[ "${1:-}" == "ch" && -n "${2:-}" ]] || { echo "usage: fetch-v1.sh ch <company number>" >&2; exit 2; }
root="$(cd "$(dirname "$0")/../.." && pwd)"
json="$("$root/api3/scripts/supplier-fetch.sh" "$2")"
echo "$json" | jq -c --arg id "$2" '. + {source: "ch", supplierId: $id, priceUsd: "0.01"}'
