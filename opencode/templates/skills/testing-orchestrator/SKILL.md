---
name: testing-orchestrator
description: Orchestrate test execution intelligently — run only affected tests, detect and manage flaky tests, parallelize suites, and generate test coverage from diffs.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: git-diff
---

## What I do
- Determine which tests to run based on changed files (`git diff`)
- Run tests in parallel across available cores
- Detect flaky tests by re-running failures and comparing results
- Prioritize test execution: fast tests first, then integration, then e2e
- Generate targeted tests for new code based on diffs
- Track test execution metrics over time (duration, flakiness score)
- Smart test splitting for CI parallelism

## When to use me
Use this skill when:
- You've made changes and want to run only relevant tests
- You're dealing with flaky tests and need to identify them
- Test suite is too slow and needs optimization
- You want to verify coverage for new code
- CI tests are flaky and you need to diagnose
- You're splitting a test suite across CI jobs

## Commands reference
```bash
# Find test files related to changed source files
git diff --name-only HEAD~1 | while read f; do
  test_file="${f/src\//__tests__\/}"
  test_file="${test_file%.ts}.test.ts"
  [ -f "$test_file" ] && echo "$test_file"
done

# Run only tests related to changes (Jest)
npm test -- --findRelatedTests $(git diff --name-only HEAD~1 | tr '\n' ' ')

# Run tests in parallel (Jest)
npm test -- --maxWorkers=$(nproc)

# Detect flaky tests — run failing tests N times
npm test -- --onlyFailures --repeat=5

# Flaky detector script
for i in $(seq 1 5); do
  npm test -- --onlyFailures 2>&1 | tee "run-$i.log"
done
# Analyze: tests that pass in some runs, fail in others = flaky

# Time-based test splitting (slow/fast)
npm test -- --testPathPattern='(?!.*\.e2e\.).*'
npm test -- --testPathPattern='.*\.e2e\..*'

# Coverage for changed files only
git diff --name-only HEAD~1 | grep '\.ts$' | grep -v '\.test\.' | \
  xargs npm test -- --collectCoverageFrom

# Test impact analysis — which tests are slowest?
npm test -- --verbose --json 2>/dev/null | \
  jq '.testResults[].assertionResults[] | select(.status=="passed") | {name: .fullName, duration: .duration} | select(.duration > 5000)'

# Generate test skeleton for new files
git diff --name-only --diff-filter=A HEAD~1 | while read f; do
  echo "New file: $f — consider adding tests"
done
```

## Test selection strategies
```
1. Changed-files: tests matching changed source files
2. Dependency-graph: tests that import changed modules
3. Affected-specs: e2e specs covering changed routes
4. Full-suite: run everything (nightly, pre-release)
5. Smoke: critical path tests only (pre-deploy gate)
```

## Flaky test detector
```bash
#!/usr/bin/env bash
# Runs failing tests multiple times to detect flakiness
FAILED_TESTS=$(npm test -- --json 2>/dev/null | jq -r '.testResults[] | select(.status=="failed") | .name')
PASSES=0
RUNS=5

for test in $FAILED_TESTS; do
  for i in $(seq 1 $RUNS); do
    if npm test -- --testNamePattern="$test" >/dev/null 2>&1; then
      PASSES=$((PASSES + 1))
    fi
  done
  FLAKE_SCORE=$((100 - (PASSES * 100 / RUNS)))
  echo "$test: flake_score=$FLAKE_SCORE% ($PASSES/$RUNS consistent passes)"
done
```

## Output format
```
## Test Orchestration Report

### Test Selection
- Changed files: <N> → Found <M> related test files
- Strategy: <changed-files/full-suite/smoke>
- Estimated duration: <time>

### Results
| Suite | Tests | Passed | Failed | Skipped | Duration |
|-------|-------|--------|--------|---------|----------|
| unit | 145 | 143 | 2 | 0 | 12s |
| integration | 67 | 67 | 0 | 0 | 45s |
| e2e | 23 | 23 | 0 | 0 | 3m 10s |

### Flaky Test Analysis
| Test | Pass Rate | Recommendation |
|------|-----------|----------------|
| AuthFlow.test.ts:42 | 60% (3/5) | Add `waitFor` before assertion |
| Search.test.ts:88 | 80% (4/5) | Mock network call, remove race condition |

### Coverage (changed files only)
| File | Lines | Branches | Functions |
|------|-------|----------|-----------|
| src/auth/login.ts | 92% | 85% | 100% |
| src/api/search.ts | 78% | 60% | 100% |

### Recommendations
1. Fix 2 flaky tests (tagged above)
2. Add tests for search.ts error handling (22% uncovered)
3. Split e2e suite across 3 CI jobs (would save 2 min)
```
