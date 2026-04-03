# Plugin API — Foundation (Operation Order, Node Creation, Auto-Layout, CSS Grid)

> **Compatibility**: Verified against Figma Plugin API via figma-console-mcp v1.11.2 (February 2026)
>
> **Scope**: Operation order, node creation methods, auto-layout system, CSS Grid layout. For text, colors, effects, images, and cross-page operations, see `plugin-api-visuals.md`. For components, prototypes, variables, and performance, see `plugin-api-advanced.md`.

> For M3 specs to use in code, see `design-rules.md`. For complete working recipes, see `recipes-foundation.md`, `recipes-components.md`, and `recipes-advanced.md`. For error recovery, see `anti-patterns.md`.

---

## Operation Order (Always Follow This)

```
┌─────────────────────────────────────────────────┐
│ 1. LOAD ALL FONTS UPFRONT                       │
│    await Promise.all([                          │
│      figma.loadFontAsync({family:'Inter',       │
│        style:'Regular'}),                       │
│      figma.loadFontAsync({family:'Inter',       │
│        style:'Bold'}),                          │
│    ])                                           │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 2. CREATE PARENT FRAME + SET layoutMode FIRST   │
│    const frame = figma.createFrame()            │
│    frame.name = "Screen/Home"                   │
│    frame.layoutMode = 'VERTICAL'                │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 3. SET SIZING + DIMENSIONS                      │
│    frame.layoutSizingHorizontal = 'FIXED'       │
│    frame.layoutSizingVertical = 'HUG'           │
│    frame.resize(375, 1)                         │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 4. SET PADDING → SPACING → ALIGNMENT            │
│    frame.paddingTop = 24 (etc.)                 │
│    frame.itemSpacing = 16                       │
│    frame.primaryAxisAlignItems = 'MIN'          │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 5. SET VISUAL PROPERTIES                        │
│    frame.fills = [...]; frame.cornerRadius = 8  │
│    frame.clipsContent = true; frame.effects=[…] │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 6. FOR EACH CHILD:                              │
│    a. Create + name + visual props              │
│    b. Text: fontName → characters → fontSize    │
│    c. frame.appendChild(child)                  │
│    d. child.layoutSizingHorizontal = 'FILL'     │
│       (MUST be AFTER appendChild!)              │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 7. SET MIN/MAX CONSTRAINTS (last)               │
│    frame.minHeight = 100; frame.maxHeight = 800 │
└─────────────────────┬───────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│ 8. POSITION + VIEWPORT                          │
│    figma.viewport.scrollAndZoomIntoView([frame])│
└─────────────────────────────────────────────────┘
```

**Critical ordering rules:**
1. Fonts -> before any text operations
2. `layoutMode` -> before ALL layout properties (padding, spacing, sizing, alignment, min/max)
3. Parent frame config -> before children
4. `fontName` -> before `characters` on text nodes
5. `resize()` -> after `layoutMode` and sizing mode
6. `appendChild()` -> before `layoutSizingHorizontal/Vertical = 'FILL'` or `layoutAlign = 'STRETCH'`
7. Clone -> before modify for fills/strokes/effects
8. `layoutWrap = 'WRAP'` -> before `counterAxisAlignContent`
9. Min/max constraints -> after `layoutMode` is set

---

## Node Creation Methods

