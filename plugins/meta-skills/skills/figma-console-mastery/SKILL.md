---
name: figma-console-mastery
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", "use figma-console MCP", "automate Figma design", "create variables in Figma", "instantiate Figma component", "render JSX in Figma", "use figma_render", "use figma-use MCP", "analyze Figma design", "diff Figma designs", "query Figma nodes with XPath", or when developing skills/commands that use the Figma Console or figma-use MCP servers. Provides tool selection, Plugin API patterns, JSX rendering, design analysis, visual diffing, design rules, and selective reference loading for both MCP servers.
---

# Figma Console Mastery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Design creation via Console MCP + figma-use MCP (JSX rendering, analysis, diffing), plus Code Handoff Protocol for preparing designs for downstream code implementation. For the design-to-code pipeline after handoff, see the Downstream Workflow section.

## Overview

Two MCP servers work together: **figma-console** (Southleft, 56+ tools) for Plugin API access, variable CRUD, debugging, and screenshots; and **figma-use** (115+ declarative tools) for token-efficient creation, modification, analysis, and diffing. Both connect to Figma Desktop via different transports and coexist without conflict.

**Core principles**:
1. **figma-use-first** — use declarative tools for all atomic operations (create, modify, query); reserve `figma_execute` for complex conditional logic only
2. **Discover before creating** — check existing components/tokens before building from scratch
3. **Persist state** — write node IDs to a local file after each batch to survive context compaction
4. **Validate visually** — screenshot after every creation step (max 3 fix cycles)

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

### Phase 2 — Discovery
1. `figma_get_design_system_summary` → understand existing tokens, components, styles
2. `figma_get_variables(format="summary")` → catalog available variables
3. `figma_search_components` → find reusable components before building custom

### Phase 3 — Creation (figma-use-first)
1. **Compose first**: `figma_instantiate_component` for existing library components
2. **Create with figma-use**: `figma_create_frame`, `figma_create_text`, `figma_create_rect`, `figma_set_fill`, `figma_set_layout` for new elements
3. **Complex logic only**: `figma_execute` for multi-step async sequences (font loading + text + layout) or conditional logic
4. **Place in context**: Create Section/Frame containers; never leave nodes floating on canvas
5. **Apply tokens**: `figma_variable_bind` (figma-use) or `figma_execute` with `setBoundVariable()` for complex binding
6. **Persist state**: Write created node IDs to local file after each batch — see `workflow-draft-to-handoff.md`

### Phase 4 — Validation
1. `figma_take_screenshot` → visual check (max 3 screenshot-fix cycles)
2. Verify: alignment, spacing, proportions, visual hierarchy
3. Fix issues found, re-screenshot
4. `figma_generate_component_doc` → document created components

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

**Load**: `recipes-restructuring.md` (required for all paths), `recipes-foundation.md` (Tier 1), `design-rules.md` (for M3 specs and spacing rules). Path B (Reconstruction) additionally requires: `recipes-components.md`, `recipes-advanced.md` (Shell Injection, full-page assembly patterns).

### Phase 1 — Analyze

1. **Preflight** — `figma_get_status` → `figma_list_open_files` → `figma_navigate` to target page
2. **Screenshot** — `figma_take_screenshot` to capture the current state (before)
3. **Node tree scan** — `figma_get_file_for_plugin({ selectionOnly: true })` or full page scan
4. **Deep analysis** — run the Deep Node Tree Analysis recipe via `figma_execute` to catalog all deviations (missing auto-layout, hardcoded colors, non-4px spacing, generic names, flat hierarchies)
5. **Pattern detection** — run the Repeated Pattern Detection recipe to find component candidates
6. **Design system inventory** — `figma_get_design_system_summary` + `figma_get_variables(format="summary")` to understand available tokens and components
7. **Health baseline** — `figma_audit_design_system` for a 0-100 health score
8. **Compile findings** — structure the analysis results into a clear summary for Phase 2

> **ST trigger**: If Phase 1 found deviations in 3+ categories, activate ST with a 7-thought estimate. Use the Phase 1 Analysis template from [`st-integration.md#template-phase-1-analysis`] to structure hypothesis tracking across the 8 analysis steps.

> **Early exit**: If Phase 1 finds zero deviations across all categories, report "This design is already well-structured" with the health score and skip to Phase 5 for a final polish check.

