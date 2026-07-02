---
name: review-work
description: Post-implementation code review. Verify against plan, check correctness, test coverage, edge cases, and code quality. Report issues by severity.
license: MIT
compatibility: opencode
metadata:
  audience: developers
---

## What I do
- Review completed work against the implementation plan
- Check for correctness and edge case handling
- Verify test coverage for all new code
- Inspect for performance and security issues
- Report issues with severity (CRITICAL > HIGH > MEDIUM > INFO)
- Block progress on CRITICAL issues only

## Review checklist
1. **Plan compliance** — Does implementation match the spec/plan?
2. **Correctness** — Logic handles all expected paths correctly?
3. **Edge cases** — null/undefined, empty inputs, large inputs, boundaries
4. **Error handling** — try/catch, fallback states, user-facing errors
5. **Test coverage** — New code has tests? Tests pass? Edge cases covered?
6. **Performance** — No N+1 queries, unnecessary operations, memory issues?
7. **Security** — Input validated? No injection vectors? Auth checked?
8. **Code style** — Consistent with project conventions? No dead code?

## Review commands
```bash
# See what changed
git diff main..HEAD --stat

# Full diff
git diff main..HEAD

# Run tests
npm test

# Run lint + typecheck
npm run lint && npx tsc --noEmit

# Check for secrets accidentally committed
git diff main..HEAD | grep -iE '(password|secret|token|api_key|key)'

# Check test coverage
npm test -- --coverage

# Find TODO/FIXME in changes
git diff main..HEAD | grep -iE '(TODO|FIXME|HACK|XXX)'
```

## Severity levels
- **CRITICAL** — Bug that breaks functionality, data loss, security vulnerability. MUST fix before merge.
- **HIGH** — Missing feature from spec, broken edge case. SHOULD fix.
- **MEDIUM** — Style inconsistency, missing test, minor optimization. NICE to fix.
- **INFO** — Suggestion, alternative approach, documentation note. Optional.

## Output format
```
## Review: <feature/branch>

### CRITICAL
- <file>:<line> — <issue> (impact)

### HIGH
- <file>:<line> — <issue>

### MEDIUM
- <file>:<line> — <issue>

### Summary
- Critical: X, High: Y, Medium: Z
- Test coverage: XX%
- Verdict: APPROVED / CHANGES REQUESTED
```
