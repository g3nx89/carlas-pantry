# Anti-Patterns and Error Recovery

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)

This reference catalogs the most common failures, anti-patterns, and hard constraints encountered when working with the Figma Console MCP. Each entry includes a clear recovery path. For correct patterns, see `plugin-api.md`. For design rules, see `design-rules.md`. For GUI-only recovery steps (plugin setup, cache refresh, CDP launch), see `gui-walkthroughs.md`.

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
| `"object is not extensible"` on GROUP | Setting `constraints` on a GROUP node — GROUPs don't support constraints | Convert GROUP to FRAME first (see `recipes-components.md` GROUP→FRAME recipe), then set constraints on the FRAME |
| `"The node with id X does not exist"` after GROUP child move | Calling `group.remove()` after all children were moved out — GROUP auto-deletes when empty | Never call `group.remove()` after moving children. The GROUP is already gone |
| `createInstance()` returns undefined or throws on COMPONENT_SET | Calling `createInstance()` on a COMPONENT_SET instead of on a COMPONENT variant child | Get the COMPONENT_SET, find the variant child via `set.children.find(c => c.name.includes("State=Default"))`, call `createInstance()` on the child |
| Async IIFE return value is `undefined` | `(async () => { return data; })()` without outer `return` — bridge sees the Promise but doesn't await it | Use `return (async () => { ... return data; })()` — the outer `return` is required. Confirmed working as of 2026-02-22 |
| Reactions array empty after `setReactionsAsync` on GROUP | GROUP nodes silently drop reactions — `setReactionsAsync` succeeds but reactions stay empty | Always re-read `node.reactions` after setting. If empty, node type is incompatible (GROUP). Convert to FRAME first |
| `primaryAxisSizingMode = "FILL"` throws validation error | `"FILL"` is not a valid enum for frame sizing modes. Inside async IIFE, the entire script fails silently with no error returned | Use `"AUTO"` or `"FIXED"` on the frame's sizing modes. To make a child fill, append it to parent first, THEN set `child.layoutSizingHorizontal = "FILL"`. The `layoutSizing*` properties are child-level, not parent-level |
| Auto-layout frame height stays at 1px even after appending children | Setting `counterAxisSizingMode = "AUTO"` before appending children. The layout engine does not recalculate height when children are added in the same script | Toggle fix: set `counterAxisSizingMode = "FIXED"`, call `resize(w, approxHeight)`, then set `counterAxisSizingMode = "AUTO"`. This forces the layout engine to recalculate |
| Enum property validation errors fail silently inside async IIFE | Invalid enum values (e.g., `primaryAxisSizingMode = "FILL"`) throw validation errors that are NOT caught by try-catch inside async IIFEs. Script fails silently, no nodes created, bridge returns `undefined` | For creation scripts, prefer sync approach where possible. When async is needed (font loading), split: (1) async font-load call, (2) sync creation call. Avoid setting enum properties to undocumented values |
| GROUP child `x`/`y` coordinates are unexpectedly large | Children of a GROUP node report `x`/`y` relative to the **containing FRAME**, not the GROUP. Direct reads produce incorrect gap calculations | Compute local position: `localY = child.y - group.y`. To measure gap: `gap = group.height - child1.height - child2.height`. Verify spacing with `figma_capture_screenshot` on the specific GROUP node |
| `figma.getNodeById(id)` throws in dynamic-page mode | The plugin manifest uses `documentAccess: "dynamic-page"` which disables the sync API entirely | Always use `figma.getNodeByIdAsync(id)` inside an async IIFE with outer `return`: `return (async () => { const n = await figma.getNodeByIdAsync(id); return n ? { id: n.id, x: n.x } : null; })()` |
| GROUP child position assignment lands at wrong screen location | Setting `child.x = 156; child.y = 807` on a GROUP child — the child appears at screen y=674 because GROUP children use the PARENT FRAME's coordinate space, not GROUP-local space | Offset by GROUP's position: `child.x = group.x + desiredLocalX; child.y = group.y + desiredLocalY`. Confirm with `child.absoluteBoundingBox.y - group.absoluteBoundingBox.y === desiredLocalY`. For FRAME children, x/y are always frame-local |
| `addComponentProperty` returned key not matching property name | `addComponentProperty('message', 'TEXT', 'default')` returns `"message#206:8"`, not `"message"`. Using the base name in `componentPropertyReferences` silently fails — no error, no binding | Always capture the return value: `const propKey = component.addComponentProperty('message', 'TEXT', val)`. Bind with returned key: `textNode.componentPropertyReferences = { characters: propKey }`. Use the base name only in `setProperties` on instances |
| Text wraps silently after instance override | When a text override is applied to an INSTANCE, Figma sets `textAutoResize=HEIGHT` with the component's default fixed width. If the override text is too long, it wraps silently | Detect: `textNode.height > fontSize * 1.5 * 1.5` signals wrapping. Fix: `textNode.textAutoResize = 'WIDTH_AND_HEIGHT'` (after loading font). Apply to any INSTANCE text override that might be width-constrained |
| `textAutoResize = 'WIDTH_AND_HEIGHT'` on FILL text competes | Setting `WIDTH_AND_HEIGHT` on a text node with `layoutSizingHorizontal = 'FILL'` creates two competing sizing systems — text wants to manage its own width while parent layout manages it | Use `textAutoResize = 'HEIGHT'` when text has `layoutSizingHorizontal = 'FILL'` in auto-layout. `HEIGHT` delegates width to the FILL constraint. Reserve `WIDTH_AND_HEIGHT` for free-floating text only |
| `inst.findOne(n => n.type === 'TEXT')` returns null on M3 buttons | M3 Button components do NOT expose label as a TEXT property. `findOne` returns null because Figma skips invisible children by default | Set `figma.skipInvisibleInstanceChildren = false` BEFORE traversing, find TEXT node, set `.characters`, then reset to `true` |
| GROUP bounding box expands after `setCurrentPageAsync` | After `await setCurrentPageAsync(handoffPage)`, GROUP child position assignments are interpreted in a shifted coordinate frame — GROUP width jumps unexpectedly | Set children using page-absolute coordinates (`child.x = sectionX + localX`), let GROUP auto-bounding recalculate. Never assign `group.x` directly after `setCurrentPageAsync` in the same IIFE |
| Container frame appears at non-zero x after append | Creating a FRAME with `resize(360, 56)` and appending to a parent with `layoutMode=NONE` — Figma assigns non-zero x based on internal layout state | Always explicitly set `container.x = 0; container.y = desiredY` AFTER appending. Never assume appending to `layoutMode=NONE` places child at x=0 |

