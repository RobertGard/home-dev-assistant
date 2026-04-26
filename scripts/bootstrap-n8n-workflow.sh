#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
WORKFLOW_FILE="${ROOT_DIR}/n8n/local-files/workflows/opencode-task-entry.json"
WORKFLOW_NAME="OpenCode Task Entry"
WORKFLOW_ID="900001"

if [ ! -f "$ENV_FILE" ]; then
  printf '.env не найден: %s\n' "$ENV_FILE" >&2
  exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
  printf 'workflow json не найден: %s\n' "$WORKFLOW_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

N8N_URL="http://127.0.0.1:${N8N_PORT:-5678}"

BASE_COMPOSE=(docker compose -f docker-compose.yml)
if [ -d "${ROOT_DIR}/compose.overrides" ]; then
  while IFS= read -r file; do
    BASE_COMPOSE+=(-f "$file")
  done < <(ls "${ROOT_DIR}/compose.overrides"/*.yml 2>/dev/null || true)
fi

wait_for_n8n() {
  local attempt=1
  local max_attempts=60
  while [ "$attempt" -le "$max_attempts" ]; do
    if curl -fsS -u "${N8N_BASIC_AUTH_USER:-admin}:${N8N_BASIC_AUTH_PASSWORD}" "${N8N_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
    attempt=$((attempt + 1))
  done
  return 1
}

if ! wait_for_n8n; then
  printf 'n8n не ответил вовремя на %s\n' "$N8N_URL" >&2
  exit 1
fi

"${BASE_COMPOSE[@]}" exec -T n8n n8n import:workflow --input=/files/workflows/opencode-task-entry.json >/dev/null
"${BASE_COMPOSE[@]}" exec -T n8n n8n update:workflow --id="${WORKFLOW_ID}" --active=true >/dev/null
"${BASE_COMPOSE[@]}" restart n8n n8n-worker >/dev/null

if ! wait_for_n8n; then
  printf 'n8n не поднялся после активации workflow\n' >&2
  exit 1
fi

printf 'workflow готов: %s (id=%s)\n' "$WORKFLOW_NAME" "$WORKFLOW_ID"
