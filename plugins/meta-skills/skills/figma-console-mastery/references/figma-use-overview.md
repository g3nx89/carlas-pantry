# figma-use — Server Overview and Tool Inventory

> **Compatibility**: figma-use v0.11.3 (February 2026). Pre-1.0 — API surface may change before 1.0.
>
> **Scope**: Architecture, setup, tool inventory, and decision guidance for the figma-use MCP server. For tool-by-tool parameters and patterns, see the dedicated reference files: `figma-use-jsx-patterns.md`, `figma-use-analysis.md`, `figma-use-diffing.md`.

---

## Architecture

The figma-use MCP server connects to Figma Desktop via the **Chrome DevTools Protocol (CDP)**. Unlike figma-console, which requires installing the Desktop Bridge Plugin, figma-use needs no plugin — it injects an RPC bundle directly into Figma's JavaScript context through `Runtime.evaluate`, which then calls standard Figma Plugin API methods (`figma.createFrame()`, `figma.createText()`, `figma.createNodeFromJSXAsync()`, etc.).

### Transport Diagram

```
AI Agent ←→ MCP Server (port 38451) ←→ CDP WebSocket (port 9222) ←→ Figma Desktop (injected RPC → Plugin API)
```

### Key Architectural Properties

| Property | Detail |
|----------|--------|
| Transport | CDP-only via `--remote-debugging-port=9222` |
| Plugin required | None — RPC bundle injected at runtime |
| Server port | HTTP 38451 (MCP endpoint) |
| Connection target | Single CDP target (one file at a time) |
| Daemon mode | Optional — keeps CDP connection open for faster sequential commands |

### Coexistence with figma-console

Both servers can be active simultaneously. Ports do not conflict:

| Server | Transport | Ports |
|--------|-----------|-------|
| figma-console | WebSocket (Desktop Bridge Plugin) | 9223-9232 |
| figma-use | CDP WebSocket | 9222 |

The two servers are fully independent — each maintains its own connection to Figma Desktop. Both ultimately call the same underlying Figma Plugin API.

---

## Setup

### 1. Launch Figma with CDP Flag

Quit Figma completely before relaunching with the flag.

**macOS:**
```bash
open -a Figma --args --remote-debugging-port=9222
```

**Windows:**
```cmd
"C:\Users\%USERNAME%\AppData\Local\Figma\Figma.exe" --remote-debugging-port=9222
```

**Linux:**
```bash
figma --remote-debugging-port=9222
```

> **Cross-reference**: See `gui-walkthroughs.md` — Alternative Transport section for a detailed CDP launch walkthrough and troubleshooting.

### 2. MCP Client Configuration

Add to Claude Desktop, Cursor, or other MCP client configuration:

```json
{
  "mcpServers": {
    "figma-use": {
      "url": "http://localhost:38451/mcp"
    }
  }
}
```

### 3. Connection Verification

> **WARNING**: `figma_status` is **broken** (100% failure rate — returns cryptic `"8"` instead of status). Do not use it for connection verification. Instead, use figma-console `figma_get_status` or call `figma_page_list` as a connectivity check — if it returns a page list, the connection is working.

---

## Known Broken or Risky Tools

These tools have confirmed failure modes based on empirical testing across 6 production sessions (~66 figma-use calls). Re-test after each figma-use version update.

| Tool | Status | Failure Mode | Workaround |
|------|--------|-------------|-----------|
| `figma_status` | **PREVIOUSLY BROKEN** — re-test (Feb 2026 fixes may have resolved) | Was returning cryptic `"8"` instead of status | Test with single call; if still broken, use figma-console `figma_get_status` or `figma_page_list` |
| `figma_page_current` | **PREVIOUSLY BROKEN** — re-test (Feb 2026 fixes may have resolved) | Was returning `"8"` instead of page info | Test with single call; if still broken, use `figma_page_list` + `figma_page_set` |
| `figma_node_tree` | **RISKY** on large files (>500 descendant nodes) | Output exceeded 3MB (3,092,958 chars), causing token limit errors | Use `figma_node_children` with targeted depth; safe on subtrees with <500 descendant nodes |

> These findings are from figma-use v0.11.3. All other tested tools operate at 95-100% reliability.
>
> **Update (Feb 2026)**: figma-use has received fixes. Previously broken tools may now work. When encountering a tool listed above, test with a single call before relying on it in production workflows. If the tool now works reliably, update this table.

---

## Tool Inventory

This is the canonical tool list for figma-use. Each tool is listed once with a one-line purpose.

