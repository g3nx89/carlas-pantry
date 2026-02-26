# Tool Playbook — Choosing Which Tool to Call

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)

This reference covers tool selection decisions across the full 60 tool surface area. For Plugin API code patterns used inside `figma_execute`, see `plugin-api.md`. For error recovery procedures, see `anti-patterns.md`.

---

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
├── Component in library? → figma_search_components → figma_instantiate_component
└── Everything else?      → figma_execute (Plugin API) — see recipes-foundation.md

Need to modify existing elements?
├── Rename node?                → figma_rename_node (single call)
├── Solid fill/stroke?          → figma_set_fills / figma_set_strokes (SOLID only — gradients need figma_execute)
├── Text content (+ fontSize)?  → figma_set_text (font family/weight changes need figma_execute)
├── Reposition?                 → figma_move_node (position only — reparenting needs figma_execute)
├── Resize?                     → figma_resize_node (withConstraints option available)
├── Delete node?                → figma_delete_node
├── Instance properties?        → figma_set_instance_properties
├── Multi-property async?       → figma_execute (load fonts + set text + layout in sequence)
├── Gradient/image fills, font? → figma_execute (operations beyond native tool scope)
└── Batch 3+ same-type?         → figma_execute batch script (idempotency-guarded)

Need to manage variables/tokens?
├── Create token system?   → figma_setup_design_tokens (atomic, single call)
├── Create many variables? → figma_batch_create_variables (up to 100)
├── Update many values?    → figma_batch_update_variables (up to 100)
├── Single variable CRUD?  → figma_create/update/rename/delete_variable
└── Add/rename mode?       → figma_add_mode / figma_rename_mode

Need to validate or debug?
├── After Plugin API change?    → figma_capture_screenshot (Desktop Bridge — live state)
├── After save / stable design? → figma_take_screenshot (REST API)
├── Console errors?             → figma_get_console_logs / figma_watch_console
├── Design-code parity?         → figma_check_design_parity
└── Document component?         → figma_generate_component_doc
```

## Quick Reference — Core Tools

| Tool | Purpose |
|------|---------|
| `figma_get_status` | Verify connection (always first) |
| `figma_search_components` | Find library components before creating |
| `figma_instantiate_component` | Place component with variant properties |
| `figma_execute` | Run Plugin API code (creation, modification, complex logic) |
| `figma_capture_screenshot` | Visual validation after Plugin API mutations |
| `figma_take_screenshot` | Validation of already-saved designs (REST API) |
| `figma_setup_design_tokens` | Create token system atomically |
| `figma_batch_create_variables` | Bulk variable creation (up to 100) |
| `figma_batch_update_variables` | Bulk variable updates (up to 100) |
| `figma_get_design_system_summary` | Overview of tokens, components, styles |
| `figma_audit_design_system` | 0-100 health scorecard |
| `figma_generate_component_doc` | Document created components |

**Full tool reference**: See Tool Categories at a Glance and detailed sections below (60 tools)

---

## Tool Categories at a Glance

| Category | Tool Count | Mode Required | Key Tools |
|----------|-----------|---------------|-----------|
| Navigation / Status | 5 | All | `figma_get_status`, `figma_navigate`, `figma_list_open_files`, `figma_get_selection` |
| Design System Extraction | 7 | All | `figma_get_variables`, `figma_get_design_system_summary`, `figma_get_component` |
| Design Creation | 5 | Local | `figma_execute`, `figma_search_components`, `figma_instantiate_component` |
| Variable Management | 11 | Local | `figma_batch_create_variables`, `figma_setup_design_tokens` |
| Node Manipulation | 10 | Local | `figma_move_node`, `figma_resize_node`, `figma_set_fills`, `figma_set_text` |
| Visual Validation / Debugging | 8 | All | `figma_capture_screenshot`, `figma_take_screenshot`, `figma_get_console_logs`, `figma_get_design_changes` |
| Comments | 3 | All | `figma_post_comment`, `figma_get_comments`, `figma_delete_comment` |
| Design-Code Parity | 2 | All | `figma_check_design_parity`, `figma_generate_component_doc` |
| Component Properties | 4 | Local | `figma_add_component_property`, `figma_edit_component_property`, `figma_get_component_details` |
| Design System Audit | 2 | Local | `figma_audit_design_system`, `figma_get_token_values` |
| MCP App Management | 3 | All | `figma_browse_tokens`, `token_browser_refresh`, `ds_dashboard_refresh` |

---

## Navigation and Status Tools

These tools work in all modes (Local and Remote SSE). Always call `figma_get_status` first.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_get_status` | **Always first.** Gate check before any operation. Verify transport, port, mode | None | Connection status, transport type (WebSocket/CDP), port, active instances | In multi-instance mode, verify connection to the correct file |
| `figma_navigate` | Open a specific Figma file or page by URL | `url` (string, required) | Opens file in Figma or returns connected file info | WebSocket-only mode cannot perform browser-level navigation; returns file info with guidance instead. CDP required for actual navigation |
| `figma_list_open_files` | List all currently open Figma files to confirm target file is active | None | Array of open file identifiers with names and URLs | Use during Preflight to verify the correct file is connected before operations |
| `figma_reconnect` | Re-establish connection to Figma Desktop when transport is lost | None | Reconnection status | Try this before restarting Figma. Faster recovery than full restart |
| `figma_get_selection` | Returns currently selected nodes with optional verbose details | `verbose` (boolean, optional) | Selected node IDs, names, types (verbose adds full properties) | Returns empty array if nothing is selected |

