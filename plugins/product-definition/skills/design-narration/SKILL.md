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
version: 1.3.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-desktop__get_metadata", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__pal__consensus"]
---

# Design Narration Skill — Lean Orchestrator

Transform Figma Desktop mockups into a detailed UX/interaction narrative document (`UX-NARRATIVE.md`).

**Pipeline position:** `refinement (PRD.md) → design-narration (UX-NARRATIVE.md) → specification (spec.md)`

**This workflow is resumable.** Progress persisted in state file. User decisions tracked with full audit trail.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **One screen at a time**: User selects each screen in Figma Desktop. Never batch-process screens or assume order.
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

Consider user input before proceeding (if not empty).

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): SETUP                                          |
|  Figma MCP check, optional context doc, state init/resume         |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 2 (Loop — narration-screen-analyzer):                      |
|  SCREEN PROCESSING                                                 |
|                                                                    |
|  REPEAT until user says "no more screens":                         |
|    2A: Analyzer captures + describes + critiques + questions       |
|    Orchestrator: mediate questions via AskUserQuestion              |
|    2B: Analyzer refines with user answers, re-critiques            |
|    Handle decision revisions if flagged                            |
|    Sign-off → user picks next screen                               |
+-------------------------------+-----------------------------------+
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
| 3 | Coherence Check | Coordinator | `references/coherence-protocol.md` | Yes (inconsistencies) |
| 4 | Validation | Coordinator | `references/validation-protocol.md` | Yes (critical findings) |
| 5 | Output | **Inline** | `references/output-assembly.md` | No |

---

## Stage 1 — Inline Setup

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/setup-protocol.md`

Execute directly (no coordinator dispatch). Steps:

1. **Figma MCP Check** — Verify `mcp__figma-desktop__get_metadata` available; STOP if not
2. **Context Document** — Optionally collect PRD/brief; save to `design-narration/context-input.md`
3. **Lock Acquisition** — Acquire `design-narration/.narration-lock`; handle stale locks
4. **State Init or Resume** — Create new state (per `references/state-schema.md`) or resume with onboarding digest; run crash recovery if needed (per `references/recovery-protocol.md`)
5. **First Screen Selection** — User selects screen in Figma; extract node_id via `get_metadata`

---

## Stage 2 — Screen Processing Loop

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

---

## Stage 3 — Coherence Check

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/coherence-protocol.md`

Dispatch `narration-coherence-auditor` agent with ALL completed screen narratives. The auditor:
- Runs consistency checks per `coherence_checks` in config (naming, interaction, navigation, state parity, terminology)
- Extracts shared patterns
- Generates mermaid diagrams (navigation map, user journey flows, state machines)

Orchestrator presents each inconsistency to user for resolution. Updated screen files and patterns stored for Stage 5.

---

## Stage 4 — Validation

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/validation-protocol.md`

1. **MPA — 3 agents in parallel** (single Task message):
   - `narration-developer-implementability`: Can a coding agent build from this?
   - `narration-ux-completeness`: All journeys and states covered?
   - `narration-edge-case-auditor`: Unusual conditions handled?

2. **PAL Consensus** (models per `validation.pal_consensus.models` in config, graceful degradation if unavailable)

3. **Synthesis**: `narration-validation-synthesis` merges findings
   - CRITICAL findings → presented to user via AskUserQuestion
   - IMPORTANT findings → applied automatically, user notified
   - MINOR findings → applied silently

4. **Validation gate**: If recommendation = `ready` or all critical findings addressed → advance to Stage 5

---

## Stage 5 — Output Assembly

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/output-assembly.md`

Assemble `UX-NARRATIVE.md` from per-screen narratives, coherence patterns, validation results, and decision audit trail. Use template `@$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md`.

---

## State Management

**State file:** `design-narration/.narration-state.local.md` | **Schema version:** 1

**Full schema and initialization template:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/state-schema.md`

Key principles:
- YAML frontmatter tracks `current_stage`, `screens_completed`, per-screen critique scores, accumulated patterns
- Decision audit trail is **append-only** — revisions create new entries with `revises` pointer + `revision_reason`
- Checkpoint state BEFORE any user interaction

---

## Agent & Artifact Quick Reference

| Agent | Stage | Model | Purpose |
|-------|-------|-------|---------|
| `narration-screen-analyzer` | 2 | sonnet | Per-screen narrative, self-critique, questions |
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
| `references/setup-protocol.md` | Stage 1: Figma check, context, lock, state, first screen | Stage 1 execution |
| `references/screen-processing.md` | Per-screen loop: dispatch, Q&A, refinement, sign-off | Stage 2 execution |
| `references/coherence-protocol.md` | Cross-screen auditor dispatch, mermaid diagrams | Stage 3 execution |
| `references/validation-protocol.md` | MPA + PAL dispatch, synthesis, findings | Stage 4 execution |
| `references/critique-rubric.md` | 5-dimension self-critique rubric | Passed to screen analyzer |
| `references/output-assembly.md` | Stage 5: final document assembly steps | Stage 5 execution |
| `references/state-schema.md` | State file YAML schema, initialization template | State creation, crash recovery |
| `references/recovery-protocol.md` | Crash detection and recovery procedures | Skill re-invocation with incomplete state |
| `references/error-handling.md` | Error taxonomy, logging format, per-stage error tables | Any error path — shared by all stages |
| `references/checkpoint-protocol.md` | State update sequence, lock refresh, decision append | Every screen sign-off and stage transition |
| `references/README.md` | File index, sizes, cross-references | Orientation |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-7 above MUST be followed. Key reminders:
- One screen at a time — user drives the order
- Coordinator never talks to users — orchestrator mediates all interaction
- Checkpoint after every screen — state updated before next screen selection
- No question limits — ask everything needed for completeness
- Decisions are mutable but EVERY revision requires explicit user confirmation
- Figma Desktop MCP is required — stop if unavailable
- All thresholds from config — never hardcode values