### Phase 2 — Plan (Socratic)

Present the Phase 1 findings to the user and ask targeted Socratic questions. Use the question templates from `recipes-restructuring.md` (Socratic Questions section), filling in placeholders with actual data from Phase 1.

**Question categories** (ask in order, skip categories with no findings):
0. **Restructuring Approach** — Path A (in-place) or Path B (reconstruction)? Always ask first.
1. **Component Boundaries** — which repeated patterns should become components?
2. **Naming & Hierarchy** — what are the semantic sections? How should the layer tree be organized?
3. **Interaction Patterns** — which elements are interactive and need state variants?
4. **Token Strategy** — should a token system be created? Which colors to tokenize?
5. **Layout Direction** — confirm ambiguous auto-layout directions

**Output**: A confirmed conversion checklist with user-approved decisions. **Do not proceed to Phase 3 until the user approves the plan.**

> **ST trigger**: Use Fork-Join to evaluate Path A vs Path B before presenting to the user. Branch `path-a-eval` and `path-b-eval` from a synthesis thought, analyze trade-offs against Phase 1 findings, then synthesize a recommendation. See [`st-integration.md#template-path-ab-fork-join`].

---

### Path A — In-Place Modification

Use when the user chose Path A in Phase 2. Modifies the existing node tree directly. **Primary constraint: visual fidelity** — the design must look identical after restructuring.

### Phase 3A — Structure

1. **Extract blueprint** — run the Visual Blueprint Extraction recipe on the original design as a "before" reference snapshot for visual fidelity verification
2. **Reparent** — group logically related children using the Reparent Children recipe (innermost containers first, working outward)
3. **Auto-layout** — convert frames using the Convert Frame to Auto-Layout recipe (innermost-out order)
4. **Sizing modes** — set `layoutSizingHorizontal`/`layoutSizingVertical` (`FILL` for containers, `HUG` for content)
5. **Snap spacing** — run the Snap Spacing to 4px Grid recipe on the entire tree
6. **Rename** — apply semantic slash names using the Batch Rename recipe with user-approved naming from Phase 2
7. **Visual fidelity check** — `figma_take_screenshot` after each major structural change and compare against the blueprint. If a change shifts element positions, dimensions, or spacing, adjust until the visual output matches the original (max 3 fix cycles per change)

> **ST trigger**: During visual fidelity checks, use the TAO Loop: Thought (predict expected state) → Action (`figma_take_screenshot`) → Thought (compare against blueprint). If deviation detected, use `isRevision: true` before planning the fix. See [`st-integration.md#template-visual-fidelity-loop`].

> **ID tracking**: Several recipes in Phases 3A-4A create new nodes that replace originals (Extract Component, Replace with Library Instance, Reparent). Track new node IDs from recipe outputs — do not rely on IDs from the Phase 1 analysis after structural changes.

### Phase 4A — Componentize

1. **Library-first check** — `figma_search_components` for each element type identified in Phase 2
2. **Replace with instances** — use the Replace Element with Library Instance recipe for any existing library matches. Fidelity constraint: replacement must preserve size, color, and position of the original element
3. **Extract new components** — use the Extract Component from Frame recipe for user-confirmed new components
4. **Create variants** — if the user confirmed variant sets, use the Create Variant Set recipe
5. **Document** — `figma_set_description` on each new component with purpose and usage notes
6. **Validate** — `figma_take_screenshot` to confirm visual integrity after componentization

> After Phase 4A, proceed to **Phase 5 — Polish** below.

---

### Path B — Reconstruction

Use when the user chose Path B in Phase 2. Builds a new screen from scratch, visually faithful to the original. **Primary constraint: visual fidelity** — the new screen must look identical to the freehand original.

### Phase 3B — Extract Blueprint + Build New Screen

1. **Archive original** — if the user requested preservation, use `figma_move_node` to relocate the original frame to a reference section or separate page
2. **Extract blueprint** — run the Visual Blueprint Extraction recipe on the original frame to capture all visual properties as a hierarchical JSON blueprint
3. **Map to creation recipes** — using the blueprint, identify which elements map to which creation recipes:
   - Structural containers → `recipes-foundation.md` (Page Container, Horizontal Row, Wrap Layout)
   - Recognized UI patterns → `recipes-components.md` (Card, Button, Input, Navbar, Sidebar, Modal, etc.)
   - Multi-region page shells → `recipes-advanced.md` (Shell Injection pattern)
   - Custom elements with no recipe match → `figma_execute` with properties from blueprint
