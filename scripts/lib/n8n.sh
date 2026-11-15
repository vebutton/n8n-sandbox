# Shared by pull.sh and push.sh. Source it; it sets N8N_URL, ROOT, LIB and n8n_api.
# The API key is read from $N8N_API_KEY and passed to curl on stdin, never in argv.

N8N_URL="${N8N_URL:-http://localhost:5678}"
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$LIB/../.." && pwd)"

printenv N8N_API_KEY >/dev/null || { echo "N8N_API_KEY is not set" >&2; exit 1; }

# n8n_api METHOD PATH OUT_FILE [BODY_FILE]
# Writes the response body to OUT_FILE and prints the HTTP status code.
n8n_api() {
  local method="$1" path="$2" out="$3" body="${4:-}"
  {
    printf 'header = "X-N8N-API-KEY: %s"\n' "$N8N_API_KEY"
    if [ -n "$body" ]; then
      printf 'header = "Content-Type: application/json"\ndata-binary = "@%s"\n' "$body"
    fi
  } | curl -sS -K - -X "$method" -o "$out" -w '%{http_code}' "$N8N_URL/api/v1/$path"
}

# api_error OUT_FILE: the API's error message from a failed call.
api_error() {
  jq -r '.message // empty' "$1" 2>/dev/null || head -c 300 "$1"
}

# njq: jq with normalize.jq loaded.
njq() {
  jq -L "$LIB" "include \"normalize\"; $1" "${@:2}"
}