---

## Recurring API Pattern Errors

These errors recur across sessions because context compaction discards previously learned workarounds.

| # | Error | Cause | Solution |
|---|-------|-------|----------|
| 1 | `combineAsVariants: Grouped nodes must be in the same page as the parent` | Page context mismatch when combining variants | Call `figma.setCurrentPageAsync()` before combining; ensure all nodes are on the same page |
| 2 | `node.reactions = x` throws in dynamic-page mode | Direct assignment to `reactions` fails on dynamically loaded pages | Use `setReactionsAsync()` instead of direct assignment |
| 3 | `node.mainComponent` throws | Accessing `mainComponent` on instances in lazy-loaded pages | Use `getMainComponentAsync()` |
| 4 | `action` field rejected — must use `actions[]` array | Reaction format uses singular `action` instead of `actions` array | Change to `actions: [{ type: 'NODE', ... }]` |
| 5 | `componentPropertyDefinitions` only on COMPONENT_SET | Accessing property definitions on a COMPONENT instead of its parent set | Navigate to parent COMPONENT_SET first |
| 6 | `figma_take_screenshot` scale parameter rejects number | String vs number type mismatch in scale parameter | Omit the scale parameter |
| 7 | `figma_set_description` fails on FRAME nodes | Description setter only works on COMPONENT and STYLE nodes | Only call on COMPONENT or STYLE nodes |

> **Root cause**: Raw Plugin API JavaScript exposes the AI to async mode requirements, page context issues, data format mismatches, and node type constraints. After context compaction, previously learned workarounds are lost and the same errors re-emerge.

---

## Connection and Transport Errors

The server tries WebSocket first (ports 9223-9232), then falls back to CDP (port 9222). Connection issues are the most common barrier to getting started.

**Diagnostic sequence for connection failures:**

