#!/usr/bin/env bash
# Judge CLI: submit a signed record (§4.1) to a SupplierPulse+ order and print the contract's verdict.
# Simulates submitEvidence with cast call (no wallet, no gas); --send also sends it as a real transaction,
# so a rejected record shows as a failed tx on the explorer.
# Usage: scripts/plus-submit.sh <orderId> <file> [value|stale|request|key|replay] [--send]
# env: EVM_RPC_URL, PULSE_PLUS_ADDRESS; EVM_PRIVATE_KEY for --send. Read from api3/.env if not set.
# Output: ACCEPTED clean | ACCEPTED held: <labels> | REJECTED <Error>(args)
# Exit: 0 accepted, 1 rejected, 2 usage
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
x402="$here/../x402"
source "$here/plus-lib.sh"
usage() { echo "usage: $0 <orderId> <file> [value|stale|request|key|replay] [--send]" >&2; exit 2; }

send=0 args=()
for a in "$@"; do if [[ "$a" == --send ]]; then send=1; else args+=("$a"); fi; done
[[ ${#args[@]} -ge 2 && ${#args[@]} -le 3 && "${args[0]}" =~ ^[0-9]+$ && -f "${args[1]}" ]] || usage
order="${args[0]}" file="${args[1]}" mode="${args[2]:-}"
if [[ -z "${EVM_RPC_URL:-}" || -z "${PULSE_PLUS_ADDRESS:-}" ]] && [[ -f "$here/../.env" ]]; then
  set -a; . "$here/../.env"; set +a
fi
[[ -n "${EVM_RPC_URL:-}" && -n "${PULSE_PLUS_ADDRESS:-}" ]] || { echo "set EVM_RPC_URL and PULSE_PLUS_ADDRESS" >&2; exit 2; }
(( send == 0 )) || [[ -n "${EVM_PRIVATE_KEY:-}" ]] || { echo "--send needs EVM_PRIVATE_KEY" >&2; exit 2; }
[[ -d "$x402/node_modules" ]] || (cd "$x402" && npm ci --silent --no-audit --no-fund >&2)

if [[ -n "$mode" ]]; then
  tampered="$(mktemp)"
  trap 'rm -f "$tampered"' EXIT
  node "$x402/tamper.mjs" "$file" "$mode" >"$tampered" || usage
  file="$tampered"
fi
field() { jq -r ".$1" "$file"; }
SIG="submitEvidence(uint256,bytes32,uint256,bytes,bytes)"
call_args=("$order" "$(field requestHash)" "$(field timestamp)" "$(field data)" "$(field signature)")

# REJECTED <Error>(decoded args) from a failed cast output
rejected() {
  local name data decoded
  name="$(plus_error "$1")"
  data="$(echo "$1" | grep -oE 'data: "?0x[0-9a-fA-F]+' | head -1 | grep -oE '0x[0-9a-fA-F]+' || true)"
  if [[ "$name" == unknown ]]; then
    echo "REJECTED $(echo "$1" | grep -m1 -oE 'execution reverted[^,]*' || echo "$1" | head -1)"
  elif [[ "$name" == *"()" ]]; then
    echo "REJECTED $name"
  else
    decoded="$(cast decode-error --sig "$name" "$data" 2>/dev/null | sed 's/ \[.*\]$//' | paste -sd, - | sed 's/,/, /g')"
    echo "REJECTED ${name%%(*}($decoded)"
  fi
}

if out="$(cast call --from 0x000000000000000000000000000000000000dEaD --rpc-url "$EVM_RPC_URL" \
            "$PULSE_PLUS_ADDRESS" "$SIG(bool)" "${call_args[@]}" 2>&1)"; then
  if [[ "$out" == true ]]; then
    verdict="ACCEPTED clean"
  else
    # the contract only returns clean or not; the labels come from the same §4.3 rules it applies
    info="$(cast call --rpc-url "$EVM_RPC_URL" "$PULSE_PLUS_ADDRESS" \
      "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" "$order")"
    source_name="$( [[ "$(plus_num "$(echo "$info" | sed -n 3p)")" == 0 ]] && echo ch || echo gleif )"
    rules="$(plus_num "$(echo "$info" | sed -n 8p)")"
    labels="$(cd "$x402" && node --input-type=module -e "
      import { hexToString } from 'viem'; import { evaluateRules } from './requests.mjs';
      const { labels } = evaluateRules('$source_name', JSON.parse(hexToString('$(field data)')), $rules);
      console.log(labels.join(', '));")"
    verdict="ACCEPTED held: $labels"
  fi
  status=0
else
  verdict="$(rejected "$out")"
  status=1
fi
echo "$verdict"

if (( send )); then
  # a fixed gas limit skips estimation, so a rejected record is still mined (as a failed tx). A clean real
  # record needs ~683k gas on v2 (agent finding, 30 Oct); unused gas is refunded.
  rc="$(plus_send "$EVM_PRIVATE_KEY" --gas-limit 2000000 "$PULSE_PLUS_ADDRESS" "$SIG" "${call_args[@]}")" \
    || { echo "send failed: $rc" >&2; exit 1; }
  echo "tx $(echo "$rc" | jq -r .transactionHash) status $( [[ "$(echo "$rc" | jq -r .status)" == 0x1 ]] && echo success || echo failed)"
fi
exit "$status"
