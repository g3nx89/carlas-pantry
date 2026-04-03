# Plugin API — Visuals (Text, Colors, Effects, Images, Cross-Page Operations)

> **Compatibility**: Verified against Figma Plugin API via figma-console-mcp v1.11.2 (February 2026)
>
> **Scope**: Text handling, colors and paint system, effects and decorations, image handling, cross-page operations. For operation order, node creation, and auto-layout, see `plugin-api-foundation.md`. For components, prototypes, variables, and performance, see `plugin-api-advanced.md`.

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
| `textAutoResize` | `'NONE'`\|`'WIDTH_AND_HEIGHT'`\|`'HEIGHT'`\|`'TRUNCATE'` | Use `'HEIGHT'` with `layoutSizingHorizontal='FILL'` in auto-layout; `'WIDTH_AND_HEIGHT'` for free-floating text only |
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

> **CRITICAL CONSTRAINT for Draft-to-Handoff workflows**: While `createImageAsync(url)` and `createImage(bytes)` exist, they are NOT usable for transferring existing designs between pages. When moving designs from a Draft page to a Handoff page, the ONLY way to preserve IMAGE fills is to **clone the source node** via `figma_clone_node` (or `figma_execute` with Plugin API `node.clone()`). Any approach that creates screens from scratch instead of cloning will lose all images, replacing them with black rectangles. See `anti-patterns.md` Hard Constraints and the `design-handoff` skill (product-definition plugin) for the full preparation workflow.

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

- **`figma_clone_node` does not support cross-page cloning** — use `figma_execute` with Plugin API `node.clone()` for cross-page operations
- **`page.findOne(n => n.name === X)`** may find the WRONG node if multiple nodes share a name — always prefer node IDs when possible
- **External library COMPONENT_SETs**: `getNodeByIdAsync` returns the node but `.parent` is `undefined` — they cannot be moved, only referenced via instances
- **Deleting a FRAME with COMPONENT/COMPONENT_SET children**: children may survive (reparented to page) or be deleted. Always verify critical components still exist after deleting container frames

---