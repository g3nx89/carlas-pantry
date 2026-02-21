---
name: figma-console-mastery
version: 0.8.0
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", "render JSX in Figma", "use figma_render", "use figma-use MCP", "analyze Figma design", "diff Figma designs", "query Figma nodes with XPath", "convert draft to handoff", "transfer Figma designs to handoff", "prepare Figma for code handoff", "create handoff page from draft", or when developing skills/commands that use the Figma Console or figma-use MCP servers. Provides tool selection, Plugin API patterns, JSX rendering, design analysis, visual diffing, design rules, Draft-to-Handoff workflow with clone-first architecture, and selective reference loading for both MCP servers.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design creation via Console MCP + figma-use MCP (JSX rendering, analysis, diffing), plus Code Handoff Protocol for preparing designs for downstream code implementation. For the design-to-code pipeline after handoff, see the Downstream Workflow section.

## Overview

Two MCP servers work together: **figma-console** (Southleft, 56+ tools) for Plugin API access, variable CRUD, debugging, and screenshots; and **figma-use** (115+ declarative tools) for token-efficient creation, modification, analysis, and diffing. Both connect to Figma Desktop via different transports and coexist without conflict.

**Core principles**:
1. **figma-use-first** — use declarative tools for all atomic operations (create, modify, query); reserve `figma_execute` for complex conditional logic or batch scripts only
2. **Discover before creating** — check existing components/tokens before building from scratch
3. **Converge, never regress** — log every operation to the journal; check journal before every mutation; never redo completed work (see `convergence-protocol.md`)
4. **Persist aggressively** — write to operation journal after EVERY operation, snapshot after each screen; assume context compaction can happen at any time
5. **One screen at a time** — in Draft-to-Handoff workflows, process each screen through the full pipeline (clone, validate, restructure, integrate components, visual diff) before starting the next; batch homogeneous operations *within* a screen (see `convergence-protocol.md`)
6. **Validate visually** — screenshot and `figma_diff_visual` after every screen (max 3 fix cycles per screen)
7. **Smart componentization** — apply the TIER system: componentize only elements meeting all 3 criteria (recurrence 3+, behavioral variants, codebase match); see `workflow-code-handoff.md` for TIER definitions and Smart Componentization Criteria
8. **Subagents inherit skill context** — all subagents dispatched for Figma workflows must load figma-console-mastery skill references (see `convergence-protocol.md` Subagent Prompt Template)
9. **Ask user when in doubt** — for non-trivial screen conversions (GROUP-heavy, complex components, ambiguous layouts), analyze first and present findings to user before proceeding. Trivial screens proceed autonomously. Early user involvement prevents token waste on wrong assumptions
10. **GROUP→FRAME before constraints** — after cloning, convert ALL GROUP nodes to transparent FRAMEs before setting constraints. GROUPs don't support `constraints` — assignment silently fails. See `recipes-components.md` GROUP→FRAME recipe

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) — Console MCP |
| Local mode | Required for all creation/mutation tools (Console MCP) |

**figma-use prerequisites** (needed only for JSX rendering, analysis, diffing, XPath queries):

| Requirement | Check |
|-------------|-------|
| Figma Desktop with CDP | Launched with `--remote-debugging-port=9222` |
| figma-use server | Running (pre-1.0, v0.11.3) — `http://localhost:38451/mcp` |

**Gate check**: Call `figma_get_status` before any operation. If transport shows `"not connected"`, the Bridge Plugin is not active — load `references/gui-walkthroughs.md` and guide the user through the setup steps.

**GUI-only operations**: Some tasks require direct interaction with the Figma Desktop application (plugin setup, activation, cache refresh, node selection, CDP transport, MCP Apps configuration). These have no MCP or CLI equivalent. See `references/gui-walkthroughs.md` for full step-by-step instructions. **When a task requires the user to interact with the Figma Desktop UI**, load `references/gui-walkthroughs.md` and relay the step-by-step instructions to the user.

## Quick Start

**Simple tasks** — figma-use declarative tools (preferred):
- **Check status** → `figma_get_status` (figma-console) or `figma_page_list` (figma-use connectivity check)
- **Create frame** → `figma_create_frame(name, width, height, fill, parent)`
- **Create text** → `figma_create_text(text, font-family, font-size, fill, parent)`
- **Set properties** → `figma_set_fill`, `figma_set_stroke`, `figma_set_layout`, `figma_set_font`
- **Find components** → `figma_search_components(query="Button")`
- **Place component** → `figma_instantiate_component(component_key, variant_properties)`
- **Validate** → `figma_take_screenshot` (figma-console)

**Complex conditional logic** — figma-console `figma_execute` (fallback):
- **Multi-step async** → `figma_execute(code="(async () => { ... })()")` — font loading + text + layout in sequence
- **Prototype wiring** → `figma_execute` with `setReactionsAsync`

