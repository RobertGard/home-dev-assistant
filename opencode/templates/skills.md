---
description: Dynamic skill discovery and installation — search skills.sh, install skills at runtime, manage skill presets.
agent: build
subtask: true
---

Use the find-skills skill (from skills.sh):
1. SEARCH: check skills.sh for skills matching the current task domain
2. INSTALL: run `npx skills add <owner/repo>` for selected skills
3. LIST: show currently installed skills (built-in + dynamically added)
4. PRESET: suggest and install skill presets based on project stack

Report: installed skills, newly added skills, recommended presets for this project.
