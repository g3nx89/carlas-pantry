# Recipes — Building Specific UI Patterns

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> For Plugin API details, see `plugin-api.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.

## Recipe Index

| Section | Recipe | Line |
|---------|--------|-----:|
| **Foundation** | Error-Handled IIFE Wrapper | 43 |
| | Multi-Font Preloading | 69 |
| | Node Reference Across Calls | 93 |
| | Returning Structured Data | 110 |
| **Layouts** | Page Container (Full-Width Vertical Stack) | 128 |
| | Horizontal Row with Fill Children | 165 |
| | Wrap Layout (Tag Cloud / Chip Group) | 220 |
| | Absolute Positioned Badge on Card | 284 |
| **Components** | Card with Auto-Layout | 322 |
| | Button (Horizontal, Hug-Both) | 388 |
| | Input Field (Outlined) | 433 |
| | Toast Notification | 482 |
| | Top Navigation Bar | 548 |
| | Sidebar Navigation | 621 |
| | Form Layout | 709 |
| | Data Table Row | 825 |
| | Empty State | 931 |
| | Modal with Scrim Overlay | 1030 |
| | Dashboard Header | 1174 |
| | Component Variant Set | 1310 |
| **Composition** | Shell Injection (Multi-Region Pages) | 1374 |
| | Compose Library Components into Layout | 1442 |
| | Design System Bootstrap | 1509 |
| **Advanced** | Variable Binding to Nodes | 1581 |
| | SVG Import and Styling | 1669 |
| | Mixed-Style Rich Text | 1706 |
| **Full Page** | Settings Page (End-to-End Multi-Call) | 1756 |

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

### Recipe: Form Layout

**Goal**: Create a vertical form with labeled input fields and a submit button.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
    ])

    const form = figma.createFrame()
    form.name = "Form"
    form.layoutMode = "VERTICAL"
    form.primaryAxisSizingMode = "AUTO"
    form.counterAxisSizingMode = "FIXED"
    form.resize(400, 1)
    form.paddingTop = 24
    form.paddingBottom = 24
    form.paddingLeft = 24
    form.paddingRight = 24
    form.itemSpacing = 20
    form.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    const fields = [
      { label: "Full Name", placeholder: "Enter your name..." },
      { label: "Email Address", placeholder: "Enter your email..." },
    ]

    for (const field of fields) {
      const group = figma.createFrame()
      group.name = `Field/${field.label}`
      group.layoutMode = "VERTICAL"
      group.primaryAxisSizingMode = "AUTO"
      group.counterAxisSizingMode = "AUTO"
      group.itemSpacing = 6
      group.fills = []

      const label = figma.createText()
      label.fontName = { family: "Inter", style: "Medium" }
      label.characters = field.label
      label.fontSize = 14
      label.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
      group.appendChild(label)

      const input = figma.createFrame()
      input.name = "Input"
      input.layoutMode = "HORIZONTAL"
      input.primaryAxisSizingMode = "AUTO"
      input.counterAxisSizingMode = "FIXED"
      input.resize(100, 44)
      input.primaryAxisAlignItems = "MIN"
      input.counterAxisAlignItems = "CENTER"
      input.paddingLeft = 12
      input.paddingRight = 12
      input.paddingTop = 0
      input.paddingBottom = 0
      input.cornerRadius = 8
      input.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
      input.strokes = [{ type: 'SOLID', color: { r: 0.8, g: 0.8, b: 0.8 } }]
      input.strokeWeight = 1
      input.strokeAlign = "INSIDE"

      const placeholder = figma.createText()
      placeholder.fontName = { family: "Inter", style: "Regular" }
      placeholder.characters = field.placeholder
      placeholder.fontSize = 14
      placeholder.fills = [{ type: 'SOLID', color: { r: 0.6, g: 0.6, b: 0.6 } }]
      input.appendChild(placeholder)
      placeholder.layoutSizingHorizontal = "FILL"

      group.appendChild(input)
      input.layoutSizingHorizontal = "FILL"

      form.appendChild(group)
      group.layoutSizingHorizontal = "FILL"
    }

    // Submit button
    const submitBtn = figma.createFrame()
    submitBtn.name = "Button/Submit"
    submitBtn.layoutMode = "HORIZONTAL"
    submitBtn.primaryAxisSizingMode = "AUTO"
    submitBtn.counterAxisSizingMode = "FIXED"
    submitBtn.resize(100, 44)
    submitBtn.primaryAxisAlignItems = "CENTER"
    submitBtn.counterAxisAlignItems = "CENTER"
    submitBtn.cornerRadius = 8
    submitBtn.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]

    const submitLabel = figma.createText()
    submitLabel.fontName = { family: "Inter", style: "Medium" }
    submitLabel.characters = "Submit"
    submitLabel.fontSize = 14
    submitLabel.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    submitBtn.appendChild(submitLabel)

    form.appendChild(submitBtn)
    submitBtn.layoutSizingHorizontal = "FILL"

    figma.currentPage.appendChild(form)
    figma.viewport.scrollAndZoomIntoView([form])
    return JSON.stringify({ success: true, id: form.id, name: form.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Form" }`

**Next**: Add validation states (error borders, helper text), or convert field groups into reusable components.

### Recipe: Data Table Row

