# OpenCode + n8n

Этот проект поднимает удобную связку:

- `n8n` как оркестратор
- `opencode-worker-*` как исполнители
- `postgres` и `redis` как инфраструктура для `n8n`
- Telegram как встроенный канал команд и ответов внутри `n8n`
- optional `opencode-gateway`, если когда-нибудь понадобится отдельная JSON-прослойка

## Самое важное

### Что такое worker

- `worker` это контейнер с OpenCode
- он выполняет инженерные задачи: клонирует репозитории, ставит зависимости, запускает тесты, поднимает Docker-инфраструктуру проекта
- если worker-ов несколько, их можно разделять по ролям или проектам

Примеры:

- `primary` для основного проекта
- `sandbox` для экспериментов
- отдельный worker под frontend
- отдельный worker под devops

### Нужен ли gateway

Нет, обычно не нужен.

`opencode-gateway` это необязательная прослойка. Она нужна только если ты хочешь:

- отдельную HTTP-точку `/run`
- строго нормализованный JSON между `n8n` и OpenCode
- вынести разбор ответа из `n8n`

Что такое `/run`:

- это endpoint именно gateway-прослойки
- `n8n` отправляет туда один запрос
- gateway внутри сам идет в OpenCode
- при необходимости сам создает сессию
- сам прокидывает контекст
- и возвращает уже один подготовленный ответ

Если тебе удобнее работать напрямую из `n8n` с OpenCode, gateway можно не использовать вообще.

## Архитектура

### Сервисы

1. `postgres`
   База данных для `n8n`.

2. `redis`
   Очередь для `n8n` queue mode.

3. `n8n`
   Основной оркестратор с UI, webhook-ами и workflow.

4. `n8n-worker`
   Фоновый worker для выполнения задач `n8n`.

5. `opencode-worker-1`
   Основной OpenCode worker.

6. `opencode-gateway`
   Опциональная прослойка, включается через профиль `gateway`.

Важно:

- один worker это нормальная полноценная конфигурация
- второй worker и все следующие создаются одинаково через generated compose override-файлы

### Сети

- `edge`: для сервисов, которые торчат наружу на localhost-порты
- `control`: внутренняя сеть для общения `n8n -> OpenCode worker-*`
- `data`: внутренняя сеть для `postgres` и `redis`

Это сделано для того, чтобы:

- не светить базу и redis лишний раз
- отделить control-plane от внешнего трафика
- нормально масштабировать несколько worker-ов

## Что умеют OpenCode worker-ы

Worker настроен не как демо-контейнер, а как нормальный dev-worker.

### Ставится базовый инструментарий

- `opencode`
- `git`, `gh`, `jq`, `ripgrep`, `fd`, `bat`, `tree`
- `docker`, `docker compose`
- `node`, `pnpm`, `bun`, `turbo`, `tsx`, `typescript`
- `eslint`, `prettier`, `biome`, `vitest`, `jest`, `ts-jest`, `ts-node`, `vite`, `nx`, `nodemon`, `prisma`, `typescript-language-server`, `vscode-langservers-extracted`
- `python3`, `pip`, `uv`
- `shellcheck`, `yamllint`, `sqlite3`

### Ставятся agent-расширения

- `get-shit-done`
- `superpowers`
- `Context7`
- `Serena`

### MCP

По умолчанию включены:

- `context7`
- `serena`

Установлены, но по умолчанию выключены:

- `filesystem`
- `gitmcp`
- `memory`

Это сделано, чтобы не раздувать контекст тем, что OpenCode и так умеет делать сам.

### Дополнительная защита

Включены local plugins OpenCode:

- прокидывание нужных env в shell
- защита от чтения `.env`

## Как задаются репозитории

У каждого worker-а есть свой каталог репозиториев:

- `workers/worker-1/repos.json`

Если worker-ов больше одного, setup-скрипт создает дополнительные каталоги вида:

