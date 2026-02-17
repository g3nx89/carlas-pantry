# Recipes — Composition, Advanced Patterns & Full Pages

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> **Prerequisites**: Load `recipes-foundation.md` and `recipes-components.md` first. Foundation provides the IIFE wrapper, font preloading, and node reference patterns. Component recipes provide the sidebar, form, and button patterns reused in composition and full-page recipes below.
>
> For Plugin API details, see `plugin-api.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`. For M3 component recipes, see `recipes-m3.md`.

## Recipe Index

| Section | Recipe | Line |
|---------|--------|-----:|
| **Composition** | Shell Injection (Multi-Region Pages) | 30 |
| | Compose Library Components into Layout | 98 |
| | Design System Bootstrap | 165 |
| **Advanced** | Variable Binding to Nodes | 237 |
| | SVG Import and Styling | 325 |
| | Mixed-Style Rich Text | 362 |
| **Full Page** | Settings Page (End-to-End Multi-Call) | 412 |
| **Chaining** | Component Composition Pattern | 744 |
| | Iterative Refinement Pattern | 756 |
| | Design System Bootstrap Pattern | 771 |
| | Handoff Preparation Pattern | 783 |
| | Handoff Naming Audit | 798 |

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

**Goal**: Build a complete settings page by chaining 4 sequential `figma_execute` calls connected by returned node IDs. Demonstrates the composition pattern: page shell -> sidebar -> content area with form -> footer.

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
4. **Nested layouts**: Page (HORIZONTAL) -> Content (VERTICAL) -> Form Body (VERTICAL) -> Field groups (VERTICAL)

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

### Handoff Preparation Pattern

**Flow**: naming audit → fix naming → exception descriptions → token alignment check → health check

Prepares custom components for consumption by the coding agent via `get_design_context` (Official MCP). Implements the naming-convention-as-contract strategy: component names are the cross-platform mapping key, descriptions are used only for naming exceptions. See SKILL.md Code Handoff Protocol for the full workflow.

| Step | Tool | Action |
|------|------|--------|
| 1 | `figma_execute` | Run the Handoff Naming Audit recipe — check for non-PascalCase names and uppercase variant property keys |
| 2 | `figma_execute` | Rename components and variant property keys to match codebase conventions |
| 3 | `figma_set_description` | Add code-name exception notes only where Figma name must differ from code name |
| 4 | `figma_execute` | Verify token names align with codebase token system |
| 5 | `figma_search_components` | Prefer UI kit components (M3, Apple, SDS) for automatic Code Connect on Professional+ |
| 6 | `figma_audit_design_system` | Final health check — naming, tokens, consistency scores |

### Recipe: Handoff Naming Audit

**Goal**: Scan all components on the current page and report naming issues that would hinder downstream code mapping via `get_design_context`. Checks PascalCase component names and lowercase variant property keys. This provides code-readiness-specific analysis beyond the general naming score in `figma_audit_design_system`.

**Code**:

```javascript
(async () => {
  try {
    const components = figma.currentPage.findAll(n =>
      n.type === 'COMPONENT' || n.type === 'COMPONENT_SET'
    )
    const issues = []
    for (const comp of components) {
      // Check PascalCase per slash segment
      const segments = comp.name.split('/')
      for (const seg of segments) {
        if (!/^[A-Z][a-zA-Z0-9]*$/.test(seg.trim())) {
          issues.push({ id: comp.id, name: comp.name, issue: 'not-pascal-case', segment: seg })
          break
        }
      }
      // Check variant property keys (lowercase)
      if (comp.type === 'COMPONENT_SET') {
        const propDefs = comp.componentPropertyDefinitions
        if (propDefs) {
          for (const [key, def] of Object.entries(propDefs)) {
            if (def.type === 'VARIANT' && key !== key.toLowerCase()) {
              issues.push({ id: comp.id, name: comp.name,
                issue: 'uppercase-variant-key', key })
            }
          }
        }
      }
    }
    const capped = issues.slice(0, 50)
    return JSON.stringify({
      total_components: components.length,
      issues_found: issues.length,
      details: capped,
      truncated: issues.length > 50
    })
  } catch(error) { return JSON.stringify({ error: error.message }) }
})()
```

**Next**: Fix issues reported by this audit, then proceed with steps 3-6 of the Handoff Preparation Pattern.

> **Note**: The PascalCase check requires segments to start with an uppercase
> letter. Size tokens like `2XL` or all-caps abbreviations like `CTA` will be
> flagged. Review flagged items manually — not all flags are naming errors.

> **Multi-platform note**: this recipe does not include platform-specific paths or prop mappings. The naming convention is the cross-platform contract — the coding agent for each platform searches its own codebase for a component matching the Figma name. For components where platform names diverge, use `figma_set_description` with platform-specific code names.

---

*Recipes are designed to be composed. A typical screen build chains Page Container + Top App Bar + content cards + bottom navigation, each as a separate `figma_execute` call connected by returned node IDs.*
