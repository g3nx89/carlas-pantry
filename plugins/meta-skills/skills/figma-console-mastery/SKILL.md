---
name: figma-console-mastery
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", or when developing skills/commands that use the Figma Console MCP server. Provides tool selection, Plugin API patterns, design rules, and selective reference loading for the figma-console-mcp server.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design CREATION via Console MCP. For design-to-code translation, see dev-skills `figma-implement-design`.

## Overview

The Figma Console MCP server (Southleft) exposes **56+ tools** in Local mode (~21 in Remote SSE) for autonomous design creation, variable management, and visual validation. The **power tool** is `figma_execute` — it runs arbitrary Figma Plugin API JavaScript, enabling anything the Plugin API supports.

**Core principle**: Discover existing design system assets before creating anything from scratch. Compose library components before building custom elements. Validate visually after every creation step.

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for all creation/mutation tools |

**Gate check**: Call `figma_get_status` before any operation. If transport shows `"not connected"`, the Bridge Plugin is not active — load `references/gui-walkthroughs.md` and guide the user through the setup steps.

**GUI-only operations**: Some tasks require direct interaction with the Figma Desktop application (plugin setup, activation, cache refresh, node selection, CDP transport, MCP Apps configuration). These have no MCP or CLI equivalent. See `references/gui-walkthroughs.md` for full step-by-step instructions. **When a task requires the user to interact with the Figma Desktop UI**, load `references/gui-walkthroughs.md` and relay the step-by-step instructions to the user.

## Quick Start

**Simple tasks** — invoke tools directly:
- **Check status** → `figma_get_status`
- **Find components** → `figma_search_components(query="Button")`
- **Place component** → `figma_instantiate_component(component_key, variant_properties)`
- **Create custom** → `figma_execute(code="(async () => { ... })()")`
- **Validate** → `figma_take_screenshot`

