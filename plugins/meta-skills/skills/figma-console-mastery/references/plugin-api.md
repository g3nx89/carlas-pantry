# Plugin API Reference — Writing figma_execute Code

> **Compatibility**: Verified against Figma Plugin API via Figma Console MCP v1.10.0 (February 2026)

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

## Text Handling

### Font Loading (Mandatory)

```javascript
// Single font
await figma.loadFontAsync({ family: "Inter", style: "Regular" })

// Multiple fonts (preferred)
await Promise.all([
  figma.loadFontAsync({ family: 'Inter', style: 'Regular' }),
  figma.loadFontAsync({ family: 'Inter', style: 'Bold' }),
])

// All fonts on existing mixed-font node
await Promise.all(
  node.getRangeAllFontNames(0, node.characters.length).map(figma.loadFontAsync)
)
```

**Requires** font: `characters`, `fontSize`, `fontName`, `textCase`, `textDecoration`, `letterSpacing`, `lineHeight`, `textAlignHorizontal/Vertical`, `textAutoResize`, all `setRange*()`. Does **NOT** require font: `fills`, `strokes`, `opacity`. Results are cached. Check `textNode.hasMissingFont` on user-created nodes.

### Text Properties Reference

| Property | Type / Values | Notes |
|----------|--------------|-------|
| `characters` | `string` | Requires font loaded |
| `fontSize` | `number \| figma.mixed` | Min 1 |
| `fontName` | `{ family, style }` | e.g. `{ family: 'Inter', style: 'Bold' }` |
| `textAlignHorizontal` | `'LEFT'`\|`'CENTER'`\|`'RIGHT'`\|`'JUSTIFIED'` | |
| `textAlignVertical` | `'TOP'`\|`'CENTER'`\|`'BOTTOM'` | |
| `textAutoResize` | `'NONE'`\|`'WIDTH_AND_HEIGHT'`\|`'HEIGHT'`\|`'TRUNCATE'` | |
| `lineHeight` | `{ unit: 'AUTO' }` or `{ value, unit: 'PIXELS'\|'PERCENT' }` | |
| `letterSpacing` | `{ value, unit: 'PIXELS'\|'PERCENT' }` | |
| `textDecoration` | `'NONE'`\|`'UNDERLINE'`\|`'STRIKETHROUGH'` | |
| `textTruncation` | `'DISABLED'`\|`'ENDING'` | Ellipsis |
| `maxLines` | `number\|null` | Only with `'ENDING'` |

### Mixed Styles via Range Functions

```javascript
textNode.setRangeFontSize(0, 5, 24)
textNode.setRangeFontName(0, 5, { family: 'Inter', style: 'Bold' })
textNode.setRangeFills(6, 12, [{ type: 'SOLID', color: { r: 1, g: 0, b: 0 } }])
textNode.setRangeTextDecoration(0, 5, 'UNDERLINE')
textNode.setRangeHyperlink(0, 5, { type: 'URL', value: 'https://example.com' })

// Batch read
textNode.getStyledTextSegments(['fontName', 'fontSize', 'fills'])
// Returns: Array<{ characters, start, end, fontName, fontSize, fills }>
```

**Gotcha:** When setting `fontName`, only the NEW font needs loading. For any OTHER property, ALL current fonts must be loaded.

---

## Colors and Paint System

Colors use `{ r, g, b }` in **0-1 range** (NOT 0-255).

```javascript
// Built-in utilities (recommended)
figma.util.rgb('#FF0000')           // { r: 1, g: 0, b: 0 }
figma.util.solidPaint('#FF00FF')    // complete SolidPaint object
figma.util.solidPaint('#FF00FF88')  // SolidPaint with opacity from alpha

// Manual hex conversion
function hexToFigma(hex) {
  hex = hex.replace('#', '')
  return {
    r: parseInt(hex.substring(0, 2), 16) / 255,
    g: parseInt(hex.substring(2, 4), 16) / 255,
    b: parseInt(hex.substring(4, 6), 16) / 255
  }
}
```

**Paint types:**
```javascript
// SolidPaint — NO alpha on color, use paint.opacity
node.fills = [{ type: 'SOLID', color: { r: 0.23, g: 0.51, b: 0.96 }, opacity: 0.8 }]

// GradientPaint — color stops use RGBA (has alpha)
node.fills = [{
  type: 'GRADIENT_LINEAR',
  gradientTransform: [[1, 0, 0], [0, 1, 0]],
  gradientStops: [
    { position: 0, color: { r: 1, g: 0, b: 0, a: 1 } },
    { position: 1, color: { r: 0, g: 0, b: 1, a: 1 } }
  ]
}]

// ImagePaint — see "Image Handling" section below for full details
const image = figma.createImage(uint8ArrayBytes)
node.fills = [{ type: 'IMAGE', scaleMode: 'FILL', imageHash: image.hash }]
```

