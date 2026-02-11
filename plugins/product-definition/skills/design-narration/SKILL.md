---
name: design-narration
description: >-
  This skill should be used when the user asks to "narrate Figma screens",
  "create a UX narrative", "describe mockups for coding agents",
  "generate interaction descriptions from Figma", "design narration",
  "create a UX-NARRATIVE document", "document screen interactions",
  "Figma to developer handoff", "UX documentation from Figma",
  "describe screens for implementation", or wants to transform Figma Desktop
  mockups into a detailed UX/interaction description document.
  Produces UX-NARRATIVE.md with per-screen purpose, elements, behaviors,
  states, navigation, and animations — filling the gaps that static
  mockups cannot communicate.
version: 1.6.1
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-desktop__get_metadata", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__pal__consensus", "mcp__pal__clink"]
---

# Design Narration Skill — Lean Orchestrator

Transform Figma Desktop mockups into a detailed UX/interaction narrative document (`UX-NARRATIVE.md`).

**Pipeline position:** `refinement (PRD.md) → design-narration (UX-NARRATIVE.md) → specification (spec.md)`

**This workflow is resumable.** Progress persisted in state file. User decisions tracked with full audit trail.

---

## Core Concepts

- **Self-critique loop**: Each screen narrative is scored on 5 dimensions (completeness, interaction clarity, state coverage, navigation context, ambiguity). Targeted follow-up questions address weak dimensions until the GOOD threshold is reached or the user signs off.
- **MPA validation**: Three specialist agents (implementability, UX completeness, edge cases) evaluate independently in parallel. A synthesis agent merges findings with randomized read order and source-dominance bias checks.
- **File-based handoff**: Batch mode writes per-screen results to disk rather than passing them through context, preventing overflow with large screen sets.
- **Coordinator isolation**: Stage coordinators never interact with users directly — the orchestrator mediates all prompts and answer routing, keeping user experience consistent.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **One screen at a time (interactive) or all screens per cycle (batch)**: In interactive mode, user selects each screen in Figma Desktop. In batch mode (`--batch` flag), all screens are processed per cycle from a Figma page. Never assume screen order — use Figma page position.
2. **Coordinator never talks to users**: Screen analyzer returns summary with questions; orchestrator mediates ALL user interaction via AskUserQuestion.
3. **Checkpoint after every screen**: Update state file with screen status, critique scores, and patterns BEFORE asking user to select next screen.
4. **No question limits**: Continue question rounds until critique score reaches GOOD threshold (per `self_critique.thresholds.good.min` in config) or user signs off.
5. **Mutable decisions with audit trail**: Prior decisions CAN be revised if later analysis warrants it — but EVERY revision requires explicit user confirmation. Never silently change a prior answer.
6. **Config reference**: All thresholds and parameters from `@$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`.
7. **Figma Desktop MCP required**: Verify `mcp__figma-desktop__get_metadata` is available at startup. If unavailable, STOP and notify user.

---

## User Input

```text
$ARGUMENTS
```

**Supported flags:**
- `--batch` — Batch mode: process all screens from a Figma page in consolidated Q&A cycles
- No flag — Interactive mode (default): one screen at a time, user-driven order

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): SETUP                                          |
|  Figma MCP check, optional context doc, state init/resume         |
|  Batch mode: parse screen descriptions, match Figma page frames   |
+---------------+-------------------+-------------------------------+
                |                   |
    (interactive)                 (--batch)
                |                   |
+---------------v-----------+  +----v----------------------------------+
|  Stage 2 (Loop):          |  |  Stage 2-BATCH (Cycle loop):          |
|  SCREEN PROCESSING        |  |  BATCH PROCESSING                     |
|                           |  |                                       |
|  Per screen:              |  |  2B.1: Analyze all screens             |
|  2A: Analyze + critique   |  |  2B.2: Consolidate questions           |
|  Q&A via AskUserQuestion  |  |  2B.3: Write BATCH-QUESTIONS doc       |
|  2B: Refine + re-critique |  |  2B.4: Pause for user answers          |
|  Sign-off → next screen   |  |  2B.5: Read answers on re-invocation   |
+---------------+-----------+  |  2B.6: Refine affected screens         |
                |              |  2B.7: Convergence check → loop/advance |
                |              +----+----------------------------------+
                |                   |
                +-------+-----------+
                        |
