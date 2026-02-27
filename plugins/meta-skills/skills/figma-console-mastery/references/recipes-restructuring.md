# Recipes — Restructuring Freehand Designs

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Prerequisites**: Load `recipes-foundation.md` first — restructuring recipes assume familiarity with the IIFE wrapper, font preloading, and node reference patterns.
>
> For Plugin API details, see `plugin-api.md`. For design rules and M3 specs, see `design-rules.md`. For common errors, see `anti-patterns.md`.
> For component recipes, see `recipes-components.md`. For composition and advanced patterns, see `recipes-advanced.md`.

## Recipe Index

| Section | Recipe | Line |
|---------|--------|-----:|
| **Analysis** | Deep Node Tree Analysis | 32 |
| | Repeated Pattern Detection | 148 |
| | Visual Blueprint Extraction | 221 |
| **Structural** | Convert Frame to Auto-Layout | 386 |
| | Reparent Children into New Container | 473 |
| | Snap Spacing to 4px Grid | 535 |
| **Componentization** | Extract Component from Frame | 597 |
| | Replace Element with Library Instance | 636 |
| | Create Variant Set from Existing Elements | 690 |
| **Token Binding** | Bind Color Token to Existing Node | 743 |
| | Batch Token Binding | 800 |
| **Naming** | Batch Rename with Semantic Slash Convention | 872 |
| **Socratic Questions** | Question Templates by Category | 932 |

---

## Analysis Recipes

### Recipe: Deep Node Tree Analysis

**Goal**: Scan a selected frame's entire node tree and compile a structured deviation report — missing auto-layout, hardcoded colors, non-4px spacing, generic names, missing component usage.

**Code**:

```javascript
(async () => {
  try {
    const root = await figma.getNodeByIdAsync("ROOT_ID_HERE")
    if (!root) return JSON.stringify({ success: false, error: "Node not found" })

    const deviations = {
      missingAutoLayout: [],
      hardcodedColors: [],
      nonGridSpacing: [],
      genericNames: [],
      flatHierarchy: [],
      totalNodes: 0
    }

    const GENERIC_NAMES = /^(Frame|Rectangle|Group|Ellipse|Line|Vector|Text|Image)\s*\d*$/i

    function walkNode(node, depth) {
      deviations.totalNodes++

      // Generic name check
      if (GENERIC_NAMES.test(node.name)) {
        deviations.genericNames.push({ id: node.id, name: node.name, type: node.type })
      }

      // Frame without auto-layout (has 2+ children)
      if (node.type === "FRAME" && !node.layoutMode && node.children && node.children.length >= 2) {
        deviations.missingAutoLayout.push({
          id: node.id, name: node.name,
          childCount: node.children.length
        })
      }

      // Hardcoded solid fills (check per-fill-index for variable binding)
      if ("fills" in node && Array.isArray(node.fills)) {
        for (let fi = 0; fi < node.fills.length; fi++) {
          const fill = node.fills[fi]
          if (fill.type === "SOLID" && fill.visible !== false) {
            const isBound = !!node.boundVariables?.fills?.[fi]
            if (!isBound) {
              const { r, g, b } = fill.color
              deviations.hardcodedColors.push({
                id: node.id, name: node.name, fillIndex: fi,
                color: `rgb(${Math.round(r*255)},${Math.round(g*255)},${Math.round(b*255)})`
              })
            }
          }
        }
      }

      // Non-4px spacing (padding, itemSpacing)
      if ("itemSpacing" in node && node.itemSpacing % 4 !== 0) {
        deviations.nonGridSpacing.push({
          id: node.id, name: node.name,
          property: "itemSpacing", value: node.itemSpacing
        })
      }
      for (const pad of ["paddingTop", "paddingBottom", "paddingLeft", "paddingRight"]) {
        if (pad in node && node[pad] % 4 !== 0) {
          deviations.nonGridSpacing.push({
            id: node.id, name: node.name,
            property: pad, value: node[pad]
          })
        }
      }

      // Flat hierarchy — frame with 10+ direct children likely needs grouping
      if (node.type === "FRAME" && node.children && node.children.length >= 10) {
        deviations.flatHierarchy.push({
          id: node.id, name: node.name,
          childCount: node.children.length
        })
      }

      // Recurse
      if ("children" in node) {
        for (const child of node.children) {
          walkNode(child, depth + 1)
        }
      }
    }

    walkNode(root, 0)

    return JSON.stringify({
      success: true,
      rootId: root.id,
      rootName: root.name,
      totalNodes: deviations.totalNodes,
      summary: {
        missingAutoLayout: deviations.missingAutoLayout.length,
        hardcodedColors: deviations.hardcodedColors.length,
        nonGridSpacing: deviations.nonGridSpacing.length,
        genericNames: deviations.genericNames.length,
        flatHierarchy: deviations.flatHierarchy.length
      },
      deviations
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, totalNodes: N, summary: { missingAutoLayout: N, ... }, deviations: { ... } }`