1. Call `figma_get_status` to determine current connection state
2. Try `figma_reconnect` before manual intervention
3. If still disconnected, load `gui-walkthroughs.md` and guide the user through the relevant setup steps

| Error | Cause | Recovery |
|-------|-------|---------|
| `Failed to connect to Figma Desktop` | No transport available (neither WebSocket nor CDP) | Guide user through plugin setup — see `gui-walkthroughs.md` (Initial Setup + Per-Session sections) |
| `EADDRINUSE` port conflict | Multiple MCP instances competing for same port (pre-v1.10.0) | Update to v1.10.0+ for automatic port fallback (9223-9232). Guide user through re-import — see `gui-walkthroughs.md` (Post-Update section) |
| `Variables cache empty` | Plugin cache not populated or stale | Guide user through cache refresh — see `gui-walkthroughs.md` (Cache Refresh section) |
| `No plugin UI found` | Desktop Bridge Plugin not running in current file | Guide user through activation — see `gui-walkthroughs.md` (Per-Session section) |
| `ECONNREFUSED localhost:9222` | CDP not available | Informational if WebSocket works. For CDP setup, see `gui-walkthroughs.md` (Alternative Transport section) |

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
| Non-idempotent creation scripts | Re-running a script creates duplicate nodes every time | Before creating a named node, check: `const existing = figma.currentPage.findOne(n => n.name === "Target"); if (existing) return { id: existing.id, reused: true }`. Only create if not found |
| Overusing `figma_execute` for atomic operations | Each execute + console-logs pair costs ~2,000 tokens; accumulates to context overflow on large sessions | Use `return (async () => { ... return JSON.stringify(data); })()` form for operations that need data back; batch 3+ same-type operations into a single idempotent script (see `convergence-protocol.md` Batch Scripting Protocol); use native figma-console tools (`figma_search_components`, `figma_instantiate_component`, `figma_batch_create_variables`) instead of scripting those via `figma_execute` |
| **Building screens from text descriptions** | Text files (PRDs, reconstruction guides) cannot capture IMAGE fills, exact fonts, layer ordering, opacity, gradients, or spacing — 100% of produced screens will be visually incorrect | ALWAYS read source Figma nodes via `figma_node_children` before constructing screens. Text documents are supplementary context for annotations only — see `design-handoff` skill (product-definition plugin) |
| **Silent fallback to text when Figma access fails** | When source design cannot be read, silently building from text produces entirely wrong output; the user discovers the failure only after hours of work | If `figma_node_children` fails on ANY source screen, STOP immediately and inform the user. NEVER fall back to text-based construction |
| **No visual fidelity check during construction** | Deferring visual validation to the final phase allows N screens of wrong output to accumulate before any comparison | Run `figma_capture_screenshot` (Desktop Bridge, live state) after EVERY screen and compare against the before-screenshot. Do NOT defer to the final phase — see `design-handoff` skill (product-definition plugin) |
| **Building from scratch when cloning is possible** | Using `figma_create_frame` + manual child creation instead of `figma_node_clone` loses all IMAGE fills, exact fonts, and visual properties from the source design | Default to clone + restructure for ALL screens that exist in the Draft. Only build from scratch for screens with no source — see `design-handoff` skill (product-definition plugin) |
| **Batch-processing screens in Draft-to-Handoff** | Processing multiple screens simultaneously hides silent failures (empty clones, missing instances, broken constraints) and delays error detection by N screens | Process one screen at a time through the full pipeline. Validate each screen completely before proceeding to the next — see `design-handoff` skill (product-definition plugin) |
| **Not involving user for complex screen conversions** | The agent wastes tokens making assumptions about ambiguous elements, constraint types, and component matching — then discovers issues only at visual validation (too late) | Analyze the screen FIRST, present findings + questions to user for MODERATE/COMPLEX screens BEFORE cloning. Trivial screens proceed autonomously — see `design-handoff` skill (product-definition plugin) |
| **Using `figma_take_screenshot` to validate recent Plugin API mutations** | `figma_take_screenshot` uses the Figma REST API, which renders from the cloud-synced file state. Changes made via `figma_execute` are NOT reflected until the file is saved and synced. The REST API also caches renders — identical byte sizes across repeated calls confirm cache hits. There is no public API to force cache invalidation | Use `figma_capture_screenshot` (Desktop Bridge transport) which exports from the live plugin runtime state. `figma_take_screenshot` is only safe for validating already-saved designs |
| **Splitting page-switch and data-read across `figma_execute` calls** | `setCurrentPageAsync()` inside an async IIFE only sets the active page for that IIFE's execution. The next `figma_execute` call reverts to whichever page Figma Desktop has open — `figma.currentPage.findOne()` then searches the wrong page and returns null | All reads AND `setCurrentPageAsync()` must be in the **same async IIFE**. Or capture the page object reference once (`const p = figma.root.children.find(n => n.id === "24:2")`) and use `p.findOne()` directly — page object references remain valid across calls |
| **Assuming Desktop Bridge persists through long async sequences** | After successful sequential `figma_execute` calls (especially async IIFEs with font loading), the Desktop Bridge WebSocket may silently drop. Subsequent calls fail with `"Desktop Bridge plugin UI not found"`. CDP transport (REST screenshots) stays active but Plugin API is blocked | Gate multi-step sessions with `figma_get_status` between major steps. On dropout, instruct user to reopen the plugin from Figma's plugin menu. Do not assume Bridge availability persists indefinitely |

