# Recipes — Component Patterns

> **Compatibility**: Verified against figma-console-mcp v1.11.2 (February 2026)
>
> **Prerequisite**: Load `recipes-foundation.md` first — all component recipes assume familiarity with the IIFE wrapper, font preloading, and node reference patterns.
>
> **Scope**: Basic/atomic UI component recipes (Card, Button, Input, Toast, Navbar, Sidebar). For composite patterns (Form, Data Table, Empty State, Modal, Dashboard Header, Variant Set), see `recipes-components-composite.md`. For handoff patterns (GROUP→FRAME, Componentize from Clone, Variant Instantiation), see `recipes-handoff.md`.
>
> For Plugin API details, see `plugin-api-foundation.md`, `plugin-api-visuals.md`, `plugin-api-advanced.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.
> For foundation patterns and layouts, see `recipes-foundation.md`. For composition and advanced patterns, see `recipes-advanced.md`. For M3 component recipes, see `recipes-m3.md`.

## Recipe Index

| Recipe | Line |
|--------|-----:|
| Card with Auto-Layout | 27 |
| Button (Horizontal, Hug-Both) | 93 |
| Input Field (Outlined) | 138 |
| Toast Notification | 187 |
| Top Navigation Bar | 253 |
| Sidebar Navigation | 326 |

---

## Component Recipes

### Recipe: Card with Auto-Layout

**Goal**: Create a complete card component with vertical layout, shadow, title, and body text.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Bold" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
    ])

    const card = figma.createFrame()
    card.name = "Card"
    card.layoutMode = "VERTICAL"
    card.primaryAxisAlignItems = "MIN"
    card.counterAxisAlignItems = "MIN"
    card.paddingTop = 24
    card.paddingBottom = 24
    card.paddingLeft = 24
    card.paddingRight = 24
    card.itemSpacing = 16
    card.resize(320, 1)
    card.layoutSizingVertical = "HUG"
    card.layoutSizingHorizontal = "FIXED"
    card.cornerRadius = 16
    card.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    card.effects = [{
      type: 'DROP_SHADOW',
      color: { r: 0, g: 0, b: 0, a: 0.1 },
      offset: { x: 0, y: 4 },
      radius: 12,
      visible: true,
      blendMode: 'NORMAL'
    }]

    const title = figma.createText()
    title.fontName = { family: "Inter", style: "Bold" }
    title.characters = "Card Title"
    title.fontSize = 20
    card.appendChild(title)
    title.layoutSizingHorizontal = "FILL"

    const body = figma.createText()
    body.fontName = { family: "Inter", style: "Regular" }
    body.characters = "Card body text goes here. This supports multiple lines and will wrap within the card width."
    body.fontSize = 14
    body.lineHeight = { value: 20, unit: "PIXELS" }
    card.appendChild(body)
    body.layoutSizingHorizontal = "FILL"

    figma.currentPage.appendChild(card)
    figma.viewport.scrollAndZoomIntoView([card])
    return JSON.stringify({ success: true, id: card.id, name: card.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Card" }`

**Next**: Add action buttons, images, or convert to a component with `figma.createComponentFromNode(card)`.

### Recipe: Button (Horizontal, Hug-Both)