**Note**: For pages with 2000+ nodes, scope the scan to a selected frame (pass its ID as `ROOT_ID_HERE`) rather than the full page. Full-page scans on large files may hit Plugin API execution time limits or return oversized JSON.

**Next**: Present the summary to the user. Use the deviations data to populate Socratic question templates (see Socratic Questions section). Feed specific node IDs into structural and naming recipes below.

### Recipe: Repeated Pattern Detection

**Goal**: Identify groups of nodes that share the same structural fingerprint (child count, child types, similar dimensions) — likely candidates for componentization.

**Code**:

```javascript
(async () => {
  try {
    const root = await figma.getNodeByIdAsync("ROOT_ID_HERE")
    if (!root) return JSON.stringify({ success: false, error: "Node not found" })

    const fingerprints = new Map()

    function getFingerprint(node) {
      if (!("children" in node) || node.children.length === 0) return null
      const childTypes = node.children.map(c => c.type).sort().join(",")
      const w = Math.round(node.width / 10) * 10
      const h = Math.round(node.height / 10) * 10
      return `${childTypes}|${node.children.length}|${w}x${h}`
    }

    function walkNode(node) {
      const fp = getFingerprint(node)
      if (fp) {
        if (!fingerprints.has(fp)) fingerprints.set(fp, [])
        fingerprints.get(fp).push({
          id: node.id,
          name: node.name,
          type: node.type,
          childCount: node.children.length,
          width: Math.round(node.width),
          height: Math.round(node.height)
        })
      }
      if ("children" in node) {
        for (const child of node.children) walkNode(child)
      }
    }

    walkNode(root)

    // Filter to groups with 2+ matches (actual repeated patterns)
    const repeatedPatterns = []
    for (const [fp, nodes] of fingerprints) {
      if (nodes.length >= 2) {
        repeatedPatterns.push({
          fingerprint: fp,
          count: nodes.length,
          nodes: nodes
        })
      }
    }

    // Sort by count descending — highest repetition first
    repeatedPatterns.sort((a, b) => b.count - a.count)

    return JSON.stringify({
      success: true,
      rootId: root.id,
      patternsFound: repeatedPatterns.length,
      patterns: repeatedPatterns.slice(0, 10)  // Top 10 candidates
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, patternsFound: N, patterns: [{ fingerprint, count, nodes }] }`

**Next**: Present patterns to the user with Socratic questions about which should become components. Use the node IDs in the Extract Component recipe.

### Recipe: Visual Blueprint Extraction

**Goal**: Perform a read-only scan of a selected frame and capture ALL visual properties needed to faithfully reproduce the design — dimensions, fills (including gradients), strokes, corner radii, opacity, layout properties, absolute bounds, and complete text styles. Returns a hierarchical JSON blueprint that mirrors the node tree structure.

**Used by both paths**: Path A uses the blueprint as a "before" reference to verify visual fidelity after each structural change. Path B uses it as the creation blueprint for reconstruction from scratch.

**Code**:

```javascript
(async () => {
  try {
    const root = await figma.getNodeByIdAsync("ROOT_ID_HERE")
    if (!root) return JSON.stringify({ success: false, error: "Node not found" })

    function extractFills(node) {
      if (!("fills" in node) || !Array.isArray(node.fills)) return []
      return node.fills.map(f => {
        if (f.type === "SOLID") {
          return {
            type: "SOLID",
            color: { r: Math.round(f.color.r * 255), g: Math.round(f.color.g * 255), b: Math.round(f.color.b * 255) },
            opacity: f.opacity !== undefined ? f.opacity : 1,
            visible: f.visible !== false
          }
        }
        if (f.type === "GRADIENT_LINEAR" || f.type === "GRADIENT_RADIAL" || f.type === "GRADIENT_ANGULAR") {
          return {
            type: f.type,
            gradientStops: (f.gradientStops || []).map(s => ({
              position: s.position,
              color: { r: Math.round(s.color.r * 255), g: Math.round(s.color.g * 255), b: Math.round(s.color.b * 255), a: s.color.a }
            })),
            visible: f.visible !== false
          }
        }
        return { type: f.type, visible: f.visible !== false }
      })
    }

    function extractStrokes(node) {
      if (!("strokes" in node) || !Array.isArray(node.strokes)) return []
      return node.strokes.map(s => ({
        type: s.type,
        color: s.color ? { r: Math.round(s.color.r * 255), g: Math.round(s.color.g * 255), b: Math.round(s.color.b * 255), a: s.color.a } : null,
        opacity: s.opacity !== undefined ? s.opacity : 1
      }))
    }

    function extractEffects(node) {
      if (!("effects" in node) || !Array.isArray(node.effects)) return []
      return node.effects.map(e => {
        const data = { type: e.type, visible: e.visible !== false }
        if (e.color) {
          data.color = { r: Math.round(e.color.r * 255), g: Math.round(e.color.g * 255), b: Math.round(e.color.b * 255), a: e.color.a }
        }
        if (e.offset) data.offset = e.offset
        if (e.radius !== undefined) data.radius = e.radius
        if (e.spread !== undefined) data.spread = e.spread
        return data
      })
    }

    function extractNode(node) {
      const data = {
        id: node.id, name: node.name, type: node.type,
        visible: node.visible !== false,
        width: Math.round(node.width), height: Math.round(node.height),
        x: Math.round(node.x), y: Math.round(node.y),
        rotation: node.rotation || 0,
        opacity: node.opacity !== undefined ? node.opacity : 1,
        blendMode: node.blendMode || "NORMAL",
        fills: extractFills(node),
        strokes: extractStrokes(node),
        strokeWeight: node.strokeWeight || 0,
        strokeAlign: node.strokeAlign || "INSIDE",
        effects: extractEffects(node),
        cornerRadius: typeof node.cornerRadius === "number" ? node.cornerRadius : 0,
        cornerSmoothing: node.cornerSmoothing || 0
      }

      // Per-corner radius (when corners differ)
      if ("topLeftRadius" in node && typeof node.cornerRadius !== "number") {
        data.topLeftRadius = node.topLeftRadius
        data.topRightRadius = node.topRightRadius
        data.bottomLeftRadius = node.bottomLeftRadius
        data.bottomRightRadius = node.bottomRightRadius
      }

      // Clipping and layout positioning
      if ("clipsContent" in node) data.clipsContent = node.clipsContent
      if ("layoutPositioning" in node) data.layoutPositioning = node.layoutPositioning

      // Layout properties (frames only)
      if ("layoutMode" in node) {
        data.layoutMode = node.layoutMode || null
        data.itemSpacing = node.itemSpacing
        data.paddingTop = node.paddingTop
        data.paddingBottom = node.paddingBottom
        data.paddingLeft = node.paddingLeft
        data.paddingRight = node.paddingRight
        data.primaryAxisSizingMode = node.primaryAxisSizingMode
        data.counterAxisSizingMode = node.counterAxisSizingMode
        data.primaryAxisAlignItems = node.primaryAxisAlignItems
        data.counterAxisAlignItems = node.counterAxisAlignItems
        data.layoutSizingHorizontal = node.layoutSizingHorizontal
        data.layoutSizingVertical = node.layoutSizingVertical
      }

      // Instance metadata (for library component mapping in Path B)
      if (node.type === "INSTANCE") {
        try {
          data.mainComponentKey = node.mainComponent?.key || null
          data.componentProperties = node.componentProperties || {}
        } catch (_) { data.mainComponentKey = null }
      }

      // Text-specific properties
      if (node.type === "TEXT") {
        data.characters = node.characters
        data.fontSize = node.fontSize
        data.fontName = node.fontName
        data.textAlignHorizontal = node.textAlignHorizontal
        data.lineHeight = node.lineHeight
        data.letterSpacing = node.letterSpacing
        data.textAutoResize = node.textAutoResize
        try {
          data.styledSegments = node.getStyledTextSegments(
            ["fontName", "fontSize", "fills", "textDecoration"]
          ).map(seg => ({
            start: seg.start, end: seg.end,
            characters: node.characters.slice(seg.start, seg.end),
            fontName: seg.fontName, fontSize: seg.fontSize,
            fills: seg.fills, textDecoration: seg.textDecoration
          }))
        } catch (_) { data.styledSegments = [] }
      }

      // Recurse into children
      if ("children" in node && node.children.length > 0) {
        data.children = node.children.map(child => extractNode(child))
      }

      return data
    }

    const blueprint = extractNode(root)
    return JSON.stringify({ success: true, rootId: root.id, rootName: root.name, blueprint })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, rootId: "...", rootName: "...", blueprint: { id, name, type, visible, width, height, x, y, rotation, opacity, blendMode, fills, strokes, strokeAlign, effects, cornerRadius, cornerSmoothing, clipsContent, layoutMode, layoutSizing*, children: [...] } }`

