---
description: Deployment management — deploy to cloud platforms, verify health, rollback if needed
agent: release-manager
subtask: true
---

Use the cloud-deploy skill:
1. TARGET: identify deployment target (Docker Compose primary)
2. PRE-FLIGHT: verify build passes, tests green, migration safety
3. DEPLOY: execute platform-specific deploy command
4. VERIFY: health checks, smoke tests, SSL, environment variables
5. MONITOR: watch logs for 2 minutes post-deploy, detect error spikes

Report: deployment URL, verification results, rollback availability, post-deploy health.