**Analysis and diffing** — figma-use:
- **Render JSX** → `figma_render(jsx, x, y, parent)` — 2-4x fewer tokens for complex trees
- **Analyze design** → `figma_analyze_clusters`, `figma_analyze_colors`, `figma_analyze_typography`, `figma_analyze_spacing`
- **Diff designs** → `figma_diff_visual`, `figma_diff_create`, `figma_diff_apply`
- **Query nodes** → `figma_query(xpath)` — XPath 3.1 for structured node discovery

**Complex workflows** — load references as needed:
```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md  # Which tool to call (three-server comparison)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md     # Writing figma_execute code (nodes, auto-layout, text, colors, images, components, variables)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md   # Design decisions + M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md  # Foundation patterns + layouts (always needed for figma_execute)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components.md  # Component code recipes (cards, buttons, forms, tables, etc.)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md    # Composition, variable binding, full page assembly, chaining
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md          # M3 component recipes
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md  # Errors and debugging
```

## Session Protocol

Every design session follows four phases:

### Phase 1 — Preflight
1. `figma_get_status` → verify connection and mode
2. `figma_list_open_files` → confirm correct file is active
3. `figma_navigate` → open target page/file if needed
4. **Load compound learnings** — if `~/.figma-console-mastery/learnings.md` exists, read it and note entries relevant to the current task type. Cross-session knowledge base — learnings apply across all projects. File is optional; sessions function identically without it

### Phase 2 — Discovery
1. `figma_get_design_system_summary` → understand existing tokens, components, styles
2. `figma_get_variables(format="summary")` → catalog available variables
3. `figma_search_components` → find reusable components before building custom

### Phase 3 — Creation (figma-use-first, journal-tracked)
1. **Read journal** — before ANY mutation, check `operation-journal.jsonl` for already-completed operations; skip anything already done
2. **Compose first**: `figma_instantiate_component` for existing library components
3. **Create with figma-use**: `figma_create_frame`, `figma_create_text`, `figma_create_rect`, `figma_set_fill`, `figma_set_layout` for new elements
4. **Batch homogeneous ops**: for 3+ same-type operations (renames, moves, fills), use a single `figma_execute` batch script with built-in idempotency checks — see `convergence-protocol.md`
5. **Complex logic only**: `figma_execute` for multi-step async sequences (font loading + text + layout) or conditional logic
6. **Place in context**: Create Section/Frame containers; never leave nodes floating on canvas
7. **Apply tokens**: `figma_variable_bind` (figma-use) or `figma_execute` with `setBoundVariable()` for complex binding
8. **Log every operation** — append to `operation-journal.jsonl` immediately after each successful mutation; write session snapshot after each batch — see `convergence-protocol.md`

### Phase 4 — Validation
1. `figma_take_screenshot` → visual check (max 3 screenshot-fix cycles)
2. Verify: alignment, spacing, proportions, visual hierarchy
3. Fix issues found, re-screenshot
4. `figma_generate_component_doc` → document created components
5. **Save compound learnings** — review the session for learning-worthy discoveries and append 0-3 new entries to `~/.figma-console-mastery/learnings.md`. See Compound Learning Protocol below

> **ST trigger**: When a screenshot-fix cycle in Phase 4 reveals unexpected misalignment, activate ST with the Iterative Refinement template from [`st-integration.md#template-iterative-refinement`]. TAO Loop: predict → screenshot → compare → revise if mismatch (max 3 cycles).

## Decision Matrix — Which Path to Take

Before picking a tool, determine the execution path through these gates:

| Gate | Question | Path | Primary Tool |
|------|----------|------|-------------|
| **G0: Declarative?** | Can this be done with a single figma-use tool call? | **DECLARE** | `figma_create_*`, `figma_set_*`, `figma_node_*`, `figma_variable_bind` |
| **G1: Exists?** | Is the element a standard atom (Button, Badge, Icon) likely in the Team Library? | **INSTANTIATE** | `figma_search_components` → `figma_instantiate_component` |
| **G2: Complex?** | Does the operation require multi-step async logic, conditionals, or loops? | **EXECUTE** or **RENDER** | `figma_execute` for conditional/async logic; `figma_render` (JSX) for 5+ node compositions |
| **G3: Modify?** | Is the intent to alter properties of an existing node (color, padding, text)? | **MODIFY** | figma-use `figma_set_*` tools; `figma_execute` only if multi-property + async |
| **G4: Analyze/Diff?** | Is the goal to audit, analyze, compare, or query existing designs? | **ANALYZE** | `figma_analyze_*` / `figma_diff_*` / `figma_query` |

**Always evaluate G0 first** — most operations can be expressed as a single figma-use call without writing any JavaScript. Then check G1 (library components). Only reach for `figma_execute` at G2 when the operation genuinely requires complex logic. G4 analysis/diff tools require figma-use CDP connection. Creating a button from scratch when one exists in the library wastes tokens, breaks design system consistency, and loses the instance-master link.

