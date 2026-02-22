---
name: design-handoff
description: >-
  This skill should be used when the user asks to "prepare Figma for handoff",
  "handoff designs to developers", "prepare designs for coding agents",
  "run design handoff", "create handoff supplement", "handoff",
  or wants to prepare a Figma file for downstream coding agent consumption.
  Produces handoff-manifest.md (structural inventory) and HANDOFF-SUPPLEMENT.md
  (compact table-first document covering ONLY behaviors, transitions, and logic
  not expressible in Figma). Figma file is the visual source of truth.
version: 1.0.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-desktop__get_metadata", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-console__figma_take_screenshot", "mcp__figma-console__figma_audit_design_system", "mcp__figma-console__figma_get_selection", "mcp__figma-console__figma_search_components", "mcp__figma-console__figma_get_variables", "mcp__figma-console__figma_get_styles", "mcp__figma-console__figma_get_status"]
---

# Design Handoff Skill — Lean Orchestrator

Prepare Figma designs for coding agent consumption via two tracks:
- **Track A**: Prepare the Figma file itself (naming, structure, components, tokens)
- **Track B**: Generate a compact supplement covering ONLY what Figma cannot express

**Pipeline position:** `refinement (PRD.md) → [design-narration (UX-NARRATIVE.md)] → specification (spec.md) → design-handoff (manifest + supplement)`

**Core philosophy:** Figma is the visual source of truth. The supplement NEVER describes layouts, colors, spacing, or anything already visible in Figma. If there's a conflict, the Figma file wins.

**This workflow is resumable.** Progress persisted in state file. Designer decisions tracked per-screen.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **Figma is source of truth**: The supplement NEVER duplicates Figma content. Zero layout descriptions, color specs, spacing values. Tables over prose — every word must earn its place.
2. **Both MCP servers required**: Verify `mcp__figma-desktop__get_metadata` AND `mcp__figma-console__figma_take_screenshot` are available at startup. If either is unavailable, STOP and notify user.
3. **ONE screen per figma-preparer dispatch**: figma-console MCP is context-heavy. Never batch multiple screens in a single agent dispatch. Sequential processing with step-level state tracking.
4. **Visual diff is non-negotiable**: Every prepared screen MUST pass visual diff. HARD BLOCK on failure after 3 fix attempts — screen is marked `blocked`, workflow continues with remaining screens.
5. **Judge checkpoints are dedicated phases**: The judge is dispatched as a SEPARATE agent at each checkpoint boundary. Never inline quality evaluation.
6. **Coordinator never talks to users**: Agents write to files. Orchestrator mediates ALL user interaction via AskUserQuestion.
7. **Config reference**: All thresholds and parameters from `@$CLAUDE_PLUGIN_ROOT/config/handoff-config.yaml`.

---

## User Input

```text
$ARGUMENTS
```

**Supported flags:**
- `--quick` — Quick mode: single screen, no Figma preparation, gap analysis + dialog only
- `--batch` — Batch mode: file-based Q&A, no interactive dialog
- No flag — Guided mode (default): full preparation + interactive per-screen dialog

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): DISCOVERY & INVENTORY                          |
|  Figma MCP check, page scan, readiness audit, TIER, scenario      |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 2 (handoff-figma-preparer): FIGMA PREPARATION              |
|  Component library (TIER 2/3), per-screen pipeline, visual diff   |
|  ONE screen per dispatch. Mandatory 9-step checklist.             |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 2J (handoff-judge): FIGMA PREP QUALITY                     |
|  Visual fidelity, naming, tokens, components, GROUP residue       |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 3 (handoff-gap-analyzer): GAP & COMPLETENESS               |
|  Per-screen gap detection (dual MCP). Missing screen detection.   |
|  Cross-screen patterns.                                           |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 3J (handoff-judge): GAP COMPLETENESS CHECK                 |
|  Thoroughness, navigation dead-ends, classification accuracy      |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 3.5 (handoff-figma-preparer, CONDITIONAL): DESIGN EXTENSION|
|  Create missing screens/states in Figma. Designer chooses per item.|
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 3.5J (handoff-judge): EXTENSION QUALITY                    |
|  Visual consistency, component usage, layout, content             |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 4 (Orchestrator): DESIGNER DIALOG                          |
|  Per-screen Q&A about gaps ONLY. Cross-screen confirmation.       |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 5 (Inline): OUTPUT ASSEMBLY                                |
|  HANDOFF-SUPPLEMENT.md + handoff-manifest.md update               |
+---------------+---------------------------------------------------+
                |
