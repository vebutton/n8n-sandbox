#!/usr/bin/env bash
# Push workflow files to n8n: update the workflow when the file has an `id`, create one
# when it has none (and write the new id back into the file).
#
# Usage: scripts/push.sh [--force] [--publish] FILE...
# Env:   N8N_API_KEY (required; passed to curl on stdin, never in argv)
#        N8N_URL     (optional; default http://localhost:5678)
#
# - Sends only the fields the API accepts (name, nodes, connections, settings, pinData,
#   staticData, nodeGroups). Tags and activation are not pushed.
# - Refuses to update a workflow whose n8n copy differs from the file's last commit:
#   it was edited in the UI since, and pushing would overwrite that. Pull and merge
#   first, or pass --force.
# - A published workflow gets the change as a draft; its live version is untouched.
#   Pass --publish to put the change live.
# - After each push, compares what n8n stored with the file and says if they differ.
set -euo pipefail

. "$(dirname "$0")/lib/n8n.sh"

force=0 publish=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --publish) publish=true ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
  shift
done
[ $# -gt 0 ] || { echo "usage: scripts/push.sh [--force] [--publish] FILE..." >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

failed=0
fail() { echo "error:     $*" >&2; failed=1; }

for file in "$@"; do
  if ! jq -e 'type == "object" and has("name") and has("nodes")' "$file" >/dev/null 2>&1; then
    fail "$file is not a workflow file"; continue
  fi
  njq 'body' "$file" >"$TMP/body.json"
  njq 'norm' "$file" | jq -S . >"$TMP/local.json"
  njq 'warnings[]' -r "$file" | while IFS= read -r w; do echo "  WARN $file: $w"; done
  if [ "$(jq '.tags // [] | length' "$file")" -gt 0 ]; then
    echo "  note $file: tags are not pushed"
  fi
  id="$(jq -r '.id // empty' "$file")"

  # No id: create, then store the result so the next push updates it.
  if [ -z "$id" ]; then
    code="$(n8n_api POST workflows "$TMP/resp.json" "$TMP/body.json")"
    [ "$code" = 200 ] || { fail "$file: create: HTTP $code $(api_error "$TMP/resp.json")"; continue; }
    id="$(jq -r '.id' "$TMP/resp.json")"
    code="$(n8n_api GET "workflows/$id" "$TMP/remote.json")"
    [ "$code" = 200 ] || { fail "$file: created $id but re-read failed: HTTP $code"; continue; }
    njq 'norm' "$TMP/remote.json" | jq -S . >"$file"
    echo "created:   $file (id $id, written into the file)"
    continue
  fi

  code="$(n8n_api GET "workflows/$id" "$TMP/remote.json")"
  case "$code" in
    200) ;;
    404) fail "$file: workflow $id is not in n8n. Remove the id to create it anew."; continue ;;
    *) fail "$file: read $id: HTTP $code $(api_error "$TMP/remote.json")"; continue ;;
  esac
  njq 'norm' "$TMP/remote.json" | jq -S . >"$TMP/remote-norm.json"

  if cmp -s "$TMP/remote-norm.json" "$TMP/local.json"; then
    echo "unchanged: $file (n8n already matches)"
    continue
  fi

  # Has n8n moved on since the file was last committed?
  abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  rel="${abs#"$ROOT"/}"
  if [ "$force" -eq 0 ]; then
    if git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null; then
      git -C "$ROOT" show "HEAD:$rel" | njq 'norm' | jq -S . >"$TMP/head.json"
      if ! cmp -s "$TMP/head.json" "$TMP/remote-norm.json"; then
        fail "$file: n8n differs from the committed version (edited in the UI?). Run scripts/pull.sh and merge, or use --force."
        continue
      fi
    else
      echo "  note $file: not committed, so UI edits can't be detected"
    fi
  fi

  code="$(n8n_api PUT "workflows/$id?publishIfActive=$publish" "$TMP/resp.json" "$TMP/body.json")"
  [ "$code" = 200 ] || { fail "$file: update: HTTP $code $(api_error "$TMP/resp.json")"; continue; }

  code="$(n8n_api GET "workflows/$id" "$TMP/after.json")"
  [ "$code" = 200 ] || { fail "$file: updated $id but re-read failed: HTTP $code"; continue; }
  njq 'norm' "$TMP/after.json" | jq -S . >"$TMP/after-norm.json"
  status="updated:   $file"
  if [ "$(jq -r '.activeVersionId // empty' "$TMP/after.json")" != "" ] && [ "$publish" = false ]; then
    status="$status (saved as a draft; the published version is unchanged)"
  fi
  echo "$status"
  if ! cmp -s "$TMP/after-norm.json" "$TMP/local.json"; then
    echo "  note $file: n8n stored it differently from the file; scripts/pull.sh shows how:"
    diff -u "$TMP/local.json" "$TMP/after-norm.json" | sed -n '3,30p' | sed 's/^/    /'
  fi
done

exit "$failed"
