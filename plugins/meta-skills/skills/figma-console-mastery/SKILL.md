---
name: figma-console-mastery
version: 0.9.0
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", or when developing skills/commands that use the Figma Console MCP server. Provides tool selection, Plugin API patterns, design rules, and selective reference loading. For Draft-to-Handoff and Code Handoff preparation workflows, use the design-handoff skill (product-definition plugin) which delegates Figma operations to this skill's references.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design creation and manipulation via figma-console MCP (Southleft, 56+ tools) — Plugin API access, variable CRUD, debugging, screenshots. This skill is a **Figma API technique library**. For Draft-to-Handoff and Code Handoff orchestration, use the `design-handoff` skill (product-definition plugin), which delegates Figma operations here.

## Overview

**figma-console** (Southleft, 56+ tools) connects to Figma Desktop via the Desktop Bridge Plugin (WebSocket ports 9223-9232). It provides native tools for search, instantiation, screenshots, variable management, and `figma_execute` for Plugin API access.

**Core principles**:
1. **Native-tools-first** — use figma-console native tools (`figma_search_components`, `figma_instantiate_component`, `figma_batch_create_variables`, etc.) for standard operations; use `figma_execute` for everything else
2. **Discover before creating** — check existing components/tokens before building from scratch
3. **Converge, never regress** — log every operation to the journal; check journal before every mutation; never redo completed work (see `convergence-protocol.md`)
4. **Persist aggressively** — write to operation journal after EVERY operation, snapshot after each batch; assume context compaction can happen at any time
5. **Validate visually** — use `figma_capture_screenshot` (Desktop Bridge, live state) for post-Plugin-API validation; use `figma_take_screenshot` (REST API) only for already-saved designs. Max 3 fix cycles per screen
6. **Subagents inherit skill context** — all subagents dispatched for Figma workflows must load figma-console-mastery skill references (see `convergence-protocol.md` Subagent Prompt Template)
7. **Ask user when in doubt** — for non-trivial screen conversions (GROUP-heavy, complex components, ambiguous layouts), analyze first and present findings before proceeding
8. **GROUP→FRAME before constraints** — convert ALL GROUP nodes to transparent FRAMEs before setting constraints. GROUPs don't support `constraints` — assignment silently fails

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for all creation/mutation tools |

**Gate check**: Call `figma_get_status` before any operation. If transport shows `"not connected"`, the Bridge Plugin is not active — load `references/gui-walkthroughs.md` and guide the user through the setup steps.

**GUI-only operations**: Some tasks require direct interaction with Figma Desktop (plugin setup, activation, cache refresh). See `references/gui-walkthroughs.md`.

## Quick Start

**Checking and navigating**:
- **Check status** → `figma_get_status` (always first)
- **List open files** → `figma_list_open_files`
- **Open file/page** → `figma_navigate`

**Working with components**:
- **Find components** → `figma_search_components(query="Button")`
- **Place component** → `figma_instantiate_component(component_key, variant_properties)`

**Creating elements** — via `figma_execute` Plugin API:
- **Create frame** → `return (async () => { const f = figma.createFrame(); f.resize(375, 812); figma.currentPage.appendChild(f); return { id: f.id } })()`
- **Create text** → load font first, then `figma.createText()`
- **Set fills/layout** → use Plugin API with proper immutable-clone pattern

**Managing variables**:
- **Create token system** → `figma_setup_design_tokens` (atomic)
- **Bulk create** → `figma_batch_create_variables` (up to 100)
- **Bulk update** → `figma_batch_update_variables` (up to 100)

**Validation**:
- **After Plugin API changes** → `figma_capture_screenshot` (Desktop Bridge, live state)
- **For saved designs** → `figma_take_screenshot` (REST API)

**Complex workflows** — load references as needed:
```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
```

## Session Protocol

Every design session follows four phases:

### Phase 1 — Preflight
1. `figma_get_status` → verify connection and mode
2. `figma_list_open_files` → confirm correct file is active
3. `figma_navigate` → open target page/file if needed
4. **Load compound learnings** — if `~/.figma-console-mastery/learnings.md` exists, read entries relevant to the current task type

