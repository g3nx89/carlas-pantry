# Design Restructuring Workflow

> **Cross-references**: `recipes-restructuring.md` (all restructuring recipes + Socratic question templates), `recipes-foundation.md` (Tier 1), `design-rules.md` (M3 specs + spacing rules), `recipes-components.md` + `recipes-advanced.md` (Path B), `st-integration.md` (thought chain templates), `convergence-protocol.md` (journal + convergence checks)

When the goal is to convert a freehand/unstructured design into a well-structured, best-practice-compliant design with auto-layout, components, naming conventions, and tokens. This is a collaborative, multi-phase process that uses Socratic questioning to define structure with the user rather than guessing.

**Load**: `recipes-restructuring.md` (required for all paths), `recipes-foundation.md` (Tier 1), `design-rules.md` (for M3 specs and spacing rules). Path B (Reconstruction) additionally requires: `recipes-components.md`, `recipes-advanced.md` (Shell Injection, full-page assembly patterns).

## Phase 1 — Analyze

1. **Preflight** — `figma_get_status` -> `figma_list_open_files` -> `figma_navigate` to target page
2. **Screenshot** — `figma_take_screenshot` to capture the current state (before)
3. **Node tree scan** — `figma_get_file_for_plugin({ selectionOnly: true })` or full page scan
4. **Deep analysis** — run the Deep Node Tree Analysis recipe via `figma_execute` to catalog all deviations (missing auto-layout, hardcoded colors, non-4px spacing, generic names, flat hierarchies)
5. **Pattern detection** — run the Repeated Pattern Detection recipe to find component candidates
6. **Design system inventory** — `figma_get_design_system_summary` + `figma_get_variables(format="summary")` to understand available tokens and components
7. **Health baseline** — `figma_audit_design_system` for a 0-100 health score
8. **Compile findings** — structure the analysis results into a clear summary for Phase 2

> **ST trigger**: If Phase 1 found deviations in 3+ categories, activate ST with a 7-thought estimate. Use the Phase 1 Analysis template from [`st-integration.md#template-phase-1-analysis`] to structure hypothesis tracking across the 8 analysis steps.

> **Early exit**: If Phase 1 finds zero deviations across all categories, report "This design is already well-structured" with the health score and skip to Phase 5 for a final polish check.

## Phase 2 — Plan (Socratic)

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

## Path A — In-Place Modification

Use when the user chose Path A in Phase 2. Modifies the existing node tree directly. **Primary constraint: visual fidelity** — the design must look identical after restructuring.

### Phase 3A — Structure

1. **Extract blueprint** — run the Visual Blueprint Extraction recipe on the original design as a "before" reference snapshot for visual fidelity verification
2. **Reparent** — group logically related children using the Reparent Children recipe (innermost containers first, working outward)
3. **Auto-layout** — convert frames using the Convert Frame to Auto-Layout recipe (innermost-out order)
4. **Sizing modes** — set `layoutSizingHorizontal`/`layoutSizingVertical` (`FILL` for containers, `HUG` for content)
5. **Snap spacing** — run the Snap Spacing to 4px Grid recipe on the entire tree
6. **Rename** — apply semantic slash names using the Batch Rename recipe with user-approved naming from Phase 2
7. **Visual fidelity check** — `figma_take_screenshot` after each major structural change and compare against the blueprint. If a change shifts element positions, dimensions, or spacing, adjust until the visual output matches the original (max 3 fix cycles per change)

> **ST trigger**: During visual fidelity checks, use the TAO Loop: Thought (predict expected state) -> Action (`figma_take_screenshot`) -> Thought (compare against blueprint). If deviation detected, use `isRevision: true` before planning the fix. See [`st-integration.md#template-visual-fidelity-loop`].

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

## Path B — Reconstruction

Use when the user chose Path B in Phase 2. Builds a new screen from scratch, visually faithful to the original. **Primary constraint: visual fidelity** — the new screen must look identical to the freehand original.

### Phase 3B — Extract Blueprint + Build New Screen

1. **Archive original** — if the user requested preservation, use `figma_move_node` to relocate the original frame to a reference section or separate page
2. **Extract blueprint** — run the Visual Blueprint Extraction recipe on the original frame to capture all visual properties as a hierarchical JSON blueprint
3. **Map to creation recipes** — using the blueprint, identify which elements map to which creation recipes:
   - Structural containers -> `recipes-foundation.md` (Page Container, Horizontal Row, Wrap Layout)
   - Recognized UI patterns -> `recipes-components.md` (Card, Button, Input, Navbar, Sidebar, Modal, etc.)
   - Multi-region page shells -> `recipes-advanced.md` (Shell Injection pattern)
   - Custom elements with no recipe match -> `figma_execute` with properties from blueprint
4. **Build root container** — create the new screen root using Page Container recipe, matching blueprint `width`/`height`
5. **Build layer by layer** — reconstruct from outermost container inward, applying auto-layout to every container from the start; use blueprint `layoutMode`, `itemSpacing`, and `padding*` values as targets (snapping to 4px grid)
6. **Reproduce visual properties** — apply `fills`, `cornerRadius`, `strokeWeight`, `opacity` from blueprint to each constructed node; for text nodes, apply `fontSize`, `fontName`, `lineHeight`, `letterSpacing`, `textAlignHorizontal`, and `characters`
7. **Integrate library components** — `figma_search_components` for each UI pattern; prefer library instances over custom builds where library components match the blueprint appearance
8. **Name semantically** — apply slash-convention names to all nodes as they are created (not as a post-processing step); use blueprint `name` values as starting hints, improved with user-approved naming from Phase 2
9. **Validate** — `figma_take_screenshot` after each major section is built and compare against the original screenshot from Phase 1 (max 3 fix cycles per section)

> Reconstruction is a single phase because building from scratch inherently applies auto-layout, components, and proper naming simultaneously. After Phase 3B, proceed directly to **Phase 5 — Polish** below.

---

## Phase 5 — Polish (Shared: Both Paths)

1. **Token binding** — bind hardcoded colors to tokens using Batch Token Binding recipe
   - If no tokens exist: offer to create them using Design System Bootstrap recipe from `recipes-advanced.md`, or skip if user prefers

> **ST trigger**: When creating a token system via Design System Bootstrap, activate ST with checkpoint thoughts at each phase boundary (Tokens -> Components -> Documentation). See [`st-integration.md#template-design-system-bootstrap-checkpoint`].
2. **Accessibility check** — verify contrast ratios, touch target sizes (48x48 minimum), text readability
3. **Final health score** — re-run `figma_audit_design_system` and compare to Phase 1 baseline
4. **Visual fidelity report** — compare the final result against the Phase 1 blueprint snapshot and flag any deviations (>2px position shift, different fill colors, missing elements)
5. **Before/after summary** — present the improvement metrics:
   - Health score: {before} -> {after}
   - Auto-layout coverage: {before_pct}% -> {after_pct}%
   - Token-bound colors: {before_count} -> {after_count}
   - Named layers: {before_pct}% -> {after_pct}%
   - Components used: {before_count} -> {after_count}
   - Visual fidelity: {deviation_count} deviations flagged
