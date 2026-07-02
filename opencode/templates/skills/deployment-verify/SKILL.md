---
name: deployment-verify
description: Verify deployments: check container health, test endpoints, validate rollback capability, monitor error rates, and confirm rollback plan.
license: MIT
compatibility: opencode
metadata:
  audience: devops
  requires: docker-socket
---

## What I do
- Pre-deployment: verify build passes, tests green, migration safety
- During deployment: check container startup, health checks, zero errors
- Post-deployment: smoke test endpoints, verify rollback plan, monitor logs
- Rollback: quick revert to last known good state

## Pre-deployment checklist
```bash
# Ensure all tests pass
npm test  # or equivalent

# Verify build
npm run build  # or equivalent

# Check git status
git status
git log --oneline -5

# Check for pending migrations
git diff HEAD~1 --name-only | grep -i migrate
```

## Deployment verification
```bash
# Pull latest and rebuild
docker compose pull
docker compose up -d --build

# Wait for healthy
sleep 10
docker compose ps

# Check all containers healthy
for c in $(docker compose ps -q); do
  docker inspect --format='{{.Name}} {{.State.Health.Status}}' $c
done

# Check logs for startup errors
docker compose logs --tail 50 | grep -iE '(error|fatal|panic|exception)'

# Smoke test endpoints
curl -sf http://localhost:3000/health
curl -sf http://localhost:3000/api/status
```

## Post-deployment monitoring
```bash
# Watch logs for 30 seconds
timeout 30 docker compose logs -f --tail 0 2>&1 | grep -iE '(error|warn|fatal)'

# Check resource usage
docker stats --no-stream
```

## Rollback plan
```bash
# If deployment fails, revert:
git checkout <previous-commit>
docker compose up -d --build

# Verify rollback
docker compose ps
```