> **Grid note**: CSS Grid layout creation can follow G0 (declarative `figma_set_layout` with `display="grid"`) for simple grids, or G2 (`figma_execute` with `layoutMode='GRID'`) for complex grid configurations requiring conditional logic or dynamic row/column definitions.

## Quick Audit Protocol (Alternative Session)

When the goal is to spot-fix specific deviations in an existing design rather than create new elements:

1. **Select target** — ask the user to select the frame or page to audit
2. **Scan** — `figma_get_file_for_plugin({ selectionOnly: true })` to get the node tree JSON
3. **Analyze** — look for deviations: hardcoded colors (no `boundVariables`), non-4px spacing, missing auto-layout, generic layer names
4. **Report** — use `figma_post_comment` or `figma_set_description` to annotate findings directly in the file
5. **Fix** — apply patches via `figma_execute`, targeting specific node IDs: `const n = await figma.getNodeByIdAsync("ID"); n.fills = [...]`
6. **Validate** — `figma_capture_screenshot` on the patched nodes to confirm corrections

For automated health scoring, use `figma_audit_design_system` which returns a 0-100 scorecard across naming, tokens, components, accessibility, consistency, and coverage.

> For comprehensive structural conversion of freehand designs into best-practice-compliant structures, use the Design Restructuring Workflow section below (load `workflow-restructuring.md`).

## Design Restructuring Workflow (Alternative Session)

Convert freehand/unstructured designs into well-structured, best-practice-compliant designs with auto-layout, components, naming conventions, and tokens. Multi-phase collaborative process (Analyze → Socratic Plan → Path A in-place or Path B reconstruction → Polish) with visual fidelity gates.

```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-restructuring.md
```

> Also load: `recipes-restructuring.md` (required), `recipes-foundation.md` (Tier 1), `design-rules.md`. Path B additionally: `recipes-components.md`, `recipes-advanced.md`.

## Code Handoff Protocol (Post-Session)

Prepare completed Figma designs for downstream code implementation. Uses the **TIER system** to scale componentization effort: TIER 1 (naming + tokens — always), TIER 2 (smart components — recommended), TIER 3 (heavy — optional). Generates a **Handoff Manifest** (`specs/figma/handoff-manifest.md`) with screen inventory, component-to-code mapping, and token mapping for the coding agent. If a **UX-NARRATIVE** exists (produced BEFORE handoff by the `design-narration` skill), it feeds into the Smart Componentization Analysis (Gate 2 behavioral variants) and is referenced in the manifest.

```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md
```

> Also load: `recipes-advanced.md` (Handoff Preparation Pattern).

## Tool Selection Decision Tree

```
Need to check connection or navigate?
├── Connection status? → figma_get_status (figma-console) ✓ ALWAYS FIRST
├── Connectivity check → figma_page_list (figma-use — also verifies CDP)
├── Open file/page?    → figma_navigate
└── List open files?   → figma_list_open_files

Need to understand existing design system?
├── Overview?          → figma_get_design_system_summary
├── Variables/tokens?  → figma_get_variables (format="summary" first)
├── Styles?            → figma_get_styles
├── Component details? → figma_get_component / figma_get_component_for_development
└── Full file tree?    → figma_get_file_for_plugin (prefer over figma_get_file_data)

Need to create design elements? (figma-use-first)
├── Component exists in library? → figma_search_components → figma_instantiate_component
├── Create frame?      → figma_create_frame (figma-use)
├── Create text?       → figma_create_text (figma-use)
├── Create shape?      → figma_create_rect / figma_create_ellipse / figma_create_line (figma-use)
├── Create component?  → figma_create_component (figma-use)
├── Create instance?   → figma_create_instance (figma-use)
├── Complex multi-node UI?  → figma_render (JSX, 1 call for N nodes)
├── Complex conditional logic? → figma_execute (figma-console — fallback for async/conditionals)
├── CSS Grid layout?    → figma_set_layout (figma-use, display="grid") or figma_execute (Plugin API, layoutMode='GRID')
└── Organize variants?        → figma_arrange_component_set (figma-console)

Need to modify existing elements? (figma-use-first)
├── Set fill/stroke?   → figma_set_fill / figma_set_stroke (figma-use)
├── Set text?          → figma_set_text (figma-use or figma-console)
├── Set layout?        → figma_set_layout (figma-use)
├── Set font?          → figma_set_font / figma_set_font_range (figma-use)
├── Set radius?        → figma_set_radius (figma-use)
├── Combine variants?  → figma_component_combine (figma-use — avoids page context errors)
├── Bind variable?     → figma_variable_bind (figma-use)
└── Multi-property + async? → figma_execute (figma-console — fallback)

Need to manage variables/tokens?
├── Create token system?   → figma_setup_design_tokens (atomic, single call)
├── Create many variables? → figma_batch_create_variables (up to 100)
├── Update many values?    → figma_batch_update_variables (up to 100)
├── Single variable CRUD?  → figma_create/update/rename/delete_variable
└── Add/rename mode?       → figma_add_mode / figma_rename_mode

Need to manipulate existing nodes? (figma-use)
├── Move/reparent?  → figma_node_move / figma_node_set_parent (figma-use)
├── Resize?         → figma_node_resize (figma-use)
├── Rename?         → figma_node_rename (figma-use)
├── Clone?          → figma_node_clone (figma-use)
├── Delete?         → figma_node_delete (figma-use)
├── Replace?        → figma_node_replace_with (figma-use)
└── Add child?      → figma_create_child (figma-console)

Need to validate or debug?
├── Visual check?       → figma_take_screenshot (max 3 cycles)
├── Capture for report? → figma_capture_screenshot
├── Console errors?     → figma_get_console_logs / figma_watch_console
├── Design-code parity? → figma_check_design_parity
└── Document component? → figma_generate_component_doc

Need to analyze or diff? (figma-use, CDP required)
├── Analyze clusters?       → figma_analyze_clusters
├── Analyze colors?         → figma_analyze_colors
├── Analyze typography?     → figma_analyze_typography
├── Analyze spacing?        → figma_analyze_spacing
├── Accessibility snapshot? → figma_analyze_snapshot
├── Visual pixel diff?      → figma_diff_visual
├── Property diff?          → figma_diff_create → figma_diff_apply
├── XPath query?            → figma_query
├── Boolean operation?      → figma_boolean_union / subtract / intersect / exclude
└── Icon from Iconify?      → figma_create_icon / inline <Icon> in JSX
```

