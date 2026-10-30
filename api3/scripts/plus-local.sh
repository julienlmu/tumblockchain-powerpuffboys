#!/usr/bin/env bash
# Local test chain for SupplierPulse+ (docs/SUPPLIERPULSE_PLUS.md §4.8). No money, no waiting.
# Starts anvil on :8545 unless it is already running (and leaves it running), deploys the contract with
# local Airnode keys, creates the four sample orders and writes api3/.local/plus-local.env.
# Then: source api3/.local/plus-local.env
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/plus-lib.sh
export EVM_RPC_URL=http://127.0.0.1:8545
# anvil's public default keys: never send value to them on a public network
BUYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80   # #0 buyer / deployer
CH_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d      # #1 local Companies House Airnode
GLEIF_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a   # #2 local GLEIF Airnode
AGENT_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6   # #3 agent
SUPPLIER_1=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65                           # #4
SUPPLIER_2=0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc                           # #5

mkdir -p .local
if ! cast chain-id --rpc-url "$EVM_RPC_URL" &>/dev/null; then
  nohup anvil --silent >.local/anvil.log 2>&1 &
  echo "anvil started (pid $!, log api3/.local/anvil.log)" >&2
  for _ in $(seq 50); do cast chain-id --rpc-url "$EVM_RPC_URL" &>/dev/null && break; sleep 0.2; done
fi

EVM_PRIVATE_KEY="$BUYER_KEY" \
CH_AIRNODE="$(cast wallet address --private-key "$CH_KEY")" \
GLEIF_AIRNODE="$(cast wallet address --private-key "$GLEIF_KEY")" \
MAX_AGE=300 TIER_COUNT_GAP=60 REFUND_GRACE=120 \
  forge script script/DeploySupplierPulsePlus.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --silent
export PULSE_PLUS_ADDRESS="$(jq -r '.transactions[0].contractAddress' broadcast/DeploySupplierPulsePlus.s.sol/31337/run-latest.json)"
echo "SupplierPulsePlus: $PULSE_PLUS_ADDRESS" >&2

# order <source> <id> <supplier> <rules> <amounts tokens> <dues +s> <approved milestones...>
order() {
  local src="$1" id="$2" sup="$3" rules="$4" amounts dues total rc m
  amounts="$(plus_amounts_wei "$5")"; total="$(plus_total_wei "$5")"; dues="$(plus_dues "$6")"; shift 6
  rc="$(plus_send "$BUYER_KEY" --value "$total" "$PULSE_PLUS_ADDRESS" \
    "createOrder(uint8,string,address,bytes32,uint256[],uint64[],uint64,uint8)" \
    "$src" "$id" "$sup" "$(cast keccak "LOCAL-$id")" "$amounts" "$dues" 300 "$rules")"
  [[ "$(echo "$rc" | jq -r .status)" == "0x1" ]] || { echo "createOrder failed: $rc" >&2; exit 1; }
  local n=$(( $(plus_num "$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "ordersLength()(uint256)")") - 1 ))
  for m in "$@"; do
    plus_send "$BUYER_KEY" "$PULSE_PLUS_ADDRESS" "approveMilestone(uint256,uint256)" "$n" "$m" >/dev/null
  done
  echo "order $n: $id, rules $rules, approved: $*" >&2
}
order 0 01234567 "$SUPPLIER_1" 0x07 500,1000,1500 +60,+600,+1200 0 1
order 0 07654321 "$SUPPLIER_2" 0x07 1000,2000 +60,+600 0
order 1 TESTLEI0000000000000 "$SUPPLIER_1" 0x08 500,1000 +60,+600 0 1
order 1 TESTLEI0000000000001 "$SUPPLIER_2" 0x08 500,500 +60,+600 0

cat > .local/plus-local.env <<ENV
export EVM_RPC_URL=$EVM_RPC_URL
export PULSE_PLUS_ADDRESS=$PULSE_PLUS_ADDRESS
export BUYER_PRIVATE_KEY=$BUYER_KEY
export AGENT_PRIVATE_KEY=$AGENT_KEY
export LOCAL_CH_KEY=$CH_KEY
export LOCAL_GLEIF_KEY=$GLEIF_KEY
export FETCH_CMD=api3/scripts/fetch-local.sh
ENV
echo "wrote api3/.local/plus-local.env, now: source api3/.local/plus-local.env" >&2