**Complex workflows** — load references as needed:
```
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md  # Which tool to call
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

### Phase 2 — Discovery
1. `figma_get_design_system_summary` → understand existing tokens, components, styles
2. `figma_get_variables(format="summary")` → catalog available variables
3. `figma_search_components` → find reusable components before building custom

### Phase 3 — Creation
1. **Compose first**: `figma_instantiate_component` for existing library components
2. **Build custom**: `figma_execute` for new elements (always with async IIFE + try-catch)
3. **Place in context**: Create Section/Frame containers; never leave nodes floating on canvas
4. **Apply tokens**: Bind variables to properties using `figma.variables.setBoundVariableForPaint`

### Phase 4 — Validation
1. `figma_take_screenshot` → visual check (max 3 screenshot-fix cycles)
2. Verify: alignment, spacing, proportions, visual hierarchy
3. Fix issues found, re-screenshot
4. `figma_generate_component_doc` → document created components

## Decision Matrix — Which Path to Take

Before picking a tool, determine the execution path through three gates:

| Gate | Question | Path | Primary Tool |
|------|----------|------|-------------|
| **G1: Exists?** | Is the element a standard atom (Button, Badge, Icon) likely in the Team Library? | **INSTANTIATE** | `figma_search_components` → `figma_instantiate_component` |
| **G2: Create?** | Is the request a novel layout, page, or composite organism not in the library? | **EXECUTE** | `figma_execute` (Plugin API code) |
| **G3: Modify?** | Is the intent to alter properties of an existing node (color, padding, text)? | **MODIFY** | `figma_get_selection` → `figma_execute` or specialized tool |

**Always evaluate G1 first.** Creating a button from scratch when one exists in the library wastes tokens, breaks design system consistency, and loses the instance-master link.

## Quick Audit Protocol (Alternative Session)

When the goal is to spot-fix specific deviations in an existing design rather than create new elements:

1. **Select target** — ask the user to select the frame or page to audit
2. **Scan** — `figma_get_file_for_plugin({ selectionOnly: true })` to get the node tree JSON
3. **Analyze** — look for deviations: hardcoded colors (no `boundVariables`), non-4px spacing, missing auto-layout, generic layer names
4. **Report** — use `figma_post_comment` or `figma_set_description` to annotate findings directly in the file
5. **Fix** — apply patches via `figma_execute`, targeting specific node IDs: `const n = await figma.getNodeByIdAsync("ID"); n.fills = [...]`
6. **Validate** — `figma_capture_screenshot` on the patched nodes to confirm corrections

For automated health scoring, use `figma_audit_design_system` which returns a 0-100 scorecard across naming, tokens, components, accessibility, consistency, and coverage.

> For comprehensive structural conversion of freehand designs into best-practice-compliant structures, use the Design Restructuring Workflow below instead.

## Design Restructuring Workflow (Alternative Session)

When the goal is to convert a freehand/unstructured design into a well-structured, best-practice-compliant design with auto-layout, components, naming conventions, and tokens. This is a collaborative, multi-phase process that uses Socratic questioning to define structure with the user rather than guessing.

**Load**: `recipes-restructuring.md` (required), `recipes-foundation.md` (Tier 1), `design-rules.md` (for M3 specs and spacing rules)

### Phase 1 — Analyze

1. **Preflight** — `figma_get_status` → `figma_list_open_files` → `figma_navigate` to target page
2. **Screenshot** — `figma_take_screenshot` to capture the current state (before)
3. **Node tree scan** — `figma_get_file_for_plugin({ selectionOnly: true })` or full page scan
4. **Deep analysis** — run the Deep Node Tree Analysis recipe via `figma_execute` to catalog all deviations (missing auto-layout, hardcoded colors, non-4px spacing, generic names, flat hierarchies)
5. **Pattern detection** — run the Repeated Pattern Detection recipe to find component candidates
6. **Design system inventory** — `figma_get_design_system_summary` + `figma_get_variables(format="summary")` to understand available tokens and components
7. **Health baseline** — `figma_audit_design_system` for a 0-100 health score
8. **Compile findings** — structure the analysis results into a clear summary for Phase 2

> **Early exit**: If Phase 1 finds zero deviations across all categories, report "This design is already well-structured" with the health score and skip to Phase 5 for a final polish check.

### Phase 2 — Plan (Socratic)

Present the Phase 1 findings to the user and ask targeted Socratic questions. Use the question templates from `recipes-restructuring.md` (Socratic Questions section), filling in placeholders with actual data from Phase 1.

**Question categories** (ask in order, skip categories with no findings):
1. **Component Boundaries** — which repeated patterns should become components?
2. **Naming & Hierarchy** — what are the semantic sections? How should the layer tree be organized?
3. **Interaction Patterns** — which elements are interactive and need state variants?
4. **Token Strategy** — should a token system be created? Which colors to tokenize?
5. **Layout Direction** — confirm ambiguous auto-layout directions

**Output**: A confirmed conversion checklist with user-approved decisions. **Do not proceed to Phase 3 until the user approves the plan.**

### Phase 3 — Structure

Apply structural fixes in this order (innermost containers first, working outward):

1. **Reparent** — group logically related children using the Reparent Children recipe
2. **Auto-layout** — convert frames using the Convert Frame to Auto-Layout recipe (innermost-out order)
3. **Sizing modes** — set `layoutSizingHorizontal`/`layoutSizingVertical` (`FILL` for containers, `HUG` for content)
4. **Snap spacing** — run the Snap Spacing to 4px Grid recipe on the entire tree
5. **Rename** — apply semantic slash names using the Batch Rename recipe with user-approved naming from Phase 2
6. **Validate** — `figma_take_screenshot` after each major structural change (max 3 fix cycles)

> **ID tracking**: Several recipes in Phases 3-4 create new nodes that replace originals (Extract Component, Replace with Library Instance, Reparent). Track new node IDs from recipe outputs — do not rely on IDs from the Phase 1 analysis after structural changes.

### Phase 4 — Componentize

1. **Library-first check** — `figma_search_components` for each element type identified in Phase 2
2. **Replace with instances** — use the Replace Element with Library Instance recipe for any existing library matches
3. **Extract new components** — use the Extract Component from Frame recipe for user-confirmed new components
4. **Create variants** — if the user confirmed variant sets, use the Create Variant Set recipe
5. **Document** — `figma_set_description` on each new component with purpose and usage notes
6. **Validate** — `figma_take_screenshot` to confirm visual integrity after componentization

### Phase 5 — Polish

1. **Token binding** — bind hardcoded colors to tokens using Batch Token Binding recipe
   - If no tokens exist: offer to create them using Design System Bootstrap recipe from `recipes-advanced.md`, or skip if user prefers
2. **Accessibility check** — verify contrast ratios, touch target sizes (48x48 minimum), text readability
3. **Final health score** — re-run `figma_audit_design_system` and compare to Phase 1 baseline
4. **Before/after summary** — present the improvement metrics:
   - Health score: {before} → {after}
   - Auto-layout coverage: {before_pct}% → {after_pct}%
   - Token-bound colors: {before_count} → {after_count}
   - Named layers: {before_pct}% → {after_pct}%
   - Components used: {before_count} → {after_count}

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
├── Component exists in library? → figma_search_components → figma_instantiate_component
├── Simple fill/stroke change?   → figma_set_fills / figma_set_strokes
├── Simple text change?          → figma_set_text
├── Custom element / layout?     → figma_execute (Plugin API code) ✓ POWER TOOL
└── Organize variants?           → figma_arrange_component_set

Need to manage variables/tokens?
├── Create token system?   → figma_setup_design_tokens (atomic, single call)
├── Create many variables? → figma_batch_create_variables (up to 100)
├── Update many values?    → figma_batch_update_variables (up to 100)
├── Single variable CRUD?  → figma_create/update/rename/delete_variable
└── Add/rename mode?       → figma_add_mode / figma_rename_mode

Need to manipulate existing nodes?
├── Move/reparent?  → figma_move_node
├── Resize?         → figma_resize_node
├── Rename?         → figma_rename_node
├── Clone?          → figma_clone_node
├── Delete?         → figma_delete_node
└── Add child?      → figma_create_child

Need to validate or debug?
├── Visual check?       → figma_take_screenshot (max 3 cycles)
├── Capture for report? → figma_capture_screenshot
├── Console errors?     → figma_get_console_logs / figma_watch_console
├── Design-code parity? → figma_check_design_parity
└── Document component? → figma_generate_component_doc
```