### The Clone/Spread Pattern (CRITICAL)

**`fills`, `strokes`, and `effects` are READ-ONLY frozen arrays.** Never mutate directly.

```javascript
// WRONG — throws
node.fills[0].color.r = 0.5
node.fills.push(newPaint)

// CORRECT — clone, modify, reassign
const fills = JSON.parse(JSON.stringify(node.fills))
fills[0].color.r = 0.5
node.fills = fills

// CORRECT — spread or replace
node.fills = [...node.fills, newPaint]
node.fills = [{ type: 'SOLID', color: { r: 1, g: 0, b: 0 } }]
```

`node.opacity` affects entire node + children. `paint.opacity` affects one paint layer only.

### Async Paint Setters

For pattern fills/strokes (e.g., repeating image patterns), use the async setters instead of direct assignment:

```javascript
// Async setters — required for pattern fills/strokes
await node.setFillsAsync(fills)
await node.setStrokesAsync(strokes)
```

Direct assignment (`node.fills = [...]`) still works for `SOLID`, `GRADIENT_*`, and `IMAGE` paints. Use `setFillsAsync`/`setStrokesAsync` when working with pattern-based paints or when the paint type requires async resolution.

---

## Effects and Decorations

```javascript
// DropShadow
{ type: 'DROP_SHADOW', color: { r: 0, g: 0, b: 0, a: 0.25 },
  offset: { x: 0, y: 4 }, radius: 8, spread: 0, visible: true, blendMode: 'NORMAL' }

// InnerShadow
{ type: 'INNER_SHADOW', color: { r: 0, g: 0, b: 0, a: 0.15 },
  offset: { x: 0, y: 2 }, radius: 4, visible: true, blendMode: 'NORMAL' }

// Blur
{ type: 'LAYER_BLUR', radius: 10, visible: true }
{ type: 'BACKGROUND_BLUR', radius: 20, visible: true }  // frosted glass
```

**Corner radius:**
```javascript
node.cornerRadius = 8                   // Uniform
node.topLeftRadius = 8                  // Per-corner
node.topRightRadius = 8
node.bottomLeftRadius = 0
node.bottomRightRadius = 0
node.cornerSmoothing = 0.6             // iOS-style (0-1)
```

**Strokes:**
```javascript
node.strokes = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
node.strokeWeight = 1
node.strokeAlign = 'INSIDE'  // 'CENTER' | 'INSIDE' | 'OUTSIDE'
node.strokeTopWeight = 0; node.strokeBottomWeight = 1  // Per-side (Frame/Rect only)
node.dashPattern = [10, 5]  // [dash, gap]
```

---

## Image Handling

Images in Figma are a paint type (`ImagePaint`), not a standalone node. Apply them as fills on shapes or frames.

> **CRITICAL CONSTRAINT for Draft-to-Handoff workflows**: While `createImageAsync(url)` and `createImage(bytes)` exist, they are NOT usable for transferring existing designs between pages. When moving designs from a Draft page to a Handoff page, the ONLY way to preserve IMAGE fills is to **clone the source node** via `figma_node_clone`. Any approach that creates screens from scratch instead of cloning will lose all images, replacing them with black rectangles. See `anti-patterns.md` Hard Constraints and the `design-handoff` skill (product-definition plugin) for the full preparation workflow.

### From URL (async)

```javascript
const rect = figma.createRectangle()
rect.name = "Hero Image"
rect.resize(375, 200)

const image = await figma.createImageAsync('https://example.com/photo.jpg')
rect.fills = [{
  type: 'IMAGE',
  scaleMode: 'FILL',  // 'FILL' | 'FIT' | 'CROP' | 'TILE'
  imageHash: image.hash
}]
```

### From bytes (Uint8Array)

```javascript
const image = figma.createImage(uint8ArrayBytes)
rect.fills = [{
  type: 'IMAGE',
  scaleMode: 'FIT',
  imageHash: image.hash
}]
```

### Scale Modes

| Mode | Behavior |
|------|----------|
| `'FILL'` | Cover entire shape, cropping excess |
| `'FIT'` | Fit within shape, may leave empty space |
| `'CROP'` | User-defined crop region |
| `'TILE'` | Repeat pattern |

**Gotcha:** `createImageAsync(url)` requires network access from the plugin context. In Console MCP's Desktop Bridge environment, this works if the URL is publicly accessible. For private images, convert to `Uint8Array` externally and use `createImage(bytes)`.

---

## Cross-Page Operations

Cross-page operations are essential for Draft-to-Handoff workflows. The Plugin API supports cloning nodes between pages within the same file.

### Cross-Page Clone (Primary Pattern)

The **only** reliable way to transfer designs between pages while preserving image fills, fonts, exact positioning, and layer ordering:

```javascript
(async () => {
  try {
    await figma.loadAllPagesAsync();

    const draftPage = figma.root.children.find(p => p.name === "Draft");
    const handoffPage = figma.root.children.find(p => p.name === "Handoff");

    const sourceNode = await figma.getNodeByIdAsync("24:2905");
    if (!sourceNode) return;

    const clone = sourceNode.clone();
    handoffPage.appendChild(clone);
    clone.x = 80;
    clone.y = 80;
    clone.name = "WK-01 — Episode Preview";

    console.log(JSON.stringify({ success: true, cloneId: clone.id }));
  } catch(e) {
    console.log(JSON.stringify({ error: e.message }));
  }
})()
```

**Key rules:**
- **`figma.loadAllPagesAsync()`** — required before accessing nodes on non-current pages in dynamic-page mode
- **`figma.getNodeByIdAsync()`** — MUST use async version; sync `getNodeById()` throws `"Cannot call with documentAccess: dynamic-page"`
- **`sourceNode.clone()`** — creates a deep copy preserving ALL visual properties including IMAGE fills, fonts, effects, and nested children
- **`handoffPage.appendChild(clone)`** — moves the clone from its default parent (same page as source) to the target page
- **Coordinates after reparenting** — `clone.x` / `clone.y` are relative to the new parent after `appendChild`

### Why Clone Instead of Rebuild

| Approach | Image fills | Fonts | Layer order | Visual fidelity |
|----------|------------|-------|-------------|-----------------|
| Clone (`node.clone()`) | Preserved | Preserved | Preserved | Pixel-perfect |
| Rebuild from spec/text | Lost (black rectangles) | Approximated | Manual | Divergent |
| `figma_render` JSX | Not supported | Limited | Correct | Partial |

**NEVER reconstruct screens from text documents (PRDs, reconstruction guides, design specs).** Text cannot capture image fills, exact font weights, layer ordering, or visual properties. Always clone from the source design.

### Cross-Page Node Access Patterns

```javascript
// Pattern 1: Sync page list + async node lookup (preferred)
const draftPage = figma.root.children.find(p => p.name === "Draft");  // sync — works
const node = await figma.getNodeByIdAsync("24:2905");  // async — required

// Pattern 2: Sync page access + sync findOne (works without loadAllPagesAsync in some cases)
const draftPage = figma.root.children.find(p => p.name === "Draft");
const node = draftPage.findOne(n => n.id === "24:2905");  // sync — may work if page loaded

// WRONG: sync getNodeById in dynamic-page mode
const node = figma.getNodeById("24:2905");  // THROWS: "Cannot call with documentAccess: dynamic-page"
```

### Section Reparenting

SECTION nodes accept children via `appendChild`. After reparenting, child coordinates become section-relative:

```javascript
const section = figma.createSection();
section.name = "🧩 Components";
section.resizeWithoutConstraints(1400, 900);
section.x = 0;
section.y = 1000;
handoffPage.appendChild(section);

// Move component into section
const comp = handoffPage.children.find(n => n.name === "MyComponent");
const prevX = comp.x, prevY = comp.y;
section.appendChild(comp);
comp.x = prevX - section.x;  // convert to section-relative
comp.y = prevY - section.y;
```

### Gotchas

- **`figma_node_clone` (figma-use MCP) is broken for cross-page operations** — use `figma_execute` with Plugin API `node.clone()` instead
- **`page.findOne(n => n.name === X)`** may find the WRONG node if multiple nodes share a name — always prefer node IDs when possible
- **External library COMPONENT_SETs**: `getNodeByIdAsync` returns the node but `.parent` is `undefined` — they cannot be moved, only referenced via instances
- **Deleting a FRAME with COMPONENT/COMPONENT_SET children**: children may survive (reparented to page) or be deleted. Always verify critical components still exist after deleting container frames

---

## Components and Instances

```javascript
// Creating a component
const comp = figma.createComponent()
comp.name = "Button"
comp.resize(200, 48)
comp.layoutMode = 'HORIZONTAL'
comp.primaryAxisAlignItems = 'CENTER'
comp.counterAxisAlignItems = 'CENTER'
comp.paddingLeft = 24; comp.paddingRight = 24
comp.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.5, b: 1 } }]
```

**Creating variants** — there is **no `figma.createComponentSet()`**:
```javascript
const defaultState = figma.createComponent()
defaultState.name = "Size=Medium, State=Default"  // Property=Value naming
const hoverState = figma.createComponent()
hoverState.name = "Size=Medium, State=Hover"

const componentSet = figma.combineAsVariants([defaultState, hoverState], figma.currentPage)
componentSet.name = "Button"
```

**Component properties:**
```javascript
comp.addComponentProperty('ShowIcon', 'BOOLEAN', true)
comp.addComponentProperty('Label', 'TEXT', 'Submit')
comp.addComponentProperty('Icon', 'INSTANCE_SWAP', defaultIconId)

comp.children[0].componentPropertyReferences = { 'visible': 'ShowIcon#0:0' }
comp.children[1].componentPropertyReferences = { 'characters': 'Label#0:1' }
```

