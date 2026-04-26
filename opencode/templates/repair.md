---
description: Repair the active repository and prove the fix with verification steps
agent: build
---

1. Diagnose the failing behavior from the current task context.
2. Use `serena` for symbol-aware analysis when useful.
3. Use `context7` for current docs if the issue touches framework APIs.
4. Apply the smallest correct fix.
5. Re-run relevant checks.
6. If a compose file exists, boot the full declared infrastructure and verify service state.
7. Return a concise engineering summary with what changed and what still needs attention.