+---------------v---------------------------------------------------+
|  Stage 5J (handoff-judge): SUPPLEMENT QUALITY                     |
|  No Figma duplication, completeness, formatting, conciseness      |
+-------------------------------------------------------------------+
```

---

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | User Pause? |
|-------|------|------------|---------------|-------------|
| 1 | Discovery & Inventory | **Inline** | `references/setup-protocol.md` | Yes (designer approval) |
| 2 | Figma Preparation | Agent (per-screen loop) | `references/figma-preparation.md` | No |
| 2J | Figma Prep Quality | Agent (judge) | `references/judge-protocol.md` | On BLOCK |
| 3 | Gap & Completeness | Agent | `references/gap-analysis.md` | No |
| 3J | Gap Completeness Check | Agent (judge) | `references/judge-protocol.md` | On NEEDS_DEEPER |
| 3.5 | Design Extension | Agent (conditional) | `references/design-extension.md` | Yes (per missing screen) |
| 3.5J | Extension Quality | Agent (judge) | `references/judge-protocol.md` | On NEEDS_FIX |
| 4 | Designer Dialog | **Orchestrator** | `references/designer-dialog.md` | Yes (per screen) |
| 5 | Output Assembly | **Inline** | `references/output-assembly.md` | No |
| 5J | Supplement Quality | Agent (judge) | `references/judge-protocol.md` | On NEEDS_REVISION |

---

## Stage 1 — Discovery & Inventory (Inline)

Establish prerequisites, scan the Figma file, and get designer approval before any modifications.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/setup-protocol.md`

Execute directly (no coordinator dispatch). Steps:

1. **Config Validation** — Validate all required config keys exist
2. **Figma MCP Check** — Verify BOTH `figma-desktop` AND `figma-console` MCP servers; STOP if either unavailable
3. **Lock Acquisition** — Acquire `design-handoff/.handoff-lock`; handle stale locks
4. **State Init or Resume** — Create new state (per `references/state-schema.md`) or resume with digest
5. **Page Selection** — Designer selects Figma page
6. **Screen Scanner Dispatch** — Dispatch `handoff-screen-scanner` agent (haiku) for frame discovery + structural analysis
7. **TIER Decision** — Smart Componentization analysis, recommend TIER 1/2/3
8. **Scenario Detection** — Classify: (A) Draft→Handoff, (B) In-place cleanup, (C) Already clean
9. **Designer Approval** — Present inventory table, TIER recommendation, scenario via AskUserQuestion

**Quick mode (`--quick`):** Skip steps 7-8. Single screen selection instead of full page scan. Proceed directly to Stage 3.

---

## Stage 2 — Figma Preparation (Agent Loop)

The core file preparation — each screen is transformed through a mandatory 9-step checklist.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/figma-preparation.md`

**CRITICAL: ONE screen per `handoff-figma-preparer` dispatch.** The orchestrator runs a sequential loop:

1. IF TIER 2/3: dispatch `handoff-figma-preparer` for component library creation (one-time)
2. FOR EACH screen in inventory:
   - IF state shows screen completed → SKIP
   - Dispatch `handoff-figma-preparer` for THIS SINGLE SCREEN
   - Read completion summary from state file
   - IF visual diff failed → mark `blocked`, continue to next screen
3. Post-loop: Assemble `handoff-manifest.md` from per-screen data

**Mode guard:** Skip entirely in Quick mode (`--quick`).

---

## Stage 2J — Figma Prep Quality (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 2J rubric)

Dispatch `handoff-judge` (opus) with per-screen screenshots, manifest, and audit data. Evaluates: visual fidelity, naming compliance, token binding, component instantiation, GROUP residue.

PASS → Stage 3. NEEDS_FIX → re-dispatch affected screens. BLOCK → mark screens blocked, continue.

---

## Stage 3 — Gap & Completeness Analysis (Agent)

Identify what Figma cannot express and what's missing from the design.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/gap-analysis.md`

Dispatch `handoff-gap-analyzer` (sonnet) with ALL prepared screens. The analyzer uses BOTH MCP servers:
- **Part A**: Per-screen gap detection (behaviors, states, animations, data, logic, edge cases)
- **Part B**: Missing screen/state detection (navigation dead-ends, implied states)
- **Part C**: Cross-screen pattern extraction

Output: `design-handoff/gap-report.md`

---

## Stage 3J — Gap Completeness Check (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 3J rubric)

Evaluates gap detection thoroughness, navigation dead-end coverage, classification accuracy.

PASS → Stage 3.5 (if missing screens) or Stage 4. NEEDS_DEEPER → re-examine specific areas.

---

## Stage 3.5 — Design Extension (Conditional)

