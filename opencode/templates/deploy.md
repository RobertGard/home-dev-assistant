---
description: Deployment verification — check health, logs, endpoints, and rollback plan
agent: build
subtask: true
---

Use the deployment-verify skill:
1. PRE: verify tests pass, build succeeds, no pending migrations
2. DEPLOY: rebuild containers, check health, verify startup logs
3. POST: smoke test endpoints, watch logs for errors
4. ROLLBACK: confirm rollback plan and commands

Report: deployment status, any errors found, rollback readiness.
