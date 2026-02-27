---
name: figma-console-mastery
version: 1.1.0
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", or when developing skills/commands that use the figma-console MCP server.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design creation, manipulation, and quality assurance via figma-console MCP (Southleft, 60 tools) — Plugin API access, variable CRUD, debugging, screenshots. This skill is a **Figma API technique library** providing two flows: Design Session (creation/restructuring/audit) and Handoff QA (quality assurance for code handoff readiness). For Draft-to-Handoff and Code Handoff **orchestration**, use the `design-handoff` skill (product-definition plugin), which delegates Figma operations here.

## Overview

**figma-console** (Southleft, 60 tools) connects to Figma Desktop via the Desktop Bridge Plugin (WebSocket ports 9223-9232). It provides native tools for search, instantiation, screenshots, variable management, and `figma_execute` for Plugin API access.

**Core principles**:
1. **Native-tools-first** — use figma-console native tools for standard operations; `figma_execute` for everything else
2. **Discover before creating** — check existing components/tokens before building from scratch
3. **Converge, never regress** — log every operation to per-screen journal; never redo completed work (`convergence-protocol.md`)
4. **Validate visually** — 11-dimension quality audit with tiered depth Spot/Standard/Deep (`quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`)
5. **Subagent-first (Sonnet)** — all Figma modifications and audits delegated to Sonnet subagents; main context orchestrates only
6. **Ask user when in doubt** — every `AskUserQuestion` includes "Let's discuss this" option
7. **GROUP→FRAME before constraints** — GROUPs don't support `constraints`; assignment silently fails

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for all creation/mutation tools |

**Gate check**: Call `figma_get_status` before any operation. If `"not connected"`, load `references/gui-walkthroughs.md`.

## Quick Start

**Check & navigate**: `figma_get_status` (always first) → `figma_list_open_files` → `figma_navigate`

**Components**: `figma_search_components(query="Button")` → `figma_instantiate_component(componentKey, { variant, overrides })`

**Create elements**: `figma_execute` with async IIFE + outer `return` (see `recipes-foundation.md`)

**Variables**: `figma_setup_design_tokens` (atomic) | `figma_batch_create_variables` (up to 100) | `figma_batch_update_variables` (up to 100)

**Validate**: `figma_capture_screenshot` (live, post-mutation) | `figma_take_screenshot` (REST API, saved designs)

## Cross-Cutting Principles

**P1: figma-console Only** — This skill uses ONLY figma-console MCP. No Official Figma MCP, figma-desktop MCP, or figma-use MCP.

**P2: Subagent-First (Sonnet)** — Main context dispatches subagents for all Figma work; never executes `figma_execute` or quality audits inline. Exception: lightweight read-only operations in Phase 1 (Preflight).

**P3: Explicit User Interaction** — Every `AskUserQuestion` MUST include "Let's discuss this" option. Never force users into constrained choices.

## Flow 1 — Design Session

Unified flow for design creation, restructuring, targeted fixes, and audits. **Full procedures**: `references/flow-procedures.md`

### Mode Selection

| User Intent | Mode | Phase 2 | Phase 3 | Phase 4 |
|-------------|------|---------|---------|---------|
| "Create a design" / "Build a screen" | **Create** | Socratic (creation subset) | Full creation (subagent) | Spot + Standard |
| "Restructure this design" | **Restructure** | Socratic (all categories) | Path A/B (subagent) | Standard + metrics |
| "Check/fix this frame" | **Audit** | Selection scan | Targeted fixes (subagent) | Spot |
| "Create components" / "Setup tokens" | **Targeted** | Targeted discovery | Specific ops (subagent) | Spot |

**Ambiguous intent?** If user intent maps to multiple modes (e.g., "fix the colors" could be Audit or Restructure), ask the user to clarify scope: "Should I apply targeted fixes to specific elements (Audit), or systematically restructure the screen (Restructure)?" Always include "Let's discuss this" option.

### Phase 1 — Preflight & Discovery (inline)
Shared: `figma_get_status` → `figma_list_open_files` → `figma_navigate` → build/validate Session Index → load learnings → `figma_get_design_system_summary` → `figma_get_variables`. Mode-specific additions via subagent (Sonnet). See `flow-procedures.md` §1.1.

