#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
  printf '.env не найден: %s\n' "$ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

BASE_COMPOSE=(docker compose -f docker-compose.yml)
if [ -d "${ROOT_DIR}/compose.overrides" ]; then
  while IFS= read -r file; do
    BASE_COMPOSE+=(-f "$file")
  done < <(ls "${ROOT_DIR}/compose.overrides"/*.yml 2>/dev/null || true)
fi

check_url() {
  local label="$1"
  local url="$2"
  local user="${3:-}"
  local pass="${4:-}"
  if [ -n "$user" ]; then
    curl -fsS -u "${user}:${pass}" "$url" >/dev/null
  else
    curl -fsS "$url" >/dev/null
  fi
  printf 'ok: %s\n' "$label"
}

retry_with_remediation() {
  local label="$1"
  local service="$2"
  local url="$3"
  local user="${4:-}"
  local pass="${5:-}"

  if check_url "$label" "$url" "$user" "$pass" 2>/dev/null; then
    return 0
  fi

  printf 'warn: %s не ответил, пробую восстановление через docker compose up -d %s\n' "$label" "$service"
  "${BASE_COMPOSE[@]}" up -d "$service" >/dev/null
  sleep 5
  check_url "$label" "$url" "$user" "$pass"
}

check_worker_urls() {
  local routing_file="${ROOT_DIR}/n8n/local-files/opencode-routing.json"
  if [ ! -f "$routing_file" ]; then
    return
  fi

  while IFS= read -r line; do
    alias="$(printf '%s' "$line" | jq -r '.alias')"
    service="$(printf '%s' "$line" | jq -r '.service')"
    health_url="$(printf '%s' "$line" | jq -r '.healthUrl')"
    username="$(printf '%s' "$line" | jq -r '.username')"
    password_env="$(printf '%s' "$line" | jq -r '.passwordEnv // empty')"
    password="${!password_env:-}"
    retry_with_remediation "worker ${alias}" "$service" "$health_url" "$username" "$password"
  done < <(jq -c '.workers | to_entries[] | .value' "$routing_file")
}

printf 'Проверяю docker compose services...\n'
"${BASE_COMPOSE[@]}" ps

printf '\nПроверяю n8n...\n'
retry_with_remediation "n8n" "n8n" "http://127.0.0.1:${N8N_PORT:-5678}" "${N8N_BASIC_AUTH_USER:-admin}" "${N8N_BASIC_AUTH_PASSWORD}"

if [ -f "${ROOT_DIR}/n8n/local-files/opencode-routing.json" ]; then
  printf '\nПроверяю routing-файл...\n'
  jq . "${ROOT_DIR}/n8n/local-files/opencode-routing.json" >/dev/null
  printf 'ok: routing json\n'
  printf '\nПроверяю все OpenCode worker-ы из routing-файла...\n'
  check_worker_urls
else
  printf '\nПроверяю OpenCode worker-1...\n'
  check_url "opencode-worker-1" "http://127.0.0.1:${OPENCODE_WORKER_1_PORT:-4096}/global/health" "opencode" "${OPENCODE_WORKER_1_PASSWORD}"
fi

printf '\nПроверяю starter workflow в n8n...\n'
bash "${ROOT_DIR}/scripts/bootstrap-n8n-workflow.sh"

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  printf '\nПроверяю Telegram интеграцию...\n'
  if ! bash "${ROOT_DIR}/scripts/bootstrap-telegram-integration.sh"; then
    printf 'warn: Telegram bootstrap не завершился успешно\n' >&2
  fi
fi

printf '\nИтог: базовая проверка пройдена.\n'