---

## Handoff-Specific Anti-Patterns

These patterns cause structural or visual failures specific to the Draft-to-Handoff workflow (orchestrated by the `design-handoff` skill, product-definition plugin). Each was empirically discovered during production screen processing (WK-01, WK-02, WK-03).

| Anti-Pattern | Problem | Solution |
|-------------|---------|---------|
| **Setting constraints on GROUP nodes** | GROUP nodes don't have the `constraints` property — assignment silently fails or throws `"object is not extensible"`. 30-60% of cloned screen children are GROUPs | Convert ALL GROUPs to transparent FRAMEs before setting constraints — see `recipes-components.md` GROUP→FRAME recipe. Run batch conversion on every cloned screen |
| **Calling `group.remove()` after moving children** | After all children are moved out, the GROUP auto-deletes. Explicit `remove()` throws `"node does not exist"`, and code after it in the same try-block is silently skipped (including constraint assignment) | Never call `group.remove()`. The GROUP is already gone when its last child is moved |
| **Uniform Y-shift for proportional resize** | Shifting all elements by `(newHeight - oldHeight) / 2` breaks proportional relationships between differently-anchored elements | Use per-constraint-type formulas: MIN keeps y, MAX pins to bottom, CENTER keeps proportional center, STRETCH resizes. See `recipes-foundation.md` Proportional Resize Calculator |
| **Using MAX when STRETCH is needed** | MAX pins the bottom edge only — element shifts but keeps height. STRETCH pins both edges — element resizes. Using MAX for fill-areas leaves gaps | Use STRETCH for elements that fill remaining space (e.g., content area between header and footer). Use MAX for fixed-height elements anchored to bottom |
| **`createInstance()` on COMPONENT_SET** | `createInstance()` works on COMPONENT (individual variant), NOT on COMPONENT_SET. Calling it on COMPONENT_SET fails silently or throws | Find the variant child first: `set.children.find(c => c.name.includes("Phase=Run"))`, then `variant.createInstance()` |
| **Normalizing colors across component variants** | Different variants intentionally use different colors (e.g., Run=green, Walk=blue). Copying fills from one variant to another produces incorrect results | Inspect the specific Draft source for EACH variant independently. Only change properties that actually differ between variants |
| **Modifying base component before cloning variants** | Modifying the first variant (e.g., adding "Run" label) then cloning it causes all clones to inherit that modification and say "Run" too | Clone N-1 times FIRST to create all variants, THEN modify each clone independently |
| **Skipping cornerRadius on handoff frames** | Cloned screens arrive without design system cornerRadius. Screen looks like a raw rectangle instead of a polished device frame | Apply `frame.cornerRadius = 32` and `frame.clipsContent = true` as the FIRST post-clone step, before any other transformation |
| **Building screens without analyzing first** | Jumping straight to cloning/transformation without analyzing the draft screen structure leads to wasted tokens when unexpected GROUPs, complex nesting, or ambiguities are discovered mid-process | Always run a Screen Analysis step BEFORE cloning: count GROUPs, determine viewport vs scrollable, identify component candidates, assess complexity. Ask user for non-trivial screens |
| **Not verifying icon positions after clone/resize** | INSTANCE icons inside GROUP containers get displaced below their parent ellipses after cloning and resizing. Telltale: GROUP that should be 64px tall shows as 110px | After any resize/shift on cloned screens, check all INSTANCE nodes recursively. For 24px icons in 64px ellipses: `icon.y` should equal `ellipse.y + 20` |
| **Using `resize()` on component instances** | `inst.resize(targetW, h)` changes the bounding box only — all internal children stay at their original sizes and proportions, producing a distorted/clipped result | Reset to natural size first: `inst.resize(naturalW, naturalH)`, then call `inst.rescale(targetW / naturalW)`. `rescale()` scales both bounds AND all children proportionally. Pattern: reset → rescale, never resize directly |
| **Setting instance label via `setProperties` when label is not exposed** | `setProperties({ 'Label text': 'value' })` on a component instance only affects properties explicitly exposed as component properties. Nested sub-instance labels (e.g., button label inside a card) and non-exposed text layers silently do nothing | Navigate to the nested TEXT node directly (`inst.findOne(n => n.type === 'TEXT')`) and set `node.characters = "value"` after `await figma.loadFontAsync(...)`. Direct character assignment bypasses the component property system |
| **`combineAsVariants` on incomplete variant sets** | If any node in the array has a different set of property keys in its name, `combineAsVariants` throws `"Component set has existing errors"` — the resulting set is unusable and cannot be repaired | Before calling `combineAsVariants`, ensure ALL nodes have names containing EVERY property: `Prop1=Val1, Prop2=Val2`. Verify with `nodes.every(n => n.name.includes("Progress="))`. If a bad set was created, delete it and regenerate |
| **Fixing component instance height instead of master variant** | When a component variant is created with `resize(w, 1)` and `primaryAxisSizingMode=FIXED`, the height is frozen at 1px. All instances inherit this collapsed bounding box. Fixing individual instances has no effect | Fix the MASTER variant directly: `variant.primaryAxisSizingMode = 'AUTO'` (height/primary axis for VERTICAL layout). Height recalculates from children immediately and all instances automatically inherit the corrected intrinsic height |
| **Creating instances via `getNodeByIdAsync` on cross-page components** | `getNodeByIdAsync('componentId')` syntactically works, but calling `.createInstance()` on the returned node and appending it may not persist reliably when the component lives on a different page context | Call `getMainComponentAsync()` on an **existing INSTANCE already on the current page**. The returned component reference is live: `const comp = await existingInst.getMainComponentAsync(); const newInst = comp.createInstance();` |
| **Trusting `get_design_context` for text override validation** | `get_design_context` (and Figma REST API) returns a component's **property defaults** as defined in the master component, not live `.characters` overrides set via Plugin API. All instances may appear to have placeholder text even when correctly set | Cross-check with Plugin API: `figma_execute` returning `node.characters` as ground truth. False-positive "Critical" findings from design-context readers are expected for any `.characters`-based override until the file is cloud-synced |
| **Wrapping only buttons in a container without associated text** | Creating a `buttons_container` that groups ONLY CTA buttons without their title and description text — produces broken layout where text floats outside, spacing breaks on resize | When grouping action elements, ALWAYS wrap the complete logical unit: `(title + description + button)` together. If text and button are visually grouped in Draft, they must be structurally grouped too |
| **Wrapping remote components in local COMPONENT wrappers** | Creating a local COMPONENT that wraps a remote M3 component to add custom typography — causes double text content, extra indirection, hardcoded text width causing wrapping bugs, breaks on M3 library updates | Use remote M3 component directly. Override fills for theming, set text via `.characters` on internal TEXT node, use `setProperties` for BOOLEAN properties. Override `fontName` on TEXT node if custom typography needed |
| **Adding auto-layout to frame with many loose children** | `layoutMode=VERTICAL` on a frame with manually-positioned children reflows them in document order from top, ignoring x/y positions — completely breaks visual layout. Destructive, no undo | Before adding AL: check children positions. If irregular, create a NEW empty AL container and move children preserving order. For too-complex content: build clean components, delete loose nodes, create fresh instances |
| **Not recalibrating screen height after structural content changes** | After replacing 30 loose nodes with 7 component instances, the original 1070px height has 458px of empty space. An over-tall screen misleads developers about scroll areas | Compute: `contentEnd = lastChild.y + lastChild.height`; resize to `contentEnd + 20-28px`. Check if viewport (target 871px) or scrollable (keep calculated). Never blindly keep original height |
| **Not pre-checking node existence before parallel subagents** | Spawning parallel audit/fix subagents with stale handoff_ids — agents run to completion on null nodes, return "success" summaries, failure invisible at orchestrator level | Run lightweight existence pre-check in MAIN context BEFORE spawning: batch-check all IDs in one `figma_execute` call. Fix stale IDs before any subagent launch |
| **Not verifying ALL fix issues in re-audit** | Fix subagent addresses 2 of 4 Major issues — the other 2 silently skipped. Orchestrator incorrectly assumes all resolved | After every fix subagent: enumerate each issue from previous audit by ID, verify each in new audit output. Issue absent from new report = still open. Never accept fix subagent's "what I fixed" summary as truth — only the audit is truth |
| **Not inspecting container structure before component replacement** | Replacing component instances in-place without checking parent container — cards end up as loose children with wrong spacing instead of inside the Draft's auto-layout container | Before ANY component replacement: inspect Draft parent's `layoutMode`, `itemSpacing`, `padding*`. If Draft has AL container, create matching container FIRST. After placement, verify `itemSpacing` matches |

