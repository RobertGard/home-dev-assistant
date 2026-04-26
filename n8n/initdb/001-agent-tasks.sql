CREATE TABLE IF NOT EXISTS agent_tasks (
  id BIGSERIAL PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'telegram',
  chat_id TEXT NOT NULL,
  user_id TEXT NULL,
  username TEXT NULL,
  worker_alias TEXT NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('prompt', 'command')),
  command_name TEXT NULL,
  prompt TEXT NOT NULL DEFAULT '',
  context JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'done', 'failed')) DEFAULT 'queued',
  session_id TEXT NULL,
  result_json JSONB NULL,
  result_text TEXT NULL,
  error_text TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ NULL,
  finished_at TIMESTAMPTZ NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_status_created
ON agent_tasks (status, created_at);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_worker_status_created
ON agent_tasks (worker_alias, status, created_at);