### Phase 2 — Analysis & Planning (Create/Restructure only)
Expanded Socratic Protocol with 11 categories (Cat. 0-10). **Question templates**: `references/socratic-protocol.md`. **Procedures**: `flow-procedures.md` §1.2. Do NOT proceed to Phase 3 until user approves checklist.

### Phase 3 — Execution (subagent)
Dispatch subagent with approved checklist + references. Logs to per-screen journal. See `flow-procedures.md` §1.3.

### Phase 4 — Validation (subagent)
Quality audit per tier (Spot/Standard/Deep). **Audit model**: `quality-dimensions.md` + `quality-audit-scripts.md` + `quality-procedures.md`. **Procedures**: `flow-procedures.md` §1.4. Save compound learnings at session end.

## Flow 2 — Handoff QA

Quality assurance for code handoff readiness. Does NOT generate manifest. **Full procedures**: `references/flow-procedures.md` §2.

| Phase | Focus | Who |
|-------|-------|-----|
| 1 — Screen Inventory | Baseline screenshots, screen catalog | Sonnet subagent |
| 2 — Quality Audit | 11-dimension Standard per screen | Sonnet subagent |
| 3 — Mod-Audit-Loop | Fix → re-audit → loop (max 3/screen) | Sonnet subagents |
| 4 — Handoff Readiness | Naming rules, token alignment, health check | Sonnet + user |

## Decision Matrix

| Gate | Question | Path | Primary Tool |
|------|----------|------|-------------|
| **G0: Exists?** | Standard component in Team Library? | INSTANTIATE | `figma_search_components` → `figma_instantiate_component` |
| **G1a: Native batch?** | Dedicated batch/read/audit tool? | NATIVE-BATCH | `figma_batch_create_variables`, `figma_capture_screenshot` |
| **G1b: Native modify?** | Single-property modification? | NATIVE-MODIFY | `figma_set_fills`, `figma_rename_node`, `figma_set_text` |
| **G2: Simple?** | 1-2 operations, no cross-node dependencies? | EXECUTE-SIMPLE | `figma_execute` with idempotency |
| **G3: Complex?** | 3+ same-type operations OR multi-step with cross-node dependencies (e.g., parent layout affects child constraints)? | EXECUTE-BATCH | `figma_execute` batch script |
| **G4: Not covered?** | None of the above? | ESCALATE | Ask user for clarification |

Evaluate G0→G1a→G1b→G2→G3→G4 in order. **Full decision tree**: `references/tool-playbook.md`

## Essential Rules (Top 8)

### MUST
1. **Wrap `figma_execute` in async IIFE with outer `return`** — the outer `return` is required for Desktop Bridge
2. **Use `figma.getNodeByIdAsync(id)`** — sync variant throws in `dynamic-page` mode
3. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})`
4. **Set `layoutMode` before layout properties** — padding/spacing require auto-layout active first
5. **Use `figma_capture_screenshot` for post-mutation validation** — `figma_take_screenshot` shows stale cached state
6. **Converge, never regress** — read per-screen journal before every mutation; skip if already logged
7. **Native-tools-first** — use dedicated tools before reaching for `figma_execute`
8. **Subagents inherit skill context** — load references per `convergence-protocol.md` Subagent Prompt Template

### AVOID
1. **Never mutate Figma arrays directly** — clone, modify, reassign
2. **Never return raw Figma nodes** — return plain data `{ id, name }`
3. **Never set constraints on GROUP nodes** — convert to FRAME first
4. **Never split page-switch and data-read across calls** — `setCurrentPageAsync` reverts in next IIFE
5. **Never skip quality audit at phase boundaries** — Standard/Deep catches issues screenshots miss

**Full rules (23 MUST + 13 AVOID)**: `references/essential-rules.md`

## Selective Reference Loading

**Reference map**: `references/README.md` lists all 24 reference files with sizes, triggers, and cross-references.

### Tier 1 — Always Load

```
# Foundation patterns — ALWAYS load when writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

# Convergence protocol — per-screen journal, anti-regression rules
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md
```

### Tier 2 — Load by Task

```
# Convergence execution — batch scripting, subagent delegation, snapshots, recovery
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-execution.md

