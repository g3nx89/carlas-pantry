---
stage: "2"
description: "Figma Preparation — per-screen file modifications via handoff-figma-preparer agent"
agents_dispatched: ["handoff-figma-preparer"]
artifacts_written:
  - "design-handoff/handoff-manifest.md"
  - "design-handoff/screenshots/*-before.png"
  - "design-handoff/screenshots/*-after.png"
  - "design-handoff/.handoff-state.local.md (updated per-screen)"
config_keys_used:
  - "figma_preparation.one_screen_per_dispatch"
  - "figma_preparation.component_library_dispatch"
  - "figma_preparation.prototype_wiring_dispatch"
  - "figma_preparation.scenario_detection.*"
  - "judge.checkpoints.stage_2j.*"
  - "tier.*"
---

# Stage 2 — Figma Preparation (Coordinator)

> Orchestrator dispatches `handoff-figma-preparer` agent — ONE screen per dispatch.
> This file describes the orchestrator's workflow. The agent's internal procedure
> (9-step checklist, scenario logic) lives in `agents/handoff-figma-preparer.md`.
> Figma API recipes live in the `figma-console-mastery` skill references.

## Purpose

Raw Figma design files contain ambiguous layer names, hardcoded hex colors, GROUP nodes
with no layout semantics, and disconnected component usage. A coding agent consuming
these files would guess intent rather than translate it. Stage 2 transforms each screen
into a clean, token-bound, component-integrated frame with verified visual fidelity —
producing a handoff-ready Figma file and an incrementally-assembled handoff manifest.

**Inputs consumed:**
- `design-handoff/.screen-inventory.md` — screen list, readiness scores, componentization candidates (from Stage 1)
- `design-handoff/.handoff-state.local.md` — scenario, TIER decision, per-screen status (from Stage 1)

**Outputs produced:**
- Per-screen: before/after screenshots in `design-handoff/screenshots/`
- Per-screen: state file updated with step-level progress and operation journal
- Aggregate: `design-handoff/handoff-manifest.md` — assembled incrementally as screens complete
- Aggregate: component library page/frame in Figma (TIER 2/3 only, one-time creation)

---

## Dispatch Strategy

**ONE screen per dispatch.** The figma-console MCP server is context-heavy — each call
returns large node trees, variable collections, and component metadata. Processing
multiple screens in a single agent dispatch leads to context compaction, causing the
agent to lose track of node IDs, skip checklist steps, or produce inaccurate visual diffs.

The orchestrator maintains the screen loop and dispatches `handoff-figma-preparer` once
per screen, sequentially. Between dispatches, the orchestrator reads the state file to
determine whether the screen was prepared, blocked, or errored — and decides whether to
continue, re-dispatch with fix instructions, or skip to the next screen.

**Dispatch order:** Process screens in the same order as the Stage 1 inventory (Y ascending,
X ascending on the Figma page). This matches the natural reading order designers use and
produces a manifest in page order.

---

## Pre-Dispatch: Component Library (TIER 2/3 Only)

Before entering the screen loop, TIER 2 and TIER 3 workflows require a one-time dispatch
to create the component library. This dispatch uses the same `handoff-figma-preparer` agent
but with a dedicated prompt that targets library creation rather than screen preparation.

**Skip condition:** If `component_library.status == "created"` in state file (crash recovery).

### Component Library Dispatch Prompt

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Handoff, Stage 2 — Component Library Creation.
You MUST NOT interact with users directly. Write all output to files.

Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/handoff-figma-preparer.md

## Task
Create the component library page/frame in Figma using Smart Componentization candidates.
This is a ONE-TIME operation before the per-screen preparation loop.

## Context
- Working directory: {WORKING_DIR}
- State file: {STATE_FILE_PATH}
- Screen inventory: {WORKING_DIR}/.screen-inventory.md
- TIER: {TIER}

## Componentization Candidates
{CANDIDATES_YAML}

