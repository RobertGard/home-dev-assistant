---
name: ci-cd-automation
description: Trigger CI pipelines, monitor build status, diagnose failures, manage releases via GitHub Actions and other CI providers.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: gh-cli
---

## What I do
- Trigger CI pipelines via `gh workflow run` or CI provider API
- Monitor build status with real-time polling or watch mode
- Diagnose CI failures by extracting logs and identifying root causes
- Manage GitHub Actions: list, enable, disable, re-run workflows
- Create and manage releases from green CI builds
- Coordinate multi-service deployment pipelines

## When to use me
Use this skill when:
- You need to run CI for a branch without pushing (manual trigger)
- A CI build has failed and you need to understand why
- You want to check the status of all recent pipeline runs
- You need to re-run a flaky CI job
- You're preparing a release and need to verify all gates pass
- You want to view CI logs for a specific job step

## Commands reference
```bash
# List recent workflow runs
gh run list --limit 20

# View a specific run
gh run view <run-id> --log

# Watch a run in real-time
gh run watch <run-id>

# Trigger a workflow manually
gh workflow run <workflow-name> --ref <branch>

# List workflows
gh workflow list

# Re-run a failed run
gh run rerun <run-id> --failed

# View only failed jobs
gh run view <run-id> --log-failed

# Cancel a running workflow
gh run cancel <run-id>

# PR status checks
gh pr checks <pr-number>

# Create a release
gh release create <tag> --generate-notes

# Lint GitHub Actions workflows
actionlint .github/workflows/*.yml 2>&1

# Pre-commit CI validation
find .github/workflows -name '*.yml' -exec actionlint {} \;
```

## Workflow
1. Identify CI provider (GitHub Actions detected via `.github/workflows/`, infer others)
2. For diagnostics: fetch the failed run, extract the failing step logs
3. Analyze the error: parse stack traces, identify missing env vars, flaky tests, timeout issues
4. Provide actionable fix recommendation (describe, don't implement source changes)
5. For releases: verify all checks green, create release, monitor post-deploy

## PR checklist automation
```
- [ ] All workflows passing
- [ ] Required reviews approved
- [ ] No merge conflicts
- [ ] Branch protection satisfied
- [ ] Security scan clean
```

## Output format
```
## CI Report: <workflow> on <branch>

### Status: <🟢 PASSED / 🔴 FAILED / 🟡 RUNNING>
- Run ID: <id>, Duration: <time>
- Trigger: <manual/push/PR>, Actor: <user>

### Jobs
| Job | Status | Duration | Attempts |
|-----|--------|----------|----------|
| build | 🟢 | 2m 30s | 1 |
| test | 🔴 | 45s | 2 |

### Failure Analysis (if any)
- Failed job: <name>
- Error: <snippet from logs>
- Root cause: <analysis>
- Fix: <actionable suggestion>
```
