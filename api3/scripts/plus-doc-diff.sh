#!/usr/bin/env bash
# Change report for two versions of an order document: what changed between the agreed version and the one presented.
# Prints a line diff, then a short plain-language summary from a language model when ANTHROPIC_API_KEY is set
# (env or api3/.env); without a key it prints the diff only. The report is informational for the reviewer:
# payments are decided by the contract and the signed registry records, never by this summary.
# Usage: scripts/plus-doc-diff.sh <agreed file> <presented file>
# env: [ANTHROPIC_API_KEY] [DOC_SUMMARY_MODEL=claude-haiku-5-5] [DOC_SUMMARY_URL=https://api.anthropic.com/v1/messages]
set -euo pipefail
[[ $# -eq 2 ]] || { sed -n '2,7p' "$0" >&2; exit 2; }
for f in "$1" "$2"; do [[ -f "$f" ]] || { echo "no such file: $f" >&2; exit 2; }; done

# PDFs are compared as text when pdftotext is installed; other binary files cannot be diffed line by line
as_text() {
  if [[ "$1" == *.pdf ]] && command -v pdftotext >/dev/null; then pdftotext -layout "$1" -
  elif LC_ALL=C grep -qI . "$1" || [[ ! -s "$1" ]]; then cat "$1"
  else echo "binary file, no text diff: $1" >&2; return 1; fi
}
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
as_text "$1" > "$tmp/agreed"; as_text "$2" > "$tmp/presented"
diff -u --label agreed --label presented "$tmp/agreed" "$tmp/presented" > "$tmp/diff" || true
if [[ ! -s "$tmp/diff" ]]; then echo "No text differences (the files differ only in bytes the text view does not show)."; exit 0; fi

echo "=== Changes (agreed -> presented; informational only, does not affect payments) ==="
cat "$tmp/diff"

key="${ANTHROPIC_API_KEY:-}"
envfile="$(dirname "$0")/../.env"
if [[ -z "$key" && -f "$envfile" ]]; then key="$(grep -E '^ANTHROPIC_API_KEY=' "$envfile" | tail -1 | cut -d= -f2- | tr -d "\"' \r" || true)"; fi
if [[ -z "$key" ]]; then echo; echo "(no ANTHROPIC_API_KEY: summary skipped, the diff above is the full report)"; exit 0; fi

prompt="Two versions of a purchase-order document are compared below as a unified diff ('-' = agreed version, '+' = version now presented). In at most 6 short bullet points, state in plain language what changed, quoting the old and new values for quantities, prices, dates, delivery terms and parties. Do not judge whether anyone should be paid or who is right; only describe the changes.

$(head -c 20000 "$tmp/diff")"
body="$(jq -n --arg m "${DOC_SUMMARY_MODEL:-claude-haiku-5-5}" --arg p "$prompt" \
  '{model: $m, max_tokens: 400, messages: [{role: "user", content: $p}]}')"
if ! resp="$(curl -sS --max-time 30 "${DOC_SUMMARY_URL:-https://api.anthropic.com/v1/messages}" \
  -H "x-api-key: $key" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d "$body")"; then
  echo; echo "(summary request failed: the diff above is the full report)"; exit 0
fi
summary="$(echo "$resp" | jq -r '[.content[]? | select(.type == "text") | .text] | join("\n")' 2>/dev/null || true)"
if [[ -z "$summary" ]]; then
  echo; echo "(no summary: $(echo "$resp" | jq -r '.error.message // "unexpected response"' 2>/dev/null || echo "unexpected response"))"; exit 0
fi
echo
echo "=== Summary (informational only, does not affect payments) ==="
echo "$summary"