### Phase 2 — Discovery
1. `figma_get_design_system_summary` → understand existing tokens, components, styles
2. `figma_get_variables(format="summary")` → catalog available variables
3. `figma_search_components` → find reusable components before building custom

### Phase 3 — Creation (native-tools-first, journal-tracked)
1. **Read journal** — before ANY mutation, check `operation-journal.jsonl` for already-completed operations; skip anything already done
2. **Compose first**: `figma_instantiate_component` for existing library components
3. **Create with `figma_execute`**: Plugin API code for frame/text/shape creation and property setting
4. **Batch homogeneous ops**: for 3+ same-type operations (renames, moves, fills), use a single `figma_execute` batch script — see `convergence-protocol.md`
5. **Apply tokens**: `figma_execute` with `setBoundVariable()` for variable binding
6. **Log every operation** — append to `operation-journal.jsonl` immediately after each successful mutation

### Phase 4 — Validation
1. `figma_capture_screenshot` → visual check after Plugin API mutations (max 3 fix cycles)
2. Verify: alignment, spacing, proportions, visual hierarchy
3. `figma_generate_component_doc` → document created components
4. **Reflection** — run per triage tier (R0 skip, R1 quick, R2 standard, R3 deep critique). Full tier definitions, token budgets, and suppress conditions in `reflection-protocol.md` Section 2. Common triggers:
   - **R1** after each screen pipeline (3 dimensions: D1, D5, D6)
   - **R2** at phase boundaries (all 6 dimensions + CoV)
   - **R3** at session end (3 Figma-domain judges)
   - If verdict is **fail** or **conditional_pass**: targeted fix cycle (max 2 iterations) before proceeding

5. **Save compound learnings** — review for learning-worthy discoveries (triggers T1-T6); append 0-3 new entries to `~/.figma-console-mastery/learnings.md`

> **ST trigger**: When a screenshot-fix cycle reveals unexpected misalignment, activate ST with the Iterative Refinement template from `st-integration.md`. When R2+ reflection requires cross-referencing 3+ data sources, activate ST with the Reflection Quality Assessment template.

## Decision Matrix — Which Path to Take

| Gate | Question | Path | Primary Tool |
|------|----------|------|-------------|
| **G0: Exists?** | Standard component in Team Library? | **INSTANTIATE** | `figma_search_components` → `figma_instantiate_component` |
| **G1: Native?** | Dedicated figma-console tool for this operation? | **NATIVE** | `figma_batch_create_variables`, `figma_capture_screenshot`, `figma_audit_design_system` |
| **G2: Simple?** | Single-node create, fill, text set, rename, move, resize? | **EXECUTE-SIMPLE** | `figma_execute` with idempotency check |
| **G3: Complex?** | Multi-step async, conditionals, loops, batch homogeneous ops? | **EXECUTE-BATCH** | `figma_execute` batch script (see `convergence-protocol.md`) |

**Evaluate gates in order G0→G1→G2→G3.** Most atomic operations are G2. Reach for G3 batch scripts when operating on 3+ same-type nodes simultaneously — batch is ~70% cheaper.

## Visual QA Protocol

For screen-level quality validation (Draft vs Handoff comparison, deep 8-dimension audits, iterative fix cycles):

```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/visual-qa-protocol.md
```

Key patterns:
- **Modification-Audit-Loop**: modifications delegated to subagents (never in main context), audits run separately, max 3 fix iterations
- **Screen Diff**: side-by-side Draft vs Handoff comparison template
- **Handoff Audit**: 8-dimension deep quality check (Visual Quality, Layer Structure, Semantic Naming, Auto-Layout with 6 automated checks, Component Compliance 3-layer, Constraints, Screen Properties, Instance Override Integrity)
- **Positional Diff**: programmatic `absoluteBoundingBox` comparison catching +/-3-8px deltas that screenshots miss
- **Model**: Sonnet for all QA subagents (sufficient vision, lower latency than Opus)

## Quick Audit Protocol

When the goal is to spot-fix specific deviations in an existing design:

1. **Select target** — ask the user to select the frame or page to audit
2. **Scan** — `figma_get_file_for_plugin({ selectionOnly: true })` to get the node tree JSON
3. **Analyze** — look for deviations: hardcoded colors (no `boundVariables`), non-4px spacing, missing auto-layout, generic layer names
4. **Report** — `figma_post_comment` or `figma_set_description` to annotate findings directly in the file
5. **Fix** — `figma_execute` patches targeting specific node IDs
6. **Validate** — `figma_capture_screenshot` on patched nodes to confirm corrections

