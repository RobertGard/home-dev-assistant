---
name: api-testing
description: Test REST and GraphQL APIs: verify endpoints, status codes, response bodies, auth, rate limiting, and error handling with curl.
license: MIT
compatibility: opencode
metadata:
  audience: developers
---

## What I do
- Test REST API endpoints with curl
- Verify correct HTTP status codes
- Validate response body structure and content
- Test authentication and authorization
- Check rate limiting headers
- Verify error responses (400, 401, 403, 404, 500)
- Test pagination, filtering, sorting
- Validate CORS headers
- Test GraphQL queries and mutations

## REST API testing
```bash
# Health check
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health

# GET with auth
curl -s -H "Authorization: Bearer <token>" http://localhost:3000/api/users

# POST with JSON body
curl -s -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"test","email":"test@example.com"}'

# Verify response status and body
response=$(curl -s -w "\n%{http_code}" http://localhost:3000/api/users)
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

# Test error cases
curl -s -o /dev/null -w "401=%{http_code} " http://localhost:3000/api/users  # no auth
curl -s -o /dev/null -w "404=%{http_code} " http://localhost:3000/api/nonexistent
curl -s -o /dev/null -w "400=%{http_code} " -X POST http://localhost:3000/api/users -d '{}'

# Check CORS headers
curl -s -I -H "Origin: http://example.com" http://localhost:3000/api/users | grep -i 'access-control'

# Rate limiting
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{http_code} " http://localhost:3000/api/users
done
```

## GraphQL testing
```bash
# Simple query
curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ users { id name email } }"}'

# Mutation with variables
curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"query":"mutation($input:CreateUserInput!){ createUser(input:$input){ id } }","variables":{"input":{"name":"test"}}}'

# Introspection (check if enabled in production)
curl -s -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { types { name } } }"}'
```

## Output format
```
## API Test Results

| Endpoint | Method | Auth | Expected | Actual | Status |
|---|---|---|---|---|---|
| /health | GET | No | 200 | 200 | PASS |
| /api/users | GET | Yes | 200 | 401 | FAIL |
| /api/users | POST | Yes | 201 | 201 | PASS |

### Failures
- GET /api/users: Expected 200, got 401 (missing auth token)
```