---

## Regression Anti-Patterns

These patterns cause the system to **undo its own work** or **redo already-completed operations** after context compaction. Regression is the most destructive session-level failure — it wastes tokens, breaks deliberately tuned values, and can create infinite loops. Full prevention protocol in `convergence-protocol.md`.

| Anti-Pattern | Problem | Solution |
|-------------|---------|---------|
| Renaming already-renamed nodes | After context compaction, the AI renames nodes back to their original names or applies a second rename pass, undoing the first | Check `operation-journal.jsonl` for existing `rename` entries on the target node before renaming; use batch scripts with built-in `already_done` checks |
| Recreating already-created components | After compact, the AI creates a duplicate component because it doesn't remember the first | Check journal for `create_component` with the same name before creating; also check Figma: `figma.currentPage.findOne(n => n.name === "Target")` |
| Restarting a phase from scratch after compact | The AI loses phase progress and re-executes the entire phase, redoing all operations | Read journal + session snapshot after compact; resume from first uncompleted operation, not phase start |
| Restructuring already-restructured screens | After compact, the AI applies auto-layout, renames, and instance replacements to screens that were already processed | Check journal for `clone_screen` and `batch_rename` entries for the target screen before restructuring |
| Using in-context memory as truth after compact | The AI "remembers" partial state from before compact but that memory may be incomplete or wrong | ONLY trust the operation journal; in-context memory after compact is unreliable — see `convergence-protocol.md` Rule C6 |
| No idempotency in batch scripts | A batch `figma_execute` script modifies nodes unconditionally; if re-run after compact, it re-applies all changes | Include `if (node.name === r.name) { status: "already_done"; continue; }` checks in all batch scripts — see `convergence-protocol.md` Batch Script Templates |
| Using individual calls for 3+ same-type operations | 20 individual `figma_node_rename` calls consume ~2,000 tokens and 20 round-trips; a single batch script does the same in ~600 tokens and 1 round-trip | Batch homogeneous operations (renames, moves, fills) into `figma_execute` scripts — see `convergence-protocol.md` Batch Scripting Protocol |

