# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 344 | Tool selection across 56+ tools, workflows, Console vs Official MCP, component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 697 | Plugin API reference for `figma_execute` code (node creation, auto-layout, text, colors, images, components, variables, performance optimization) | Writing `figma_execute` code |
| `design-rules.md` | 295 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes.md` | 2129 | Core code recipes: foundation patterns, layouts, components (toast, navbar, sidebar, form, data table, empty state, modal, dashboard header), shell injection composition, full page composition, chaining, variable binding, SVG import, rich text | Building specific UI patterns |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 192 | Error catalog, debugging, hard constraints, rate limiting, performance anti-patterns, idempotency | Debugging or reviewing output |
| `gui-walkthroughs.md` | 141 | Step-by-step GUI instructions for Figma Desktop operations with no MCP/CLI equivalent: plugin setup, activation, cache refresh, node selection, CDP transport, MCP Apps | Connection/setup issues requiring user interaction with Figma Desktop |

## Cross-References

| File | References |
|------|------------|
| `tool-playbook.md` | `plugin-api.md`, `anti-patterns.md`, `gui-walkthroughs.md` |
| `plugin-api.md` | `design-rules.md`, `recipes.md`, `recipes-m3.md`, `anti-patterns.md` |
| `design-rules.md` | `recipes.md`, `plugin-api.md` |
| `recipes.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-m3.md` |
| `recipes-m3.md` | `design-rules.md`, `plugin-api.md`, `anti-patterns.md`, `recipes.md` |
| `anti-patterns.md` | `plugin-api.md`, `design-rules.md`, `gui-walkthroughs.md` |
| `gui-walkthroughs.md` | `anti-patterns.md`, `tool-playbook.md` |

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
| Core code recipes | `recipes.md` |
| GUI walkthrough instructions | `gui-walkthroughs.md` |