---

## Design System Extraction Tools

All extraction tools work in both modes. Start every discovery phase with `figma_get_design_system_summary`.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_get_design_system_summary` | First step in discovery — understand what tokens, components, and styles exist | `fileUrl` | Summary statistics of variables, components, styles | High-level only; follow up with specific tools for details |
| `figma_get_variables` | Extract design tokens and variable values | `fileUrl` (required), `format` (`"summary"` / `"filtered"` / `"full"`), optional `collection`, `namePattern`, `mode`, `refreshCache` | Variables with `id`, `name`, `resolvedType`, `valuesByMode`; collections with modes | Use `"summary"` first (~2-5K tokens). `"full"` auto-summarizes above 25K tokens. Cache: 5-min TTL, LRU eviction (max 10 files). Enterprise plan required in Remote mode; local mode bypasses this |
| `figma_get_styles` | Extract color, text, and effect styles | `fileUrl` | Structured style data | -- |
| `figma_get_component` | Get component metadata or a machine-readable reconstruction spec | Component identifier, `format` (`"metadata"` / `"reconstruction"`) | Component data in chosen format | Reconstruction format provides specs for programmatic recreation via `figma_execute` |
| `figma_get_component_for_development` | Get component visual image plus implementation specs | Component identifier, `fileUrl` | Visual reference image + structured spec | Best for understanding a component before instantiating or recreating it |
| `figma_get_file_data` | Get full file structure as JSON | `fileUrl` | Complete document tree | Can be extremely large; prefer `figma_get_file_for_plugin` for large files |
| `figma_get_file_for_plugin` | Get optimized file data for plugin consumption | `fileUrl` | Optimized file data subset | Lighter alternative to `figma_get_file_data`; prefer for large files |

---

## Design Creation Tools

All design creation tools require **Local mode** with the Desktop Bridge Plugin.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_execute` | Run arbitrary Figma Plugin API code — fallback for complex conditional logic, multi-step async sequences, and operations not covered by declarative tools | `code` (string): JavaScript in Plugin API context | Execution result (created node info, return values) | Silent failures possible — always validate with screenshot. Wrap in try-catch. See figma_execute Deep Dive below |
| `figma_search_components` | Find components in the library before instantiating | `query` (string), optional filters | Matching components with key, name, description, variants | May return many results for common terms; use specific queries |
| `figma_instantiate_component` | Place a found component with correct variant and property settings | `componentKey` or `nodeId`, `variant` (object matching variant property names), `overrides` (instance property overrides), `parentId` (optional), `position` (optional `{x, y}`) | Created instance node ID | Variant property names must exactly match the component set definitions; mismatches fail silently |
| `figma_arrange_component_set` | Organize variants into a professional component set with labels | Component set identifier or variant node IDs | Organized set with purple dashed border, labels, headers | Use after creating multiple variants via `figma_execute` |
| `figma_set_description` | Add markdown documentation to components | `nodeId`, `description` | Confirmation | Descriptions appear in Dev Mode |