**Instantiating and overriding:**
```javascript
const instance = comp.createInstance()
instance.setProperties({
  'Size': 'Large',          // variant property (no suffix)
  'Label#0:1': 'Login',     // text property (with suffix)
  'ShowIcon#0:0': false      // boolean property (with suffix)
})
instance.swapComponent(otherComponent)     // preserves overrides
const frame = instance.detachInstance()     // returns FrameNode
```

### Component Gotchas

- **`componentPropertyDefinitions`** is only accessible on COMPONENT_SET nodes, NOT on individual variant COMPONENTs within the set
- **`instance.swapComponent(node)`** requires a COMPONENT node, NOT a COMPONENT_SET. If the target is a COMPONENT_SET, get a specific child variant first: `const variant = componentSet.children[0]; instance.swapComponent(variant);`
- **`node.mainComponent`** — in dynamic-page mode, use `await node.getMainComponentAsync()` instead (sync version throws)

---

## Prototype Reactions and Navigation

Prototype connections are managed via the `reactions` property, available on nodes that implement `ReactionMixin`: FRAME, COMPONENT, INSTANCE, TEXT, RECTANGLE, ELLIPSE, VECTOR, POLYGON, STAR, LINE, and most shape nodes. GROUP nodes also expose `reactions` but **silently drop** them on write.

### Setting Reactions (Async Required)

```javascript
await node.setReactionsAsync([
  {
    trigger: { type: 'ON_CLICK' },
    actions: [{
      type: 'NODE',
      destinationId: '24:3025',
      navigation: 'NAVIGATE',
      transition: {
        type: 'SMART_ANIMATE',
        duration: 0.3,
        easing: { type: 'EASE_IN_AND_OUT' }
      },
      resetScrollPosition: true,
      resetInteractiveComponents: false
    }]
  }
]);
```

### Reaction Format

**`actions` array (plural) is required.** The singular `action` field is **deprecated**.

```javascript
// CORRECT — actions array (supports multi-action per trigger)
{ trigger: { type: 'ON_CLICK' }, actions: [{ type: 'NODE', ... }, { type: 'SET_VARIABLE', ... }] }

// WRONG — action singular (deprecated, will fail)
{ trigger: { type: 'ON_CLICK' }, action: { type: 'NODE', ... } }
```

### Trigger Types

| Trigger | Properties | Notes |
|---------|-----------|-------|
| `ON_CLICK` | — | Standard click/tap |
| `ON_HOVER` | — | **Reverts** on hover-out |
| `ON_PRESS` | — | **Reverts** on release |
| `ON_DRAG` | — | Drag/swipe gesture |
| `AFTER_TIMEOUT` | `timeout: number` (ms) | Auto-fire after delay |
| `MOUSE_ENTER` | `delay: number` (ms) | One-way (no revert) |
| `MOUSE_LEAVE` | `delay: number` (ms) | One-way (no revert) |
| `MOUSE_UP` | `delay: number` (ms) | One-way |
| `MOUSE_DOWN` | `delay: number` (ms) | One-way |
| `ON_KEY_DOWN` | `device`, `keyCodes: number[]` | Hardware input. `device`: `'KEYBOARD'\|'XBOX_ONE'\|'PS4'\|'SWITCH_PRO'\|'UNKNOWN_CONTROLLER'` |
| `ON_MEDIA_HIT` | `mediaHitTime: number` (seconds) | Video layers only |
| `ON_MEDIA_END` | — | Video layers only |

### Action Types

| Action | Key Properties | Notes |
|--------|---------------|-------|
| `NODE` | `destinationId`, `navigation`, `transition`, `resetScrollPosition`, `resetVideoPosition`, `resetInteractiveComponents` | All navigation flows |
| `BACK` | — | Go back in prototype history |
| `CLOSE` | — | Dismiss topmost overlay |
| `URL` | `url: string` | Open external link |
| `SET_VARIABLE` | `variableId`, `variableValue: VariableData` | Set variable value in prototype |
| `SET_VARIABLE_MODE` | `variableCollectionId`, `variableModeId` | Switch collection mode |
| `CONDITIONAL` | `conditionalBlocks: ConditionalBlock[]` | IF/ELSE branching logic |
| `UPDATE_MEDIA_RUNTIME` | `destinationId?`, `mediaAction` | Video control (`PLAY`, `PAUSE`, `TOGGLE_PLAY_PAUSE`, `MUTE`, `UNMUTE`, `TOGGLE_MUTE_UNMUTE`) |

### Navigation Types (on NODE action)

| Navigation | Behavior |
|-----------|----------|
| `NAVIGATE` | Replace current screen, closes overlays |
| `OVERLAY` | Open destination as overlay layer |
| `SWAP` | Replace current overlay (or navigate without history entry) |
| `SCROLL_TO` | Scroll within current frame to target node |
| `CHANGE_TO` | Switch nearest ancestor instance to destination variant (interactive components) |

