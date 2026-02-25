# Field Learnings — Production Strategies & Workflows

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Effective strategies, workflows, and patterns empirically discovered during production Figma sessions. These are NOT API errors (see `anti-patterns.md`) or API reference (see `plugin-api.md`) — they are hard-won "how to do it right" patterns from building real screens.
>
> **Source**: Distilled from `~/.figma-console-mastery/learnings.md` cross-session knowledge base.
>
> **Graduation policy**: Patterns that stabilize after 2-3 sessions should be promoted to their canonical owner file (`plugin-api.md`, `anti-patterns.md`, `recipes-components.md`, etc.), with this file retaining only a cross-reference. This keeps `field-learnings.md` as a staging area for empirically-discovered patterns, not a permanent parallel reference.

---

## Componentization Workflows

### Componentize from Clone (6-step)

Convert an existing raw FRAME in a screen into a reusable DS component without losing the original instance position.

```
Step 1: Record origX, origY, origW, origH, origParent from rawFrame
Step 2: clone = rawFrame.clone(); dsSection.appendChild(clone)
Step 3: component = figma.createComponentFromNode(clone); component.name = 'Name'
Step 4: addComponentProperty + bind textNode using RETURNED key
        (addComponentProperty returns a disambiguated key like "message#206:8")
Step 5: instance = component.createInstance()
        origParent.appendChild(instance)
        instance.resize(origW, origH)
        instance.x = origX; instance.y = origY
Step 6: rawFrame.remove()
```

Verify with `getMainComponentAsync()` on the instance.

### Create DS Component from Scratch (6-step)

For purpose-built new components with no source frame to clone from.

```
Step 1: Load fonts (await Promise.all([figma.loadFontAsync(...)]))
Step 2: Create parent FRAME with desired auto-layout
Step 3: Create child nodes (TEXT, FRAME, cloned INSTANCE) and append
Step 4: Find safe x in dsSection (maxX of existing children + 40px)
Step 5: dsSection.appendChild(rowFrame)
Step 6: component = figma.createComponentFromNode(rowFrame)
        addComponentProperty -> bind returned key
```

Key detail: clone needed icons/switches from an EXISTING instance in the current scene (e.g., `existingSwitch.clone()`). Do NOT use `getNodeByIdAsync` on a component ID that may live on a different page context.

### Component Property Binding vs Instance Override

Two distinct operations require two distinct identifiers:

| Operation | Context | Identifier to Use |
|-----------|---------|-------------------|
| **Binding** (inside component, once) | `textNode.componentPropertyReferences = { characters: key }` | The RETURNED key from `addComponentProperty` (e.g., `"day#222:62"`) |
| **Setting value** (on each instance) | `inst.setProperties({ day: 'Monday' })` | The PROPERTY NAME — the first argument to `addComponentProperty` (e.g., `"day"`) |

If `setProperties` silently does nothing, verify the property name matches exactly (case-sensitive) and that the binding was done correctly inside the master component.

---

## Component Migration Patterns

### swapComponent In-Place Migration

> See `plugin-api.md` § Component Properties for the full `swapComponent` code pattern (capture x/y/w/h/constraints before, restore after).

**Field insight**: Component properties from the OLD component are gone after swap — set new properties by name or by finding TEXT nodes directly. This is the most common post-swap surprise.

### M3 Remote Component Property Access

M3 App Bar (and similar remote M3 components) do NOT expose a TEXT component property for the Headline.

**For text**: find the TEXT node directly — `inst.findAll(n => n.type === 'TEXT')`, filter by `n.name === 'Headline'` and `n.visible !== false`. Load font and set `.characters`.

**For boolean properties**: inspect `inst.componentProperties` to get the exact key (including `#ID` suffix), then `inst.setProperties({ [exactKey]: false })`. Figma may accept just the base name if the property name is unambiguous.

### Remote Component Fill Override

Remote M3 components render with baseline color tokens (e.g., purple-tinted surface). Override fills directly on the INSTANCE node:

```javascript
inst.fills = [{ type: 'SOLID', color: { r: 247/255, g: 242/255, b: 233/255 }, opacity: 1 }]
```

This overrides computed fills from the component hierarchy and is stable regardless of the M3 library's internal structure.

### Wrapper Component Anti-Pattern

Wrapping a remote component inside a local COMPONENT to overlay custom elements causes: (1) double text content, (2) extra indirection layer, (3) hardcoded width on text causing wrapping bugs, (4) breaks on remote component layout changes.

**Solution**: Use the remote M3 component directly. Override fills for theming, set text via `.characters` on the internal TEXT node, use `setProperties` for BOOLEAN properties.

---

## Container & Layout Strategies

### Replace Component — Inspect Container First

Before replacing ANY set of component instances, run a mandatory pre-check on the Draft:

1. Inspect the parent of the target instances: `parent.layoutMode`, `parent.itemSpacing`, `parent.padding*`
2. If Draft has auto-layout container: create matching container in Handoff BEFORE placing new instances
3. After placement, verify `itemSpacing` matches Draft — never assume default 0 spacing
4. Post-check: screenshot both Draft and Handoff side-by-side to confirm spacing visually

