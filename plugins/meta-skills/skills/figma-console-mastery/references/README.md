# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 376 | Tool selection across 56+ tools, figma-use-first vs figma_execute strategy, workflows, three-server comparison (Console / figma-use / Official), component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 1257 | Plugin API reference for `figma_execute` code (node creation, auto-layout, text, colors, images, components, variables, performance optimization, CSS Grid layout, expanded prototype reactions (triggers, actions, easing, overlays, conditionals), variable aliases and binding targets, Figma Draw APIs) | Writing `figma_execute` code |
| `design-rules.md` | 300 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes-foundation.md` | 531 | Foundation patterns (IIFE wrapper with async IIFE return warning, font preloading, node references, structured data), layout recipes (page container, horizontal row, wrap layout, absolute badge, CSS Grid card layout recipe), constraint patterns (reference table, proportional resize calculator) | Writing ANY `figma_execute` code (Tier 1 — always load) |
| `recipes-components.md` | 1401 | Component recipes: card, button, input, toast, navbar, sidebar, form, data table, empty state, modal, dashboard header, component variant set. Handoff patterns: GROUP→FRAME conversion (single + batch), componentize from clone, COMPONENT_SET variant instantiation | Building specific UI components (Tier 2 — by task) |
| `recipes-advanced.md` | 972 | Composition patterns (shell injection, library composition, design system bootstrap), advanced recipes (variable binding, variable alias chain recipe, effect/layout-grid variable binding recipe, SVG import, rich text), full page composition, chaining patterns, handoff preparation | Assembling multi-component layouts, full pages, advanced patterns, or code handoff (Tier 3 — by need) |
| `recipes-restructuring.md` | 1022 | Restructuring recipes: deep node tree analysis, repeated pattern detection, visual blueprint extraction (full visual properties + effects + instance metadata), convert to auto-layout, reparent children, snap spacing, extract component, replace with library instance, variant sets, token binding, batch rename, Socratic question templates (restructuring approach, component boundaries, naming, interaction, tokens, layout) | Restructuring a freehand design — Path A (in-place) or Path B (reconstruction) (Tier 2 — by task) |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 308 | Error catalog, recurring API pattern errors, regression anti-patterns, context and buffer anti-patterns, IMAGE fill limitation, text-building anti-patterns, prototype anti-patterns, grid layout anti-patterns, handoff-specific anti-patterns (constraints on GROUP, group.remove(), variant fidelity, batch processing), debugging, hard constraints, rate limiting, performance anti-patterns, idempotency | Debugging or reviewing output |
| `gui-walkthroughs.md` | 141 | Step-by-step GUI instructions for Figma Desktop operations with no MCP/CLI equivalent: plugin setup, activation, cache refresh, node selection, CDP transport, MCP Apps | Connection/setup issues requiring user interaction with Figma Desktop |
| `figma-use-overview.md` | 380 | figma-use server architecture, CDP setup, known broken/risky tools, 115+ tool inventory, decision matrix (figma-use vs Console vs both), performance characteristics (code-verified), limitations, 1.0 migration checklist | Any figma-use task — start here (Tier 1 — always) |
| `figma-use-jsx-patterns.md` | 385 | JSX rendering via `figma_render`, shorthand props reference, Plugin API → JSX translation table, CSS Grid (expanded Grid JSX props), Iconify icons, complex single-call composition, round-trip editing, common gotchas | Rendering JSX in Figma, complex multi-node compositions (Tier 2 — by task) |
| `figma-use-analysis.md` | 257 | Dedicated `figma_analyze_*` commands (clusters, colors, typography, spacing, snapshot), restructuring workflow integration, dual-server analysis workflow | Analyzing or auditing existing designs without writing code (Tier 2 — by task) |
| `figma-use-diffing.md` | 298 | Visual/property/JSX diffing, XPath 3.1 queries (`figma_query`), boolean operations, vector path manipulation, arrange algorithms, Storybook export, comment-driven workflows | Diffing designs, XPath queries, boolean ops, vector paths, specialty operations (Tier 3 — by need) |
| `st-integration.md` | 537 | Sequential Thinking thought chain templates (Phase 1 Analysis, Path A/B Fork-Join, Visual Fidelity Loop, Naming Audit Reasoning, Iterative Refinement, Design System Bootstrap Checkpoint), activation protocol, suppress conditions, session protocol mapping | ST server available and workflow complexity warrants structured reasoning (Tier 3 — by need) |
| `workflow-restructuring.md` | 112 | Design Restructuring Workflow: 5-phase process (Analyze, Socratic Plan, Path A in-place / Path B reconstruction, Polish), visual fidelity gates, ST triggers, before/after metrics | Restructuring freehand designs (Tier 2 — by task) |
| `workflow-code-handoff.md` | 146 | Code Handoff Protocol: TIER system (componentization depth), Smart Componentization Criteria (3 gates), Handoff Manifest template, naming audit, token alignment, multi-platform notes, UX-NARRATIVE preceding input reference | Preparing designs for code implementation (Tier 2 — by task) |
| `workflow-draft-to-handoff.md` | 868 | Draft-to-Handoff workflow: 8 critical principles (one-screen-at-a-time, smart-componentization, ask-user-when-in-doubt), simplified entry point, 28 operational rules (incl. GROUP→FRAME, viewport/scrollable, 9-step checklist, per-variant fidelity), Smart Componentization Analysis (Step 0.5), TIER-gated Phase 1 + Step 2.6, per-screen progress reporting, per-screen rollback protocol, dual-layer state persistence v3, 6-phase workflow with per-screen pipeline (screen analysis → user decision gate → clone → childCount gate → frame setup → GROUP→FRAME conversion → constraints + proportional resize → component integration → visual validation → user approval → completion), Handoff Screen Mandatory Checklist (9 steps), Viewport vs Scrollable reference table, Handoff Manifest generation (Step 5.2), preflight existing content declaration, GROUP prototype verification, error prevention (34 entries), source access failure protocol | Converting hand-designed drafts into structured handoff pages (Tier 2 — by task) |
| `convergence-protocol.md` | 571 | Operation Journal spec (append-only JSONL, 9 rules incl. real timestamps), anti-regression Convergence Check rules (7 rules), Batch Scripting Protocol (templates for rename/move/fill, when-to-batch decision matrix, token savings), Subagent Delegation Model (per-screen sequential architecture, skill-inheriting prompt template with 15 mandatory rules, 9 delegation rules), Session Snapshot schema v3 (childCount, instance_count, connections breakdown), Compact Recovery Protocol | Any multi-step workflow — anti-regression, batch efficiency, subagent delegation (Tier 1 — always) |
| `compound-learning.md` | 209 | Compound Learning Protocol: learnings file format (H2 categories → H3 entries), file lifecycle, save protocol (5 auto-detect triggers), load protocol (Tag-based relevance matching), deduplication procedure, subagent integration (orchestrator-only reads/writes, filtered injection), initial file template | Cross-session knowledge persistence — load at Preflight, save at Validation (Tier 3 — by need) |

## Cross-References

| File | References |
|------|------------|
| `tool-playbook.md` | `plugin-api.md`, `anti-patterns.md`, `gui-walkthroughs.md`, `figma-use-overview.md` |
| `plugin-api.md` | `design-rules.md`, `recipes-foundation.md`, `recipes-components.md`, `recipes-advanced.md`, `recipes-m3.md`, `anti-patterns.md`, `figma-use-jsx-patterns.md` (Grid JSX props) |
| `design-rules.md` | `recipes-components.md`, `recipes-m3.md`, `plugin-api.md` |
| `recipes-foundation.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-components.md`, `recipes-advanced.md`, `workflow-draft-to-handoff.md` |
| `recipes-components.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-foundation.md`, `recipes-advanced.md`, `recipes-m3.md`, `workflow-draft-to-handoff.md` |
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
| `workflow-restructuring.md` | `recipes-restructuring.md`, `recipes-foundation.md`, `design-rules.md`, `recipes-components.md`, `recipes-advanced.md`, `st-integration.md`, `convergence-protocol.md` |
| `workflow-code-handoff.md` | `recipes-advanced.md`, `design-rules.md`, `st-integration.md`, `tool-playbook.md`, external: `design-narration` skill (product-definition plugin) |
| `workflow-draft-to-handoff.md` | `anti-patterns.md` (bidirectional), `figma-use-overview.md`, `tool-playbook.md`, `plugin-api.md`, `convergence-protocol.md` (bidirectional), `recipes-components.md`, `recipes-foundation.md` |
| `convergence-protocol.md` | `workflow-draft-to-handoff.md` (bidirectional), `anti-patterns.md`, `figma-use-overview.md`, `recipes-foundation.md`, `compound-learning.md` |
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
| Code-readiness SHOULD rules (#11-15) | `design-rules.md` |
| ST thought chain templates for Figma workflows | `st-integration.md` |
| Draft-to-Handoff workflow, operational rules, session state persistence | `workflow-draft-to-handoff.md` |
| Per-screen pipeline (analyze → user gate → clone → validate → frame setup → GROUP→FRAME → constraints → components → visual diff → approval) | `workflow-draft-to-handoff.md` |
| childCount validation gate, component integration per screen | `workflow-draft-to-handoff.md` |
| Preflight existing content declaration, GROUP prototype verification | `workflow-draft-to-handoff.md` |
| IMAGE fill limitation (design transfer) | `anti-patterns.md` (Hard Constraints), cross-referenced in `plugin-api.md` and `workflow-draft-to-handoff.md` |
| Clone-first architecture, visual fidelity gates | `workflow-draft-to-handoff.md` |
| GROUP→FRAME conversion recipes (single + batch) | `recipes-components.md` |
| Componentize from Clone recipe | `recipes-components.md` |
| COMPONENT_SET Variant Instantiation recipe | `recipes-components.md` |
| Constraint reference table, proportional resize calculator | `recipes-foundation.md` |
| Handoff-specific anti-patterns (10 entries) | `anti-patterns.md` |
| Handoff Screen Mandatory Checklist (9 steps) | `workflow-draft-to-handoff.md` |
| Viewport vs Scrollable screen types | `workflow-draft-to-handoff.md` |
| Screen Analysis + User Decision Gate (Steps 2.0/2.0B) | `workflow-draft-to-handoff.md` |
| Design Restructuring Workflow (5-phase, Path A/B) | `workflow-restructuring.md` |
| Code Handoff Protocol (naming audit, token alignment) | `workflow-code-handoff.md` |
| Operation Journal spec, JSONL format, entry types | `convergence-protocol.md` |
| Anti-regression Convergence Check rules (C1-C7) | `convergence-protocol.md` |
| Batch Scripting Protocol, script templates, when-to-batch | `convergence-protocol.md` |
| Subagent Delegation Model, skill-inheriting prompt template, per-screen delegation rules | `convergence-protocol.md` |
| Real timestamp requirement for journal entries | `convergence-protocol.md` |
| Compact Recovery Protocol | `convergence-protocol.md` |
| Regression anti-patterns | `anti-patterns.md` |
| Compound Learning Protocol, learnings file format, save/load rules | `compound-learning.md` |
| TIER system (componentization depth), Smart Componentization Criteria (3 gates) | `workflow-code-handoff.md` |
| Handoff Manifest template (`specs/figma/handoff-manifest.md`) | `workflow-code-handoff.md` |
| UX-NARRATIVE preceding input (design-narration skill, produced before handoff) | `workflow-code-handoff.md` |