## Quick Reference — Core Tools

| Tool | Purpose |
|------|---------|
| `figma_get_status` | Verify connection (always first) |
| `figma_search_components` | Find library components before creating |
| `figma_instantiate_component` | Place component with variant properties |
| `figma_execute` | Run Plugin API code (power tool) |
| `figma_take_screenshot` | Visual validation (max 3 cycles) |

**Full tool reference** (all 56+ tools with parameters and pitfalls): `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md`

## Essential Rules

### MUST

1. **Call `figma_get_status` first** — gate check before any operation
2. **Wrap `figma_execute` in async IIFE with try-catch** — `(async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()`
3. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})` before any `.characters` assignment
4. **Set `layoutMode` before layout properties** — padding, spacing, constraints all require auto-layout to be active first
5. **Validate with screenshots** — take a screenshot after every creation step (max 3 fix cycles)
6. **Check before creating (idempotency)** — before creating a named node, check if it already exists: `figma.currentPage.findOne(n => n.name === "Target")`. Re-running a script must not produce duplicates

### AVOID

1. **Never skip Discovery** — always check existing components/tokens before building from scratch
2. **Never mutate Figma arrays directly** — fills, strokes, effects are immutable references; clone, modify, reassign
3. **Never return raw Figma nodes** from `figma_execute` — return plain data: `{ id: node.id, name: node.name }`
4. **Never leave nodes floating on canvas** — always place inside a Section or Frame container
5. **Never use individual variable calls for bulk operations** — use `figma_batch_create_variables` / `figma_batch_update_variables` (10-50x faster)

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
```

### Loading Tiers

**Tier 1 — Always:** `recipes-foundation.md` (required for any `figma_execute` code)
**Tier 2 — By task:** `recipes-components.md` | `recipes-restructuring.md` | `tool-playbook.md` | `plugin-api.md` | `design-rules.md`
**Tier 3 — By need:** `recipes-advanced.md` | `recipes-m3.md` | `anti-patterns.md` | `gui-walkthroughs.md`

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

**Full reference**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md`

## When NOT to Use This Skill

- **Design-to-code translation** — use dev-skills `figma-implement-design` (Official Figma MCP)
- **Code Connect mappings** — use dev-skills `figma-code-connect-components`
- **Design system rules for code** — use dev-skills `figma-create-design-system-rules`
- **FigJam diagrams** — not supported by Console MCP
- **Figma REST API / OAuth setup** — outside scope (Console MCP uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