Additional per-type fields: INSTANCE → `mainComponentKey`, `componentProperties`. TEXT → `characters`, `fontSize`, `fontName`, `textAlignHorizontal`, `lineHeight`, `letterSpacing`, `textAutoResize`, `styledSegments`. Per-corner radius when corners differ: `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius`.

**Note**: The blueprint JSON can be large for complex designs. For screens with 200+ nodes, scope the extraction to individual sections (pass section frame IDs) and merge the results. Text nodes include `styledSegments` for mixed-style content (via `getStyledTextSegments`).

**Next**: For Path A, save the blueprint as the fidelity reference — compare screenshots against it after each structural change. For Path B, feed the blueprint into creation recipes from `recipes-foundation.md`, `recipes-components.md`, and `recipes-advanced.md` to reconstruct the design from scratch.

---

## Structural Recipes

### Recipe: Convert Frame to Auto-Layout

**Goal**: Convert a freehand-positioned frame to auto-layout by detecting child arrangement (horizontal vs vertical spread), inferring spacing from gaps between children, and snapping to 4px grid.

**Code**:

```javascript
(async () => {
  try {
    const frame = await figma.getNodeByIdAsync("FRAME_ID_HERE")
    if (!frame || frame.type !== "FRAME") {
      return JSON.stringify({ success: false, error: "Frame not found or not a FRAME" })
    }
    if (frame.children.length < 2) {
      return JSON.stringify({ success: false, error: "Need 2+ children to detect layout" })
    }

    // Detect direction from child positions
    const sorted = [...frame.children].sort((a, b) => a.y - b.y || a.x - b.x)
    const xSpread = Math.max(...sorted.map(c => c.x + c.width)) - Math.min(...sorted.map(c => c.x))
    const ySpread = Math.max(...sorted.map(c => c.y + c.height)) - Math.min(...sorted.map(c => c.y))
    const isHorizontal = xSpread > ySpread

    // Infer spacing from gaps between consecutive children
    const gaps = []
    const axis = isHorizontal
      ? sorted.sort((a, b) => a.x - b.x)
      : sorted.sort((a, b) => a.y - b.y)

    for (let i = 1; i < axis.length; i++) {
      const prev = axis[i - 1]
      const curr = axis[i]
      const gap = isHorizontal
        ? curr.x - (prev.x + prev.width)
        : curr.y - (prev.y + prev.height)
      if (gap > 0) gaps.push(gap)
    }

    const avgGap = gaps.length > 0 ? gaps.reduce((a, b) => a + b, 0) / gaps.length : 8
    const spacing = Math.round(avgGap / 4) * 4  // Snap to 4px grid

    // Infer padding from first/last child distances to frame edges
    const first = axis[0]
    const last = axis[axis.length - 1]
    const padStart = isHorizontal ? first.x : first.y
    const padEnd = isHorizontal
      ? frame.width - (last.x + last.width)
      : frame.height - (last.y + last.height)

    const paddingStart = Math.max(0, Math.round(padStart / 4) * 4)
    const paddingEnd = Math.max(0, Math.round(padEnd / 4) * 4)

    // Apply auto-layout
    frame.layoutMode = isHorizontal ? "HORIZONTAL" : "VERTICAL"
    frame.itemSpacing = spacing
    if (isHorizontal) {
      frame.paddingLeft = paddingStart
      frame.paddingRight = paddingEnd
      frame.paddingTop = Math.round(Math.min(...sorted.map(c => c.y)) / 4) * 4
      frame.paddingBottom = Math.round(Math.max(0, frame.height - Math.max(...sorted.map(c => c.y + c.height))) / 4) * 4
    } else {
      frame.paddingTop = paddingStart
      frame.paddingBottom = paddingEnd
      frame.paddingLeft = Math.round(Math.min(...sorted.map(c => c.x)) / 4) * 4
      frame.paddingRight = Math.round(Math.max(0, frame.width - Math.max(...sorted.map(c => c.x + c.width))) / 4) * 4
    }

    return JSON.stringify({
      success: true,
      id: frame.id,
      direction: isHorizontal ? "HORIZONTAL" : "VERTICAL",
      spacing,
      padding: {
        top: frame.paddingTop, bottom: frame.paddingBottom,
        left: frame.paddingLeft, right: frame.paddingRight
      }
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, direction: "VERTICAL", spacing: 12, padding: { ... } }`

