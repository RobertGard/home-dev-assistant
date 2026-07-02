---
name: performance-profile
description: Profile application performance: identify bottlenecks, memory leaks, slow queries, N+1 problems, and rendering issues. Suggest optimizations.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: docker-socket
---

## What I do
- Profile CPU and memory usage
- Identify slow database queries (N+1, missing indexes)
- Detect memory leaks and excessive allocations
- Analyze bundle size and load times
- Check for unnecessary re-renders (React/Vue)
- Measure API response times
- Find blocking I/O operations

## Frontend profiling
```bash
# Bundle analysis
npm run build -- --analyze  # webpack-bundle-analyzer

# Lighthouse check (if available)
npx lighthouse http://localhost:3000 --quiet --chrome-flags="--headless"
```

## Backend profiling
```bash
# CPU/memory of containers
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'

# Check for memory leaks: watch memory over time
for i in $(seq 1 5); do
  docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | tee -a /tmp/mem.log
  sleep 10
done

# Database query analysis
# Check for N+1: look for queries in loops
grep -rn '\.find\|\.query\|SELECT' --include='*.ts' --include='*.js' | head -20

# API response times
for url in $(cat endpoints.txt); do
  curl -s -o /dev/null -w "%{url_effective} %{time_total}s %{http_code}\n" "$url"
done
```

## Code-level issues to spot
1. **N+1 queries** — queries inside loops/map
2. **Missing indexes** — WHERE/JOIN columns without DB indexes
3. **Unnecessary re-renders** — React components without memo/useMemo
4. **Large bundles** — imported entire library instead of specific function
5. **Blocking operations** — sync I/O in async context
6. **Memory leaks** — unsubscribed listeners, growing collections
7. **Unoptimized images** — large uncompressed assets

## Output
```
## Performance Review: <project>

### Bottlenecks Found
- [CRITICAL] <file>:<line> — <issue> (<impact estimate>)
- [WARNING] <file>:<line> — <issue>

### Resource Usage
- CPU: X%, Memory: Y MB, API p95: Z ms

### Recommendations
- <specific optimization suggestion>
```