---

## Variable Management Tools

All variable management tools require **Local mode**. Batch tools (v1.7.0+) are 10-50x faster than individual calls.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_create_variable_collection` | Create a new token collection with modes | `name`, `modes` (optional array) | Collection ID | -- |
| `figma_create_variable` | Create a single variable | `collectionId`, `name`, `resolvedType` (`COLOR` / `FLOAT` / `STRING` / `BOOLEAN`), `values` | Variable ID | Use `figma_batch_create_variables` when creating multiple |
| `figma_update_variable` | Update a variable value for a specific mode | `variableId`, `modeId`, `value` | Confirmation | Must specify correct mode ID |
| `figma_rename_variable` | Rename while preserving all values | `variableId`, `newName` | Confirmation | -- |
| `figma_delete_variable` | Delete a single variable | `variableId` | Confirmation | Irreversible |
| `figma_delete_variable_collection` | Delete collection and all its variables | `collectionId` | Confirmation | **Cascading delete** -- removes all contained variables |
| `figma_add_mode` | Add a mode to a collection (e.g., "Dark") | `collectionId`, `name` | Mode ID | -- |
| `figma_rename_mode` | Rename an existing mode | `collectionId`, `modeId`, `newName` | Confirmation | -- |
| `figma_batch_create_variables` | Create up to 100 variables in one call | `collectionId`, `variables` (array, max 100) | Array of variable IDs | **10-50x faster** than individual calls (v1.7.0+) |
| `figma_batch_update_variables` | Update up to 100 variable values in one call | `updates` (array of `{variableId, modeId, value}`, max 100) | Confirmation | v1.7.0+ |
| `figma_setup_design_tokens` | Create complete token system atomically | `name`, `modes`, `variables` | Full system (collection + modes + variables) | Single atomic operation -- all-or-nothing. Ideal for initial token setup |

---

## Node Manipulation Tools

All node manipulation tools require **Local mode** (v1.5.0+). These provide dedicated operations for common tasks without requiring raw `figma_execute` code.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_move_node` | Reposition a node (position only — reparenting requires `figma_execute` with `parent.appendChild()`) | `nodeId`, `x`, `y` | Updated position | -- |
| `figma_resize_node` | Change node dimensions | `nodeId`, `width`, `height`, `withConstraints` (boolean, optional — respects parent constraints when true) | Updated dimensions | -- |
| `figma_rename_node` | Rename a node in the layer panel | `nodeId`, `name` | Confirmation | -- |
| `figma_delete_node` | Remove a node and its children | `nodeId` | Confirmation | Irreversible |
| `figma_clone_node` | Duplicate a node | `nodeId` | Cloned node info | -- |
| `figma_create_child` | Add a child node to a parent | Parent and child parameters | Created child info | -- |
| `figma_set_fills` | Set **solid** fill colors on a node (SOLID type only — hex color, optional opacity). Gradient, image, and pattern fills require `figma_execute` | `nodeId`, `fills` (array of `{type: "SOLID", color: "#hex", opacity?}`) | Confirmation | Only SOLID fills supported; complex fills need `figma_execute` |
| `figma_set_strokes` | Set **solid** strokes on a node (SOLID type only — hex color, optional opacity, optional strokeWeight). Gradient strokes require `figma_execute` | `nodeId`, `strokes` (array of `{type: "SOLID", color: "#hex", opacity?}`), `strokeWeight?` | Confirmation | Only SOLID strokes supported |
| `figma_set_text` | Update text content and optionally font size (content + fontSize only — font family, weight, style, alignment, and other typography changes require `figma_execute` with `loadFontAsync`) | `nodeId`, `text` (string), `fontSize?` (number) | Confirmation | Font family/weight changes need `figma_execute` |
| `figma_set_instance_properties` | Update component instance properties | Instance identifier, properties | Confirmation | Property names must match component definitions |