**Goal**: Create a button with horizontal layout that hugs its label content on both axes.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Medium" })

    const button = figma.createFrame()
    button.name = "Button/Primary"
    button.layoutMode = "HORIZONTAL"
    button.primaryAxisSizingMode = "AUTO"
    button.counterAxisSizingMode = "AUTO"
    button.primaryAxisAlignItems = "CENTER"
    button.counterAxisAlignItems = "CENTER"
    button.paddingTop = 10
    button.paddingBottom = 10
    button.paddingLeft = 24
    button.paddingRight = 24
    button.itemSpacing = 8
    button.cornerRadius = 6
    button.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]

    const label = figma.createText()
    label.fontName = { family: "Inter", style: "Medium" }
    label.characters = "Click Me"
    label.fontSize = 14
    label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    button.appendChild(label)

    figma.currentPage.appendChild(button)
    return JSON.stringify({ success: true, id: button.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Convert to component with `figma.createComponentFromNode(button)` or add an icon before the label.

### Recipe: Input Field (Outlined)

**Goal**: Create a 56px-height outlined text input with placeholder text and 16px padding.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Regular" })

    const input = figma.createFrame()
    input.name = "Input/Outlined"
    input.layoutMode = "HORIZONTAL"
    input.counterAxisSizingMode = "FIXED"
    input.primaryAxisSizingMode = "FIXED"
    input.resize(280, 56)
    input.primaryAxisAlignItems = "MIN"
    input.counterAxisAlignItems = "CENTER"
    input.paddingLeft = 16
    input.paddingRight = 16
    input.paddingTop = 0
    input.paddingBottom = 0
    input.cornerRadius = 4
    input.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    input.strokes = [{ type: 'SOLID', color: { r: 0.475, g: 0.455, b: 0.494 } }]
    input.strokeWeight = 1
    input.strokeAlign = "INSIDE"

    const placeholder = figma.createText()
    placeholder.fontName = { family: "Inter", style: "Regular" }
    placeholder.characters = "Enter text..."
    placeholder.fontSize = 16
    placeholder.fills = [{ type: 'SOLID', color: { r: 0.475, g: 0.455, b: 0.494 } }]
    input.appendChild(placeholder)
    placeholder.layoutSizingHorizontal = "FILL"

    figma.currentPage.appendChild(input)
    return JSON.stringify({ success: true, id: input.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Add a floating label above the field, or pair with a helper-text row below.

### Recipe: Toast Notification

**Goal**: Create a toast/snackbar-style notification with horizontal layout -- icon placeholder on left, message text in center (FILL), dismiss X on right.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Regular" })

    const toast = figma.createFrame()
    toast.name = "Toast/Notification"
    toast.layoutMode = "HORIZONTAL"
    toast.primaryAxisSizingMode = "FIXED"
    toast.counterAxisSizingMode = "AUTO"
    toast.resize(344, 1)
    toast.primaryAxisAlignItems = "MIN"
    toast.counterAxisAlignItems = "CENTER"
    toast.paddingTop = 12
    toast.paddingBottom = 12
    toast.paddingLeft = 12
    toast.paddingRight = 12
    toast.itemSpacing = 12
    toast.cornerRadius = 8
    toast.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }]

    const icon = figma.createFrame()
    icon.name = "Icon"
    icon.resize(24, 24)
    icon.cornerRadius = 4
    icon.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }]
    toast.appendChild(icon)
    icon.layoutSizingHorizontal = "FIXED"
    icon.layoutSizingVertical = "FIXED"

    const message = figma.createText()
    message.fontName = { family: "Inter", style: "Regular" }
    message.characters = "This is a toast notification message."
    message.fontSize = 14
    message.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    toast.appendChild(message)
    message.layoutSizingHorizontal = "FILL"

    const dismiss = figma.createFrame()
    dismiss.name = "Dismiss"
    dismiss.resize(24, 24)
    dismiss.cornerRadius = 4
    dismiss.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }]
    toast.appendChild(dismiss)
    dismiss.layoutSizingHorizontal = "FIXED"
    dismiss.layoutSizingVertical = "FIXED"

    figma.currentPage.appendChild(toast)
    figma.viewport.scrollAndZoomIntoView([toast])
    return JSON.stringify({ success: true, id: toast.id, name: toast.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Toast/Notification" }`

**Next**: Replace icon and dismiss placeholders with SVG imports, or add a slide-in animation prototype trigger.

### Recipe: Top Navigation Bar

**Goal**: Create a horizontal top navigation bar with logo placeholder on left, nav links in center row, avatar placeholder on right.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Medium" })

    const navbar = figma.createFrame()
    navbar.name = "TopNavBar"
    navbar.layoutMode = "HORIZONTAL"
    navbar.primaryAxisSizingMode = "FIXED"
    navbar.counterAxisSizingMode = "FIXED"
    navbar.resize(375, 56)
    navbar.primaryAxisAlignItems = "SPACE_BETWEEN"
    navbar.counterAxisAlignItems = "CENTER"
    navbar.paddingTop = 0
    navbar.paddingBottom = 0
    navbar.paddingLeft = 16
    navbar.paddingRight = 16
    navbar.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    const logo = figma.createFrame()
    logo.name = "Logo"
    logo.resize(32, 32)
    logo.cornerRadius = 4
    logo.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    navbar.appendChild(logo)
    logo.layoutSizingHorizontal = "FIXED"
    logo.layoutSizingVertical = "FIXED"

    const navLinks = figma.createFrame()
    navLinks.name = "NavLinks"
    navLinks.layoutMode = "HORIZONTAL"
    navLinks.primaryAxisSizingMode = "AUTO"
    navLinks.counterAxisSizingMode = "AUTO"
    navLinks.itemSpacing = 24
    navLinks.fills = []

    const linkLabels = ["Home", "Features", "Pricing"]
    for (const linkText of linkLabels) {
      const link = figma.createText()
      link.fontName = { family: "Inter", style: "Medium" }
      link.characters = linkText
      link.fontSize = 14
      link.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
      navLinks.appendChild(link)
    }

    navbar.appendChild(navLinks)

    const avatar = figma.createEllipse()
    avatar.name = "Avatar"
    avatar.resize(32, 32)
    avatar.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    navbar.appendChild(avatar)

    figma.currentPage.appendChild(navbar)
    figma.viewport.scrollAndZoomIntoView([navbar])
    return JSON.stringify({ success: true, id: navbar.id, name: navbar.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "TopNavBar" }`

**Next**: Add a bottom border stroke, swap logo/avatar placeholders with images, or add dropdown menus to nav links.

### Recipe: Sidebar Navigation

**Goal**: Create a vertical sidebar with section headers and navigation items. Active item highlighted with SecondaryContainer fill.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
    ])

    const sidebar = figma.createFrame()
    sidebar.name = "Sidebar"
    sidebar.layoutMode = "VERTICAL"
    sidebar.primaryAxisSizingMode = "AUTO"
    sidebar.counterAxisSizingMode = "FIXED"
    sidebar.resize(240, 1)
    sidebar.paddingTop = 16
    sidebar.paddingBottom = 16
    sidebar.paddingLeft = 16
    sidebar.paddingRight = 16
    sidebar.itemSpacing = 4
    sidebar.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    // Section header
    const sectionHeader = figma.createText()
    sectionHeader.fontName = { family: "Inter", style: "Medium" }
    sectionHeader.characters = "NAVIGATION"
    sectionHeader.fontSize = 12
    sectionHeader.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }]
    sectionHeader.textCase = "UPPER"
    sidebar.appendChild(sectionHeader)
    sectionHeader.layoutSizingHorizontal = "FILL"

    const navItems = [
      { label: "Dashboard", active: true },
      { label: "Projects", active: false },
      { label: "Settings", active: false },
      { label: "Analytics", active: false },
    ]

    for (const item of navItems) {
      const row = figma.createFrame()
      row.name = `NavItem/${item.label}`
      row.layoutMode = "HORIZONTAL"
      row.primaryAxisSizingMode = "AUTO"
      row.counterAxisSizingMode = "AUTO"
      row.primaryAxisAlignItems = "MIN"
      row.counterAxisAlignItems = "CENTER"
      row.paddingTop = 8
      row.paddingBottom = 8
      row.paddingLeft = 8
      row.paddingRight = 8
      row.cornerRadius = 8

      if (item.active) {
        row.fills = [{ type: 'SOLID', color: { r: 0.910, g: 0.871, b: 0.973 } }]
      } else {
        row.fills = []
      }

      const label = figma.createText()
      label.fontName = { family: "Inter", style: "Regular" }
      label.characters = item.label
      label.fontSize = 14
      label.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
      row.appendChild(label)

      sidebar.appendChild(row)
      row.layoutSizingHorizontal = "FILL"
    }

    figma.currentPage.appendChild(sidebar)
    figma.viewport.scrollAndZoomIntoView([sidebar])
    return JSON.stringify({ success: true, id: sidebar.id, name: sidebar.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Sidebar" }`

**Next**: Add icons before each nav label, nest sub-sections, or convert to a component with active-state variant.