**Next**: Screenshot to validate. Adjust sizing modes for children — see `layoutSizingHorizontal`/`layoutSizingVertical` in `plugin-api.md`.

### Recipe: Reparent Children into New Container

**Goal**: Take a set of child nodes from a flat frame and group them into a new auto-layout container, preserving order.

**Code**:

```javascript
(async () => {
  try {
    const parent = await figma.getNodeByIdAsync("PARENT_ID_HERE")
    if (!parent) return JSON.stringify({ success: false, error: "Parent not found" })

    const childIds = ["CHILD_ID_1", "CHILD_ID_2", "CHILD_ID_3"]
    const children = []
    for (const id of childIds) {
      const node = await figma.getNodeByIdAsync(id)
      if (node) children.push(node)
    }
    if (children.length === 0) {
      return JSON.stringify({ success: false, error: "No valid children found" })
    }

    // Find insertion index (position of first child in parent)
    const insertIndex = parent.children.indexOf(children[0])

    // Create container
    const container = figma.createFrame()
    container.name = "CONTAINER_NAME_HERE"
    container.layoutMode = "VERTICAL"
    container.primaryAxisSizingMode = "AUTO"
    container.counterAxisSizingMode = "FILL"
    container.itemSpacing = 8
    container.fills = []

    // Insert container at the original position
    if (insertIndex >= 0) {
      parent.insertChild(insertIndex, container)
    } else {
      parent.appendChild(container)
    }

    // Move children into container (in order)
    for (const child of children) {
      container.appendChild(child)
    }

    return JSON.stringify({
      success: true,
      containerId: container.id,
      containerName: container.name,
      childrenMoved: children.length
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, containerId: "...", childrenMoved: 3 }`

**Next**: Set `layoutSizingHorizontal`/`layoutSizingVertical` on the container and its children. Screenshot to validate hierarchy.

### Recipe: Snap Spacing to 4px Grid

**Goal**: Walk a node tree and fix all non-4px-aligned spacing values (itemSpacing, padding) by rounding to nearest 4px.

**Code**:

```javascript
(async () => {
  try {
    const root = await figma.getNodeByIdAsync("ROOT_ID_HERE")
    if (!root) return JSON.stringify({ success: false, error: "Node not found" })

    const fixes = []
    const snap4 = (v) => Math.round(v / 4) * 4

    function walkAndFix(node) {
      if ("itemSpacing" in node && node.itemSpacing % 4 !== 0) {
        const old = node.itemSpacing
        node.itemSpacing = snap4(old)
        fixes.push({ id: node.id, name: node.name, prop: "itemSpacing", old, fixed: node.itemSpacing })
      }

      for (const pad of ["paddingTop", "paddingBottom", "paddingLeft", "paddingRight"]) {
        if (pad in node && node[pad] % 4 !== 0) {
          const old = node[pad]
          node[pad] = snap4(old)
          fixes.push({ id: node.id, name: node.name, prop: pad, old, fixed: node[pad] })
        }
      }

      if ("counterAxisSpacing" in node && node.counterAxisSpacing && node.counterAxisSpacing % 4 !== 0) {
        const old = node.counterAxisSpacing
        node.counterAxisSpacing = snap4(old)
        fixes.push({ id: node.id, name: node.name, prop: "counterAxisSpacing", old, fixed: node.counterAxisSpacing })
      }

      if ("children" in node) {
        for (const child of node.children) walkAndFix(child)
      }
    }

    walkAndFix(root)

    return JSON.stringify({
      success: true,
      fixCount: fixes.length,
      fixes: fixes.slice(0, 50)  // Cap output to avoid oversized return
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, fixCount: N, fixes: [{ id, name, prop, old, new }] }`

**Next**: Screenshot to validate spacing corrections. Review any fixes where the snap changed the value by more than 2px — these may need manual confirmation.

---

## Componentization Recipes

### Recipe: Extract Component from Frame

**Goal**: Convert an existing frame into a reusable Figma component using `createComponentFromNode`, preserving all children and properties.

**Code**:

```javascript
(async () => {
  try {
    const frame = await figma.getNodeByIdAsync("FRAME_ID_HERE")
    if (!frame) return JSON.stringify({ success: false, error: "Node not found" })
    if (frame.type !== "FRAME") {
      return JSON.stringify({ success: false, error: `Expected FRAME, got ${frame.type}` })
    }

    // Convert frame to component (preserves children and layout)
    const component = figma.createComponentFromNode(frame)
    component.name = "COMPONENT_NAME_HERE"
    component.description = "COMPONENT_DESCRIPTION_HERE"

    return JSON.stringify({
      success: true,
      componentId: component.id,
      componentKey: component.key,
      name: component.name,
      childCount: component.children.length,
      width: Math.round(component.width),
      height: Math.round(component.height)
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, componentId: "...", componentKey: "...", name: "..." }`