### Transitions and Easing

| Category | Transition Types |
|----------|-----------------|
| Simple | `DISSOLVE`, `SMART_ANIMATE`, `SCROLL_ANIMATE` |
| Directional | `MOVE_IN`, `MOVE_OUT`, `PUSH`, `SLIDE_IN`, `SLIDE_OUT` (+ `direction`: `'LEFT'\|'RIGHT'\|'TOP'\|'BOTTOM'`) |
| Instant | `transition: null` |

Transition properties: `duration` (seconds), `easing` (object).

**Easing types:**

| Category | Values |
|----------|--------|
| Preset bezier | `LINEAR`, `EASE_IN`, `EASE_OUT`, `EASE_IN_AND_OUT`, `EASE_IN_BACK`, `EASE_OUT_BACK`, `EASE_IN_AND_OUT_BACK` |
| Spring presets | `GENTLE`, `QUICK`, `BOUNCY`, `SLOW` |
| Custom bezier | `CUSTOM_CUBIC_BEZIER` — requires `easingFunctionCubicBezier: { x1, y1, x2, y2 }` |
| Custom spring | `CUSTOM_SPRING` — requires `easingFunctionSpring: { mass, stiffness, damping, initialVelocity }` |

### Overlay Properties

Set on the **destination FrameNode** (readonly in Plugin API — set via Figma UI):

| Property | Values |
|----------|--------|
| `overlayPositionType` | `CENTER`, `TOP_LEFT`, `TOP_CENTER`, `TOP_RIGHT`, `BOTTOM_LEFT`, `BOTTOM_CENTER`, `BOTTOM_RIGHT`, `MANUAL` |
| `overlayBackground` | `{ type: 'NONE' }` or `{ type: 'SOLID_COLOR', color: RGBA }` |
| `overlayBackgroundInteraction` | `NONE`, `CLOSE_ON_CLICK_OUTSIDE` |

For `MANUAL` positioning, the NODE action includes `overlayRelativePosition: { x, y }`.

### Conditional Prototyping (SET_VARIABLE + CONDITIONAL)

```javascript
// Multi-action: set a variable AND navigate conditionally
await node.setReactionsAsync([{
  trigger: { type: 'ON_CLICK' },
  actions: [
    // Action 1: Set a variable
    {
      type: 'SET_VARIABLE',
      variableId: isLoggedIn.id,
      variableValue: { type: 'BOOLEAN', resolvedType: 'BOOLEAN', value: true }
    },
    // Action 2: Conditional navigation
    {
      type: 'CONDITIONAL',
      conditionalBlocks: [{
        condition: { type: 'EXPRESSION', resolvedType: 'BOOLEAN',
          value: { expressionFunction: 'EQUALS',
            expressionArguments: [
              { type: 'VARIABLE_ALIAS', resolvedType: 'BOOLEAN',
                value: { type: 'VARIABLE_ALIAS', id: isLoggedIn.id } },
              { type: 'BOOLEAN', resolvedType: 'BOOLEAN', value: true }
            ]
          }
        },
        actions: [{ type: 'NODE', destinationId: dashboardId, navigation: 'NAVIGATE',
          transition: { type: 'SMART_ANIMATE', duration: 0.3, easing: { type: 'EASE_OUT' } } }]
      }, {
        // ELSE block (no condition)
        actions: [{ type: 'NODE', destinationId: signupId, navigation: 'OVERLAY',
          transition: { type: 'DISSOLVE', duration: 0.2, easing: { type: 'EASE_OUT' } } }]
      }]
    }
  ]
}]);
```

> **Caveat**: The exact `VariableData` nesting structure for CONDITIONAL actions is synthesized from multiple research sources. Verify against `@figma/plugin-typings` (`Reaction`, `Action`, `ConditionalBlock` types) before production use — field names or nesting depth may differ.

**Expression functions** for conditions: `EQUALS`, `NOT_EQUAL`, `LESS_THAN`, `LESS_THAN_OR_EQUAL`, `GREATER_THAN`, `GREATER_THAN_OR_EQUAL`, `AND`, `OR`, `NOT`, `NEGATE`, `ADDITION`, `SUBTRACTION`, `MULTIPLICATION`, `DIVISION`, `VAR_MODE_LOOKUP`.

### Node Type Support

| Node Type | Supports reactions? | Notes |
|-----------|-------------------|-------|
| FRAME | Yes | Primary target |
| COMPONENT | Yes | Works on component masters |
| INSTANCE | Yes | Works on instances |
| TEXT | Yes | Via `ReactionMixin` |
| RECTANGLE, ELLIPSE, VECTOR, POLYGON, STAR, LINE | Yes | Via `ReactionMixin` |
| GROUP | **Silently drops** | `reactions` property exists but `setReactionsAsync` silently discards. Verify after write |