For automated health scoring: `figma_audit_design_system` (0-100 scorecard across naming, tokens, components, accessibility, consistency, coverage).

## Design Restructuring Workflow

Convert freehand/unstructured designs into well-structured, best-practice-compliant designs with auto-layout, components, naming conventions, and tokens.

```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-restructuring.md
```

> Also load: `recipes-restructuring.md` (required), `recipes-foundation.md` (Tier 1), `design-rules.md`. Path B additionally: `recipes-components.md`, `recipes-advanced.md`.

## Code Handoff (Technique Reference)

> **Full orchestration delegated**: The `design-handoff` skill (product-definition plugin) handles the complete Code Handoff workflow — screen inventory, scenario detection, per-screen preparation loop, gap analysis, and supplement generation. That skill's `handoff-figma-preparer` agent loads this skill's references for all Figma operations.

For TIER system definitions, Smart Componentization Criteria (3 gates), and Handoff Manifest format:

```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md
```

## Tool Selection Decision Tree

```
Need to check connection or navigate?
├── Connection status? → figma_get_status ✓ ALWAYS FIRST
├── Open file/page?    → figma_navigate
└── List open files?   → figma_list_open_files

Need to understand existing design system?
├── Overview?          → figma_get_design_system_summary
├── Variables/tokens?  → figma_get_variables (format="summary" first)
├── Styles?            → figma_get_styles
├── Component details? → figma_get_component / figma_get_component_for_development
└── Full file tree?    → figma_get_file_for_plugin (prefer over figma_get_file_data)

Need to create design elements?
├── Component in library? → figma_search_components → figma_instantiate_component
└── Everything else?      → figma_execute (Plugin API) — see recipes-foundation.md

Need to modify existing elements?
├── Multi-property async? → figma_execute (load fonts + set text + layout in sequence)
├── Single property?      → figma_execute (simple: clone fills, modify, reassign)
└── Batch 3+ same-type?   → figma_execute batch script (idempotency-guarded)

Need to manage variables/tokens?
├── Create token system?   → figma_setup_design_tokens (atomic, single call)
├── Create many variables? → figma_batch_create_variables (up to 100)
├── Update many values?    → figma_batch_update_variables (up to 100)
├── Single variable CRUD?  → figma_create/update/rename/delete_variable
└── Add/rename mode?       → figma_add_mode / figma_rename_mode

Need to validate or debug?
├── After Plugin API change?    → figma_capture_screenshot (Desktop Bridge — live state)
├── After save / stable design? → figma_take_screenshot (REST API)
├── Console errors?             → figma_get_console_logs / figma_watch_console
├── Design-code parity?         → figma_check_design_parity
└── Document component?         → figma_generate_component_doc
```

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
| `figma_get_design_system_summary` | Overview of tokens, components, styles |
| `figma_audit_design_system` | 0-100 health scorecard |
| `figma_generate_component_doc` | Document created components |

**Full tool reference**: `references/tool-playbook.md` (56+ tools)

## Essential Rules

### MUST