- `workers/<имя-worker>/repos.json`

Пример:

```json
{
  "repos": [
    {
      "slug": "ai-backend-marketing-agent",
      "url": "https://github.com/sixmo-team/ai-backend-marketing-agent.git",
      "ref": "main",
      "path": "ai-backend-marketing-agent",
      "install_dependencies": true,
      "package_manager": "auto",
      "turbo_smoke": true,
      "turbo_tasks": ["build", "test"],
      "install_gsd_local": true,
      "auto_start_docker": true
    }
  ]
}
```

Что это дает:

- worker сам клонирует или обновляет repo
- сам ставит зависимости
- сам запускает turbo-задачи
- сам инициализирует local GSD, если нужно
- сам поднимает полную Docker-инфраструктуру проекта, если включено `auto_start_docker`

## Telegram и очередь задач

Telegram встроен именно в контекст `n8n`, а не как внешняя надстройка.

Используется схема:

1. `Telegram Trigger` в `n8n` получает входящее сообщение
2. workflow превращает это сообщение в задачу
3. задача записывается во встроенную `n8n Data Table` `agent_tasks`
4. отдельный workflow-диспетчер периодически забирает следующую задачу из очереди
5. задача уходит в нужный OpenCode worker
6. когда задача завершена, `n8n` отправляет результат обратно в Telegram через `Telegram` node

То есть:

- команды приходят из Telegram
- очередь живет во встроенной `n8n Data Table`
- маршрутизация и исполнение живут в `n8n`
- ответ возвращается в Telegram

### Таблица очереди

При bootstrap Telegram-интеграции через `n8n API` создается Data Table:

- `agent_tasks`

Она используется как встроенная durable queue для команд.

### Telegram credentials в n8n

По официальной документации `n8n` для работы с credentials через REST API нужен `N8N_API_KEY`.

Поэтому для полной автоматизации Telegram-слоя используются:

- `TELEGRAM_BOT_TOKEN`
- `N8N_API_KEY`

Если `TELEGRAM_BOT_TOKEN` задан, а `N8N_API_KEY` нет, скрипт честно предупреждает, что Telegram credential не может быть автоматически создан по официальной схеме.

## Долгие задачи и стабильность

Стек настроен на долгие задачи.

Уже выставлены длинные дефолты:

- `N8N_EXECUTIONS_TIMEOUT=604800`
- `N8N_EXECUTIONS_TIMEOUT_MAX=604800`
- `OPENCODE_PROVIDER_TIMEOUT_MS=1800000`
- `OPENCODE_PROVIDER_CHUNK_TIMEOUT_MS=900000`
- `OPENCODE_MCP_TIMEOUT_MS=120000`

Также у сервисов увеличен `stop_grace_period`.

Важно:

- если ты вызываешь OpenCode из `n8n` через `HTTP Request` node напрямую, у самого node тоже нужно поставить большой timeout или unlimited

## Первый запуск

Нормальный путь запуска: через setup-скрипт.

```bash
bash ./scripts/setup-stack.sh
```

Что делает setup-скрипт:

- задает минимум реально нужных вопросов на русском
- сначала спрашивает, сколько всего нужно worker-ов
- потом настраивает каждый worker по отдельности
- предлагает безопасные дефолты, которые можно просто подтверждать Enter
- создает `.env`
- создает `workers/worker-1/repos.json`
- для каждого дополнительного worker-а создает свой каталог и свой compose override-файл
- если ты выбираешь автозапуск, после `docker compose up` он автоматически импортирует starter workflow в `n8n`
- если заданы `TELEGRAM_BOT_TOKEN` и `N8N_API_KEY`, он автоматически создает Telegram credential и импортирует Telegram workflow
- после этого запускает базовую проверку и при необходимости повторно импортирует starter workflow
- при желании сразу запускает контейнеры

### Стандартный режим

В стандартном режиме скрипт спрашивает только то, что действительно нужно:

- секреты
- ключи API, если хочешь указать их сразу
- Telegram bot token, если хочешь сразу включить Telegram интеграцию
- сколько всего worker-ов нужно
- затем по очереди конфигурирует каждый worker
- запускать ли контейнеры сразу

### Расширенный режим

Если нужно, можно включить расширенный режим. Тогда появятся вопросы про:

- имя compose-проекта
- порты
- alias worker-ов
- timeout-ы OpenCode
- дополнительные настройки repo bootstrap

Если задан `TELEGRAM_BOT_TOKEN`, setup-скрипт также предложит `N8N_API_KEY` для автоматического создания Telegram credentials в `n8n`.

## Как реально происходит взаимодействие

### Кто принимает запрос извне

Запрос извне принимает `n8n`, а не OpenCode worker.

Обычная схема такая:

1. в `n8n` создается workflow
2. в workflow добавляется `Webhook` node
3. `n8n` сам выдает URL webhook-а
4. внешний клиент делает `POST` на этот webhook
5. дальше workflow уже решает, к какому worker отправить задачу

То есть payload вроде:

```json
{
  "worker": "primary",
  "prompt": "Проверь проект, установи зависимости и подними инфраструктуру",
  "context": ["repo=ai-backend-marketing-agent"]
}
```

попадает не в OpenCode напрямую, а в `Webhook` node внутри `n8n`.

### Как это видно в интерфейсе n8n

В интерфейсе это выглядит как обычный workflow из node-ов:

1. `Webhook`
2. `Code`
3. `HTTP Request`
4. `HTTP Request`
5. `Respond to Webhook`

В `Webhook` node ты видишь входной JSON.

В `Code` node ты видишь уже преобразованный JSON, где есть:

- выбранный worker
- `authHeader`
- готовые endpoint-ы OpenCode

В `HTTP Request` node ты просто используешь эти поля через expression.

Подробная пошаговая шпаргалка лежит здесь:

- `n8n/local-files/opencode-workflow-example.md`

Также в проекте уже лежит готовый starter workflow:

- `n8n/local-files/workflows/opencode-task-entry.json`

И Telegram workflow templates:

- `n8n/local-files/workflows/templates/telegram-task-ingress.template.json`
- `n8n/local-files/workflows/templates/telegram-task-dispatcher.template.json`

Если использовать setup-скрипт с автозапуском контейнеров, он пытается автоматически:

1. дождаться старта `n8n`
2. создать или обновить workflow `OpenCode Task Entry`
3. активировать его
4. если заданы `TELEGRAM_BOT_TOKEN` и `N8N_API_KEY`, создать Telegram credential
5. сгенерировать Telegram workflow из template
6. импортировать и активировать Telegram workflow

## Что автоматизировано, а что нет

### Уже автоматизировано

- генерация `.env`
- генерация конфигов worker-ов
- генерация routing-файла для `n8n`
- поднятие `n8n`, `postgres`, `redis`, OpenCode worker-ов
- генерация compose override-файлов для всех дополнительных worker-ов, начиная со второго
- авто-импорт starter workflow в `n8n`
- авто-bootstrap Telegram credential и Telegram workflow при наличии нужных токенов
- базовая post-install проверка
- базовое восстановление сервисов и workflow при типовых проблемах старта

### Пока не автоматизировано

- автоматическая регистрация callback URL в worker-ах

### Почему это сейчас не автоматизировано

Потому что webhook принадлежит не worker-у, а самому workflow в `n8n`.

То есть правильная модель такая:

- `n8n` сам владеет своими webhook-ами
- OpenCode worker не обязан знать webhook URL
- worker получает задачу от `n8n`, а не наоборот

## Можно ли автоматизировать webhook и workflow дальше

Да, и базовый вариант уже добавлен.

Сейчас в проекте есть:

1. starter workflow JSON для `n8n`
2. авто-импорт этого workflow через CLI `n8n`
3. Telegram workflow templates
4. скрипт автоматического создания Telegram credential через официальный REST API `n8n`