**Always verify after wiring:**
```javascript
await node.setReactionsAsync(reactions);
const actual = node.reactions;
if (actual.length === 0 && reactions.length > 0) {
  console.log(JSON.stringify({ warning: "Reactions dropped", nodeType: node.type, nodeId: node.id }));
}
```

---

## Variables — Programmatic Binding

```javascript
// Create collection and variables
const collection = figma.variables.createVariableCollection("design-tokens")
collection.renameMode(collection.modes[0].modeId, "light")
const darkModeId = collection.addMode("dark")

const primaryColor = figma.variables.createVariable("primary", collection, "COLOR")
primaryColor.setValueForMode(collection.modes[0].modeId, { r: 0.2, g: 0.4, b: 1 })
primaryColor.setValueForMode(darkModeId, { r: 0.4, g: 0.6, b: 1 })
// Types: 'BOOLEAN' | 'FLOAT' | 'STRING' | 'COLOR'

// Bind to node properties
node.setBoundVariable('paddingTop', spacingVariable)
node.setBoundVariable('itemSpacing', spacingVariable)

// Bind COLOR to fills (requires helper)
const boundPaint = figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', colorVariable
)
node.fills = [boundPaint]

// Set explicit mode
frame.setExplicitVariableModeForCollection(collection, darkModeId)

// Scoping
// Variable scoping — controls where the variable appears in Figma's UI
colorVar.scopes = ['ALL_FILLS']
// Available scopes: 'ALL_SCOPES', 'TEXT_CONTENT', 'CORNER_RADIUS', 'WIDTH_HEIGHT',
// 'GAP', 'ALL_FILLS', 'FRAME_FILL', 'SHAPE_FILL', 'TEXT_FILL', 'STROKE_COLOR',
// 'STROKE_FLOAT', 'EFFECT_FLOAT', 'EFFECT_COLOR', 'OPACITY', 'FONT_FAMILY',
// 'FONT_STYLE', 'FONT_WEIGHT', 'FONT_SIZE', 'LINE_HEIGHT', 'LETTER_SPACING',
// 'PARAGRAPH_SPACING', 'PARAGRAPH_INDENT'

// Resolve value for a specific consumer node (respects mode inheritance)
const resolved = variable.resolveForConsumer(node)
// { value: { r: 0.4, g: 0.6, b: 1 }, resolvedType: 'COLOR' }

// Retrieve existing
const collections = await figma.variables.getLocalVariableCollectionsAsync()
const colorVars = await figma.variables.getLocalVariablesAsync('COLOR')
const variable = await figma.variables.getVariableByIdAsync(id)
```

### Variable Aliases

Aliases create semantic tokens that reference other variables (similar to CSS custom property chains):

```javascript
// Create a primitive token
const blue500 = figma.variables.createVariable("blue-500", collection, "COLOR")
blue500.setValueForMode(lightModeId, figma.util.rgb('#3B82F6'))

// Create a semantic alias pointing to the primitive
const primaryColor = figma.variables.createVariable("primary", collection, "COLOR")
primaryColor.setValueForMode(lightModeId, figma.variables.createVariableAlias(blue500))
primaryColor.setValueForMode(darkModeId, figma.variables.createVariableAlias(blue300))

// Async version (when you only have the variable ID)
const alias = await figma.variables.createVariableAliasByIdAsync(variableId)
```

**Resolving aliases** — `resolveForConsumer` follows the alias chain:
```javascript
const resolved = primaryColor.resolveForConsumer(someNode)
// { value: { r: 0.23, g: 0.51, b: 0.96 }, resolvedType: 'COLOR' }
```

### Code Syntax

Map variable names to platform-specific code tokens:

```javascript
variable.codeSyntax  // readonly: { WEB?: string, ANDROID?: string, iOS?: string }
variable.setVariableCodeSyntax("WEB", "--color-primary")
variable.setVariableCodeSyntax("ANDROID", "colorPrimary")
variable.setVariableCodeSyntax("iOS", "ColorPrimary")
variable.removeVariableCodeSyntax("ANDROID")  // remove single platform
```

### Complete Binding Targets

**Node-level** (`node.setBoundVariable(field, variable)`):

`height`, `width`, `visible`, `opacity`, `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius`, `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft`, `itemSpacing`, `counterAxisSpacing`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `strokeWeight`, `strokeTopWeight`, `strokeRightWeight`, `strokeBottomWeight`, `strokeLeftWeight`, `gridRowGap`, `gridColumnGap`, `characters`

**Text-level** (`textNode.setBoundVariable(field, variable)` or `textNode.setRangeBoundVariable(start, end, field, variable)`):

`fontFamily`, `fontSize`, `fontStyle`, `fontWeight`, `letterSpacing`, `lineHeight`, `paragraphSpacing`, `paragraphIndent`