---

## Performance Anti-Patterns

These patterns cause slow execution or excessive resource usage, especially on large Figma files.

| Anti-Pattern | Problem | Solution |
|-------------|---------|---------|
| `scrollAndZoomIntoView()` per node in a loop | Triggers viewport reflow on every iteration, compounding rendering cost | Collect all nodes in an array, call `figma.viewport.scrollAndZoomIntoView(allNodes)` once at the end |
| `findAll()` on large documents | Scans every node including invisible instance children; can take seconds on complex files | Use `figma.currentPage.findAllWithCriteria({ types: ['FRAME'] })` for type-filtered search (hundreds of times faster) |
| Not setting `skipInvisibleInstanceChildren` | Instance children inside collapsed/hidden instances are included in searches and iterations | Set `figma.skipInvisibleInstanceChildren = true` before any `findAll` or `findAllWithCriteria` call |
| `figma_get_file_data` on large files | Response can exceed 25K token limit, causing truncation or errors | Use `figma_get_file_for_plugin` for optimized output, or target specific nodes with `figma_capture_screenshot` |
| `figma_get_variables` with `format: "full"` | Full variable dump auto-summarizes above 25K tokens, losing detail | Start with `format: "summary"`, then use `format: "filtered"` with `collection`, `namePattern`, or `mode` parameters for specific data |
| Full-canvas `figma_take_screenshot` on complex files | Rendering the entire canvas is slow and captures unrelated content | Use `figma_capture_screenshot` with a specific `nodeId` for targeted validation |

