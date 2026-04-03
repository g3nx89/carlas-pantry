---
name: figma-execute
version: 1.0.0
description: This skill should be used when the user asks to "create a Figma design", "add a component", "build a UI element", "design a screen", "make a button", "set up design tokens", "create variables in Figma", "instantiate a component", "use figma_execute", or any direct Figma creation or manipulation task. Do NOT trigger for "restructure this design" or "clean up" (use figma-restructure), "audit" or "quality check" (use figma-qa), "handoff to developers" (use design-handoff), skill/command development (use figma-console-mastery), FigJam diagrams, Figma REST API, or figma-desktop/Official Figma MCP.
---

# Figma Execute — Direct Creation & Manipulation

> **Compatibility**: figma-console-mcp v1.11.2+ (Southleft, 61 tools)
>
> **Scope**: Direct Figma creation and manipulation with zero ceremony. No convergence journaling, no Socratic protocol, no formal quality audit. Just execute and verify via screenshot.
>
> **Reference hub**: All reference files live in `../figma-console-mastery/references/`.

## Prerequisites

| Requirement | Check |
|-------------|-------|
| Figma Desktop App | Running with file open |
| Desktop Bridge Plugin | Installed and active (WebSocket ports 9223-9232) |
| Local mode | Required for all creation/mutation tools |

**Always first**: `figma_get_status`. If not connected, ask user to check Figma Desktop and Bridge Plugin.

## Quick Start

**Connect & navigate**: `figma_get_status` → `figma_list_open_files` → `figma_navigate`

**Design system discovery**: `figma_get_design_system_kit` (tokens + components + styles in one call) | `figma_get_design_system_summary` (lightweight)

**Local components**: `figma_search_components(query="Button")` → `figma_instantiate_component(componentKey, { variant, overrides })`

**External library import**: Team Library → `importComponentByKeyAsync(key)` | UI Kit (M3, iOS) → Clone Pattern via `getMainComponentAsync()` → `createInstance()`

**Create elements**: `figma_execute` with async IIFE + outer `return`:
```javascript
return (async () => {
  const frame = figma.createFrame();
  frame.name = "MyFrame";
  return JSON.stringify({ id: frame.id, name: frame.name });
})()
```

**Variables**: `figma_setup_design_tokens` (atomic) | `figma_batch_create_variables` / `figma_batch_update_variables` (up to 100)

**Verify**: `figma_capture_screenshot` (live state, post-mutation) — NOT `figma_take_screenshot` (may show cached state)

## Decision Matrix

Evaluate in order, stop at first match:

| Gate | Question | Tool Path |
|------|----------|-----------|
| **G0: DS Kit?** | Need full design system context? | `figma_get_design_system_kit` |
| **G0b: Local component?** | Component in current file? | `figma_search_components` → `figma_instantiate_component` |
| **G0c: Team Library?** | Published Team Library component? | `figma_execute` → `importComponentByKeyAsync(key)` |
| **G0d: UI Kit?** | M3/iOS/Apple component? | `figma_execute` → Clone Pattern |
| **G1: Native tool?** | Dedicated batch/read/modify tool? | `figma_batch_create_variables`, `figma_set_fills`, `figma_rename_node`, etc. |
| **G2: Simple execute?** | 1-2 ops, no cross-node deps? | `figma_execute` single script |
| **G3: Complex execute?** | 3+ ops or cross-node deps? | `figma_execute` batch script |

## Essential Rules

> Canonical source: `../figma-console-mastery/references/essential-rules.md` (23 MUST + 13 AVOID). Critical subset below.

### MUST
1. **Wrap `figma_execute` in async IIFE with outer `return`** — required for Desktop Bridge
2. **Use `figma.getNodeByIdAsync(id)`** — sync variant throws in `dynamic-page` mode
3. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})`
4. **Set `layoutMode` before layout properties** — padding/spacing require auto-layout active first
5. **Use `figma_capture_screenshot` for post-mutation validation** — NOT `figma_take_screenshot`
6. **Native-tools-first** — use dedicated tools before `figma_execute`
7. **GROUP→FRAME before constraints** — GROUPs don't support `constraints`; assignment silently fails
8. **Place components in Sections/Frames** — never on blank canvas

### AVOID
1. **Never mutate Figma arrays directly** — clone, modify, reassign
2. **Never return raw Figma nodes** — return plain data `{ id, name }`
3. **Never set constraints on GROUP nodes** — convert to FRAME first
4. **Never split page-switch and data-read across calls** — `setCurrentPageAsync` reverts in next IIFE
5. **Never assume `figma_search_components` finds external libraries** — searches local file only

## Execution Pattern

1. **Preflight**: `figma_get_status` → `figma_get_design_system_kit(format="summary")`
2. **Execute**: Use Decision Matrix to pick tool path. Execute directly (no subagent required for simple tasks; use subagent for complex multi-element compositions).
3. **Verify**: `figma_capture_screenshot` after mutations. If issues visible, fix and re-screenshot (max 3 cycles). If still failing, present screenshot + issue description to user.

No journaling. No Socratic planning. No formal quality audit.

## Reference Loading

```
# Tier 1 — Always load when writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md

# Tier 2 — Load by task (max 3 simultaneously)
# Tool selection:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/tool-playbook.md
# Layout, node creation, auto-layout:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-foundation.md
# Text, colors, effects, images:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-visuals.md
# Components, variables, prototypes:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api-advanced.md
# Design constraints, M3 specs:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md
# Basic components (card, button, input, toast, navbar):
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components.md
# Composite components (form, data table, modal, dashboard):
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-components-composite.md
# Material Design 3 recipes:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md
# Composition, variable binding, SVG, full pages:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-advanced.md
# Debugging, error catalog:
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
```

## Troubleshooting (Top 5)

| Symptom | Quick Fix |
|---------|-----------|
| `figma_execute` returns empty/error | Wrap in async IIFE with outer `return` |
| Font loading error | `figma.loadFontAsync({family, style})` before `.characters` |
| Layout properties silently ignored | Set `layoutMode` BEFORE padding/spacing |
| Screenshot shows stale content | Use `figma_capture_screenshot`, not `figma_take_screenshot` |
| `importComponentByKeyAsync` fails | UI Kit components require Clone Pattern, not import |

## When NOT to Use

- **Restructuring existing designs** → use `figma-restructure`
- **Quality audits / handoff readiness** → use `figma-qa`
- **Full protocol with convergence, journaling, compound learning** → use `figma-console-mastery`
- **Draft-to-Handoff orchestration** → use `design-handoff` skill (product-definition plugin)
