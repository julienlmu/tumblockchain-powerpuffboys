#!/usr/bin/env bash
# Salted hash of an order document (contract, PO, delivery terms), for use as the order's orderRef.
# The document and its salt stay with buyer and supplier; only the hash goes on chain.
# Usage: scripts/plus-doc-hash.sh <file> [salt]   (a new random salt if none is given)
# Prints ORDER_DOC_HASH and ORDER_DOC_SALT. Keep the salt: without it nobody can prove the document.
# Exits non-zero and prints nothing on stdout if the file cannot be hashed.
set -euo pipefail
source "$(dirname "$0")/plus-lib.sh"
[[ $# -ge 1 ]] || { sed -n '2,6p' "$0" >&2; exit 2; }
salt="${2:-$(plus_new_salt)}"
hash="$(plus_doc_hash "$1" "$salt")"
echo "ORDER_DOC_HASH=$hash"
echo "ORDER_DOC_SALT=$salt"