## Instructions
1. Load `@figma-console-mastery/references/workflow-code-handoff.md` for TIER system and Smart Componentization Criteria
2. Create a "Components" page in the Figma file (or use existing if present)
3. For EACH candidate that passed all 3 Smart Componentization gates:
   a. Create the base component with semantic PascalCase name
   b. Create variant properties for identified behavioral states
      > **⚠️ `combineAsVariants` property completeness**: When using `combineAsVariants`, ALL
      > variant node properties MUST be set BEFORE calling combine. Properties set after the
      > combine call are silently dropped. Verify that every variant frame has its `name` set
      > in `Property=Value` format and all required properties are populated before combining.
   c. Record component node_id, variant props, and target screens
4. Update state file: component_library.status = "created"
5. Update state file: component_library.components[] with all created entries
""")
```

### Variable Sourcing — Component Library

| Variable | Source | Default |
|----------|--------|---------|
| `WORKING_DIR` | State file `directories.root` resolved to absolute path | Required |
| `STATE_FILE_PATH` | `{WORKING_DIR}/.handoff-state.local.md` | Required |
| `TIER` | State file `tier_decision.tier` | Required |
| `CANDIDATES_YAML` | From `.screen-inventory.md` `componentization_candidates` section | `"No candidates identified"` |

### Post-Dispatch State Update — Component Library

```
READ state file
IF agent wrote component_library.status == "created":
    LOG to Progress Log: "Component library created: {N} components"
    CONTINUE to screen loop
ELSE IF agent wrote component_library.status == "error":
    SET component_library.status = "skipped"
    LOG to Progress Log: "Component library creation failed — proceeding without library"
    DOWNGRADE TIER to 1 for all subsequent screen dispatches
    CONTINUE to screen loop
```

---

## Screen Loop

The orchestrator iterates over all screens from the Stage 1 inventory, dispatching
`handoff-figma-preparer` once per screen. The loop handles three outcomes per dispatch:
prepared, blocked, or error.

```
READ state file
READ screen inventory from design-handoff/.screen-inventory.md

SET screens_to_process = state.screens WHERE status IN ("pending", "preparing")
SET screens_completed = 0
SET screens_blocked = 0
SET manifest_entries = []

FOR EACH screen IN screens_to_process (ordered by inventory position):

    # 1. Update state to signal dispatch
    SET screen.status = "preparing"
    SET state.last_updated = NOW()
    WRITE state file

    # 2. Dispatch agent (see Per-Screen Dispatch Protocol below)
    DISPATCH handoff-figma-preparer with per-screen prompt

    # 3. Read agent's state updates
    READ state file
    READ screen entry for this screen

    # 4. Handle outcome
    IF screen.status == "prepared":
        screens_completed += 1
        COLLECT manifest entry from screen state (naming_fixes, tokens_bound, etc.)
        APPEND to manifest_entries
        LOG to Progress Log: "Screen '{screen.name}' prepared ({screen.steps_completed}/9 steps)"

    ELSE IF screen.status == "blocked":
        screens_blocked += 1
        LOG to Progress Log: "Screen '{screen.name}' BLOCKED: {screen.block_reason}"

    ELSE IF screen.status == "error":
        LOG to Progress Log: "Screen '{screen.name}' ERROR — will retry on next invocation"

    # 5. Update state with running totals
    SET state.last_updated = NOW()
    WRITE state file

# After loop
LOG to Progress Log: "Stage 2 screen loop complete: {screens_completed} prepared, {screens_blocked} blocked"

IF screens_completed == 0 AND screens_blocked > 0:
    HALT workflow — no screens available for downstream stages
    NOTIFY designer: "All screens blocked during preparation. Review blocked reasons in state file."
```

---

## Per-Screen Dispatch Protocol

Each screen dispatch sends a focused prompt with ONLY the context needed for that single
screen. Cross-screen state (component library, prior screen patterns) is passed as compact
summaries, not raw data.

### Per-Screen Dispatch Prompt

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for Design Handoff, Stage 2 — Per-Screen Preparation.
You MUST NOT interact with users directly. Write all output to files.

Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/handoff-figma-preparer.md

## Screen
- Name: {SCREEN_NAME}
- Node ID: {SCREEN_NODE_ID}
- Scenario: {SCENARIO}
- TIER: {TIER}

## Paths
- State file: {STATE_FILE_PATH}
- Working directory: {WORKING_DIR}
- Screenshots directory: {WORKING_DIR}/screenshots/

## Screen Inventory Data
{INVENTORY_DATA_YAML}

## Component Library (TIER 2/3)
{COMPONENT_LIBRARY_SUMMARY}

## Resume Context
{RESUME_CONTEXT}

## Visual Diff Config
- Threshold: {VISUAL_DIFF_THRESHOLD}
- Max fix attempts: {MAX_FIX_CYCLES}
""")
```

### Variable Sourcing — Per-Screen

| Variable | Source | Default |
|----------|--------|---------|
| `SCREEN_NAME` | `state.screens[i].name` | Required |
| `SCREEN_NODE_ID` | `state.screens[i].node_id` | Required |
| `SCENARIO` | `state.scenario` | Required |
| `TIER` | `state.tier_decision.tier` (may be downgraded to 1 if library creation failed) | Required |
| `STATE_FILE_PATH` | `{WORKING_DIR}/.handoff-state.local.md` | Required |
| `WORKING_DIR` | Resolved absolute path to `design-handoff/` | Required |
| `INVENTORY_DATA_YAML` | Screen's entry from `.screen-inventory.md` (readiness scores, group count, image fills) | Required |
| `COMPONENT_LIBRARY_SUMMARY` | If TIER >= 2: YAML list of `{name, figma_id, variant_props}` from state. If TIER 1: `"TIER 1 — no component library"` | Per TIER |
| `RESUME_CONTEXT` | If `completed_steps` is non-empty: `"Resume from step {N+1}. Completed: {steps}."` Else: `"Fresh start — no prior steps."` | `"Fresh start"` |
| `VISUAL_DIFF_THRESHOLD` | `judge.checkpoints.stage_2j.visual_diff_threshold` from config | `0.95` |
| `MAX_FIX_CYCLES` | `judge.checkpoints.stage_2j.max_fix_cycles` from config | `3` |

---

## Scenario A: Draft to Handoff

Full pipeline for raw design drafts that have never been prepared for handoff.

**Detection criteria (from Stage 1 readiness — thresholds from `figma_preparation.scenario_detection` config):**
- Average naming score < `scenario_detection.draft_naming_threshold`, OR
- Average token score < `scenario_detection.draft_token_threshold`, OR
- GROUP count > `readiness.group_warning_threshold` * screen_count

**Agent executes all 9 steps:**
1. Pre-preparation screenshot (baseline)
2. Clone frame to Handoff page (preserves original)
3. Naming audit and fix (generic names to semantic names)
4. GROUP to FRAME conversion (bottom-up)
5. Constraint and auto-layout migration
6. Token binding (hardcoded hex to design variables)
7. Component integration (TIER 2/3: replace raw frames with instances)
8. Image fill inventory (flag for export)
9. Post-preparation screenshot and visual diff

**Clone semantics:** The agent creates a copy on a dedicated "Handoff" page. The original
frame remains untouched. All subsequent stages reference the cloned node ID, not the
original. The state file records both `source_node_id` and `prepared_node_id`.

---

## Scenario B: In-Place Cleanup

For partially prepared files where the designer has done some cleanup but gaps remain.

**Detection criteria (thresholds from `figma_preparation.scenario_detection` and `readiness` config):**
- Average naming score >= `scenario_detection.draft_naming_threshold`, AND
- Average token score >= `scenario_detection.draft_token_threshold`, AND
- Readiness composite < `scenario_detection.clean_threshold`, AND
- GROUP count <= `readiness.group_warning_threshold`

**Agent executes all 9 steps but skips Step 2 (clone):**
- Works directly on the existing frame
- Pre-preparation screenshot captures current state as baseline
- Visual diff compares before vs after on the same frame

**Risk mitigation:** Since there is no clone, the agent's operation journal is the only
rollback reference. The orchestrator should warn the designer on first Scenario B screen:
"In-place cleanup modifies the original Figma frame. Ensure version history is enabled."

---

## Scenario C: Already Clean

For screens that already meet handoff readiness thresholds.

**Detection criteria (thresholds from `figma_preparation.scenario_detection` and `readiness` config):**
- Readiness composite score >= `scenario_detection.clean_threshold`, AND
- GROUP count == 0, AND
- Naming score >= `readiness.naming_compliance_threshold`, AND
- Token binding score >= `readiness.token_binding_threshold`

**Agent executes verification-only pathway:**
1. Step 1: Pre-preparation screenshot
2. Step 3: Naming audit (verification, expecting zero fixes)
3. Step 6: Token binding check (verification, expecting zero unbound)

**Escalation:** If verification discovers ANY issues (naming fixes > 0 OR unbound tokens > 0),
the agent escalates to Scenario B and executes the full 9-step checklist. This escalation
is recorded in the state file as `scenario_escalated: true`.

---

## Visual Diff Enforcement

Visual diff is mandatory after EACH screen, not after all screens. This prevents a cascade
of uncaught visual regressions from accumulating across the screen loop.

**Per-screen visual diff protocol:**

```
AFTER agent completes Step 9:
    READ screen entry from state file
    CHECK screen.visual_diff field

    IF visual_diff == "pass":
        screen.status = "prepared"
        CONTINUE to next screen

    IF visual_diff == "fail":
        CHECK screen.fix_attempts

        IF fix_attempts < max_fix_cycles (from config):
            RE-DISPATCH handoff-figma-preparer with fix instructions:
            """
            Visual diff FAILED for screen '{SCREEN_NAME}'.
            Fix attempt: {fix_attempts + 1} of {max_fix_cycles}.

            Issues identified by the agent:
            {VISUAL_DIFF_ISSUES}

            Resume from Step 9 after applying fixes.
            """

        IF fix_attempts >= max_fix_cycles:
            screen.status = "blocked"
            screen.block_reason = "Visual diff failed after {max_fix_cycles} fix attempts: {issues}"
            LOG to Progress Log: "HARD BLOCK: '{SCREEN_NAME}' visual diff unrecoverable"