**Next**: Document the component with `figma_set_description`. If multiple similar frames were detected by Pattern Detection, convert the first one and use instances for the rest.

### Recipe: Replace Element with Library Instance

**Goal**: Replace a freehand element with an instance of an existing library component. Three steps: search library, instantiate, swap position and remove old node.

**Prerequisite**: Run `figma_search_components(query="...")` first to get the `component_key`. This recipe assumes the key is already known.

**Code**:

```javascript
(async () => {
  try {
    const oldNode = await figma.getNodeByIdAsync("OLD_NODE_ID_HERE")
    if (!oldNode) return JSON.stringify({ success: false, error: "Old node not found" })

    const parent = oldNode.parent
    if (!parent) return JSON.stringify({ success: false, error: "No parent" })

    const insertIndex = parent.children.indexOf(oldNode)

    // Import component by key and create instance
    const component = await figma.importComponentByKeyAsync("COMPONENT_KEY_HERE")
    const instance = component.createInstance()

    // Match position and size
    instance.x = oldNode.x
    instance.y = oldNode.y
    instance.resize(oldNode.width, oldNode.height)

    // Insert at same position in parent
    if (insertIndex >= 0) {
      parent.insertChild(insertIndex, instance)
    } else {
      parent.appendChild(instance)
    }

    // Remove old node
    oldNode.remove()

    return JSON.stringify({
      success: true,
      instanceId: instance.id,
      componentName: component.name,
      replacedNode: "OLD_NODE_ID_HERE"
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, instanceId: "...", componentName: "...", replacedNode: "..." }`

**Next**: Set variant properties on the instance if needed. Screenshot to validate the swap maintained visual appearance.

### Recipe: Create Variant Set from Existing Elements

**Goal**: Take multiple similar frames (identified by Repeated Pattern Detection) and combine them into a component set with variants.

**Code**:

```javascript
(async () => {
  try {
    const frameIds = ["FRAME_ID_1", "FRAME_ID_2", "FRAME_ID_3"]
    const variantNames = ["Default", "Hover", "Active"]

    const components = []
    for (let i = 0; i < frameIds.length; i++) {
      const frame = await figma.getNodeByIdAsync(frameIds[i])
      if (!frame) continue

      const comp = figma.createComponentFromNode(frame)
      // Variant naming convention: "Property=Value"
      comp.name = `State=${variantNames[i] || 'Variant' + (i + 1)}`
      components.push(comp)
    }

    if (components.length < 2) {
      return JSON.stringify({ success: false, error: "Need at least 2 frames for a variant set" })
    }

    // Combine into component set
    const componentSet = figma.combineAsVariants(components, figma.currentPage)
    componentSet.name = "COMPONENT_SET_NAME_HERE"
    componentSet.description = "COMPONENT_SET_DESCRIPTION_HERE"

    return JSON.stringify({
      success: true,
      componentSetId: componentSet.id,
      name: componentSet.name,
      variantCount: components.length,
      variants: components.map(c => ({ id: c.id, name: c.name }))
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, componentSetId: "...", variantCount: 3, variants: [...] }`

**Next**: Use `figma_arrange_component_set` to lay out variants neatly. Document with `figma_set_description`. Screenshot to validate.

---

## Token Binding Recipes

### Recipe: Bind Color Token to Existing Node

**Goal**: Bind a variable (color token) to an existing node's fill, replacing a hardcoded color with a token reference.

**Code**:

```javascript
(async () => {
  try {
    const node = await figma.getNodeByIdAsync("NODE_ID_HERE")
    if (!node) return JSON.stringify({ success: false, error: "Node not found" })

    // Look up the variable by name within a collection
    const collections = await figma.variables.getLocalVariableCollectionsAsync()
    let targetVar = null
    for (const coll of collections) {
      for (const varId of coll.variableIds) {
        const v = await figma.variables.getVariableByIdAsync(varId)
        if (v && v.name === "VARIABLE_NAME_HERE") {
          targetVar = v
          break
        }
      }
      if (targetVar) break
    }

    if (!targetVar) {
      return JSON.stringify({ success: false, error: "Variable not found: VARIABLE_NAME_HERE" })
    }

    // Clone fills, bind variable to first solid fill
    const fills = JSON.parse(JSON.stringify(node.fills))
    if (fills.length === 0) {
      return JSON.stringify({ success: false, error: "Node has no fills" })
    }

    // Apply binding using setBoundVariableForPaint (preserves other fills)
    fills[0] = figma.variables.setBoundVariableForPaint(fills[0], "color", targetVar)
    node.fills = fills

    return JSON.stringify({
      success: true,
      nodeId: node.id,
      nodeName: node.name,
      boundVariable: targetVar.name,
      variableId: targetVar.id
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, nodeId: "...", boundVariable: "colors/primary" }`