> For the correct performance patterns (code examples), see the Performance Optimization section in `plugin-api.md`.

---

## Context and Buffer Anti-Patterns

These workflow-level patterns cause context window exhaustion and data loss from log buffer limits. Empirically observed across 7 production sessions (~600 MCP calls, 14 context compactions, 1 critical quality failure).

| Anti-Pattern | Problem | Solution |
|-------------|---------|---------|
| fire-log-verify pattern overuse | `figma_execute` + `figma_get_console_logs` pairs consume ~1,500-3,000 tokens each; 100+ pairs exhaust the context window | Use `return (async () => { ... return JSON.stringify(data); })()` for direct data retrieval; reserve console.log only when async return is not practical |
| Console log buffer rotation + tripling | Figma's console buffer holds ~100 entries. Each `console.log()` call inside `figma_execute` emits **3 identical entries** (not 1) — a script with 30 log calls fills the entire buffer, pushing out earlier entries | Call `figma_clear_console` before each `figma_execute` batch. Budget max ~18-20 `console.log` calls per IIFE. Use `return JSON.stringify(...)` (sync return with outer `return`) instead of `console.log` for data retrieval — avoids buffer tripling |
| No session state persistence | After context compaction, all created node IDs, positions, and intermediate state are lost | Write node IDs and phase state to a local file after each operation batch — see `convergence-protocol.md` Session Snapshot schema |
| Orphaned components from wrong phase order | Components created after screen cloning result in screens using old variants with zero new-component instances | Always create components before assembling screens; enforce strict phase ordering (see `convergence-protocol.md`) |
| Plans with assumed node IDs | Plans drafted with cached or guessed node IDs get rejected when IDs do not match live data | Always verify node IDs against live file data in a read-only inventory phase before drafting a plan |

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

### IMAGE Fill Limitation (CRITICAL for Draft-to-Handoff)

**The Figma Plugin API cannot create IMAGE fills from external sources in practice during design transfer workflows.** While `figma.createImageAsync(url)` exists, it requires network access from the plugin context and public URLs — neither of which is available when transferring existing designs between pages.

**The only reliable way to preserve IMAGE fills is to clone the source node** via `figma_node_clone`. Any workflow that creates screens from scratch instead of cloning will lose ALL image fills, replacing them with black rectangles or empty frames.

**Impact**: A Draft-to-Handoff workflow that builds screens from text descriptions or from scratch (instead of cloning) produces 100% incorrect output for any screen containing images — artwork, photos, backgrounds, illustrations are all lost.

**Rule**: When transferring designs between pages, ALWAYS use `figma_node_clone` for screens containing IMAGE fills. See the `design-handoff` skill (product-definition plugin) for the full preparation workflow.

### Any-Mode Limitations

These apply regardless of connection mode (local or remote):

