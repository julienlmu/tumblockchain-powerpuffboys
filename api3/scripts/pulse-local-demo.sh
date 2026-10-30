#!/usr/bin/env bash
# SupplierPulse end to end on a local anvil chain with a local "Airnode" key. No AirnodeHub access needed.
# Order: 2 milestones. Milestone 0: supplier active -> paid (after 4 tamper attempts are rejected).
# Milestone 1: supplier now in liquidation -> remaining balance held, buyer refunds.
set -euo pipefail
cd "$(dirname "$0")/.."
export EVM_RPC_URL=http://127.0.0.1:8545
# anvil default accounts 0, 1 and 2 (public test keys)
export EVM_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export SIGNER_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
SUPPLIER=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
anvil --silent & ANVIL=$!; trap 'kill $ANVIL' EXIT
for _ in $(seq 50); do cast chain-id --rpc-url "$EVM_RPC_URL" &>/dev/null && break; sleep 0.2; done
source scripts/pulse-lib.sh

export PULSE_AIRNODE="$(cast wallet address --private-key "$SIGNER_KEY")"
forge script script/DeploySupplierPulse.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --silent "$@"
export PULSE_ADDRESS="$(jq -r '.transactions[0].contractAddress' broadcast/DeploySupplierPulse.s.sol/31337/run-latest.json)"
echo "contract: $PULSE_ADDRESS  airnode: $PULSE_AIRNODE"

NUMBER=01234567
export ORDER_ID="$(scripts/pulse-create-order.sh "$NUMBER" "$SUPPLIER" 500000000000000000,1500000000000000000)"
scripts/pulse-approve.sh "$ORDER_ID" 0 >/dev/null
req="$(pulse_request_hash "$NUMBER")"
# same shape as the real Airnode's signed data: {"status":"active"}
sign() { scripts/sign-response.sh "{\"status\":\"$1\"}" "$req" "$2"; }

expect_reject() {
  local out
  if out="$(scripts/pulse-submit.sh "$@" 2>&1)"; then echo "$out"; echo "FAIL: accepted"; exit 1; fi
  echo "$out"
  grep -q "REJECTED by contract" <<<"$out" || { echo "FAIL: script error, not a contract rejection"; exit 1; }
}
now="$(cast block latest --rpc-url "$EVM_RPC_URL" -f timestamp)"
resp="$(mktemp)"; sign active "$now" > "$resp"
for t in value stale request key; do echo "--- tamper: $t"; expect_reject "$resp" "$t"; done
echo "--- milestone 0: valid response, supplier active"; RESPONSE_FILE="$resp" scripts/supplier-agent.sh
echo "--- replay"; expect_reject "$resp"
scripts/pulse-status.sh "$ORDER_ID"

echo "--- milestone 1: buyer approves, supplier is now in liquidation"
scripts/pulse-approve.sh "$ORDER_ID" 1 >/dev/null
resp2="$(mktemp)"; sign liquidation "$((now + 1))" > "$resp2"
RESPONSE_FILE="$resp2" scripts/supplier-agent.sh
scripts/pulse-status.sh "$ORDER_ID"
echo "--- buyer takes back the protected balance"
pulse_send "$PULSE_ADDRESS" "refundRemaining(uint256)" "$ORDER_ID" | jq '{txHash: .transactionHash, status}'
echo "supplier balance: $(cast balance --rpc-url "$EVM_RPC_URL" "$SUPPLIER" --ether) ETH (10000 + 0.5 paid)"