**Next**: Screenshot to confirm the visual appearance is unchanged after binding. Repeat for other hardcoded colors identified in the Deep Node Tree Analysis.

### Recipe: Batch Token Binding

**Goal**: Bind color tokens to multiple nodes at once, using a mapping of node IDs to variable names.

**Code**:

```javascript
(async () => {
  try {
    // Mapping: nodeId -> variableName
    const bindings = [
      { nodeId: "NODE_1", varName: "colors/primary" },
      { nodeId: "NODE_2", varName: "colors/surface" },
      { nodeId: "NODE_3", varName: "colors/on-surface" }
    ]

    // Pre-load all variables into a lookup map
    const varMap = new Map()
    const collections = await figma.variables.getLocalVariableCollectionsAsync()
    for (const coll of collections) {
      for (const varId of coll.variableIds) {
        const v = await figma.variables.getVariableByIdAsync(varId)
        if (v) varMap.set(v.name, v)
      }
    }

    const results = []
    for (const { nodeId, varName } of bindings) {
      const node = await figma.getNodeByIdAsync(nodeId)
      const variable = varMap.get(varName)

      if (!node || !variable) {
        results.push({ nodeId, varName, success: false, error: !node ? "Node not found" : "Variable not found" })
        continue
      }

      try {
        const fills = JSON.parse(JSON.stringify(node.fills))
        if (fills.length === 0) {
          results.push({ nodeId, varName, success: false, error: "No fills" })
          continue
        }
        fills[0] = figma.variables.setBoundVariableForPaint(fills[0], "color", variable)
        node.fills = fills
        results.push({ nodeId, varName, success: true })
      } catch (e) {
        results.push({ nodeId, varName, success: false, error: e.message })
      }
    }

    const successCount = results.filter(r => r.success).length
    return JSON.stringify({
      success: true,
      total: bindings.length,
      bound: successCount,
      failed: bindings.length - successCount,
      results
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, total: 3, bound: 2, failed: 1, results: [...] }`

**Next**: Screenshot to validate. If no tokens exist yet, branch to Design System Bootstrap recipe in `recipes-advanced.md` to create the token system first.

---

## Naming Recipes

### Recipe: Batch Rename with Semantic Slash Convention

**Goal**: Rename nodes using a semantic slash convention (`Category/Element/Variant`), replacing generic names identified in the Deep Node Tree Analysis.

**Code**:

```javascript
(async () => {
  try {
    // Mapping: nodeId -> newName
    const renames = [
      { nodeId: "NODE_1", newName: "Header/Logo" },
      { nodeId: "NODE_2", newName: "Header/Navigation/Link" },
      { nodeId: "NODE_3", newName: "Content/Hero/Title" },
      { nodeId: "NODE_4", newName: "Content/Hero/Subtitle" },
      { nodeId: "NODE_5", newName: "Footer/Copyright" }
    ]

    const results = []
    for (const { nodeId, newName } of renames) {
      const node = await figma.getNodeByIdAsync(nodeId)
      if (!node) {
        results.push({ nodeId, newName, success: false, error: "Not found" })
        continue
      }
      const oldName = node.name
      node.name = newName
      results.push({ nodeId, oldName, newName, success: true })
    }

    const successCount = results.filter(r => r.success).length
    return JSON.stringify({
      success: true,
      total: renames.length,
      renamed: successCount,
      results
    })
  } catch (error) {
    return JSON.stringify({ success: false, error: error.message })
  }
})()
```

**Returns**: `{ success: true, total: 5, renamed: 5, results: [...] }`

**Naming conventions** (use with Socratic questions to confirm with user):

| Level | Pattern | Examples |
|-------|---------|----------|
| **Page section** | `Section/Element` | `Header/Logo`, `Footer/Links` |
| **Component part** | `Component/Part` | `Card/Thumbnail`, `Card/Title` |
| **Variant** | `Component/Property=Value` | `Button/State=Hover`, `Input/Size=Large` |
| **Utility** | `_utility-name` | `_spacer`, `_divider` |

**Next**: Screenshot to verify layer panel reflects the new naming hierarchy.

