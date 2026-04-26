# OpenCode для n8n

Этот файл нужен как шпаргалка для сборки workflow в `n8n`.

## Главное правило маршрутизации

Не ориентируйся на `WORKER_1`, `WORKER_2` и так далее как на основную модель.

Основной источник правды для маршрутизации:

- `/files/opencode-routing.json`

Именно он отражает реальное число worker-ов и их alias.

## Какие env есть в n8n

Из стабильных и полезных:

- `{{$env.OPENCODE_DEFAULT_AGENT}}`
- `{{$env.OPENCODE_WORKER_1_ALIAS}}`
- `{{$env.OPENCODE_WORKER_1_BASE_URL}}`
- `{{$env.OPENCODE_WORKER_1_HEALTH_URL}}`
- `{{$env.OPENCODE_GATEWAY_BASE_URL}}`

Но для `2+` worker-ов лучше всегда опираться на routing JSON, а не на env-переменные.

## Basic auth

Worker credentials уже лежат в `/files/opencode-routing.json`, поэтому удобнее брать их оттуда через router code.

## Как выбирать worker

В payload передавай:

```json
{
  "worker": "primary"
}
```

или

```json
{
  "workerAlias": "primary"
}
```

## Готовый Code node

В starter workflow эта логика уже встроена прямо в `Code` node.

То есть dispatcher и entry workflow не зависят от внешнего JS helper-файла.

Что делает встроенный `Code` node:

- читает `/files/opencode-routing.json`
- берет `worker` или `workerAlias`
- находит нужный worker
- берет имя env-переменной с паролем из routing-файла
- собирает `authHeader`
- собирает endpoint-ы OpenCode

## Что отдает router code

- `workerAlias`
- `worker`
- `opencodeAgent`
- `authHeader`
- `endpoints.health`
- `endpoints.openapi`
- `endpoints.sessionCreate`
- `endpoints.sessionMessage`
- `endpoints.sessionCommand`
- `gateway`
- `prompt`
- `commandName`
- `sessionId`
- `context`

## Основные endpoint-ы OpenCode

- создать сессию: `{{$json.endpoints.sessionCreate}}`
- отправить сообщение: `{{$json.endpoints.sessionMessage}}`
- вызвать команду: `{{$json.endpoints.sessionCommand}}`
- проверить health: `{{$json.endpoints.health}}`

## Когда нужен gateway

Обычно не нужен.

`/run` это endpoint gateway-прослойки, а не OpenCode.

Он нужен только в схеме:

- `n8n -> gateway -> OpenCode`

Если у тебя схема:

- `n8n -> OpenCode`

то `/run` вообще не используется.
