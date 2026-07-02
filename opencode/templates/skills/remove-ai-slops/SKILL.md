---
name: remove-ai-slops
description: Detect and clean common AI-generated code smells: excessive comments, over-engineering, unused variables, redundant abstractions, and verbose patterns. Never change logic.
license: MIT
compatibility: opencode
metadata:
  audience: developers
---

## What I do
- Find and remove pointless comments ("Increment counter", "Create a new instance")
- Replace verbose patterns with idiomatic equivalents
- Remove unused imports, variables, and functions
- Collapse over-engineered abstractions into simple code
- Convert overly defensive null checks to proper types
- Simplify nested ternaries into readable conditionals
- Remove console.log and debug statements
- Clean up "it works" code into production quality

## Common AI slops
```typescript
// ❌ SLOP — obvious comments
// Create a new user
const user = new User()

// ✅ CLEAN
const user = new User()

// ❌ SLOP — unnecessary intermediate variable
const result = await fetchData()
const data = result.data
return data

// ✅ CLEAN
return (await fetchData()).data

// ❌ SLOP — over-defensive when types guarantee safety
if (user && user.name && user.name.first) { ... }

// ✅ CLEAN (if user is typed as non-nullable)
user.name.first

// ❌ SLOP — verbose try/catch for non-critical code
try { await logEvent() } catch (error) { console.error(error) }

// ✅ CLEAN
await logEvent().catch(console.error)

// ❌ SLOP — nested ternaries
const color = isActive ? (isAdmin ? 'red' : 'blue') : 'gray'

// ✅ CLEAN — use if/else or object map
const color = getColor({ isActive, isAdmin })

// ❌ SLOP — pointless abstraction
const createMultiplier = (n: number) => (x: number) => x * n
const double = createMultiplier(2)

// ✅ CLEAN
const double = (x: number) => x * 2
```

## Detection commands
```bash
# Find obvious comments (single line, matches code exactly)
git diff HEAD~1 | grep -E '^\+\s*//.*(create|set|get|return|increment|decrement)' | head -20

# Find console.log
git diff HEAD~1 | grep -E '^\+\s*console\.(log|debug|info)' | head -20

# Find overly defensive null checks
# (AST-grep can find these structurally)
sg -p 'if ($OBJ && $OBJ.$PROP) { $$$ }' --lang ts

# Find empty catch blocks
sg -p 'catch ($E) { }' --lang ts

# Find unused imports (run linter)
npx eslint --rule 'no-unused-vars: error' --quiet

# Find TODO/FIXME without context
git diff HEAD~1 | grep -E '^\+\s*//.*(TODO|FIXME)$'
```

## Rules
1. **NEVER change logic** — only clean up code style and verbosity
2. **If unsure, leave it** — better AI-slop than broken code
3. **Run tests after every change** — ensure nothing broke
4. **One type of slop per commit** — easy to review/revert
5. **Prefer project conventions** — follow existing code style over generic rules
