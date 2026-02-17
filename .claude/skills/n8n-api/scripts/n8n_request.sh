#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.claude/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

: "${N8N_BASE_URL:?N8N_BASE_URL not set}"
: "${N8N_API_KEY:?N8N_API_KEY not set}"

METHOD="${1:?Usage: n8n_request.sh <METHOD> <PATH> [BODY]}"
PATH_ARG="${2:?Usage: n8n_request.sh <METHOD> <PATH> [BODY]}"
BODY="${3:-}"

CURL_ARGS=(
  -sk
  -X "$METHOD"
  -H "X-N8N-API-KEY: $N8N_API_KEY"
  -H "Content-Type: application/json"
)

if [[ -n "$BODY" ]]; then
  CURL_ARGS+=(-d "$BODY")
fi

RESPONSE=$(curl "${CURL_ARGS[@]}" "${N8N_BASE_URL}${PATH_ARG}")

if command -v jq &>/dev/null; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
