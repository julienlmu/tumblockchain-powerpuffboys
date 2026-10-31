#!/usr/bin/env bash
# Demo orders that are due within minutes, for recording the video or a live demo on the deployed contract
# (Sepolia v2 uses real block time, so it cannot be fast-forwarded). Same suppliers as plus-demo-orders.sh,
# with every first milestone approved and due QUICK_DUE seconds from now. Prints the ids and a timeline.
#   QA clean Companies House  -> the agent pays M1 once due, then M2
#   QB liquidation            -> held at the first check; the buyer can refund at once, anyone after refundGrace
#   QD clean GLEIF            -> the agent pays M1 once due
# The whole set costs 0.002 ETH from the buyer. The agent pays $0.01 aUSD per check, as for any order.
# Usage: scripts/plus-quick-orders.sh
# env: EVM_RPC_URL, BUYER_PRIVATE_KEY, PULSE_PLUS_ADDRESS, DEMO_SUPPLIER_1, DEMO_SUPPLIER_2,
#      [QUICK_DUE=120] (seconds to the first due date), [QUICK_GAP=120] (seconds between milestones)
set -euo pipefail
cd "$(dirname "$0")"
source plus-lib.sh
: "${EVM_RPC_URL:?}" "${BUYER_PRIVATE_KEY:?}" "${PULSE_PLUS_ADDRESS:?}" "${DEMO_SUPPLIER_1:?}" "${DEMO_SUPPLIER_2:?}"
due="${QUICK_DUE:-120}" gap="${QUICK_GAP:-120}"
max_age="$(plus_num "$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "maxAge()(uint256)")")"
grace="$(plus_num "$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "refundGrace()(uint64)")")"
ttl="$max_age" # the shortest permit the contract accepts (permitTtl >= maxAge)
stamp="$(date +%H%M)"

# Readable names on chain (bytes32 strings), so the website shows "PO-<HHMM><n> <name>". Dummy demo names only.
ref() { cast format-bytes32-string "PO-$stamp$1 $2"; }

# quick <label> <ORDER_REF> <ch|gleif> <id> <supplier> <rules> <amounts> <dues> <approved milestones...>
quick() {
  local label="$1" id m; shift
  id="$(ORDER_REF="$1" ./plus-create-order.sh "$2" "$3" "$4" "$6" "$7" "$5" "$ttl")"
  shift 7
  for m in "$@"; do ./plus-approve.sh "$id" "$m" >/dev/null; done
  echo "$label=$id"
}
start="$(plus_now)"
quick QA "$(ref 1 "Motor supply")" ch    03778796             "$DEMO_SUPPLIER_1" 0x06 500,500 "+$due,+$((due + gap))" 0 1
quick QB "$(ref 2 "Gearbox")" ch    07418033             "$DEMO_SUPPLIER_2" 0x06 500     "+$due"                0
quick QD "$(ref 3 "Cable harness (DE)")" gleif 391200JI69LS8L648F30 "$DEMO_SUPPLIER_1" 0x08 500     "+$due"                0

at() { date -r "$1" +%H:%M:%S 2>/dev/null || date -d "@$1" +%H:%M:%S; }
cat >&2 <<EOF

Timeline (chain time, permitTtl ${ttl} s, refundGrace ${grace} s):
  now            the agent's next tick checks QA, QB, QD (\$0.01 each); QB is held at once
  $(at $((start + due)))       M1 of QA and QD is due: the agent pays it with a valid permit
  $(at $((start + due + gap)))       M2 of QA is due: paid after a new check
  any time       QB: the buyer refunds now (scripts/plus-refund.sh <QB id>)
  ~$(at $((start + grace)))      QB: anyone can refund (refundGrace after the hold)
Without the agent, once M1 is due: scripts/fetch-evidence.sh ch 03778796 rec.json, then
  cast send \$PULSE_PLUS_ADDRESS "checkAndRelease(uint256,bytes32,uint256,bytes,bytes)" <QA id> <requestHash timestamp data signature from rec.json>
EOF
