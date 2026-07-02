---
description: Systematic debugging — find root cause using 4-phase process
agent: build
subtask: true
---

Follow the systematic-debugging skill:
1. REPRODUCE — reliably trigger the bug, capture exact error
2. ISOLATE — narrow to minimum reproducible case
3. IDENTIFY — find exact line/cause using logs and code inspection
4. VERIFY — confirm fix resolves the issue

Current context: $ARGUMENTS

Check docker logs, test output, console errors, and relevant source files.
Report: root cause (file:line), why it happens, and fix suggestion.
Do NOT fix — diagnose only.
