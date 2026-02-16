# figma-console-mastery — Reference Files

## File Usage Table

| File | Lines | Purpose | Load When |
|------|------:|---------|-----------|
| `tool-playbook.md` | 344 | Tool selection across 56+ tools, workflows, Console vs Official MCP, component property tools, design system audit tools | Choosing which tool to call |
| `plugin-api.md` | 536 | Plugin API reference for `figma_execute` code (auto-layout, text, colors, components, variables, performance optimization) | Writing `figma_execute` code |
| `design-rules.md` | 295 | MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs, QA checklist | Making design decisions |
| `recipes.md` | 869 | Core code recipes: foundation patterns, layouts, components, composition, chaining, variable binding, SVG import, rich text | Building specific UI patterns |
| `recipes-m3.md` | 703 | Material Design 3 recipes: M3 Button, Card, Top App Bar, TextField, Bottom Nav, Dialog, Snackbar, Elevation Shadows | Building M3-specific components |
| `anti-patterns.md` | 192 | Error catalog, debugging, hard constraints, rate limiting, performance anti-patterns | Debugging or reviewing output |

## Cross-References

| File | References |
|------|------------|
| `tool-playbook.md` | `plugin-api.md`, `anti-patterns.md` |
| `plugin-api.md` | `design-rules.md`, `recipes.md`, `recipes-m3.md`, `anti-patterns.md` |
| `design-rules.md` | `recipes.md`, `plugin-api.md` |
| `recipes.md` | `plugin-api.md`, `design-rules.md`, `anti-patterns.md`, `recipes-m3.md` |
| `recipes-m3.md` | `design-rules.md`, `plugin-api.md`, `anti-patterns.md`, `recipes.md` |
| `anti-patterns.md` | `plugin-api.md`, `design-rules.md` |

## Content Ownership (Deduplication)

Each topic lives in exactly one canonical file:

| Content | Canonical File |
|---------|---------------|
| Plugin API property tables | `plugin-api.md` |
| Tool parameter tables | `tool-playbook.md` |
| Error tables | `anti-patterns.md` |
| M3 spec tables | `design-rules.md` |
| M3 code recipes | `recipes-m3.md` |
| Core code recipes | `recipes.md` |
