# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 376 | Tool selection across 56+ tools, figma-use-first vs figma_execute strategy, workflows, three-server comparison (Console / figma-use / Official), component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 709 | Plugin API reference for `figma_execute` code (node creation, auto-layout, text, colors, images, components, variables, performance optimization) | Writing `figma_execute` code |
| `design-rules.md` | 299 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes-foundation.md` | 298 | Foundation patterns (IIFE wrapper, font preloading, node references, structured data) and layout recipes (page container, horizontal row, wrap layout, absolute badge) | Writing ANY `figma_execute` code (Tier 1 — always load) |
| `recipes-components.md` | 1077 | Component recipes: card, button, input, toast, navbar, sidebar, form, data table, empty state, modal, dashboard header, component variant set | Building specific UI components (Tier 2 — by task) |
| `recipes-advanced.md` | 854 | Composition patterns (shell injection, library composition, design system bootstrap), advanced recipes (variable binding, SVG import, rich text), full page composition, chaining patterns, handoff preparation | Assembling multi-component layouts, full pages, advanced patterns, or code handoff (Tier 3 — by need) |
| `recipes-restructuring.md` | 1022 | Restructuring recipes: deep node tree analysis, repeated pattern detection, visual blueprint extraction (full visual properties + effects + instance metadata), convert to auto-layout, reparent children, snap spacing, extract component, replace with library instance, variant sets, token binding, batch rename, Socratic question templates (restructuring approach, component boundaries, naming, interaction, tokens, layout) | Restructuring a freehand design — Path A (in-place) or Path B (reconstruction) (Tier 2 — by task) |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 240 | Error catalog, recurring API pattern errors, context and buffer anti-patterns, IMAGE fill limitation, text-building anti-patterns, debugging, hard constraints, rate limiting, performance anti-patterns, idempotency | Debugging or reviewing output |
| `gui-walkthroughs.md` | 141 | Step-by-step GUI instructions for Figma Desktop operations with no MCP/CLI equivalent: plugin setup, activation, cache refresh, node selection, CDP transport, MCP Apps | Connection/setup issues requiring user interaction with Figma Desktop |
| `figma-use-overview.md` | 380 | figma-use server architecture, CDP setup, known broken/risky tools, 115+ tool inventory, decision matrix (figma-use vs Console vs both), performance characteristics (code-verified), limitations, 1.0 migration checklist | Any figma-use task — start here (Tier 1 — always) |
| `figma-use-jsx-patterns.md` | 365 | JSX rendering via `figma_render`, shorthand props reference, Plugin API → JSX translation table, CSS Grid, Iconify icons, complex single-call composition, round-trip editing, common gotchas | Rendering JSX in Figma, complex multi-node compositions (Tier 2 — by task) |
| `figma-use-analysis.md` | 257 | Dedicated `figma_analyze_*` commands (clusters, colors, typography, spacing, snapshot), restructuring workflow integration, dual-server analysis workflow | Analyzing or auditing existing designs without writing code (Tier 2 — by task) |
| `figma-use-diffing.md` | 298 | Visual/property/JSX diffing, XPath 3.1 queries (`figma_query`), boolean operations, vector path manipulation, arrange algorithms, Storybook export, comment-driven workflows | Diffing designs, XPath queries, boolean ops, vector paths, specialty operations (Tier 3 — by need) |
| `st-integration.md` | 537 | Sequential Thinking thought chain templates (Phase 1 Analysis, Path A/B Fork-Join, Visual Fidelity Loop, Naming Audit Reasoning, Iterative Refinement, Design System Bootstrap Checkpoint), activation protocol, suppress conditions, session protocol mapping | ST server available and workflow complexity warrants structured reasoning (Tier 3 — by need) |
| `workflow-draft-to-handoff.md` | 415 | Draft-to-Handoff workflow: 4 critical principles, simplified entry point, 15 operational rules, progress reporting, rollback protocol, session state persistence, 6-phase workflow (Deep Inventory, Component Library, Screen Transfer with clone-first + mandatory diff gates, Prototype Wiring, Annotations, Validation), error prevention, source access failure protocol | Converting hand-designed drafts into structured handoff pages (Tier 2 — by task) |

## Cross-References

| File | References |
|------|------------|
| `tool-playbook.md` | `plugin-api.md`, `anti-patterns.md`, `gui-walkthroughs.md`, `figma-use-overview.md` |
| `plugin-api.md` | `design-rules.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md`, `recipes-m3.md`, `anti-patterns.md` |
| `design-rules.md` | `recipes-components.md`, `recipes-m3.md`, `plugin-api.md` |
| `recipes-foundation.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-components.md`, `recipes-advanced.md` |
| `recipes-components.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-advanced.md`, `recipes-m3.md` |
| `recipes-advanced.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-m3.md` |
| `recipes-restructuring.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md` |
| `recipes-m3.md` | `design-rules.md`, `plugin-api.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md` |
| `anti-patterns.md` | `plugin-api.md`, `design-rules.md`, `gui-walkthroughs.md`, `figma-use-overview.md`, `workflow-draft-to-handoff.md` (bidirectional) |
| `gui-walkthroughs.md` | `anti-patterns.md`, `tool-playbook.md` |
| `figma-use-overview.md` | `gui-walkthroughs.md`, `figma-use-jsx-patterns.md`, `figma-use-analysis.md`, `figma-use-diffing.md` |
| `figma-use-jsx-patterns.md` | `figma-use-overview.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md`, `plugin-api.md`, `design-rules.md` |
| `figma-use-analysis.md` | `figma-use-overview.md`, `recipes-restructuring.md`, `figma-use-diffing.md` |
| `figma-use-diffing.md` | `figma-use-overview.md`, `figma-use-analysis.md`, `figma-use-jsx-patterns.md`, `recipes-restructuring.md` |
| `st-integration.md` | `recipes-restructuring.md`, `recipes-advanced.md`, `tool-playbook.md` |
| `workflow-draft-to-handoff.md` | `anti-patterns.md` (bidirectional), `figma-use-overview.md`, `tool-playbook.md`, `plugin-api.md` |

## Content Ownership (Deduplication)

Each topic lives in exactly one canonical file:

| Content | Canonical File |
|---------|---------------|
| Plugin API property tables | `plugin-api.md` |
| Node creation patterns | `plugin-api.md` |
| Image handling patterns | `plugin-api.md` |
| Tool parameter tables | `tool-playbook.md` |
| Error tables | `anti-patterns.md` |
| M3 spec tables | `design-rules.md` |
| M3 code recipes | `recipes-m3.md` |
| Foundation patterns | `recipes-foundation.md` |
| Layout recipes | `recipes-foundation.md` |
| Component recipes | `recipes-components.md` |
| Composition and advanced patterns | `recipes-advanced.md` |
| Restructuring patterns and Socratic question templates | `recipes-restructuring.md` |
| GUI walkthrough instructions | `gui-walkthroughs.md` |
| figma-use architecture, setup, tool inventory, decision matrix | `figma-use-overview.md` |
| JSX rendering patterns, shorthand props, translation table | `figma-use-jsx-patterns.md` |
| figma_analyze_* parameters, output shapes, dual-server workflow | `figma-use-analysis.md` |
| figma_diff_*, figma_query, boolean ops, vector paths, arrange | `figma-use-diffing.md` |
| Three-server comparison (Console / figma-use / Official) | `tool-playbook.md` |
| Two-server decision matrix (figma-use vs figma-console) | `figma-use-overview.md` |
| Handoff preparation pattern and naming audit recipe | `recipes-advanced.md` |
| Code-readiness SHOULD rules (#11-14) | `design-rules.md` |
| ST thought chain templates for Figma workflows | `st-integration.md` |
| Draft-to-Handoff workflow, operational rules, session state persistence | `workflow-draft-to-handoff.md` |
| IMAGE fill limitation (design transfer) | `anti-patterns.md` (Hard Constraints), cross-referenced in `plugin-api.md` and `workflow-draft-to-handoff.md` |
| Clone-first architecture, visual fidelity gates | `workflow-draft-to-handoff.md` |