1. **Call `figma_get_status` first** — gate check before any operation
2. **Wrap `figma_execute` in async IIFE with outer `return`** — `return (async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()`. The outer `return` is required for the Desktop Bridge to await the Promise
3. **Use `figma.getNodeByIdAsync(id)`** — sync `figma.getNodeById()` **throws** in `dynamic-page` manifest mode (the API is disabled entirely). Use async variant inside async IIFE. (Async variant returns `null` if node doesn't exist — check for null separately)
4. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})` before any `.characters` assignment
5. **Set `layoutMode` before layout properties** — padding, spacing, constraints all require auto-layout to be active first
6. **Use `figma_capture_screenshot` for post-Plugin-API validation** — `figma_take_screenshot` uses the REST API (cloud-synced, cached) and will NOT reflect recent `figma_execute` mutations
7. **Check before creating (idempotency)** — before creating a named node, check if it already exists: `figma.currentPage.findOne(n => n.name === "Target")`. Re-running a script must not produce duplicates
8. **Native-tools-first** — use `figma_search_components` and `figma_instantiate_component` for library components; use batch variable tools for token management
9. **Converge, never regress** — read `operation-journal.jsonl` before every mutating operation; if the operation is already logged, SKIP it (see `convergence-protocol.md`)
10. **Journal every mutation** — append to `operation-journal.jsonl` immediately after each successful Figma mutation; write session snapshot after each batch
11. **Respect tool constraints** — use `figma_get_file_for_plugin` instead of `figma_get_file_data` on large files; call `figma_clear_console` before each `figma_execute` batch (buffer holds ~100 entries, each `console.log` emits 3 entries)
12. **Smart componentization** — componentize only elements meeting all 3 criteria: recurrence (3+), behavioral variants exist, codebase match. See `workflow-code-handoff.md` TIER system
13. **Subagents inherit figma-console-mastery** — all subagents dispatched for Figma workflows must load the skill references before starting work (see `convergence-protocol.md` Subagent Prompt Template)
14. **Real timestamps only** — journal `ts` fields must come from `new Date().toISOString()` inside `figma_execute` or from the orchestrator's real clock
15. **Verify prototype reactions after wiring** — after `setReactionsAsync`, re-read `node.reactions`. If reactions.length is 0 but wiring was attempted, log as `group_unsupported`
16. **Load learnings at session start** — if `~/.figma-console-mastery/learnings.md` exists, read it during Phase 1
17. **Save discoveries at session end** — during Phase 4, review for compound learning triggers. Deduplicate by H3 key before appending
18. **`createInstance()` on COMPONENT, not COMPONENT_SET** — get COMPONENT_SET → find variant child → `createInstance()` on the child
19. **Never call `group.remove()` after moving children** — GROUP auto-deletes when all children are moved out. Explicit `remove()` throws and silently skips subsequent code
20. **Run reflection per triage** — R1 after each screen pipeline, R2 at phase boundaries, R3 at session end. Skip only when suppress conditions are met (see `reflection-protocol.md`)
21. **Log reflection to journal** — append `op: "reflection"` entry with tier, scores, and verdict after every R1/R2/R3 evaluation

### AVOID

1. **Never skip Discovery** — always check existing components/tokens before building from scratch
2. **Never mutate Figma arrays directly** — fills, strokes, effects are immutable references; clone, modify, reassign
3. **Never return raw Figma nodes** from `figma_execute` — return plain data: `{ id: node.id, name: node.name }`
4. **Never leave nodes floating on canvas** — always place inside a Section or Frame container
5. **Never use individual variable calls for bulk operations** — use `figma_batch_create_variables` / `figma_batch_update_variables` (10-50x faster)
6. **Never use individual calls for 3+ same-type operations** — use batch `figma_execute` scripts with idempotency checks
7. **Never redo an operation already in the journal** — journal is the single source of truth for completed work
8. **Never trust in-context memory after compaction** — re-read operation journal before resuming
9. **Never save trivial or already-documented learnings** — only save insights NOT already covered by existing reference files
10. **Never set constraints on GROUP nodes** — convert to FRAME first
11. **Never use `figma_take_screenshot` to validate recent Plugin API mutations** — it serves stale cloud-cached renders; use `figma_capture_screenshot` instead
12. **Never split page-switch and data-read across calls** — `setCurrentPageAsync()` only affects the current async IIFE; subsequent calls revert to Figma Desktop active page. Always read in the same IIFE where you switched
13. **Never use `primaryAxisSizingMode = "FILL"` on a frame** — invalid enum; use `"AUTO"` or `"FIXED"` on frames and set `child.layoutSizingHorizontal = "FILL"` on children instead
14. **Never skip R2+ reflection at phase boundaries** — the per-phase quality gate catches structural and token-binding issues that screenshots alone miss; suppress only when explicit conditions are met (see `reflection-protocol.md`)

## Selective Reference Loading

**Load only when needed:**

```
# Tool selection — which of the 56+ tools to call and when
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

# Restructuring patterns — analysis, auto-layout conversion, componentization, naming, Socratic questions
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md

# Material Design 3 component recipes
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md

# Error catalog and anti-patterns — debugging, recovery, hard constraints
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md

# GUI walkthrough instructions — setup, plugin activation, cache refresh
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/gui-walkthroughs.md