---

## Socratic Question Templates

### Question Templates by Category

These templates are filled with data from the Deep Node Tree Analysis and Visual Blueprint Extraction (Phase 1) and presented to the user during the Socratic planning phase (Phase 2). Placeholders in `{braces}` are replaced with actual values from the analysis.

**Derived placeholders**: `{auto_layout_pct}` is not directly in the analysis output — compute as `(totalFrames - missingAutoLayout) / totalFrames * 100` from the Deep Node Tree Analysis summary.

#### Restructuring Approach

Always ask this FIRST — before all other Socratic questions — to determine which path to take:

> The Phase 1 analysis found **{deviation_count} deviations** across **{total_nodes} nodes** ({health_score}/100 health score). The design currently has:
>
> - Auto-layout coverage: {auto_layout_pct}% of frames
> - Hardcoded colors: {hardcoded_color_count} fills unbound from tokens
> - Generic layer names: {generic_name_count} nodes
> - Component candidates: {pattern_count} repeated patterns
>
> **Two restructuring paths are available:**
>
> **Path A — In-place modification**: The existing node tree is modified directly. Frames get auto-layout, components are extracted in-place, colors are bound to tokens. The screen stays on the same canvas position with the same root node ID. Visual fidelity is verified after each structural change against the blueprint snapshot.
>
> **Path B — Reconstruction**: A new screen is built from scratch, visually faithful to the current design but using proper auto-layout, real components, and tokens from the start. The original design is preserved for reference. Best when the existing structure is too deeply flattened or inconsistent to patch incrementally.
>
> **Questions:**
> 1. Which path do you prefer: **in-place modification (Path A)** or **reconstruction from scratch (Path B)**?
> 2. *(If Path B)* Should the original design be kept on the same page (moved to a separate section) or archived to a separate Figma page?
> 3. *(If Path B)* Are there specific components from the team library that the new screen should use, or should the reconstruction build custom components that match the visual appearance?

#### Component Boundaries

Use when Repeated Pattern Detection found structural duplicates:

> I found **{pattern_count} groups** of visually similar elements. The most repeated pattern appears **{top_count} times** — these nodes share the same structure ({fingerprint_description}):
>
> {node_list_with_names}
>
> **Questions:**
> 1. Should these become a single reusable component? If so, what should it be called?
> 2. Are the visual differences between instances intentional variants (e.g., states, sizes) or accidental inconsistencies to normalize?
> 3. Does a similar component already exist in the team library that these should use instead?

#### Naming & Hierarchy

Use when the analysis found generic names or flat hierarchies:

> The current structure has **{generic_count} generic names** (like "Frame 12", "Rectangle 3") and **{flat_count} flat containers** with 10+ direct children.
>
> Here is the current layer structure:
> {indented_tree_excerpt}
>
> **Questions:**
> 1. What are the main semantic sections of this screen? (e.g., Header, Hero, Content, Footer)
> 2. Within each section, how should sub-elements be grouped? (e.g., should these {child_count} items in "{frame_name}" be split into logical groups?)
> 3. Is there a naming convention already in use across the project I should follow?

#### Interaction Patterns

Use when the design contains elements that look interactive (buttons, inputs, links):

> I identified elements that appear to be interactive controls:
>
> {interactive_elements_list}
>
> **Questions:**
> 1. Which of these are interactive? Should they become component instances with state variants (Default/Hover/Active/Disabled)?
> 2. Are there hover or pressed states that aren't yet designed? Should I create them?
> 3. Should any of these be linked to existing library components?

#### Token Strategy

Use when hardcoded colors were found but no variable bindings exist:

> The design uses **{color_count} hardcoded colors** across {node_count} nodes. The most frequently used colors are:
>
> {color_frequency_table}
>
> **Questions:**
> 1. Does a color token system already exist for this project? (I can check with `figma_get_variables`)
> 2. If not, should I create a basic token set based on these colors? I can group them as: primary, secondary, surface, on-surface, error.
> 3. Are any of these colors intentionally one-off, or should every color be tokenized?

#### Layout Direction

Use when Convert Frame to Auto-Layout inferred an ambiguous direction:

> Frame "{frame_name}" has {child_count} children. The child arrangement suggests {inferred_direction} layout, but the spread ratio is close (X: {x_spread}px, Y: {y_spread}px).
>
> **Questions:**
> 1. Should this be a {inferred_direction} stack, or is {alt_direction} more appropriate?
> 2. The inferred spacing is {spacing}px — does that match the intended design rhythm?
> 3. Should any children fill the available space, or should all items hug their content?
