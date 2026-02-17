# M3 Recipes — Material Design 3 Components

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> For M3 spec values (colors, typography, dimensions), see `design-rules.md`. For Plugin API details, see `plugin-api.md`. For common errors, see `anti-patterns.md`.
> For core recipes (foundation patterns, layouts, generic components, composition), see `recipes-foundation.md`, `recipes-components.md`, and `recipes-advanced.md`.

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

---

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

---

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

---

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

---

## M3 Text Field (Outlined)

**Goal**: Create a Material Design 3 Outlined Text Field -- 56px height, 4px corner radius, 16px padding, 1px Outline border, with placeholder label.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Roboto", style: "Regular" }),
      figma.loadFontAsync({ family: "Roboto", style: "Medium" }),
    ])

    const field = figma.createFrame()
    field.name = "M3/TextField/Outlined"
    field.layoutMode = "VERTICAL"
    field.primaryAxisSizingMode = "FIXED"
    field.counterAxisSizingMode = "FIXED"
    field.resize(280, 56)
    field.primaryAxisAlignItems = "CENTER"
    field.counterAxisAlignItems = "MIN"
    field.paddingLeft = 16
    field.paddingRight = 16
    field.paddingTop = 8
    field.paddingBottom = 8
    field.cornerRadius = 4
    // Surface
    field.fills = [{ type: 'SOLID', color: { r: 1, g: 0.984, b: 0.996 } }]
    // Outline: #79747E
    field.strokes = [{ type: 'SOLID', color: { r: 0.475, g: 0.455, b: 0.494 } }]
    field.strokeWeight = 1
    field.strokeAlign = "INSIDE"

    // Floating label (unfocused state — inside the field)
    const label = figma.createText()
    label.name = "Label"
    label.fontName = { family: "Roboto", style: "Regular" }
    label.characters = "Label"
    label.fontSize = 16
    label.lineHeight = { value: 24, unit: "PIXELS" }
    label.letterSpacing = { value: 0.5, unit: "PIXELS" }
    // On Surface Variant: #49454F
    label.fills = [{ type: 'SOLID', color: { r: 0.286, g: 0.271, b: 0.310 } }]
    field.appendChild(label)
    label.layoutSizingHorizontal = "FILL"

    figma.currentPage.appendChild(field)
    return JSON.stringify({ success: true, id: field.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Create focused state variant (2px Primary border, 12px label above the field) and combine with `figma.combineAsVariants()`.

---

## M3 Bottom Navigation Bar

**Goal**: Create a Material Design 3 Bottom Navigation Bar -- 80px height, 3 items with icons and labels, active indicator pill.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Roboto", style: "Medium" })

    const nav = figma.createFrame()
    nav.name = "M3/BottomNavigation"
    nav.layoutMode = "HORIZONTAL"
    nav.counterAxisSizingMode = "FIXED"
    nav.primaryAxisSizingMode = "FIXED"
    nav.resize(375, 80)
    nav.primaryAxisAlignItems = "SPACE_BETWEEN"
    nav.counterAxisAlignItems = "CENTER"
    nav.paddingLeft = 0
    nav.paddingRight = 0
    nav.paddingTop = 12
    nav.paddingBottom = 16
    // Surface Container: #F3EDF7
    nav.fills = [{ type: 'SOLID', color: { r: 0.953, g: 0.929, b: 0.969 } }]

    const items = [
      { label: "Home", active: true },
      { label: "Search", active: false },
      { label: "Profile", active: false },
    ]

    const navItems = []
    for (const item of items) {
      const navItem = figma.createFrame()
      navItem.name = `NavItem/${item.label}`
      navItem.layoutMode = "VERTICAL"
      navItem.primaryAxisSizingMode = "AUTO"
      navItem.counterAxisSizingMode = "AUTO"
      navItem.primaryAxisAlignItems = "CENTER"
      navItem.counterAxisAlignItems = "CENTER"
      navItem.itemSpacing = 4
      navItem.fills = []
      navItem.paddingLeft = 20
      navItem.paddingRight = 20

      // Active indicator pill (64x32px)
      const indicator = figma.createFrame()
      indicator.name = "Active-Indicator"
      indicator.resize(64, 32)
      indicator.cornerRadius = 16
      if (item.active) {
        // Secondary Container: #E8DEF8
        indicator.fills = [{ type: 'SOLID', color: { r: 0.910, g: 0.871, b: 0.973 } }]
      } else {
        indicator.fills = []
      }
      // Icon placeholder (24x24, centered in indicator)
      indicator.layoutMode = "HORIZONTAL"
      indicator.primaryAxisAlignItems = "CENTER"
      indicator.counterAxisAlignItems = "CENTER"
      const iconPlaceholder = figma.createFrame()
      iconPlaceholder.name = "Icon"
      iconPlaceholder.resize(24, 24)
      iconPlaceholder.fills = []
      indicator.appendChild(iconPlaceholder)
      navItem.appendChild(indicator)

      // Label: Label Medium (12px, Roboto Medium)
      const label = figma.createText()
      label.fontName = { family: "Roboto", style: "Medium" }
      label.characters = item.label
      label.fontSize = 12
      label.lineHeight = { value: 16, unit: "PIXELS" }
      label.letterSpacing = { value: 0.5, unit: "PIXELS" }
      // On Surface: #1C1B1F
      label.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
      navItem.appendChild(label)

      nav.appendChild(navItem)
      navItem.layoutSizingHorizontal = "FILL"
      navItems.push({ id: navItem.id, label: item.label })
    }

    figma.currentPage.appendChild(nav)
    return JSON.stringify({ success: true, id: nav.id, items: navItems })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", items: [...] }`

**Next**: Replace icon placeholders with actual icon components via `figma_instantiate_component`, or add a 4th and 5th nav item.

---

## M3 Dialog

**Goal**: Create a Material Design 3 Dialog -- min 280px / max 560px width, 28px corner radius, 24px padding, Level 3 elevation, with title, body, and action buttons.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Roboto", style: "Regular" }),
      figma.loadFontAsync({ family: "Roboto", style: "Medium" }),
    ])

    const dialog = figma.createFrame()
    dialog.name = "M3/Dialog"
    dialog.layoutMode = "VERTICAL"
    dialog.primaryAxisSizingMode = "AUTO"
    dialog.counterAxisSizingMode = "FIXED"
    dialog.resize(400, 1)
    dialog.primaryAxisAlignItems = "MIN"
    dialog.counterAxisAlignItems = "MIN"
    dialog.paddingTop = 24
    dialog.paddingBottom = 24
    dialog.paddingLeft = 24
    dialog.paddingRight = 24
    dialog.itemSpacing = 16
    dialog.cornerRadius = 28
    // Surface Container High: #ECE6F0
    dialog.fills = [{ type: 'SOLID', color: { r: 0.925, g: 0.902, b: 0.941 } }]
    // Level 3 elevation
    dialog.effects = [
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
    dialog.minWidth = 280
    dialog.maxWidth = 560

    // Headline
    const headline = figma.createText()
    headline.name = "Headline"
    headline.fontName = { family: "Roboto", style: "Regular" }
    headline.characters = "Dialog Title"
    headline.fontSize = 24
    headline.lineHeight = { value: 32, unit: "PIXELS" }
    // On Surface: #1C1B1F
    headline.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }]
    dialog.appendChild(headline)
    headline.layoutSizingHorizontal = "FILL"

    // Supporting text
    const body = figma.createText()
    body.name = "Body"
    body.fontName = { family: "Roboto", style: "Regular" }
    body.characters = "A dialog is a type of modal window that appears in front of app content to provide critical information, or prompt for a decision to be made."
    body.fontSize = 14
    body.lineHeight = { value: 20, unit: "PIXELS" }
    body.letterSpacing = { value: 0.25, unit: "PIXELS" }
    // On Surface Variant: #49454F
    body.fills = [{ type: 'SOLID', color: { r: 0.286, g: 0.271, b: 0.310 } }]
    dialog.appendChild(body)
    body.layoutSizingHorizontal = "FILL"

    // Action buttons row
    const actions = figma.createFrame()
    actions.name = "Actions"
    actions.layoutMode = "HORIZONTAL"
    actions.primaryAxisSizingMode = "FIXED"
    actions.counterAxisSizingMode = "AUTO"
    actions.primaryAxisAlignItems = "MAX"
    actions.counterAxisAlignItems = "CENTER"
    actions.itemSpacing = 8
    actions.fills = []
    dialog.appendChild(actions)
    actions.layoutSizingHorizontal = "FILL"

    // Cancel button (text style)
    const cancelBtn = figma.createFrame()
    cancelBtn.name = "Button/Cancel"
    cancelBtn.layoutMode = "HORIZONTAL"
    cancelBtn.primaryAxisSizingMode = "AUTO"
    cancelBtn.counterAxisSizingMode = "AUTO"
    cancelBtn.primaryAxisAlignItems = "CENTER"
    cancelBtn.counterAxisAlignItems = "CENTER"
    cancelBtn.paddingTop = 10
    cancelBtn.paddingBottom = 10
    cancelBtn.paddingLeft = 12
    cancelBtn.paddingRight = 12
    cancelBtn.cornerRadius = 20
    cancelBtn.fills = []

    const cancelLabel = figma.createText()
    cancelLabel.fontName = { family: "Roboto", style: "Medium" }
    cancelLabel.characters = "Cancel"
    cancelLabel.fontSize = 14
    cancelLabel.lineHeight = { value: 20, unit: "PIXELS" }
    cancelLabel.letterSpacing = { value: 0.1, unit: "PIXELS" }
    // Primary: #6750A4
    cancelLabel.fills = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]
    cancelBtn.appendChild(cancelLabel)
    actions.appendChild(cancelBtn)

    // Confirm button (text style)
    const confirmBtn = figma.createFrame()
    confirmBtn.name = "Button/Confirm"
    confirmBtn.layoutMode = "HORIZONTAL"
    confirmBtn.primaryAxisSizingMode = "AUTO"
    confirmBtn.counterAxisSizingMode = "AUTO"
    confirmBtn.primaryAxisAlignItems = "CENTER"
    confirmBtn.counterAxisAlignItems = "CENTER"
    confirmBtn.paddingTop = 10
    confirmBtn.paddingBottom = 10
    confirmBtn.paddingLeft = 12
    confirmBtn.paddingRight = 12
    confirmBtn.cornerRadius = 20
    confirmBtn.fills = []

    const confirmLabel = figma.createText()
    confirmLabel.fontName = { family: "Roboto", style: "Medium" }
    confirmLabel.characters = "Confirm"
    confirmLabel.fontSize = 14
    confirmLabel.lineHeight = { value: 20, unit: "PIXELS" }
    confirmLabel.letterSpacing = { value: 0.1, unit: "PIXELS" }
    confirmLabel.fills = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]
    confirmBtn.appendChild(confirmLabel)
    actions.appendChild(confirmBtn)

    figma.currentPage.appendChild(dialog)
    figma.viewport.scrollAndZoomIntoView([dialog])
    return JSON.stringify({ success: true, id: dialog.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Add an icon above the headline, or create a fullscreen dialog variant for mobile.

---

## M3 Snackbar

**Goal**: Create a Material Design 3 Snackbar -- Inverse Surface container, 4px corner radius, single-line message with optional action button.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Roboto", style: "Regular" }),
      figma.loadFontAsync({ family: "Roboto", style: "Medium" }),
    ])

    const snackbar = figma.createFrame()
    snackbar.name = "M3/Snackbar"
    snackbar.layoutMode = "HORIZONTAL"
    snackbar.primaryAxisSizingMode = "FIXED"
    snackbar.counterAxisSizingMode = "AUTO"
    snackbar.resize(344, 1)
    snackbar.primaryAxisAlignItems = "SPACE_BETWEEN"
    snackbar.counterAxisAlignItems = "CENTER"
    snackbar.paddingLeft = 16
    snackbar.paddingRight = 8
    snackbar.paddingTop = 0
    snackbar.paddingBottom = 0
    snackbar.minHeight = 48
    snackbar.cornerRadius = 4
    // Inverse Surface: #313033
    snackbar.fills = [{ type: 'SOLID', color: { r: 0.192, g: 0.188, b: 0.200 } }]
    // Level 3 elevation
    snackbar.effects = [
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

    // Message text
    const message = figma.createText()
    message.name = "Message"
    message.fontName = { family: "Roboto", style: "Regular" }
    message.characters = "Changes saved successfully"
    message.fontSize = 14
    message.lineHeight = { value: 20, unit: "PIXELS" }
    message.letterSpacing = { value: 0.25, unit: "PIXELS" }
    // Inverse On Surface: #F4EFF4
    message.fills = [{ type: 'SOLID', color: { r: 0.957, g: 0.937, b: 0.957 } }]
    snackbar.appendChild(message)
    message.layoutSizingHorizontal = "FILL"

    // Action button
    const actionBtn = figma.createFrame()
    actionBtn.name = "Action"
    actionBtn.layoutMode = "HORIZONTAL"
    actionBtn.primaryAxisSizingMode = "AUTO"
    actionBtn.counterAxisSizingMode = "AUTO"
    actionBtn.primaryAxisAlignItems = "CENTER"
    actionBtn.counterAxisAlignItems = "CENTER"
    actionBtn.paddingTop = 10
    actionBtn.paddingBottom = 10
    actionBtn.paddingLeft = 12
    actionBtn.paddingRight = 12
    actionBtn.cornerRadius = 20
    actionBtn.fills = []

    const actionLabel = figma.createText()
    actionLabel.fontName = { family: "Roboto", style: "Medium" }
    actionLabel.characters = "Undo"
    actionLabel.fontSize = 14
    actionLabel.lineHeight = { value: 20, unit: "PIXELS" }
    actionLabel.letterSpacing = { value: 0.1, unit: "PIXELS" }
    // Inverse Primary: #D0BCFF
    actionLabel.fills = [{ type: 'SOLID', color: { r: 0.816, g: 0.737, b: 1.0 } }]
    actionBtn.appendChild(actionLabel)
    snackbar.appendChild(actionBtn)

    figma.currentPage.appendChild(snackbar)
    return JSON.stringify({ success: true, id: snackbar.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Create a two-line variant (max height 68px) or add a close icon button on the right.
