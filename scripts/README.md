# Setup Scripts

Основной скрипт первичной настройки:

```bash
bash ./scripts/setup-stack.sh
```

Что делает:

- задает вопросы на русском
- генерирует `.env`
- настраивает worker-ов по количеству, которое ты указал
- создает `repos.json` для каждого worker-а
- по желанию сразу запускает `docker compose up -d --build`
- автоматически импортирует starter workflow в `n8n`
- пытается автоматически создать Telegram credential и Telegram workflow, если задан `TELEGRAM_BOT_TOKEN`
- запускает базовую проверку стека

Дополнительные скрипты:

```bash
bash ./scripts/bootstrap-n8n-workflow.sh
bash ./scripts/bootstrap-telegram-integration.sh
bash ./scripts/verify-stack.sh
```
