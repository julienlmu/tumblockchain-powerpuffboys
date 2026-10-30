#!/usr/bin/env bash
# Text view of one order: state, protected balance, milestones with due dates, permit, tier,
# failed rules as labels, refund countdown.
# Usage: scripts/plus-status.sh <order id>      env: EVM_RPC_URL, PULSE_PLUS_ADDRESS
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
: "${EVM_RPC_URL:?}" "${PULSE_PLUS_ADDRESS:?}"
[[ $# -eq 1 ]] || { sed -n '4p' "$0" >&2; exit 2; }
call() { cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" "$@"; }
fmt_time() { date -u -r "$1" '+%a %H:%M:%S UTC' 2>/dev/null || date -u -d "@$1" '+%a %H:%M:%S UTC'; }
tokens() { local w; w="$(plus_num "$1")"; echo "$((w / PLUS_TOKEN_WEI))"; }

info=(); while IFS= read -r l; do info+=("$l"); done < <(call "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" "$1")
st=(); while IFS= read -r l; do st+=("$l"); done < <(call "orderStatus(uint256)(uint8,uint256,uint256,uint256,uint256,uint64,bool,uint256)" "$1")
sc=(); while IFS= read -r l; do sc+=("$l"); done < <(call "orderSchedule(uint256)(uint64,bool,uint8,uint64,uint64,uint8)" "$1")
ms=(); while IFS= read -r l; do ms+=("$l"); done < <(call "orderMilestones(uint256)(uint256[],uint64[],bool[])" "$1")
now="$(plus_now)"
states=(active held closed); sources=("Companies House" GLEIF); tiers=(Standard Trusted Premium)

IFS=', ' read -r -a amounts <<<"$(echo "${ms[0]}" | sed 's/ \[[^]]*\]//g' | tr -d '[]')"
IFS=', ' read -r -a dues <<<"$(echo "${ms[1]}" | sed 's/ \[[^]]*\]//g' | tr -d '[]')"
IFS=', ' read -r -a approved <<<"$(echo "${ms[2]}" | tr -d '[]')"
next="$(plus_num "${st[3]}")"

echo "Order:            $1   (${sources[${info[2]}]} ${info[3]//\"/}, rules $(printf "0x%02x" "${info[7]}"))"
echo "Buyer / supplier: ${info[0]} -> ${info[1]}"
echo "State:            ${states[${st[0]}]}"
echo "Paid:             $(tokens "${st[1]}") tokens"
echo "Protected:        $(tokens "${st[2]}") tokens (remaining, locked in the contract)"
echo "Supplier tier:    ${tiers[${sc[5]}]}"
echo "Milestones:"
for i in "${!amounts[@]}"; do
  if (( i < next )); then mark="paid"; elif (( i == next )) && [[ "${st[0]}" == 0 ]]; then mark="next"; else mark=""; fi
  printf "  M%d  %6s tokens  due %s  approved %-5s %s\n" "$((i + 1))" "$((amounts[i] / PLUS_TOKEN_WEI))" \
    "$(fmt_time "${dues[i]}")" "${approved[i]}" "$mark"
done
until_ts="$(plus_num "${st[5]}")"
if [[ "${st[6]}" == "true" ]]; then echo "Payment permit:   valid until $(fmt_time "$until_ts") ($((until_ts - now)) s left)"
elif [[ "$until_ts" != "0" ]]; then echo "Payment permit:   expired"
else echo "Payment permit:   none (needs fresh evidence)"; fi
last="$(plus_num "${st[7]}")"
if [[ "$last" != "0" ]]; then
  echo "Last check:       $(fmt_time "$last"), failed rules: $(plus_rule_labels "${sc[2]}")"
elif [[ "${sc[2]}" != 0 ]]; then echo "Last check:       none on this order; held by the supplier-wide stop ($(plus_rule_labels "${sc[2]}"))"
else echo "Last check:       none yet"; fi
if [[ "${st[0]}" == 1 ]]; then
  auto="$(plus_num "${sc[4]}")"
  if (( now >= auto )); then echo "Refund:           anyone can trigger it now (money goes to the buyer)"
  else echo "Refund:           buyer can claim now; automatic in $((auto - now)) s"; fi
elif [[ "${st[0]}" == 0 && "$(plus_num "${sc[4]}")" != 0 ]]; then
  auto="$(plus_num "${sc[4]}")"
  if (( now >= auto )); then echo "No-data exit:     anyone can refund the buyer now (no signed record arrived)"
  else echo "No-data exit:     if no signed record arrives, refundable in $((auto - now)) s"; fi
fi
