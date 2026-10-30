#!/usr/bin/env bash
# Simulate a signed SupplierPulse+ record; optionally broadcast it, including expected reverts.
# Usage: scripts/plus-submit.sh <order id> <response.json> [value|stale|request|key|replay] [--send]
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/plus-lib.sh"
x402_dir="$script_dir/../x402"

usage() {
  echo "usage: $0 <order id> <response.json> [value|stale|request|key|replay] [--send]" >&2
  echo "env: EVM_RPC_URL, PULSE_PLUS_ADDRESS; --send also needs SUBMIT_PRIVATE_KEY, AGENT_PRIVATE_KEY or EVM_PRIVATE_KEY" >&2
}

if [[ $# -lt 2 ]]; then usage; exit 2; fi
order_id="$1"
record_file="$2"
shift 2
[[ "$order_id" =~ ^[0-9]+$ ]] || { echo "order id must be a non-negative integer" >&2; exit 2; }
[[ -f "$record_file" ]] || { echo "record file not found: $record_file" >&2; exit 2; }

mode=""
send=0
for arg in "$@"; do
  case "$arg" in
    --send)
      (( send == 0 )) || { echo "--send may only be specified once" >&2; exit 2; }
      send=1
      ;;
    value|stale|request|key|replay)
      [[ -z "$mode" ]] || { echo "specify at most one tamper mode" >&2; exit 2; }
      mode="$arg"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

: "${EVM_RPC_URL:?}" "${PULSE_PLUS_ADDRESS:?}"
submit_key="${SUBMIT_PRIVATE_KEY:-${AGENT_PRIVATE_KEY:-${EVM_PRIVATE_KEY:-}}}"
if (( send )) && [[ -z "$submit_key" ]]; then
  echo "--send requires SUBMIT_PRIVATE_KEY, AGENT_PRIVATE_KEY or EVM_PRIVATE_KEY" >&2
  exit 2
fi

candidate="$record_file"
tmp=""
if [[ -n "$mode" ]]; then
  tmp="$(mktemp)"
  trap 'rm -f -- "$tmp"' EXIT
  [[ -d "$x402_dir/node_modules" ]] || (cd "$x402_dir" && npm ci --silent --no-audit --no-fund >&2)
  node "$x402_dir/tamper.mjs" "$record_file" "$mode" >"$tmp"
  candidate="$tmp"
fi

if ! jq -e 'type == "object" and (.requestHash | type == "string") and (.timestamp | tostring | test("^[0-9]+$")) and (.data | type == "string") and (.signature | type == "string")' "$candidate" >/dev/null; then
  echo "record must contain requestHash, a unix-seconds timestamp, data, and signature" >&2
  exit 2
fi
request_hash="$(jq -er '.requestHash' "$candidate")"
timestamp="$(jq -er '.timestamp | tostring' "$candidate")"
data="$(jq -er '.data' "$candidate")"
signature="$(jq -er '.signature' "$candidate")"
function_sig="submitEvidence(uint256,bytes32,uint256,bytes,bytes)"
call_sig="$function_sig(bool)"
args=("$order_id" "$request_hash" "$timestamp" "$data" "$signature")

if simulation="$(cast call --rpc-url "$EVM_RPC_URL" --from 0x000000000000000000000000000000000000dEaD \
  "$PULSE_PLUS_ADDRESS" "$call_sig" "${args[@]}" 2>&1)"; then
  clean="$(plus_num "$simulation")"
  if [[ "$clean" == "true" || "$clean" == "1" ]]; then
    echo "ACCEPTED clean" >&2
  else
    if ! order_info="$(cast call --rpc-url "$EVM_RPC_URL" --json "$PULSE_PLUS_ADDRESS" \
      "orderInfo(uint256)(address,address,uint8,string,bytes32,bytes32,uint64,uint8)" "$order_id" 2>&1)"; then
      echo "evidence accepted but could not read order rules: $order_info" >&2
      exit 1
    fi
    source_id="$(cast to-dec "$(jq -er '.[2]' <<<"$order_info")")"
    rules="$(cast to-dec "$(jq -er '.[7]' <<<"$order_info")")"
    raw="$(cast to-utf8 "$data")"
    failed=0
    if [[ "$source_id" == 0 ]]; then
      [[ "$(jq -r '.status // ""' <<<"$raw")" == "active" ]] || failed=$((failed | 0x80))
      if (( rules & 0x02 )); then
        [[ "$(jq -r 'if has("accounts_overdue") then .accounts_overdue else "" end' <<<"$raw")" == "false" ]] || failed=$((failed | 0x02))
      fi
      if (( rules & 0x04 )); then
        [[ "$(jq -r 'if has("confirmation_overdue") then .confirmation_overdue else "" end' <<<"$raw")" == "false" ]] || failed=$((failed | 0x04))
      fi
    else
      [[ "$(jq -r '.entity_status // ""' <<<"$raw")" == "ACTIVE" ]] || failed=$((failed | 0x80))
      if (( rules & 0x08 )); then
        [[ "$(jq -r '.registration_status // ""' <<<"$raw")" == "ISSUED" ]] || failed=$((failed | 0x08))
      fi
    fi
    echo "ACCEPTED held: $(plus_rule_labels "$failed")" >&2
  fi
else
  sim_error="$(plus_error "$simulation")"
  echo "simulation rejected by contract: $sim_error" >&2
  echo "$simulation" | grep -m1 -oE '(custom error|execution reverted|data:).*' >&2 || true
  if (( ! send )); then exit 1; fi
fi

if (( ! send )); then
  echo "simulation only; pass --send to broadcast a transaction" >&2
  exit 0
fi

gas_limit="${SUBMIT_GAS_LIMIT:-300000}"
[[ "$gas_limit" =~ ^[0-9]+$ ]] || { echo "SUBMIT_GAS_LIMIT must be an integer" >&2; exit 2; }
if sent="$(plus_send "$submit_key" --gas-limit "$gas_limit" "$PULSE_PLUS_ADDRESS" "$function_sig" "${args[@]}" 2>&1)"; then
  echo "$sent" | jq '{txHash: .transactionHash, status}'
else
  echo "transaction failed or reverted: $(plus_error "$sent")" >&2
  echo "$sent" >&2
  exit 1
fi
