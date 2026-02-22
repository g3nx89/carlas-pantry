# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 376 | Tool selection across 56+ tools, figma-console strategy, workflows, three-server comparison (Console / figma-use / Official), component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 1257 | Plugin API reference for `figma_execute` code (node creation, auto-layout, text, colors, images, components, variables, performance optimization, CSS Grid layout, expanded prototype reactions (triggers, actions, easing, overlays, conditionals), variable aliases and binding targets, Figma Draw APIs) | Writing `figma_execute` code |
| `design-rules.md` | 300 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes-foundation.md` | 535 | Foundation patterns (async IIFE wrapper with outer-return requirement, enum validation caveat, font preloading, node references, structured data), layout recipes (page container, horizontal row, wrap layout, absolute badge, CSS Grid card layout recipe), constraint patterns (reference table, proportional resize calculator) | Writing ANY `figma_execute` code (Tier 1 — always load) |
| `recipes-components.md` | 1401 | Component recipes: card, button, input, toast, navbar, sidebar, form, data table, empty state, modal, dashboard header, component variant set. Handoff patterns: GROUP→FRAME conversion (single + batch), componentize from clone, COMPONENT_SET variant instantiation | Building specific UI components (Tier 2 — by task) |
| `recipes-advanced.md` | 972 | Composition patterns (shell injection, library composition, design system bootstrap), advanced recipes (variable binding, variable alias chain recipe, effect/layout-grid variable binding recipe, SVG import, rich text), full page composition, chaining patterns, handoff preparation | Assembling multi-component layouts, full pages, advanced patterns, or code handoff (Tier 3 — by need) |
| `recipes-restructuring.md` | 1022 | Restructuring recipes: deep node tree analysis, repeated pattern detection, visual blueprint extraction, convert to auto-layout, reparent children, snap spacing, extract component, replace with library instance, variant sets, token binding, batch rename, Socratic question templates | Restructuring a freehand design — Path A (in-place) or Path B (reconstruction) (Tier 2 — by task) |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 355 | Error catalog, recurring API pattern errors, auto-layout pitfalls (FILL on frames, height-1 toggle fix, async silent failures), GROUP coordinate system, instance resize vs rescale, page-context reversion, console-log tripling, screenshot validation (capture vs take), session-level anti-patterns, handoff-specific anti-patterns, regression anti-patterns, performance anti-patterns, context and buffer anti-patterns, hard constraints, prototype anti-patterns, grid anti-patterns | Debugging or reviewing output |
| `gui-walkthroughs.md` | 141 | Step-by-step GUI instructions for Figma Desktop operations with no MCP/CLI equivalent: plugin setup, activation, cache refresh, node selection | Connection/setup issues requiring user interaction with Figma Desktop |
| `st-integration.md` | 537 | Sequential Thinking thought chain templates (Phase 1 Analysis, Path A/B Fork-Join, Visual Fidelity Loop, Naming Audit Reasoning, Iterative Refinement, Design System Bootstrap Checkpoint), activation protocol, suppress conditions, session protocol mapping | ST server available and workflow complexity warrants structured reasoning (Tier 3 — by need) |
| `workflow-restructuring.md` | 112 | Design Restructuring Workflow: 5-phase process (Analyze, Socratic Plan, Path A in-place / Path B reconstruction, Polish), visual fidelity gates, ST triggers, before/after metrics | Restructuring freehand designs (Tier 2 — by task) |
| `workflow-code-handoff.md` | 146 | Code Handoff Protocol: TIER system (componentization depth), Smart Componentization Criteria (3 gates), Handoff Manifest template, naming audit, token alignment, multi-platform notes, UX-NARRATIVE preceding input reference | Preparing designs for code implementation (Tier 2 — by task) |
| `convergence-protocol.md` | 571 | Operation Journal spec (append-only JSONL, 9 rules incl. real timestamps), anti-regression Convergence Check rules (7 rules), Batch Scripting Protocol (templates for rename/move/fill, when-to-batch decision matrix, token savings), Subagent Delegation Model (per-screen sequential architecture, skill-inheriting prompt template with 15 mandatory rules, 9 delegation rules), Session Snapshot schema v3, Compact Recovery Protocol | Any multi-step workflow — anti-regression, batch efficiency, subagent delegation (Tier 1 — always) |
| `compound-learning.md` | 209 | Compound Learning Protocol: learnings file format (H2 categories → H3 entries), file lifecycle, save protocol (5 auto-detect triggers), load protocol (Tag-based relevance matching), deduplication procedure, subagent integration (orchestrator-only reads/writes, filtered injection), initial file template | Cross-session knowledge persistence — load at Preflight, save at Validation (Tier 3 — by need) |

## Cross-References

| File | References |
|------|------------|
| `tool-playbook.md` | `plugin-api.md`, `anti-patterns.md`, `gui-walkthroughs.md` |
| `plugin-api.md` | `design-rules.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md`, `recipes-m3.md`, `anti-patterns.md`, external: `design-handoff` skill (product-definition plugin) |
| `design-rules.md` | `recipes-components.md`, `recipes-m3.md`, `plugin-api.md` |
| `recipes-foundation.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-components.md`, `recipes-advanced.md` |
| `recipes-components.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-advanced.md`, `recipes-m3.md` |
| `recipes-advanced.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-m3.md` |
| `recipes-restructuring.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md` |
| `recipes-m3.md` | `design-rules.md`, `plugin-api.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md` |
| `anti-patterns.md` | `plugin-api.md`, `design-rules.md`, `gui-walkthroughs.md`, external: `design-handoff` skill (product-definition plugin) |
| `gui-walkthroughs.md` | `anti-patterns.md`, `tool-playbook.md` |
| `st-integration.md` | `recipes-restructuring.md`, `recipes-advanced.md`, `tool-playbook.md` |
| `workflow-restructuring.md` | `recipes-restructuring.md`, `recipes-foundation.md`, `design-rules.md`, `recipes-components.md`, `recipes-advanced.md`, `st-integration.md`, `convergence-protocol.md` |
| `workflow-code-handoff.md` | `recipes-advanced.md`, `design-rules.md`, `st-integration.md`, `tool-playbook.md`, external: `design-narration` skill (product-definition plugin) |
| `convergence-protocol.md` | `anti-patterns.md`, `recipes-foundation.md`, `compound-learning.md` |
| `compound-learning.md` | `convergence-protocol.md`, `anti-patterns.md`, `SKILL.md` |

## Content Ownership (Deduplication)

Each topic lives in exactly one canonical file:

| Content | Canonical File |
|---------|---------------|
| Plugin API property tables | `plugin-api.md` |
| Node creation patterns | `plugin-api.md` |
| Image handling patterns | `plugin-api.md` |
| Tool parameter tables | `tool-playbook.md` |
| Error tables | `anti-patterns.md` |
| Auto-layout pitfalls (FILL on frames, height-1 toggle, async silent failures) | `anti-patterns.md` |
| Instance resize vs rescale | `anti-patterns.md` |
| Screenshot validation (figma_capture_screenshot vs figma_take_screenshot) | `anti-patterns.md` + `SKILL.md` |
| Page-context reversion between figma_execute calls | `anti-patterns.md` |
| Console-log 3x tripling | `anti-patterns.md` |
| M3 spec tables | `design-rules.md` |
| M3 code recipes | `recipes-m3.md` |
| Foundation patterns | `recipes-foundation.md` |
| Async IIFE return value requirement (outer return) | `recipes-foundation.md` |
| Layout recipes | `recipes-foundation.md` |
| Component recipes | `recipes-components.md` |
| GROUP→FRAME conversion recipes (single + batch) | `recipes-components.md` |
| Componentize from Clone recipe | `recipes-components.md` |
| COMPONENT_SET Variant Instantiation recipe | `recipes-components.md` |
| Constraint reference table, proportional resize calculator | `recipes-foundation.md` |
| Composition and advanced patterns | `recipes-advanced.md` |
| Restructuring patterns and Socratic question templates | `recipes-restructuring.md` |
| GUI walkthrough instructions | `gui-walkthroughs.md` |
| Handoff-specific anti-patterns (12 entries) | `anti-patterns.md` |
| Design Restructuring Workflow (5-phase, Path A/B) | `workflow-restructuring.md` |
| Code Handoff Protocol (naming audit, token alignment) | `workflow-code-handoff.md` |
| Operation Journal spec, JSONL format, entry types | `convergence-protocol.md` |
| Anti-regression Convergence Check rules (C1-C7) | `convergence-protocol.md` |
| Batch Scripting Protocol, script templates, when-to-batch | `convergence-protocol.md` |
| Subagent Delegation Model, skill-inheriting prompt template | `convergence-protocol.md` |
| Real timestamp requirement for journal entries | `convergence-protocol.md` |
| Compact Recovery Protocol | `convergence-protocol.md` |
| Regression anti-patterns | `anti-patterns.md` |
| Compound Learning Protocol, learnings file format, save/load rules | `compound-learning.md` |
| TIER system (componentization depth), Smart Componentization Criteria (3 gates) | `workflow-code-handoff.md` |
| Handoff Manifest template (`specs/figma/handoff-manifest.md`) | `workflow-code-handoff.md` |
| UX-NARRATIVE preceding input (design-narration skill, produced before handoff) | `workflow-code-handoff.md` |
| IMAGE fill limitation (design transfer) | `anti-patterns.md` (Hard Constraints) |
| ST thought chain templates for Figma workflows | `st-integration.md` |
| Three-server comparison (Console / figma-use / Official) | `tool-playbook.md` |
