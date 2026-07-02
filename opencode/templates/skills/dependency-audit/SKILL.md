---
name: dependency-audit
description: Audit project dependencies: check for vulnerabilities, outdated packages, license compliance, and unused dependencies. Suggest safe upgrades.
license: MIT
compatibility: opencode
metadata:
  audience: developers
---

## What I do
- Run security audit on all dependencies
- Check for outdated packages with available updates
- Identify unused dependencies that can be removed
- Verify license compatibility
- Suggest safe version upgrades
- Check for deprecated packages

## Commands by package manager
```bash
# npm
npm audit --audit-level=moderate
npm outdated
npx depcheck  # find unused deps
npx license-checker --summary

# yarn
yarn audit --level moderate
yarn outdated
yarn dlx depcheck

# pnpm
pnpm audit --audit-level moderate
pnpm outdated
pnpm dlx depcheck

# pip (Python)
pip-audit
pip list --outdated
pip-licenses --summary

# cargo (Rust)
cargo audit
cargo outdated
cargo deny check

# bundler (Ruby)
bundle audit check --update
bundle outdated
```

## Safe upgrade process
```bash
# npm: check what will change
npx npm-check-updates

# Upgrade one package at a time
npm install <package>@latest

# Run tests after each upgrade
npm test

# If tests fail, roll back
npm install <package>@<previous-version>
```

## License compliance check
```bash
# npm
npx license-checker --production --summary --onlyAllow 'MIT;ISC;Apache-2.0;BSD-2-Clause;BSD-3-Clause'

# Check for copyleft licenses (GPL, AGPL, etc.)
npx license-checker --production | grep -iE 'gpl|agpl|lgpl'
```

## Output format
```
## Dependency Audit: <project>

### Vulnerabilities (CVEs)
| Package | Current | CVE | Severity | Fix Version |
|---|---|---|---|---|
| lodash | 4.17.20 | CVE-2021-23337 | HIGH | 4.17.21 |

### Outdated Packages
- <package>: <current> → <latest> (<changelog>)

### Unused Dependencies
- <package> (can be removed)

### License Issues
- <package>: <license> (not in allowed list)

### Recommended Upgrades
1. <package>: <version> → <version> (fixes CVE-XXXX)
```
