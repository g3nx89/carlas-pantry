# Tool Playbook — Choosing Which Tool to Call

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)

This reference covers tool selection decisions across the full 56+ tool surface area. For Plugin API code patterns used inside `figma_execute`, see `plugin-api.md`. For error recovery procedures, see `anti-patterns.md`.

---

## Tool Categories at a Glance

| Category | Tool Count | Mode Required | Key Tools |
|----------|-----------|---------------|-----------|
| Navigation / Status | 3 | All | `figma_get_status`, `figma_navigate`, `figma_list_open_files` |
| Design System Extraction | 7 | All | `figma_get_variables`, `figma_get_design_system_summary`, `figma_get_component` |
| Design Creation | 5 | Local | `figma_execute`, `figma_search_components`, `figma_instantiate_component` |
| Variable Management | 11 | Local | `figma_batch_create_variables`, `figma_setup_design_tokens` |
| Node Manipulation | 10+ | Local | `figma_move_node`, `figma_resize_node`, `figma_set_fills`, `figma_set_text` |
| Visual Validation / Debugging | 6 | All | `figma_capture_screenshot`, `figma_take_screenshot`, `figma_get_console_logs` |
| Comments | 3 | All | `figma_post_comment`, `figma_get_comments`, `figma_delete_comment` |
| Design-Code Parity | 2 | All | `figma_check_design_parity`, `figma_generate_component_doc` |

---

## Navigation and Status Tools

These tools work in all modes (Local and Remote SSE). Always call `figma_get_status` first.

| Tool | When to Use | Key Params | Output | Pitfalls |
|------|-------------|------------|--------|----------|
| `figma_get_status` | **Always first.** Gate check before any operation. Verify transport, port, mode | None | Connection status, transport type (WebSocket/CDP), port, active instances | In multi-instance mode, verify connection to the correct file |
| `figma_navigate` | Open a specific Figma file or page by URL | `url` (string, required) | Opens file in Figma or returns connected file info | WebSocket-only mode cannot perform browser-level navigation; returns file info with guidance instead. CDP required for actual navigation |
| `figma_list_open_files` | List all currently open Figma files to confirm target file is active | None | Array of open file identifiers with names and URLs | Use during Preflight to verify the correct file is connected before operations |
| `figma_reconnect` | Re-establish connection to Figma Desktop when transport is lost | None | Reconnection status | Try this before restarting Figma. Faster recovery than full restart |

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
| `figma_execute` | **Power tool.** Run any Figma Plugin API code for custom elements, auto-layout, effects, text | `code` (string): JavaScript in Plugin API context | Execution result (created node info, return values) | Silent failures possible -- always validate with screenshot. Wrap in try-catch. See figma_execute Deep Dive below |
| `figma_search_components` | Find components in the library before instantiating | `query` (string), optional filters | Matching components with key, name, description, variants | May return many results for common terms; use specific queries |
| `figma_instantiate_component` | Place a found component with correct variant and property settings | `component_key` (required), `variant_properties` (optional), `parent_node_id` (optional), `position` (optional `{x, y}`) | Created instance node ID | Variant property names must exactly match the component set definitions; mismatches fail silently |
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
| `figma_move_node` | Reposition or reparent a node | `nodeId`, `x`, `y`, `parent_node_id` (optional) | Updated position | -- |
| `figma_resize_node` | Change node dimensions | `nodeId`, `width`, `height` | Updated dimensions | -- |
| `figma_rename_node` | Rename a node in the layer panel | `nodeId`, `name` | Confirmation | -- |
| `figma_delete_node` | Remove a node and its children | `nodeId` | Confirmation | Irreversible |
| `figma_clone_node` | Duplicate a node | `nodeId` | Cloned node info | -- |
| `figma_reorder_node` | Change z-order / layer order of a node | `nodeId` (string), `position` (`"front"`, `"back"`, or integer index) | Updated layer order | Affects visual stacking, not auto-layout flow order |
| `figma_create_child` | Add a child node to a parent | Parent and child parameters | Created child info | -- |
| `figma_set_fills` | Set fill colors on a node | `nodeId`, fill properties | Confirmation | -- |
| `figma_set_strokes` | Set stroke properties on a node | `nodeId`, stroke properties | Confirmation | -- |
| `figma_set_text` | Update text content | Node identifier, text content | Confirmation | -- |
| `figma_set_instance_properties` | Update component instance properties | Instance identifier, properties | Confirmation | Property names must match component definitions |

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

---

## Specialized Tools vs figma_execute

The specialized node manipulation tools are convenience wrappers around Plugin API operations. `figma_execute` can do everything the specialized tools do -- and more. The decision comes down to operation complexity.

**Use specialized tools when:**
- Performing a single-property change on a known node ID (move, resize, rename, delete)
- Setting fills or strokes with simple color values
- Updating text content without font changes
- Modifying instance properties

**Use `figma_execute` when:**
- Multiple operations must happen in sequence (create frame + set auto-layout + add children)
- Async work is required (font loading before text creation)
- Complex logic is involved (conditionals, loops, calculations)
- Auto-layout construction is needed (`layoutMode`, `itemSpacing`, sizing modes)
- Variable binding via `setBoundVariable()` is required
- Creating nodes from scratch (frames, text, shapes, components)
- Reparenting instantiated components into container layouts

**Rule of thumb**: If the operation touches more than one property or requires `await`, use `figma_execute`.

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

## Console MCP vs Official Figma MCP

### At a Glance

Console MCP provides **56+ tools** with full CRUD capabilities. The Official Figma MCP provides **12 tools** focused on design-to-code translation.

### What Official Offers That Console Does Not

- `get_design_context` -- Returns structured code representation (React + Tailwind by default, customizable to Vue/HTML/iOS) from selected layers
- `get_code_connect_map` / `add_code_connect_map` -- Maps Figma components to codebase components
- Code Connect suggestions and mappings -- AI-prompted Code Connect setup
- `generate_diagram` -- Creates FigJam diagrams from Mermaid syntax
- `get_figjam` -- Reads FigJam diagram content
- `create_design_system_rules` -- Generates a rules file for agents with design system and tech stack context
- Agent Skills -- Packaged workflow instructions as plugins for Claude Code, Cursor

### What Console Offers That Official Does Not

- Design creation and modification via `figma_execute` (full Plugin API access)
- Variable CRUD (create, read, update, delete design tokens)
- Plugin debugging (real-time console log capture)
- Project-wide design system extraction (complete system overview)
- Design-code parity checking (scored diff reports)
- Component documentation generation (platform-agnostic markdown)
- 20+ node manipulation tools (move, resize, delete, rename, clone)
- Interactive MCP Apps (Token Browser, Design System Dashboard)
- Figma Comments (post, retrieve, clean up design feedback)
- Variables without Enterprise plan (Desktop Bridge bypasses REST API restriction)

### Complementary Workflow

Both servers are designed to work together:

1. **Design creation phase** -- Console MCP (`figma_execute`, component instantiation, variable management)
2. **Code generation phase** -- Official MCP (`get_design_context` for framework-ready code, `get_variable_defs` for token references)
3. **Validation phase** -- Console MCP (`figma_check_design_parity`, screenshots, debugging)
4. **Documentation phase** -- Console MCP (`figma_generate_component_doc`, `figma_set_description`)

> **Rate limit note**: Official MCP Starter/View/Collab seats get only 6 tool calls per month. Dev/Full seats on paid plans get per-minute rate limits matching Tier 1 REST API. Console MCP has no artificial rate limits beyond underlying Figma API constraints.