| Node | Creation Method | Notes |
|------|----------------|-------|
| Frame | `figma.createFrame()` | Supports auto-layout, clipsContent, children |
| Rectangle | `figma.createRectangle()` | No children. Supports cornerRadius |
| Ellipse | `figma.createEllipse()` | Supports `arcData` for arcs/donuts |
| Line | `figma.createLine()` | Height must be **0**: `line.resize(200, 0)` |
| Polygon | `figma.createPolygon()` | `pointCount` sets sides |
| Star | `figma.createStar()` | `pointCount`, `innerRadius` (0-1) |
| Text | `figma.createText()` | **MUST** `await figma.loadFontAsync()` first |
| Vector | `figma.createVector()` | Set `vectorPaths` with SVG path data |
| Component | `figma.createComponent()` | Like Frame + component features |
| ComponentSet | `figma.combineAsVariants(comps, parent)` | **No `createComponentSet()`** |
| Instance | `component.createInstance()` | **No `figma.createInstance()`** |
| Group | `figma.group(nodes, parent)` | **No `figma.createGroup()`**. Auto-resizes |
| Boolean Op | `figma.union/subtract/intersect/exclude()` | `createBooleanOperation()` **DEPRECATED** |
| Page | `figma.createPage()` | Auto-appended to document |
| Section | `figma.createSection()` | Canvas organizer |
| Slice | `figma.createSlice()` | Export regions |
| Text Path | `figma.createTextPath(vectorNode, startSeg, startPos)` | Text on a vector path. Returns TEXT_PATH node |
| Transform Group | `figma.transformGroup(nodes, parent, index, modifiers)` | Wraps nodes with transform modifiers |
| SVG Import | `figma.createNodeFromSvg(svgString)` | Returns FrameNode |

`parent.appendChild(child)` works on Frame, Component, ComponentSet, Group, Instance, Page, Section, BooleanOperation nodes. `insertChild(index, child)` places at a specific z-index.

> **Figma Draw APIs** (Update 123, January 2026): New node types `TEXT_PATH` and `TRANSFORM_GROUP` support text-on-a-path and transform groups. New properties: `complexStrokeProperties` (brush strokes), `variableWidthStrokeProperties` (variable-width profiles). Use `figma.loadBrushesAsync(brushType)` to load first-party brushes.

**`width` and `height` are READ-ONLY.** Always use `resize(w, h)`. `resizeWithoutConstraints(w, h)` is faster (skips child constraint propagation).

### Node Creation Patterns

Quick-reference snippets for common node types. See the table above for the full method list.

**Rectangle** — shape with fill and rounded corners:
```javascript
const rect = figma.createRectangle()
rect.name = "Card Background"
rect.resize(200, 120)
rect.fills = [figma.util.solidPaint('#E8DEF8')]
rect.cornerRadius = 12
figma.currentPage.appendChild(rect)
```

**Ellipse** — perfect circle:
```javascript
const circle = figma.createEllipse()
circle.name = "Avatar"
circle.resize(48, 48)  // equal width/height = circle
circle.fills = [figma.util.solidPaint('#6750A4')]
```

**Line** — horizontal rule with stroke:
```javascript
const line = figma.createLine()
line.name = "Divider"
line.resize(320, 0)  // height MUST be 0
line.strokes = [figma.util.solidPaint('#CAC4D0')]
line.strokeWeight = 1
```

**Vector** — custom shape from SVG path data:
```javascript
const vec = figma.createVector()
vec.name = "Checkmark"
vec.vectorPaths = [{ windingRule: 'NONZERO', data: 'M 4 11 L 9 16 L 20 5' }]
vec.strokes = [figma.util.solidPaint('#1B5E20')]
vec.strokeWeight = 2
```

**Group** — wrap existing nodes (no `createGroup`):
```javascript
// nodes must already share the same parent
const group = figma.group([nodeA, nodeB], figma.currentPage)
group.name = "Grouped Items"
// group auto-resizes to fit children; x/y/resize not needed
```

**Section** — canvas organizer:
```javascript
const section = figma.createSection()
section.name = "Home Screen"
section.resize(800, 600)
section.fills = [figma.util.solidPaint('#F5F5F5')]
```

**Boolean Operations** — use `figma.union()` / `figma.subtract()`, NOT `createBooleanOperation()`:
```javascript
// operands are consumed (removed from parent and placed inside the result)
const merged = figma.union([shapeA, shapeB], figma.currentPage)
merged.name = "Combined Shape"

const cutout = figma.subtract([base, hole], figma.currentPage)
cutout.name = "Icon Cutout"
// also: figma.intersect(), figma.exclude()
```

