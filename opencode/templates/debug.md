---
description: Debug systematically — observe, hypothesize, test, verify. Replace random edits with the scientific method.
agent: build
subtask: true
---

Use the systematic-debugging skill:
1. OBSERVE: reproduce the bug, capture error messages, stack traces, logs, check git history
2. HYPOTHESIZE: list ALL possible causes with rationale and test plan. Rank by likelihood.
3. TEST: test each hypothesis with minimal diagnostic code. CONFIRMED or REJECTED.
4. VERIFY: once root cause found, apply fix, run reproduction steps (bug must NOT occur), run full test suite, add regression test.

Report: hypotheses table (tested, confirmed, rejected), root cause analysis, fix applied, regression test added.
