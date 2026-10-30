#!/usr/bin/env bash
# Creates the Sepolia demo orders A to E and their approvals (docs/SUPPLIERPULSE_PLUS.md §2.5). Prints the ids.
# Run at C3, right after the deploy. Amounts are tokens (1 token = 10^12 wei); the whole set costs 0.0095 ETH.
# env: EVM_RPC_URL, BUYER_PRIVATE_KEY, PULSE_PLUS_ADDRESS,
#      DEMO_CH_A, DEMO_CH_B, DEMO_CH_C, DEMO_LEI_D, DEMO_LEI_E (supplier ids),
#      DEMO_SUPPLIER_1, DEMO_SUPPLIER_2 (fresh team wallets, never anvil addresses), [PERMIT_TTL=1800]
set -euo pipefail
cd "$(dirname "$0")"
source plus-lib.sh
: "${EVM_RPC_URL:?}" "${BUYER_PRIVATE_KEY:?}" "${PULSE_PLUS_ADDRESS:?}"
: "${DEMO_CH_A:?}" "${DEMO_CH_B:?}" "${DEMO_CH_C:?}" "${DEMO_LEI_D:?}" "${DEMO_LEI_E:?}"
: "${DEMO_SUPPLIER_1:?}" "${DEMO_SUPPLIER_2:?}"
ttl="${PERMIT_TTL:-1800}"

# Saturday 31 Oct 2026, CET (UTC+1)
SAT_1145=1793443500
SAT_1200=1793444400
SAT_1530=1793457000

# demo <label> <ORDER_REF> <ch|gleif> <id> <supplier> <rules> <amounts> <dues> <approved milestones...>
demo() {
  local label="$1" id m; shift
  id="$(ORDER_REF="$1" ./plus-create-order.sh "$2" "$3" "$4" "$6" "$7" "$5" "$ttl")"
  shift 7
  for m in "$@"; do ./plus-approve.sh "$id" "$m" >/dev/null; done
  echo "$label=$id"
}
demo A "PO-1001 Motor supply"        ch    "$DEMO_CH_A"  "$DEMO_SUPPLIER_1" 0x07 500,1000,1500 "+1200,$SAT_1145,$SAT_1530" 0 1
demo B "PO-1002 Gearbox"             ch    "$DEMO_CH_B"  "$DEMO_SUPPLIER_2" 0x07 1000,2000      "+1200,$SAT_1145" 0
demo C "PO-1003 Sensors"             ch    "$DEMO_CH_C"  "$DEMO_SUPPLIER_1" 0x02 500,500        "+1200,$SAT_1200" 0
demo D "PO-1004 Cable harness (DE)"  gleif "$DEMO_LEI_D" "$DEMO_SUPPLIER_1" 0x08 500,1000       "+1800,$SAT_1200" 0 1
demo E "PO-1005 Castings"            gleif "$DEMO_LEI_E" "$DEMO_SUPPLIER_2" 0x08 500,500        "+1800,$SAT_1200" 0
