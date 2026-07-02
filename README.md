# OpenCode + n8n

Self-hosted AI development assistant: submit a task in Telegram, n8n dispatches it to OpenCode workers, results come back to the chat.

> **Русская версия:** [README.ru.md](./README.ru.md)

**Key features:**

- **Multi-Worker** — any number of workers, each with its own project and MCP toolset
- **Session context** — workers remember conversation history, you can refine and extend tasks within a session
- **Interactive OpenCode** — workers can ask clarifying questions directly in chat; you answer, they continue
- **Auto-mode** — after task completion, the bot analyzes results and suggests the next step: GSD cycle, quality checks, tests, documentation
- **Task chains** — a task can wait for its parent to complete and execute only if the result contains specified text (e.g. tests passed → deploy)
- **Acceptance verification** — pass `--verify="criteria"` with a task; after completion, a read-only verifier agent checks code health, application logs, browser console (via Playwright), API responses, and per-criterion evidence. Failed verification auto-generates a fix task
- **Natural language commands** — type requests in plain language; an AI translator converts them to structured commands with proper flags
- **Fully self-hosted** — no cloud services, all data under your control
- **Batteries included** — PostgreSQL, Redis, n8n, Caddy (HTTPS) — one `bash setup-stack.sh` and you're ready
- **CI/CD integration** — trigger pipelines, check build status, diagnose failures, manage releases from Telegram (`/ci`, `/release`)
- **Database tools** — explore schemas, analyze queries, review migrations, generate seed data (`/db`)
- **Observability** — log analysis, error pattern detection, incident reports, health monitoring
- **Smart testing** — run only affected tests by changed files, detect flaky tests
- **Docker deployment** — deploy, verify health, check logs, rollback via `/deploy`
- **9 specialist agents** — planner, reviewer, verifier, security-auditor, ci-cd-agent, db-analyst, observability-agent, release-manager, ralph-loop-agent
- **16 built-in skills** — from code review and performance profiling to CI/CD automation and Docker deployment

## Requirements

- Docker Engine + Docker Compose
- Telegram bot token (for Telegram mode)
- Public domain, ports 80/443 (for HTTPS)

## Quick start

```bash
bash ./scripts/setup-stack.sh
```

The script asks questions, creates `.env` and `config.json`, launches containers, configures Telegram.

### Reinstall

```bash
docker compose down -v --rmi all --remove-orphans
docker builder prune -af
bash ./scripts/setup-stack.sh
```

## Telegram bot commands

The bot accepts commands via `/`. Flags use `--flag="value"` format.

### `/task` — task creation and management

| Command | Description |
|---|---|
| `/task --prompt="description"` | Create a new task |
| `/task --answer="answer"` | Answer an OpenCode question (auto-selects pending task) |
| `/task --task_key="xxx" --answer="answer"` | Answer a specific pending task |
| `/task --parent_task_key="xxx" --parent_match_text="text"` | Follow-up with text match check in parent result |
| `/task --auto_mode="true"` | Enable auto-mode |
| `/task --auto_mode="false"` | Disable auto-mode |

### `/abort` — task cancellation

| Command | Description |
|---|---|
| `/abort --task_key="xxx"` | Abort a specific task |
| `/abort` | Auto-select the only running task |

### Additional flags

| Flag | Description |
|---|---|
| `--worker="alias"` | Assign task to a specific worker |
| `--new_session` / `--fresh_session` | Force a new OpenCode session |
| `--verify="criteria"` | Acceptance criteria — after task completion, a read-only verifier agent checks code health (lint, typecheck, tests), application logs (docker logs for every container), browser console (Playwright), API responses, and every criterion individually. Failed verification auto-creates a fix task |

### Answering OpenCode questions

OpenCode asks a question → the bot sends numbered options.

- **Single question** — option number or label text
- **Multiple questions** — separated by `||`: `1 || Prisma`
- **Multi-select** — separated by `&&`: `1 && 3`
- **Reject** — `/reject` or `/task --answer="/reject"`

### Auto-mode

