---
name: design-handoff
description: >-
  This skill should be used when the user asks to "prepare Figma for handoff",
  "handoff designs to developers", "prepare designs for coding agents",
  "run design handoff", "create handoff supplement", "handoff",
  or wants to prepare a Figma file for downstream coding agent consumption.
  Produces handoff-manifest.md (structural inventory), HANDOFF-SUPPLEMENT.md
  (compact table-first document covering behaviors, transitions, and logic
  not expressible in Figma), and figma-screen-briefs/ (structured specs for
  missing screens, ready for a figma-console agent to execute).
  Figma file is the visual source of truth.
version: 1.1.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-console__figma_take_screenshot", "mcp__figma-console__figma_capture_screenshot", "mcp__figma-console__figma_audit_design_system", "mcp__figma-console__figma_get_selection", "mcp__figma-console__figma_search_components", "mcp__figma-console__figma_get_variables", "mcp__figma-console__figma_get_styles", "mcp__figma-console__figma_get_status", "mcp__figma-console__figma_get_file_for_plugin", "mcp__figma-console__figma_get_component_for_development"]
---

# Design Handoff Skill — Lean Orchestrator

Prepare Figma designs for coding agent consumption via two tracks:
- **Track A**: Prepare the Figma file itself (naming, structure, components, tokens)
- **Track B**: Generate a compact supplement covering ONLY what Figma cannot express

**Pipeline position:** `refinement (PRD.md) → [design-narration (UX-NARRATIVE.md)] → specification (spec.md) → design-handoff (manifest + supplement)`

**Core philosophy:** Figma is the visual source of truth. The supplement NEVER describes layouts, colors, spacing, or anything already visible in Figma. If there's a conflict, the Figma file wins.

**This workflow is resumable.** The state file persists progress. The workflow tracks designer decisions per-screen.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **Figma is source of truth**: The supplement NEVER duplicates Figma content. Zero layout descriptions, color specs, spacing values. Tables over prose — every word must earn its place.
2. **figma-console MCP required**: Verify `mcp__figma-console__figma_get_status` is available at startup. If unavailable, STOP and notify user.
3. **ONE screen per figma-preparer dispatch**: figma-console MCP is context-heavy. Never batch multiple screens in a single agent dispatch. Sequential processing with step-level state tracking.
4. **Visual diff is non-negotiable**: Every prepared screen MUST pass visual diff. HARD BLOCK on failure after 3 fix attempts — screen is marked `blocked`, workflow continues with remaining screens.
5. **Judge checkpoints are dedicated phases**: The judge is dispatched as a SEPARATE agent at each checkpoint boundary. Never inline quality evaluation.
6. **Coordinator never talks to users**: Agents write to files. Orchestrator mediates ALL user interaction via AskUserQuestion.
7. **Config reference**: All thresholds and parameters from `@$CLAUDE_PLUGIN_ROOT/config/handoff-config.yaml`.
8. **Screenshots ALWAYS via figma-console**: NEVER use `mcp__figma-desktop__get_screenshot`. Use `figma_take_screenshot` (figma-console) for baseline reads. Use `figma_capture_screenshot` (figma-console, Desktop Bridge) for any post-mutation visual diff — `figma_take_screenshot` returns a cloud-cached render and will appear unchanged after Plugin API mutations.
9. **Expand `$CLAUDE_PLUGIN_ROOT` before dispatch**: ALWAYS resolve `$CLAUDE_PLUGIN_ROOT` to an absolute path before passing to `Task()` dispatch prompts. Subagents may not inherit plugin-framework variable resolution.
10. **Visual diff screenshot validation**: After every visual diff, verify the screenshot was taken with `figma_capture_screenshot` (not `figma_take_screenshot`). A stale cached screenshot silently passes any diff.

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

> Visual stage flow: see `references/README.md` Stage Flow section.

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | User Pause? | Quick Mode |
|-------|------|------------|---------------|-------------|------------|
| 1 | Discovery & Inventory | **Inline** | `references/setup-protocol.md` | Yes (designer approval) | Reduced (skip TIER/scenario) |
| 2 | Figma Preparation | Agent (per-screen loop) | `references/figma-preparation.md` | No | **Skip** |
| 2J | Figma Prep Quality | Agent (judge) | `references/judge-protocol.md` | On BLOCK | **Skip** |
| 3 | Gap & Completeness | Agent | `references/gap-analysis.md` | No | Single screen, no manifest |
| 3J | Gap Completeness Check | Agent (judge) | `references/judge-protocol.md` | On NEEDS_FIX | Runs |
| 3.5 | Design Extension | Agent (conditional) | `references/design-extension.md` | Yes (per missing screen) | **Skip** |
| 3.5J | Extension Quality | Agent (judge) | `references/judge-protocol.md` | On NEEDS_FIX | **Skip** |
| 4 | Designer Dialog | **Orchestrator** | `references/designer-dialog.md` | Yes (per screen) | Runs |
| 5 | Output Assembly | **Inline** | `references/output-assembly.md` | No | Minimal (no manifest) |
| 5J | Supplement Quality | Agent (judge) | `references/judge-protocol.md` | On NEEDS_FIX | Runs |
| RETRO | Retrospective | Coordinator | `references/retrospective-protocol.md` | No | Runs |
| — | Completion | **Inline** | `references/state-schema.md` | No | Runs |

---

## Stage 1 — Discovery & Inventory (Inline)

