#!/usr/bin/env bash
# Shared helpers for the SupplierPulse+ scripts (sourced, not run).

# 1 token = 10^12 wei (0.000001 ETH), so a 500 + 1,000 + 1,500 order costs 0.003 ETH
PLUS_TOKEN_WEI=1000000000000

# "ch" or "gleif" (or 0/1) -> contract source id
plus_source() {
  case "$1" in
    ch|0) echo 0 ;;
    gleif|1) echo 1 ;;
    *) echo "unknown source '$1' (use ch or gleif)" >&2; return 2 ;;
  esac
}

# Same as SupplierPulsePlus.requestHashFor() on chain (docs/SUPPLIERPULSE_PLUS.md §4.2)
plus_request_hash() {
  if [[ "$(plus_source "$1")" == 0 ]]; then
    cast keccak "[\"getCompanyProfile\",[[\"company_number\",\"$2\"]],[[\"accounts_overdue\",\"/accounts/next_accounts/overdue\"],[\"confirmation_overdue\",\"/confirmation_statement/overdue\"],[\"status\",\"/company_status\"]]]"
  else
    cast keccak "[\"getLegalEntity\",[[\"lei\",\"$2\"]],[[\"entity_status\",\"/data/attributes/entity/status\"],[\"registration_status\",\"/data/attributes/registration/status\"]]]"
  fi
}

# Salted document hash: keccak256(salt ++ file bytes), salt = 32 random bytes (0x + 64 hex).
# Used as the order's orderRef, so the order documents stay off chain and only this hash is public.
# Fails (non-zero, nothing on stdout) instead of printing an empty or partial hash.
plus_doc_hash() {
  [[ -f "$1" && -r "$1" ]] || { echo "no such file: $1" >&2; return 2; }
  [[ "$2" =~ ^0x[0-9a-fA-F]{64}$ ]] || { echo "salt must be 0x + 64 hex characters" >&2; return 2; }
  local h hex
  if printf '' | openssl dgst -keccak-256 >/dev/null 2>&1; then
    # OpenSSL >= 3.2 streams the file, so any size works
    h="$({ printf '%s' "${2#0x}" | xxd -r -p && cat "$1"; } | openssl dgst -keccak-256 -r)" || return 1
    h="0x${h%% *}"
  else
    # fallback (e.g. macOS LibreSSL): the file goes through one argument, so about 1 MiB at most
    hex="$(od -An -v -tx1 "$1" | tr -d ' \n')" || return 1
    h="$(cast keccak "$2$hex")" || { echo "could not hash $1 (too large without OpenSSL 3.2+?)" >&2; return 1; }
  fi
  h="$(echo "$h" | tr A-F a-f)"
  [[ "$h" =~ ^0x[0-9a-f]{64}$ ]] || { echo "could not hash $1" >&2; return 1; }
  echo "$h"
}

plus_new_salt() { echo "0x$(openssl rand -hex 32)"; }

# Latest block timestamp of the chain (due dates and permits use chain time)
plus_now() {
  cast block latest --rpc-url "$EVM_RPC_URL" -f timestamp
}

# Send a tx from $1 (private key). Newer Foundry wraps --json output as {"success","data",...}; unwrap it.
plus_send() {
  local key="$1"; shift
  cast send --rpc-url "$EVM_RPC_URL" --private-key "$key" --json "$@" \
    | jq '(if type == "object" and has("success") and has("data") then .data else . end)'
}

# First line of a cast call result, without cast's " [1.2e9]" suffix
plus_num() { echo "${1%% *}"; }

# Name of the custom error in a failed cast call/send output (every error in §4.6)
plus_error() {
  local sel name="unknown" e
  # older cast prints "custom error 0x<sel>", newer prints the revert data as data: "0x<sel>..."
  sel="$(echo "$1" | grep -oE '(custom error |data: "?)0x[0-9a-fA-F]{8}' | head -1 | grep -oE '0x[0-9a-fA-F]{8}' | tr 'A-F' 'a-f' || true)"
  for e in "WrongSigner(address)" "WrongRequest(bytes32,bytes32)" "StaleResponse(uint256,uint256)" \
           "FutureResponse(uint256,uint256)" "Replayed(bytes32)" "NotNewer(uint256,uint256)" \
           "NoValidPermit(uint256)" "PermitExpired(uint256,uint256)" "NotApproved(uint256)" \
           "NotDue(uint256,uint256)" "NotActive(uint8)" "NotRefundable()" "RefundNotYet(uint256)" \
           "SupplierFailed(uint256)" "NoNewerFailure()" \
           "BadOrder()" "BadSource()" "BadSupplierId()" "BadRules()" "NotAuthorized()" "TransferFailed()" \
           "InvalidSignatureLength()" "InvalidSignatureS()" "InvalidSignatureV()" "InvalidSigner()" \
           "KeyNotFound()" "NoNumber()" "NoString()" "NoBool()"; do
    [[ "$(cast sig "$e")" == "$sel" ]] && name="$e"
  done
  echo "$name"
}

# Screen labels for failedRules bits (§4.3, v1.1)
plus_rule_labels() {
  local f="$1" out=()
  (( f & 0x80 )) && out+=("registry status not active")
  (( f & 0x02 )) && out+=("accounts overdue")
  (( f & 0x04 )) && out+=("confirmation statement overdue")
  (( f & 0x08 )) && out+=("LEI renewal overdue")
  if [[ ${#out[@]} -eq 0 ]]; then echo none; else printf '%s, ' "${out[@]}" | sed 's/, $//'; fi
}

# "500,1000" tokens -> "[500000000000000,1000000000000000]" wei
plus_amounts_wei() {
  local a list=()
  for a in ${1//,/ }; do list+=("$((a * PLUS_TOKEN_WEI))"); done
  local IFS=","; echo "[${list[*]}]"
}

# "500,1000" tokens -> total in wei (the msg.value of createOrder)
plus_total_wei() {
  local a total=0
  for a in ${1//,/ }; do total=$((total + a * PLUS_TOKEN_WEI)); done
  echo "$total"
}

# "+1200,1793443500" -> "[<now+1200>,1793443500]" (relative entries are counted from chain time)
plus_dues() {
  local d list=() now; now="$(plus_now)"
  for d in ${1//,/ }; do
    if [[ "$d" == +* ]]; then list+=("$((now + ${d#+}))"); else list+=("$d"); fi
  done
  local IFS=","; echo "[${list[*]}]"
}