+-------------------------------v-----------------------------------+
|  Stage 3 (narration-coherence-auditor): COHERENCE CHECK            |
|  Cross-screen consistency, pattern extraction, mermaid diagrams    |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 4 (MPA + PAL): VALIDATION                                  |
|  3 specialist agents in parallel + PAL Consensus + synthesis       |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 5 (Inline): OUTPUT                                          |
|  Assemble UX-NARRATIVE.md from screens + patterns + validation     |
+-------------------------------------------------------------------+
```

---

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | User Pause? |
|-------|------|------------|---------------|-------------|
| 1 | Setup | **Inline** | `references/setup-protocol.md` | No |
| 2 | Screen Processing | Coordinator (loop) | `references/screen-processing.md` | Yes (per screen) |
| 2-BATCH | Batch Processing | Coordinator (cycle loop) | `references/batch-processing.md` | Yes (per cycle) |
| 3 | Coherence Check | Coordinator | `references/coherence-protocol.md` | Yes (inconsistencies) |
| 4 | Validation | Coordinator | `references/validation-protocol.md` | Yes (critical findings) |
| 5 | Output | **Inline** | `references/output-assembly.md` | No |

---

## Stage 1 — Inline Setup

Establish prerequisites and workspace before any analysis begins — a missing MCP connection or stale lock discovered mid-workflow would waste an entire analysis cycle.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/setup-protocol.md`

Execute directly (no coordinator dispatch). Steps:

1. **Config Validation** — Validate all required config keys exist with valid types
2. **Figma MCP Check** — Verify `mcp__figma-desktop__get_metadata` available; STOP if not
3. **Context Document** — Optionally collect PRD/brief; save to `design-narration/context-input.md`
4. **Lock Acquisition** — Acquire `design-narration/.narration-lock`; handle stale locks
5. **State Init or Resume** — Create new state (per `references/state-schema.md`) or resume with onboarding digest; run crash recovery if needed (per `references/recovery-protocol.md`)
6. **Workflow Mode & Screen Setup** — Detect `--batch` flag (default: interactive), then run mode-specific screen setup

---

## Stage 2 — Screen Processing

The core analysis loop — each screen is narrated, self-critiqued, and refined through Socratic Q&A until the narrative is concrete enough for a coding agent to implement without guessing.

**Mode guard:** Check `workflow_mode` in state file.

### If `workflow_mode == "interactive"` → Stage 2 (Interactive)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/screen-processing.md`

This stage loops for each screen:

1. **2A — Analysis dispatch**: Send node_id, screen name, context doc, prior patterns, Q&A history, and completed screens digest to `narration-screen-analyzer` agent
2. **Q&A mediation**: Read analyzer's summary → present questions via AskUserQuestion (batches per `maieutic_questions.max_per_batch` in config, "Let's discuss this" option on every question)
3. **2B — Refinement dispatch**: Send user answers back to analyzer for narrative update + re-critique
4. **Decision revision handling**: If analyzer flags contradictions with prior screens, present revisions to user
5. **Sign-off**: Present final score, user approves or flags for review
6. **Pattern accumulation**: Extract shared patterns from completed screen
7. **Next screen**: User selects next screen in Figma or indicates "no more screens"

**Loop exit**: User selects "No more screens — proceed to coherence check" → advance to Stage 3.

### If `workflow_mode == "batch"` → Stage 2-BATCH

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/batch-processing.md`

This stage processes all screens in batch cycles:

1. **2B.1 — Batch analysis**: Analyze all screens sequentially (pattern accumulation across screens)
2. **2B.2 — Consolidation**: Dispatch `narration-question-consolidator` to dedup, detect conflicts, and group
3. **2B.3 — Write questions**: Generate BATCH-QUESTIONS document from consolidated questions
4. **2B.4 — Pause**: Save state, notify user, EXIT workflow (user answers offline)
5. **2B.5 — Read answers** (on re-invocation): Parse user selections from BATCH-QUESTIONS file
6. **2B.6 — Refine**: Re-analyze affected screens with user answers
7. **2B.7 — Convergence check**: If no new questions → advance to Stage 3; otherwise loop to 2B.2

**Cycle exit**: All screens at GOOD threshold with zero pending questions, or user accepts current state → advance to Stage 3.

---

## Stage 3 — Coherence Check

Individual screen narratives may use different terms for the same concept or describe inconsistent behaviors for shared elements — this stage catches cross-screen contradictions before they reach validation.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/coherence-protocol.md`

Dispatch `narration-coherence-auditor` agent with ALL completed screen narratives. The auditor:
- Runs consistency checks per `coherence_checks` in config (naming, interaction, navigation, state parity, terminology)
- Extracts shared patterns
- Generates mermaid diagrams (navigation map, user journey flows, state machines)

Orchestrator presents each inconsistency to user for resolution. Updated screen files and patterns stored for Stage 5.

---

## Stage 4 — Validation

