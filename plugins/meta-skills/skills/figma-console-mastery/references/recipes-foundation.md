# Recipes — Foundation Patterns & Layouts

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> For Plugin API details, see `plugin-api.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.
> For component recipes (cards, buttons, forms, tables, etc.), see `recipes-components.md`. For composition and advanced patterns, see `recipes-advanced.md`.

## Recipe Index

| Section | Recipe | Line |
|---------|--------|-----:|
| **Foundation** | Error-Handled IIFE Wrapper | 25 |
| | Multi-Font Preloading | 51 |
| | Node Reference Across Calls | 75 |
| | Returning Structured Data | 92 |
| **Layouts** | Page Container (Full-Width Vertical Stack) | 110 |
| | Horizontal Row with Fill Children | 147 |
| | Wrap Layout (Tag Cloud / Chip Group) | 202 |
| | Absolute Positioned Badge on Card | 266 |
| | CSS Grid Card Layout | 300 |

---

## Foundation Patterns

### Pattern: Error-Handled IIFE Wrapper

Every `figma_execute` call MUST use this async IIFE wrapper. Omitting it causes failures on any code that uses `await`.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Regular" })
    const frame = figma.createFrame()
    frame.name = "my-frame"
    frame.layoutMode = "VERTICAL"
    frame.resize(375, 1)
    figma.currentPage.appendChild(frame)
    figma.currentPage.selection = [frame]
    figma.viewport.scrollAndZoomIntoView([frame])
    return JSON.stringify({ success: true, id: frame.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "1:23" }` or `{ success: false, error: "..." }`

### Pattern: Multi-Font Preloading

Load all required fonts in a single `Promise.all` before creating any text nodes. Attempting to set `characters` on a text node with an unloaded font produces the most common `figma_execute` error.

**Code**:

```javascript
await Promise.all([
  figma.loadFontAsync({ family: 'Inter', style: 'Regular' }),
  figma.loadFontAsync({ family: 'Inter', style: 'Medium' }),
  figma.loadFontAsync({ family: 'Inter', style: 'Bold' }),
])
```

For M3 designs using Roboto:

```javascript
await Promise.all([
  figma.loadFontAsync({ family: 'Roboto', style: 'Regular' }),
  figma.loadFontAsync({ family: 'Roboto', style: 'Medium' }),
  figma.loadFontAsync({ family: 'Roboto', style: 'Bold' }),
])
```

### Pattern: Node Reference Across Calls

Call 1 creates a node and returns its ID. Call 2 retrieves it via async lookup.

**Call 1 returns**:

```javascript
return { id: frame.id, name: frame.name }
```

**Call 2 retrieves**:

```javascript
const frame = await figma.getNodeByIdAsync("1:23")
if (!frame) return JSON.stringify({ success: false, error: "Node not found" })
```

### Pattern: Returning Structured Data

Always return serializable JSON. Node objects cannot be serialized directly.

**Code**:

```javascript
return {
  frameId: frame.id,
  children: frame.children.map(c => ({ id: c.id, name: c.name, type: c.type })),
  dimensions: { width: frame.width, height: frame.height }
}
```

---

## Layout Recipes

### Recipe: Page Container (Full-Width Vertical Stack)

**Goal**: Create a mobile-width page frame that stacks children vertically and hugs content height.

**Code**:

```javascript
(async () => {
  try {
    const page = figma.createFrame()
    page.name = "Page"
    page.layoutMode = "VERTICAL"
    page.primaryAxisSizingMode = "AUTO"
    page.counterAxisSizingMode = "FIXED"
    page.resize(375, 1)
    page.paddingTop = 0
    page.paddingBottom = 0
    page.paddingLeft = 0
    page.paddingRight = 0
    page.itemSpacing = 0
    page.clipsContent = true
    page.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    figma.currentPage.appendChild(page)
    figma.currentPage.selection = [page]
    figma.viewport.scrollAndZoomIntoView([page])
    return JSON.stringify({ success: true, id: page.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }` -- use this ID as the parent for all subsequent section recipes.