```

**HARD BLOCK policy:** A screen with a failing visual diff is NEVER marked as "prepared."
It is marked "blocked" and excluded from downstream stages (gap analysis, supplement
generation). The designer is notified at Stage 2J with the full list of blocked screens
and their failure reasons.

---

## Post-Loop: Prototype Wiring (TIER 3 Only)

After all screens are prepared, TIER 3 workflows require a final dispatch to establish
cross-screen prototype connections in Figma.

**Skip condition:** TIER < 3, OR all screens blocked, OR `prototype_wiring.status == "completed"` in state.

```
IF TIER == 3 AND screens_completed > 1:
    DISPATCH handoff-figma-preparer with prompt:
    """
    You are a coordinator for Design Handoff, Stage 2 — Prototype Wiring.
    You MUST NOT interact with users directly. Write all output to files.

    Read and execute the instructions in @$CLAUDE_PLUGIN_ROOT/agents/handoff-figma-preparer.md
    Load figma-console-mastery prototype wiring recipes.

    ## Task
    Wire cross-screen prototype connections between all prepared screens.

    ## Prepared Screens
    {PREPARED_SCREENS_TABLE}

    ## Navigation Relationships (from Stage 1 inventory)
    {NAVIGATION_RELATIONSHIPS}

    ## Paths
    - State file: {STATE_FILE_PATH}
    - Working directory: {WORKING_DIR}
    """

    READ state file after dispatch
    UPDATE prototype_wiring status
