# Anti-Patterns and Error Recovery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)

This reference catalogs the most common failures, anti-patterns, and hard constraints encountered when working with the Figma Console MCP. Each entry includes a clear recovery path. For correct patterns, see `plugin-api.md`. For design rules, see `design-rules.md`.

---

## The Top 5 figma_execute Failures

Ranked by frequency. These five errors account for the vast majority of `figma_execute` debugging time. All are preventable by following the correct operation order documented in `plugin-api.md`.

| # | Error Message | Cause | Solution |
|---|--------------|-------|---------|
| 1 | `Cannot write to node with unloaded font` | Setting text properties without loading the font first | Always call `await figma.loadFontAsync({ family, style })` before any `.characters` assignment |
| 2 | Layout properties throw or are silently ignored | Setting `paddingTop`, `itemSpacing`, `maxHeight`, `layoutGrow`, or `layoutAlign` when `layoutMode === 'NONE'` | Set `layoutMode = 'VERTICAL'` or `'HORIZONTAL'` FIRST, then set layout properties |
| 3 | `await` fails or code hangs | Code using `await` not wrapped in an async IIFE | Wrap all async code in `(async () => { ... })()` |
| 4 | Property mutation silently fails | `node.fills[0].color.r = 0.5` — Figma arrays are immutable references | Deep-clone the array, modify the clone, reassign: `const f = clone(node.fills); f[0].color.r = 0.5; node.fills = f` |
| 5 | Return value is empty or errors | Returning the raw Figma node object | Return plain data only: `return { id: node.id }`, never the node itself |

---

## Common Plugin API Errors

Full catalog of Plugin API errors encountered during `figma_execute` calls. Most relate to operation ordering (setting properties before their prerequisites) or type mismatches.

| Error | Cause | Solution |
|-------|-------|---------|
| `Cannot write to node with unloaded font "Inter Regular"` | Setting text without loading font | `await figma.loadFontAsync({ family: 'Inter', style: 'Regular' })` before text changes |
| `Cannot assign to read only property 'r' of object` | Directly mutating a fill/stroke/effect | Clone array, modify clone, reassign: `const f = clone(node.fills); f[0].color.r = 0.5; node.fills = f` |
| `object is not extensible` (on selection) | Pushing to read-only selection array | `figma.currentPage.selection = [...figma.currentPage.selection, node]` |
| Layout properties have no effect | Setting `paddingTop`, `itemSpacing` etc. when `layoutMode === 'NONE'` | Set `layoutMode = 'VERTICAL'` or `'HORIZONTAL'` FIRST |
| `HUG is only valid on auto-layout frames and text nodes` | Setting `layoutSizingHorizontal = 'HUG'` on non-auto-layout frame | Only use HUG on frames with `layoutMode` set, or on TextNodes |
| `FILL is only valid on auto-layout children` | Setting `layoutSizingHorizontal = 'FILL'` on node outside auto-layout parent | Ensure parent has `layoutMode` set before using FILL on children |
| Min/max constraint error | Setting `maxHeight`/`minWidth` before `layoutMode` | Set `layoutMode` first, then min/max constraints |
| `counterAxisAlignContent` error | Setting on non-WRAP frame | Set `layoutWrap = 'WRAP'` before `counterAxisAlignContent` |
| `there are still font loads in progress` | Calling `figma.closePlugin()` while font ops pending | Await all `loadFontAsync` promises before closing |
| `Error: in set_characters` after loading wrong font | Loading "Bold" but node has "Regular" | Load the font currently on the node, OR set `fontName` before `characters` |
| `in set_fills: Invalid discriminator value` | Fills contain unsupported properties or paint types | Validate paint objects; strip unrecognized properties |
| `in set_fills: Invalid SHA1 hash` | Cloning fills with null `videoHash` | Check for null hashes before cloning/reassigning |
| `Cannot read properties of null` | Accessing removed node or unloaded page children | Check `node.removed` before access; call `page.loadAsync()` for dynamic pages |
| Instance structure modification fails | Adding/removing children on an InstanceNode | Modify the main ComponentNode instead; instances only support property overrides |
| STRETCH + AUTO conflict | `layoutAlign='STRETCH'` with parent `counterAxisSizingMode='AUTO'` | Use `counterAxisSizingMode = 'FIXED'` when any child uses STRETCH |
| `resize()` no-ops on one dimension | Frame has AUTO sizing on that axis | `resize()` only works on FIXED axes; AUTO dimensions are computed from children |
| `in set_opacity: Expected number but got string` | Passing wrong type to property setter | Ensure correct types: opacity is 0-1 number, colors are 0-1 `{r,g,b}` |