### Auto-Layout for Repeated Identical Components

Any 2+ instances of the same component stacked/aligned = **Major** issue if not inside an auto-layout frame. The audit must check: `parent.layoutMode !== 'NONE'` for the common parent. If the parent is the screen root itself, a wrapper container should exist.

### SPACE_BETWEEN for 2-Child Rows

> See `plugin-api.md` § Auto-Layout Gotchas for the `SPACE_BETWEEN` property reference.

**Field insight**: For exactly-2-child HORIZONTAL rows, `SPACE_BETWEEN` eliminates the need for spacers, avoids Check C violations, and avoids hardcoded widths. Does NOT work when uniform `itemSpacing` is needed across 3+ children.

### Wrap Loose Instances in Auto-Layout Container

Script pattern for wrapping N loose instances in a VERTICAL auto-layout container:

```
Step 1: createFrame -> set layoutMode=VERTICAL, itemSpacing=N, fills=[], resize(w, 1)
Step 2: Append each instance, then set child.layoutSizingHorizontal="FILL"
        and child.layoutSizingVertical="HUG"
Step 3: Trigger height recalc: primaryAxisSizingMode="FIXED",
        resize(w, estimatedH), primaryAxisSizingMode="AUTO"
Step 4: Set container.constraints
```

Measure `itemSpacing` from existing instance y-gaps: `gap = instances[1].y - (instances[0].y + instances[0].height)`. Set container position from first instance x/y.

### Check Before Adding Auto-Layout to Existing Frame

Adding `layoutMode=VERTICAL` to a frame with manually-positioned children does NOT rearrange them to their visual positions — it reflows them in document order from the top, ignoring all x/y coordinates. This is destructive with no undo.

**Before adding auto-layout to any non-AL frame with children:**
1. Check children count and y-positions — if irregular/inconsistent, do NOT add AL in-place
2. Instead: create a NEW empty VERTICAL AL container, move children preserving order
3. When content is too complex: build a clean component, delete loose nodes, create fresh instances

### Buttons Container Anti-Pattern

Creating a `buttons_container` that groups ONLY button instances without their associated title and description text produces a broken layout. The container is sized to buttons only, text nodes float outside.

**Rule**: When grouping action elements, ALWAYS wrap the complete logical unit: `(title + description + button)` all together. If text and button are visually grouped in the Draft, they must be structurally grouped too.

### Container X-Drift After Append

When creating a FRAME and appending it to a parent with `layoutMode=NONE`, Figma may assign a non-zero x based on internal state.

**Always explicitly set** `container.x = 0; container.y = desiredY` AFTER appending. Never assume appending to a `layoutMode=NONE` frame places the child at x=0.

---

## Screen-Level Strategies

### Screen Height Recalibration After Content Change

After any structural fix that changes content height (e.g., replacing 30 loose nodes with 7 component instances), compute: `contentEnd = lastChild.y + lastChild.height`, then `screen.resize(360, contentEnd + bottomPadding)` where `bottomPadding = 20-28px`.

Check whether the screen is a viewport screen (target 871px) or truly scrollable (keep calculated height). Do NOT blindly keep the original height — an over-tall screen misleads developers about scroll areas.

### ToggleRow Settings Gate Pattern

Standard Settings screen ToggleRow placement: y=84 (immediately below TopBar h=84), width=360px, constraints STRETCH/MIN.

After appending: shift content below by ToggleRow height. Then check if content now exceeds screen height — if so, expand: `if (content.y + content.height + 24 > screen.height) screen.resize(360, content.y + content.height + 24)`.

---

## Text Handling

### textAutoResize + FILL Interaction

> See `anti-patterns.md` § Common Plugin API Errors for the textAutoResize + FILL rule. See `plugin-api.md` § Text Properties for the property reference.

**Field insight**: The competing sizing systems manifest as text that either overflows its container or refuses to grow. The decision tree: `FILL` parent → use `'HEIGHT'`; free-floating → use `'WIDTH_AND_HEIGHT'`.

### Text Wrapping Detection on Instance Overrides

> See `anti-patterns.md` § Common Plugin API Errors for the error pattern and fix.

**Field insight — detection heuristic**: `textNode.height > fontSize * 1.5 * 1.5` signals silent wrapping caused by instance override text exceeding the component's default fixed width. This heuristic catches wrapping before visual inspection does.

### M3 Button Label Text — Skip Invisible Children

> See `anti-patterns.md` § Common Plugin API Errors for the `skipInvisibleInstanceChildren` error pattern and code fix.

**Field insight**: This affects ALL M3 components with nested invisible layers, not just Buttons. Always toggle `skipInvisibleInstanceChildren` when traversing remote library component instances to find TEXT nodes for override.

---

## Cross-Call Data Patterns

### globalThis for Cross-Call Data Persistence

> See `plugin-api.md` § State Tracking for the full `globalThis` pattern with code examples.

**Field insight**: Use unique key names per operation (e.g., `globalThis.__swapResult`, not `globalThis.__result`) to avoid collisions when multiple workflows run in the same session. This is the most reliable pattern for async → sync data handoff across `figma_execute` calls.

