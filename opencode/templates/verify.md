---
description: Verify the active project with lint, tests, and Docker smoke checks
agent: build
---

1. Work inside the active repository directory.
2. Use `serena` when semantic code navigation or refactors are helpful.
3. Use `context7` for current framework and library docs when needed.
4. Run lint, typecheck, and tests that make sense for the repository.
5. If a compose file exists, boot the full declared infrastructure and verify service state.
6. Do not read `.env` files unless explicitly asked.
7. Return a concise engineering summary with failures, commands run, and next steps.
