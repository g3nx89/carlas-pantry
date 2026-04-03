# Recipes — Composite Component Patterns

> **Compatibility**: Verified against figma-console-mcp v1.11.2 (February 2026)
>
> **Prerequisite**: Load `recipes-foundation.md` first — all component recipes assume familiarity with the IIFE wrapper, font preloading, and node reference patterns.
>
> **Scope**: Composite/complex UI component recipes (Form, Data Table, Empty State, Modal, Dashboard Header, Component Variant Set). For basic/atomic components (Card, Button, Input, Toast, Navbar, Sidebar), see `recipes-components.md`. For handoff patterns, see `recipes-handoff.md`.
>
> For Plugin API details, see `plugin-api-foundation.md`, `plugin-api-visuals.md`, `plugin-api-advanced.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.

## Recipe Index

| Recipe | Line |
|--------|-----:|
| Form Layout | 24 |
| Data Table Row | 140 |
| Empty State | 246 |
| Modal with Scrim Overlay | 345 |
| Dashboard Header | 489 |
| Component Variant Set | 625 |

---

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
