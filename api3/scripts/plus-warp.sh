#!/usr/bin/env bash
# Local test chain only: move anvil's clock forward, e.g. past a due date or refundGrace, and mine a block.
# Usage: scripts/plus-warp.sh <seconds>
# env: EVM_RPC_URL (default http://127.0.0.1:8545); refuses any chain other than anvil (31337)
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
export EVM_RPC_URL="${EVM_RPC_URL:-http://127.0.0.1:8545}"
[[ $# -eq 1 && "$1" =~ ^[0-9]+$ ]] || { sed -n '3p' "$0" >&2; exit 2; }
[[ "$(cast chain-id --rpc-url "$EVM_RPC_URL")" == 31337 ]] || { echo "not a local anvil chain: real chains use real time" >&2; exit 2; }
cast rpc --rpc-url "$EVM_RPC_URL" evm_increaseTime "$1" >/dev/null
cast rpc --rpc-url "$EVM_RPC_URL" evm_mine >/dev/null
echo "chain time now $(plus_now)"