```

---

## Post-Loop: Handoff Manifest Assembly

After all screen dispatches complete (and prototype wiring if TIER 3), the orchestrator
assembles the handoff manifest from per-screen data collected during the loop.

```
READ manifest template: $CLAUDE_PLUGIN_ROOT/templates/handoff-manifest-template.md
READ state file: all screen entries with status == "prepared"
READ component_library entries (if TIER 2/3)

POPULATE template:
    - Screen Inventory table: one row per prepared screen
    - Component-to-Code Mapping: from component_library.components[]
    - Token Mapping: aggregated from per-screen token binding data
    - Naming Exceptions: from per-screen operation journals (unmatched tokens)
    - Health Score: computed from readiness scores before/after preparation

WRITE to: {WORKING_DIR}/handoff-manifest.md
UPDATE state: artifacts.handoff_manifest = path

# Include blocked screens as a warning section at the bottom
IF screens_blocked > 0:
    APPEND "## Blocked Screens" section to manifest
    LIST each blocked screen with block_reason
```

**Manifest is incremental:** If the workflow crashes mid-loop and resumes, already-collected
manifest entries are preserved. The assembly step at the end is idempotent — it reads all
prepared screen data from the state file and regenerates the full manifest.

---

## Crash Recovery

Stage 2 is the most crash-prone stage due to the volume of MCP calls per screen. The
state file provides step-level recovery.

**Recovery procedure on re-invocation:**

```
READ state file
CHECK current_stage == "2"