Пока не сделано только более глубокое управление, например:

- создание нескольких workflow под разные сценарии
- автоматическое обновление кастомных credential-ов для сложных node-ов

## Доступ

- `n8n`: `http://127.0.0.1:${N8N_PORT:-5678}`
- `opencode-worker-1`: `http://127.0.0.1:${OPENCODE_WORKER_1_PORT:-4096}`

Если worker-ов больше одного, дополнительные сервисы создаются через `compose.overrides/*.yml`.

OpenCode использует basic auth:

- user: `opencode`
- password: пароль конкретного worker-а из `.env`

## Константы для n8n

В `n8n` и `n8n-worker` автоматически прокидываются готовые константы:

- `OPENCODE_DEFAULT_AGENT`
- `OPENCODE_WORKER_1_ALIAS`
- `OPENCODE_WORKER_1_BASE_URL`
- `OPENCODE_WORKER_1_HEALTH_URL`
- `OPENCODE_WORKER_1_PASSWORD`
- `OPENCODE_GATEWAY_BASE_URL`

Дополнительно в `n8n/local-files/` лежат:

- `opencode-routing.json`
- `opencode-n8n-reference.md`
- `opencode-workflow-example.md`
- `workflows/opencode-task-entry.json`
- `workflows/templates/telegram-task-ingress.template.json`
- `workflows/templates/telegram-task-dispatcher.template.json`

Starter workflow уже содержит `Code` node, который знает, что надо читать `/files/opencode-routing.json`.

Секреты worker-ов при этом не хранятся в `opencode-routing.json` напрямую. Routing-файл хранит имя env-переменной с паролем, а сам пароль берется из окружения `n8n`.

То есть если ты используешь авто-импортированный workflow, тебе не нужно вручную объяснять node, откуда брать routing.

## Проверка после установки

При автозапуске setup-скрипт вызывает:

```bash
bash ./scripts/bootstrap-n8n-workflow.sh
bash ./scripts/bootstrap-telegram-integration.sh
bash ./scripts/verify-stack.sh
```

Что проверяется:

1. поднялись ли compose-сервисы
2. отвечает ли `n8n`
3. отвечают ли OpenCode worker-ы из routing-файла
4. валиден ли `opencode-routing.json`
5. корректно ли переимпортируется и активируется workflow `OpenCode Task Entry`
6. если включен Telegram-режим, может ли быть доbootstrap-лен Telegram credential и Telegram workflow

Если workflow поврежден или неактуален, bootstrap-скрипт переимпортирует его заново по фиксированному ID.

Это сделано, чтобы в интерфейсе `n8n` не вспоминать URL, алиасы и endpoint-ы из головы.

Начиная со второго worker-а, главным источником правды для маршрутизации лучше считать:

- `n8n/local-files/opencode-routing.json`

На практике лучше считать его главным источником правды уже начиная со второго worker-а.

Рекомендуемый паттерн:

1. передавать в задаче поле `worker` или `workerAlias`, например `primary`
2. в `Code` или `Set` node превращать alias в base URL worker-а
3. строить HTTP Request из env-констант
4. собирать Basic auth header из env-пароля worker-а

## Добавление нового worker-а

Есть helper-скрипт:

```bash
./opencode/bin/add-opencode-worker.sh qa 4100 workers/qa
```

Он создаст:

- override-файл в `compose.overrides/`
- папку конфигурации `workers/qa`
- начальный `repos.json`

Потом можно запустить:

```bash
docker compose -f docker-compose.yml -f compose.overrides/opencode-qa.yml up -d --build opencode-qa
```

## Коротко по сути

- `n8n` это оркестратор
- OpenCode worker-ы это исполнители
- gateway обычно не нужен
- репозитории задаются через конфиг, а не через хардкод имен контейнеров
- setup-скрипт должен быть основным способом установки