**SVG Import** — returns a FrameNode containing vector children:
```javascript
const svgNode = figma.createNodeFromSvg(
  '<svg width="24" height="24"><path d="M12 2L2 22h20z" fill="#6750A4"/></svg>'
)
svgNode.name = "Triangle Icon"
// override colors on the imported vectors
svgNode.findAll(n => n.type === 'VECTOR').forEach(v => { v.fills = [figma.util.solidPaint('#1D1B20')] })
```

**Page** — new page (auto-appended to document):
```javascript
const page = figma.createPage()
page.name = "Prototypes"
// switch to it: figma.currentPage = page
```

**Convert Frame to Component** — `figma.createComponentFromNode()`:
```javascript
// turns any existing frame into a component, preserving children and layout
const comp = figma.createComponentFromNode(existingFrame)
comp.name = "Card"  // now usable as a component with createInstance()
```

**Import Remote Component by Key** — `figma.importComponentByKeyAsync()`:
```javascript
// imports a library component by its key (from figma_search_components) and creates an instance
const component = await figma.importComponentByKeyAsync("abc123def456")
const instance = component.createInstance()
instance.x = 100
instance.y = 100
figma.currentPage.appendChild(instance)
```

### Inside-Out Construction Pattern

Build from leaf nodes inward to containers. Create children first, configure them, then create the parent frame and `appendChild`. This prevents dimension collapse: an auto-layout frame with `'AUTO'` sizing starts at 0×0 if empty, and children added later may not trigger immediate recalculation.

```javascript
// CORRECT — Inside-Out: children ready before container
const icon = figma.createRectangle()
icon.name = "Icon"
icon.resize(24, 24)

const label = figma.createText()
label.fontName = { family: "Inter", style: "Medium" }  // Font must already be loaded
label.characters = "Submit"
label.fontSize = 14

const button = figma.createFrame()
button.name = "Button"
button.layoutMode = "HORIZONTAL"
button.primaryAxisSizingMode = "AUTO"
button.counterAxisSizingMode = "AUTO"
button.itemSpacing = 8
button.paddingLeft = 16; button.paddingRight = 16
button.paddingTop = 10; button.paddingBottom = 10

button.appendChild(icon)
button.appendChild(label)
// Button now auto-sizes around its children correctly
```

For complex builds (full pages), use Outside-In with explicit sizing: create the page shell with FIXED dimensions first, then populate with children. Inside-Out is best for components and molecules.

---

## Auto-Layout System

### Frame-Level Properties

| Property | Values | Default | Description |
|----------|--------|---------|-------------|
| `layoutMode` | `'NONE'`\|`'HORIZONTAL'`\|`'VERTICAL'`\|`'GRID'` | `'NONE'` | **Set FIRST**. `'GRID'` enables CSS Grid — see Grid Layout section |
| `layoutWrap` | `'NO_WRAP'`\|`'WRAP'` | `'NO_WRAP'` | Flex-wrap |
| `primaryAxisSizingMode` | `'FIXED'`\|`'AUTO'` | `'AUTO'` | AUTO = hug contents |
| `counterAxisSizingMode` | `'FIXED'`\|`'AUTO'` | `'AUTO'` | AUTO = hug contents |
| `primaryAxisAlignItems` | `'MIN'`\|`'CENTER'`\|`'MAX'`\|`'SPACE_BETWEEN'` | `'MIN'` | justify-content |
| `counterAxisAlignItems` | `'MIN'`\|`'CENTER'`\|`'MAX'`\|`'BASELINE'` | `'MIN'` | align-items |
| `counterAxisAlignContent` | `'AUTO'`\|`'SPACE_BETWEEN'` | `'AUTO'` | **WRAP frames only** |
| `paddingTop/Bottom/Left/Right` | `number` | `0` | Padding px |
| `itemSpacing` | `number` | `0` | Gap along primary axis |
| `counterAxisSpacing` | `number\|null` | `null` | Wrap row/col gap |
| `itemReverseZIndex` | `boolean` | `false` | First child on top |
| `strokesIncludedInLayout` | `boolean` | `false` | border-box equivalent |

