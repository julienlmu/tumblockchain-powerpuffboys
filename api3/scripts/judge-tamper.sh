#!/usr/bin/env bash
# Judge tamper test in one command: one valid signed record pays, four tampered copies are rejected.
#
# Local (default): no keys, no money. Starts anvil (or reuses one on :8545), deploys SupplierPulse+ with the
# local Airnode keys (scripts/plus-local.sh), signs a fresh record for order 0 and then
#   (a) value, (b) stale, (c) request, (d) key  -> each must be REJECTED by the contract
#   valid record                                -> must be accepted and pay milestone 1
#   the same record again                       -> must be REJECTED (Replayed)
#
# Live (--live): the same four rejections and the valid case against the deployed contract on Sepolia,
# simulated with cast call (no wallet, no gas). Needs a fresh, unused signed record of the order's supplier,
# e.g. from scripts/fetch-evidence.sh, and an active order whose next milestone is approved and due.
#
# Usage: scripts/judge-tamper.sh
#        scripts/judge-tamper.sh --live <orderId> <record.json>
# env (--live): EVM_RPC_URL, PULSE_PLUS_ADDRESS; read from api3/.env if set there, else publicnode and the live v2
# Exit: 0 every case behaved as expected, 1 at least one did not, 2 usage
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.foundry/bin:$PATH"
for t in cast jq node; do command -v "$t" >/dev/null || { echo "$t is not installed" >&2; exit 2; }; done

fails=0
# expect <label> <wanted verdict prefix> <plus-submit.sh args...>
expect() {
  local label="$1" want="$2" out; shift 2
  out="$("$here/plus-submit.sh" "$@" 2>/dev/null | head -1 || true)"
  if [[ "$out" == "$want"* ]]; then
    printf 'PASS  %-34s %s\n' "$label" "$out"
  else
    printf 'FAIL  %-34s %s (expected %s)\n' "$label" "${out:-no output}" "$want"
    fails=$((fails + 1))
  fi
}
tamper_cases() {
  expect "(a) one value edited" "REJECTED WrongSigner" "$1" "$2" value
  expect "(b) too old (-1 h)" "REJECTED StaleResponse" "$1" "$2" stale
  expect "(c) other company's request" "REJECTED WrongRequest" "$1" "$2" request
  expect "(d) signed by another key" "REJECTED WrongSigner" "$1" "$2" key
}

if [[ "${1:-}" == --live ]]; then
  [[ $# -eq 3 && "$2" =~ ^[0-9]+$ && -f "$3" ]] || { echo "usage: $0 --live <orderId> <record.json>" >&2; exit 2; }
  if [[ -z "${EVM_RPC_URL:-}" || -z "${PULSE_PLUS_ADDRESS:-}" ]] && [[ -f "$here/../.env" ]]; then
    set -a; . "$here/../.env"; set +a
  fi
  export EVM_RPC_URL="${EVM_RPC_URL:-https://ethereum-sepolia-rpc.publicnode.com}"
  export PULSE_PLUS_ADDRESS="${PULSE_PLUS_ADDRESS:-0xf25Aae1772326C95294D1923399D55c658493DfC}" # live v2 on Sepolia
  echo "Contract $PULSE_PLUS_ADDRESS, order $2, record $3 (simulated, nothing is sent)"
  age=$(( $(date +%s) - $(jq -r .timestamp "$3") ))
  (( age <= 300 )) || echo "Note: the record is ${age} s old (maxAge 300 s), so the contract answers StaleResponse first. Get a fresh one: scripts/fetch-evidence.sh <ch|gleif> <id> record.json"
  tamper_cases "$2" "$3"
  expect "valid record" "ACCEPTED" "$2" "$3"
  echo
  (( fails == 0 )) && echo "All cases behaved as expected." || echo "$fails case(s) did not behave as expected."
  echo "To record the valid case on chain: scripts/plus-submit.sh $2 $3 --send"
  exit $(( fails > 0 ))
fi
[[ $# -eq 0 ]] || { echo "usage: $0 | $0 --live <orderId> <record.json>" >&2; exit 2; }

command -v anvil >/dev/null && command -v forge >/dev/null || { echo "install Foundry first: https://getfoundry.sh" >&2; exit 2; }
"$here/plus-local.sh" 2>/dev/null
source "$here/../.local/plus-local.env"
source "$here/plus-lib.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Order 0: Companies House 01234567, milestone 1 approved and due 60 s after creation. Move the local chain
# past the due date, then sign the record at the new chain time so it is fresh (maxAge 300 s).
cast rpc --rpc-url "$EVM_RPC_URL" evm_increaseTime 61 >/dev/null
cast rpc --rpc-url "$EVM_RPC_URL" evm_mine >/dev/null
raw="$(jq -cS '.["ch:01234567"]' "$here/../x402/local-registry.json")"
node "$here/../x402/sign-local.mjs" ch 01234567 "$raw" "$(plus_now)" >"$work/record.json"
echo "Local contract $PULSE_PLUS_ADDRESS, order 0, record signed by the local Companies House Airnode"
echo

tamper_cases 0 "$work/record.json"

supplier="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" \
  "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" 0 | sed -n 2p)"
before="$(plus_num "$(cast balance --rpc-url "$EVM_RPC_URL" "$supplier")")"
rc="$(plus_send "$AGENT_PRIVATE_KEY" "$PULSE_PLUS_ADDRESS" \
  "checkAndRelease(uint256,bytes32,uint256,bytes,bytes)" 0 \
  "$(jq -r .requestHash "$work/record.json")" "$(jq -r .timestamp "$work/record.json")" \
  "$(jq -r .data "$work/record.json")" "$(jq -r .signature "$work/record.json")")"
after="$(plus_num "$(cast balance --rpc-url "$EVM_RPC_URL" "$supplier")")"
paid="$(node -e "console.log(String((BigInt(process.argv[1]) - BigInt(process.argv[2])) / ${PLUS_TOKEN_WEI}n))" "$after" "$before")"
if [[ "$(echo "$rc" | jq -r .status)" == 0x1 ]] && (( paid > 0 )); then
  printf 'PASS  %-34s %s\n' "valid record" "ACCEPTED and paid $paid tokens to $supplier (tx $(echo "$rc" | jq -r .transactionHash))"
else
  printf 'FAIL  %-34s %s\n' "valid record" "not paid (status $(echo "$rc" | jq -r .status), $paid tokens)"
  fails=$((fails + 1))
fi
expect "same record again" "REJECTED Replayed" 0 "$work/record.json"

echo
(( fails == 0 )) && echo "All cases behaved as expected." || echo "$fails case(s) did not behave as expected."
exit $(( fails > 0 ))
