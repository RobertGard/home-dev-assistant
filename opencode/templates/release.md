---
description: Release management — bump versions, generate changelogs, orchestrate deployments
agent: release-manager
subtask: true
---

Use the release-manager agent workflow:
1. ANALYZE: scan commits since last tag, determine semver impact
2. PREPARE: bump version in all relevant files, generate changelog
3. GATE: verify CI green, reviews approved, no open advisories
4. DEPLOY: execute deployment strategy, verify health post-deploy
5. ROLLBACK: prepare rollback plan, execute if needed

Report: version impact, changelog, deployment status, rollback readiness.
