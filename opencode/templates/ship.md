---
description: Ship it — run quality gates, commit, push, create PR, request review. Complete branch lifecycle in one command.
agent: build
subtask: true
---

Use the finishing-a-development-branch skill (from skills.sh):
1. GATE: run lint, typecheck, full test suite, coverage check
2. COMMIT: analyze diff, generate conventional commit message, commit
3. PUSH: push branch to remote
4. PR: create pull request with structured description (summary, changes, testing, checklist)
5. REVIEW: request review from appropriate reviewers

Report: quality gate results, commit hash + message, PR number + URL.
