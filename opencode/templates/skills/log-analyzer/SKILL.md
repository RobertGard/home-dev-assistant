---
name: log-analyzer
description: Analyze application and container logs to detect error patterns, performance issues, security anomalies, and anomalies. Correlate events across services.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  requires: docker-socket
---

## What I do
- Parse and analyze docker container logs
- Detect error patterns, stack traces, and warning spikes
- Correlate events across multiple services
- Identify slow requests and performance bottlenecks
- Detect security anomalies (brute force, SQL injection attempts)
- Generate structured incident reports
- Track error rate trends over time

## When to use me
Use this skill when:
- Something is broken and logs need investigation
- You want to understand error frequency and patterns
- A deployment caused new errors — before/after comparison
- There are intermittent failures that need root cause analysis
- Performance is degrading and you need to find slow endpoints
- Security incidents need investigation from logs

## Commands reference
```bash
# View recent logs for all containers
docker compose logs --tail 200 --timestamps

# Follow logs in real-time
docker compose logs -f --tail 50

# View logs for specific service
docker compose logs api --tail 500

# Filter for errors only
docker compose logs --tail 500 2>&1 | grep -iE 'error|exception|fatal|panic|fail'

# Count error frequency per service (last 500 lines)
docker compose logs --tail 500 2>&1 | grep -iE 'error|exception' | \
  cut -d'|' -f1 | sort | uniq -c | sort -rn

# Find stack traces
docker compose logs --tail 1000 2>&1 | grep -A 20 'Traceback\|stack trace\|at .*(.*:\d+)'

# Time-window analysis (errors in specific timeframe)
docker compose logs --since 30m 2>&1 | grep -i error

# View logs with JSON formatting (if structured logging)
docker compose logs --tail 100 api 2>&1 | jq 'select(.level == "error")'

# Check for specific patterns
docker compose logs 2>&1 | grep -c 'connection refused'
docker compose logs 2>&1 | grep -c 'timeout'
docker compose logs 2>&1 | grep -c 'rate limit'

# Application log files (non-docker)
tail -n 500 app.log | grep -i error
tail -n 500 app.log | jq 'select(.status >= 500)'
```

## Error pattern detection
```bash
# Group errors by message pattern
docker compose logs --tail 1000 2>&1 | \
  grep -oP '(?<=Error: |Exception: |Fatal: ).*' | \
  sort | uniq -c | sort -rn | head -20

# Find slow requests (access logs)
docker compose logs nginx --tail 500 2>&1 | \
  awk '{if($NF>1.0) print $0}'  # response time > 1s

# OOM / resource issues
docker compose logs 2>&1 | grep -i 'out of memory\|OOM\|killed'

# Database errors
docker compose logs postgres --tail 500 2>&1 | \
  grep -iE 'error|fatal|panic|deadlock|timeout'
```

## Incident report template
```
# INCIDENT REPORT: <title>
- Time detected: <datetime>
- Duration: <time>
- Services affected: <list>
- Severity: P0/P1/P2/P3

## Timeline (UTC)
| Time | Event |
|------|-------|
| 14:30 | First error spike detected |
| 14:32 | DB connection pool exhausted |
| 14:35 | Auto-recovery via connection reset |

## Root Cause
<explanation with log evidence>

## Impact
- Users affected: <count>
- Errors: <count> <type>
- Data loss: <yes/no>

## Resolution
<what was done to fix>

## Prevention
<what to change to prevent recurrence>
```

## Output format
```
## Log Analysis Report: <service/context>

### Error Summary (last <timeframe>)
| Error Pattern | Count | First Seen | Last Seen |
|---------------|-------|------------|------------|
| ConnectionRefusedError | 47 | 14:30 | 14:35 |
| NullPointerException | 12 | 14:31 | 14:33 |

### Top Errors
1. `ConnectionRefusedError: Connection refused to postgres:5432` (47 occurrences)
   - Source: api/src/db.ts:23
   - Likely cause: DB container restart during deployment
   - Fix: add retry with exponential backoff to DB connection

2. `NullPointerException at handleLogin` (12 occurrences)
   - Source: auth/login.ts:42
   - Likely cause: null user after failed auth
   - Fix: add null guard before accessing user.email

### Performance
- Slowest endpoints (p95): GET /api/search (3.2s), POST /api/reports (2.1s)
- Memory trend: stable at 65% of limit
- CPU spikes: 14:30-14:35 (correlates with DB outage)
```