Create missing screens/states in Figma before generating the supplement.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/design-extension.md`

**Triggered only if** Stage 3 detected MUST_CREATE or SHOULD_CREATE missing items.

1. Present missing items to designer with 4 options each (Create / Designer creates / Supplement only / Skip)
2. For "Create" items: dispatch `handoff-figma-preparer` in extend mode, one per screen
3. For "Designer creates" items: save state, EXIT workflow (resume on re-invocation)
4. Update screen inventory and gap report

**Skip condition:** No missing screens, or all classified as OPTIONAL.

---

## Stage 3.5J — Extension Quality (Judge, Conditional)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 3.5J rubric)

Evaluates newly created screens: visual consistency, component usage, layout coherence, content completeness.

---

## Stage 4 — Designer Dialog (Orchestrator-Mediated)

Focused Q&A about gaps only — never about what's visible in Figma.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/designer-dialog.md`

Orchestrator runs this stage directly via AskUserQuestion:

1. Present gap report summary
2. Per-screen loop (ordered by most gaps first): present gaps as numbered questions in batches of `designer_dialog.questions_per_batch`
3. Cross-screen pattern confirmation
4. Exit: all screens done, or designer accepts remaining as-is

**Batch mode (`--batch`):** Write gaps to file, EXIT workflow. Designer answers offline. Resume on re-invocation.

---

## Stage 5 — Output Assembly (Inline)

Consolidate all collected information into final deliverables.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/output-assembly.md`

Execute directly (no coordinator dispatch):

1. Load templates from `$CLAUDE_PLUGIN_ROOT/templates/handoff-*.md`
2. Assemble cross-screen patterns section (shared behaviors, mermaid navigation, common transitions)
3. Assemble per-screen sections (template for screens with gaps, one-liner for no-gap screens)
4. Assemble missing screens section (supplement-only items from Stage 3.5)
5. Write `HANDOFF-SUPPLEMENT.md`
6. Update `handoff-manifest.md` with routes, annotations, new screens
7. Present completion summary to designer

---

## Stage 5J — Supplement Quality (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 5J rubric)

Evaluates: no Figma duplication, gap coverage completeness, naming consistency, table formatting, conciseness.

PASS → workflow complete. NEEDS_REVISION → regenerate affected sections.

---

## State Management

**State file:** `design-handoff/.handoff-state.local.md` | **Schema version:** 1

**Full schema and initialization template:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/state-schema.md`

Key principles:
- YAML frontmatter tracks `current_stage`, per-screen status, judge verdicts, artifacts
- Per-screen step-level progress for crash recovery (Stage 2)
- Designer decisions in `missing_screens` are final once set
- Checkpoint state BEFORE any user interaction or stage transition

---

## Agent & Artifact Quick Reference

| Agent | Stage | Model | Purpose |
|-------|-------|-------|---------|
| `handoff-screen-scanner` | 1 | haiku | Frame discovery, structural analysis, readiness scoring |
| `handoff-figma-preparer` | 2, 3.5 | sonnet | Figma file preparation + design extension (loads figma-console-mastery) |
| `handoff-gap-analyzer` | 3 | sonnet | Gap detection + missing screen detection, dual MCP |
| `handoff-judge` | 2J, 3J, 3.5J, 5J | opus | LLM-as-judge at critical stage boundaries |

**Key output artifacts:** `HANDOFF-SUPPLEMENT.md` (final), `handoff-manifest.md` (structural inventory), `gap-report.md` (working), `screenshots/` (visual diffs), `judge-verdicts/` (quality gate records).

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/setup-protocol.md` | Stage 1: discovery, inventory, TIER, scenario | Stage 1 execution |
| `references/figma-preparation.md` | Stage 2: per-screen dispatch loop, visual diff | Stage 2 execution |
| `references/gap-analysis.md` | Stage 3: gap detection, missing screens, patterns | Stage 3 dispatch |
| `references/design-extension.md` | Stage 3.5: missing screen creation, designer options | Stage 3.5 (conditional) |
| `references/designer-dialog.md` | Stage 4: focused Q&A, cross-screen confirmation | Stage 4 execution |
| `references/output-assembly.md` | Stage 5: supplement + manifest generation | Stage 5 execution |
| `references/judge-protocol.md` | Shared judge dispatch, 4 checkpoint rubrics | Every judge checkpoint |
| `references/state-schema.md` | YAML schema, init template, resume protocol | State creation, crash recovery |
| `references/README.md` | File index, cross-references | Orientation |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-7 above MUST be followed. Key reminders:
- Figma is source of truth — supplement NEVER duplicates Figma content
- Both MCP servers required — stop if either unavailable
- ONE screen per figma-preparer dispatch — sequential with step-level state
- Visual diff is non-negotiable — HARD BLOCK on failure after max retries
- Judge checkpoints are dedicated phases — never inline
- Coordinator never talks to users — orchestrator mediates all interaction
- All thresholds from config — never hardcode values
