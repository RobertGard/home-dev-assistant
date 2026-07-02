---
name: security-audit
description: Perform comprehensive security audit. Check OWASP Top 10, dependency vulnerabilities, secret leaks, auth flaws, and configuration issues. Never change code.
license: MIT
compatibility: opencode
metadata:
  audience: security
  requires: github-mcp, bravesearch-mcp
---

## What I do
- Audit code for OWASP Top 10 vulnerabilities
- Scan dependencies for known CVEs (npm audit, cargo audit, pip audit, etc.)
- Check for exposed secrets and API keys in code
- Review authentication and authorization logic
- Inspect configuration for security best practices
- Verify input validation and sanitization
- Check rate limiting and DoS protections
- Audit CORS, CSP, and security headers

## Audit checklist
1. **Injection** — SQL, NoSQL, command, LDAP injection vectors
2. **Broken Auth** — Session management, token handling, password policies
3. **Sensitive Data Exposure** — Encryption at rest/in transit, PII handling
4. **XXE** — XML external entity processing
5. **Broken Access Control** — Role checks, direct object references
6. **Security Misconfiguration** — Default passwords, verbose errors, open ports
7. **XSS** — Reflected, stored, DOM-based
8. **Insecure Deserialization** — Untrusted data deserialization
9. **Using Vulnerable Components** — Outdated libraries, known CVEs
10. **Insufficient Logging** — Audit trails, monitoring coverage

## Workflow
```bash
# Dependency audit
npm audit --audit-level=high
# or: pip-audit, cargo audit, bundle audit

# Secret detection (preferred: gitleaks)
gitleaks detect --source . --verbose 2>&1

# Fallback if gitleaks unavailable: grep patterns
git log --all -p | grep -iE '(password|secret|token|api[_-]?key|private[_-]?key)'

# Check git history for committed secrets
git rev-list --all | xargs -I{} git grep -iE '(password|secret|token)' {} -- ':!.gitignore'

# Security headers check
curl -sI https://localhost | grep -iE '(strict-transport|content-security|x-frame|x-content)'

# Open ports scan
docker ps --format '{{.Names}} {{.Ports}}'

# Check environment files
find . -name '.env*' -o -name '*.pem' -o -name '*.key' | grep -v '.git/'
```

## Output format
```
## Security Audit: <project>

### Critical (CVE/CVSS >= 7)
- <file>:<line> — <vulnerability> (CVE-XXXX-XXXXX)

### High
- <file>:<line> — <vulnerability>

### Medium
- <file>:<line> — <vulnerability>

### Recommendations
- <specific remediation step>
```