# Sequential Thinking integration — thought chain templates
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/st-integration.md

# Design Restructuring workflow — 5-phase process (Analyze, Socratic Plan, Path A/B, Polish)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-restructuring.md

# Code Handoff technique reference — TIER system, Smart Componentization, Handoff Manifest
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md

# Convergence protocol — operation journal, anti-regression, batch scripting, subagent delegation
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

# Compound Learning Protocol — cross-session knowledge persistence
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/compound-learning.md

# Reflection Protocol — quality self-assessment (R0-R3 tiers, 6 Figma dimensions, judge templates)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/reflection-protocol.md

# Visual QA Protocol — screen validation, 8-dimension audit, Modification-Audit-Loop pattern
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/visual-qa-protocol.md

# Field Learnings — production strategies, componentization workflows, container patterns, coordinate systems
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/field-learnings.md
```

### Loading Tiers

**Tier 1 — Always:** `recipes-foundation.md` (required for any `figma_execute` code), `convergence-protocol.md` (operation journal + anti-regression — required for any multi-step workflow)

**Tier 2 — By task:** `recipes-components.md` | `recipes-restructuring.md` | `tool-playbook.md` | `plugin-api.md` | `design-rules.md` | `workflow-restructuring.md` | `workflow-code-handoff.md`

**Tier 3 — By need:** `recipes-advanced.md` | `recipes-m3.md` | `anti-patterns.md` | `gui-walkthroughs.md` | `st-integration.md` | `compound-learning.md` | `reflection-protocol.md` | `visual-qa-protocol.md` | `field-learnings.md`

## Sequential Thinking Integration (Optional)

> **Prerequisite**: `mcp__sequential-thinking__sequentialthinking` MCP server must be available. ST is **never required** — all workflows function identically without it.

| Trigger | ST Pattern |
|---------|------------|
| Path A/B decision in restructuring (ambiguous Socratic findings) | Fork-Join |
| Iterative screenshot-fix cycle (unexpected misalignment) | TAO Loop + Revision |
| Multi-step diagnostic (deviations across 3+ categories) | Hypothesis Tracking |
| Code Handoff naming audit (>5 ambiguous flags) | TAO Loop |

**Skip ST for**: simple create-screenshot-confirm flows (<3 steps), quick audits with zero deviations, single-tool operations.

**Thought chain templates**: `references/st-integration.md`

## Compound Learning Protocol (Optional)

> **Location**: `~/.figma-console-mastery/learnings.md` (user-home, cross-project)
> **Full spec**: `references/compound-learning.md`

| Save When | Category |
|-----------|----------|
| >1 attempt to solve (different approach needed) | API Quirks & Workarounds |
| Workaround discovered (standard approach failed) | API Quirks & Workarounds |
| Non-obvious recovery (beyond anti-patterns.md) | Error Recovery |
| Strategy significantly outperformed alternatives | Effective Strategies |

**Do NOT save**: solutions already in reference files, trivial solutions, project-specific insights, sessions with no retries or surprises. Max 3 entries per session.

## Troubleshooting Quick Index

| Symptom | Quick Fix |
|---------|-----------|
| `figma_get_status` shows not connected | Guide user through plugin setup — see `references/gui-walkthroughs.md` |
| `figma_execute` returns empty/error | Wrap in `return (async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()` — outer `return` required |
| Font loading error | Call `figma.loadFontAsync({family, style})` before setting `.characters` |
| Layout properties silently ignored | Set `layoutMode = 'VERTICAL'` or `'HORIZONTAL'` BEFORE padding/spacing |
| Fill/stroke mutation fails | Clone array, modify clone, reassign (immutable reference pattern) |
| `figma_instantiate_component` silent fail | Verify variant property names match exactly (case-sensitive) |
| Batch variable call fails | Verify `collectionId` is valid; max 100 per batch call |
| Node IDs lost after context compaction | Re-read `operation-journal.jsonl` and `session-state.json` — see `convergence-protocol.md` Compact Recovery Protocol |
| System redoing already-completed work | Read `operation-journal.jsonl`, skip any operation already logged |
| Console log buffer missing earlier results | Buffer holds ~100 entries, each `console.log` emits 3 — call `figma_clear_console` before each batch |
| `figma_take_screenshot` shows stale content | Use `figma_capture_screenshot` (Desktop Bridge, live state) for post-Plugin-API validation |
| Context compaction mid-workflow | Re-read journal + state files, rebuild completed-ops set, resume from first uncompleted operation |
| Prototype connections silently lost | GROUP nodes drop reactions silently; verify with `node.reactions` re-read after `setReactionsAsync` |
| `createInstance()` fails on COMPONENT_SET | Find variant child first: `set.children.find(c => c.name.includes("State=Default"))`, then `variant.createInstance()` |
| `"object is not extensible"` on GROUP | Cannot set `constraints` on GROUP. Convert to transparent FRAME first |
| `"node does not exist"` after moving GROUP children | GROUP auto-deletes when empty. Never call `group.remove()` |
| Auto-layout height stays at 1px | Toggle fix: set `counterAxisSizingMode = "FIXED"`, `resize(w, approxH)`, then `counterAxisSizingMode = "AUTO"` |
| Child fill sizing throws validation error | `primaryAxisSizingMode = "FILL"` is invalid on frames — use `"AUTO"`. Set `child.layoutSizingHorizontal = "FILL"` on the child |
| Instance looks distorted after resize | `resize()` changes bounding box only — use `inst.rescale(targetW / naturalW)` to scale content proportionally |
| `combineAsVariants` throws "has existing errors" | All nodes must have EVERY property in `Prop1=Val1, Prop2=Val2` format before combining |
| `figma.getNodeById(id)` throws in dynamic-page mode | Use `figma.getNodeByIdAsync(id)` — the sync API is disabled entirely; throws, does not return null |
| Desktop Bridge drops mid-session | Gate each step with `figma_get_status`; on dropout, instruct user to reopen the plugin |
| `get_design_context` reports wrong text values | Returns master component defaults, not live `.characters` overrides. Cross-check with `figma_execute` returning `node.characters` |
| `page.findOne()` returns null after `setCurrentPageAsync` | Capture page object in the same IIFE: `const p = figma.root.children.find(...)` then `p.findOne()` |
| `setProperties()` silently does nothing | Use base property name (e.g., `"day"`) not the disambiguated key (`"day#222:62"`) — binding uses returned key, overriding uses the name |
| `addComponentProperty` key mismatch | `addComponentProperty` returns a disambiguated key like `"message#206:8"` — always use the RETURNED key for `componentPropertyReferences` binding |
| Text wraps unexpectedly after instance override | Override sets `textAutoResize=HEIGHT` with component's narrow default width. Fix: `textAutoResize = 'WIDTH_AND_HEIGHT'` after loading font |
| `textAutoResize = 'WIDTH_AND_HEIGHT'` ignored in auto-layout | Competing sizing: use `textAutoResize = 'HEIGHT'` when text has `layoutSizingHorizontal = 'FILL'` |
| `swapComponent` loses position and properties | Capture x/y/w/h/constraints BEFORE swap, restore AFTER. Old component properties are gone — set new ones by name or find TEXT nodes directly |
| M3 Button label text is null | `figma.skipInvisibleInstanceChildren = false` before `findOne(n => n.type === 'TEXT')`, restore to `true` after |
| GROUP child position assignment offset | GROUP children report x/y relative to the CONTAINING FRAME, not the GROUP. Use `child.x = group.x + desiredLocalX` |
| Container appears at wrong x after append | `layoutMode=NONE` parent assigns non-zero x on append. Always set `container.x = 0` explicitly AFTER appending |
| Data lost between `figma_execute` calls | Use `globalThis.__key = value` in async IIFE, read back in subsequent sync call. Use unique key names per operation |

**Full reference**: `references/anti-patterns.md`, `references/field-learnings.md`

## When NOT to Use This Skill

- **FigJam diagrams** — not supported by Console MCP
- **Figma REST API / OAuth setup** — outside scope (Console MCP uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
- **Design analysis and visual diffing** — `figma_analyze_*`, `figma_diff_visual`, XPath queries were provided by figma-use MCP (removed from this skill); use `figma_audit_design_system` as the available alternative
- **Full Draft-to-Handoff and Code Handoff orchestration** — use `design-handoff` skill (product-definition plugin)