---

## Connection and Transport Errors

The server tries WebSocket first (ports 9223-9232), then falls back to CDP (port 9222). Connection issues are the most common barrier to getting started.

**Diagnostic sequence for connection failures:**

1. Call `figma_get_status` to determine current connection state
2. Check if Desktop Bridge Plugin is running in the target file
3. Verify no port conflicts with other MCP instances
4. Try `figma_reconnect` before restarting Figma

| Error | Cause | Recovery |
|-------|-------|---------|
| `Failed to connect to Figma Desktop` | No transport available (neither WebSocket nor CDP) | Import and run the Desktop Bridge Plugin in Figma; or restart Figma with `--remote-debugging-port=9222` |
| `EADDRINUSE` port conflict | Multiple MCP instances competing for same port (pre-v1.10.0) | Update to v1.10.0+ for automatic port fallback (9223-9232). Re-import Desktop Bridge after update |
| `Variables cache empty` | Plugin cache not populated or stale | Close and reopen the Desktop Bridge plugin in Figma |
| `No plugin UI found` | Desktop Bridge Plugin not running in current file | Open target file in Figma, then Plugins > Development > run Desktop Bridge |
| `ECONNREFUSED localhost:9222` | CDP not available | Informational if WebSocket works. For CDP: quit Figma, relaunch with `--remote-debugging-port=9222` |

---

## Session-Level Anti-Patterns

These workflow-level mistakes cause wasted iterations, silent data loss, or session stalls. Each is avoidable with disciplined tool usage.

| Anti-Pattern | Problem | Solution |
|-------------|---------|---------|
| Infinite screenshot loop | Agent iterates screenshot-fix cycles endlessly on minor issues | Hard cap at 3 iteration cycles. Set acceptance criteria upfront; accept "good enough" |
| Not gating on `figma_get_status` | Operations fail silently when plugin is disconnected | Always call `figma_get_status` before any design operations |
| Using remote mode for write operations | Remote SSE mode is read-only (~21 tools) | Switch to local mode for any creation, modification, or variable operations |
| Monolithic `figma_execute` scripts | Large scripts are harder to debug and more prone to silent failures | Break into single-responsibility calls; verify each with a screenshot |
| Not returning node IDs | Created nodes cannot be referenced in subsequent calls | Always `return { id: node.id }` from `figma_execute` |
| Not using try-catch in `figma_execute` | Errors are swallowed silently by the plugin sandbox | Wrap all code in try-catch; return error messages explicitly |
| Using `figma_get_file_data` on large files | Response exceeds token limits, gets truncated | Use `figma_get_file_for_plugin` for optimized output |
| Not discovering before creating | Duplicate components or missed existing assets | Always `figma_search_components` before creating new components |

---

## Hard Constraints

These are platform-level limitations that cannot be worked around. Understanding them prevents wasted effort attempting impossible operations.

### Remote SSE Mode Limitations

Remote mode connects via Cloudflare Workers and is restricted to read-only operations:

- **No design creation or modification** -- `figma_execute`, node manipulation, component instantiation are unavailable
- **No variable management** -- all CRUD operations require local mode
- **No Desktop Bridge Plugin** -- remote cannot connect to localhost
- **Variables require Enterprise plan** -- REST API endpoint is Enterprise-gated (local mode bypasses this)
- **Only ~21 read-only tools** available (~34% of the full 56+ tool set)

### Any-Mode Limitations

These apply regardless of connection mode (local or remote):

- **No direct DOM/browser control** -- `figma_execute` runs in the Plugin API sandbox, not a browser context
- **No network requests from plugin context** -- cannot fetch external data from within `figma_execute`
- **No undo/redo programmatic control** -- Plugin API changes cannot be programmatically undone
- **No cross-file operations** -- each session operates on the single file where the Desktop Bridge is running (v1.10.0 supports multiple files with multiple plugin instances)
- **No Code Connect integration** -- unlike the Official Figma MCP, Console MCP does not support Code Connect
- **No FigJam support** -- cannot read or generate FigJam diagrams
- **No Figma Make resource retrieval**

### Large File Constraints

Large Figma files introduce token and cache limits that require targeted query strategies:

- `figma_get_file_data` may exceed token limits -- set `MAX_MCP_OUTPUT_TOKENS` env var or use `figma_get_file_for_plugin`
- `figma_get_variables` with `format: "full"` auto-summarizes above 25K tokens -- use `"filtered"` with `collection`, `namePattern`, or `mode` params
- Variable cache uses LRU eviction: max 10 files, 5-minute TTL
- For 1000+ component files, use targeted `figma_search_components` queries over bulk extraction
- Screenshot operations on extremely complex canvases may be slow -- prefer `figma_capture_screenshot` on specific nodes over full-canvas `figma_take_screenshot`

---

## Full Errors and Recovery Table

Comprehensive reference including detection method and recovery steps. Use `figma_get_status` as the first diagnostic tool for any connection-related error. Use `figma_get_console_logs` for silent execution failures.

| Error | Cause | Detection | Recovery |
|-------|-------|-----------|----------|
| `Failed to connect to Figma Desktop` | No transport available | `figma_get_status` returns disconnected | Run Desktop Bridge Plugin; or restart Figma with `--remote-debugging-port=9222` |
| `EADDRINUSE` | Multiple MCP instances on same port | Server startup fails | Update to v1.10.0+ (auto port fallback 9223-9232). Re-import Desktop Bridge |
| `Variables cache empty` | Plugin cache not populated/stale | `figma_get_variables` returns empty | Close and reopen Desktop Bridge plugin |
| Silent failure in `figma_execute` | JS error in Plugin API code | Screenshot shows no change; no visible error | Wrap in try-catch. Check `figma_get_console_logs`. Validate with screenshot after every execute |
| Text not appearing | `loadFontAsync` not called before `.characters` | Screenshot shows empty text node | Always `await figma.loadFontAsync()` before setting text |
| Library variable ID resolution failure | Variable IDs from library components need async resolution | Variable binding fails silently | Use `getVariableByIdAsync()` for ID resolution |
| Component descriptions missing | Known Figma API limitation | Component data lacks `description` field | Use `figma_set_description` via Plugin API |
| Infinite screenshot loop | Agent keeps finding minor issues | Session stalls with repeated screenshot-fix cycles | Hard cap: 3 cycles. Set acceptance criteria before starting |
| Rate limiting (HTTP 429) | Figma REST API limits exceeded | API calls return 429 status | Wait and retry. Limits vary by plan (see below) |
| Claude Code SSE transport bug | Known bug in Claude Code native `--transport sse` | Connection fails in Claude Code | Use `mcp-remote` workaround: `npx -y mcp-remote@latest https://...` |
| `figma_navigate` does not navigate | WebSocket-only mode lacks browser-level navigation | Tool returns file info instead of navigating | Expected behavior in WebSocket mode. Ensure correct file is already open. Use CDP transport for actual navigation |
| Truncated responses on large files | File data exceeds response size | Response appears incomplete | Use `figma_get_file_for_plugin` instead of `figma_get_file_data`. Use filtered variable queries. Target specific nodes rather than entire file |
| `No plugin UI found` | Desktop Bridge Plugin not running | `figma_get_status` shows no plugin connection | Open target Figma file, then Plugins > Development > run Desktop Bridge plugin |

---

## Rate Limiting

### Official Figma MCP Limits

The Official Figma MCP (not Console MCP) imposes per-seat tool call limits:

| Seat Type | Limit |
|-----------|-------|
| Starter / View-only / Collab | 6 tool calls/month |
| Dev / Full (paid plans) | Per-minute throttle (Tier 1) |

### Figma REST API Limits (Remote SSE Mode)

These apply to Console MCP in Remote mode only:

| Plan | Rate Limit |
|------|-----------|
| Organization | 200 calls/day |
| Enterprise | 600 calls/day |

### MCP Response Limits

The `MAX_MCP_OUTPUT_TOKENS` environment variable controls maximum MCP response size (default: 25,000 tokens). When a response exceeds this limit, the error `MCP tool response exceeds maximum allowed tokens` is returned. Increase the value or use targeted queries to reduce response size.

Console MCP itself imposes no artificial rate limits beyond what the Figma API enforces. Local mode operations through the Desktop Bridge Plugin are not subject to REST API rate limits.

---

> **Cross-references**: For correct operation patterns and code templates, see `plugin-api.md`. For spacing, typography, and layout rules, see `design-rules.md`.