### Rendering and Export

| Tool | Purpose |
|------|---------|
| `figma_render` | Render JSX string into Figma nodes (single call, entire tree) |
| `figma_export_node` | Export node as PNG/SVG/PDF |
| `figma_export_selection` | Export selected nodes |
| `figma_export_screenshot` | Capture viewport |
| `figma_export_jsx` | Export Figma node as JSX code (round-trip capable) |
| `figma_export_storybook` | Generate React/Vue components + Storybook stories from ComponentSets (experimental) |
| `figma_export_fonts` | List fonts, generate @font-face CSS or Google Fonts URLs |

### Node Creation

| Tool | Purpose |
|------|---------|
| `figma_create_frame` | Create frame with layout, fill, radius |
| `figma_create_rect` | Create rectangle |
| `figma_create_ellipse` | Create ellipse/circle |
| `figma_create_text` | Create text node |
| `figma_create_line` | Create line |
| `figma_create_polygon` | Create polygon |
| `figma_create_star` | Create star shape |
| `figma_create_vector` | Create vector from SVG path |
| `figma_create_component` | Create master component |
| `figma_create_instance` | Create component instance |
| `figma_create_section` | Create section container |
| `figma_create_page` | Create new page |
| `figma_create_icon` | Insert Iconify icon (150K+ icons) as SVG vector |
| `figma_create_slice` | Create export slice |

### Property Setters

| Tool | Purpose |
|------|---------|
| `figma_set_fill` | Set fill color (hex or `var:Name` for variable binding) |
| `figma_set_stroke` | Set stroke color and weight |
| `figma_set_stroke_align` | Set stroke alignment (INSIDE/CENTER/OUTSIDE) |
| `figma_set_radius` | Set corner radius (uniform or per-corner) |
| `figma_set_opacity` | Set opacity (0-1) |
| `figma_set_rotation` | Set rotation in degrees |
| `figma_set_visible` | Show/hide node |
| `figma_set_locked` | Lock/unlock node |
| `figma_set_text` | Set text content |
| `figma_set_text_resize` | Set text auto-resize mode |
| `figma_set_font` | Set font family, style, size |
| `figma_set_font_range` | Style a character range (partial text styling) |
| `figma_set_effect` | Add shadow, blur, or other effects |
| `figma_set_layout` | Set auto-layout or CSS Grid mode |
| `figma_set_constraints` | Set resize constraints |
| `figma_set_blend` | Set blend mode |
| `figma_set_image` | Set image fill from path or URL |
| `figma_set_props` | Set component instance properties |
| `figma_set_minmax` | Set min/max width/height |

### Node Operations

| Tool | Purpose |
|------|---------|
| `figma_node_get` | Get node properties |
| `figma_node_tree` | Get node tree (descendants) **[RISKY — use `figma_node_children` on large files]** |
| `figma_node_children` | Get direct children |
| `figma_node_ancestors` | Get parent chain |
| `figma_node_bounds` | Get position, size, center |
| `figma_node_bindings` | Get variable bindings |
| `figma_node_delete` | Delete node(s) |
| `figma_node_clone` | Duplicate node |
| `figma_node_rename` | Rename node |
| `figma_node_move` | Move node (absolute or relative) |
| `figma_node_resize` | Resize node |
| `figma_node_set_parent` | Reparent node |
| `figma_node_replace_with` | Replace node with JSX or another node |
| `figma_node_to_component` | Convert frame to component |

### Query and Selection

| Tool | Purpose |
|------|---------|
| `figma_query` | XPath 3.1 queries across the node tree |
| `figma_find` | Find nodes by name/type |
| `figma_selection_get` | Get current selection |
| `figma_selection_set` | Set selection by node IDs |

### Analysis

| Tool | Purpose |
|------|---------|
| `figma_analyze_clusters` | Find repeated patterns (component candidates) |
| `figma_analyze_colors` | Palette analysis with similarity grouping |
| `figma_analyze_typography` | Font usage inventory |
| `figma_analyze_spacing` | Gap/padding grid compliance |
| `figma_analyze_snapshot` | Accessibility tree extraction |

### Diffing

| Tool | Purpose |
|------|---------|
| `figma_diff_visual` | Pixel-by-pixel comparison (output PNG with changes in red) |
| `figma_diff_create` | Git-style property diff between two nodes |
| `figma_diff_apply` | Apply patch to node (with dry-run/force) |
| `figma_diff_show` | Preview proposed changes before applying |
| `figma_diff_jsx` | JSX-level comparison |

