---
name: ast-grep
description: Pattern-aware code search and rewriting across 25+ languages. Use when you need to find, match, or transform code by AST patterns instead of regex. Faster and more accurate than grep for structural code changes.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: ast-grep-cli
---

## What I do
- Find code by structural pattern (not text regex)
- Rewrite code across entire codebase with AST accuracy
- Detect anti-patterns and deprecated API usage
- Enforce coding conventions at AST level
- Generate fix suggestions for lint violations
- Safe refactoring: only matches valid syntax nodes

## When to use me
- "Find all function calls that take 3 arguments"
- "Replace all `var` declarations with `const`/`let`"
- "Find React components without memo()"
- "Migrate from API v1 to v2 across the codebase"
- "Find all database queries without error handling"
- "Enforce import conventions"

## Quick reference
```bash
# Search by pattern
sg -p 'console.log($$$)' --lang ts

# Search by rule file
sg scan --rule my-rule.yml

# Interactive rewrite
sg -p 'var $A = $B' -r 'const $A = $B' --lang ts

# Run all rules from a directory
sg scan --rule-dir ./rules/

# Find with context
sg -p '$O.find($$$)' -C 3 --lang ts

# Test a rule
sg test --rule my-rule.yml --test-dir ./tests/
```

## Rule format (rule.yml)
```yaml
id: no-console-log
message: Use logger instead of console.log
severity: warning
language: TypeScript
rule:
  pattern: console.log($$$)
fix: logger.log($$$)
```

## Common patterns
```bash
# Find all useState without type parameter
sg -p 'const [$A, $B] = useState($C)' --lang tsx

# Find unawaited promises
sg -p '$A.$METHOD($$$)' --lang ts  # then filter for Promise methods

# Find missing try/catch on async calls
sg -p 'await $FUNC($$$)' --lang ts  # check if inside try/catch

# Find deprecated imports
sg -p 'import { $$$ } from "old-lib"' --lang ts

# Find incomplete error handling
sg -p 'catch ($E) { $$$ }' --lang ts  # check if body is empty
```

## Integration with lint workflow
```bash
# Run ast-grep rules as part of CI
sg scan --rule-dir .sg-rules/ --report-style rich

# Combine with eslint
npm run lint && sg scan
```