## Quick Reference — Core Tools

| Tool | Server | Purpose |
|------|--------|---------|
| `figma_get_status` | figma-console | Verify connection (always first) |
| `figma_search_components` | figma-console | Find library components before creating |
| `figma_instantiate_component` | figma-console | Place component with variant properties |
| `figma_create_frame` | figma-use | Create frame with layout, fill, radius |
| `figma_create_text` | figma-use | Create text node |
| `figma_set_fill` / `figma_set_stroke` | figma-use | Set fill or stroke color |
| `figma_set_layout` | figma-use | Set auto-layout or CSS Grid mode |
| `figma_node_move` / `figma_node_clone` | figma-use | Move, clone, reparent nodes |
| `figma_variable_bind` | figma-use | Bind variable to node property |
| `figma_render` | figma-use | JSX rendering (complex multi-node, 1 call) |
| `figma_component_combine` | figma-use | Combine variants (avoids page context errors) |
| `figma_execute` | figma-console | Run Plugin API code (complex logic fallback) |
| `figma_take_screenshot` | figma-console | Visual validation (max 3 cycles) |

**Full tool reference**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md` (figma-console 56+ tools) and `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/figma-use-overview.md` (figma-use 115+ tools)

## Essential Rules

### MUST

1. **Call `figma_get_status` first** — gate check before any operation
2. **Wrap `figma_execute` in async IIFE with try-catch** — `(async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()`
3. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})` before any `.characters` assignment
4. **Set `layoutMode` before layout properties** — padding, spacing, constraints all require auto-layout to be active first
5. **Validate with screenshots** — take a screenshot after every creation step (max 3 fix cycles)
6. **Check before creating (idempotency)** — before creating a named node, check if it already exists: `figma.currentPage.findOne(n => n.name === "Target")`. Re-running a script must not produce duplicates
7. **figma-use-first** — use declarative tools (`figma_create_*`, `figma_set_*`, `figma_node_*`) for all atomic operations; use `figma_execute` batch scripts for 3+ homogeneous ops; fall back to individual `figma_execute` only for complex conditional logic
8. **Converge, never regress** — read `operation-journal.jsonl` before every mutating operation; if the operation is already logged, SKIP it; this is the primary defense against redoing work after context compaction (see `convergence-protocol.md`)
9. **Journal every mutation** — append to `operation-journal.jsonl` immediately after each successful Figma mutation; write session snapshot (`session-state.json`) after each batch; assume compaction can happen at any time
10. **Respect tool constraints** — use `figma_node_children` instead of `figma_node_tree` on large files (>500 nodes); test unfamiliar figma-use tools with a single call before batch usage
11. **Verify source design access before building** — before constructing ANY screen on a Handoff page, successfully read the source Draft screen's node tree via `figma_node_children(id: draftScreenId)`. If the call fails or returns no meaningful children, STOP and inform the user. NEVER fall back to building from text documents, PRDs, or reconstruction guides — text cannot capture images, fonts, layer ordering, or visual properties
12. **Clone-first for existing designs** — when a Draft page contains finalized designs, ALWAYS use `figma_node_clone` to transfer screens to the Handoff page, then restructure. Only build from scratch for screens that do not exist in the Draft. Cloning is the only way to preserve IMAGE fills, exact fonts, and visual fidelity
13. **One screen at a time in Draft-to-Handoff** — process each screen through the full pipeline (clone → validate childCount → restructure → integrate components → visual diff) and confirm correctness before starting the next. Never batch-process screens — batch processing hides silent failures
14. **Validate childCount after clone** — after every `figma_node_clone`, compare clone's childCount against the source's childCount from Phase 0 inventory. If clone has 0 children but source has >0, this is a clone failure — retry once, halt if still 0. NEVER mark a 0-child clone as complete
15. **Smart componentization** — apply the TIER system from `workflow-code-handoff.md`: TIER 2 (default) componentizes only elements passing all 3 gates (recurrence 3+, behavioral variants, codebase match). TIER 1 skips component creation. 0 instances is expected for TIER 1, flagged for review only in TIER 2/3 when passing candidates exist
16. **Subagents inherit figma-console-mastery** — all subagents dispatched for Figma workflows must load the skill references (workflow, convergence protocol, recipes-foundation, anti-patterns) before starting work. See `convergence-protocol.md` Subagent Prompt Template
17. **Real timestamps only** — journal `ts` fields must come from `new Date().toISOString()` inside `figma_execute` or from the orchestrator's real clock. Never use hardcoded placeholder timestamps
18. **Verify prototype reactions after wiring** — after `setReactionsAsync`, re-read `node.reactions`. If reactions.length is 0 but wiring was attempted, log as `group_unsupported` — GROUP nodes silently drop reactions
19. **Load learnings at session start** — if `~/.figma-console-mastery/learnings.md` exists, read it during Phase 1. Apply relevant learnings proactively. Sessions function identically without it
20. **Save discoveries at session end** — during Phase 4, review for compound learning triggers (>1 attempt, workaround discovered, non-obvious recovery). Deduplicate by H3 key match before appending
21. **`createInstance()` on COMPONENT, not COMPONENT_SET** — to instantiate a variant: get the COMPONENT_SET → find variant child by name → `createInstance()` on the child. Calling it on COMPONENT_SET fails. Similarly, `swapComponent()` requires a COMPONENT node
22. **Mandatory 9-step handoff post-processing** — every cloned screen requires: cornerRadius → clipsContent → GROUP→FRAME → semantic naming → constraints → proportional resize (viewport only) → component integration → instance count verify → visual validation. See `workflow-draft-to-handoff.md` Handoff Screen Checklist
23. **Viewport vs Scrollable screen handling** — viewport screens (device-height) need proportional resize with per-constraint-type Y formulas. Scrollable screens keep draft positions unchanged with all MIN constraints. See `recipes-foundation.md` Constraint Reference
24. **Never call `group.remove()` after moving children** — GROUP auto-deletes when all children are moved out. Explicit remove() throws and silently skips subsequent code in the same try-block
25. **Per-variant source fidelity** — inspect Draft source for EACH variant independently. Never normalize fills across variants. Clone N-1 times FIRST, then modify each independently
26. **Analyze before cloning in Draft-to-Handoff** — run Screen Analysis (Step 2.0) BEFORE cloning each screen. For MODERATE/COMPLEX screens, present analysis and ask user questions before proceeding. See `workflow-draft-to-handoff.md` Steps 2.0-2.0B

### AVOID

1. **Never skip Discovery** — always check existing components/tokens before building from scratch
2. **Never mutate Figma arrays directly** — fills, strokes, effects are immutable references; clone, modify, reassign
3. **Never return raw Figma nodes** from `figma_execute` — return plain data: `{ id: node.id, name: node.name }`
4. **Never leave nodes floating on canvas** — always place inside a Section or Frame container
5. **Never use individual variable calls for bulk operations** — use `figma_batch_create_variables` / `figma_batch_update_variables` (10-50x faster)
6. **Never use individual calls for 3+ same-type operations** — use batch `figma_execute` scripts with idempotency checks; individual calls for renames/moves/fills waste 70% more tokens (see `convergence-protocol.md`)
7. **Never build Handoff screens from text descriptions alone** — text documents (PRDs, reconstruction guides, design specs) are supplementary context for naming and annotations, never the design source of truth. If the only available source is text, STOP and inform the user that Figma source designs are required
8. **Never proceed silently when source Figma access fails** — if source designs cannot be read (connection issues, missing page, empty node tree), halt immediately and inform the user. Silent fallback to text-based construction produces 100% incorrect output
9. **Never redo an operation already in the journal** — if `operation-journal.jsonl` records that a node was renamed/moved/created, do NOT perform that operation again; this is the #1 cause of regression and wasted tokens in long sessions
10. **Never trust in-context memory after compaction** — after context compaction, the ONLY reliable record of completed work is the operation journal on disk; re-read it before resuming any work
11. **Never save trivial or already-documented learnings** — only save insights NOT already covered by existing reference files. "Font needs loading before text" is in SKILL.md and anti-patterns.md — do not duplicate known rules
12. **Never set constraints on GROUP nodes** — GROUP nodes don't support `constraints`. Convert to FRAME first (MUST rule #10). See `anti-patterns.md` Handoff-Specific Anti-Patterns
13. **Never use uniform Y-shift for proportional resize** — each constraint type (MIN/MAX/CENTER/STRETCH) has its own formula. Shifting all elements equally breaks proportional relationships. See `recipes-foundation.md` Proportional Resize Calculator
14. **Never normalize colors across component variants** — different variants intentionally differ. Inspect each variant's Draft source independently (MUST rule #25)
15. **Never skip Screen Analysis for complex screens** — jumping to clone/transform without analyzing wastes tokens on wrong assumptions. Analyze first, ask user when in doubt (MUST rule #26)

## Selective Reference Loading

**Load only when needed:**

### Reference Files
```
# Tool selection guidance — which of the 56+ tools to call and when
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md

# Plugin API reference — writing figma_execute code (node creation, auto-layout, text, colors, components, variables)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md

# Design rules — MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

# Foundation patterns + layouts — ALWAYS load when writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

# Component recipes — cards, buttons, inputs, toast, navbar, sidebar, form, data table, empty state, modal
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components.md

# Advanced patterns — composition, variable binding, SVG import, rich text, full page assembly, chaining
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md

# Restructuring patterns — analysis, auto-layout conversion, componentization, token binding, naming, Socratic questions
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-restructuring.md

# Material Design 3 component recipes — M3 Button, Card, Top App Bar, TextField, Dialog, Snackbar, Bottom Nav, Elevation
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md

# Error catalog and anti-patterns — debugging, recovery, hard constraints
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md

# GUI walkthrough instructions — setup, plugin activation, cache refresh, node selection, CDP transport
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/gui-walkthroughs.md

# figma-use: server overview, tool inventory, decision matrix, setup, performance
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/figma-use-overview.md

# figma-use: JSX rendering patterns, shorthand props, translation table, CSS Grid, icons
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/figma-use-jsx-patterns.md

# figma-use: figma_analyze_* tools, dual-server analysis workflow
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/figma-use-analysis.md

# figma-use: diffing, XPath queries, boolean ops, vector paths, arrange, icons, storybook
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/figma-use-diffing.md

# Sequential Thinking integration — thought chain templates for restructuring, handoff, iterative refinement
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/st-integration.md

# Design Restructuring workflow — 5-phase process (Analyze, Socratic Plan, Path A/B, Polish)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-restructuring.md

# Code Handoff protocol — TIER system, Smart Componentization, Handoff Manifest, naming audit, token alignment
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-code-handoff.md

# Draft-to-Handoff workflow — operational rules, user-involved per-screen pipeline (analyze → ask → clone → GROUP→FRAME → constraints → components → visual validate → approve), 6-phase workflow, state persistence, error prevention
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-draft-to-handoff.md

# Convergence protocol — operation journal, anti-regression, batch scripting, subagent delegation
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

# Compound Learning Protocol — cross-session knowledge persistence, format spec, save/load rules
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/compound-learning.md
```

### Loading Tiers

**Tier 1 — Always:** `recipes-foundation.md` (required for any `figma_execute` code), `figma-use-overview.md` (tool inventory + decision matrix), `convergence-protocol.md` (operation journal + anti-regression — required for any multi-step workflow)
**Tier 2 — By task:** `recipes-components.md` (includes GROUP→FRAME, Componentize from Clone, COMPONENT_SET instantiation) | `recipes-restructuring.md` | `tool-playbook.md` | `plugin-api.md` | `design-rules.md` | `figma-use-jsx-patterns.md` | `figma-use-analysis.md` | `workflow-draft-to-handoff.md` (user-involved per-screen pipeline, constraint formulas, Handoff Checklist) | `workflow-restructuring.md` | `workflow-code-handoff.md`
**Tier 3 — By need:** `recipes-advanced.md` | `recipes-m3.md` | `anti-patterns.md` | `gui-walkthroughs.md` | `figma-use-diffing.md` | `st-integration.md` | `compound-learning.md`

## Sequential Thinking Integration (Optional)

> **Prerequisite**: `mcp__sequential-thinking__sequentialthinking` MCP server must be available.
> **Cross-skill reference**: See `sequential-thinking-mastery` skill for full ST documentation.

When a Figma workflow involves multi-step diagnostic chains, branching decisions, or iterative fix loops, Sequential Thinking can externalize the reasoning into an auditable, revisable thought chain. ST is **never required** — all workflows function identically without it.

### When to Activate ST

| Trigger | Example | ST Pattern |
|---------|---------|------------|
| Path A/B decision in restructuring | Phase 2 Socratic planning with ambiguous findings | Fork-Join |
| Iterative screenshot-fix cycle | Phase 3/4 validation revealing unexpected misalignment | TAO Loop + Revision |
| Multi-step diagnostic analysis | Phase 1 producing deviations across 3+ categories | Hypothesis Tracking |
| Code Handoff naming audit | Step 1 surfaces >5 ambiguous flags (CTA, 2XL, etc.) | TAO Loop |

### When to SKIP ST

- Simple create-screenshot-confirm flows (G1/G2 paths with <3 steps)
- Quick Audit with zero deviations found
- Single-tool operations (status check, navigate, search)

### Integration Rules

1. **TAO Loop**: Alternate `sequentialthinking` calls with Figma tool calls — never batch all thinking before all actions
2. **Checkpoint at phase boundary**: Before transitioning between phases, emit a checkpoint thought summarizing findings
3. **Revision on contradiction**: When `figma_take_screenshot` reveals a result contradicting the previous thought, use `isRevision: true`
4. **Circuit breaker at 15**: If a thought chain exceeds 15 steps within a single phase, checkpoint and request user guidance
5. **Max 3 fix cycles**: The existing max-3-screenshot-fix-cycles rule supersedes ST's dynamic horizon — never extend fix loops beyond 3

> Full rule set (6 rules including evidence-based progression): see `st-integration.md` Integration Rules Summary.

**Thought chain templates**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/st-integration.md`

## Compound Learning Protocol (Optional)

> **Location**: `~/.figma-console-mastery/learnings.md` (user-home, cross-project)
> **Full spec**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/compound-learning.md`

**Problem**: Effective strategies, API quirks, and workarounds discovered during Figma sessions are
lost when the session ends. The same issues are re-discovered in future sessions.

**Solution**: Persist field-discovered knowledge to a Markdown file at user-home, loaded at session
start and updated at session end. Learnings apply across all projects.

### When to Save (Triggers)

| Trigger | Category |
|---------|----------|
| >1 attempt to solve (retry with different approach) | API Quirks & Workarounds |
| Workaround discovered (standard approach failed) | API Quirks & Workarounds |
| Non-obvious recovery (beyond anti-patterns.md) | Error Recovery |
| Strategy significantly outperformed alternatives | Effective Strategies |
| Unexpected performance savings or costs | Performance Patterns |

### When NOT to Save

- Solution already in anti-patterns.md, SKILL.md, or other reference files
- Solution is trivial or covered by Essential Rules
- Solution is project-specific (not generalizable)
- Session had no retries, workarounds, or surprises

### Deduplication

Before appending, grep the learnings file for the proposed `### key`. If an exact match exists,
skip. Save 0-3 entries per session maximum.

### Session Integration

- **Phase 1 (Preflight)**: Read `~/.figma-console-mastery/learnings.md` if it exists; note
  entries relevant to the current task type by Tag matching
- **Phase 4 (Validation)**: Review session for triggers; compose and append 0-3 new entries
- **First session**: File does not exist — created when first learning is saved
- **Subagents**: Orchestrator injects relevant excerpts (max 3 entries) into subagent prompts;
  subagents never read/write the file directly

## Troubleshooting Quick Index

| Symptom | Quick Fix |
|---------|-----------|
| `figma_get_status` shows not connected | Guide user through plugin setup — see `references/gui-walkthroughs.md` |
| `figma_execute` returns empty/error | Wrap in async IIFE with try-catch; return plain data, not nodes |
| Font loading error | Call `figma.loadFontAsync({family, style})` before setting `.characters` |
| Layout properties silently ignored | Set `layoutMode = 'VERTICAL'` or `'HORIZONTAL'` BEFORE padding/spacing |
| Fill/stroke mutation fails | Clone array, modify clone, reassign (immutable reference pattern) |
| `figma_instantiate_component` silent fail | Verify variant property names match exactly (case-sensitive) |
| Screenshot shows misaligned elements | Check `layoutSizingHorizontal/Vertical` — use `'FILL'` instead of `'HUG'` for containers |
| Batch variable call fails | Verify `collectionId` is valid; max 100 per batch call |
| `figma_node_tree` exceeds token limit | Output can exceed 3MB on large files; use `figma_node_children` with targeted depth instead |
| Node IDs lost after context compaction | Re-read `operation-journal.jsonl` and `session-state.json` — see `convergence-protocol.md` Compact Recovery Protocol |
| System redoing already-completed work (regression) | Read `operation-journal.jsonl`, skip any operation already logged — see `convergence-protocol.md` Convergence Check |
| Console log buffer missing earlier results | Buffer holds ~100 entries; call `figma_clear_console` before each `figma_execute` batch |
| Components not appearing in screen instances | Components must be created (Phase 1) before screens (Phase 2); component integration is part of per-screen pipeline (Step 2.6) — see `workflow-draft-to-handoff.md` |
| Context compaction mid-workflow | Follow Compact Recovery Protocol: re-read journal + state files, rebuild completed-ops set, resume from first uncompleted operation — see `convergence-protocol.md` |
| Clone produces empty frame (0 children) | childCount validation gate: compare against Phase 0 inventory, retry once, halt if still 0 — see `workflow-draft-to-handoff.md` Step 2.2 |
| Prototype connections silently lost | GROUP nodes drop reactions silently; verify with `node.reactions` re-read after `setReactionsAsync` — see `workflow-draft-to-handoff.md` Phase 3 |
| Journal timestamps show impossible durations | Use `new Date().toISOString()` inside `figma_execute`; orchestrator injects real time for subagents — see `convergence-protocol.md` Journal Rule #9 |
| Component library exists but 0 instances in screens | Check TIER decision: for TIER 1, 0 instances is expected (no component creation). For TIER 2/3, component integration (Step 2.6) applies — audit at Phase 5. See `workflow-draft-to-handoff.md` and `workflow-code-handoff.md` TIER System |
| Same API error recurring across sessions | Load `~/.figma-console-mastery/learnings.md`; save workaround after resolving — see Compound Learning Protocol |
| Learnings file missing or empty | Normal for first session; created when first learning is saved. All workflows function identically without it |
| Constraints silently not applied after clone | 30-60% of cloned children are GROUP nodes — convert ALL to FRAMEs first. See `recipes-components.md` GROUP→FRAME recipe |
| `"object is not extensible"` on GROUP | Cannot set `constraints` on GROUP. Convert to transparent FRAME, then set constraints |
| `"node does not exist"` after moving GROUP children | GROUP auto-deletes when empty. Never call `group.remove()` — it's already gone |
| `createInstance()` fails on COMPONENT_SET | Find variant child first: `set.children.find(c => c.name.includes("State=Default"))`, then `variant.createInstance()` |
| Elements bunched at top/bottom after resize | Using uniform Y-shift instead of per-constraint formulas. See `recipes-foundation.md` Proportional Resize Calculator |
| Icons displaced below parent ellipse after clone | INSTANCE icons in GROUPs get displaced during resize. Check all INSTANCE positions after clone/resize operations |
| Screen looks like raw rectangle (no rounded corners) | Missing `cornerRadius = 32` + `clipsContent = true` — first step after clone. See Handoff Screen Checklist |
| Prototype conditional actions not working | Verify `actions` array (plural, not singular `action`). Use `CONDITIONAL` action type with `conditionalBlocks`. See `plugin-api.md` Conditional Prototyping section |
| Grid children not filling cells | Set `layoutSizingHorizontal = 'FILL'` on children. Use `gridRowGap`/`gridColumnGap` (not `itemSpacing`) for gaps |

**Full reference**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md`

## When NOT to Use This Skill

- **FigJam diagrams** — not supported by Console MCP or figma-use
- **Figma REST API / OAuth setup** — outside scope (Console MCP uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
- **figma-use without CDP** — JSX rendering, analysis, and diffing tools require
  Figma Desktop launched with `--remote-debugging-port=9222`

## Downstream Workflow (After This Skill)

> **Downstream compatibility**: Verified against Official Figma MCP Agent Skills (February 2026)

After completing the Code Handoff Protocol, the coding agent uses Official Figma
MCP Agent Skills to translate designs into code. For plan-specific rate limits and
tool availability, see `tool-playbook.md` (Three-Server Comparison).

- **Handoff Manifest** → `specs/figma/handoff-manifest.md` — generated during Code Handoff Protocol (Step 7). Contains screen inventory (node IDs), component-to-code mapping, token mapping. The coding agent reads this to locate screens and resolve component names without Code Connect
- **Generate CLAUDE.md rules** → `figma:create-design-system-rules` (any paid plan, Dev/Full seat)
- **Implement design as code** → `figma:implement-design` Agent Skill via `get_design_context` (any paid plan, Dev/Full seat)
- **Code Connect mappings** → `figma:code-connect-components` — automatic for UI kit components (Professional+); custom components require Organization/Enterprise. Without Enterprise, the Handoff Manifest + Smart Componentization (TIER 2) provides best-effort alignment
- **UX-NARRATIVE** → produced BEFORE handoff by `design-narration` skill (`product-definition` plugin). Pipeline: `refinement → design-narration → specification → handoff`. When available, feeds into Smart Componentization Gate 2 (behavioral variants) and is referenced in the Handoff Manifest for the coding agent. Recommended but not required — Gate 2 falls back to visual inspection without it
