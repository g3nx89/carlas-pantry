# Recipes — Component Patterns

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> **Prerequisite**: Load `recipes-foundation.md` first — all component recipes assume familiarity with the IIFE wrapper, font preloading, and node reference patterns.
>
> For Plugin API details, see `plugin-api.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.
> For foundation patterns and layouts, see `recipes-foundation.md`. For composition and advanced patterns, see `recipes-advanced.md`. For M3 component recipes, see `recipes-m3.md`.

## Recipe Index

| Section | Recipe | Line |
|---------|--------|-----:|
| **Components** | Card with Auto-Layout | 34 |
| | Button (Horizontal, Hug-Both) | 100 |
| | Input Field (Outlined) | 145 |
| | Toast Notification | 194 |
| | Top Navigation Bar | 260 |
| | Sidebar Navigation | 333 |
| | Form Layout | 421 |
| | Data Table Row | 537 |
| | Empty State | 643 |
| | Modal with Scrim Overlay | 742 |
| | Dashboard Header | 886 |
| | Component Variant Set | 1022 |
| **Handoff Patterns** | GROUP→FRAME Conversion | 1088 |
| | Componentize from Clone | 1233 |
| | COMPONENT_SET Variant Instantiation | 1323 |

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

## Handoff Patterns

> These recipes address operational patterns discovered during Draft-to-Handoff production sessions. They solve structural issues specific to screen transfer workflows.

### Recipe: GROUP→FRAME Conversion

**Goal**: Convert a GROUP node to a transparent FRAME so that constraints, reactions, and auto-layout can be applied. GROUP nodes do not support the `constraints` property — the Plugin API throws `"object is not extensible"` or silently ignores the assignment.

**When to use**: After cloning a Draft screen, 30-60% of direct children are typically GROUPs. ALL must be converted before setting constraints.

**Critical rule**: DO NOT call `group.remove()` after moving children. When all children are moved out, Figma auto-deletes the GROUP. Explicit `remove()` throws `"The node with id X does not exist"`, and any code after it in the same try-block is silently skipped.

**Code**:

```javascript
// figma_execute — convert a single GROUP to FRAME
(async () => {
  try {
    const group = await figma.getNodeByIdAsync("GROUP_ID_HERE");
    if (!group || group.type !== "GROUP") {
      return JSON.stringify({ error: "Not a GROUP node" });
    }

    const parent = group.parent;
    const gx = group.x, gy = group.y;
    const gw = group.width, gh = group.height;
    const idx = parent.children.indexOf(group);

    // Create transparent replacement FRAME
    const frame = figma.createFrame();
    frame.name = "SEMANTIC_NAME_HERE";  // e.g., "hero_text", "star_badge"
    frame.fills = [];                    // transparent
    frame.clipsContent = false;
    frame.resize(gw, gh);

    // Move children — coordinates are absolute in GROUP, must convert to relative
    const children = [...group.children];  // snapshot array before mutation
    for (const child of children) {
      const relX = child.x - gx;
      const relY = child.y - gy;
      frame.appendChild(child);
      child.x = relX;
      child.y = relY;
    }
    // GROUP auto-deletes when empty — DO NOT call group.remove()

    // Insert at same z-index and position
    parent.insertChild(idx, frame);
    frame.x = gx;
    frame.y = gy;

    // Now constraints CAN be set
    frame.constraints = { horizontal: "SCALE", vertical: "MIN" };

    return JSON.stringify({
      success: true,
      id: frame.id,
      name: frame.name,
      childCount: frame.children.length
    });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Batch version** (for converting all GROUPs in a screen):

```javascript
// figma_execute — batch GROUP→FRAME conversion for all direct children
(async () => {
  try {
    const screen = await figma.getNodeByIdAsync("SCREEN_ID_HERE");
    if (!screen) return JSON.stringify({ error: "Screen not found" });

    const results = [];
    // Snapshot children — iterating while mutating causes issues
    const children = [...screen.children];

    for (const child of children) {
      if (child.type !== "GROUP") {
        results.push({ id: child.id, name: child.name, status: "not_group" });
        continue;
      }

      const gx = child.x, gy = child.y;
      const gw = child.width, gh = child.height;
      const idx = screen.children.indexOf(child);
      const oldName = child.name;

      const frame = figma.createFrame();
      frame.name = oldName.startsWith("Group ")
        ? `frame_${idx}` // placeholder — rename semantically later
        : oldName;
      frame.fills = [];
      frame.clipsContent = false;
      frame.resize(gw, gh);

      const groupChildren = [...child.children];
      for (const gc of groupChildren) {
        const relX = gc.x - gx;
        const relY = gc.y - gy;
        frame.appendChild(gc);
        gc.x = relX;
        gc.y = relY;
      }
      // GROUP auto-deletes — no remove() call

      screen.insertChild(idx, frame);
      frame.x = gx;
      frame.y = gy;

      results.push({
        id: frame.id,
        name: frame.name,
        oldName: oldName,
        children: frame.children.length,
        status: "converted"
      });
    }

    return JSON.stringify({ success: true, converted: results.filter(r => r.status === "converted").length, results });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Returns**: `{ success: true, converted: N, results: [...] }`

**Key rules**:
- Always snapshot `[...group.children]` before iterating — the array mutates as children are moved
- Coordinates in GROUPs are absolute — subtract GROUP's x,y to get relative position in new FRAME
- GROUP auto-deletes when empty — never call `group.remove()`
- Use the conversion as an opportunity to apply semantic names

**Node type constraint support reference**:

| Node Type | `constraints` exists | Can set constraints |
|-----------|---------------------|-------------------|
| FRAME | Yes | Yes |
| RECTANGLE | Yes | Yes |
| TEXT | Yes | Yes |
| ELLIPSE | Yes | Yes |
| COMPONENT | Yes | Yes |
| INSTANCE | Yes | Yes |
| **GROUP** | **No** | **No** |
| SECTION | No | No |

### Recipe: Componentize from Clone

**Goal**: Convert an existing element from a cloned screen into a reusable component, preserving all visual properties (fonts, fills, nested instances, images) perfectly.

**When to use**: When a Draft screen contains a visual element that should become a reusable component. This pattern preserves IMAGE fills, exact fonts, nested INSTANCE nodes, and all visual properties — building from scratch would lose them.

**Code**:

```javascript
// figma_execute — componentize an element from a cloned screen
(async () => {
  try {
    const screen = await figma.getNodeByIdAsync("SCREEN_ID");
    const element = await figma.getNodeByIdAsync("ELEMENT_ID");
    const componentsSection = await figma.getNodeByIdAsync("COMPONENTS_SECTION_ID");
    if (!screen || !element || !componentsSection) {
      return JSON.stringify({ error: "Node not found" });
    }

    // 1. Record original position
    const origX = element.x;
    const origY = element.y;
    const origIdx = screen.children.indexOf(element);
    const origConstraints = 'constraints' in element
      ? { horizontal: element.constraints.horizontal, vertical: element.constraints.vertical }
      : { horizontal: "SCALE", vertical: "MIN" };

    // 2. Clone to components section
    const clone = element.clone();
    componentsSection.appendChild(clone);
    clone.x = 0;
    clone.y = 0;

    // 3. Convert inner GROUPs to FRAMEs if needed
    // (apply GROUP→FRAME conversion pattern here)

    // 4. Convert to COMPONENT — preserves ALL children, fills, fonts, nested instances
    const comp = figma.createComponentFromNode(clone);
    comp.name = "ComponentName";
    comp.description = "Description for developers";

    // 5. Add text properties for customizable text fields
    // Find text nodes and expose as component properties
    const textNodes = comp.findAll(n => n.type === "TEXT");
    for (const tn of textNodes) {
      const propName = tn.name.toLowerCase().replace(/\s+/g, '_');
      comp.addComponentProperty(propName, "TEXT", tn.characters);
      const propKey = Object.keys(comp.componentPropertyDefinitions)
        .find(k => k.startsWith(propName));
      if (propKey) {
        await figma.loadFontAsync(tn.fontName);
        tn.componentPropertyReferences = { characters: propKey };
      }
    }

    // 6. Create instance back in screen
    const instance = comp.createInstance();
    screen.insertChild(origIdx, instance);
    instance.x = origX;
    instance.y = origY;
    instance.constraints = origConstraints;

    // 7. Remove original element
    element.remove();

    return JSON.stringify({
      success: true,
      componentId: comp.id,
      componentName: comp.name,
      instanceId: instance.id,
      textProperties: Object.keys(comp.componentPropertyDefinitions).length
    });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Returns**: `{ success: true, componentId: "...", instanceId: "...", textProperties: N }`

**Why this is better than building from scratch**:

| Aspect | Build from scratch | Componentize from clone |
|--------|-------------------|------------------------|
| Font fidelity | Must know exact fonts/weights | Preserved automatically |
| Nested instances | Must recreate | Preserved (e.g., Material slider) |
| Visual accuracy | Approximate | Pixel-perfect |
| Effort | 20-50 lines of code | 10-15 lines |
| Error risk | High (font loading, layout) | Low |

### Recipe: COMPONENT_SET Variant Instantiation

**Goal**: Correctly instantiate a specific variant from a COMPONENT_SET. `createInstance()` works on COMPONENT (individual variant), NOT on COMPONENT_SET.

**When to use**: When replacing raw elements with component instances during the Component Integration step (Step 2.6 of the Draft-to-Handoff pipeline).

**Code**:

```javascript
// figma_execute — instantiate a specific variant from a COMPONENT_SET
(async () => {
  try {
    const setId = "COMPONENT_SET_ID_HERE";
    const set = await figma.getNodeByIdAsync(setId);

    if (!set) return JSON.stringify({ error: "Node not found" });

    if (set.type === "COMPONENT_SET") {
      // Find the specific variant by property combination
      const variant = set.children.find(c =>
        c.name.includes("State=Default") && c.name.includes("Size=Medium")
      );
      if (!variant) {
        return JSON.stringify({
          error: "Variant not found",
          available: set.children.map(c => c.name)
        });
      }
      // createInstance() on the VARIANT child, not the SET
      const instance = variant.createInstance();
      return JSON.stringify({
        success: true,
        instanceId: instance.id,
        variantName: variant.name
      });
    }

    if (set.type === "COMPONENT") {
      // Simple component (no variants) — instantiate directly
      const instance = set.createInstance();
      return JSON.stringify({
        success: true,
        instanceId: instance.id,
        componentName: set.name
      });
    }

    return JSON.stringify({ error: `Unexpected type: ${set.type}` });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Setting properties on a variant instance**:

```javascript
// After creating instance, set text/boolean properties
instance.setProperties({
  "label#145:14": "Custom Label",    // text property
  "value#145:15": "25:02",           // text property
  "showIcon#145:16": true            // boolean property
});
```

**Swapping to a different variant** (after instance is placed):

```javascript
// swapComponent also requires a COMPONENT, not COMPONENT_SET
const newVariant = set.children.find(c => c.name.includes("State=Active"));
instance.swapComponent(newVariant);  // ← COMPONENT node, not SET
```

**Key rules**:
- `createInstance()` on COMPONENT → works
- `createInstance()` on COMPONENT_SET → does NOT work
- `swapComponent()` requires COMPONENT → not COMPONENT_SET
- When searching for variant children, use `set.children.find()` with name matching
- Variant names follow the pattern `"Property1=Value1, Property2=Value2"`