> **Note**: Z-order / layer reordering has no dedicated native tool. Use `figma_execute` to manipulate `parent.insertChild(index, node)`.

---

## Component Property Tools

Component property tools (local mode, v1.5.0+) manage boolean, text, and instance-swap properties on components without requiring raw `figma_execute` code.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_add_component_property` | Add a boolean, text, or instance-swap property to a component | Component identifier, property name, type (`BOOLEAN` / `TEXT` / `INSTANCE_SWAP`), default value | Created property info | Property type cannot be changed after creation |
| `figma_edit_component_property` | Modify an existing component property (name, default value) | Component identifier, property name, new values | Confirmation | Renaming a property updates all instances referencing it |
| `figma_delete_component_property` | Remove a component property | Component identifier, property name | Confirmation | Irreversible -- instances lose the property override |
| `figma_get_component_details` | Get detailed component info including properties, variants, and nested structure | Component identifier | Full component details with property definitions, variant list, and layer structure | More detailed than `figma_get_component` with `"metadata"` format |

---

## Design System Audit Tools

These tools provide automated analysis and direct access to design system data (local mode, v1.7.0+).

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_audit_design_system` | Run automated health check on the design system | `fileUrl` (optional) | Scorecard with findings across naming, tokens, components, accessibility, consistency, coverage | May take several seconds on large files |
| `figma_get_token_values` | Get resolved token values for specific variables or collections | Variable/collection identifiers | Resolved values per mode | Use for targeted value lookups; prefer `figma_get_variables` with `format="filtered"` for broader queries |

---

## Visual Validation and Debugging Tools

