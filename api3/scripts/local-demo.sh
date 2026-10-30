#!/usr/bin/env bash
# End-to-end on a local anvil chain with a local "Airnode" key: deploy, valid submit, 4 tamper attempts,
# then the agent entry point. No AirnodeHub access needed.
set -euo pipefail
cd "$(dirname "$0")/.."
export EVM_RPC_URL=http://127.0.0.1:8545
# anvil default accounts 0 and 1 (public test keys)
export EVM_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export SIGNER_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
anvil --silent & ANVIL=$!; trap 'kill $ANVIL' EXIT; sleep 1

export AIRNODE_ADDRESS="$(cast wallet address --private-key "$SIGNER_KEY")"
export REQUEST_HASH="$(cast keccak '["latestFeeds",[["name","ETH/USD"]],[["price","/ETH~1USD/value"],["updatedAt","/ETH~1USD/timestamp"]]]')"
forge script script/Deploy.s.sol --rpc-url "$EVM_RPC_URL" --broadcast --silent "$@"
export VAULT_ADDRESS="$(jq -r '.transactions[0].contractAddress' broadcast/Deploy.s.sol/31337/run-latest.json)"
echo "vault: $VAULT_ADDRESS  airnode: $AIRNODE_ADDRESS"

now="$(cast block latest --rpc-url "$EVM_RPC_URL" -f timestamp)"
resp="$(mktemp)"; scripts/sign-response.sh "{\"price\":3120.55,\"updatedAt\":${now}000}" "$REQUEST_HASH" "$now" > "$resp"
# a tamper case only counts if the vault itself rejected it (not a script error)
expect_reject() {
  local out
  if out="$(scripts/submit.sh "$@" 2>&1)"; then echo "$out"; echo "FAIL: accepted"; exit 1; fi
  echo "$out"
  grep -q "REJECTED by vault" <<<"$out" || { echo "FAIL: script error, not a vault rejection"; exit 1; }
}
for t in value stale request key; do
  echo "--- tamper: $t"; expect_reject "$resp" "$t"
done
echo "--- valid response"; scripts/submit.sh "$resp"
echo "--- replay"; expect_reject "$resp"

echo "--- agent entry point (ETH < 3000? price 2950.10)"
resp2="$(mktemp)"; scripts/sign-response.sh "{\"price\":2950.1,\"updatedAt\":${now}000}" "$REQUEST_HASH" "$((now + 1))" > "$resp2"
THRESHOLD_USD=3000 RESPONSE_FILE="$resp2" scripts/agent-run.sh
