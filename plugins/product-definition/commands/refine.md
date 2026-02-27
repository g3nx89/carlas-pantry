---
description: Generate a finalized, non-technical PRD from a user's draft through iterative Q&A with offline file-based responses.
argument-hint: |
  Draft filename (in requirements/draft/)

  Options:
    --mode=complete    Use full analysis (MPA + PAL + ST) - Recommended
    --mode=advanced    Use MPA + PAL ThinkDeep
    --mode=standard    Use MPA only
    --mode=rapid       Use single BA agent
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking"]
---

# Requirements Refinement (Superseded)

> **This command has been migrated to a skill.**
> The canonical implementation is now at `$CLAUDE_PLUGIN_ROOT/skills/refinement/SKILL.md`.

This command is a thin wrapper that invokes the refinement skill.

---

## Execution

Read and execute the skill at: @$CLAUDE_PLUGIN_ROOT/skills/refinement/SKILL.md

Pass all arguments: `$ARGUMENTS`

---