4. **Build root container** — create the new screen root using Page Container recipe, matching blueprint `width`/`height`
5. **Build layer by layer** — reconstruct from outermost container inward, applying auto-layout to every container from the start; use blueprint `layoutMode`, `itemSpacing`, and `padding*` values as targets (snapping to 4px grid)
6. **Reproduce visual properties** — apply `fills`, `cornerRadius`, `strokeWeight`, `opacity` from blueprint to each constructed node; for text nodes, apply `fontSize`, `fontName`, `lineHeight`, `letterSpacing`, `textAlignHorizontal`, and `characters`
7. **Integrate library components** — `figma_search_components` for each UI pattern; prefer library instances over custom builds where library components match the blueprint appearance
8. **Name semantically** — apply slash-convention names to all nodes as they are created (not as a post-processing step); use blueprint `name` values as starting hints, improved with user-approved naming from Phase 2
9. **Validate** — `figma_take_screenshot` after each major section is built and compare against the original screenshot from Phase 1 (max 3 fix cycles per section)

> Reconstruction is a single phase because building from scratch inherently applies auto-layout, components, and proper naming simultaneously. After Phase 3B, proceed directly to **Phase 5 — Polish** below.

---

### Phase 5 — Polish (Shared: Both Paths)

1. **Token binding** — bind hardcoded colors to tokens using Batch Token Binding recipe
   - If no tokens exist: offer to create them using Design System Bootstrap recipe from `recipes-advanced.md`, or skip if user prefers

> **ST trigger**: When creating a token system via Design System Bootstrap, activate ST with checkpoint thoughts at each phase boundary (Tokens → Components → Documentation). See [`st-integration.md#template-design-system-bootstrap-checkpoint`].
2. **Accessibility check** — verify contrast ratios, touch target sizes (48x48 minimum), text readability
3. **Final health score** — re-run `figma_audit_design_system` and compare to Phase 1 baseline
4. **Visual fidelity report** — compare the final result against the Phase 1 blueprint snapshot and flag any deviations (>2px position shift, different fill colors, missing elements)
5. **Before/after summary** — present the improvement metrics:
   - Health score: {before} → {after}
   - Auto-layout coverage: {before_pct}% → {after_pct}%
   - Token-bound colors: {before_count} → {after_count}
   - Named layers: {before_pct}% → {after_pct}%
   - Components used: {before_count} → {after_count}
   - Visual fidelity: {deviation_count} deviations flagged

## Code Handoff Protocol (Post-Session)

When the design session is complete and the design will be implemented as code,
run this protocol to prepare the Figma artifact for downstream consumption by the
coding agent. The coding agent uses `get_design_context` (Official MCP) to extract
framework-ready specs (React, SwiftUI, Compose, etc.) and the `implement-design`
Agent Skill to translate them into production code.

**How this compensates for missing Code Connect**: `get_design_context` returns
component names, variant properties, and descriptions. The naming conventions below
ensure these names match the codebase, allowing the coding agent to identify the
correct code component without Code Connect bidirectional mappings. This is
best-effort alignment — not equivalent to Code Connect. For full bidirectional
mapping of custom components, an Organization/Enterprise plan is required.

**Load**: `recipes-advanced.md` (Handoff Preparation Pattern)

1. **Naming audit** — run the Handoff Naming Audit recipe via `figma_execute` to
   check all components for non-PascalCase names and uppercase variant property keys
2. **Fix naming** — rename components to match the target codebase's component
   naming convention (typically PascalCase: `ProductCard`, not `product card`
   or `Frame 42`); rename variant property keys to lowercase (`size`, `variant`,
   `state`)
3. **Exception descriptions** — `figma_set_description` ONLY where the Figma name
   must differ from the code name:
   ```
   Code name: CallToActionButton
   Note: Figma name "CTA Button" differs for brevity
   ```
4. **Token alignment** — verify variable/token names correspond to the codebase
   token system (e.g., `color/primary/500` → `--color-primary-500`)
