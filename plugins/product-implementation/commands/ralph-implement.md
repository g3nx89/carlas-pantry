---
description: "Start autonomous implementation via Ralph Loop"
argument-hint: "FEATURE_DIR"
allowed-tools:
  - Read
  - Glob
  - Skill
---

# Ralph Implement

Execute the implementation plan autonomously via a Ralph loop. The harness environment
must already be configured — this command validates and then loops the implement skill.

## Procedure

1. **Validate harness exists** — check that the feature directory (from `$ARGUMENTS`,
   or ask the user) contains `.harness/analysis.json` and `.harness/feature-list.json`.

   If either file is missing:
   > "The harness is not configured. Run `/product-implementation:harness` first."

2. **Check completion state** — read `.harness/feature-list.json`. If all tasks have
   `passes: true`, report "All tasks already complete" and stop.

3. **Count remaining tasks** — calculate how many tasks have `passes: false`.
   Set max iterations to `remaining_tasks * 2` (buffer for review fix loops).

4. **Invoke Ralph loop** — use `/oh-my-claudecode:ralph` (requires oh-my-claudecode plugin) with:
   - **Prompt**: "Follow the `/product-implementation:implement` protocol. Work one task
     at a time from `.harness/feature-list.json`. Stop when all tasks have `passes: true`
     or when blocked."
   - **Completion check**: "All tasks in `.harness/feature-list.json` have `passes: true`"
   - **Max iterations**: calculated above