### Page Object for Cross-Page findOne

After `setCurrentPageAsync(draftPage)` reverts in subsequent calls, `figma.currentPage.findOne()` searches the wrong page. Capture the page object once and use it directly:

```javascript
const draftPage = figma.root.children.find(p => p.id === "24:2");
draftPage.findOne(n => n.name === "Target");  // always searches correct page
```

### findOne Duplicate Ambiguity

`page.findOne(n => n.name === 'TopBar')` returns the FIRST match in document order. If multiple nodes share a name across screens, the result is non-deterministic.

**Always prefer node ID lookups**: `await figma.getNodeByIdAsync('222:14767')`. When name-based search is necessary, scope to the correct parent: `screen.findOne(...)` instead of `page.findOne(...)`.

---

## Variant & Component Set Patterns

### Adding Variant to Existing Component Set

There is no `addVariant()` API. Pattern:

```
Step 1: clone = existingVariant.clone()
Step 2: componentSet.appendChild(clone)
Step 3: clone.name = "State=Error"  (match property key names exactly)
```

Figma auto-updates `componentSet.variantGroupProperties` after append+rename.

### Component Property Definitions — Component Set Only

`node.componentPropertyDefinitions` is only available on `COMPONENT_SET` nodes. For a variant COMPONENT, navigate to its parent:

```javascript
const defs = node.parent?.type === 'COMPONENT_SET'
  ? node.parent.componentPropertyDefinitions
  : node.componentPropertyDefinitions;
```

### External Library Component Sets

`getNodeByIdAsync('externalId')` returns the node but `.parent` is `undefined` for external library nodes. Cannot move or re-parent — only create instances.

Check: `const mc = await inst.getMainComponentAsync(); if (mc.remote) { /* use createInstance, never appendChild */ }`.

---

## Coordinate Systems

### GROUP Children — Parent Frame Space

Children of a GROUP report `x`/`y` relative to the **containing FRAME**, not the GROUP. To set position:

```javascript
child.x = group.x + desiredLocalX;
child.y = group.y + desiredLocalY;
```

Confirm: `child.absoluteBoundingBox.y - group.absoluteBoundingBox.y === desiredLocalY`.

### SECTION Children — Section-Relative Coordinates

SECTION children `x`/`y` are relative to the SECTION's origin, not page-absolute.

```javascript
// Page-absolute position of a section child:
absX = section.x + child.x;
// Position child at desired page coordinate:
child.x = desiredPageX - section.x;
```

Confirm with `child.absoluteBoundingBox.x/y`.

### GROUP Coordinate Shift After setCurrentPageAsync

After `await setCurrentPageAsync(handoffPage)`, GROUP child position assignments are interpreted in a shifted coordinate frame.

**Solution**: Set children using page-absolute coordinates (`child.x = sectionX + localX`), then let the GROUP's auto-bounding recalculate. Never assign `group.x` directly after `setCurrentPageAsync` in the same IIFE.

---

## Audit Script Performance

### Single-Pass O(N) Classification

Avoid running 5 separate `allNodes.filter()` passes. Instead, build all typed buckets in one loop:

```javascript
const instanceNodes = [], frameNoAL = [], allFrames = [];
const frameVertAL = [], frameAnyAL = [];

for (const node of allNodes) {
  if (node.type === 'INSTANCE') { instanceNodes.push(node); continue; }
  if (node.type !== 'FRAME') continue;
  allFrames.push(node);
  const mode = node.layoutMode;
  if (!mode || mode === 'NONE') { frameNoAL.push(node); continue; }
  if (mode === 'VERTICAL') frameVertAL.push(node);
  frameAnyAL.push(node);
}
```

Batch `getMainComponentAsync()` via `Promise.all` for parallel resolution. Use a `parentCache = new Map()` for O(1) parent lookups.

---

## Instance Creation Patterns

### Create Instance via Existing Instance Reference

`getNodeByIdAsync('componentId')` + `.createInstance()` + `appendChild()` may not persist reliably when the component lives on a different page. Instead:

```javascript
const existingInst = page.findOne(n => n.type === 'INSTANCE' && n.name.includes('PrimaryCTAButton'));
const comp = await existingInst.getMainComponentAsync();
const newInst = comp.createInstance();
```

### Nested Instance Property Access

For button labels inside nested component instances: navigate to the nested Content sub-instance and call `setProperties` with the full qualified key `Label text#<nodeId>`. Alternatively, traverse `children` to find the TEXT node directly and set `.characters`.

### Instance Resize vs Rescale

`inst.resize(targetW, h)` changes bounding box only — children stay at original sizes. Use `inst.rescale(targetW / naturalW)` to scale proportionally. Pattern: reset to natural size first, then rescale.

---

## Cross-References

- **Anti-patterns** (API errors, common failures): `anti-patterns.md`
- **Plugin API** (property tables, operation order): `plugin-api.md`
- **Visual QA protocol** (audit templates, scoring): `visual-qa-protocol.md`
- **Convergence protocol** (journal, anti-regression): `convergence-protocol.md`
- **Component recipes** (GROUP->FRAME, component creation): `recipes-components.md`
