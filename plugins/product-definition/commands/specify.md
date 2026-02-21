---
description: Create or update the feature specification from a natural language feature description.
argument-hint: |
  Feature description

  Figma Integration Options:
    --figma    Enable Figma integration (will ask: desktop vs online, capture mode)
    --no-figma Skip Figma integration entirely (no questions asked)
    (no flag)  Interactive mode - will ask if you want Figma integration
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Bash(mkdir:*)", "Bash(test:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-desktop__get_metadata", "mcp__figma__get_screenshot", "mcp__figma__get_design_context", "mcp__figma__get_metadata"]
---

# Specify Feature (Superseded)

> **This command has been migrated to a skill.**
> The canonical implementation is now at `$CLAUDE_PLUGIN_ROOT/skills/specify/SKILL.md`.

This command is a thin wrapper that invokes the specify skill.

---

## Execution

Read and execute the skill at: @$CLAUDE_PLUGIN_ROOT/skills/specify/SKILL.md

Pass all arguments: `$ARGUMENTS`

---

## Legacy Phase Mapping

The original phase-by-phase implementation has been consolidated into 7 stages. Research phases (1.7, 1.8) are excluded from the skill:

| Skill Stage | Original Phases |
|-------------|----------------|
| Stage 1: Setup & Figma | Phases 0.0-0.5, 1.0, 1.5 (pre-flight, lock, state, init, Figma) |
| Stage 2: Spec Draft & Gates | Phases 2.0, 2.3, 2.5, 2.7 (BA draft, MPA-Challenge, gates) |
| Stage 3: Checklist & Validation | Phases 3.0, 4.0 (checklist creation, BA validation) |
| Stage 4: Edge Cases & Clarification | Phases 4.3, 4.5, 4.6 (EdgeCases, clarification, triangulation) |
| Stage 5: PAL Validation & Design | Phases 5.0, 5.5 (PAL Consensus, design-brief, design-supplement) |
| Stage 6: Testability & Risk Assessment | Phase 5.7 (risk analysis, testability verification) |
| Stage 7: Completion | Phase 6.0 (lock release, report, next steps) |

**Excluded:** Phases 1.7 (Research Discovery) and 1.8 (Research Analysis) are not part of the skill workflow.