### Child-Level Properties

| Property | Values | Default | Description |
|----------|--------|---------|-------------|
| `layoutAlign` | `'INHERIT'`\|`'STRETCH'` | `'INHERIT'` | Cross-axis stretch |
| `layoutGrow` | `0`\|`1` | `0` | 1 = fill remaining primary space |
| `layoutPositioning` | `'AUTO'`\|`'ABSOLUTE'` | `'AUTO'` | ABSOLUTE enables x/y |
| `minWidth/maxWidth` | `number\|null` | `null` | Set AFTER layoutMode |
| `minHeight/maxHeight` | `number\|null` | `null` | Set AFTER layoutMode |

### Shorthand Properties (Preferred)

| Property | Values | Description |
|----------|--------|-------------|
| `layoutSizingHorizontal` | `'FIXED'`\|`'HUG'`\|`'FILL'` | HUG: auto-layout frames/text only. FILL: auto-layout children only |
| `layoutSizingVertical` | `'FIXED'`\|`'HUG'`\|`'FILL'` | Same rules |

### Axis Mapping

**HORIZONTAL:** primary = X (width), counter = Y (height). `layoutGrow` stretches horizontally. `STRETCH` stretches vertically.

**VERTICAL:** primary = Y (height), counter = X (width). `layoutGrow` stretches vertically. `STRETCH` stretches horizontally.

Prefer `layoutSizingHorizontal/Vertical` over lower-level properties to avoid axis-flipping confusion.

### Gotchas

- **x/y ignored:** Writing `x`/`y` on auto-layout children is silently ignored unless `layoutPositioning = 'ABSOLUTE'`
- **Toggling is DESTRUCTIVE:** `layoutMode = 'VERTICAL'` then `'NONE'` does NOT restore child positions
- **STRETCH + AUTO conflict:** Frame cannot hug children AND have a child stretching to fill it
- **HUG/FILL restrictions:** `'HUG'` throws on non-auto-layout frames. `'FILL'` throws on nodes outside auto-layout
- **resize() in auto-layout:** No-ops on AUTO (hug) dimensions
- **Min/max before layoutMode:** Throws error. Always set `layoutMode` first
- **Insertion order = flow order:** First `appendChild` = first in layout. `itemReverseZIndex` reverses z only, not flow
- **Auto-layout frame collapse to h=1:** Frames with text children may collapse height. Fix: `resize()` to explicit height first, then re-set `primaryAxisSizingMode = 'AUTO'`
- **SPACE_BETWEEN for 2-child rows:** For exactly-2-child HORIZONTAL rows where left and right elements should be at opposite edges, use `primaryAxisAlignItems = 'SPACE_BETWEEN'`. No spacer needed, no hardcoded widths. Does NOT work for 3+ children needing uniform spacing — use `itemSpacing` for those

### CSS Grid Layout

> Added in Plugin API Update 115 (July 2025), extended in Update 120 (November 2025).

CSS Grid is a 2D layout mode distinct from the 1D flex-based auto-layout (`HORIZONTAL`/`VERTICAL`). Enable it with `layoutMode = 'GRID'`. Grid and flex modes are **mutually exclusive** on a frame.

> **Do not confuse** `layoutMode = 'GRID'` (actual 2D layout engine) with `layoutGrids` (visual overlay guides). They are independent features.

#### Container Properties

