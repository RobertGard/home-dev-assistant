---
description: Bootstrap a repository from the worker repo catalog
agent: build
---

1. Read the worker repo catalog and identify the target repository.
2. Clone or update the repository into the workspace if needed.
3. Install dependencies with the detected package manager.
4. If configured, run the repository's configured Turborepo task set.
5. If configured, boot the repository's full Docker stack.
6. Return a concise summary of bootstrap status and next actions.
