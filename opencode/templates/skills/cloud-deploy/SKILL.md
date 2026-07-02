---
name: cloud-deploy
description: Deploy applications via Docker Compose with health verification, rollback, and environment management. For platform-specific deployment (Vercel, Netlify, AWS, Fly.io), install via skills.sh.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: docker-socket
---

## What I do
- Deploy applications via Docker Compose (rebuild, restart, health check)
- Verify deployment: health endpoints, container status, error-free logs
- Manage environment variables per environment
- Execute rollback when deployments fail
- For cloud-specific deployment (Vercel, Netlify, Fly.io, AWS, Railway): install via `npx skills add` — see skills.sh for platform-specific skills

## When to use me
Use this skill when:
- Pushing code from local/dev to production via Docker
- Setting up a new environment (staging, production)
- A deployment has failed and diagnostics are needed
- Configuring environment variables for a service
- Rolling back to a previous deployment

## Commands reference

### Docker Compose (primary)
```bash
# Rebuild and deploy
docker compose up -d --build

# Deploy specific service
docker compose up -d --build <service-name>

# Deploy with multiple compose files
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# Scale a service
docker compose up -d --scale <service>=3

# Check status
docker compose ps
docker compose logs --tail 50 --timestamps

# Health check
curl -fsS http://localhost:<port>/health
docker inspect --format='{{.State.Health.Status}}' <container>

# Rollback to previous image
docker compose up -d <service>  # re-pulls the previous tag
```

### Cloud platforms (install via skills.sh)
```bash
# For cloud-specific deployment, install skills from skills.sh:
npx skills add vercel-labs/agent-skills    # Vercel deployment patterns
npx skills add microsoft/azure-skills      # Azure / AKS deployment
npx skills add xixu-me/skills              # CI/CD + cloud automation
# Then follow the installed skill's instructions for your platform
```

## Deployment verification checklist
```
- [ ] Health endpoint returns 200
- [ ] All containers in "running" state
- [ ] No error spikes in first 2 minutes
- [ ] Core functionality smoke test passes
- [ ] Environment variables set correctly
- [ ] Database migrations applied successfully (if applicable)
```

## Output format
```
## Deployment Report: <service> → <environment>

### Status: <🟢 SUCCESS / 🔴 FAILED / 🟡 DEGRADED>
- Provider: Docker Compose
- Duration: <time>
- Version: <commit-hash>

### Verification
- [x] Health check: 200 OK (120ms)
- [x] Containers: all running
- [x] Smoke tests: 5/5 passed
- [ ] <any failing check>

### Rollback Info
- Previous image: <tag>
- Rollback command: docker compose up -d <service>
```
