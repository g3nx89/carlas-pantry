---
name: figma-console-mastery
version: 1.1.0
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", or when developing skills/commands that use the Figma Console MCP server. Provides 2 flows (Design Session and Handoff QA), subagent-first orchestration, quality model, and selective reference loading. For Draft-to-Handoff and Code Handoff preparation workflows, use the design-handoff skill (product-definition plugin) which delegates Figma operations to this skill's references.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design creation, manipulation, and quality assurance via figma-console MCP (Southleft, 60 tools) — Plugin API access, variable CRUD, debugging, screenshots. This skill is a **Figma API technique library**. For Draft-to-Handoff and Code Handoff orchestration, use the `design-handoff` skill (product-definition plugin), which delegates Figma operations here.

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

### Phase 1 — Preflight & Discovery (inline)
Shared: `figma_get_status` → `figma_list_open_files` → `figma_navigate` → build/validate Session Index → load learnings → `figma_get_design_system_summary` → `figma_get_variables`. Mode-specific additions via Sonnet subagent. See `flow-procedures.md` §1.1.

### Phase 2 — Analysis & Planning (Create/Restructure only)
Expanded Socratic Protocol with 11 categories (Cat. 0-10). **Question templates**: `references/socratic-protocol.md`. **Procedures**: `flow-procedures.md` §1.2. Do NOT proceed to Phase 3 until user approves checklist.

### Phase 3 — Execution (Sonnet subagent)
Dispatch subagent with approved checklist + references. Logs to per-screen journal. See `flow-procedures.md` §1.3.

### Phase 4 — Validation (Sonnet subagent)
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
| **G2: Simple?** | Single-node create, complex fill, layout? | EXECUTE-SIMPLE | `figma_execute` with idempotency |
| **G3: Complex?** | Multi-step, batch 3+ same-type? | EXECUTE-BATCH | `figma_execute` batch script |

Evaluate G0→G1a→G1b→G2→G3 in order. **Full decision tree**: `references/tool-playbook.md`

## Quick Reference — Core Tools

| Tool | Purpose |
|------|---------|
| `figma_get_status` | Verify connection (always first) |
| `figma_search_components` | Find library components before creating |
| `figma_instantiate_component` | Place component with variant properties |
| `figma_execute` | Run Plugin API code (creation, modification, complex logic) |
| `figma_capture_screenshot` | Visual validation after Plugin API mutations |
| `figma_take_screenshot` | Validation of already-saved designs (REST API) |
| `figma_setup_design_tokens` | Create token system atomically |
| `figma_batch_create_variables` | Bulk variable creation (up to 100) |
| `figma_batch_update_variables` | Bulk variable updates (up to 100) |
| `figma_audit_design_system` | 0-100 health scorecard |

**Full tool reference**: `references/tool-playbook.md` (60 tools)

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

**Full rules (23 MUST + 14 AVOID)**: `references/essential-rules.md`

## Selective Reference Loading

```
# Tool selection — which of the 60 tools to call and when
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md

# Plugin API reference — writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md

# Design rules — MUST/SHOULD/AVOID, dimensions, typography, M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

# Foundation patterns — ALWAYS load when writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

# Component recipes — cards, buttons, inputs, toast, navbar, sidebar, form, data table, modal
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components.md

# Advanced patterns — composition, variable binding, SVG import, rich text, full page assembly
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md

# Restructuring patterns — analysis, auto-layout conversion, componentization, naming
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md

# Material Design 3 component recipes
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md

# Error catalog, anti-patterns, troubleshooting — debugging, recovery, hard constraints
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md

# GUI walkthrough instructions — setup, plugin activation, cache refresh
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/gui-walkthroughs.md

# Sequential Thinking integration — thought chain templates
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/st-integration.md

# Code Handoff technique reference — TIER system, Smart Componentization, Handoff Manifest
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md

# Convergence protocol — per-screen journal, anti-regression, batch scripting, subagent delegation
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

# Session Index Protocol — L2 name→ID cache, build/validate/lookup patterns
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/session-index-protocol.md

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

# Flow procedures — detailed phase steps for Flow 1 (4 modes) and Flow 2
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/flow-procedures.md

# Socratic Protocol — Cat. 0-10 question templates for Phase 2
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/socratic-protocol.md

# Essential Rules — full 23 MUST + 14 AVOID rules
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/essential-rules.md
```

### Loading Tiers

**Tier 1 — Always:** `recipes-foundation.md`, `convergence-protocol.md`

**Tier 2 — By task:** `recipes-components.md` | `recipes-restructuring.md` | `tool-playbook.md` | `plugin-api.md` | `design-rules.md` | `workflow-code-handoff.md` | `flow-procedures.md` | `socratic-protocol.md` | `essential-rules.md` | `session-index-protocol.md`

**Tier 3 — By need:** `recipes-advanced.md` | `recipes-m3.md` | `anti-patterns.md` | `gui-walkthroughs.md` | `st-integration.md` | `compound-learning.md` | `quality-dimensions.md` | `quality-audit-scripts.md` | `quality-procedures.md` | `field-learnings.md`

## Sequential Thinking Integration (Optional)

> **Prerequisite**: `mcp__sequential-thinking__sequentialthinking` must be available. ST is **never required**.

| Trigger | ST Pattern |
|---------|------------|
| Path A/B decision (ambiguous findings) | Fork-Join |
| Screenshot-fix cycle (unexpected misalignment) | TAO Loop + Revision |
| Multi-step diagnostic (3+ category deviations) | Hypothesis Tracking |

**Thought chain templates**: `references/st-integration.md`

## Compound Learning (Optional)

> **Location**: `~/.figma-console-mastery/learnings.md` (cross-project). **Full spec**: `references/compound-learning.md`

Load at Phase 1 (if exists). Save at Phase 4 (0-3 entries, triggers T1-T6). Never save trivial or already-documented insights.

## Troubleshooting (Top 5)

| Symptom | Quick Fix |
|---------|-----------|
| `figma_execute` returns empty/error | Wrap in async IIFE with outer `return` |
| Font loading error | `figma.loadFontAsync({family, style})` before `.characters` |
| Layout properties silently ignored | Set `layoutMode` BEFORE padding/spacing |
| `figma_take_screenshot` shows stale content | Use `figma_capture_screenshot` (Desktop Bridge, live state) |
| Node IDs lost after compaction | Re-read per-screen journal + `session-state.json` |

**Full troubleshooting index (37 entries)**: `references/anti-patterns.md` § Quick Troubleshooting Index

## When NOT to Use This Skill

- **FigJam diagrams** — not supported by figma-console MCP
- **Figma REST API / OAuth setup** — outside scope (uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
- **Full Draft-to-Handoff orchestration** — use `design-handoff` skill (product-definition plugin)
