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

## Legacy Phase Files

The original phase-by-phase implementation files remain at `$CLAUDE_PLUGIN_ROOT/commands/requirements/` for reference. The skill consolidates them into 6 stages:

| Skill Stage | Original Phases |
|-------------|----------------|
| Stage 1: Setup | Phases 1-3 (initialization, workspace, configuration) |
| Stage 2: Research | Phases 4-5 (research agenda, synthesis) |
| Stage 3: Analysis & Questions | Phases 6-7 (ThinkDeep, MPA question generation) |
| Stage 4: Response & Gaps | Phases 8-9 (user response, gap analysis) |
| Stage 5: Validation & PRD | Phases 10-11 (readiness validation, PRD generation) |
| Stage 6: Completion | Phase 12 (lock release, report, next steps) |
