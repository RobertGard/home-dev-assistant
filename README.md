# OpenCode + n8n

## Назначение

Этот проект поднимает self-hosted среду, в которой:

- `n8n` принимает команды и оркестрирует выполнение
- `OpenCode worker`-ы исполняют инженерные задачи
- Telegram используется как пользовательский интерфейс для постановки задач и получения ответов
- очередь задач и интерактивные уточнения живут внутри `n8n`

## Что входит в стек

### Обязательные сервисы

- `n8n`
  Основной UI, webhooks и workflow orchestration.

- `n8n-worker`
  Фоновое выполнение workflow в queue mode.

- `postgres`
  Основная база `n8n`.

- `redis`
  Очередь `n8n` queue mode.

- `opencode-worker-1`
  Первый OpenCode worker.

### Опциональные сервисы

- `caddy`
  Reverse proxy для внешнего HTTPS-доступа к `n8n`.

- дополнительные `OpenCode worker`-ы
  Создаются через `compose.overrides/*.yml`, начиная со второго worker-а.

## Как работает система

### Поток задачи

1. Пользователь отправляет команду в Telegram-бота.
2. `Telegram Trigger` в `n8n` получает сообщение.
3. Workflow ставит задачу в очередь `n8n Data Table` `agent_tasks`.
4. Dispatcher workflow выбирает следующую задачу и отправляет ее в нужный OpenCode worker.
5. OpenCode либо завершает задачу, либо просит уточнение.
6. Если нужно уточнение, `n8n` использует `Telegram sendAndWait` и продолжает ту же OpenCode session.
7. После завершения `n8n` отправляет результат обратно в Telegram.

### Формат команд в Telegram

Рекомендуемый формат команд:

```text
/task --worker="primary" --prompt="Почини CI и подними инфраструктуру"
/command --worker="primary" --name="verify"
```

Поддерживаются флаги:

- `--worker`
- `--prompt`
- `--name`

Значения рекомендуется передавать в кавычках:

```text
--worker="primary"
--prompt="Текст с пробелами"
--name="verify"
```

Формат без кавычек не считается основным и не рекомендуется.

Если сообщение отправлено без `/task` и `/command`, оно трактуется как обычный prompt для worker-а по умолчанию.

### Роли компонентов

- `n8n` отвечает за orchestration, очередь, Telegram и workflow logic
- `OpenCode worker` отвечает за код, shell, git, docker, зависимости и запуск проектов
- `Caddy` отвечает только за внешний HTTPS для `n8n`

## Возможности OpenCode worker

Worker запускается как полноценная инженерная среда.

### Базовый инструментарий

- `opencode`
- `git`, `gh`, `jq`, `ripgrep`, `fd`, `bat`, `tree`
- `docker`, `docker compose`
- `node`, `pnpm`, `bun`, `turbo`, `tsx`, `typescript`
- `eslint`, `prettier`, `biome`, `vitest`, `jest`, `ts-jest`, `ts-node`, `vite`, `nx`, `nodemon`, `prisma`, `typescript-language-server`, `vscode-langservers-extracted`
- `python3`, `pip`, `uv`
- `shellcheck`, `yamllint`, `sqlite3`

### Agent-расширения

- `get-shit-done`
- `superpowers`
- `Context7`
- `Serena`

### Поведение worker-а

Worker умеет:

- клонировать и обновлять репозитории
- ставить зависимости
- запускать тесты и build
- поднимать Docker-инфраструктуру проекта
- работать через OpenCode API по session/message/command

## Конфигурация репозиториев worker-а

У каждого worker-а свой файл:

- `workers/worker-1/repos.json`
- `workers/<worker-name>/repos.json` для дополнительных worker-ов

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

Основные поля:

- `slug`: короткое имя
- `url`: git URL
- `ref`: ветка или tag
- `path`: папка в workspace worker-а
- `install_dependencies`: ставить зависимости автоматически
- `package_manager`: `auto`, `pnpm`, `npm`, `npm-ci`, `bun`
- `turbo_smoke`: запускать ли Turbo tasks
- `turbo_tasks`: список задач Turbo
- `install_gsd_local`: инициализировать ли local GSD
- `auto_start_docker`: поднимать ли Docker-инфраструктуру проекта

## Внешний доступ к n8n

Если нужен внешний доступ, setup-скрипт спросит:

- нужен ли публичный доступ к `n8n`
- публичный домен
- email для `Let's Encrypt`

Если внешний доступ включен:

- запускается `caddy`
- `WEBHOOK_URL` становится `https://<домен>/`
- `N8N_EDITOR_BASE_URL` становится `https://<домен>/`
- `N8N_HOST` и `N8N_PROTOCOL` перестраиваются под внешний контур

### Требования для HTTPS

Чтобы SSL реально заработал:

1. домен должен указывать на сервер
2. порты `80` и `443` должны быть открыты извне
3. на сервере не должно быть другого процесса, который занимает `80/443`

## Telegram интеграция

### Что требуется

- `TELEGRAM_BOT_TOKEN`
- `N8N_API_KEY`

`N8N_API_KEY` нужен для автоматического создания Telegram credential и bootstrap Data Table по официальной схеме `n8n` API.

### Что создается автоматически

Если заданы `TELEGRAM_BOT_TOKEN` и `N8N_API_KEY`, bootstrap создает:

- Telegram credential в `n8n`
- `agent_tasks` Data Table
- workflow `Telegram Task Ingress`
- workflow `Telegram Task Dispatcher`

### Что хранится в очереди `agent_tasks`

- `task_key`
- `worker_alias`
- `status`
- `session_id`
- `pending_question`
- `pending_options_json`
- `result_text`

## Установка

### Быстрый запуск

```bash
bash ./scripts/setup-stack.sh
```

### Что спросит установщик

В стандартном режиме:

- нужен ли внешний HTTPS-доступ к `n8n`
- домен и email для TLS, если внешний доступ включен
- секреты `postgres` и `n8n`
- API ключи, если хочешь указать их сразу
- `TELEGRAM_BOT_TOKEN`, если нужен Telegram
- `N8N_API_KEY`, если нужен автоматический bootstrap Telegram в `n8n`
- сколько нужно worker-ов
- конфигурацию каждого worker-а
- запускать ли контейнеры сразу

В расширенном режиме дополнительно спрашиваются:

- имя compose-проекта
- порты
- alias worker-ов
- timeout-ы OpenCode
- дополнительные repo bootstrap настройки

### Что делает установщик

- создает `.env`
- создает `workers/*/repos.json`
- создает `compose.overrides/*.yml` для дополнительных worker-ов
- запускает контейнеры, если ты это выбрал
- импортирует workflow `OpenCode Task Entry`
- импортирует Telegram workflow, если заданы Telegram токены
- запускает проверку стека

## Ручной запуск

### Без внешнего proxy

```bash
docker compose up -d --build
```

### С внешним proxy

```bash
docker compose --profile proxy up -d --build
```

### С дополнительными worker-ами

Если есть override-файлы, укажи их явно:

```bash
docker compose -f docker-compose.yml -f compose.overrides/opencode-worker-2.yml up -d --build
```

Добавляй все нужные override-файлы через дополнительные `-f`.

Если создаешь worker через helper-скрипт, используй имя worker-а как часть имени override-файла:

```bash
./opencode/bin/add-opencode-worker.sh worker-2 4097 workers/worker-2
```

## Проверка после установки

Setup-скрипт использует:

```bash
bash ./scripts/bootstrap-n8n-workflow.sh
bash ./scripts/bootstrap-telegram-integration.sh
bash ./scripts/verify-stack.sh
```

Проверяется:

1. поднялись ли сервисы compose
2. отвечает ли `n8n`
3. отвечают ли OpenCode worker-ы из routing-файла
4. валиден ли `opencode-routing.json`
5. корректно ли импортирован `OpenCode Task Entry`
6. если включен Telegram, корректно ли создан Telegram credential и Telegram workflow

Если базовые части не поднялись, verify пытается выполнить простое remediation.

## Основные файлы

### Конфигурация

- `docker-compose.yml`
- `.env.example`
- `infra/Caddyfile`

### Setup и bootstrap

- `scripts/setup-stack.sh`
- `scripts/bootstrap-n8n-workflow.sh`
- `scripts/bootstrap-telegram-integration.sh`
- `scripts/verify-stack.sh`

### OpenCode

- `opencode/Dockerfile`
- `opencode/bin/bootstrap-opencode.sh`
- `opencode/bin/bootstrap-repos.sh`
- `opencode/bin/add-opencode-worker.sh`

### n8n

- `n8n/local-files/opencode-routing.json`
- `n8n/local-files/workflows/opencode-task-entry.json`
- `n8n/local-files/workflows/templates/telegram-task-ingress.template.json`
- `n8n/local-files/workflows/templates/telegram-task-dispatcher.template.json`

## Когда что использовать

### Если нужен только API-вызов OpenCode из внешней системы
Используй workflow `OpenCode Task Entry`.

### Если нужен Telegram-бот с очередью и уточнениями
Используй `Telegram Task Ingress` + `Telegram Task Dispatcher`.

### Если нужен внешний публичный webhook для Telegram
Включай внешний доступ через `Caddy` и домен с HTTPS.

## Кратко

- `n8n` оркестрирует
- OpenCode worker-ы исполняют
- Telegram встроен в `n8n`
- очередь задач живет во встроенных `n8n Data Tables`
- внешний HTTPS для `n8n` делает `Caddy`
- установка и bootstrap идут через `scripts/setup-stack.sh`