### Variables and Collections

| Tool | Purpose |
|------|---------|
| `figma_variable_list` | List variables in collection |
| `figma_variable_find` | Search variables by name |
| `figma_variable_get` | Get variable details |
| `figma_variable_create` | Create variable |
| `figma_variable_set` | Set variable value (per mode) |
| `figma_variable_delete` | Delete variable |
| `figma_variable_bind` | Bind variable to node property |
| `figma_collection_list` | List collections |
| `figma_collection_get` | Get collection details |
| `figma_collection_create` | Create collection with modes |
| `figma_collection_delete` | Delete collection |

### Styles

| Tool | Purpose |
|------|---------|
| `figma_style_list` | List local styles |
| `figma_style_create_paint` | Create paint style |
| `figma_style_create_text` | Create text style |
| `figma_style_create_effect` | Create effect style |

### Boolean and Vector

| Tool | Purpose |
|------|---------|
| `figma_boolean_union` | Merge shapes |
| `figma_boolean_subtract` | Subtract shapes |
| `figma_boolean_intersect` | Intersect shapes |
| `figma_boolean_exclude` | Exclude overlap |
| `figma_path_get` | Get SVG path data |
| `figma_path_set` | Replace SVG path |
| `figma_path_move` | Translate path |
| `figma_path_scale` | Scale path |
| `figma_path_flip` | Flip path on axis |

### Layout and Organization

| Tool | Purpose |
|------|---------|
| `figma_arrange` | Arrange nodes using grid/row/column/squarify/binary algorithms |
| `figma_group_create` | Group nodes |
| `figma_group_ungroup` | Ungroup |
| `figma_group_flatten` | Flatten to single vector |

### Components

| Tool | Purpose |
|------|---------|
| `figma_component_add_prop` | Add component property |
| `figma_component_edit_prop` | Edit component property |
| `figma_component_delete_prop` | Delete component property |
| `figma_component_combine` | Combine into ComponentSet |

### Pages and Viewport

| Tool | Purpose |
|------|---------|
| `figma_page_current` | Get current page **[BROKEN — returns "8"; use `figma_page_list`]** |
| `figma_page_list` | List all pages |
| `figma_page_set` | Switch to page |
| `figma_page_bounds` | Get page bounds |
| `figma_viewport_get` | Get viewport position/zoom |
| `figma_viewport_set` | Set viewport position/zoom |
| `figma_viewport_zoom_to_fit` | Zoom to fit nodes |

### Comments and File

| Tool | Purpose |
|------|---------|
| `figma_comment_list` | List comments |
| `figma_comment_add` | Add comment (with position and reply support) |
| `figma_comment_delete` | Delete comment |
| `figma_comment_resolve` | Resolve comment |
| `figma_comment_watch` | Poll for new comments (event-driven workflows) |
| `figma_version_list` | List file versions |
| `figma_font_list` | List available fonts |
| `figma_import` | Import SVG string |
| `figma_eval` | Execute arbitrary JS in Figma plugin context |
| `figma_me` | Get current user info |

---

## When to Use figma-use vs figma-console

This is the canonical decision matrix for choosing between the two servers.

### Prefer figma-use When

| Scenario | Why figma-use | Key Tool |
|----------|---------------|----------|
| Creating complex multi-node UI | JSX is 2-4x more token-compact; 1 call creates entire tree | `figma_render` |
| Quick design analysis without code | Dedicated commands, no `figma_execute` code to write | `figma_analyze_*` |
| Visual regression checking | Pixel-level diff with quantitative output | `figma_diff_visual` |
| Querying nodes by properties | XPath 3.1 in a single call vs multiple `figma_execute` | `figma_query` |
| No plugin install available | CDP-only, no Desktop Bridge Plugin needed | All tools |
| Inserting icons from Iconify | 150K+ icons with single command | `figma_create_icon` |
| Round-trip JSX editing | Export, edit, re-render workflow | `figma_export_jsx` then `figma_render` |
| Creating individual nodes | Declarative single-call creation avoids `figma_execute` overhead | `figma_create_frame`, `figma_create_text`, `figma_create_rect`, etc. |
| Setting node properties | Single-call property setters without Plugin API boilerplate | `figma_set_fill`, `figma_set_stroke`, `figma_set_layout`, `figma_set_font` |
| Moving, cloning, reparenting | Declarative node operations without `getNodeByIdAsync` lookups | `figma_node_move`, `figma_node_clone`, `figma_node_set_parent` |
| Combining component variants | Avoids page context errors with `combineAsVariants` | `figma_component_combine` |
| Binding variables to nodes | Declarative variable binding without `setBoundVariable` boilerplate | `figma_variable_bind` |

