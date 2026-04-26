#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
INGRESS_TEMPLATE="${ROOT_DIR}/n8n/local-files/workflows/templates/telegram-task-ingress.template.json"
DISPATCH_TEMPLATE="${ROOT_DIR}/n8n/local-files/workflows/templates/telegram-task-dispatcher.template.json"
INGRESS_WORKFLOW="${ROOT_DIR}/n8n/local-files/workflows/telegram-task-ingress.json"
DISPATCH_WORKFLOW="${ROOT_DIR}/n8n/local-files/workflows/telegram-task-dispatcher.json"
TASKS_TABLE_NAME="agent_tasks"
STATE_FILE="${ROOT_DIR}/.n8n-bootstrap-state.json"

if [ ! -f "$ENV_FILE" ]; then
  printf '.env не найден: %s\n' "$ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  printf 'TELEGRAM_BOT_TOKEN не задан, Telegram интеграция пропущена.\n'
  exit 0
fi

if [ -z "${N8N_API_KEY:-}" ]; then
  printf 'N8N_API_KEY не задан. По официальной документации REST API n8n требует API key.\n' >&2
  printf 'Создай ключ в Settings -> n8n API и добавь его в .env, затем запусти:\n' >&2
  printf 'bash ./scripts/bootstrap-telegram-integration.sh\n' >&2
  exit 1
fi

N8N_URL="http://127.0.0.1:${N8N_PORT:-5678}"
TELEGRAM_CREDENTIAL_NAME="Telegram Bot"

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

render_template() {
  local input="$1"
  local output="$2"
  local cred_id="$3"
  local cred_name="$4"
  local table_id="$5"
  sed \
    -e "s/__TELEGRAM_CREDENTIAL_ID__/${cred_id}/g" \
    -e "s/__TELEGRAM_CREDENTIAL_NAME__/${cred_name}/g" \
    -e "s/__TASKS_TABLE_ID__/${table_id}/g" \
    "$input" > "$output"
}

if ! wait_for_n8n; then
  printf 'n8n не поднялся вовремя\n' >&2
  exit 1
fi

tasks_table_id="$(curl -fsS \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  "${N8N_URL}/api/v1/data-tables" | jq -r --arg name "$TASKS_TABLE_NAME" '.data // . // [] | map(select(.name == $name)) | first | .id // empty')"

if [ -z "$tasks_table_id" ]; then
  tasks_table_id="$(curl -fsS \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d '{"name":"agent_tasks","columns":[{"name":"source","type":"string"},{"name":"chat_id","type":"string"},{"name":"user_id","type":"string"},{"name":"username","type":"string"},{"name":"worker_alias","type":"string"},{"name":"mode","type":"string"},{"name":"command_name","type":"string"},{"name":"prompt","type":"string"},{"name":"context_json","type":"string"},{"name":"status","type":"string"},{"name":"session_id","type":"string"},{"name":"pending_question","type":"string"},{"name":"pending_options_json","type":"string"},{"name":"result_text","type":"string"}]}' \
    "${N8N_URL}/api/v1/data-tables" | jq -r '.id // .data.id')"
fi

if [ -z "$tasks_table_id" ] || [ "$tasks_table_id" = "null" ]; then
  printf 'Не удалось создать или найти Data Table agent_tasks\n' >&2
  exit 1
fi

credential_id=""
if [ -f "$STATE_FILE" ]; then
  credential_id="$(jq -r '.telegramCredentialId // empty' "$STATE_FILE" 2>/dev/null || true)"
fi

if [ -z "$credential_id" ]; then
  credential_id="$(curl -fsS \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "{\"name\":\"${TELEGRAM_CREDENTIAL_NAME}\",\"type\":\"telegramApi\",\"nodesAccess\":[{\"nodeType\":\"n8n-nodes-base.telegram\"},{\"nodeType\":\"n8n-nodes-base.telegramTrigger\"}],\"data\":{\"accessToken\":\"${TELEGRAM_BOT_TOKEN}\"}}" \
    "${N8N_URL}/rest/credentials" | jq -r '.data.id // .id')"
fi

if [ -z "$credential_id" ] || [ "$credential_id" = "null" ]; then
  printf 'Не удалось создать Telegram credential в n8n\n' >&2
  exit 1
fi

printf '{"telegramCredentialId":"%s","tasksTableId":"%s"}\n' "$credential_id" "$tasks_table_id" > "$STATE_FILE"

render_template "$INGRESS_TEMPLATE" "$INGRESS_WORKFLOW" "$credential_id" "$TELEGRAM_CREDENTIAL_NAME" "$tasks_table_id"
render_template "$DISPATCH_TEMPLATE" "$DISPATCH_WORKFLOW" "$credential_id" "$TELEGRAM_CREDENTIAL_NAME" "$tasks_table_id"

"${BASE_COMPOSE[@]}" exec -T n8n n8n import:workflow --input=/files/workflows/telegram-task-ingress.json >/dev/null
"${BASE_COMPOSE[@]}" exec -T n8n n8n import:workflow --input=/files/workflows/telegram-task-dispatcher.json >/dev/null
"${BASE_COMPOSE[@]}" exec -T n8n n8n update:workflow --id=900010 --active=true >/dev/null
"${BASE_COMPOSE[@]}" exec -T n8n n8n update:workflow --id=900011 --active=true >/dev/null
"${BASE_COMPOSE[@]}" restart n8n n8n-worker >/dev/null

printf 'Telegram credential и workflow импортированы.\n'
