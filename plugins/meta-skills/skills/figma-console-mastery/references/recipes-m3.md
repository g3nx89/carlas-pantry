# M3 Recipes — Material Design 3 Components

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> For M3 spec values (colors, typography, dimensions), see `design-rules.md`. For Plugin API details, see `plugin-api.md`. For common errors, see `anti-patterns.md`.
> For core recipes (foundation patterns, layouts, generic components, composition), see `recipes.md`.

---

## M3 Filled Button

**Goal**: Create a Material Design 3 Filled Button with exact spec values per `design-rules.md` M3 Button Specifications.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Roboto", style: "Medium" })

    const btn = figma.createFrame()
    btn.name = "M3/Button/Filled"
    btn.layoutMode = "HORIZONTAL"
    btn.counterAxisSizingMode = "FIXED"
    btn.primaryAxisSizingMode = "AUTO"
    btn.resize(100, 40)
    btn.primaryAxisAlignItems = "CENTER"
    btn.counterAxisAlignItems = "CENTER"
    btn.paddingLeft = 24
    btn.paddingRight = 24
    btn.paddingTop = 0
    btn.paddingBottom = 0
    btn.cornerRadius = 20
    // Primary: #6750A4
    btn.fills = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]

    const label = figma.createText()
    label.fontName = { family: "Roboto", style: "Medium" }
    label.characters = "Button"
    label.fontSize = 14
    label.lineHeight = { value: 20, unit: "PIXELS" }
    label.letterSpacing = { value: 0.1, unit: "PIXELS" }
    // On Primary: #FFFFFF
    label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    btn.appendChild(label)

    figma.currentPage.appendChild(btn)
    return JSON.stringify({ success: true, id: btn.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Create Outlined, Text, Elevated, and Tonal variants, then combine with `figma.combineAsVariants()`.

## M3 Card (Outlined)

**Goal**: Create a Material Design 3 Outlined Card with 12px radius, 1px Outline Variant border, and 16px padding.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Roboto", style: "Regular" }),
      figma.loadFontAsync({ family: "Roboto", style: "Medium" }),
    ])

    const card = figma.createFrame()
    card.name = "M3/Card/Outlined"
    card.layoutMode = "VERTICAL"
    card.primaryAxisAlignItems = "MIN"
    card.counterAxisAlignItems = "MIN"
    card.primaryAxisSizingMode = "AUTO"
    card.counterAxisSizingMode = "FIXED"
    card.resize(320, 1)
    card.paddingTop = 16
    card.paddingBottom = 16
    card.paddingLeft = 16
    card.paddingRight = 16
    card.itemSpacing = 16
    card.cornerRadius = 12
    // Surface: #FFFBFE
    card.fills = [{ type: 'SOLID', color: { r: 1, g: 0.984, b: 0.996 } }]
    // Outline Variant: #CAC4D0
    card.strokes = [{ type: 'SOLID', color: { r: 0.792, g: 0.769, b: 0.816 } }]
    card.strokeWeight = 1
    card.strokeAlign = "INSIDE"

    const heading = figma.createText()
    heading.fontName = { family: "Roboto", style: "Medium" }
    heading.characters = "Card Heading"
    heading.fontSize = 16
    heading.lineHeight = { value: 24, unit: "PIXELS" }
    heading.letterSpacing = { value: 0.15, unit: "PIXELS" }
    // On Surface: #1C1B1F
    heading.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
    card.appendChild(heading)
    heading.layoutSizingHorizontal = "FILL"

    const body = figma.createText()
    body.fontName = { family: "Roboto", style: "Regular" }
    body.characters = "Supporting text for the card content area."
    body.fontSize = 14
    body.lineHeight = { value: 20, unit: "PIXELS" }
    body.letterSpacing = { value: 0.25, unit: "PIXELS" }
    body.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
    card.appendChild(body)
    body.layoutSizingHorizontal = "FILL"

    figma.currentPage.appendChild(card)
    figma.viewport.scrollAndZoomIntoView([card])
    return JSON.stringify({ success: true, id: card.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Add a media image slot above the text, or add action buttons in a horizontal row at the bottom.

## M3 Top App Bar (Small)

**Goal**: Create a Material Design 3 Small Top App Bar -- 64px height, horizontal layout, Title Large (22px), 16px padding.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Roboto", style: "Regular" })

    const appBar = figma.createFrame()
    appBar.name = "M3/TopAppBar/Small"
    appBar.layoutMode = "HORIZONTAL"
    appBar.counterAxisSizingMode = "FIXED"
    appBar.primaryAxisSizingMode = "FIXED"
    appBar.resize(375, 64)
    appBar.primaryAxisAlignItems = "SPACE_BETWEEN"
    appBar.counterAxisAlignItems = "CENTER"
    appBar.paddingLeft = 16
    appBar.paddingRight = 16
    appBar.paddingTop = 0
    appBar.paddingBottom = 0
    // Surface: #FFFBFE
    appBar.fills = [{ type: 'SOLID', color: { r: 1, g: 0.984, b: 0.996 } }]

    // Leading icon placeholder
    const leadingIcon = figma.createFrame()
    leadingIcon.name = "Leading-Icon"
    leadingIcon.resize(48, 48)
    leadingIcon.cornerRadius = 24
    leadingIcon.fills = []
    appBar.appendChild(leadingIcon)
    leadingIcon.layoutSizingHorizontal = "FIXED"

    // Title
    const title = figma.createText()
    title.fontName = { family: "Roboto", style: "Regular" }
    title.characters = "Title"
    title.fontSize = 22
    title.lineHeight = { value: 28, unit: "PIXELS" }
    // On Surface: #1C1B1F
    title.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
    appBar.appendChild(title)
    title.layoutSizingHorizontal = "FILL"

    // Trailing icon placeholder
    const trailingIcon = figma.createFrame()
    trailingIcon.name = "Trailing-Icon"
    trailingIcon.resize(48, 48)
    trailingIcon.cornerRadius = 24
    trailingIcon.fills = []
    appBar.appendChild(trailingIcon)
    trailingIcon.layoutSizingHorizontal = "FIXED"

    figma.currentPage.appendChild(appBar)
    return JSON.stringify({ success: true, id: appBar.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Replace icon placeholders with actual icon components via `figma_instantiate_component`, or add elevation for a scrolled state.

## M3 Elevation Shadows

**Goal**: Ready-to-paste effect arrays for M3 elevation levels 1, 2, and 3.

All shadow colors use Figma 0-1 RGB format. Each level uses two shadow layers matching the M3 specification.

**Level 1 (1dp)**:

```javascript
const elevation1 = [
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.3 },
    offset: { x: 0, y: 1 },
    radius: 3,
    visible: true,
    blendMode: 'NORMAL'
  },
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.15 },
    offset: { x: 0, y: 1 },
    radius: 3,
    spread: 1,
    visible: true,
    blendMode: 'NORMAL'
  }
]
```

**Level 2 (3dp)**:

```javascript
const elevation2 = [
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.3 },
    offset: { x: 0, y: 1 },
    radius: 2,
    visible: true,
    blendMode: 'NORMAL'
  },
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.15 },
    offset: { x: 0, y: 2 },
    radius: 6,
    spread: 2,
    visible: true,
    blendMode: 'NORMAL'
  }
]
```

**Level 3 (6dp)**:

```javascript
const elevation3 = [
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.3 },
    offset: { x: 0, y: 1 },
    radius: 3,
    visible: true,
    blendMode: 'NORMAL'
  },
  {
    type: 'DROP_SHADOW',
    color: { r: 0, g: 0, b: 0, a: 0.15 },
    offset: { x: 0, y: 4 },
    radius: 8,
    spread: 3,
    visible: true,
    blendMode: 'NORMAL'
  }
]
```

**Usage**: Assign to any node's `effects` property:

```javascript
card.effects = elevation2
```