| Property | Type | Default | Notes |
|----------|------|---------|-------|
| `gridRowCount` | `number` | `1` | Min 1. Cannot reduce below occupied rows |
| `gridColumnCount` | `number` | `1` | Min 1. Cannot reduce below occupied columns |
| `gridRowGap` | `number` | `0` | Pixels, >= 0 |
| `gridColumnGap` | `number` | `0` | Pixels, >= 0 |
| `gridRowSizes` | `Array<GridTrackSize>` | `[{type:'FLEX',value:1}]` | Top-to-bottom order |
| `gridColumnSizes` | `Array<GridTrackSize>` | `[{type:'FLEX',value:1}]` | Left-to-right order |

**`GridTrackSize` interface:**

```typescript
interface GridTrackSize {
  type: 'FIXED' | 'FLEX' | 'HUG'
  value?: number  // px for FIXED, fr-weight for FLEX, unused for HUG
}
```

- `FIXED` — static pixel size (CSS `100px`)
- `FLEX` — fractional unit (CSS `1fr`, `2fr`). Update 120 added non-1 values
- `HUG` — shrink to largest child (CSS `auto`). Added in Update 120

#### Container Methods

| Method | Signature | Notes |
|--------|-----------|-------|
| `appendChildAt` | `(node, rowIndex, columnIndex): void` | 0-based. Throws if out-of-bounds or cell occupied |

`appendChild(child)` (without `At`) places child at the first available cell.

#### Child Properties

| Property | Type | Access | Notes |
|----------|------|--------|-------|
| `gridRowAnchorIndex` | `number` | readonly | 0-based row start |
| `gridColumnAnchorIndex` | `number` | readonly | 0-based column start |
| `gridRowSpan` | `number` | read/write | Positive int. Throws on overlap/overflow |
| `gridColumnSpan` | `number` | read/write | Positive int. Throws on overlap/overflow |
| `gridChildHorizontalAlign` | `'MIN'\|'CENTER'\|'MAX'\|'AUTO'` | read/write | Self-alignment horizontal |
| `gridChildVerticalAlign` | `'MIN'\|'CENTER'\|'MAX'\|'AUTO'` | read/write | Self-alignment vertical |

#### Child Methods

| Method | Signature | Notes |
|--------|-----------|-------|
| `setGridChildPosition` | `(rowIndex, columnIndex): void` | 0-based. Throws if occupied or out-of-bounds |

#### Operation Order — Grid

```
1. Set layoutMode = 'GRID'
2. Set gridRowCount, gridColumnCount
3. Set gridRowSizes, gridColumnSizes (track sizing)
4. Set gridRowGap, gridColumnGap
5. Set padding (paddingTop/Bottom/Left/Right)
6. appendChildAt(child, row, col) for each child
7. Set child gridRowSpan / gridColumnSpan (after placement)
8. Set child gridChildHorizontalAlign / gridChildVerticalAlign
```

#### Grid Gotchas

- **UI defaults HUG, API defaults FIXED** — tracks created via API default to `{type:'FIXED',value:10}`, not HUG. Explicitly set track sizes after creation
- **FLEX tracks + HUG container = error** — a grid container with `layoutSizingHorizontal = 'HUG'` cannot have `FLEX` column tracks (contradiction: can't flex into indeterminate space)
- **One child per cell** — `appendChildAt` throws if the target cell is already occupied. Use `layoutPositioning = 'ABSOLUTE'` as an escape hatch for overlapping
- **No implicit auto-flow** — children are not auto-placed into the next available cell. Position must be explicit via `appendChildAt` or `setGridChildPosition`
- **Cannot reduce below occupied** — setting `gridRowCount` lower than the last occupied row throws. Remove or relocate children first
- **Padding/spacing** — `paddingTop/Bottom/Left/Right` work normally. `itemSpacing`/`counterAxisSpacing` are IGNORED on Grid containers — use `gridRowGap`/`gridColumnGap`
- **`layoutSizingHorizontal = 'FILL'`** — children should use `'FILL'` for responsive behavior within cells
- **Grid variable binding** — `gridRowGap` and `gridColumnGap` are bindable via `node.setBoundVariable('gridRowGap', variable)` (added as `VariableBindableNodeField`)

---