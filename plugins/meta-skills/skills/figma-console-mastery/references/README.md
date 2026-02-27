# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 403 | Tool selection decision tree, quick reference core tools, tool categories across 60 tools, figma-console-only strategy, component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 1308 | Plugin API reference for `figma_execute` code (node creation, auto-layout, text, colors, images, components, variables, performance optimization, CSS Grid layout, expanded prototype reactions, variable aliases and binding targets, Figma Draw APIs) | Writing `figma_execute` code |
| `design-rules.md` | 299 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes-foundation.md` | 534 | Foundation patterns (async IIFE wrapper with outer-return requirement, enum validation caveat, font preloading, node references, structured data), layout recipes (page container, horizontal row, wrap layout, absolute badge, CSS Grid card layout recipe), constraint patterns (reference table, proportional resize calculator) | Writing ANY `figma_execute` code (Tier 1 — always load) |
| `recipes-components.md` | 1401 | Component recipes: card, button, input, toast, navbar, sidebar, form, data table, empty state, modal, dashboard header, component variant set. Handoff patterns: GROUP-to-FRAME conversion (single + batch), componentize from clone, COMPONENT_SET variant instantiation | Building specific UI components (Tier 2 — by task) |
| `recipes-advanced.md` | 974 | Composition patterns (shell injection, library composition, design system bootstrap), advanced recipes (variable binding, variable alias chain, effect/layout-grid variable binding, SVG import, rich text), full page composition, chaining patterns, handoff preparation | Assembling multi-component layouts, full pages, advanced patterns, or code handoff (Tier 3 — by need) |
| `recipes-restructuring.md` | 1022 | Restructuring recipes: deep node tree analysis, repeated pattern detection, visual blueprint extraction, convert to auto-layout, reparent children, snap spacing, extract component, replace with library instance, variant sets, token binding, batch rename | Restructuring a freehand design — Path A (in-place) or Path B (reconstruction) (Tier 2 — by task) |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 375 | Quick Troubleshooting Index (37-row symptom-to-fix table), error catalog, recurring API pattern errors, auto-layout pitfalls, GROUP coordinate system, instance resize vs rescale, page-context reversion, console-log tripling, screenshot validation, session-level anti-patterns, handoff-specific anti-patterns, regression anti-patterns, performance anti-patterns, hard constraints | Debugging or reviewing output |
| `gui-walkthroughs.md` | 141 | Step-by-step GUI instructions for Figma Desktop operations with no MCP/CLI equivalent: plugin setup, activation, cache refresh, node selection | Connection/setup issues requiring user interaction with Figma Desktop |
| `st-integration.md` | 657 | Sequential Thinking thought chain templates (Phase 1 Analysis, Path A/B Fork-Join, Visual Fidelity Loop, Naming Audit Reasoning, Iterative Refinement, Design System Bootstrap Checkpoint), activation protocol, suppress conditions | ST server available and workflow complexity warrants structured reasoning (Tier 3 — by need) |
| `workflow-code-handoff.md` | 142 | Code Handoff Protocol: TIER system (componentization depth), Smart Componentization Criteria (3 gates), Handoff Manifest template, naming audit, token alignment, multi-platform notes, UX-NARRATIVE preceding input reference | Preparing designs for code implementation (Tier 2 — by task) |
| `convergence-protocol.md` | ~650 | Operation Journal spec (append-only JSONL, 9 rules incl. real timestamps), anti-regression Convergence Check rules (9 rules incl. C8-C9 Session Index), Batch Scripting Protocol, Subagent Delegation Model (per-screen sequential architecture, skill-inheriting prompt template), Session Snapshot schema v4, Compact Recovery Protocol, per-screen journal architecture, journal compaction, cross-screen operations journal, session summary compaction | Any multi-step workflow — anti-regression, batch efficiency, subagent delegation (Tier 1 — always) |
| `compound-learning.md` | 216 | Compound Learning Protocol: learnings file format (H2 categories to H3 entries), file lifecycle, save protocol (6 auto-detect triggers incl. T6 quality audit), load protocol (Tag-based relevance matching), deduplication procedure, subagent integration (orchestrator-only reads/writes, filtered injection) | Cross-session knowledge persistence — load at Preflight, save at Validation (Tier 3 — by need) |
| `quality-dimensions.md` | 407 | Unified Quality Model dimensions: 10 dimensions (D1 Visual Quality, D2 Layer Structure, D3 Semantic Naming, D4 Auto-Layout, D5 Component Compliance, D6 Constraints & Position, D7 Screen Properties, D8 Instance Integrity, D9 Token Binding, D10 Operational Efficiency), scoring rubrics (0-10 per dimension), composite scoring formula, depth tiers (Spot/Standard/Deep) with triage decision matrix, contradiction resolutions (10 resolved) | Quality audit planning, understanding dimension definitions and rubrics (Tier 3 — by need) |
| `quality-audit-scripts.md` | 604 | JavaScript audit scripts A-F (parent context check, positional diff, DS registry, structure inspection, raw frames detection, auto-layout inspection), Screen Diff template (Sonnet subagent prompt), per-element position analysis decision tree and constraint rules, scrollability check, enhanced positional diff script | Executing Standard or Deep audits, running audit scripts (Tier 3 — by need) |
| `quality-procedures.md` | 687 | Spot/Standard/Deep audit execution procedures, Handoff Audit template (Sonnet subagent prompt with all 10 dimensions), unified fix cycle, Mod-Audit-Loop pattern, Deep Critique judge templates (Visual Fidelity, Structural & Component, Design System & Token), journal integration (quality_audit op type), compound learning T6 trigger integration | Phase 4 quality self-assessment, handoff audits, modification-audit loops (Tier 3 — by need) |
| `field-learnings.md` | 338 | Production strategies distilled from cross-session learnings: componentization workflows (clone 6-step, scratch 6-step, property binding vs override), component migration (swapComponent, M3 remote access, fill override), container & layout strategies, text handling, cross-call data patterns, variant patterns, coordinate systems (GROUP, SECTION), audit performance, instance creation | Componentization, migration, layout debugging, advanced Plugin API patterns (Tier 3 — by need) |
| `flow-procedures.md` | 312 | Detailed phase procedures for Flow 1 (Design Session — 4 modes: Create, Restructure, Audit, Targeted) and Flow 2 (Handoff QA — 4 phases). Phase-by-phase steps, mode-specific variations, subagent dispatch instructions | Understanding full phase procedures for either flow (Tier 2 — by task) |
| `socratic-protocol.md` | 268 | Expanded Socratic Protocol question templates for Phase 2 — Categories 0-9 (Documentation Check, User Description, Cross-Screen Comparison, General Approach, Screen Structure, Auto-Layout/Spacing, Componentization, Naming Rules, Design Tokens, Interactions). Mode-specific category subsets (Create vs Restructure) | Phase 2 analysis and planning in Flow 1 (Tier 2 — by task) |
| `essential-rules.md` | 63 | Complete collection of 23 MUST rules and 14 AVOID rules. Full rule text with cross-references. SKILL.md contains top-8 MUST and top-5 AVOID summary | Full rule reference when top-8/top-5 in SKILL.md is insufficient (Tier 2 — by task) |
| `session-index-protocol.md` | 219 | Session Index: L2 cache format (JSONL), build via `figma_get_file_data(summary)`, Grep-based lookups, invalidation via `figma_get_design_changes`, subagent integration | Multi-screen workflows needing name-to-ID resolution (Tier 2 — by task) |

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
| `anti-patterns.md` | `plugin-api.md`, `design-rules.md`, `gui-walkthroughs.md`, `convergence-protocol.md`, external: `design-handoff` skill (product-definition plugin) |
| `gui-walkthroughs.md` | `anti-patterns.md`, `tool-playbook.md` |
| `st-integration.md` | `recipes-restructuring.md`, `recipes-advanced.md`, `tool-playbook.md` |
| `workflow-code-handoff.md` | `recipes-advanced.md`, `design-rules.md`, `st-integration.md`, `tool-playbook.md`, external: `design-narration` skill (product-definition plugin) |
| `convergence-protocol.md` | `anti-patterns.md`, `recipes-foundation.md`, `compound-learning.md`, `quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`, `session-index-protocol.md` |
| `compound-learning.md` | `convergence-protocol.md`, `anti-patterns.md`, `SKILL.md`, `quality-dimensions.md` |
| `quality-dimensions.md` | `quality-audit-scripts.md`, `quality-procedures.md`, `convergence-protocol.md`, `compound-learning.md`, `design-rules.md`, `SKILL.md` |
| `quality-audit-scripts.md` | `quality-dimensions.md`, `quality-procedures.md`, `convergence-protocol.md`, `plugin-api.md`, `design-rules.md` |
| `quality-procedures.md` | `quality-dimensions.md`, `quality-audit-scripts.md`, `convergence-protocol.md`, `compound-learning.md`, `anti-patterns.md`, `design-rules.md`, `plugin-api.md`, `field-learnings.md`, `recipes-components.md`, `SKILL.md` |
| `field-learnings.md` | `anti-patterns.md`, `plugin-api.md`, `quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`, `convergence-protocol.md`, `recipes-components.md` |
| `flow-procedures.md` | `quality-dimensions.md`, `socratic-protocol.md`, `convergence-protocol.md`, `compound-learning.md`, `SKILL.md`, `session-index-protocol.md` |
| `socratic-protocol.md` | `flow-procedures.md`, `SKILL.md` |
| `essential-rules.md` | `SKILL.md`, `convergence-protocol.md`, `anti-patterns.md`, `quality-dimensions.md` |
| `session-index-protocol.md` | `convergence-protocol.md`, `flow-procedures.md`, `SKILL.md` |

## Content Ownership (Deduplication)

Each topic lives in exactly one canonical file:

| Content | Canonical File |
|---------|---------------|
| Plugin API property tables | `plugin-api.md` |
| Node creation patterns | `plugin-api.md` |
| Image handling patterns | `plugin-api.md` |
| Tool parameter tables | `tool-playbook.md` |
| Tool selection decision tree | `tool-playbook.md` |
| Quick reference core tools table | `tool-playbook.md` |
| figma-console-only approach | `tool-playbook.md` |
| Quick Troubleshooting Index (37-row symptom-to-fix) | `anti-patterns.md` |
| Error tables | `anti-patterns.md` |
| Auto-layout pitfalls (FILL on frames, height-1 toggle, async silent failures) | `anti-patterns.md` |
| Instance resize vs rescale | `anti-patterns.md` |
| Screenshot validation (figma_capture_screenshot vs figma_take_screenshot) | `anti-patterns.md` + `SKILL.md` |
| Page-context reversion between figma_execute calls | `anti-patterns.md` |
| Console-log 3x tripling | `anti-patterns.md` |
| Handoff-specific anti-patterns | `anti-patterns.md` |
| Regression anti-patterns | `anti-patterns.md` |
| IMAGE fill limitation (design transfer) | `anti-patterns.md` (Hard Constraints) |
| M3 spec tables | `design-rules.md` |
| M3 code recipes | `recipes-m3.md` |
| Foundation patterns | `recipes-foundation.md` |
| Async IIFE return value requirement (outer return) | `recipes-foundation.md` |
| Layout recipes | `recipes-foundation.md` |
| Constraint reference table, proportional resize calculator | `recipes-foundation.md` |
| Component recipes | `recipes-components.md` |
| GROUP-to-FRAME conversion recipes (single + batch) | `recipes-components.md` |
| Componentize from Clone recipe | `recipes-components.md` |
| COMPONENT_SET Variant Instantiation recipe | `recipes-components.md` |
| Composition and advanced patterns | `recipes-advanced.md` |
| Restructuring patterns | `recipes-restructuring.md` |
| GUI walkthrough instructions | `gui-walkthroughs.md` |
| Code Handoff Protocol (naming audit, token alignment) | `workflow-code-handoff.md` |
| TIER system (componentization depth), Smart Componentization Criteria (3 gates) | `workflow-code-handoff.md` |
| Handoff Manifest template | `workflow-code-handoff.md` |
| UX-NARRATIVE preceding input (design-narration skill) | `workflow-code-handoff.md` |
| Operation Journal spec, JSONL format, entry types | `convergence-protocol.md` |
| Anti-regression Convergence Check rules (C1-C9) | `convergence-protocol.md` |
| Batch Scripting Protocol, script templates, when-to-batch | `convergence-protocol.md` |
| Subagent Delegation Model, skill-inheriting prompt template | `convergence-protocol.md` |
| Real timestamp requirement for journal entries | `convergence-protocol.md` |
| Compact Recovery Protocol | `convergence-protocol.md` |
| Per-screen journal architecture, journal compaction | `convergence-protocol.md` |
| Cross-screen operations journal, session summary compaction | `convergence-protocol.md` |
| Compound Learning Protocol, learnings file format, save/load rules | `compound-learning.md` |
| ST thought chain templates for Figma workflows | `st-integration.md` |
| Unified quality dimensions (D1-D10), rubrics, composite scoring | `quality-dimensions.md` |
| Depth tiers (Spot/Standard/Deep), triage decision matrix | `quality-dimensions.md` |
| Contradiction resolutions (10 resolved contradictions) | `quality-dimensions.md` |
| Audit scripts A-F (JavaScript) | `quality-audit-scripts.md` |
| Screen Diff template (Sonnet subagent prompt) | `quality-audit-scripts.md` |
| Positional diff script, enhanced positional diff | `quality-audit-scripts.md` |
| Per-element position analysis, constraint rules | `quality-audit-scripts.md` |
| Scrollability check | `quality-audit-scripts.md` |
| Spot/Standard/Deep audit execution procedures | `quality-procedures.md` |
| Handoff Audit template (Sonnet subagent prompt with all 10 dimensions) | `quality-procedures.md` |
| Deep Critique judge prompt templates (Visual Fidelity, Structural, Design System) | `quality-procedures.md` |
| Fix cycle protocol, Mod-Audit-Loop pattern | `quality-procedures.md` |
| Quality audit journal entry format (`op: "quality_audit"`) | `quality-procedures.md` |
| Reflection-to-Learning pipeline (T6 trigger) | `quality-procedures.md` + `compound-learning.md` |
| Audit fix completeness rule, node existence pre-check | `quality-procedures.md` |
| Componentization workflows (clone 6-step, scratch 6-step) | `field-learnings.md` |
| Component property binding vs instance override distinction | `field-learnings.md` |
| Component migration patterns (swapComponent, M3 remote, fill override) | `field-learnings.md` |
| Container & layout strategies (pre-check, SPACE_BETWEEN, wrap loose, AL caveats) | `field-learnings.md` |
| Text handling patterns (textAutoResize+FILL, wrapping detection, M3 skip invisible) | `field-learnings.md` |
| Cross-call data patterns (globalThis persistence, page object, findOne ambiguity) | `field-learnings.md` |
| Coordinate systems (GROUP, SECTION, GROUP after setCurrentPageAsync) | `field-learnings.md` |
| Audit script performance (single-pass O(N) classification) | `field-learnings.md` |
| Instance creation patterns (existing ref, nested property, resize vs rescale) | `field-learnings.md` |
| Flow 1/Flow 2 phase procedures (Create, Restructure, Audit, Targeted, Handoff QA) | `flow-procedures.md` |
| Expanded Socratic Protocol question templates (Cat. 0-9) | `socratic-protocol.md` |
| Full 23 MUST + 14 AVOID rules | `essential-rules.md` |
| Top-8 MUST + Top-5 AVOID summary | `SKILL.md` |
| Session Index format (JSONL), meta file schema, build procedure | `session-index-protocol.md` |
| Session Index lookup patterns, validation, subagent integration | `session-index-protocol.md` |
| L1/L2/L3 three-tier access model | `session-index-protocol.md` |