**Goal**: Create a horizontal data table row with checkbox placeholder, name cell, status badge, and action button.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
    ])

    const row = figma.createFrame()
    row.name = "TableRow"
    row.layoutMode = "HORIZONTAL"
    row.primaryAxisSizingMode = "FIXED"
    row.counterAxisSizingMode = "FIXED"
    row.resize(600, 52)
    row.primaryAxisAlignItems = "MIN"
    row.counterAxisAlignItems = "CENTER"
    row.paddingTop = 0
    row.paddingBottom = 0
    row.paddingLeft = 16
    row.paddingRight = 16
    row.itemSpacing = 16
    row.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    row.strokes = [{ type: 'SOLID', color: { r: 0.878, g: 0.878, b: 0.878 } }]
    row.strokeWeight = 1
    row.strokeAlign = "INSIDE"
    row.strokesIncludedInLayout = false

    // Bottom-only border via individual stroke weights
    row.strokeTopWeight = 0
    row.strokeLeftWeight = 0
    row.strokeRightWeight = 0
    row.strokeBottomWeight = 1

    // Checkbox placeholder
    const checkbox = figma.createFrame()
    checkbox.name = "Checkbox"
    checkbox.resize(20, 20)
    checkbox.cornerRadius = 4
    checkbox.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    checkbox.strokes = [{ type: 'SOLID', color: { r: 0.8, g: 0.8, b: 0.8 } }]
    checkbox.strokeWeight = 1
    checkbox.strokeAlign = "INSIDE"
    row.appendChild(checkbox)
    checkbox.layoutSizingHorizontal = "FIXED"
    checkbox.layoutSizingVertical = "FIXED"

    // Name cell (FILL)
    const name = figma.createText()
    name.fontName = { family: "Inter", style: "Regular" }
    name.characters = "Jane Doe"
    name.fontSize = 14
    name.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
    row.appendChild(name)
    name.layoutSizingHorizontal = "FILL"

    // Status badge
    const badge = figma.createFrame()
    badge.name = "Badge/Active"
    badge.layoutMode = "HORIZONTAL"
    badge.primaryAxisSizingMode = "AUTO"
    badge.counterAxisSizingMode = "AUTO"
    badge.primaryAxisAlignItems = "CENTER"
    badge.counterAxisAlignItems = "CENTER"
    badge.paddingTop = 4
    badge.paddingBottom = 4
    badge.paddingLeft = 12
    badge.paddingRight = 12
    badge.cornerRadius = 12
    badge.fills = [{ type: 'SOLID', color: { r: 0.878, g: 0.957, b: 0.878 } }]

    const badgeLabel = figma.createText()
    badgeLabel.fontName = { family: "Inter", style: "Medium" }
    badgeLabel.characters = "Active"
    badgeLabel.fontSize = 12
    badgeLabel.fills = [{ type: 'SOLID', color: { r: 0.133, g: 0.545, b: 0.133 } }]
    badge.appendChild(badgeLabel)

    row.appendChild(badge)

    // Action button (text-only)
    const action = figma.createText()
    action.fontName = { family: "Inter", style: "Medium" }
    action.characters = "Edit"
    action.fontSize = 14
    action.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]
    row.appendChild(action)

    figma.currentPage.appendChild(row)
    figma.viewport.scrollAndZoomIntoView([row])
    return JSON.stringify({ success: true, id: row.id, name: row.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "TableRow" }`

**Next**: Duplicate the row for additional entries, add a header row with bold labels, or wrap rows in a vertical table container.

### Recipe: Empty State

**Goal**: Create a centered empty state with illustration placeholder, heading, description, and CTA button.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Bold" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
    ])

    const container = figma.createFrame()
    container.name = "EmptyState"
    container.layoutMode = "VERTICAL"
    container.primaryAxisSizingMode = "AUTO"
    container.counterAxisSizingMode = "FIXED"
    container.resize(400, 1)
    container.primaryAxisAlignItems = "CENTER"
    container.counterAxisAlignItems = "CENTER"
    container.paddingTop = 48
    container.paddingBottom = 48
    container.paddingLeft = 48
    container.paddingRight = 48
    container.itemSpacing = 16
    container.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    // Illustration placeholder
    const illustration = figma.createFrame()
    illustration.name = "Illustration"
    illustration.resize(120, 120)
    illustration.cornerRadius = 16
    illustration.fills = [{ type: 'SOLID', color: { r: 0.933, g: 0.933, b: 0.933 } }]
    container.appendChild(illustration)
    illustration.layoutSizingHorizontal = "FIXED"
    illustration.layoutSizingVertical = "FIXED"

    // Heading
    const heading = figma.createText()
    heading.fontName = { family: "Inter", style: "Bold" }
    heading.characters = "No items yet"
    heading.fontSize = 20
    heading.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
    heading.textAlignHorizontal = "CENTER"
    container.appendChild(heading)

    // Description
    const description = figma.createText()
    description.fontName = { family: "Inter", style: "Regular" }
    description.characters = "Get started by creating your first item. It only takes a moment."
    description.fontSize = 14
    description.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }]
    description.textAlignHorizontal = "CENTER"
    description.resize(280, 1)
    container.appendChild(description)
    description.layoutSizingHorizontal = "FIXED"
    description.textAutoResize = "HEIGHT"

    // CTA button
    const ctaBtn = figma.createFrame()
    ctaBtn.name = "Button/CTA"
    ctaBtn.layoutMode = "HORIZONTAL"
    ctaBtn.primaryAxisSizingMode = "AUTO"
    ctaBtn.counterAxisSizingMode = "FIXED"
    ctaBtn.resize(100, 40)
    ctaBtn.primaryAxisAlignItems = "CENTER"
    ctaBtn.counterAxisAlignItems = "CENTER"
    ctaBtn.paddingLeft = 24
    ctaBtn.paddingRight = 24
    ctaBtn.paddingTop = 0
    ctaBtn.paddingBottom = 0
    ctaBtn.cornerRadius = 8
    ctaBtn.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]

    const ctaLabel = figma.createText()
    ctaLabel.fontName = { family: "Inter", style: "Medium" }
    ctaLabel.characters = "Create Item"
    ctaLabel.fontSize = 14
    ctaLabel.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    ctaBtn.appendChild(ctaLabel)

    container.appendChild(ctaBtn)

    figma.currentPage.appendChild(container)
    figma.viewport.scrollAndZoomIntoView([container])
    return JSON.stringify({ success: true, id: container.id, name: container.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "EmptyState" }`

**Next**: Swap the illustration placeholder with an SVG import, add a secondary text link, or animate with a prototype entrance transition.

### Recipe: Modal with Scrim Overlay

**Goal**: Create a modal dialog centered on a semi-transparent scrim overlay. The scrim simulates the background darkening effect. The dialog is centered within the scrim using auto-layout alignment (`primaryAxisAlignItems = "CENTER"`, `counterAxisAlignItems = "CENTER"`).

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Bold" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
    ])

    // Scrim (full viewport overlay)
    const scrim = figma.createFrame()
    scrim.name = "Modal/Overlay"
    scrim.resize(1280, 800)
    scrim.fills = [{ type: 'SOLID', color: { r: 0, g: 0, b: 0 }, opacity: 0.5 }]
    scrim.layoutMode = "HORIZONTAL"
    scrim.primaryAxisAlignItems = "CENTER"
    scrim.counterAxisAlignItems = "CENTER"

    // Dialog surface
    const dialog = figma.createFrame()
    dialog.name = "Modal/Dialog"
    dialog.layoutMode = "VERTICAL"
    dialog.primaryAxisSizingMode = "AUTO"
    dialog.counterAxisSizingMode = "FIXED"
    dialog.resize(480, 1)
    dialog.paddingTop = 24
    dialog.paddingBottom = 24
    dialog.paddingLeft = 24
    dialog.paddingRight = 24
    dialog.itemSpacing = 16
    dialog.cornerRadius = 16
    dialog.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    dialog.effects = [
      {
        type: 'DROP_SHADOW',
        color: { r: 0, g: 0, b: 0, a: 0.25 },
        offset: { x: 0, y: 8 },
        radius: 24,
        visible: true,
        blendMode: 'NORMAL'
      }
    ]

    // Title
    const title = figma.createText()
    title.fontName = { family: "Inter", style: "Bold" }
    title.characters = "Confirm Action"
    title.fontSize = 20
    title.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
    dialog.appendChild(title)
    title.layoutSizingHorizontal = "FILL"

    // Body text
    const body = figma.createText()
    body.fontName = { family: "Inter", style: "Regular" }
    body.characters = "Are you sure you want to proceed? This action cannot be undone."
    body.fontSize = 14
    body.lineHeight = { value: 20, unit: "PIXELS" }
    body.fills = [{ type: 'SOLID', color: { r: 0.4, g: 0.4, b: 0.4 } }]
    dialog.appendChild(body)
    body.layoutSizingHorizontal = "FILL"

    // Action buttons row
    const actions = figma.createFrame()
    actions.name = "Actions"
    actions.layoutMode = "HORIZONTAL"
    actions.primaryAxisSizingMode = "AUTO"
    actions.counterAxisSizingMode = "AUTO"
    actions.primaryAxisAlignItems = "MAX"
    actions.counterAxisAlignItems = "CENTER"
    actions.itemSpacing = 12
    actions.fills = []

    // Cancel button
    const cancelBtn = figma.createFrame()
    cancelBtn.name = "Button/Cancel"
    cancelBtn.layoutMode = "HORIZONTAL"
    cancelBtn.primaryAxisSizingMode = "AUTO"
    cancelBtn.counterAxisSizingMode = "AUTO"
    cancelBtn.primaryAxisAlignItems = "CENTER"
    cancelBtn.counterAxisAlignItems = "CENTER"
    cancelBtn.paddingTop = 10
    cancelBtn.paddingBottom = 10
    cancelBtn.paddingLeft = 20
    cancelBtn.paddingRight = 20
    cancelBtn.cornerRadius = 8
    cancelBtn.fills = []
    cancelBtn.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.85, b: 0.85 } }]
    cancelBtn.strokeWeight = 1
    cancelBtn.strokeAlign = "INSIDE"
    const cancelLabel = figma.createText()
    cancelLabel.fontName = { family: "Inter", style: "Medium" }
    cancelLabel.characters = "Cancel"
    cancelLabel.fontSize = 14
    cancelLabel.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }]
    cancelBtn.appendChild(cancelLabel)
    actions.appendChild(cancelBtn)

    // Confirm button
    const confirmBtn = figma.createFrame()
    confirmBtn.name = "Button/Confirm"
    confirmBtn.layoutMode = "HORIZONTAL"
    confirmBtn.primaryAxisSizingMode = "AUTO"
    confirmBtn.counterAxisSizingMode = "AUTO"
    confirmBtn.primaryAxisAlignItems = "CENTER"
    confirmBtn.counterAxisAlignItems = "CENTER"
    confirmBtn.paddingTop = 10
    confirmBtn.paddingBottom = 10
    confirmBtn.paddingLeft = 20
    confirmBtn.paddingRight = 20
    confirmBtn.cornerRadius = 8
    confirmBtn.fills = [{ type: 'SOLID', color: { r: 0.702, g: 0.149, b: 0.118 } }]
    const confirmLabel = figma.createText()
    confirmLabel.fontName = { family: "Inter", style: "Medium" }
    confirmLabel.characters = "Delete"
    confirmLabel.fontSize = 14
    confirmLabel.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    confirmBtn.appendChild(confirmLabel)
    actions.appendChild(confirmBtn)

    dialog.appendChild(actions)
    actions.layoutSizingHorizontal = "FILL"

    scrim.appendChild(dialog)

    figma.currentPage.appendChild(scrim)
    figma.viewport.scrollAndZoomIntoView([scrim])
    return JSON.stringify({ success: true, scrimId: scrim.id, dialogId: dialog.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, scrimId: "...", dialogId: "..." }`

**Next**: Replace scrim with a prototype overlay trigger, or add form fields to the dialog body.

### Recipe: Dashboard Header

**Goal**: Create a horizontal dashboard header with title and subtitle on the left, action buttons pushed to the right using a spacer frame with `layoutGrow = 1`.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Bold" }),
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
      figma.loadFontAsync({ family: "Inter", style: "Medium" }),
    ])

    const header = figma.createFrame()
    header.name = "Dashboard/Header"
    header.layoutMode = "HORIZONTAL"
    header.primaryAxisSizingMode = "FIXED"
    header.counterAxisSizingMode = "AUTO"
    header.resize(1024, 1)
    header.primaryAxisAlignItems = "MIN"
    header.counterAxisAlignItems = "CENTER"
    header.paddingTop = 24
    header.paddingBottom = 24
    header.paddingLeft = 32
    header.paddingRight = 32
    header.fills = []

    // Left group: title + subtitle
    const leftGroup = figma.createFrame()
    leftGroup.name = "Title-Group"
    leftGroup.layoutMode = "VERTICAL"
    leftGroup.primaryAxisSizingMode = "AUTO"
    leftGroup.counterAxisSizingMode = "AUTO"
    leftGroup.itemSpacing = 4
    leftGroup.fills = []

    const title = figma.createText()
    title.fontName = { family: "Inter", style: "Bold" }
    title.characters = "Welcome back, Alex"
    title.fontSize = 24
    title.lineHeight = { value: 32, unit: "PIXELS" }
    title.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.1 } }]
    leftGroup.appendChild(title)

    const subtitle = figma.createText()
    subtitle.fontName = { family: "Inter", style: "Regular" }
    subtitle.characters = "Monday, February 16, 2026"
    subtitle.fontSize = 14
    subtitle.fills = [{ type: 'SOLID', color: { r: 0.5, g: 0.5, b: 0.5 } }]
    leftGroup.appendChild(subtitle)

    header.appendChild(leftGroup)

    // Spacer — pushes right group to the end
    const spacer = figma.createFrame()
    spacer.name = "Spacer"
    spacer.resize(1, 1)
    spacer.fills = []
    header.appendChild(spacer)
    spacer.layoutGrow = 1

    // Right group: action buttons
    const rightGroup = figma.createFrame()
    rightGroup.name = "Actions"
    rightGroup.layoutMode = "HORIZONTAL"
    rightGroup.primaryAxisSizingMode = "AUTO"
    rightGroup.counterAxisSizingMode = "AUTO"
    rightGroup.itemSpacing = 12
    rightGroup.fills = []

    // Export button (outlined)
    const exportBtn = figma.createFrame()
    exportBtn.name = "Button/Export"
    exportBtn.layoutMode = "HORIZONTAL"
    exportBtn.primaryAxisSizingMode = "AUTO"
    exportBtn.counterAxisSizingMode = "AUTO"
    exportBtn.primaryAxisAlignItems = "CENTER"
    exportBtn.counterAxisAlignItems = "CENTER"
    exportBtn.paddingTop = 8
    exportBtn.paddingBottom = 8
    exportBtn.paddingLeft = 16
    exportBtn.paddingRight = 16
    exportBtn.cornerRadius = 6
    exportBtn.fills = []
    exportBtn.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.85, b: 0.85 } }]
    exportBtn.strokeWeight = 1
    exportBtn.strokeAlign = "INSIDE"
    const exportLabel = figma.createText()
    exportLabel.fontName = { family: "Inter", style: "Medium" }
    exportLabel.characters = "Export"
    exportLabel.fontSize = 14
    exportLabel.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }]
    exportBtn.appendChild(exportLabel)
    rightGroup.appendChild(exportBtn)

    // Add New button (filled)
    const addBtn = figma.createFrame()
    addBtn.name = "Button/AddNew"
    addBtn.layoutMode = "HORIZONTAL"
    addBtn.primaryAxisSizingMode = "AUTO"
    addBtn.counterAxisSizingMode = "AUTO"
    addBtn.primaryAxisAlignItems = "CENTER"
    addBtn.counterAxisAlignItems = "CENTER"
    addBtn.paddingTop = 8
    addBtn.paddingBottom = 8
    addBtn.paddingLeft = 16
    addBtn.paddingRight = 16
    addBtn.cornerRadius = 6
    addBtn.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]
    const addLabel = figma.createText()
    addLabel.fontName = { family: "Inter", style: "Medium" }
    addLabel.characters = "Add New"
    addLabel.fontSize = 14
    addLabel.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    addBtn.appendChild(addLabel)
    rightGroup.appendChild(addBtn)

    header.appendChild(rightGroup)

    figma.currentPage.appendChild(header)
    figma.viewport.scrollAndZoomIntoView([header])
    return JSON.stringify({ success: true, id: header.id, name: header.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Dashboard/Header" }`

**Key pattern**: The transparent spacer frame with `layoutGrow = 1` pushes the right group to the far end of the header. This is the standard technique for left-right split layouts in Figma auto-layout.

**Next**: Add a date picker or search bar to the right group, or place inside a page shell recipe.

### Recipe: Component Variant Set

**Goal**: Create multiple component variants and combine them into a component set. There is no `figma.createComponentSet()` -- use `figma.combineAsVariants()` instead.

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Medium" })

    const variants = []
    const states = ["Default", "Hover", "Pressed", "Disabled"]

    for (const state of states) {
      const btn = figma.createComponent()
      btn.name = `Size=Medium, State=${state}`
      btn.layoutMode = "HORIZONTAL"
      btn.primaryAxisSizingMode = "AUTO"
      btn.counterAxisSizingMode = "AUTO"
      btn.primaryAxisAlignItems = "CENTER"
      btn.counterAxisAlignItems = "CENTER"
      btn.paddingTop = 10
      btn.paddingBottom = 10
      btn.paddingLeft = 24
      btn.paddingRight = 24
      btn.cornerRadius = 6

      const opacity = state === "Disabled" ? 0.38 : 1
      btn.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 }, opacity }]

      const label = figma.createText()
      label.fontName = { family: "Inter", style: "Medium" }
      label.characters = "Button"
      label.fontSize = 14
      label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
      btn.appendChild(label)

      variants.push(btn)
    }

    const buttonSet = figma.combineAsVariants(variants, figma.currentPage)
    buttonSet.name = "Button"

    figma.viewport.scrollAndZoomIntoView([buttonSet])
    return JSON.stringify({
      success: true,
      setId: buttonSet.id,
      variants: variants.map(v => ({ id: v.id, name: v.name }))
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, setId: "...", variants: [...] }`

**Next**: Use `figma_arrange_component_set` to auto-arrange the variant grid, or add more property dimensions (Size=Small, Size=Large).

---

## Composition Recipes

### Pattern: Shell Injection (Multi-Region Pages)

For complex pages (dashboards, settings, admin panels), create the page shell with named slot frames first, then inject content into the slots in subsequent calls. This separates layout architecture from content population.

**Step 1 — Create shell with empty slots**:

```javascript
(async () => {
  try {
    const shell = figma.createFrame()
    shell.name = "Page/Dashboard"
    shell.layoutMode = "HORIZONTAL"
    shell.resize(1280, 800)
    shell.layoutSizingHorizontal = "FIXED"
    shell.layoutSizingVertical = "FIXED"
    shell.clipsContent = true
    shell.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    const sidebarSlot = figma.createFrame()
    sidebarSlot.name = "Slot/Sidebar"
    sidebarSlot.resize(240, 1)
    sidebarSlot.layoutMode = "VERTICAL"
    sidebarSlot.fills = []
    shell.appendChild(sidebarSlot)
    sidebarSlot.layoutSizingHorizontal = "FIXED"
    sidebarSlot.layoutSizingVertical = "FILL"

    const contentSlot = figma.createFrame()
    contentSlot.name = "Slot/Content"
    contentSlot.layoutMode = "VERTICAL"
    contentSlot.fills = []
    shell.appendChild(contentSlot)
    contentSlot.layoutSizingHorizontal = "FILL"
    contentSlot.layoutSizingVertical = "FILL"

    figma.currentPage.appendChild(shell)
    return JSON.stringify({
      success: true,
      shellId: shell.id,
      sidebarSlotId: sidebarSlot.id,
      contentSlotId: contentSlot.id,
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Step 2 — Inject content into slots** (using IDs from Step 1):

```javascript
(async () => {
  try {
    const slot = await figma.getNodeByIdAsync("SIDEBAR_SLOT_ID")
    if (!slot) return JSON.stringify({ success: false, error: "Slot not found" })
    // ... build sidebar content, then:
    slot.appendChild(sidebarContent)
    sidebarContent.layoutSizingHorizontal = "FILL"
    sidebarContent.layoutSizingVertical = "FILL"
    return JSON.stringify({ success: true })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Key principle**: Slots use `layoutSizingHorizontal/Vertical = "FILL"` so injected content stretches to fill the allocated region. The shell defines proportions; recipes provide content.

### Recipe: Compose Library Components into Layout

**Goal**: Search for existing library components, instantiate them, create a container, and reparent instances into the layout.

This recipe spans 4 sequential tool calls -- not a single `figma_execute`.

**Step 1** -- Search for components:

```
figma_search_components("Button")
```

Returns component keys and variant properties.

**Step 2** -- Instantiate the component:

```
figma_instantiate_component(componentKey, { "State": "Default", "Size": "Medium" })
```

Returns the instance node ID.

**Step 3** -- Create a container via `figma_execute`:

```javascript
(async () => {
  try {
    const container = figma.createFrame()
    container.name = "Button-Row"
    container.layoutMode = "HORIZONTAL"
    container.primaryAxisSizingMode = "AUTO"
    container.counterAxisSizingMode = "AUTO"
    container.itemSpacing = 16
    container.paddingTop = 16
    container.paddingBottom = 16
    container.paddingLeft = 16
    container.paddingRight = 16
    container.fills = []

    figma.currentPage.appendChild(container)
    return JSON.stringify({ success: true, id: container.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Step 4** -- Reparent instances into the container via `figma_execute`:

```javascript
(async () => {
  try {
    const container = await figma.getNodeByIdAsync("CONTAINER_ID")
    const instance = await figma.getNodeByIdAsync("INSTANCE_ID")
    if (!container || !instance) {
      return JSON.stringify({ success: false, error: "Node not found" })
    }
    container.appendChild(instance)
    return JSON.stringify({ success: true, containerId: container.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Next**: Add more instances, adjust spacing, or take a screenshot to validate.

### Recipe: Design System Bootstrap

**Goal**: Set up design tokens, create components that reference those tokens, and document everything.

This recipe spans 3 phases using multiple tools.

**Phase 1** -- Create tokens with `figma_setup_design_tokens`:

```
figma_setup_design_tokens({
  collections: [{
    name: "Brand Colors",
    modes: ["Light", "Dark"],
    variables: [
      { name: "primary", type: "COLOR", values: { "Light": "#6750A4", "Dark": "#D0BCFF" } },
      { name: "on-primary", type: "COLOR", values: { "Light": "#FFFFFF", "Dark": "#381E72" } },
      { name: "surface", type: "COLOR", values: { "Light": "#FFFBFE", "Dark": "#1C1B1F" } }
    ]
  }]
})
```

**Phase 2** -- Create components using tokens via `figma_execute`:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Roboto", style: "Medium" })

    const btn = figma.createComponent()
    btn.name = "Button/Filled"
    btn.layoutMode = "HORIZONTAL"
    btn.primaryAxisSizingMode = "AUTO"
    btn.counterAxisSizingMode = "AUTO"
    btn.primaryAxisAlignItems = "CENTER"
    btn.counterAxisAlignItems = "CENTER"
    btn.paddingTop = 10
    btn.paddingBottom = 10
    btn.paddingLeft = 24
    btn.paddingRight = 24
    btn.cornerRadius = 20
    btn.fills = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]

    const label = figma.createText()
    label.fontName = { family: "Roboto", style: "Medium" }
    label.characters = "Button"
    label.fontSize = 14
    label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    btn.appendChild(label)

    figma.currentPage.appendChild(btn)
    return JSON.stringify({ success: true, id: btn.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Phase 3** -- Document with `figma_set_description`:

```
figma_set_description(nodeId, "Filled button component. Uses Primary color token for background, On Primary for label. Label Large typography (Roboto Medium 14px).")
```

**Next**: Run `figma_audit_design_system` to validate token coverage and component documentation.

> For Material Design 3 component recipes (M3 Button, Card, Top App Bar, TextField, Bottom Navigation, Dialog, Snackbar, Elevation Shadows), see `recipes-m3.md`.

---

## Advanced Recipes

### Recipe: Variable Binding to Nodes

**Goal**: Bind design token variables to node properties so colors and spacing update automatically when modes change (e.g., Light to Dark).

**Code**:

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: "Inter", style: "Regular" })

    // Create a variable collection with Light and Dark modes
    const collection = figma.variables.createVariableCollection("Brand")
    collection.renameMode(collection.modes[0].modeId, "Light")
    const darkModeId = collection.addMode("Dark")

    // Create color variables
    const primaryColor = figma.variables.createVariable("primary", collection, "COLOR")
    primaryColor.setValueForMode(collection.modes[0].modeId, { r: 0.404, g: 0.314, b: 0.643 })
    primaryColor.setValueForMode(darkModeId, { r: 0.816, g: 0.737, b: 1.0 })

    const onPrimaryColor = figma.variables.createVariable("on-primary", collection, "COLOR")
    onPrimaryColor.setValueForMode(collection.modes[0].modeId, { r: 1, g: 1, b: 1 })
    onPrimaryColor.setValueForMode(darkModeId, { r: 0.220, g: 0.118, b: 0.447 })

    // Create spacing variable
    const spacingMd = figma.variables.createVariable("spacing-md", collection, "FLOAT")
    spacingMd.setValueForMode(collection.modes[0].modeId, 16)
    spacingMd.setValueForMode(darkModeId, 16)

    // Create a button and bind variables to it
    const btn = figma.createFrame()
    btn.name = "Token-Bound-Button"
    btn.layoutMode = "HORIZONTAL"
    btn.primaryAxisSizingMode = "AUTO"
    btn.counterAxisSizingMode = "AUTO"
    btn.primaryAxisAlignItems = "CENTER"
    btn.counterAxisAlignItems = "CENTER"
    btn.cornerRadius = 20

    // Bind COLOR variable to fills
    const boundFill = figma.variables.setBoundVariableForPaint(
      { type: 'SOLID', color: { r: 0, g: 0, b: 0 } },
      'color',
      primaryColor
    )
    btn.fills = [boundFill]

    // Bind FLOAT variable to padding
    btn.setBoundVariable('paddingTop', spacingMd)
    btn.setBoundVariable('paddingBottom', spacingMd)
    btn.setBoundVariable('paddingLeft', spacingMd)
    btn.setBoundVariable('paddingRight', spacingMd)

    // Add label with bound text color
    const label = figma.createText()
    label.fontName = { family: "Inter", style: "Regular" }
    label.characters = "Bound Button"
    label.fontSize = 14
    const boundTextFill = figma.variables.setBoundVariableForPaint(
      { type: 'SOLID', color: { r: 0, g: 0, b: 0 } },
      'color',
      onPrimaryColor
    )
    label.fills = [boundTextFill]
    btn.appendChild(label)

    figma.currentPage.appendChild(btn)
    return JSON.stringify({
      success: true,
      buttonId: btn.id,
      collectionId: collection.id,
      variables: {
        primary: primaryColor.id,
        onPrimary: onPrimaryColor.id,
        spacingMd: spacingMd.id
      }
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, buttonId: "...", collectionId: "...", variables: {...} }`

**Next**: Switch mode with `frame.setExplicitVariableModeForCollection(collection, darkModeId)` to see colors update automatically.

### Recipe: SVG Import and Styling

**Goal**: Import an SVG string as a Figma node and apply custom fills.

**Code**:

```javascript
(async () => {
  try {
    const svgString = '<svg width="24" height="24" viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

    const svgNode = figma.createNodeFromSvg(svgString)
    svgNode.name = "Icon/Layers"
    svgNode.resize(24, 24)

    // Override fills on all vector children
    for (const child of svgNode.findAll()) {
      if ('strokes' in child && child.strokes.length > 0) {
        child.strokes = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]
      }
      if ('fills' in child && child.fills.length > 0) {
        child.fills = [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }]
      }
    }

    figma.currentPage.appendChild(svgNode)
    return JSON.stringify({ success: true, id: svgNode.id, name: svgNode.name })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "...", name: "Icon/Layers" }`

**Next**: Resize for different icon sizes (16, 20, 24, 32px) or convert to a component with `figma.createComponentFromNode(svgNode)`.

### Recipe: Mixed-Style Rich Text

**Goal**: Create a text node with multiple styles -- bold title, colored highlight, and underlined link -- using range functions.

**Code**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: "Inter", style: "Regular" }),
      figma.loadFontAsync({ family: "Inter", style: "Bold" }),
    ])

    const text = figma.createText()
    text.fontName = { family: "Inter", style: "Regular" }
    text.characters = "Welcome to Figma! Learn more about design tokens here."
    text.fontSize = 16
    text.lineHeight = { value: 24, unit: "PIXELS" }

    // "Welcome to Figma!" in bold (chars 0-18)
    text.setRangeFontName(0, 18, { family: "Inter", style: "Bold" })
    text.setRangeFontSize(0, 18, 20)

    // "design tokens" in accent color (chars 40-53)
    text.setRangeFills(40, 53, [{ type: 'SOLID', color: { r: 0.404, g: 0.314, b: 0.643 } }])

    // "here" underlined with hyperlink (chars 54-58... adjust based on actual text)
    const hereStart = text.characters.indexOf("here")
    const hereEnd = hereStart + 4
    text.setRangeTextDecoration(hereStart, hereEnd, "UNDERLINE")
    text.setRangeFills(hereStart, hereEnd, [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }])
    text.setRangeHyperlink(hereStart, hereEnd, { type: "URL", value: "https://help.figma.com/hc/en-us/articles/15339657135383-Guide-to-variables-in-Figma" })

    figma.currentPage.appendChild(text)
    return JSON.stringify({ success: true, id: text.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, id: "..." }`

**Next**: Read styled segments with `text.getStyledTextSegments(['fontName', 'fontSize', 'fills'])` to inspect the applied styles.

---

## Full Page Composition

### Recipe: Settings Page (End-to-End Multi-Call)

**Goal**: Build a complete settings page by chaining 4 sequential `figma_execute` calls connected by returned node IDs. Demonstrates the composition pattern: page shell → sidebar → content area with form → footer.

This recipe spans **4 separate `figma_execute` calls**. Each call returns node IDs consumed by subsequent calls.

**Call 1 — Page Shell with Sidebar + Content Columns**:

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: 'Inter', style: 'Regular' }),
      figma.loadFontAsync({ family: 'Inter', style: 'Medium' }),
      figma.loadFontAsync({ family: 'Inter', style: 'Bold' }),
    ])

    // Page shell: horizontal split
    const page = figma.createFrame()
    page.name = "Page/Settings"
    page.layoutMode = "HORIZONTAL"
    page.layoutSizingHorizontal = "FIXED"
    page.layoutSizingVertical = "FIXED"
    page.resize(1280, 800)
    page.itemSpacing = 0
    page.clipsContent = true
    page.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]

    // Sidebar
    const sidebar = figma.createFrame()
    sidebar.name = "Sidebar"
    sidebar.layoutMode = "VERTICAL"
    sidebar.resize(240, 1)
    sidebar.paddingTop = 24
    sidebar.paddingBottom = 24
    sidebar.paddingLeft = 16
    sidebar.paddingRight = 16
    sidebar.itemSpacing = 4
    sidebar.fills = [{ type: 'SOLID', color: { r: 0.969, g: 0.949, b: 0.980 } }] // M3 SurfaceVariant

    // Sidebar nav items
    const navItems = ["General", "Profile", "Notifications", "Security", "Billing"]
    for (let i = 0; i < navItems.length; i++) {
      const item = figma.createFrame()
      item.name = `Nav/${navItems[i]}`
      item.layoutMode = "HORIZONTAL"
      item.counterAxisSizingMode = "AUTO"
      item.primaryAxisAlignItems = "MIN"
      item.counterAxisAlignItems = "CENTER"
      item.paddingTop = 10
      item.paddingBottom = 10
      item.paddingLeft = 12
      item.paddingRight = 12
      item.cornerRadius = 8
      item.fills = i === 0
        ? [{ type: 'SOLID', color: { r: 0.910, g: 0.871, b: 0.973 } }] // M3 SecondaryContainer
        : []

      const label = figma.createText()
      label.fontName = { family: "Inter", style: i === 0 ? "Medium" : "Regular" }
      label.characters = navItems[i]
      label.fontSize = 14
      label.lineHeight = { value: 20, unit: "PIXELS" }
      label.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }] // M3 OnSurface
      item.appendChild(label)
      sidebar.appendChild(item)
      item.layoutSizingHorizontal = "FILL"
    }
    page.appendChild(sidebar)
    sidebar.layoutSizingHorizontal = "FIXED"
    sidebar.layoutSizingVertical = "FILL"

    // Content area (vertical: header + body + footer)
    const content = figma.createFrame()
    content.name = "Content"
    content.layoutMode = "VERTICAL"
    content.itemSpacing = 0
    content.fills = []
    page.appendChild(content)
    content.layoutSizingHorizontal = "FILL"
    content.layoutSizingVertical = "FILL"

    figma.currentPage.appendChild(page)
    figma.currentPage.selection = [page]
    figma.viewport.scrollAndZoomIntoView([page])
    return JSON.stringify({
      success: true,
      pageId: page.id,
      sidebarId: sidebar.id,
      contentId: content.id,
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Important**: In Calls 2-4 below, replace the literal `"CONTENT_ID"` string with the actual `contentId` value returned by Call 1.

**Call 2 — Content Header** (uses `contentId` from Call 1):

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: 'Inter', style: 'Bold' })
    const content = await figma.getNodeByIdAsync("CONTENT_ID")
    if (!content) return JSON.stringify({ success: false, error: "Content not found" })

    const header = figma.createFrame()
    header.name = "Header"
    header.layoutMode = "HORIZONTAL"
    header.counterAxisSizingMode = "AUTO"
    header.primaryAxisAlignItems = "SPACE_BETWEEN"
    header.counterAxisAlignItems = "CENTER"
    header.paddingTop = 24
    header.paddingBottom = 24
    header.paddingLeft = 32
    header.paddingRight = 32
    header.fills = []
    header.strokes = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    header.strokeWeight = 1
    header.strokeAlign = "INSIDE"
    header.strokeBottomWeight = 1
    header.strokeTopWeight = 0
    header.strokeLeftWeight = 0
    header.strokeRightWeight = 0

    const title = figma.createText()
    title.fontName = { family: "Inter", style: "Bold" }
    title.characters = "General Settings"
    title.fontSize = 24
    title.lineHeight = { value: 32, unit: "PIXELS" }
    title.fills = [{ type: 'SOLID', color: { r: 0.110, g: 0.106, b: 0.122 } }] // M3 OnSurface
    header.appendChild(title)

    content.insertChild(0, header)
    header.layoutSizingHorizontal = "FILL"
    return JSON.stringify({ success: true, headerId: header.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Call 3 — Form Body** (uses `contentId` from Call 1):

```javascript
(async () => {
  try {
    await Promise.all([
      figma.loadFontAsync({ family: 'Inter', style: 'Regular' }),
      figma.loadFontAsync({ family: 'Inter', style: 'Medium' }),
    ])
    const content = await figma.getNodeByIdAsync("CONTENT_ID")
    if (!content) return JSON.stringify({ success: false, error: "Content not found" })

    const body = figma.createFrame()
    body.name = "Form-Body"
    body.layoutMode = "VERTICAL"
    body.paddingTop = 32
    body.paddingBottom = 32
    body.paddingLeft = 32
    body.paddingRight = 32
    body.itemSpacing = 24
    body.fills = []

    const fields = [
      { label: "Display Name", placeholder: "Enter your name" },
      { label: "Email Address", placeholder: "you@example.com" },
      { label: "Language", placeholder: "English (US)" },
      { label: "Timezone", placeholder: "UTC+01:00 (Rome)" },
    ]

    for (const f of fields) {
      const group = figma.createFrame()
      group.name = `Field/${f.label}`
      group.layoutMode = "VERTICAL"
      group.counterAxisSizingMode = "AUTO"
      group.itemSpacing = 6
      group.fills = []

      const label = figma.createText()
      label.fontName = { family: "Inter", style: "Medium" }
      label.characters = f.label
      label.fontSize = 14
      label.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }]
      group.appendChild(label)

      const input = figma.createFrame()
      input.name = "Input"
      input.layoutMode = "HORIZONTAL"
      input.counterAxisSizingMode = "FIXED"
      input.resize(100, 44)
      input.primaryAxisAlignItems = "MIN"
      input.counterAxisAlignItems = "CENTER"
      input.paddingLeft = 12
      input.paddingRight = 12
      input.cornerRadius = 8
      input.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
      input.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.85, b: 0.85 } }]
      input.strokeWeight = 1
      input.strokeAlign = "INSIDE"

      const ph = figma.createText()
      ph.fontName = { family: "Inter", style: "Regular" }
      ph.characters = f.placeholder
      ph.fontSize = 14
      ph.fills = [{ type: 'SOLID', color: { r: 0.6, g: 0.6, b: 0.6 } }]
      input.appendChild(ph)
      ph.layoutSizingHorizontal = "FILL"

      group.appendChild(input)
      input.layoutSizingHorizontal = "FILL"
      body.appendChild(group)
      group.layoutSizingHorizontal = "FILL"
    }

    // Insert body after header (index 1)
    content.insertChild(1, body)
    body.layoutSizingHorizontal = "FILL"
    body.layoutSizingVertical = "FILL"
    return JSON.stringify({ success: true, bodyId: body.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Call 4 — Sticky Footer** (uses `contentId` from Call 1):

```javascript
(async () => {
  try {
    await figma.loadFontAsync({ family: 'Inter', style: 'Medium' })
    const content = await figma.getNodeByIdAsync("CONTENT_ID")
    if (!content) return JSON.stringify({ success: false, error: "Content not found" })

    const footer = figma.createFrame()
    footer.name = "Footer"
    footer.layoutMode = "HORIZONTAL"
    footer.counterAxisSizingMode = "AUTO"
    footer.primaryAxisAlignItems = "MAX"
    footer.counterAxisAlignItems = "CENTER"
    footer.paddingTop = 16
    footer.paddingBottom = 16
    footer.paddingLeft = 32
    footer.paddingRight = 32
    footer.itemSpacing = 12
    footer.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    footer.strokes = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 } }]
    footer.strokeWeight = 1
    footer.strokeAlign = "INSIDE"
    footer.strokeTopWeight = 1
    footer.strokeBottomWeight = 0
    footer.strokeLeftWeight = 0
    footer.strokeRightWeight = 0

    // Cancel button (outlined)
    const cancelBtn = figma.createFrame()
    cancelBtn.name = "Button/Cancel"
    cancelBtn.layoutMode = "HORIZONTAL"
    cancelBtn.primaryAxisSizingMode = "AUTO"
    cancelBtn.counterAxisSizingMode = "AUTO"
    cancelBtn.primaryAxisAlignItems = "CENTER"
    cancelBtn.counterAxisAlignItems = "CENTER"
    cancelBtn.paddingTop = 10
    cancelBtn.paddingBottom = 10
    cancelBtn.paddingLeft = 20
    cancelBtn.paddingRight = 20
    cancelBtn.cornerRadius = 8
    cancelBtn.fills = []
    cancelBtn.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.85, b: 0.85 } }]
    cancelBtn.strokeWeight = 1
    cancelBtn.strokeAlign = "INSIDE"
    const cancelLabel = figma.createText()
    cancelLabel.fontName = { family: "Inter", style: "Medium" }
    cancelLabel.characters = "Cancel"
    cancelLabel.fontSize = 14
    cancelLabel.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.2, b: 0.2 } }]
    cancelBtn.appendChild(cancelLabel)
    footer.appendChild(cancelBtn)

    // Save button (filled primary)
    const saveBtn = figma.createFrame()
    saveBtn.name = "Button/Save"
    saveBtn.layoutMode = "HORIZONTAL"
    saveBtn.primaryAxisSizingMode = "AUTO"
    saveBtn.counterAxisSizingMode = "AUTO"
    saveBtn.primaryAxisAlignItems = "CENTER"
    saveBtn.counterAxisAlignItems = "CENTER"
    saveBtn.paddingTop = 10
    saveBtn.paddingBottom = 10
    saveBtn.paddingLeft = 20
    saveBtn.paddingRight = 20
    saveBtn.cornerRadius = 8
    saveBtn.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.4, b: 1 } }]
    const saveLabel = figma.createText()
    saveLabel.fontName = { family: "Inter", style: "Medium" }
    saveLabel.characters = "Save Changes"
    saveLabel.fontSize = 14
    saveLabel.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]
    saveBtn.appendChild(saveLabel)
    footer.appendChild(saveBtn)

    // Append footer as last child of content
    content.appendChild(footer)
    footer.layoutSizingHorizontal = "FILL"
    return JSON.stringify({ success: true, footerId: footer.id })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns** (combined across all 4 calls):
- `pageId` — the outer 1280x800 page frame
- `sidebarId` — sidebar with navigation items
- `contentId` — content column (header + body + footer)
- `headerId`, `bodyId`, `footerId` — individual content sections

**Key composition patterns demonstrated:**
1. **ID tracking**: Call 1 returns `contentId`, used by Calls 2-4 via `getNodeByIdAsync`
2. **Insertion order**: `insertChild(0, header)` for header, `insertChild(1, body)` for body, `appendChild(footer)` for footer
3. **FILL sizing**: Sidebar FIXED width + Content FILL = sidebar-content split
4. **Nested layouts**: Page (HORIZONTAL) → Content (VERTICAL) → Form Body (VERTICAL) → Field groups (VERTICAL)

**Next**: Validate with `figma_capture_screenshot(pageId)`. Replace placeholder inputs with interactive components via `figma_instantiate_component`.

---

## Chaining Patterns

### Component Composition Pattern

**Flow**: search library --> find component --> instantiate with variants --> arrange in auto-layout container --> validate with screenshot

| Step | Tool | Action |
|------|------|--------|
| 1 | `figma_search_components` | Search for the target component by name |
| 2 | `figma_instantiate_component` | Instantiate with desired variant properties |
| 3 | `figma_execute` | Create an auto-layout container frame |
| 4 | `figma_execute` | Reparent instance(s) into the container |
| 5 | `figma_capture_screenshot` | Validate the result visually |

### Iterative Refinement Pattern

**Flow**: create design --> screenshot --> analyze --> fix --> screenshot --> confirm

| Step | Tool | Action |
|------|------|--------|
| 1 | `figma_execute` | Create or modify the design |
| 2 | `figma_capture_screenshot` | Capture current state |
| 3 | (AI analysis) | Examine screenshot for correctness |
| 4 | `figma_execute` | Apply fixes based on analysis |
| 5 | `figma_capture_screenshot` | Verify the fix |
| 6 | (AI analysis) | Confirm or loop back to step 4 |

Limit to a maximum of 3 refinement cycles. If the design is not correct after 3 iterations, reassess the approach rather than continuing to patch.

### Design System Bootstrap Pattern

**Flow**: tokens --> components --> documentation --> audit

| Step | Tool | Action |
|------|------|--------|
| 1 | `figma_setup_design_tokens` | Create color, spacing, and typography token collections |
| 2 | `figma_execute` | Build components using token values |
| 3 | `figma_set_description` | Document each component with usage notes |
| 4 | `figma_audit_design_system` | Validate token coverage and naming consistency |
| 5 | `ds_dashboard_refresh` | Update the Design System Dashboard |

---

*Recipes are designed to be composed. A typical screen build chains Page Container + Top App Bar + content cards + bottom navigation, each as a separate `figma_execute` call connected by returned node IDs.*
