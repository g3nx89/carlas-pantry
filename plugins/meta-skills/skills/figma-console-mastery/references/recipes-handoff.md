# Recipes — Handoff Patterns

> **Compatibility**: Verified against figma-console-mcp v1.11.2 (February 2026)
>
> **Prerequisite**: Load `recipes-foundation.md` first.
>
> **Scope**: Operational patterns for Draft-to-Handoff workflows — GROUP→FRAME conversion, componentize from clone, COMPONENT_SET variant instantiation. For basic component recipes, see `recipes-components.md`. For composite patterns, see `recipes-components-composite.md`.
>
> For Plugin API details, see `plugin-api-foundation.md`, `plugin-api-visuals.md`, `plugin-api-advanced.md`. For common errors, see `anti-patterns.md`.

## Recipe Index

| Recipe | Line |
|--------|-----:|
| GROUP→FRAME Conversion | 23 |
| Componentize from Clone | 168 |
| COMPONENT_SET Variant Instantiation | 258 |

---

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