`/task --auto_mode="true"` — after each completed task, the bot suggests the next: GSD cycle, quality checks, tests, documentation. Auto-tasks (prefix `auto-`) inherit the worker from the triggering task.

### Natural language translation

You don't have to write structured commands. Just type in plain language:

| Input | Translated to |
|---|---|
| `deploy the project` | `/task --prompt="deploy the project"` |
| `run fixes on the second worker` | `/task --prompt="run fixes" --worker="worker-2"` |
| `answer 2 in task task-abc` | `/task --task_key="task-abc" --answer="2"` |
| `if task task-abc result contains "done" then run cleanup` | `/task --parent_task_key="task-abc" --parent_match_text="done" --prompt="run cleanup"` |
| `enable automode` | `/task --auto_mode="true"` |
| `cancel task task-xyz` | `/abort --task_key="task-xyz"` |
| `refactor the code. verify that lint passes and tests are green` | `/task --prompt="refactor the code" --verify="lint passes and tests are green"` |
| `/task --prompt="already a command"` | `/task --prompt="already a command"` (passes through unchanged) |

The translator is an AI Agent (DeepSeek) that runs before the command parser. It preserves original meaning, doesn't invent flags, and passes existing commands through unchanged.

### Acceptance verification pipeline

When you include `--verify="criteria"` with a task:

1. OpenCode completes the primary task
2. The dispatcher spawns a **separate OpenCode session** using a **read-only verifier agent** (`edit: deny, bash: allow`)
3. The verifier runs 4 mandatory checkpoints:
   - **Code & build health**: lint, typecheck, tests, `git diff`
   - **Application logs**: `docker logs --tail 100` for every container, log files
   - **Runtime behavior**: curl API checks, Playwright browser interaction (console logs, network errors, page content)
   - **Per-criterion verification**: each acceptance criterion matched against evidence
4. Every checkpoint **requires actual output as evidence** — the agent cannot skip or fabricate
5. A **DeepSeek AI judge** evaluates the verification report and returns a PASSED/FAILED verdict
6. If FAILED → a fix task is auto-created with the same `--verify` criteria

## Architecture

```
Telegram → n8n ingress → Data Table → n8n dispatcher → OpenCode worker → result in Telegram
```

**Services:** `postgres`, `redis`, `n8n`, `n8n-worker`, `opencode-worker-1`, `caddy` (optional)

**n8n Workflows (8):** ingress, dispatcher, session-manager, task-launcher, pending-interaction, task-finalizer, auto-task-generator, acceptance-verifier

## Specialist agents

8 specialized agents, each with role-based permissions and domain-specific system prompts:

| Agent | Role | Permissions |
|-------|------|-------------|
| `build` | General-purpose coder | Full read/write/bash |
| `planner` | Design & architecture | Read-only, no edits |
| `reviewer` | Code review | Read-only, no edits |
| `verifier` | Acceptance verification | Read-only, bash allowed |
| `security-auditor` | OWASP + CVE scan | Read-only, limited bash |
| `ci-cd-agent` | Pipeline management | Read-only, `gh` CLI allowed |
| `db-analyst` | Database analysis | Read-only, DB introspection allowed |
| `observability-agent` | Log analysis & monitoring | Read-only, log inspection allowed |
| `release-manager` | Versioning & deployment | Version files only |

## CI/CD & Deployment

| Command | Description |
|---------|-------------|
| `/ci` | Check CI runs for current branch. Trigger workflow, diagnose failures |
| `/release` | Version bump, changelog generation, deployment coordination |
| `/deploy` | Deploy to target platform. Verify health, prepare rollback |

Supported deployment: Docker Compose. For cloud platforms — install via `npx skills add`.

## Database management

| Command | Description |
|---------|-------------|
| `/db` | Explore schema, analyze slow queries, review migration safety, generate seed data |

Supports PostgreSQL, MySQL, SQLite, MongoDB. Integrated with Prisma, TypeORM, Knex, Alembic, Django ORM.

## Worker configuration

Created by the setup script at `workers/<name>/config.json`:

```json
{
  "repos": [{
    "slug": "my-project",
    "url": "https://github.com/user/my-project.git",
    "ref": "main",
    "path": "my-project"
  }],
  "tooling": { ... }
}
```

**Repo fields:** `slug`, `url`, `ref`, `path`, `package_manager` (default `auto`), `turbo_smoke` (`false`), `turbo_tasks` (`["build","test"]`), `auto_start_docker` (`true`).

**tooling** (optional) — global packages and MCP servers. Structure: `npm` (npm install -g), `uv` (uv tool install), `post_install` (commands after install). Example in `workers/config.json.default`.

**Templates:**

```
workers/
├── config.json.default          ← default tooling for all workers
├── worker-1/
│   ├── config.json.template     ← overrides default for worker-1
│   └── config.json              ← working config
└── worker-2/
    └── ...
```

Priority: `worker-N/config.json.template` → `workers/config.json.default`.

**Reinstall behavior:** bind-mounted `config.json` survives `docker compose down -v`. If missing or disabled — the script asks for new slug/url.

## Environment variables (.env)

Created from `.env.example`. Key sections:

| Group | Variables |
|---|---|
| n8n | `N8N_HOST`, `N8N_PROTOCOL`, `N8N_PORT`, `N8N_ENCRYPTION_KEY`, `N8N_BASIC_AUTH_*`, `N8N_API_KEY` |
| Database | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| Worker N | `OPENCODE_WORKER_N_NAME`, `_ALIAS`, `_PORT`, `_PASSWORD`, `_BASE_URL`, `_HEALTH_URL` |
| API keys | `OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`, `GITHUB_TOKEN` |
| Telegram | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| OpenCode | `OPENCODE_AGENT`, `OPENCODE_MODEL`, `OPENCODE_PROVIDER_TIMEOUT_MS` |
| CI/CD | `GITHUB_REPOSITORY`, `GITLAB_TOKEN` |

## Operations

```bash
# Stack health check
bash ./scripts/verify-stack.sh

# Launch with HTTPS
docker compose --profile proxy up -d --build

# Additional workers
docker compose -f docker-compose.yml -f compose.overrides/opencode-worker-2.yml up -d --build

# Execution cleanup (automated via cron)
bash ./scripts/cleanup-executions.sh
```

## Telegram: first launch

1. `bash ./scripts/setup-stack.sh` → provide `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`
2. Open n8n → Settings → n8n API → create an API key
3. Add to `.env`: `N8N_API_KEY=<key>`
4. `bash ./scripts/bootstrap-telegram-integration.sh`

After `docker compose down -v`, the script detects an expired key and asks for a new one.

## Project files

```
├── docker-compose.yml
├── .env.example
├── scripts/
│   ├── setup-stack.sh
│   ├── bootstrap-telegram-integration.sh
│   ├── verify-stack.sh
│   └── cleanup-executions.sh
├── opencode/
│   ├── Dockerfile
│   └── bin/ (entrypoint, bootstrap-*.sh)
├── n8n/bootstrap/
│   ├── opencode-routing.json
│   └── workflows/templates/
└── workers/
    ├── config.json.default
    ├── worker-1/
    └── worker-2/
```

## Getting help

- **Installation issues:** run `bash ./scripts/verify-stack.sh` — checks compose, n8n, workers
- **Telegram not working:** ensure `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` and `N8N_API_KEY` are set in `.env`, then `bash ./scripts/bootstrap-telegram-integration.sh`
- **Worker not responding:** `docker compose ps` — all services should be healthy
- **Bugs and suggestions:** [GitHub Issues](https://github.com/RobertGard/n8n-opencode-orchestrator/issues)

## Contributing

Pull requests welcome. Core principles:

- No hardcoded values in bash — all defaults from `config.json.template` or `config.json.default`
- `.env` — worker identity (Docker env vars), `config.json` — repo/tooling config (mounted into container)
- `docker compose down -v` must not require manual config restoration
- All scripts must pass `bash -n` (syntax check)