**Effect-level** (`figma.variables.setBoundVariableForEffect(effect, field, variable)`):

`radius`, `color`, `spread`, `offsetX`, `offsetY` (shadow); `radius` (blur). Returns modified Effect — reassign to node.

**LayoutGrid-level** (`figma.variables.setBoundVariableForLayoutGrid(grid, field, variable)`):

`sectionSize`, `count`, `offset`, `gutterSize`. Returns modified LayoutGrid — reassign to node.

```javascript
// Effect variable binding example
const shadow = node.effects[0]
const boundShadow = figma.variables.setBoundVariableForEffect(shadow, 'radius', blurVar)
node.effects = [boundShadow]

// LayoutGrid variable binding example
const grid = node.layoutGrids[0]
const boundGrid = figma.variables.setBoundVariableForLayoutGrid(grid, 'gutterSize', spacingVar)
node.layoutGrids = [boundGrid]
```

### Import from Library

```javascript
// Import a published library variable by key
const importedVar = await figma.variables.importVariableByKeyAsync("abc123def456")
// Bind to fills via paint helper (setBoundVariable does not work for fills directly)
const boundPaint = figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', importedVar
)
node.fills = [boundPaint]
```

### Plan-Based Limits

| Plan | Modes per Collection | Extended Collections |
|------|---------------------|---------------------|
| Starter | 1 | No |
| Professional | 10 | No |
| Organization | 20 | No |
| Enterprise | 40 | Yes (`extendLibraryCollectionByKeyAsync`) |

Variables per collection: 5,000 (all plans).

---

## Coordinates, Sizing, and Styles

| Concept | Details |
|---------|---------|
| `x`, `y` | Relative to **parent**. Ignored on auto-layout children unless `ABSOLUTE` |
| `width`, `height` | **READ-ONLY**. Use `resize()` or `resizeWithoutConstraints()` |
| `absoluteBoundingBox` | `{ x, y, width, height }` on page (read-only) |
| `constraints` | Non-auto-layout children: `{ horizontal: 'MIN'\|'CENTER'\|'MAX'\|'STRETCH'\|'SCALE', vertical: same }` |

**Creating and applying styles:**
```javascript
// Paint style
const style = figma.createPaintStyle()
style.name = "Colors/Brand/Primary"  // slash = folder nesting
style.paints = [{ type: 'SOLID', color: { r: 0.2, g: 0.5, b: 1 } }]
await node.setFillStyleIdAsync(style.id)

// Text style
const headingStyle = figma.createTextStyle()
headingStyle.name = "Typography/Heading/H1"
headingStyle.fontName = { family: 'Inter', style: 'Bold' }
headingStyle.fontSize = 32
headingStyle.lineHeight = { value: 40, unit: 'PIXELS' }
await textNode.setTextStyleIdAsync(headingStyle.id)

// Effect style
const shadow = figma.createEffectStyle()
shadow.name = "Effects/Shadow/Card"
shadow.effects = [{ type: 'DROP_SHADOW', color: { r: 0, g: 0, b: 0, a: 0.15 },
  offset: { x: 0, y: 4 }, radius: 8, visible: true, blendMode: 'NORMAL' }]
await frame.setEffectStyleIdAsync(shadow.id)
```

**Gotcha — `style.remove()`:** After calling `style.remove()`, do NOT access any properties on the removed style object. Cache `name` and `id` before deletion:

```javascript
// CORRECT — cache before remove
const styleName = style.name;
const styleId = style.id;
style.remove();
console.log(`Removed style: ${styleName} (${styleId})`);

// WRONG — accessing after remove throws
style.remove();
console.log(style.name);  // throws: node has been removed
```

---

## figma_execute Return Value Behavior

Understanding how `figma_execute` handles return values is critical for reliable data retrieval.

### Sync Return (Works)

Top-level synchronous `return` statements are captured in the `result` field of the response:

```javascript
// This return value IS captured in response.result
const hp = figma.root.children.find(p => p.name === "Handoff");
const nodes = hp.children.map(n => ({ id: n.id, name: n.name, type: n.type }));
return JSON.stringify({ count: hp.children.length, nodes });
// Response: { "success": true, "result": "{\"count\":2,...}", "timestamp": ... }
```

**Use for:** Data retrieval, node queries, status checks — anything that doesn't require `await`.

### Async IIFE Return (Does NOT Work)

The return value of an `async` IIFE is a Promise. The Desktop Bridge does NOT await Promises, so it sees `undefined`:

```javascript
// This return value is LOST — bridge logs "Code returned undefined"
(async () => {
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  const frame = figma.createFrame();
  return JSON.stringify({ id: frame.id });  // ← Promise, NOT captured
})()
// Response: { "success": true, "timestamp": ... }  ← no "result" field
```

**Use async IIFE for:** Operations requiring `await` (font loading, `getNodeByIdAsync`, `setReactionsAsync`).