### Prefer figma-console When

| Scenario | Why figma-console | Key Tool |
|----------|-------------------|----------|
| Batch variable operations (up to 100) | Atomic batch tools, no equivalent in figma-use | `figma_batch_create_variables` |
| Atomic design token system setup | Single-call collection+modes+variables | `figma_setup_design_tokens` |
| Full Plugin API flexibility | Any Plugin API code, not limited to JSX elements | `figma_execute` |
| Remote/cloud access (read-only) | SSE mode via Cloudflare Workers | ~21 SSE tools |
| MCP Apps (Token Browser, Dashboard) | Interactive UI tools | `figma_browse_tokens`, `ds_dashboard_refresh` |
| Component documentation | Auto-generated markdown | `figma_generate_component_doc` |
| Design-code parity checking | Scored diff reports | `figma_check_design_parity` |
| Design system audit with scoring | 0-100 scorecard | `figma_audit_design_system` |
| Connection status checking | `figma_status` (figma-use) is broken; Console has reliable status | `figma_get_status` |
| Plugin debugging and console logs | Console captures plugin-context logs | `figma_get_console_logs`, `figma_watch_console` |

### Use Both Together

| Workflow | figma-use Role | figma-console Role |
|----------|---------------|-------------------|
| Audit then Fix | `figma_analyze_*` for discovery | `figma_execute` for targeted fixes |
| Create then Validate | `figma_render` for JSX creation | `figma_take_screenshot` for validation |
| Restructure then Diff | `figma_query` for structural audit | `figma_execute` for restructuring |
| Verify changes | `figma_diff_visual` for before/after | `figma_capture_screenshot` for reports |

---

## Performance Characteristics

Both servers ultimately call the same Figma Plugin API. The performance differences are architectural, not transport-level.

| Aspect | figma-console | figma-use |
|--------|---------------|-----------|
| Per-call transport latency | Sub-ms (WebSocket) | Sub-ms (CDP WebSocket) |
| Complex UI creation | Multiple `figma_execute` calls (1 per operation group) | **1 `figma_render` call for entire tree** |
| Token cost for LLM | Plugin API code: ~450+ chars per component | **JSX: 2-4x more compact** (see `figma-use-jsx-patterns.md` for details) |
| First-call overhead | Plugin already running | ~200-500ms (RPC bundle injection, cached thereafter) |
| Sequential commands | Per-call overhead minimal | Optional daemon eliminates per-call startup |

**Key takeaway**: The efficiency advantage of figma-use comes from **call count reduction** (N nodes in 1 call via JSX) and **token compactness** (see `figma-use-jsx-patterns.md` for the full comparison), not from raw transport speed. For individual property changes, variable management, or design system operations, figma-console's specialized tools are equally efficient.

---

## Limitations

| Limitation | Impact |
|------------|--------|
| CDP-only transport | Figma Desktop must be launched with `--remote-debugging-port=9222` every session |
| Local-only | No remote/cloud mode (unlike figma-console's SSE mode) |
| Single file at a time | Only one CDP target cached; no multi-file support |
| Pre-1.0 (v0.11.3) | API surface may change; stable for use but not guaranteed backward-compatible |
| Storybook export: experimental | May not work for all ComponentSet structures |
| Visual diff requires extras | `pngjs` + `pixelmatch` must be installed separately |
| Icon matching requires extras | `whaticon` must be installed for `--match-icons` |
| No undo/redo | Same as figma-console — Plugin API limitation |
| No FigJam support | Same as figma-console |

---

## 1.0 Migration Checklist

When figma-use reaches 1.0, update these locations:

1. **Version numbers** — grep `v0.11.3` across all reference files (currently 5 files)
2. **Pre-1.0 markers** — remove "Pre-1.0 -- API surface may change" from all compatibility notes
3. **Tool parameter tables** — review `figma-use-jsx-patterns.md`, `figma-use-analysis.md`, `figma-use-diffing.md` for renamed/removed/added parameters
4. **tool-playbook.md** — update "Pre-1.0 (v0.11.3)" in the At a Glance table
5. **SKILL.md** — review whether tier assignments should change (e.g., promote overview to Tier 1 if figma-use becomes primary)
6. **README.md** — update line counts if files changed significantly