These tools work in all modes and form the visual feedback loop for autonomous design.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_take_screenshot` | Capture **full canvas/viewport** for general layout verification | `fileUrl` (optional) | Base64 screenshot of current viewport | Captures everything visible on canvas, including elements outside the target design |
| `figma_capture_screenshot` | Capture a **specific node** for targeted validation | `nodeId` (required), `fileUrl` (optional) | Rendered image of the specific node | Requires knowing the node ID; use after `figma_execute` returns the ID |
| `figma_get_component_image` | Export a component as PNG or SVG | Component identifier, format options | Image data of the component | For documentation and reference, not for in-progress validation |
| `figma_get_console_logs` | Retrieve plugin console logs for debugging | Filter options (type, count) | Array of log entries | Only captures logs from after monitoring begins (not historical). CDP captures page-level logs; WebSocket captures plugin-context logs only |
| `figma_watch_console` | Stream logs in real-time during plugin execution | Duration (seconds) | Real-time log stream | Blocks for the specified duration |
| `figma_clear_console` | Reset log buffer before a new debugging session | None | Confirmation | -- |
| `figma_get_design_changes` | Returns buffered design changes since last check | `since` (timestamp, optional), `clear` (boolean, optional) | Array of change events with node IDs and change types | Useful for tracking what changed between operations |
| `figma_reload_plugin` | Reload Figma plugin with optional console clear | `clearConsole` (boolean, default true) | Confirmation | Use when plugin state seems stale or after updates |

---

## Native Tools vs figma_execute

> **Legacy note (2026-02-22)**: The figma-use MCP server has been removed from this skill due to reliability issues. The native-tools-first strategy below describes the figma-console-only approach.

**Default strategy**: Use figma-console native tools (atomic tools like `figma_rename_node`, `figma_set_fills`, `figma_move_node`, `figma_instantiate_component`) as the primary approach for single-property operations. Reserve `figma_execute` for complex conditional logic, multi-step async sequences, or operations that native tools cannot compose atomically.

This strategy reduces token consumption by 40-70% compared to the fire-log-verify pattern (`figma_execute` + `figma_get_console_logs` pairs) for simple operations, and avoids async error surface. See `anti-patterns.md` — Recurring API Pattern Errors.

**Use figma-console native tools when:**
- Renaming a node (`figma_rename_node`)
- Setting fills or strokes (`figma_set_fills`, `figma_set_strokes`)
- Moving, resizing, or deleting nodes (`figma_move_node`, `figma_resize_node`, `figma_delete_node`)
- Instantiating or configuring component instances (`figma_instantiate_component`, `figma_set_instance_properties`)
- Reading metadata, styles, or variables (`figma_get_styles`, `figma_get_variables`)

**Use `figma_execute` (Plugin API) when:**
- Complex conditional logic is involved (if/else chains, loops with branching)
- Multiple async operations must happen in sequence (font loading + text creation + layout setup)
- Prototype wiring with `setReactionsAsync`
- Batch operations across many nodes in a single atomic transaction
- Operations not covered by native tools (GROUP→FRAME conversion, variant combination, etc.)
- `getNodeByIdAsync` node lookup followed by immediate mutation

**Rule of thumb**: If a native tool does exactly the operation needed with one call, use it. Reach for `figma_execute` when the operation requires multi-step logic, async sequencing, or direct Plugin API access.

---

## figma_execute Deep Dive

### Execution Scope

Code runs inside the Desktop Bridge Plugin's sandbox with the full `figma` global available. All Plugin API methods are accessible: `figma.currentPage`, `figma.createFrame()`, `figma.createText()`, `figma.loadFontAsync()`, and every other documented API. The same permissions as a Figma plugin apply.

### Return Patterns

Always return serializable JSON. Node objects cannot be serialized -- return IDs and metadata instead:

```javascript
return { nodeId: frame.id, name: frame.name };
```

### State Tracking Across Calls

Each `figma_execute` call is stateless. Capture node IDs from return values, then use `figma.getNodeByIdAsync("RETURNED_ID")` in the next call to reference previously created nodes:

```
Call 1: Create container -> return { containerId: container.id }
Call 2: const container = await figma.getNodeByIdAsync("RETURNED_ID"); container.appendChild(newChild);
```

### Error Handling

Errors may fail silently. Wrap code in try-catch and return error information:

```javascript
try {
  // design code
  return { success: true, nodeId: frame.id };
} catch (e) {
  return { success: false, error: e.message };
}
```

### Known Limits

- Plugin API sandbox only -- no DOM access, no network calls
- Code using `await` must be wrapped in an async IIFE: `(async () => { ... })()`
- No documented hard timeout, but excessively large operations should be split into multiple calls
- Library variable IDs require `getVariableByIdAsync()` for resolution

> For complete Plugin API property reference and code patterns, see `plugin-api.md`.

---

## Component Composition Workflow

The most efficient workflow for composing library components into layouts follows four steps:

1. **Search** -- Find the component in the library:
   `figma_search_components("Button")` returns component keys, names, variants

2. **Instantiate** -- Place the component with correct variant settings:
   `figma_instantiate_component(key, { "State": "Default", "Size": "Medium" })` returns instance node ID

3. **Container** -- Create a layout container via `figma_execute`:
   Create a frame with auto-layout, padding, and spacing; return its ID

4. **Reparent** -- Move the instance into the container via `figma_execute`:
   Use `figma.getNodeByIdAsync(instanceId)` to get the instance, then `container.appendChild(instance)`

This pattern separates library discovery (specialized tools) from layout construction (`figma_execute`), using each tool where it is strongest.

---

## Variable Management Workflow

### Full Sequence

1. **Create collection**: `figma_create_variable_collection` with name and initial mode names (e.g., "Brand Colors" with modes "Light" and "Dark")
2. **Batch create variables**: `figma_batch_create_variables` (up to 100 at once, 10-50x faster). Types: `COLOR`, `FLOAT`, `STRING`, `BOOLEAN`
3. **Batch update mode values**: `figma_batch_update_variables` to set values per mode (e.g., Light: `#3B82F6`, Dark: `#60A5FA`)
4. **Bind to nodes**: `figma_execute` with Plugin API to bind variables to node properties via `setBoundVariable()`

### Atomic Shortcut

`figma_setup_design_tokens` creates the entire system (collection + modes + variables) in a single call. Ideal for bootstrapping a new token system from scratch.