5. **UI kit preference** — where possible, compose with M3/Apple/SDS library
   components that have automatic Code Connect on Professional+ plans
6. **Health check** — `figma_audit_design_system` for final naming, token, and
   consistency scores

> **ST trigger**: When the naming audit (step 1) surfaces >5 issues with ambiguous false positives (CTA, 2XL, etc.), activate ST with a TAO Loop to reason through each flagged item: classify as true positive, false positive, or ambiguous. See [`st-integration.md#template-naming-audit-reasoning`].

> **Multi-platform**: the component name is the cross-platform contract. The coding
> agent for each platform searches its own codebase for a component matching the
> Figma name. `get_design_context` handles framework-specific translation. For
> components where platform names diverge (e.g., Figma `BottomNavigation` vs
> SwiftUI `TabView`), use step 3 exception descriptions with platform-specific
> code names.

> **Scope**: this protocol prepares the Figma artifact for downstream consumption.
> Actual code generation is performed by the `implement-design` Agent Skill via Official MCP.
> For plan-specific availability of downstream tools, see `tool-playbook.md`
> (Complementary Workflow).

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
7. **figma-use-first** — use declarative tools (`figma_create_*`, `figma_set_*`, `figma_node_*`) for all atomic operations; only fall back to `figma_execute` for complex conditional logic or multi-step async sequences
8. **Persist session state** — write created node IDs to a local file after each operation batch to survive context compaction (see `workflow-draft-to-handoff.md`)
9. **Respect broken tool blacklist** — never use `figma_status` or `figma_page_current` (figma-use, 100% failure); use `figma_node_children` instead of `figma_node_tree` on large files (>500 nodes)

### AVOID

1. **Never skip Discovery** — always check existing components/tokens before building from scratch
2. **Never mutate Figma arrays directly** — fills, strokes, effects are immutable references; clone, modify, reassign
3. **Never return raw Figma nodes** from `figma_execute` — return plain data: `{ id: node.id, name: node.name }`
4. **Never leave nodes floating on canvas** — always place inside a Section or Frame container
5. **Never use individual variable calls for bulk operations** — use `figma_batch_create_variables` / `figma_batch_update_variables` (10-50x faster)
6. **Never default to `figma_execute` for atomic operations** — each execute + console-logs pair costs ~2,000 tokens; use figma-use declarative tools instead (see `figma-use-overview.md` decision matrix)

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

# Draft-to-Handoff workflow — operational rules, 6-phase workflow, state persistence, error prevention
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-draft-to-handoff.md
```

### Loading Tiers

**Tier 1 — Always:** `recipes-foundation.md` (required for any `figma_execute` code), `figma-use-overview.md` (tool inventory + decision matrix + broken tools)
**Tier 2 — By task:** `recipes-components.md` | `recipes-restructuring.md` | `tool-playbook.md` | `plugin-api.md` | `design-rules.md` | `figma-use-jsx-patterns.md` | `figma-use-analysis.md` | `workflow-draft-to-handoff.md`
**Tier 3 — By need:** `recipes-advanced.md` | `recipes-m3.md` | `anti-patterns.md` | `gui-walkthroughs.md` | `figma-use-diffing.md` | `st-integration.md`

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
| `figma_status` or `figma_page_current` returns `"8"` | These figma-use tools are broken; use `figma_get_status` (figma-console) or `figma_page_list` |
| `figma_node_tree` exceeds token limit | Output can exceed 3MB on large files; use `figma_node_children` with targeted depth instead |
| Node IDs lost after context compaction | Write node IDs to local file after each batch — see `workflow-draft-to-handoff.md` Session State Persistence |
| Console log buffer missing earlier results | Buffer holds ~100 entries; call `figma_clear_console` before each `figma_execute` batch |
| Components not appearing in screen instances | Components must be created (Phase 1) before screens (Phase 2) — see `workflow-draft-to-handoff.md` |

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

- **Generate CLAUDE.md rules** → `figma:create-design-system-rules` (any paid plan, Dev/Full seat)
- **Implement design as code** → `figma:implement-design` Agent Skill via `get_design_context` (any paid plan, Dev/Full seat)
- **Code Connect mappings** → `figma:code-connect-components` — automatic for UI kit components (Professional+); custom components require Organization/Enterprise
