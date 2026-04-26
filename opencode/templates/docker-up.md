---
description: Boot the active repository's full Docker infrastructure through the host engine
agent: build
---

1. Inspect the active repository for `compose.yaml` or `docker-compose.yml`.
2. Use the host Docker engine through the mounted socket.
3. Start the full declared stack with the safest non-destructive command available.
4. Summarize started services, published ports, health, and follow-up actions.
