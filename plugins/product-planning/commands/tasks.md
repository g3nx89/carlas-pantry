---
description: "[DEPRECATED] Use /product-planning:plan instead. Task generation is now integrated into Phase 9 of the planning workflow."
argument-hint: "[DEPRECATED] Run /product-planning:plan for integrated task generation"
allowed-tools: ["Bash(git:*)", "AskUserQuestion"]
---

# Deprecated: Task Generation Command

> **This command is deprecated.** Task generation is now fully integrated into the `/product-planning:plan` skill (Phase 9).

## Why Deprecated?

The standalone `/tasks` command has been integrated into the main planning workflow because:

1. **TDD Integration** - Task generation needs test artifacts from Phases 7-8 to properly reference test IDs (UT-*, INT-*, E2E-*, UAT-*) in task definitions.

2. **Context Continuity** - Tasks benefit from full planning context (architecture decisions, risk analysis, ThinkDeep insights) that only exists after completing Phases 1-8.

3. **State Management** - The planning workflow tracks state and ensures tasks are generated only after prerequisites are complete.

4. **V-Model Alignment** - The integrated approach ensures every acceptance criterion has corresponding tests AND every task references those tests.

## What to Do Instead

### Option 1: Run Full Planning (Recommended)

```bash
/product-planning:plan
```

This executes the complete 9-phase workflow including integrated task generation in Phase 9.

### Option 2: Resume Existing Planning Session

If you've already completed planning but need to regenerate tasks:

```bash
# Check current state
cat {FEATURE_DIR}/.planning-state.local.md

# If planning was completed, you can manually trigger Phase 9
# by asking: "regenerate tasks for this feature"
```

## Migration Guide

| Old Workflow | New Workflow |
|--------------|--------------|
| Run `/plan` → Run `/tasks` separately | Run `/plan` (includes task generation) |
| Tasks missing test references | Tasks have full TDD integration |
| Manual context loading | Automatic context from all phases |
| 2 iteration clarification | Integrated clarification with validation |

## User Input

```text
$ARGUMENTS
```

## Redirect Logic

```
1. DETECT current git branch
   IF branch matches `feature/<NNN>-<kebab-case>`:
     FEATURE_NAME = part after "feature/"
     FEATURE_DIR = "specs/{FEATURE_NAME}"

2. CHECK planning state
   IF {FEATURE_DIR}/.planning-state.local.md exists:
     READ state
     IF state.phase == "COMPLETION" AND state.tasks_generated == true:
       DISPLAY: "Tasks already generated. See {FEATURE_DIR}/tasks.md"
       ASK: "Would you like to regenerate tasks? This will overwrite existing tasks.md"
       IF yes → Suggest running Phase 9 manually
     ELSE IF state.phase == "COMPLETION":
       DISPLAY: "Planning complete but tasks not yet generated."
       SUGGEST: "Run Phase 9 task generation"
     ELSE:
       DISPLAY: "Planning not complete (current phase: {state.phase})"
       SUGGEST: "Run /product-planning:plan to complete planning with integrated task generation"
   ELSE:
     DISPLAY: "No planning state found for this feature."
     SUGGEST: "Run /product-planning:plan to start planning workflow"

3. ASK user via AskUserQuestion:
   "The /tasks command is deprecated. Task generation is now part of /plan (Phase 9).

   Would you like to:
   1. Run /product-planning:plan (full planning with task generation)
   2. View existing tasks.md (if available)
   3. Cancel"
```

---

*Deprecated in v2.0.0 - Task generation integrated into /plan Phase 9*