### Recommended Pattern: Split Calls

For operations that need both `await` and data retrieval, use two separate `figma_execute` calls:

```javascript
// Call 1 (async IIFE): Perform mutation
(async () => {
  try {
    await figma.loadFontAsync({ family: "DM Sans", style: "Regular" });
    const frame = figma.createFrame();
    frame.name = "MyScreen";
    // ... complex async operations
    console.log(JSON.stringify({ success: true }));
  } catch(e) {
    console.log(JSON.stringify({ error: e.message }));
  }
})()

// Call 2 (sync): Retrieve results
const hp = figma.root.children.find(p => p.name === "Handoff");
const nodes = hp.children.map(n => ({ id: n.id, name: n.name }));
return JSON.stringify({ nodes });
```

### console.log Reliability

`console.log()` inside `figma_execute` writes to the Figma console buffer, retrievable via `figma_get_console_logs`. However:

- **Buffer holds ~100 entries** — call `figma_clear_console` before batch operations
- **Buffer may stop updating** after context compaction or bridge reconnect — `figma_get_console_logs` may not show new entries
- **Prefer sync return** over `console.log` for data retrieval whenever possible

---

## State Tracking Across Calls

Each `figma_execute` call is stateless. Return serializable data (never raw node objects) and use IDs for cross-call references:

```javascript
// Call 1: Create and return IDs
return { frameId: frame.id, children: frame.children.map(c => ({ id: c.id, name: c.name })) }

// Call 2: Reference by ID (O(1) lookup — fastest)
const frame = await figma.getNodeByIdAsync("1:23")

// Find by unique name (fallback)
const hero = figma.currentPage.findOne(n => n.name === "hero-section")

// Optimized search for large documents
figma.skipInvisibleInstanceChildren = true
const frames = figma.currentPage.findAllWithCriteria({ types: ['FRAME'] })
```

---

## Performance Optimization

### Search Performance

```javascript
// CRITICAL: Set before any search operations on large documents
figma.skipInvisibleInstanceChildren = true

// Prefer type-filtered search (hundreds of times faster than findAll)
const frames = figma.currentPage.findAllWithCriteria({ types: ['FRAME'] })
const texts = figma.currentPage.findAllWithCriteria({ types: ['TEXT'] })

// AVOID: Unfiltered search scans every node including invisible instance children
// const allNodes = figma.currentPage.findAll()  // slow on large documents
```

### Batch Viewport Updates

```javascript
// CORRECT: Collect all created nodes, update viewport once
const createdNodes = []
for (const item of items) {
  const node = figma.createFrame()
  // ... configure node
  createdNodes.push(node)
}
figma.viewport.scrollAndZoomIntoView(createdNodes)  // single call at end

// AVOID: Calling scrollAndZoomIntoView per node in a loop
```

### Dynamic Page Loading

In dynamic-page mode (default for Console MCP), pages other than `currentPage` are lazily loaded. Many sync APIs throw or return stale data.

```javascript
// Load all pages upfront (preferred for cross-page workflows)
await figma.loadAllPagesAsync();

// Or load a specific page
const otherPage = figma.root.children.find(p => p.name === "Components")
if (otherPage) {
  await otherPage.loadAsync()  // load children before accessing
  const components = otherPage.findAllWithCriteria({ types: ['COMPONENT'] })
}
```

**Sync vs Async API in dynamic-page mode:**

| Operation | Sync (throws) | Async (use this) |
|-----------|--------------|-------------------|
| Get node by ID | `figma.getNodeById("1:23")` | `await figma.getNodeByIdAsync("1:23")` |
| Get main component | `instance.mainComponent` | `await instance.getMainComponentAsync()` |
| Set reactions | `node.reactions = [...]` | `await node.setReactionsAsync([...])` |
| Get local styles | `figma.getLocalTextStyles()` | `await figma.getLocalTextStylesAsync()` |
| Get local variables | — | `await figma.variables.getLocalVariablesAsync()` |

**Safe sync operations** (work without loading):
- `figma.root.children` — page list is always available
- `figma.root.children.find(p => p.name === "X")` — page metadata is available
- `page.findOne(n => n.id === "X")` — works if the page is loaded or is currentPage
- `node.clone()` — works on any accessible node

### Font Check Before Loading

```javascript
// Check for missing fonts on user-created text nodes before loading
if (textNode.hasMissingFont) {
  // Font file is not installed — loadFontAsync will fail
  // Handle gracefully: skip modification or notify user
} else {
  // Safe to load and modify
  await Promise.all(
    textNode.getRangeAllFontNames(0, textNode.characters.length).map(figma.loadFontAsync)
  )
}
```

> For complete working code recipes (cards, buttons, inputs, M3 components, composition patterns), see `recipes-components.md`, `recipes-advanced.md`, and `recipes-m3.md`. For common mistakes and fixes, see `anti-patterns.md`.
