# Как это выглядит в n8n

## Откуда берется payload

Payload приходит в `n8n` в `Webhook` node.

То есть схема такая:

1. ты создаешь workflow в `n8n`
2. добавляешь `Webhook` node
3. `n8n` сам выдает URL webhook-а
4. внешний клиент или другой workflow отправляет POST на этот URL
5. body запроса становится входным `$json` для следующего node

Пример входного body:

```json
{
  "worker": "primary",
  "prompt": "Проверь проект, установи зависимости и подними инфраструктуру",
  "context": ["repo=ai-backend-marketing-agent"]
}
```

## Что видно в интерфейсе n8n

### 1. Webhook node

В `Webhook` node ты видишь:

- Method: `POST`
- Path: например `opencode/task`

После сохранения workflow `n8n` сам покажет тебе URL webhook-а.

Например это будет что-то вроде:

```text
http://127.0.0.1:5678/webhook/opencode/task
```

или внешний URL, если ты работаешь через домен/reverse proxy.

### 2. Code node

Следующим ставишь `Code` node.

Что происходит внутри:

- `Webhook` передает входной JSON дальше
- в `Code` node этот JSON доступен как `$json`
- код читает `/files/opencode-routing.json`
- по полю `worker` или `workerAlias` выбирает нужный OpenCode worker
- пароль берет через env, а не напрямую из routing JSON
- готовит URL, auth header и endpoint-ы

После выполнения в правой панели `n8n` ты увидишь уже новый JSON, например такого вида:

```json
{
  "workerAlias": "primary",
  "opencodeAgent": "build",
  "authHeader": "Basic ...",
  "endpoints": {
    "health": "http://opencode-worker-1:4096/global/health",
    "sessionCreate": "http://opencode-worker-1:4096/session",
    "sessionMessage": "http://opencode-worker-1:4096/session/:id/message",
    "sessionCommand": "http://opencode-worker-1:4096/session/:id/command"
  },
  "prompt": "Проверь проект, установи зависимости и подними инфраструктуру",
  "context": ["repo=ai-backend-marketing-agent"]
}
```

То есть это обычный промежуточный JSON в интерфейсе `n8n`.

### 3. HTTP Request node

После этого ставишь `HTTP Request` node.

Он уже не думает, к какому worker идти. Он берет готовые поля из предыдущего node.

Например:

- URL: `{{$json.endpoints.sessionCreate}}`
- Header `Authorization`: `{{$json.authHeader}}`
- Header `Content-Type`: `application/json`

Body:

```json
{
  "title": "n8n-task"
}
```

Потом следующим `HTTP Request` node отправляешь prompt или command.

## Кто создает webhook

Webhook создает не OpenCode и не worker.

Webhook создает сам `n8n`, когда в workflow есть `Webhook` node.

То есть:

- OpenCode worker не выдает тебе webhook
- worker не регистрирует webhook автоматически
- webhook принадлежит workflow внутри `n8n`

## Нужно ли worker-ам знать URL webhook-а

Обычно нет.

В стандартной схеме:

- внешний клиент -> `n8n webhook`
- `n8n` -> OpenCode worker

OpenCode worker вообще не должен знать URL webhook-а.

Это нормально и правильно.

## Есть ли автоматическая регистрация webhook сейчас

Сейчас нет.

И это сделано специально, чтобы не скрывать от тебя механику `n8n`.

Сейчас автоматизировано:

- поднятие инфраструктуры
- поднятие OpenCode worker-ов
- генерация routing-файла
- генерация worker-конфигов

Но сам workflow `n8n` и его `Webhook` node ты создаешь внутри интерфейса `n8n`.

## Можно ли автоматизировать создание webhook и workflow

Да, можно.

Возможные пути:

1. импортировать заранее подготовленный workflow JSON в `n8n`
2. использовать `n8n` API для автоматического создания workflow
3. добавить starter workflow в репозиторий и импортировать его через UI

Базовый starter workflow уже реализован в проекте и может импортироваться автоматически.

## Рекомендуемый минимальный workflow

1. `Webhook`
2. `Code` node со встроенной логикой маршрутизации
3. `HTTP Request` -> создать сессию
4. `Set` или `Code` -> подставить `sessionId`
5. `HTTP Request` -> отправить prompt или command в OpenCode
6. `Respond to Webhook`

## Итоговая схема

```text
Внешний клиент
  -> POST в webhook n8n
  -> Webhook node
  -> Code node (читает routing и выбирает worker)
  -> HTTP Request в OpenCode
  -> результат обратно в n8n
  -> Respond to Webhook
```
