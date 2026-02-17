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
| SVG Import | `figma.createNodeFromSvg(svgString)` | Returns FrameNode |

`parent.appendChild(child)` works on Frame, Component, ComponentSet, Group, Instance, Page, Section, BooleanOperation nodes. `insertChild(index, child)` places at a specific z-index.

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
| `layoutMode` | `'NONE'`\|`'HORIZONTAL'`\|`'VERTICAL'` | `'NONE'` | **Set FIRST** |
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

```javascript
// Pages other than currentPage may not have children loaded
const otherPage = figma.root.children.find(p => p.name === "Components")
if (otherPage) {
  await otherPage.loadAsync()  // load children before accessing
  const components = otherPage.findAllWithCriteria({ types: ['COMPONENT'] })
}
```

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
