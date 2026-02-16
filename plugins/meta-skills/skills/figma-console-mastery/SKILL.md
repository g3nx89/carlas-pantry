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

**Gate check**: Call `figma_get_status` before any operation. If transport shows `"not connected"`, the Bridge Plugin is not active.

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
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md     # Writing figma_execute code
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md   # Design decisions + M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes.md        # Core code recipes (layouts, components, composition)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md     # M3 component recipes
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

## Quick Reference

| Tool | Purpose | Key Params |
|------|---------|------------|
| `figma_get_status` | Verify connection | None |
| `figma_navigate` | Open file/page | `url` |
| `figma_get_design_system_summary` | Survey tokens, components, styles | `fileUrl` |
| `figma_get_variables` | Extract variable values | `fileUrl`, `format` |
| `figma_search_components` | Find library components | `query` |
| `figma_instantiate_component` | Place component instance | `component_key`, `variant_properties` |
| `figma_execute` | Run Plugin API code | `code` (JavaScript) |
| `figma_set_fills` | Set fill colors | `nodeId`, fill props |
| `figma_set_text` | Update text content | node ID, text |
| `figma_setup_design_tokens` | Create full token system | `name`, `modes`, `variables` |
| `figma_batch_create_variables` | Create up to 100 variables | `collectionId`, `variables` |
| `figma_move_node` | Reposition/reparent node | `nodeId`, `x`, `y` |
| `figma_resize_node` | Change dimensions | `nodeId`, `width`, `height` |
| `figma_take_screenshot` | Visual validation | None |
| `figma_get_console_logs` | Debug execution errors | None |

## Essential Rules

### MUST

1. **Call `figma_get_status` first** — gate check before any operation
2. **Wrap `figma_execute` in async IIFE with try-catch** — `(async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()`
3. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})` before any `.characters` assignment
4. **Set `layoutMode` before layout properties** — padding, spacing, constraints all require auto-layout to be active first
5. **Validate with screenshots** — take a screenshot after every creation step (max 3 fix cycles)

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

# Plugin API reference — writing figma_execute code (auto-layout, text, colors, components, variables)
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/plugin-api.md

# Design rules — MUST/SHOULD/AVOID rules, dimensions, typography, M3 specs
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/design-rules.md

# Ready-to-use code recipes — cards, buttons, inputs, layouts, composition, chaining
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes.md

# Material Design 3 component recipes — M3 Button, Card, Top App Bar, TextField, Dialog, Snackbar, Bottom Nav, Elevation
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-m3.md

# Error catalog and anti-patterns — debugging, recovery, hard constraints
Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
```

## Troubleshooting Quick Index

| Symptom | Quick Fix |
|---------|-----------|
| `figma_get_status` shows not connected | Verify Desktop Bridge Plugin is running in Figma |
| `figma_execute` returns empty/error | Wrap in async IIFE with try-catch; return plain data, not nodes |
| Font loading error | Call `figma.loadFontAsync({family, style})` before setting `.characters` |
| Layout properties silently ignored | Set `layoutMode = 'VERTICAL'` or `'HORIZONTAL'` BEFORE padding/spacing |
| Fill/stroke mutation fails | Clone array, modify clone, reassign (immutable reference pattern) |
| `figma_instantiate_component` silent fail | Verify variant property names match exactly (case-sensitive) |
| Screenshot shows misaligned elements | Check `layoutSizingHorizontal/Vertical` — use `'FILL'` instead of `'HUG'` for containers |
| Batch variable call fails | Verify `collectionId` is valid; max 100 per batch call |

**Full reference**: `$CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md`

## Architecture Reference

```
AI Agent (Claude Desktop/Code/Cursor/Windsurf)
  ↓ (stdio transport)
Local MCP Server (Node.js, dist/local.js)
  ↓ (WebSocket on port 9223–9232, preferred)
  ↓ (CDP on port 9222, fallback)
Desktop Bridge Plugin (running in Figma Desktop)
  ↓ (Plugin API)
Figma Design Environment
```

**Transport priority**: WebSocket first (Desktop Bridge Plugin, port 9223). Fallback: CDP (port 9222, requires Figma launched with `--remote-debugging-port=9222`). Both transports can be active simultaneously — all 56+ tools work identically through either. Multi-instance support (v1.10.0) scans ports 9223–9232.

## Prompting Guidance

### Good prompts — specific and actionable

- "Design a login card with email and password fields, a 'Forgot password?' link, and a primary Sign In button. Use 32px padding, 16px border radius, and subtle shadow."
- "Build a dashboard header using the Avatar component for the user profile, Button components for actions, and Badge components for notifications."
- "Create a settings page with a sidebar navigation, a main content area with form fields, and a sticky footer with Save and Cancel buttons."
- "Create a new color collection called 'Brand Colors' with Light and Dark modes. Add a primary color variable with value #3B82F6 for Light and #60A5FA for Dark."

### Chaining patterns summary

| Pattern | Flow |
|---------|------|
| **Component composition** | Search library → find components → instantiate with variants → arrange in auto-layout → validate |
| **Brand-new design** | Create custom frames via `figma_execute` → apply tokens → build component → apply auto-layout → validate |
| **Iterative refinement** | Receive feedback → modify via `figma_execute` → screenshot → verify → loop (max 3 cycles) |
| **Design system bootstrap** | `figma_setup_design_tokens` → create components using tokens → document with `figma_set_description` → audit with Dashboard |

## Version Compatibility

| Version | Key Additions |
|---------|---------------|
| **v1.3.0** | `figma_execute` (design creation via Plugin API), variable CRUD |
| **v1.5.0** | 20+ node manipulation tools, component property management, `figma_search_components`, `figma_instantiate_component` |
| **v1.7.0** | MCP Apps, `figma_batch_create/update_variables`, `figma_setup_design_tokens`, `figma_check_design_parity` |
| **v1.8.0** | WebSocket Bridge transport (CDP-free), `figma_get_selection`, `figma_get_design_changes` |
| **v1.9.0** | Figma Comments tools, improved port conflict detection |
| **v1.10.0** | Multi-instance support (ports 9223–9232), multi-connection plugin, `ENABLE_MCP_APPS` env var |

## When NOT to Use This Skill

- **Design-to-code translation** — use dev-skills `figma-implement-design` (Official Figma MCP)
- **Code Connect mappings** — use dev-skills `figma-code-connect-components`
- **Design system rules for code** — use dev-skills `figma-create-design-system-rules`
- **FigJam diagrams** — not supported by Console MCP
- **Figma REST API / OAuth setup** — outside scope (Console MCP uses local Desktop Bridge)
- **Remote SSE mode creation** — most creation tools require Local mode