- **No direct DOM/browser control** -- `figma_execute` runs in the Plugin API sandbox, not a browser context
- **No network requests from plugin context** -- cannot fetch external data from within `figma_execute`
- **No undo/redo programmatic control** -- Plugin API changes cannot be programmatically undone
- **No cross-file operations** -- each session operates on the single file where the Desktop Bridge is running (v1.10.0 supports multiple files with multiple plugin instances)
- **No Code Connect integration** -- unlike the Official Figma MCP, Console MCP does not support Code Connect
- **No FigJam support** -- cannot read or generate FigJam diagrams
- **No Figma Make resource retrieval**
- **No programmatic IMAGE fill creation for design transfer** -- `createImageAsync` requires public URLs; cloning is the only option for preserving images between pages (see IMAGE Fill Limitation above)

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
| `Failed to connect to Figma Desktop` | No transport available | `figma_get_status` returns disconnected | Guide user through `gui-walkthroughs.md` (Initial Setup + Per-Session) |
| `EADDRINUSE` | Multiple MCP instances on same port | Server startup fails | Update to v1.10.0+. Guide user through `gui-walkthroughs.md` (Post-Update) |
| `Variables cache empty` | Plugin cache not populated/stale | `figma_get_variables` returns empty | Guide user through `gui-walkthroughs.md` (Cache Refresh) |
| Silent failure in `figma_execute` | JS error in Plugin API code | Screenshot shows no change; no visible error | Wrap in try-catch. Check `figma_get_console_logs`. Validate with screenshot after every execute |
| Text not appearing | `loadFontAsync` not called before `.characters` | Screenshot shows empty text node | Always `await figma.loadFontAsync()` before setting text |
| Library variable ID resolution failure | Variable IDs from library components need async resolution | Variable binding fails silently | Use `getVariableByIdAsync()` for ID resolution |
| Component descriptions missing | Known Figma API limitation | Component data lacks `description` field | Use `figma_set_description` via Plugin API |
| Infinite screenshot loop | Agent keeps finding minor issues | Session stalls with repeated screenshot-fix cycles | Hard cap: 3 cycles. Set acceptance criteria before starting |
| Rate limiting (HTTP 429) | Figma REST API limits exceeded | API calls return 429 status | Wait and retry. Limits vary by plan (see below) |
| Claude Code SSE transport bug | Known bug in Claude Code native `--transport sse` | Connection fails in Claude Code | Use `mcp-remote` workaround: `npx -y mcp-remote@latest https://...` |
| `figma_navigate` does not navigate | WebSocket-only mode lacks browser-level navigation | Tool returns file info instead of navigating | Expected behavior in WebSocket mode. Ensure correct file is already open. Use CDP transport for actual navigation |
| Truncated responses on large files | File data exceeds response size | Response appears incomplete | Use `figma_get_file_for_plugin` instead of `figma_get_file_data`. Use filtered variable queries. Target specific nodes rather than entire file |
| `No plugin UI found` | Desktop Bridge Plugin not running | `figma_get_status` shows no plugin connection | Guide user through `gui-walkthroughs.md` (Per-Session) |

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

## Prototype Anti-Patterns

> **Node type support for reactions**: Per ReactionMixin, TEXT, RECTANGLE, ELLIPSE, VECTOR, POLYGON, STAR, and LINE all support reactions. Only GROUP silently drops them. Do not assume that shape primitives like TEXT or RECTANGLE lack reaction support — they fully support it.

| Anti-Pattern | Consequence | Correct Pattern |
|-------------|-------------|-----------------|
| Using `action` (singular) in Reaction | Deprecated format, may be silently ignored | Use `actions` array (plural) — supports multi-action per trigger |
| `ON_MEDIA_HIT` timeout in milliseconds | Wrong unit — causes timing errors | `mediaHitTime` uses **seconds**, not milliseconds |
| Overlay properties set via Plugin API | `overlayPositionType`, `overlayBackground`, `overlayBackgroundInteraction` are **readonly** in Plugin API | Set overlay properties via Figma UI before prototype wiring |
| Not verifying reactions after SET_VARIABLE wiring | Silent failures go undetected | Re-read `node.reactions` after `setReactionsAsync` to confirm write succeeded |

---

## Grid Layout Anti-Patterns

| Anti-Pattern | Consequence | Correct Pattern |
|-------------|-------------|-----------------|
| Using `itemSpacing` on Grid container | Silently ignored — Grid uses gaps, not spacing | Use `gridRowGap` and `gridColumnGap` instead |
| HUG container + FLEX track sizes | Runtime error — FLEX requires determinate container size | Use FIXED or HUG track sizes with HUG container, or FIXED container with FLEX tracks |
| Reducing `gridRowCount` below occupied rows | Throws error — cannot remove tracks with children | Relocate or remove children from outer rows first |
| Assuming auto-placement into grid cells | Children placed at (0,0) by default, not auto-flowing | Explicitly position with `appendChildAt(node, row, col)` |

---

> **Cross-references**: For correct operation patterns and code templates, see `plugin-api.md`. For spacing, typography, and layout rules, see `design-rules.md`.
