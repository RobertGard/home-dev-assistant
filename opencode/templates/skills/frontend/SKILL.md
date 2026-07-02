---
name: frontend
description: Design-first frontend implementation. Review designs, implement UI components, ensure accessibility, handle responsive layouts, and verify visual correctness.
license: MIT
compatibility: opencode
metadata:
  audience: frontend-developers
  requires: playwright-mcp
---

## What I do
- Implement UI components from design specs or descriptions
- Ensure accessibility (a11y): ARIA labels, keyboard navigation, contrast
- Handle responsive layouts (mobile-first)
- Verify visual correctness via Playwright
- Optimize bundle size and load performance
- Follow component patterns (composition over inheritance)

## Implementation workflow
1. **Plan** — Identify component hierarchy, props, state, events
2. **Build** — Implement with proper types, loading/error/empty states
3. **Style** — CSS modules / Tailwind / styled-components — follow project convention
4. **Accessibility** — ARIA labels, semantic HTML, keyboard navigation, focus management
5. **Test** — Visual verification via Playwright, unit tests for logic
6. **Optimize** — Lazy loading, code splitting, image optimization

## Accessibility checklist
```bash
# Semantic HTML
# ✅ <button> — not <div onclick>

# ARIA labels
# ✅ <button aria-label="Close dialog">×</button>

# Keyboard navigation
# ✅ tabIndex for custom interactive elements
# ✅ onKeyDown for Enter/Escape handlers

# Color contrast
# Check: minimum 4.5:1 for normal text, 3:1 for large text

# Focus management
# ✅ visible focus ring (never outline: none without replacement)
# ✅ focus trap in modals
# ✅ focus restoration on close
```

## Responsive patterns
```css
/* Mobile-first approach */
.container { padding: 1rem; }  /* mobile default */
@media (min-width: 768px) { .container { padding: 2rem; } }
@media (min-width: 1024px) { .container { max-width: 1200px; margin: 0 auto; } }
```

## State handling
```typescript
// Every component should handle these states:
type ComponentState<T> = 
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'empty' }  
  | { status: 'success'; data: T }

// ✅ Always show loading state
if (isLoading) return <Skeleton />

// ✅ Always handle errors
if (error) return <Error message={error.message} onRetry={refetch} />

// ✅ Always handle empty
if (data.length === 0) return <Empty message="No items found" />
```

## Visual verification
```bash
# Screenshot comparison
playwright_navigate({ url: "http://localhost:3000" })
playwright_screenshot({ name: "homepage" })

# Responsive check
playwright_setViewport({ width: 375, height: 812 })  # iPhone
playwright_screenshot({ name: "homepage-mobile" })

# Console errors check
playwright_evaluate({ expression: "() => window.__consoleErrors || []" })

# Lighthouse audit (if available)
npx lighthouse http://localhost:3000 --chrome-flags="--headless" --quiet
```
