# OpenCode на удалённом сервере с внешним доступом, Docker-доступом и очередью задач через узловую систему

## Что имеет смысл строить

Под твои ограничения — self-hosted, coding-first, без конструирования “своего” агентного фреймворка, с возможностью отдавать команды извне и давать агенту доступ к shell, пакетам и контейнерам — OpenCode сейчас выглядит одним из самых прямых open-source вариантов. У него есть headless HTTP-сервер (`opencode serve`), OpenAPI по `/doc`, официальный JS/TS SDK, built-in агент `build` с полным доступом к shell/file tools, встроенные permissions, slash-commands, плагины и API для сессий, сообщений, команд и shell. Более продвинутый коммерческий entity["company","Cursor","ai code editor"] теперь тоже умеет self-hosted cloud agents, но в его модели orchestration и inference остаются на стороне Cursor, а внутри твоей инфраструктуры живёт worker, который исполняет tool calls; то есть это уже не полностью “мой backend”, а hybrid-подход. Для полностью контролируемого backend-сценария у себя на сервере OpenCode подходит лучше. citeturn16view0turn12view2turn12view4turn12view3turn12view0turn21view0turn21view2

Для узловой оркестрации я бы выбрал entity["company","n8n","workflow automation"], а не Flowise. Причина простая: n8n официально поддерживает Docker Compose self-hosting, reverse proxy, webhooks, Postgres, queue mode с main/worker и Redis, а также удобные узлы для HTTP, Postgres, Code, Schedule, Wait и Respond to Webhook. Flowise AgentFlow V2 действительно силён в multi-agent визуальном дизайне, shared state, loops, branching и HITL, но сами его docs прямо противопоставляют Agentflow классическим automation-платформам вроде n8n; для durable очереди задач, приёма внешних команд и operational glue-кода n8n практичнее, а Flowise я бы оставил как опцию только если тебе важнее именно визуальная мультиагентность внутри самой LLM-логики. citeturn23view0turn7view2turn6view2turn6view4turn26view0turn29view0turn29view1

Итоговый выбор под твой сценарий такой: **OpenCode как coding backend**, **n8n как внешняя узловая оркестрация и очередь**, **Postgres как durable storage для workflow/state/task queue**, **Redis для queue mode n8n**, **Docker на хосте для сборки, тестов и окружений**, **reverse proxy для внешнего доступа**, и **тонкий gateway поверх OpenCode SDK** для строгого JSON-формата ответов, чтобы узловая система не ломалась на свободном тексте модели. citeturn16view0turn19view2turn7view2turn28view0turn26view2

## Железо и целевая топология

OpenCode не публикует отдельный “официальный minimum hardware” для сервера, и это логично: его docs описывают систему как оболочку, которая умеет работать как через внешних LLM-провайдеров, так и через локальные рантаймы вроде entity["company","Ollama","local model runtime"], `llama.cpp` и LM Studio. Поэтому sizing надо считать не “по OpenCode”, а по твоему профилю работы: где идёт inference, насколько тяжёлые репозитории, сколько параллельных задач, и сколько Docker-сборок ты хочешь крутить одновременно. n8n в своих performance docs отдельно пишет, что чаще упирается в память, а не в CPU; в benchmark-примере single-instance n8n работал на 4 GB RAM. Для queue mode n8n рекомендует Postgres 13+ и не рекомендует SQLite. Ollama отдельно отмечает, что увеличение context length увеличивает потребление VRAM, локальные модели занимают дополнительное дисковое место, а quantization позволяет запускать модели на более скромном железе; в интеграционных рекомендациях Ollama приводит ориентиры порядка ~11 GB VRAM для `qwen3.5` и ~16 GB VRAM для `gemma4`. citeturn17view1turn17view0turn8view0turn8view1turn7view2turn24search10turn24search14turn24search3turn24search7

Практически я бы закладывал три профиля:

1. **Минимальный живой контур для внешних моделей**: 4 vCPU, 8 GB RAM, 100 GB SSD. Подходит для одного репозитория, одного-двух параллельных workflow и умеренных Docker-задач.
2. **Нормальный production-профиль**: 8 vCPU, 16 GB RAM, 200 GB SSD. Это оптимальная точка, если хочешь, чтобы OpenCode собирал проект, крутил тесты, запускал `docker compose`, а n8n параллельно держал очередь и webhook-обвязку.
3. **Локальные модели на том же сервере**: от 12–16 vCPU, 32 GB RAM, 300+ GB SSD и отдельная GPU. Если хочешь держать coding-model локально через Ollama, ориентируйся минимум на 16–24 GB VRAM для комфортной работы с приличными coding/reasoning моделями и не забывай, что увеличение `num_ctx` и параллельности дополнительно съедает VRAM. Это эксплуатационная оценка, а не официальный minimum от вендора. citeturn17view1turn24search7turn24search10turn24search1turn8view0turn8view1

Базовая схема, которую я рекомендую, выглядит так:

```text
Интернет
  ├─ https://agent.example.com  -> reverse proxy -> OpenCode (127.0.0.1:4096)
  └─ https://flow.example.com   -> reverse proxy -> n8n (127.0.0.1:5678)

Хост
  ├─ OpenCode systemd-service
  ├─ Docker Engine
  ├─ /srv/agent/workspace        # репозиторий/репозитории
  ├─ /opt/n8n/compose.yaml       # n8n + postgres + redis + workers
  └─ /opt/opencode-gateway       # тонкий JSON-gateway поверх SDK

n8n stack
  ├─ n8n main
  ├─ n8n worker(s)
  ├─ PostgreSQL
  └─ Redis
```

Если твоя главная задача — **один coding backend на одном сервере**, это самый прямой и легко сопровождаемый дизайн. Если позже захочешь распараллеливание по нескольким проектам, масштабируй не один гигантский OpenCode, а делай либо отдельный OpenCode instance на репозиторий, либо отдельный worker-host на проект. citeturn16view0turn7view2turn26view0

## Установка и базовая настройка OpenCode

Я бы ставил сервер на Ubuntu 24.04 LTS: текущие официальные docs Docker Engine прямо указывают Ubuntu 24.04 LTS как поддерживаемую платформу, а ecosystem вокруг systemd, reverse proxy и Docker там самая предсказуемая. citeturn2search0

Сначала создай отдельного системного пользователя и рабочие каталоги. Отдельный Unix-user важен потому, что OpenCode хранит глобальный конфиг в `~/.config/opencode/opencode.json`, а provider credentials, добавленные через `/connect`, — в `~/.local/share/opencode/auth.json`. Если потом ты запустишь сервис от другого пользователя, он не увидит ни конфиг, ни ключи. citeturn18view2turn18view4turn17view1

```bash
sudo adduser --disabled-password --gecos "" agent
sudo mkdir -p /srv/agent/workspace
sudo chown -R agent:agent /srv/agent
sudo apt update
sudo apt install -y curl git jq unzip ca-certificates build-essential ripgrep
```

OpenCode поддерживает официальный install script и npm-пакет. Для удалённого сервера я бы шёл по install script, а не по npm global install: меньше возни с Node runtime именно для самого backend-процесса. citeturn1view0

```bash
sudo -u agent -H bash -lc 'curl -fsSL https://opencode.ai/install | bash'
```

Сразу после установки создай глобальный конфиг. У OpenCode отдельно конфигурируются `server`, `permissions`, `compaction`, `watcher`, `instructions`, `autoupdate` и прочие runtime-настройки. Для продовой машины я бы **отключил auto-update** или перевёл его в notify-режим, чтобы обновления не меняли поведение сервиса без твоего контроля. Также имеет смысл включить compaction и добавить ignore-паттерны для “шумных” директорий вроде `node_modules`, `dist`, `.git`, `coverage`. citeturn18view0turn18view1turn18view2turn18view3

```bash
sudo -u agent -H mkdir -p /home/agent/.config/opencode
sudo -u agent -H tee /home/agent/.config/opencode/opencode.json >/dev/null <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "server": {
    "hostname": "127.0.0.1",
    "port": 4096
  },
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 10000
  },
  "watcher": {
    "ignore": [
      "node_modules/**",
      "dist/**",
      ".git/**",
      "coverage/**",
      ".next/**"
    ]
  }
}
EOF
sudo chown agent:agent /home/agent/.config/opencode/opencode.json
```

Дальше подними первый интерактивный доступ. OpenCode умеет `attach`-подключение к уже запущенному `serve/web` backend, а также имеет команды `/connect`, `/models` и `/init`. На практике это очень удобно: ты один раз поднимаешь backend как сервис, а дальше хочешь — подключаешься локальным TUI через SSH tunnel, хочешь — стучишься по HTTP. Команда `/connect` добавляет provider credentials, `/models` выбирает модель, а `/init` анализирует приложение и создаёт `AGENTS.md`, который потом становится суперполезным статическим контекстом для всех дальнейших задач. citeturn12view1turn12view5turn17view1turn16view0

Пример systemd-unit для OpenCode:

```ini
# /etc/systemd/system/opencode.service
[Unit]
Description=OpenCode server
After=network.target

[Service]
User=agent
Group=agent
WorkingDirectory=/srv/agent/workspace
Environment=HOME=/home/agent
Environment=PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=OPENCODE_SERVER_PASSWORD=CHANGE_ME_LONG_RANDOM_PASSWORD
ExecStart=/usr/bin/env opencode serve --hostname 127.0.0.1 --port 4096
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Запуск:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now opencode
sudo systemctl status opencode
curl -u opencode:CHANGE_ME_LONG_RANDOM_PASSWORD http://127.0.0.1:4096/global/health
```

А теперь первый admin-доступ с локальной машины:

```bash
ssh -L 4096:127.0.0.1:4096 your-server
opencode attach http://127.0.0.1:4096
```

После attach сделай три вещи подряд:

```text
/connect   # добавить ключи провайдера
/models    # выбрать модель
/init      # сгенерировать AGENTS.md
```

Это даёт тебе: постоянный backend на сервере, нормальное хранилище credentials у пользователя `agent`, и репозиторий, в котором агент уже знает, как проект собирать, тестировать и где входные точки. citeturn16view0turn12view1turn12view5turn17view1

## Доступ к entity["company","Docker","container platform"] и системным утилитам

Здесь важный момент: технически OpenCode уже умеет исполнять shell-команды через `bash` tool, но это ещё не значит, что ему нужно бездумно давать root. У Docker docs есть два load-bearing предупреждения: во-первых, Docker daemon по умолчанию работает от root; во-вторых, добавление пользователя в группу `docker` фактически даёт root-level privileges. Отдельный вариант — rootless Docker, который уменьшает blast radius, но может быть менее удобен, если тебе нужен полный набор host-level возможностей. Docker также по умолчанию слушает Unix socket, а не TCP; если ты всё-таки включаешь TCP socket, то без TLS это прямой security-риск. citeturn2search2turn1search3turn2search7turn1search10turn1search2

Ставь Docker Engine с официального apt-репозитория, а не через convenience script. Docker docs для Ubuntu прямо рекомендуют apt repo как нормальный способ для поддерживаемой установки. citeturn2search0turn2search6

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo systemctl status docker
```

Дальше у тебя два режима.

**Режим попроще, но опаснее** — добавить `agent` в docker-группу:

```bash
sudo groupadd docker || true
sudo usermod -aG docker agent
sudo loginctl terminate-user agent
```

**Режим безопаснее** — rootless Docker для отдельного пользователя. Его имеет смысл выбирать, если агенту нужен Docker, но ты не хочешь автоматически давать ему почти-root на машине. citeturn2search2turn2search7

Если ты хочешь, чтобы OpenCode сам мог ставить системные пакеты и перезапускать сервисы, лучший компромисс — **не полный passwordless sudo**, а узкий allowlist через `sudoers`. Например так:

```bash
sudo tee /etc/sudoers.d/agent-opencode >/dev/null <<'EOF'
agent ALL=(ALL) NOPASSWD: /usr/bin/apt-get update
agent ALL=(ALL) NOPASSWD: /usr/bin/apt-get install *
agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart docker
agent ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *
agent ALL=(ALL) NOPASSWD: /usr/bin/journalctl *
EOF
sudo chmod 440 /etc/sudoers.d/agent-opencode
```

После этого самое главное — **зафиксировать поведение в OpenCode permissions**, чтобы unattended-режим не зависал на подтверждениях и при этом не мог выполнять всё подряд. Критичный нюанс: docs прямо говорят, что по умолчанию OpenCode разрешает все операции без явного approval, а внешние директории и env-файлы имеют отдельные правила: доступ к внешним директориям по умолчанию `ask`, `.env` и `.env.*` — `deny`, а `.env.example` — `allow`. Для автоматического backend-режима это поведение стоит ужесточить и сделать явный allowlist для `bash`. citeturn18view4turn14view0turn14view3

Пример рабочего боевого профиля:

```bash
sudo -u agent -H tee /home/agent/.config/opencode/opencode.json >/dev/null <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "server": {
    "hostname": "127.0.0.1",
    "port": 4096
  },
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 10000
  },
  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**", "coverage/**", ".next/**"]
  },
  "permission": {
    "external_directory": {
      "/srv/agent/workspace/**": "allow",
      "/opt/**": "allow"
    },
    "bash": {
      "*": "deny",
      "git *": "allow",
      "docker *": "allow",
      "docker compose *": "allow",
      "npm *": "allow",
      "pnpm *": "allow",
      "bun *": "allow",
      "uv *": "allow",
      "pytest *": "allow",
      "go *": "allow",
      "cargo *": "allow",
      "sudo apt-get update": "allow",
      "sudo apt-get install *": "allow",
      "sudo systemctl restart docker": "allow",
      "sudo systemctl status *": "allow",
      "journalctl *": "allow",
      "ls *": "allow",
      "cat /etc/os-release": "allow"
    }
  }
}
EOF
sudo chown agent:agent /home/agent/.config/opencode/opencode.json
sudo systemctl restart opencode
```

Если тебе нужны секреты для тестов и деплоя, **не заставляй агента читать `.env` из репозитория**. У OpenCode plugins есть `shell.env` hook для инъекции переменных окружения во все shell-исполнения, а также `tool.execute.before` для дополнительной защиты, например от чтения `.env` файлов. Это правильнее, чем разрешать агенту лезть в repo secrets. citeturn25view1

Минимальный плагин для безопасной инъекции окружения:

```bash
sudo -u agent -H mkdir -p /home/agent/.config/opencode/plugins
sudo -u agent -H tee /home/agent/.config/opencode/plugins/inject-env.js >/dev/null <<'EOF'
export const InjectEnvPlugin = async () => {
  return {
    "shell.env": async (_input, output) => {
      if (process.env.NODE_ENV) output.env.NODE_ENV = process.env.NODE_ENV
      if (process.env.NPM_TOKEN) output.env.NPM_TOKEN = process.env.NPM_TOKEN
      if (process.env.OPENAI_API_KEY) output.env.OPENAI_API_KEY = process.env.OPENAI_API_KEY
      if (process.env.CI) output.env.CI = process.env.CI
    }
  }
}
EOF
```

И расширение systemd unit:

```ini
Environment=NODE_ENV=production
Environment=CI=1
EnvironmentFile=-/etc/opencode/agent.env
```

Так агент сможет запускать сборки и деплой, не читая секреты из репозитория. citeturn25view1turn14view3

## Внешний доступ и как к нему обращаться

OpenCode server имеет встроенную HTTP basic auth через `OPENCODE_SERVER_PASSWORD`, умеет публиковать OpenAPI по `/doc`, SSE по `/event` и набор REST-маршрутов для session/message/command/shell/auth. Для machine-to-machine интеграции это достаточно; то есть OpenCode реально можно держать как удалённый backend и общаться с ним извне. Для developer/admin-доступа удобнее всего либо SSH tunnel + `opencode attach`, либо reverse proxy с HTTPS и basic auth. citeturn16view0turn16view1turn19view0

Я бы **не публиковал OpenCode напрямую на `0.0.0.0`**, а оставил его на `127.0.0.1:4096` и отдал наружу через reverse proxy. Для n8n docs это вообще обязательная стандартная схема: при reverse proxy нужно вручную выставлять `WEBHOOK_URL` и `N8N_PROXY_HOPS`, а на прокси пробрасывать `X-Forwarded-*`. Для OpenCode логика такая же: loopback-сервис + публичный reverse proxy — это заметно безопаснее и проще в сопровождении. citeturn28view0turn28view1turn28view2

Пример `nginx`-конфига для OpenCode и n8n:

```nginx
server {
    server_name agent.example.com;

    auth_basic "OpenCode";
    auth_basic_user_file /etc/nginx/.htpasswd-opencode;

    location / {
        proxy_pass http://127.0.0.1:4096;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    listen 443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/agent.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/agent.example.com/privkey.pem;
}

server {
    server_name flow.example.com;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $host;
    }

    listen 443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/flow.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/flow.example.com/privkey.pem;
}
```

Создание basic-auth файла:

```bash
sudo apt install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd-opencode opencode
sudo nginx -t && sudo systemctl reload nginx
```

Проверка OpenCode извне:

```bash
curl -u opencode:YOUR_PASSWORD https://agent.example.com/global/health
curl -u opencode:YOUR_PASSWORD https://agent.example.com/doc
```

Базовый цикл обращения к OpenCode по HTTP такой:

```bash
# 1. Создать сессию
SESSION_ID=$(curl -su opencode:YOUR_PASSWORD \
  -H 'content-type: application/json' \
  -d '{"title":"task-001"}' \
  https://agent.example.com/session | jq -r '.id')

# 2. Отправить сообщение агенту build
curl -su opencode:YOUR_PASSWORD \
  -H 'content-type: application/json' \
  -d '{
    "agent": "build",
    "parts": [
      { "type": "text", "text": "Проанализируй проект, запусти тесты, исправь ошибки и собери приложение." }
    ]
  }' \
  https://agent.example.com/session/'"$SESSION_ID"'/message

# 3. Получить сообщения сессии
curl -su opencode:YOUR_PASSWORD \
  https://agent.example.com/session/'"$SESSION_ID"'/message
```

Если ты хочешь не свободный prompt, а **детерминированные reusable команды**, используй slash-commands и маршрут `POST /session/:id/command`. Это очень удобно для сценариев `/verify`, `/fix-ci`, `/docker-up`, `/deploy-staging`: нодовая система будет дёргать не raw prompt, а согласованную команду с жёстко описанным протоколом поведения. OpenCode именно для этого и поддерживает кастомные commands в `.opencode/commands`. citeturn12view3turn12view4turn16view0

## Узловая система на базе entity["company","n8n","workflow automation"]

Официальные docs n8n поддерживают Linux + Docker Compose, reverse proxy и secure HTTPS; behind proxy нужно явно выставлять `WEBHOOK_URL`, `N8N_PROXY_HOPS=1` и пробрасывать `X-Forwarded-*` headers. Для масштабирования есть queue mode с Redis и workers, а для production n8n рекомендует PostgreSQL вместо SQLite; worker concurrency можно ограничить через `--concurrency` или `N8N_CONCURRENCY_PRODUCTION_LIMIT`. Всё это делает n8n действительно хорошим “внешним пультом” для OpenCode. citeturn23view0turn27view2turn27view0turn28view0turn7view2turn26view0turn22search4

Ставить я бы так: `n8n + postgres + redis + n8n-worker` в Docker Compose, а наружу публиковать только `127.0.0.1:5678`, который уже заберёт твой reverse proxy.

Подготовка каталога:

```bash
sudo mkdir -p /opt/n8n
sudo chown -R $USER:$USER /opt/n8n
cd /opt/n8n
```

`.env`:

```bash
cat > .env <<'EOF'
N8N_HOST=flow.example.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://flow.example.com/
N8N_PROXY_HOPS=1
GENERIC_TIMEZONE=UTC

POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=CHANGE_ME_POSTGRES

N8N_ENCRYPTION_KEY=CHANGE_ME_64_CHARS_MINIMUM

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=CHANGE_ME_N8N

N8N_CONCURRENCY_PRODUCTION_LIMIT=4
EOF
```

`compose.yaml`:

```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}

      EXECUTIONS_MODE: queue
      QUEUE_BULL_REDIS_HOST: redis
      QUEUE_BULL_REDIS_PORT: 6379

      N8N_HOST: ${N8N_HOST}
      N8N_PROTOCOL: ${N8N_PROTOCOL}
      N8N_PORT: 5678
      WEBHOOK_URL: ${WEBHOOK_URL}
      N8N_PROXY_HOPS: ${N8N_PROXY_HOPS}
      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      TZ: ${GENERIC_TIMEZONE}

      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_BASIC_AUTH_ACTIVE: ${N8N_BASIC_AUTH_ACTIVE}
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD}
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      N8N_CONCURRENCY_PRODUCTION_LIMIT: ${N8N_CONCURRENCY_PRODUCTION_LIMIT}
    depends_on:
      - postgres
      - redis
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files

  n8n-worker:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: unless-stopped
    command: worker --concurrency=2
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}

      EXECUTIONS_MODE: queue
      QUEUE_BULL_REDIS_HOST: redis
      QUEUE_BULL_REDIS_PORT: 6379

      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      TZ: ${GENERIC_TIMEZONE}
      N8N_CONCURRENCY_PRODUCTION_LIMIT: ${N8N_CONCURRENCY_PRODUCTION_LIMIT}
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
  n8n_data:
```

Запуск:

```bash
mkdir -p local-files
docker compose up -d
docker compose ps
docker compose logs -f n8n
```

Это сочетает официальный compose-подход n8n с официальным queue mode: main принимает webhook-и и orchestration, worker-и забирают выполнение из Redis, database — Postgres, concurrency можно ограничивать. citeturn27view2turn27view0turn7view2turn26view0

Наружу для добавления задач используй **Webhook node**, а не n8n public API. Причина: Webhook node доступен в обычном workflow-потоке, умеет быть полноценным API endpoint, умеет отвечать сам или через `Respond to Webhook`, а аутентификация может быть Basic/Header/JWT. Для выдачи результата после обработки или постановки в очередь используй `Respond to Webhook`. citeturn22search7turn22search3

## Формат ответов, цикл задач, очередь и расширение контекста

Самая частая причина, почему узловые системы “ломаются” на LLM-backend’ах, — попытка парсить свободный текст модели регулярками или `split('\n')`. В случае OpenCode лучший путь — **тонкий gateway поверх официального SDK**, потому что SDK документированно поддерживает structured output через JSON schema, умеет `noReply: true` для инъекции дополнительного контекста в сессию без генерации ответа, а результат structured output кладётся отдельно в `structured_output`. Это ровно то, что тебе нужно, чтобы n8n не ломался на “человеческом” тексте. citeturn19view2turn19view0

Минимальный контракт ответа я бы сделал таким:

```json
{
  "status": "ok | needs_input | retry | error",
  "summary": "короткое описание результата",
  "artifacts": [
    { "kind": "file | url | docker | log", "path": "", "description": "" }
  ],
  "tests": [
    { "name": "", "status": "passed | failed | skipped", "details": "" }
  ],
  "next_step": "что делать дальше",
  "commands_run": ["..."],
  "machine": {
    "repo_dirty": true,
    "branch": "",
    "commit": ""
  }
}
```

Именно этот JSON должен выходить из gateway наружу — не сырые message parts OpenCode. Тогда n8n всегда работает с одинаковым объектом. citeturn19view2

Пример простого gateway-сервиса на Node.js:

```bash
mkdir -p /opt/opencode-gateway
cd /opt/opencode-gateway
npm init -y
npm install @opencode-ai/sdk fastify zod
```

```js
// /opt/opencode-gateway/server.mjs
import Fastify from 'fastify'
import { z } from 'zod'
import { createOpencodeClient } from '@opencode-ai/sdk'

const fastify = Fastify({ logger: true })

const authHeader =
  'Basic ' +
  Buffer.from(`opencode:${process.env.OPENCODE_PASSWORD}`, 'utf8').toString('base64')

const client = createOpencodeClient({
  baseUrl: process.env.OPENCODE_BASE_URL || 'http://127.0.0.1:4096',
  fetch: async (url, init = {}) =>
    fetch(url, {
      ...init,
      headers: {
        ...(init.headers || {}),
        Authorization: authHeader,
      },
    }),
})

const Input = z.object({
  sessionId: z.string().optional(),
  title: z.string().optional(),
  agent: z.string().default('build'),
  prompt: z.string(),
  context: z.array(z.string()).default([]),
  model: z
    .object({
      providerID: z.string(),
      modelID: z.string(),
    })
    .optional(),
})

const OutputSchema = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['ok', 'needs_input', 'retry', 'error'] },
    summary: { type: 'string' },
    artifacts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string' },
          path: { type: 'string' },
          description: { type: 'string' },
        },
        required: ['kind', 'path', 'description'],
      },
    },
    tests: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          status: { type: 'string', enum: ['passed', 'failed', 'skipped'] },
          details: { type: 'string' },
        },
        required: ['name', 'status', 'details'],
      },
    },
    next_step: { type: 'string' },
    commands_run: {
      type: 'array',
      items: { type: 'string' },
    },
    machine: {
      type: 'object',
      properties: {
        repo_dirty: { type: 'boolean' },
        branch: { type: 'string' },
        commit: { type: 'string' },
      },
      required: ['repo_dirty', 'branch', 'commit'],
    },
  },
  required: ['status', 'summary'],
}

fastify.post('/run', async (request, reply) => {
  const input = Input.parse(request.body)

  let sessionId = input.sessionId
  if (!sessionId) {
    const created = await client.session.create({
      body: { title: input.title || 'queued-task' },
    })
    sessionId = created.data.id
  }

  for (const extra of input.context) {
    await client.session.prompt({
      path: { id: sessionId },
      body: {
        noReply: true,
        parts: [{ type: 'text', text: extra }],
      },
    })
  }

  const result = await client.session.prompt({
    path: { id: sessionId },
    body: {
      agent: input.agent,
      model: input.model,
      parts: [{ type: 'text', text: input.prompt }],
      format: {
        type: 'json_schema',
        retryCount: 2,
        schema: OutputSchema,
      },
    },
  })

  const data = result.data.info.structured_output
  if (!data) {
    return reply.code(500).send({
      sessionId,
      status: 'error',
      summary: 'Structured output missing',
    })
  }

  return {
    sessionId,
    ...data,
  }
})

fastify.listen({
  host: '127.0.0.1',
  port: Number(process.env.PORT || 9080),
})
```

Systemd для gateway:

```ini
# /etc/systemd/system/opencode-gateway.service
[Unit]
Description=OpenCode JSON gateway
After=network.target opencode.service

[Service]
User=agent
Group=agent
WorkingDirectory=/opt/opencode-gateway
Environment=OPENCODE_BASE_URL=http://127.0.0.1:4096
Environment=OPENCODE_PASSWORD=CHANGE_ME_LONG_RANDOM_PASSWORD
Environment=PORT=9080
ExecStart=/usr/bin/node /opt/opencode-gateway/server.mjs
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Теперь n8n работает уже не с OpenCode “напрямую”, а с предсказуемым `POST http://127.0.0.1:9080/run`. Это главный трюк, который реально делает узловую систему стабильной. citeturn19view2turn19view0

Для “подтягивания команд” и повторяемых сценариев вынеси фиксированные инструкции в slash-commands. Кастомные commands в OpenCode поддерживают frontmatter, arguments и повторно используемые prompt-шаблоны; по API они вызываются через `POST /session/:id/command`. Это отличный способ не дублировать в n8n огромные prompt’ы. citeturn12view3turn12view4turn16view0

Пример команды:

```bash
mkdir -p /srv/agent/workspace/.opencode/commands
cat > /srv/agent/workspace/.opencode/commands/verify.md <<'EOF'
---
description: Run lint, typecheck, tests, docker smoke checks and return strict JSON
agent: build
---

1. Run lint, typecheck and tests.
2. If a docker-compose.yml exists, run a smoke boot.
3. Do not read .env files.
4. Return only the structured contract already described in session context.
EOF
```

Теперь n8n может держать очень короткие payload’ы вроде:

```json
{
  "command_name": "verify",
  "task_context": [
    "Target branch: feature/payment-retry",
    "Definition of done: build passes, tests green, docker boots, write summary"
  ]
}
```

Расширение задачи дополнительным контекстом делай тремя слоями:

1. **Статический контекст**: `AGENTS.md` и `instructions` в конфиге OpenCode. Это то, что всегда надо помнить про проект. citeturn12view5turn18view2
2. **Контекст на очередь**: поля `context` / `metadata` в записи задачи в Postgres. Их gateway инжектит через `noReply: true` перед основным prompt’ом. citeturn19view0
3. **Контекст продолжения**: сохраняй `sessionId` в таблице задач и для follow-up задач используй ту же сессию. Если нужно ветвление, OpenCode поддерживает fork сессии. citeturn16view1

Саму очередь задач я бы закладывал не “на словах”, а отдельной таблицей в Postgres. n8n умеет работать с Postgres через штатный Postgres node; он поддерживает и SQL queries, и insert/update. citeturn26view2

```sql
CREATE TABLE IF NOT EXISTS agent_tasks (
  id BIGSERIAL PRIMARY KEY,
  parent_task_id BIGINT NULL REFERENCES agent_tasks(id),
  session_id TEXT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'done', 'retry', 'failed')),
  priority INT NOT NULL DEFAULT 100,
  attempt INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  command_name TEXT NULL,
  prompt TEXT NOT NULL,
  context JSONB NOT NULL DEFAULT '[]'::jsonb,
  result JSONB NULL,
  error_text TEXT NULL,
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_poll
ON agent_tasks (status, priority, available_at, created_at);
```

Дальше собираешь в n8n четыре workflow:

1. **Ingress**
   - `Webhook`
   - `Code` для проверки payload
   - `Postgres` insert в `agent_tasks`
   - `Respond to Webhook` → вернуть `{task_id, status:"queued"}`

2. **Dispatcher**
   - `Schedule Trigger` каждые 5–10 секунд
   - `Postgres` query с `FOR UPDATE SKIP LOCKED`
   - `HTTP Request` на gateway `/run`
   - `If` по `status`
   - `Postgres` update `done` / `retry` / `failed`

3. **Retry/Continuation**
   - если gateway вернул `needs_input` или `retry`, записать дочернюю задачу с тем же `session_id` и расширенным `context`

4. **Status API**
   - `Webhook`
   - `Postgres` select по `task_id`
   - `Respond to Webhook`

n8n штатно поддерживает именно те узлы, которые для этого нужны: Webhook, Respond to Webhook, HTTP Request, Postgres, Code, Schedule Trigger, Wait. Wait node особенно полезен, если тебе нужен pause/resume на внешнем approval hook; он умеет offload execution data в базу и возобновляться по webhook call. citeturn22search7turn22search3turn22search2turn26view2turn26view3turn22search1turn26view1

Если хочешь уйти от polling, OpenCode plugins умеют ловить `session.idle`, `session.error`, `session.status`, `tool.execute.before` и другие события. Это значит, что ты можешь сделать маленький плагин, который по завершении или ошибке шлёт callback в webhook n8n — и тогда n8n будет не опрашивать backend, а получать push-события. Это уже “второй уровень зрелости”, но для production очень хороший апгрейд. citeturn25view0turn25view1turn25view3

## Итоговый сценарий по шагам

Ниже — самый практичный “golden path”, который я бы реально повторял на чистом сервере. Он сводит всё выше в один конечный сценарий. citeturn16view0turn23view0turn7view2turn19view2

1. Подними сервер на Ubuntu 24.04 LTS. Если используешь внешние модели, сразу бери минимум 8 vCPU / 16 GB RAM / 200 GB SSD; если хочешь локальные модели через Ollama — добавляй GPU и запас по диску. citeturn2search0turn17view1turn24search7turn24search10

2. Создай DNS-записи `agent.example.com` и `flow.example.com` на этот сервер. `agent.*` будет проксировать OpenCode, `flow.*` — n8n webhook/UI. Для n8n behind proxy обязательно потом выстави `WEBHOOK_URL` и `N8N_PROXY_HOPS=1`. citeturn28view0turn28view1

3. Создай Unix-пользователя `agent`, установи базовые утилиты, поставь OpenCode install script’ом, создай `~/.config/opencode/opencode.json`, включи `compaction`, отключи auto-update и сузь `watcher.ignore`. Provider credentials потом добавь через `/connect`; они лягут в `~/.local/share/opencode/auth.json`. citeturn1view0turn18view0turn18view1turn18view2turn17view1

4. Подними OpenCode как systemd-службу на `127.0.0.1:4096` c `OPENCODE_SERVER_PASSWORD`. Для первичной настройки делай `ssh -L 4096:127.0.0.1:4096 server`, потом `opencode attach http://127.0.0.1:4096`, затем `/connect`, `/models`, `/init`. `/init` создаст `AGENTS.md`, который станет базовым project memory. citeturn16view0turn12view1turn12view5

5. Поставь Docker Engine из официального apt-репозитория. Если хочешь, чтобы агент работал с Docker на хосте, либо добавь `agent` в docker-группу и прими root-level риск, либо отдельно подними rootless Docker. Docker daemon не публикуй по TCP без очень чёткой причины и TLS. citeturn2search0turn2search2turn2search7turn1search10

6. Дай агенту **не полный sudo**, а узкий `sudoers` allowlist: `apt-get update`, `apt-get install *`, `systemctl restart docker`, `systemctl status *`, `journalctl *`. В OpenCode сделай строгий allowlist для `bash`, иначе unattended-задачи могут либо получить лишние права, либо зависнуть на permission prompt. Если всё же используешь `ask`, помни, что подтверждения надо потом обрабатывать через API permissions endpoint, иначе очередь встанет. citeturn18view4turn16view0turn14view3

7. Не давай агенту читать `.env` из репозитория. Храни runtime secrets в `EnvironmentFile` systemd или отдельном secrets backend, а в OpenCode при необходимости прокидывай их в shell через plugin `shell.env`. Это намного безопаснее и лучше совместимо с автоматическим режимом. citeturn14view3turn25view1

8. Подними n8n в Docker Compose с Postgres и Redis. Включи `EXECUTIONS_MODE=queue`, отдельный `n8n-worker`, общий `N8N_ENCRYPTION_KEY`, `WEBHOOK_URL=https://flow.example.com/`, `N8N_PROXY_HOPS=1`, `N8N_CONCURRENCY_PRODUCTION_LIMIT` и timezone. Это официальный path n8n для reverse-proxy и queue mode. citeturn23view0turn27view2turn7view2turn26view0turn28view0

9. Подними рядом tiny `opencode-gateway` на `127.0.0.1:9080` через официальный SDK. Задача gateway — создавать сессии, инжектить дополнительный контекст через `noReply`, вызывать OpenCode и **возвращать только валидный JSON по schema**. Именно gateway, а не n8n, должен общаться с raw LLM-ответом. Так ты устраняешь основную причину “нодовая система не поняла ответ модели”. citeturn19view2turn19view0

10. В репозитории создай `.opencode/commands`: `/verify`, `/fix`, `/docker-up`, `/deploy-staging`, `/repair`. Пусть n8n вызывает в большинстве случаев не произвольный prompt, а одну из этих команд плюс маленький `context[]`. Это резко уменьшает вариативность поведения и делает backend предсказуемее. citeturn12view3turn12view4

11. В Postgres создай таблицу `agent_tasks`. Это будет твоя durable business queue поверх infrastructural queue n8n. n8n queue mode масштабирует сами workflow executions; таблица `agent_tasks` масштабирует уже именно семантические задачи, которые ты отправляешь coding-agent’у. citeturn7view2turn26view2

12. В n8n собери workspace из четырёх workflow:
    - `task-ingress` — public webhook, который принимает задачу извне и пишет её в очередь;
    - `task-dispatcher` — cron-поллер, который atomically берёт старую задачу, шлёт её в gateway и пишет результат;
    - `task-status` — webhook на чтение статуса задачи;
    - `task-retry-or-continue` — логика повтора, расширения контекста и постановки дочерних задач.  
   Используй `Webhook`, `Respond to Webhook`, `Postgres`, `HTTP Request`, `Code`, `Schedule Trigger`; для human approval или callback continuation при необходимости добавь `Wait`. citeturn22search7turn22search3turn26view2turn22search2turn26view3turn22search1turn26view1

13. Наружу публикуй **именно n8n webhook для постановки задач**, например:

```text
POST https://flow.example.com/webhook/opencode/task
Authorization: Bearer <token>
{
  "title": "fix ci on billing-service",
  "prompt": "Почини CI, добейся green build, прогоняй тесты после каждого исправления.",
  "context": [
    "repo=billing-service",
    "definition_of_done=tests green, docker compose boots, short changelog written"
  ],
  "priority": 50
}
```

Webhook должен быстро отвечать:

```json
{
  "task_id": 12345,
  "status": "queued"
}
```

А отдельный status-endpoint должен возвращать уже результат из таблицы `agent_tasks`, а не пытаться “на лету” читать OpenCode messages. Тогда внешним клиентам всё равно, как внутри устроен агент. citeturn22search7turn22search3turn26view2

14. Для продолжения работы по одной и той же feature сохраняй `session_id` в `agent_tasks` и переиспользуй его. Для совсем новой независимой задачи создавай новую сессию. Для экспериментальной ветки поведения — форкай текущую сессию. Для дополнительного контекста используй `context[]`, который gateway вольёт в текущую сессию через `noReply`. Это даёт тебе именно тот цикл “задача → допконтекст → новая итерация”, который ты описывал. citeturn19view0turn16view1

15. Когда всё заработает, только после этого включай более продвинутые вещи: callback-плагин из OpenCode в n8n на `session.idle/session.error`, rootless Docker, отдельные OpenCode instance на разные репозитории, и model split между “дешёвым планировщиком” и “дорогим build/model backend”. Это уже эволюция системы, а не обязательный стартовый минимум. citeturn25view0turn25view3turn2search7

Если коротко свести это к одному решению, то рабочая production-связка для тебя выглядит так: **OpenCode как coding backend на сервере**, **Docker на том же хосте для сборки и тестов**, **n8n как узловая оркестрация и внешняя точка входа**, **Postgres как durable очередь и state store**, **Redis для queue mode n8n**, **gateway поверх OpenCode SDK для жёсткого JSON-формата**, и **reverse proxy с HTTPS** для внешнего доступа. Именно такая схема даёт и удалённый coding-agent, и внешние команды, и устойчивую очередь, и повторяемый формат ответа, и возможность наращивать контекст и циклы без развала всей системы из-за одной неудачной фразы модели. citeturn16view0turn19view2turn23view0turn7view2turn28view0