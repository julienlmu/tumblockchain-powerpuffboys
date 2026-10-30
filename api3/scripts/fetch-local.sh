#!/usr/bin/env bash
# Same interface as fetch-evidence.sh, but free: the record comes from api3/x402/local-registry.json and is
# signed with the local Airnode key of that source (anvil #1 / #2). For the local test chain only.
# Usage: scripts/fetch-local.sh <ch|gleif> <id> [out.json]
# Exit: 0 ok, 2 usage, 3 no data (id not in the local registry)
set -euo pipefail
dir="$(cd "$(dirname "$0")/../x402" && pwd)"
[[ $# -ge 2 && ( "$1" == ch || "$1" == gleif ) ]] || { echo "usage: $0 <ch|gleif> <id> [out.json]" >&2; exit 2; }
[[ -d "$dir/node_modules" ]] || (cd "$dir" && npm ci --silent --no-audit --no-fund >&2)
source="$1"
id="$(echo "$2" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
# compact JSON with sorted keys, like the Airnode's projected data
raw="$(jq -cS --arg k "$source:$id" '.[$k] // empty' "$dir/local-registry.json")"
[[ -n "$raw" ]] || { echo "no data: $source:$id is not in local-registry.json" >&2; exit 3; }
timestamp=()
case "${LOCAL_CHAIN_TIMESTAMP:-0}" in
  0) ;;
  1)
    : "${EVM_RPC_URL:?EVM_RPC_URL is required when LOCAL_CHAIN_TIMESTAMP=1}"
    timestamp=("$(cast block latest --rpc-url "$EVM_RPC_URL" -f timestamp)")
    ;;
  *) echo "LOCAL_CHAIN_TIMESTAMP must be 0 or 1" >&2; exit 2 ;;
esac
json="$(node "$dir/sign-local.mjs" "$source" "$id" "$raw" "${timestamp[@]}")"
if [[ $# -ge 3 ]]; then echo "$json" > "$3"; else echo "$json"; fi
