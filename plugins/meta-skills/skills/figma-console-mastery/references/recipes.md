# Recipes — Building Specific UI Patterns

> **Compatibility**: Verified against Figma Console MCP v1.10.0 (February 2026)
>
> For Plugin API details, see `plugin-api.md`. For M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.

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

> For Material Design 3 component recipes (M3 Button, M3 Card, M3 Top App Bar, M3 Elevation Shadows), see `recipes-m3.md`.

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