Three specialist perspectives catch blind spots that a single reviewer would miss; PAL consensus adds cross-model verification to reduce single-model bias.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/validation-protocol.md`

1. **MPA — 3 agents in parallel** (single Task message):
   - `narration-developer-implementability`: Can a coding agent build from this?
   - `narration-ux-completeness`: All journeys and states covered?
   - `narration-edge-case-auditor`: Unusual conditions handled?

2. **PAL Consensus** (multi-step workflow: analysis → model responses → synthesis; models with stance steering per `validation.pal_consensus.models` in config; graceful degradation if unavailable)

3. **Synthesis**: `narration-validation-synthesis` merges findings
   - CRITICAL findings → presented to user via AskUserQuestion
   - IMPORTANT findings → applied automatically, user notified
   - MINOR findings → applied silently

4. **Validation gate**: If recommendation = `ready` or all critical findings addressed → advance to Stage 5

---

## Stage 5 — Output Assembly

Consolidate all per-screen narratives, coherence fixes, and validation findings into a single deliverable document that downstream skills (specification, implementation) consume.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/output-assembly.md`

Assemble `UX-NARRATIVE.md` from per-screen narratives, coherence patterns, validation results, and decision audit trail. Use template `@$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md`.

---

## State Management

**State file:** `design-narration/.narration-state.local.md` | **Schema version:** 2

**Full schema and initialization template:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/state-schema.md`

Key principles:
- YAML frontmatter tracks `current_stage`, `screens_completed`, per-screen critique scores, accumulated patterns
- Decision audit trail is **append-only** — revisions create new entries with `revises` pointer + `revision_reason`
- Checkpoint state BEFORE any user interaction

---

## Agent & Artifact Quick Reference

| Agent | Stage | Model | Purpose |
|-------|-------|-------|---------|
| `narration-figma-discovery` | 1, 2 | haiku | Figma frame detection (interactive) and page discovery + matching (batch) |
| `narration-screen-analyzer` | 2, 2-BATCH | sonnet | Per-screen narrative, self-critique, questions |
| `narration-question-consolidator` | 2-BATCH | sonnet | Cross-screen question dedup, conflict detection, grouping |
| `narration-coherence-auditor` | 3 | sonnet | Cross-screen consistency, mermaid diagrams |
| `narration-developer-implementability` | 4 | sonnet | MPA: implementability audit |
| `narration-ux-completeness` | 4 | sonnet | MPA: journey/state coverage |
| `narration-edge-case-auditor` | 4 | sonnet | MPA: unusual conditions |
| `narration-validation-synthesis` | 4 | opus | Merge MPA + PAL, prioritize fixes |

**Key output artifacts:** `UX-NARRATIVE.md` (final), `screens/{nodeId}-{name}.md` (per-screen), `coherence-report.md`, `validation/synthesis.md`. For complete artifact listing, see each stage reference file's `artifacts_written` frontmatter.

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/setup-protocol.md` | Stage 1: Figma check, context, lock, state, screen selection | Stage 1 execution |
| `references/screen-processing.md` | Per-screen loop: dispatch, Q&A, refinement, sign-off | Stage 2 execution (interactive mode) |
| `references/batch-processing.md` | Batch cycle: analyze all, consolidate Qs, pause, refine, converge | Stage 2-BATCH execution (batch mode) |
| `references/coherence-protocol.md` | Cross-screen auditor dispatch, mermaid diagrams | Stage 3 execution |
| `references/validation-protocol.md` | MPA + PAL dispatch, synthesis, findings | Stage 4 execution |
| `references/critique-rubric.md` | 5-dimension self-critique rubric | Passed to screen analyzer |
| `references/output-assembly.md` | Stage 5: final document assembly steps | Stage 5 execution |
| `references/state-schema.md` | State file YAML schema, initialization template | State creation, crash recovery |
| `references/recovery-protocol.md` | Crash detection and recovery procedures | Skill re-invocation with incomplete state |
| `references/error-handling.md` | Error taxonomy, logging format, per-stage error tables | Any error path — shared by all stages |
| `references/checkpoint-protocol.md` | State update sequence, lock refresh, decision append | Every screen sign-off and stage transition |
| `references/implementability-rubric.md` | Shared 5-dimension implementability rubric | Stage 4 (consumed by agent + clink prompt) |
| `references/README.md` | File index, sizes, cross-references | Orientation |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-7 above MUST be followed. Key reminders:
- One screen at a time (interactive) or all screens per cycle (batch) — user drives the order
- Coordinator never talks to users — orchestrator mediates all interaction
- Checkpoint after every screen — state updated before next interaction
- No question limits — ask everything needed for completeness
- Decisions are mutable but EVERY revision requires explicit user confirmation
- Figma Desktop MCP is required — stop if unavailable
- All thresholds from config — never hardcode values
