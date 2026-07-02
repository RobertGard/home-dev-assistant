---
name: git-master
description: Master Git operations: atomic commits, surgical rebases, bisect debugging, history search, and safe force-push workflows. Never lose work.
license: MIT
compatibility: opencode
metadata:
  audience: developers
---

## What I do
- Create atomic, well-structured commits
- Perform surgical interactive rebases
- Debug regressions with git bisect
- Search commit history for patterns
- Recover lost commits from reflog
- Clean up branches before PR
- Safe force-push workflows

## Atomic commits
```bash
# NEVER do: git add .
# ALWAYS do:
git add -p  # interactive staging — commit logical units separately

# Each commit should:
# 1. Do ONE thing
# 2. Pass tests independently
# 3. Have a descriptive message

# Good commit message format:
# <type>: <short description>
#
# <why this change>
# <any breaking changes>
```

## Interactive rebase
```bash
# Before PR: clean up commit history
git rebase -i HEAD~5  # squash fixups, reorder logically

# Common operations in rebase:
# pick — keep this commit
# reword — change commit message
# squash — merge into previous commit
# fixup — merge into previous, discard message
# drop — remove this commit

# After rebase, verify:
git diff origin/main..HEAD  # changes look right?
npm test  # tests pass?
```

## Bisect debugging
```bash
# Find which commit introduced a bug
git bisect start
git bisect bad HEAD        # current is broken
git bisect good v1.0.0     # last known good
# Git checks out middle commit — test it
npm test && git bisect good || git bisect bad
# Repeat until found

git bisect reset  # exit bisect mode
```

## History search
```bash
# Find when a function was added/removed
git log -S 'functionName' --source --all

# Search commit messages
git log --all --grep='fix.*memory leak'

# Find who last touched each line
git blame path/to/file.ts -L 40,60

# Show changes between two points
git log main..feature --oneline

# Find deleted files
git log --diff-filter=D --summary | grep delete
```

## Recovery
```bash
# Find lost commits (even after reset --hard)
git reflog

# Recover a lost commit
git checkout <sha>

# Undo last commit, keep changes
git reset --soft HEAD~1

# Undo last commit, discard changes
git reset --hard HEAD~1
```

## PR cleanup checklist
1. `git rebase -i main` — clean history
2. Each commit does one thing and builds
3. `npm test` passes on every commit
4. No merge commits in branch
5. No "WIP" or "fix typo" commits remain
6. `git diff main..HEAD` reviewed
7. Force-push ONLY to your own branch: `git push --force-with-lease`
