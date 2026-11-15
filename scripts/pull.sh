#!/usr/bin/env bash
# Pull every workflow from n8n into workflows/<slug>.json, normalised for clean diffs.
#
# Usage: scripts/pull.sh
# Env:   N8N_API_KEY (required; passed to curl on stdin, never in argv)
#        N8N_URL     (optional; default http://localhost:5678)
#
# - Keeps the n8n `id` in each file so push can tell an update from a create.
# - Strips volatile fields (timestamps, versionId, activeVersion, shared, meta, ...).
# - Sorts nodes by name and all object keys, so re-pulls only diff on real changes.
# - A workflow renamed in n8n moves to its new slug; files for workflows no longer in
#   n8n are reported as stale, never deleted. Archived workflows are skipped.
# - Warns (never blocks) on pinned data and on literal values in secret-looking
#   parameters. Values are never printed, only where they are.
set -euo pipefail

N8N_URL="${N8N_URL:-http://localhost:5678}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/workflows"

printenv N8N_API_KEY >/dev/null || { echo "N8N_API_KEY is not set" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

api() {
  printf 'header = "X-N8N-API-KEY: %s"\n' "$N8N_API_KEY" | curl -fsS -K - "$N8N_URL/api/v1/$1"
}

# Fetch all pages of the workflow list (it already includes nodes and connections).
n=0 cursor=''
while :; do
  n=$((n + 1))
  api "workflows?limit=250${cursor:+&cursor=$cursor}" >"$TMP/page-$n.json"
  cursor="$(jq -r '.nextCursor // empty' "$TMP/page-$n.json")"
  [ -n "$cursor" ] || break
done

# One line per live workflow: {file, wf, warnings}. Slug collisions get the id appended.
jq -s -c '
  def slug: ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("^-+|-+$"; "");
  def secretish: type == "string"
    and test("pass(word)?|secret|token|api[-_ ]?key|authorization|bearer|cookie"; "i");
  def literal: type == "string" and length > 0 and (startswith("=") | not);
  def norm: {
      id, name, active,
      nodes: (.nodes | sort_by(.name)),
      connections, settings,
      pinData: (.pinData // {}),
      staticData,
      tags: ([.tags[]?.name] | sort)
    } + (if (.nodeGroups // [] | length) > 0 then {nodeGroups} else {} end);
  def warnings: [
      (if (.pinData // {} | length) > 0
        then "pinned data on: \(.pinData | keys | join(", "))" else empty end),
      (.nodes[] | .name as $n | (.parameters // {}) |
        ( paths(scalars) as $p
          | select(($p[-1] | secretish) and (getpath($p) | literal))
          | "\($n): literal value at \($p | map(tostring) | join("."))" ),
        ( .. | objects | select((.name | secretish) and (.value | literal))
          | "\($n): literal value for \(.name)" ))
    ] | unique;
  [.[].data[]] | map(select(.isArchived | not))
  | map(. + {slug: ((.name | slug) as $s | if $s == "" then .id else $s end)})
  | group_by(.slug)
  | map(if length > 1 then map(.slug += "-" + .id) else . end) | add // []
  | .[] | {file: "\(.slug).json", wf: norm, warnings: warnings}
' "$TMP"/page-*.json >"$TMP/live.jsonl"

jq -s -r '[.[].data[] | select(.isArchived) | .name] | .[] | "skipped (archived): \(.)"' \
  "$TMP"/page-*.json

mkdir -p "$OUT"

# Index existing files by id, so renames move the file instead of duplicating it.
: >"$TMP/index.tsv"
for f in "$OUT"/*.json; do
  [ -e "$f" ] || continue
  printf '%s\t%s\n' "$(jq -r '.id // "-"' "$f")" "$(basename "$f")" >>"$TMP/index.tsv"
done

warned=0
while IFS= read -r line; do
  file="$(jq -r '.file' <<<"$line")"
  id="$(jq -r '.wf.id' <<<"$line")"
  jq -S '.wf' <<<"$line" >"$TMP/new.json"

  old="$(awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$TMP/index.tsv")"
  if [ -n "$old" ] && [ "$old" != "$file" ]; then
    rm "$OUT/$old"
    echo "renamed:   workflows/$old -> workflows/$file"
  elif [ ! -e "$OUT/$file" ]; then
    echo "new:       workflows/$file"
  elif cmp -s "$TMP/new.json" "$OUT/$file"; then
    echo "unchanged: workflows/$file"
  else
    echo "updated:   workflows/$file"
  fi
  mv "$TMP/new.json" "$OUT/$file"

  while IFS= read -r w; do
    echo "  WARN $file: $w"
    warned=1
  done < <(jq -r '.warnings[]' <<<"$line")
done <"$TMP/live.jsonl"

# Files whose id no longer exists in n8n (or that have no id at all).
jq -r '.wf.id' "$TMP/live.jsonl" | sort >"$TMP/live-ids.txt"
while IFS=$'\t' read -r id f; do
  if [ "$id" = "-" ] || ! grep -qxF "$id" "$TMP/live-ids.txt"; then
    echo "stale (not in n8n): workflows/$f"
  fi
done <"$TMP/index.tsv"

if [ "$warned" -eq 1 ]; then
  echo "Review the warnings above before committing." >&2
fi