# 1. Component library recovery (TIER 2/3)
IF tier >= 2 AND component_library.status == "pending":
    RE-DISPATCH component library creation (see Pre-Dispatch section)

# 2. Find resume point in screen loop
SET resume_screen = FIRST screen WHERE status IN ("pending", "preparing")

IF resume_screen.status == "preparing":
    # Agent was mid-screen when crash occurred
    READ resume_screen.completed_steps
    SET resume_step = resume_screen.current_step + 1
    LOG: "Resuming screen '{resume_screen.name}' from step {resume_step}"
    DISPATCH with RESUME_CONTEXT = "Resume from step {resume_step}. Completed: {steps}."

ELSE IF resume_screen.status == "pending":
    # Clean start for this screen
    DISPATCH with RESUME_CONTEXT = "Fresh start — no prior steps."

# 3. Continue loop from resume_screen onward
# (Already-prepared and already-blocked screens are skipped by the loop)
```

**State integrity check:** Before resuming, verify that all "prepared" screens have
corresponding screenshot files. If a screen is marked "prepared" but its after-screenshot
is missing, downgrade its status to "preparing" and re-dispatch.

---

## Transition to Stage 2J

After the screen loop completes and the manifest is assembled, the orchestrator checks
readiness for the judge checkpoint.

```
READ state file

# Minimum viable gate: at least one screen must be prepared
SET prepared_count = COUNT(screens WHERE status == "prepared")
SET blocked_count = COUNT(screens WHERE status == "blocked")

IF prepared_count == 0:
    HALT workflow
    NOTIFY designer: "No screens were successfully prepared. {blocked_count} screens blocked."
    SET current_stage = "blocked"
    EXIT

# Verify artifacts exist
VERIFY file exists: {WORKING_DIR}/handoff-manifest.md
VERIFY file exists: {WORKING_DIR}/screenshots/ contains at least {prepared_count} after-*.png files

IF any artifact missing:
    LOG warning: "Expected artifacts missing — judge may flag incomplete preparation"

# Advance stage and dispatch judge
SET current_stage = "2J"
SET state.last_updated = NOW()
WRITE state file

LOG to Progress Log: "Stage 2 complete. {prepared_count} prepared, {blocked_count} blocked. Dispatching Stage 2J judge."

# Dispatch per references/judge-protocol.md — Stage 2J rubric
```

The judge evaluates visual fidelity, naming compliance, token coverage, component
instantiation, and GROUP residue across ALL prepared screens. See `references/judge-protocol.md`
for the full Stage 2J rubric and verdict handling.