### Enterprise Bypass

In Remote mode, the Variables API requires a Figma Enterprise plan. **Local mode with the Desktop Bridge Plugin bypasses this limitation entirely** -- variables work on all plan levels because access goes through the Plugin API rather than the REST API.

---

## Screenshot Validation Discipline

### Tool Selection

| Tool | Scope | When to Use |
|------|-------|-------------|
| `figma_take_screenshot` | Full canvas / viewport | Overview validation: "Does the overall layout look right?" |
| `figma_capture_screenshot` | Specific node by ID | Targeted validation: "Does this specific card look correct?" Prefer when the node ID is known |

### Iteration Cycle

The recommended validation pattern:

```
Create -> Screenshot -> Analyze -> Fix -> Screenshot -> Confirm
```

### Max 3 Iteration Cycles

Cap visual validation at **3 iteration cycles maximum**. After 3 attempts, accept the current result and document remaining issues. This prevents the infinite screenshot loop where minor issues trigger perpetual fix-and-verify cycles. Set clear acceptance criteria before the first iteration begins.

---

## MCP Apps (Experimental)

MCP Apps require `ENABLE_MCP_APPS=true` environment variable (v1.7.0+). For setup instructions, see `gui-walkthroughs.md` (Enabling MCP Apps section).

### Token Browser

- **Trigger prompt**: "Browse the design tokens" or "show me the design tokens"
- **What it shows**: Interactive token explorer -- browse by collection, filter by type (Colors/Numbers/Strings), search by name, per-collection mode columns (Light/Dark/Custom), color swatches, alias resolution, click-to-copy
- **Requires**: `ENABLE_MCP_APPS=true`

### Design System Dashboard

- **Trigger prompt**: "Audit the design system" or "show me design system health"
- **What it shows**: Lighthouse-style health scorecard (0-100) across 6 categories: Naming, Tokens, Components, Accessibility, Consistency, Coverage. Expandable findings with severity indicators and diagnostic locations
- **Requires**: `ENABLE_MCP_APPS=true`

### MCP App Management Tools

These tools control the MCP App interfaces programmatically:

| Tool | When to Use | Key Params | Output |
|------|-------------|------------|--------|
| `figma_browse_tokens` | Open the interactive Token Browser app | None | Token Browser UI |
| `token_browser_refresh` | Refresh the Token Browser with latest variable data | None | Updated token display |
| `ds_dashboard_refresh` | Refresh the Design System Dashboard with latest audit data | None | Updated dashboard scores |

---

## figma-console Only

> **Legacy note (2026-02-26)**: This skill uses figma-console MCP exclusively. Previous versions included figma-use and referenced Official Figma MCP. Both have been removed from this skill:
> - **figma-use**: Removed due to reliability issues (CDP port 9222 dependency, pre-1.0 stability)
> - **Official Figma MCP**: Out of scope for this skill — design system extraction and code generation workflows belong in separate, domain-specific skills

### What figma-console Offers

- **Full Plugin API access** via `figma_execute` — arbitrary JavaScript in the plugin sandbox
- **60 specialized tools** spanning navigation, design system extraction, creation, variable management, node manipulation, visual validation, debugging, component properties, and auditing
- **Dual transport modes**: WebSocket Desktop Bridge (local, ports 9223-9232) + Remote SSE (cloud/CI, read-only)
- **Variable CRUD without Enterprise plan** — local mode bypasses REST API plan restrictions
- **Interactive MCP Apps** (Token Browser, Design System Dashboard) — requires `ENABLE_MCP_APPS=true`
- **Plugin debugging** — real-time console log capture via `figma_get_console_logs`
- **Design-code parity checking** — scored diff reports via `figma_check_design_parity`
- **Component documentation generation** via `figma_generate_component_doc`
- **Batch operations** — `figma_batch_create_variables`, `figma_batch_update_variables` (10-50x faster than individual calls)
- **No rate limits in local mode** — all operations are plugin-local

For workflows requiring design-to-code translation or Code Connect mappings, use a separate skill that integrates Official Figma MCP.