**Next**: Append header, content, and footer sections as children of this container.

### Recipe: Horizontal Row with Fill Children

**Goal**: Create a row where the center child expands to fill remaining horizontal space (left-center-right layout).

**Code**:

```javascript
(async () => {
  try {
    const row = figma.createFrame()
    row.name = "Row"
    row.layoutMode = "HORIZONTAL"
    row.layoutSizingHorizontal = "FIXED"
    row.layoutSizingVertical = "HUG"
    row.resize(375, 1)
    row.itemSpacing = 16
    row.paddingLeft = 16
    row.paddingRight = 16
    row.paddingTop = 12
    row.paddingBottom = 12
    row.fills = []

    const left = figma.createFrame()
    left.name = "Left"
    left.resize(40, 40)
    left.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    row.appendChild(left)
    left.layoutSizingHorizontal = "FIXED"

    const center = figma.createFrame()
    center.name = "Center"
    center.resize(100, 40)
    center.fills = []
    row.appendChild(center)
    center.layoutSizingHorizontal = "FILL"

    const right = figma.createFrame()
    right.name = "Right"
    right.resize(40, 40)
    right.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    row.appendChild(right)
    right.layoutSizingHorizontal = "FIXED"

    figma.currentPage.appendChild(row)
    return JSON.stringify({ success: true, id: row.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }` with left/center/right children.

**Next**: Replace placeholder children with actual content (text, icons, buttons).

### Recipe: Wrap Layout (Tag Cloud / Chip Group)

**Goal**: Create a horizontal container that wraps children to new lines when they exceed the container width.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Medium" })

    const container = figma.createFrame()
    container.name = "Tags"
    container.layoutMode = "HORIZONTAL"
    container.layoutWrap = "WRAP"
    container.primaryAxisSizingMode = "FIXED"
    container.counterAxisSizingMode = "AUTO"
    container.resize(340, 1)
    container.itemSpacing = 8
    container.counterAxisSpacing = 8
    container.counterAxisAlignContent = "AUTO"
    container.fills = []

    const tags = ["Design", "Figma", "Auto-Layout", "Components", "Tokens"]
    const tagNodes = []

    for (const tagText of tags) {
      const chip = figma.createFrame()
      chip.name = `Tag/${tagText}`
      chip.layoutMode = "HORIZONTAL"
      chip.primaryAxisSizingMode = "AUTO"
      chip.counterAxisSizingMode = "AUTO"
      chip.primaryAxisAlignItems = "CENTER"
      chip.counterAxisAlignItems = "CENTER"
      chip.paddingTop = 6
      chip.paddingBottom = 6
      chip.paddingLeft = 12
      chip.paddingRight = 12
      chip.cornerRadius = 8
      chip.fills = [{ type: 'SOLID', color: { r: 0.925, g: 0.902, b: 0.941 } }]

      const label = figma.createText()
      label.fontName = { family: "Inter", style: "Medium" }
      label.characters = tagText
      label.fontSize = 13
      label.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
      chip.appendChild(label)

      container.appendChild(chip)
      tagNodes.push({ id: chip.id, name: chip.name })
    }

    figma.currentPage.appendChild(container)
    return JSON.stringify({ success: true, id: container.id, tags: tagNodes })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", tags: [...] }`

**Next**: Customize chip colors, add remove icons, or wire up to a component variant.

### Recipe: Absolute Positioned Badge on Card

**Goal**: Overlay a notification badge on the top-right corner of an auto-layout card without disrupting the card's layout flow.

**Code**:

```javascript
(async () => {
  try {
    // Assumes `cardId` was returned by a previous card-creation call
    const card = await figma.getNodeByIdAsync("CARD_ID_HERE")
    if (!card) return JSON.stringify({ success: false, error: "Card not found" })

    const badge = figma.createEllipse()
    badge.name = "Badge"
    badge.resize(20, 20)
    badge.fills = [{ type: 'SOLID', color: { r: 0.702, g: 0.149, b: 0.118 } }]
    card.appendChild(badge)
    badge.layoutPositioning = "ABSOLUTE"
    badge.x = card.width - 10
    badge.y = -10
    badge.constraints = { horizontal: "MAX", vertical: "MIN" }

    return JSON.stringify({ success: true, badgeId: badge.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, badgeId: "..." }`

**Next**: Add a count label inside the badge (requires font loading and a text node centered within the ellipse).

---

### Recipe: CSS Grid Card Layout

> Requires: Plugin API Update 115+ (July 2025). See `plugin-api.md` Grid Layout section.

Creates a 3-column responsive grid with flexible tracks, gaps, and a featured card spanning 2 rows.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Regular" })
    await figma.loadFontAsync({ family: "Inter", style: "Bold" })

    const grid = figma.createFrame()
    grid.name = "Card Grid"
    grid.layoutMode = 'GRID'
    grid.resize(960, 720)

    // 3 columns x 3 rows
    grid.gridColumnCount = 3
    grid.gridRowCount = 3

    // Flexible columns (1fr each)
    grid.gridColumnSizes = [
      { type: 'FLEX', value: 1 },
      { type: 'FLEX', value: 1 },
      { type: 'FLEX', value: 1 }
    ]
    // Rows hug content
    grid.gridRowSizes = [
      { type: 'HUG' },
      { type: 'HUG' },
      { type: 'HUG' }
    ]

    grid.gridRowGap = 16
    grid.gridColumnGap = 16
    grid.paddingTop = 24; grid.paddingBottom = 24
    grid.paddingLeft = 24; grid.paddingRight = 24
    grid.fills = [figma.util.solidPaint('#F9FAFB')]

    // Helper: create a card
    function makeCard(name, label) {
      const card = figma.createFrame()
      card.name = name
      card.layoutMode = 'VERTICAL'
      card.itemSpacing = 8
      card.paddingTop = 16; card.paddingBottom = 16
      card.paddingLeft = 16; card.paddingRight = 16
      card.cornerRadius = 12
      card.fills = [figma.util.solidPaint('#FFFFFF')]
      card.strokes = [figma.util.solidPaint('#E5E7EB')]
      card.strokeWeight = 1
      card.layoutSizingHorizontal = 'FILL'
      card.layoutSizingVertical = 'FILL'

      const title = figma.createText()
      title.fontName = { family: "Inter", style: "Bold" }
      title.characters = label
      title.fontSize = 16
      card.appendChild(title)

      return card
    }

    // Featured card spanning 2 rows
    const featured = makeCard("Featured", "Featured Item")
    grid.appendChildAt(featured, 0, 0)
    featured.gridRowSpan = 2

    // Regular cards
    grid.appendChildAt(makeCard("Card-B", "Item B"), 0, 1)
    grid.appendChildAt(makeCard("Card-C", "Item C"), 0, 2)
    grid.appendChildAt(makeCard("Card-D", "Item D"), 1, 1)
    grid.appendChildAt(makeCard("Card-E", "Item E"), 1, 2)
    grid.appendChildAt(makeCard("Card-F", "Item F"), 2, 0)

    figma.currentPage.appendChild(grid)
    figma.viewport.scrollAndZoomIntoView([grid])
    console.log(JSON.stringify({ success: true, id: grid.id }))
  } catch (e) {
    console.log(JSON.stringify({ error: e.message }))
  }
})()
```

**Key patterns**: `layoutMode = 'GRID'` + `gridColumnCount`/`gridRowCount` for structure, `GridTrackSize` objects for sizing, `appendChildAt(node, row, col)` for placement, `gridRowSpan` for spanning.

**Variation — Fixed + Flex columns** (sidebar layout):
```javascript
grid.gridColumnSizes = [
  { type: 'FIXED', value: 240 },  // sidebar
  { type: 'FLEX', value: 1 }       // main content
]
grid.gridColumnCount = 2
```