Establish prerequisites, scan the Figma file, and get designer approval before any modifications.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/setup-protocol.md`

Execute directly (no coordinator dispatch). Reference file contains the full 10-step procedure.

**TIER heuristic:**

| TIER | Criteria | Component Library |
|------|----------|-------------------|
| 1 | 0 candidates pass 3-gate Smart Componentization test | No |
| 2 | >= 1 candidate passes all 3 gates | Yes |
| 3 | TIER 2 criteria met AND inter-frame prototype transitions detected | Yes + prototype wiring |

Exact thresholds in config: `tier.smart_componentization.*`

**Quick mode (`--quick`):** Skip TIER decision and scenario detection. Single screen selection instead of full page scan. Proceed directly to Stage 3.

---

## Stage 2 — Figma Preparation (Agent Loop)

Per-screen Figma file preparation via `handoff-figma-preparer` — ONE screen per dispatch, sequential loop with step-level crash recovery.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/figma-preparation.md`

**Quick mode:** Skip entirely. **Batch mode:** Runs normally.

---

## Stage 2J — Figma Prep Quality (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 2J rubric)

Evaluates visual fidelity, naming, tokens, components, GROUP residue. PASS → Stage 3. NEEDS_FIX → re-dispatch affected screens. BLOCK → mark blocked, continue.

**Quick mode:** Skip (Stage 2 was skipped).

---

## Stage 3 — Gap & Completeness Analysis (Agent)

Identify what Figma cannot express and what's missing from the design. Also generates Figma Screen Briefs (FSBs) for MUST_CREATE/SHOULD_CREATE missing items.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/gap-analysis.md`

Output: `design-handoff/gap-report.md`, `design-handoff/figma-screen-briefs/FSB-*.md`

**Quick mode:** Runs, but skips manifest prerequisite check (no manifest in Quick mode). Analyzes the single selected screen only.

---

## Stage 3J — Gap Completeness Check (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 3J rubric)

PASS → Stage 3.5 (if missing screens) or Stage 4. NEEDS_FIX → re-examine specific areas.

**Quick mode:** Runs normally on the single-screen gap report.

---

## Stage 3.5 — Design Extension (Conditional)

Create missing screens/states in Figma. Triggered only if Stage 3 detected MUST_CREATE or SHOULD_CREATE items.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/design-extension.md`

**Skip condition:** No missing screens, all classified as OPTIONAL, or Quick mode.

---

## Stage 3.5J — Extension Quality (Judge, Conditional)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 3.5J rubric)

**Skip condition:** Stage 3.5 was skipped.

---

## Stage 4 — Designer Dialog (Orchestrator-Mediated)

Focused Q&A about gaps — never about what's visible in Figma. Orchestrator mediates via AskUserQuestion.

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/designer-dialog.md`

**Batch mode (`--batch`):** Write gaps to `design-handoff/working/DIALOG-ANSWERS.md`, EXIT workflow. Designer answers offline. Resume on re-invocation.

---

## Stage 5 — Output Assembly (Inline)

Assemble `HANDOFF-SUPPLEMENT.md` and update `handoff-manifest.md` from Stages 1-4 output. Execute directly (no coordinator dispatch).

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/output-assembly.md`

**Quick mode:** Generates a minimal single-screen supplement without cross-screen patterns or manifest dependency.

---

## Stage 5J — Supplement Quality (Judge)

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-handoff/references/judge-protocol.md` (Stage 5J rubric)

PASS → execute Completion Protocol (per `references/state-schema.md`). NEEDS_FIX → regenerate affected sections.

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

## Context Management

Stage 2's per-screen loop generates significant context. To prevent late-loop quality degradation:
- Every 5 screens, the orchestrator emits a compact progress summary (screens completed, blocked, remaining)
- Per-screen dispatch/response details from prior iterations are discarded after checkpoint
- The figma-preparer agent receives only the current screen's context, not accumulated history
- See `references/figma-preparation.md` Context Management subsection for screen loop compaction rules

---

## Agent & Artifact Quick Reference

| Agent | Stage | Model | Purpose |
|-------|-------|-------|---------|
| `handoff-screen-scanner` | 1 | haiku | Frame discovery, structural analysis, readiness scoring |
| `handoff-figma-preparer` | 2, 3.5 | sonnet | Figma file preparation + design extension (loads figma-console-mastery) |
| `handoff-gap-analyzer` | 3 | sonnet | Gap detection + missing screen detection via figma-console |
| `handoff-judge` | 2J, 3J, 3.5J, 5J | opus / sonnet (per checkpoint) | LLM-as-judge at critical stage boundaries |
| `definition-retrospective-writer` | RETRO | sonnet | Retrospective narrative composition |

**Key output artifacts:** `HANDOFF-SUPPLEMENT.md` (final), `handoff-manifest.md` (structural inventory), `gap-report.md` (working), `figma-screen-briefs/FSB-*.md` (structured briefs for missing screens — give to figma-console agent to create them), `screenshots/` (visual diffs), `judge-verdicts/` (quality gate records), `retrospective.md` (workflow retrospective), `.handoff-report-card.local.md` (KPI metrics).

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
| `references/gap-category-examples.md` | Gap category calibration examples (6 tables) | Stage 3 agent dispatch only |
| `references/README.md` | File index, cross-references | Orientation |
| `templates/figma-screen-brief-template.md` | Template for FSB files generated in Stage 3 for missing screens | Stage 3 brief generation |
| `references/retrospective-protocol.md` | Retrospective protocol, KPI definitions | RETRO stage dispatch |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-10 above MUST be followed. Most common violations:
- Rule 1: Supplement contains layout/color/spacing descriptions that duplicate Figma
- Rule 3: Multiple screens batched in a single figma-preparer dispatch
- Rule 8/10: Wrong screenshot tool used for visual diff (`figma_take_screenshot` instead of `figma_capture_screenshot`)