# Tool selection — which of the 60 tools to call and when
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md

# Plugin API reference — writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md

# Design rules — MUST/SHOULD/AVOID, dimensions, typography, M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

# Component recipes — cards, buttons, inputs, toast, navbar, sidebar, form, data table, modal
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components.md

# Restructuring patterns — analysis, auto-layout conversion, componentization, naming
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md

# Code Handoff technique reference — TIER system, Smart Componentization, Handoff Manifest
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md

# Flow procedures — detailed phase steps for Flow 1 (4 modes) and Flow 2
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/flow-procedures.md

# Socratic Protocol — Cat. 0-10 question templates for Phase 2
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/socratic-protocol.md

# Essential Rules — full 23 MUST + 13 AVOID rules
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/essential-rules.md

# Session Index Protocol — L2 name→ID cache, build/validate/lookup patterns
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/session-index-protocol.md
```

### Tier 3 — Load by Need

```
# Advanced patterns — composition, variable binding, SVG import, rich text, full page assembly
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md

# Material Design 3 component recipes
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md

# Error catalog, anti-patterns, troubleshooting — debugging, recovery, hard constraints
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md

# GUI walkthrough instructions — setup, plugin activation, cache refresh
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/gui-walkthroughs.md

# Sequential Thinking integration — thought chain templates
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/st-integration.md

# Compound Learning Protocol — cross-session knowledge persistence
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/compound-learning.md

# Quality Dimensions — 11 dimensions, depth tiers, scoring rubrics, contradiction resolutions
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-dimensions.md

# Quality Audit Scripts — JS scripts A-I, positional diff, screen diff template
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-audit-scripts.md

# Quality Procedures — Spot/Standard/Deep execution, fix cycles, judge templates
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/quality-procedures.md

# Field Learnings — production strategies, componentization workflows, container patterns
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/field-learnings.md
```

**Context pressure note**: After context compaction, the minimum recovery set is: (1) `session-state.json`, (2) per-screen journal for current screen, (3) `recipes-foundation.md`. Re-load additional references only as needed for the current operation. See `convergence-execution.md` Section 4 for full compact recovery.

**Maximum concurrent load**: Load at most 4 reference files simultaneously beyond Tier 1. If additional references are needed, stop referencing files no longer actively needed for the current phase.

**Optional integrations**: Sequential Thinking (`st-integration.md`, needs `mcp__sequential-thinking__sequentialthinking`) and Compound Learning (`compound-learning.md`, `~/.figma-console-mastery/learnings.md`) are both optional. Load at Phase 1 if available.

## Troubleshooting (Top 5)

| Symptom | Quick Fix |
|---------|-----------|
| `figma_execute` returns empty/error | Wrap in async IIFE with outer `return` |
| Font loading error | `figma.loadFontAsync({family, style})` before `.characters` |
| Layout properties silently ignored | Set `layoutMode` BEFORE padding/spacing |
| Screenshot shows stale content | Use `figma_capture_screenshot` (see Essential Rules MUST #5) |
| Node IDs lost after compaction | Re-read per-screen journal + `session-state.json` |

**Full troubleshooting index (37 entries)**: `references/anti-patterns.md` § Quick Troubleshooting Index

## When NOT to Use This Skill

- **FigJam diagrams** — not supported by figma-console MCP
- **Figma REST API / OAuth setup** — outside scope (uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
- **Full Draft-to-Handoff orchestration** — use `design-handoff` skill (product-definition plugin), which delegates Figma operations back to this skill's references
- **Cross-file operations** — figma-console operates on the active file only; multi-file workflows require manual file switching via `figma_navigate`
- **IMAGE fill from external URL** — `figma_execute` cannot fetch external images; use `figma_get_component_image` for existing components or ask user to import images manually (see `anti-patterns.md` § Hard Constraints)

### Scope Boundary: figma-console-mastery vs design-handoff

| This skill (technique library) | design-handoff skill (orchestration) |
|------|------|
| QA audits, readiness checks, quality dimensions | Draft-to-Handoff workflow orchestration |
| Figma API patterns and recipes | Handoff Manifest generation |
| Convergence protocol, journals | Multi-screen pipeline coordination |
