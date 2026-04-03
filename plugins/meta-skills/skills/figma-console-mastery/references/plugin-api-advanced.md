# Plugin API — Advanced (Components, Prototypes, Variables, Coordinates, Performance)

> **Compatibility**: Verified against Figma Plugin API via figma-console-mcp v1.11.2 (February 2026)
>
> **Scope**: Components and instances, prototype reactions, variables and binding, coordinates/sizing/styles, return value behavior, state tracking, performance optimization. For operation order, node creation, and auto-layout, see `plugin-api-foundation.md`. For text, colors, effects, images, and cross-page operations, see `plugin-api-visuals.md`.

---

## Components and Instances

```javascript
// Creating a component
const comp = figma.createComponent()
comp.name = "Button"
comp.resize(200, 48)
comp.layoutMode = 'HORIZONTAL'
comp.primaryAxisAlignItems = 'CENTER'
comp.counterAxisAlignItems = 'CENTER'
comp.paddingLeft = 24; comp.paddingRight = 24
comp.fills = [{ type: 'SOLID', color: { r: 0.2, g: 0.5, b: 1 } }]
```

**Creating variants** — there is **no `figma.createComponentSet()`**:
```javascript
const defaultState = figma.createComponent()
defaultState.name = "Size=Medium, State=Default"  // Property=Value naming
const hoverState = figma.createComponent()
hoverState.name = "Size=Medium, State=Hover"

const componentSet = figma.combineAsVariants([defaultState, hoverState], figma.currentPage)
componentSet.name = "Button"
```

**Component properties:**
```javascript
// addComponentProperty returns a DISAMBIGUATED key (e.g. "Label#0:1"), NOT the base name
const showIconKey = comp.addComponentProperty('ShowIcon', 'BOOLEAN', true)
const labelKey = comp.addComponentProperty('Label', 'TEXT', 'Submit')
const iconKey = comp.addComponentProperty('Icon', 'INSTANCE_SWAP', defaultIconId)

// BINDING: use the RETURNED key (inside component definition)
comp.children[0].componentPropertyReferences = { 'visible': showIconKey }
comp.children[1].componentPropertyReferences = { 'characters': labelKey }
```

**Instantiating and overriding:**
```javascript
const instance = comp.createInstance()
// SETTING VALUES: use base name OR full key (both work on instances)
instance.setProperties({
  'Size': 'Large',          // variant property (base name)
  'Label': 'Login',         // text property (base name works for instances)
  'ShowIcon': false          // boolean property (base name works for instances)
})
instance.swapComponent(otherComponent)     // preserves overrides, node ID preserved
const frame = instance.detachInstance()     // returns FrameNode
```

**Key distinction — binding vs overriding:**
- **Binding** (inside component, once): use the RETURNED key from `addComponentProperty`
- **Setting value** (on instances): use the PROPERTY NAME (first arg to `addComponentProperty`)

**swapComponent — in-place hot-swap:**
```javascript
// Capture position before swap (may shift slightly)
const x = inst.x, y = inst.y, w = inst.width, h = inst.height, c = inst.constraints;
inst.swapComponent(newComp);
// Restore position after swap
inst.x = x; inst.y = y; inst.resize(w, h); inst.constraints = c;
// Note: old component properties are gone — set new properties after swap
```

### Component Gotchas

- **`componentPropertyDefinitions`** is only accessible on COMPONENT_SET nodes, NOT on individual variant COMPONENTs within the set
- **`instance.swapComponent(node)`** requires a COMPONENT node, NOT a COMPONENT_SET. If the target is a COMPONENT_SET, get a specific child variant first: `const variant = componentSet.children[0]; instance.swapComponent(variant);`
- **`node.mainComponent`** — in dynamic-page mode, use `await node.getMainComponentAsync()` instead (sync version throws)

---

## Prototype Reactions and Navigation

Prototype connections are managed via the `reactions` property, available on nodes that implement `ReactionMixin`: FRAME, COMPONENT, INSTANCE, TEXT, RECTANGLE, ELLIPSE, VECTOR, POLYGON, STAR, LINE, and most shape nodes. GROUP nodes also expose `reactions` but **silently drop** them on write.

### Setting Reactions (Async Required)

```javascript
await node.setReactionsAsync([
  {
    trigger: { type: 'ON_CLICK' },
    actions: [{
      type: 'NODE',
      destinationId: '24:3025',
      navigation: 'NAVIGATE',
      transition: {
        type: 'SMART_ANIMATE',
        duration: 0.3,
        easing: { type: 'EASE_IN_AND_OUT' }
      },
      resetScrollPosition: true,
      resetInteractiveComponents: false
    }]
  }
]);
```

### Reaction Format

**`actions` array (plural) is required.** The singular `action` field is **deprecated**.

```javascript
// CORRECT — actions array (supports multi-action per trigger)
{ trigger: { type: 'ON_CLICK' }, actions: [{ type: 'NODE', ... }, { type: 'SET_VARIABLE', ... }] }

// WRONG — action singular (deprecated, will fail)
{ trigger: { type: 'ON_CLICK' }, action: { type: 'NODE', ... } }
```

### Trigger Types

| Trigger | Properties | Notes |
|---------|-----------|-------|
| `ON_CLICK` | — | Standard click/tap |
| `ON_HOVER` | — | **Reverts** on hover-out |
| `ON_PRESS` | — | **Reverts** on release |
| `ON_DRAG` | — | Drag/swipe gesture |
| `AFTER_TIMEOUT` | `timeout: number` (ms) | Auto-fire after delay |
| `MOUSE_ENTER` | `delay: number` (ms) | One-way (no revert) |
| `MOUSE_LEAVE` | `delay: number` (ms) | One-way (no revert) |
| `MOUSE_UP` | `delay: number` (ms) | One-way |
| `MOUSE_DOWN` | `delay: number` (ms) | One-way |
| `ON_KEY_DOWN` | `device`, `keyCodes: number[]` | Hardware input. `device`: `'KEYBOARD'\|'XBOX_ONE'\|'PS4'\|'SWITCH_PRO'\|'UNKNOWN_CONTROLLER'` |
| `ON_MEDIA_HIT` | `mediaHitTime: number` (seconds) | Video layers only |
| `ON_MEDIA_END` | — | Video layers only |

### Action Types

| Action | Key Properties | Notes |
|--------|---------------|-------|
| `NODE` | `destinationId`, `navigation`, `transition`, `resetScrollPosition`, `resetVideoPosition`, `resetInteractiveComponents` | All navigation flows |
| `BACK` | — | Go back in prototype history |
| `CLOSE` | — | Dismiss topmost overlay |
| `URL` | `url: string` | Open external link |
| `SET_VARIABLE` | `variableId`, `variableValue: VariableData` | Set variable value in prototype |
| `SET_VARIABLE_MODE` | `variableCollectionId`, `variableModeId` | Switch collection mode |
| `CONDITIONAL` | `conditionalBlocks: ConditionalBlock[]` | IF/ELSE branching logic |
| `UPDATE_MEDIA_RUNTIME` | `destinationId?`, `mediaAction` | Video control (`PLAY`, `PAUSE`, `TOGGLE_PLAY_PAUSE`, `MUTE`, `UNMUTE`, `TOGGLE_MUTE_UNMUTE`) |

### Navigation Types (on NODE action)

| Navigation | Behavior |
|-----------|----------|
| `NAVIGATE` | Replace current screen, closes overlays |
| `OVERLAY` | Open destination as overlay layer |
| `SWAP` | Replace current overlay (or navigate without history entry) |
| `SCROLL_TO` | Scroll within current frame to target node |
| `CHANGE_TO` | Switch nearest ancestor instance to destination variant (interactive components) |

### Transitions and Easing

| Category | Transition Types |
|----------|-----------------|
| Simple | `DISSOLVE`, `SMART_ANIMATE`, `SCROLL_ANIMATE` |
| Directional | `MOVE_IN`, `MOVE_OUT`, `PUSH`, `SLIDE_IN`, `SLIDE_OUT` (+ `direction`: `'LEFT'\|'RIGHT'\|'TOP'\|'BOTTOM'`) |
| Instant | `transition: null` |

Transition properties: `duration` (seconds), `easing` (object).

**Easing types:**

| Category | Values |
|----------|--------|
| Preset bezier | `LINEAR`, `EASE_IN`, `EASE_OUT`, `EASE_IN_AND_OUT`, `EASE_IN_BACK`, `EASE_OUT_BACK`, `EASE_IN_AND_OUT_BACK` |
| Spring presets | `GENTLE`, `QUICK`, `BOUNCY`, `SLOW` |
| Custom bezier | `CUSTOM_CUBIC_BEZIER` — requires `easingFunctionCubicBezier: { x1, y1, x2, y2 }` |
| Custom spring | `CUSTOM_SPRING` — requires `easingFunctionSpring: { mass, stiffness, damping, initialVelocity }` |

### Overlay Properties

Set on the **destination FrameNode** (readonly in Plugin API — set via Figma UI):

| Property | Values |
|----------|--------|
| `overlayPositionType` | `CENTER`, `TOP_LEFT`, `TOP_CENTER`, `TOP_RIGHT`, `BOTTOM_LEFT`, `BOTTOM_CENTER`, `BOTTOM_RIGHT`, `MANUAL` |
| `overlayBackground` | `{ type: 'NONE' }` or `{ type: 'SOLID_COLOR', color: RGBA }` |
| `overlayBackgroundInteraction` | `NONE`, `CLOSE_ON_CLICK_OUTSIDE` |

For `MANUAL` positioning, the NODE action includes `overlayRelativePosition: { x, y }`.

### Conditional Prototyping (SET_VARIABLE + CONDITIONAL)

```javascript
// Multi-action: set a variable AND navigate conditionally
await node.setReactionsAsync([{
  trigger: { type: 'ON_CLICK' },
  actions: [
    // Action 1: Set a variable
    {
      type: 'SET_VARIABLE',
      variableId: isLoggedIn.id,
      variableValue: { type: 'BOOLEAN', resolvedType: 'BOOLEAN', value: true }
    },
    // Action 2: Conditional navigation
    {
      type: 'CONDITIONAL',
      conditionalBlocks: [{
        condition: { type: 'EXPRESSION', resolvedType: 'BOOLEAN',
          value: { expressionFunction: 'EQUALS',
            expressionArguments: [
              { type: 'VARIABLE_ALIAS', resolvedType: 'BOOLEAN',
                value: { type: 'VARIABLE_ALIAS', id: isLoggedIn.id } },
              { type: 'BOOLEAN', resolvedType: 'BOOLEAN', value: true }
            ]
          }
        },
        actions: [{ type: 'NODE', destinationId: dashboardId, navigation: 'NAVIGATE',
          transition: { type: 'SMART_ANIMATE', duration: 0.3, easing: { type: 'EASE_OUT' } } }]
      }, {
        // ELSE block (no condition)
        actions: [{ type: 'NODE', destinationId: signupId, navigation: 'OVERLAY',
          transition: { type: 'DISSOLVE', duration: 0.2, easing: { type: 'EASE_OUT' } } }]
      }]
    }
  ]
}]);
```

> **Caveat**: The exact `VariableData` nesting structure for CONDITIONAL actions is synthesized from multiple research sources. Verify against `@figma/plugin-typings` (`Reaction`, `Action`, `ConditionalBlock` types) before production use — field names or nesting depth may differ.

**Expression functions** for conditions: `EQUALS`, `NOT_EQUAL`, `LESS_THAN`, `LESS_THAN_OR_EQUAL`, `GREATER_THAN`, `GREATER_THAN_OR_EQUAL`, `AND`, `OR`, `NOT`, `NEGATE`, `ADDITION`, `SUBTRACTION`, `MULTIPLICATION`, `DIVISION`, `VAR_MODE_LOOKUP`.

### Node Type Support

| Node Type | Supports reactions? | Notes |
|-----------|-------------------|-------|
| FRAME | Yes | Primary target |
| COMPONENT | Yes | Works on component masters |
| INSTANCE | Yes | Works on instances |
| TEXT | Yes | Via `ReactionMixin` |
| RECTANGLE, ELLIPSE, VECTOR, POLYGON, STAR, LINE | Yes | Via `ReactionMixin` |
| GROUP | **Silently drops** | `reactions` property exists but `setReactionsAsync` silently discards. Verify after write |

**Always verify after wiring:**
```javascript
await node.setReactionsAsync(reactions);
const actual = node.reactions;
if (actual.length === 0 && reactions.length > 0) {
  console.log(JSON.stringify({ warning: "Reactions dropped", nodeType: node.type, nodeId: node.id }));
}
```

---

## Variables — Programmatic Binding

```javascript
// Create collection and variables
const collection = figma.variables.createVariableCollection("design-tokens")
collection.renameMode(collection.modes[0].modeId, "light")
const darkModeId = collection.addMode("dark")

const primaryColor = figma.variables.createVariable("primary", collection, "COLOR")
primaryColor.setValueForMode(collection.modes[0].modeId, { r: 0.2, g: 0.4, b: 1 })
primaryColor.setValueForMode(darkModeId, { r: 0.4, g: 0.6, b: 1 })
// Types: 'BOOLEAN' | 'FLOAT' | 'STRING' | 'COLOR'

// Bind to node properties
node.setBoundVariable('paddingTop', spacingVariable)
node.setBoundVariable('itemSpacing', spacingVariable)

// Bind COLOR to fills (requires helper)
const boundPaint = figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', colorVariable
)
node.fills = [boundPaint]

// Set explicit mode
frame.setExplicitVariableModeForCollection(collection, darkModeId)

// Scoping
// Variable scoping — controls where the variable appears in Figma's UI
colorVar.scopes = ['ALL_FILLS']
// Available scopes: 'ALL_SCOPES', 'TEXT_CONTENT', 'CORNER_RADIUS', 'WIDTH_HEIGHT',
// 'GAP', 'ALL_FILLS', 'FRAME_FILL', 'SHAPE_FILL', 'TEXT_FILL', 'STROKE_COLOR',
// 'STROKE_FLOAT', 'EFFECT_FLOAT', 'EFFECT_COLOR', 'OPACITY', 'FONT_FAMILY',
// 'FONT_STYLE', 'FONT_WEIGHT', 'FONT_SIZE', 'LINE_HEIGHT', 'LETTER_SPACING',
// 'PARAGRAPH_SPACING', 'PARAGRAPH_INDENT'

// Resolve value for a specific consumer node (respects mode inheritance)
const resolved = variable.resolveForConsumer(node)
// { value: { r: 0.4, g: 0.6, b: 1 }, resolvedType: 'COLOR' }

// Retrieve existing
const collections = await figma.variables.getLocalVariableCollectionsAsync()
const colorVars = await figma.variables.getLocalVariablesAsync('COLOR')
const variable = await figma.variables.getVariableByIdAsync(id)
```

### Variable Aliases

Aliases create semantic tokens that reference other variables (similar to CSS custom property chains):

```javascript
// Create a primitive token
const blue500 = figma.variables.createVariable("blue-500", collection, "COLOR")
blue500.setValueForMode(lightModeId, figma.util.rgb('#3B82F6'))

// Create a semantic alias pointing to the primitive
const primaryColor = figma.variables.createVariable("primary", collection, "COLOR")
primaryColor.setValueForMode(lightModeId, figma.variables.createVariableAlias(blue500))
primaryColor.setValueForMode(darkModeId, figma.variables.createVariableAlias(blue300))

// Async version (when only the variable ID is available)
const alias = await figma.variables.createVariableAliasByIdAsync(variableId)
```

**Resolving aliases** — `resolveForConsumer` follows the alias chain:
```javascript
const resolved = primaryColor.resolveForConsumer(someNode)
// { value: { r: 0.23, g: 0.51, b: 0.96 }, resolvedType: 'COLOR' }
```

### Code Syntax

Map variable names to platform-specific code tokens:

```javascript
variable.codeSyntax  // readonly: { WEB?: string, ANDROID?: string, iOS?: string }
variable.setVariableCodeSyntax("WEB", "--color-primary")
variable.setVariableCodeSyntax("ANDROID", "colorPrimary")
variable.setVariableCodeSyntax("iOS", "ColorPrimary")
variable.removeVariableCodeSyntax("ANDROID")  // remove single platform
```

### Complete Binding Targets

**Node-level** (`node.setBoundVariable(field, variable)`):

`height`, `width`, `visible`, `opacity`, `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius`, `paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft`, `itemSpacing`, `counterAxisSpacing`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `strokeWeight`, `strokeTopWeight`, `strokeRightWeight`, `strokeBottomWeight`, `strokeLeftWeight`, `gridRowGap`, `gridColumnGap`, `characters`

**Text-level** (`textNode.setBoundVariable(field, variable)` or `textNode.setRangeBoundVariable(start, end, field, variable)`):

`fontFamily`, `fontSize`, `fontStyle`, `fontWeight`, `letterSpacing`, `lineHeight`, `paragraphSpacing`, `paragraphIndent`

**Effect-level** (`figma.variables.setBoundVariableForEffect(effect, field, variable)`):

`radius`, `color`, `spread`, `offsetX`, `offsetY` (shadow); `radius` (blur). Returns modified Effect — reassign to node.

**LayoutGrid-level** (`figma.variables.setBoundVariableForLayoutGrid(grid, field, variable)`):

`sectionSize`, `count`, `offset`, `gutterSize`. Returns modified LayoutGrid — reassign to node.

```javascript
// Effect variable binding example
const shadow = node.effects[0]
const boundShadow = figma.variables.setBoundVariableForEffect(shadow, 'radius', blurVar)
node.effects = [boundShadow]

// LayoutGrid variable binding example
const grid = node.layoutGrids[0]
const boundGrid = figma.variables.setBoundVariableForLayoutGrid(grid, 'gutterSize', spacingVar)
node.layoutGrids = [boundGrid]
```

### Import from Library

```javascript
// Import a published library variable by key
const importedVar = await figma.variables.importVariableByKeyAsync("abc123def456")
// Bind to fills via paint helper (setBoundVariable does not work for fills directly)
const boundPaint = figma.variables.setBoundVariableForPaint(
  { type: 'SOLID', color: { r: 0, g: 0, b: 0 } }, 'color', importedVar
)
node.fills = [boundPaint]
```

### Plan-Based Limits

| Plan | Modes per Collection | Extended Collections |
|------|---------------------|---------------------|
| Starter | 1 | No |
| Professional | 10 | No |
| Organization | 20 | No |
| Enterprise | 40 | Yes (`extendLibraryCollectionByKeyAsync`) |

Variables per collection: 5,000 (all plans).

---

## Coordinates, Sizing, and Styles

| Concept | Details |
|---------|---------|
| `x`, `y` | Relative to **parent**. Ignored on auto-layout children unless `ABSOLUTE` |
| `width`, `height` | **READ-ONLY**. Use `resize()` or `resizeWithoutConstraints()` |
| `absoluteBoundingBox` | `{ x, y, width, height }` on page (read-only) |
| `constraints` | Non-auto-layout children: `{ horizontal: 'MIN'\|'CENTER'\|'MAX'\|'STRETCH'\|'SCALE', vertical: same }` |

**Creating and applying styles:**
```javascript
// Paint style
const style = figma.createPaintStyle()
style.name = "Colors/Brand/Primary"  // slash = folder nesting
style.paints = [{ type: 'SOLID', color: { r: 0.2, g: 0.5, b: 1 } }]
await node.setFillStyleIdAsync(style.id)

// Text style
const headingStyle = figma.createTextStyle()
headingStyle.name = "Typography/Heading/H1"
headingStyle.fontName = { family: 'Inter', style: 'Bold' }
headingStyle.fontSize = 32
headingStyle.lineHeight = { value: 40, unit: 'PIXELS' }
await textNode.setTextStyleIdAsync(headingStyle.id)

// Effect style
const shadow = figma.createEffectStyle()
shadow.name = "Effects/Shadow/Card"
shadow.effects = [{ type: 'DROP_SHADOW', color: { r: 0, g: 0, b: 0, a: 0.15 },
  offset: { x: 0, y: 4 }, radius: 8, visible: true, blendMode: 'NORMAL' }]
await frame.setEffectStyleIdAsync(shadow.id)
```

**Gotcha — `style.remove()`:** After calling `style.remove()`, do NOT access any properties on the removed style object. Cache `name` and `id` before deletion:

```javascript
// CORRECT — cache before remove
const styleName = style.name;
const styleId = style.id;
style.remove();
console.log(`Removed style: ${styleName} (${styleId})`);

// WRONG — accessing after remove throws
style.remove();
console.log(style.name);  // throws: node has been removed
```

---

## figma_execute Return Value Behavior

Understanding how `figma_execute` handles return values is critical for reliable data retrieval.

### Sync Return (Works)

Top-level synchronous `return` statements are captured in the `result` field of the response:

```javascript
// This return value IS captured in response.result
const hp = figma.root.children.find(p => p.name === "Handoff");
const nodes = hp.children.map(n => ({ id: n.id, name: n.name, type: n.type }));
return JSON.stringify({ count: hp.children.length, nodes });
// Response: { "success": true, "result": "{\"count\":2,...}", "timestamp": ... }
```

**Use for:** Data retrieval, node queries, status checks — anything that doesn't require `await`.

### Async IIFE Return (Does NOT Work)

The return value of an `async` IIFE is a Promise. The Desktop Bridge does NOT await Promises, so it sees `undefined`:

```javascript
// This return value is LOST — bridge logs "Code returned undefined"
(async () => {
  await figma.loadFontAsync({ family: "Inter", style: "Regular" });
  const frame = figma.createFrame();
  return JSON.stringify({ id: frame.id });  // ← Promise, NOT captured
})()
// Response: { "success": true, "timestamp": ... }  ← no "result" field
```

**Use async IIFE for:** Operations requiring `await` (font loading, `getNodeByIdAsync`, `setReactionsAsync`).

### Recommended Pattern: Split Calls

For operations that need both `await` and data retrieval, use two separate `figma_execute` calls:

```javascript
// Call 1 (async IIFE): Perform mutation
(async () => {
  try {
    await figma.loadFontAsync({ family: "DM Sans", style: "Regular" });
    const frame = figma.createFrame();
    frame.name = "MyScreen";
    // ... complex async operations
    console.log(JSON.stringify({ success: true }));
  } catch(e) {
    console.log(JSON.stringify({ error: e.message }));
  }
})()

// Call 2 (sync): Retrieve results
const hp = figma.root.children.find(p => p.name === "Handoff");
const nodes = hp.children.map(n => ({ id: n.id, name: n.name }));
return JSON.stringify({ nodes });
```

### console.log Reliability

`console.log()` inside `figma_execute` writes to the Figma console buffer, retrievable via `figma_get_console_logs`. However:

- **Buffer holds ~100 entries** — call `figma_clear_console` before batch operations
- **Buffer may stop updating** after context compaction or bridge reconnect — `figma_get_console_logs` may not show new entries
- **Prefer sync return** over `console.log` for data retrieval whenever possible

---

## State Tracking Across Calls

Each `figma_execute` call is stateless. Return serializable data (never raw node objects) and use IDs for cross-call references:

```javascript
// Call 1: Create and return IDs
return { frameId: frame.id, children: frame.children.map(c => ({ id: c.id, name: c.name })) }

// Call 2: Reference by ID (O(1) lookup — fastest)
const frame = await figma.getNodeByIdAsync("1:23")

// Find by unique name (fallback)
const hero = figma.currentPage.findOne(n => n.name === "hero-section")

// Optimized search for large documents
figma.skipInvisibleInstanceChildren = true
const frames = figma.currentPage.findAllWithCriteria({ types: ['FRAME'] })
```

### globalThis for Cross-Call Data Persistence

Use `globalThis.__key = value` inside async IIFEs to persist data across separate `figma_execute` calls. The async IIFE writes data to `globalThis`, then a subsequent sync call reads it back:

```javascript
// Call 1 (async IIFE): Create nodes, persist IDs via globalThis
(async () => {
  const comp = figma.createComponent();
  comp.name = "MyComponent";
  globalThis.__myResult = { componentId: comp.id };
})()

// Call 2 (sync): Read persisted data
return JSON.stringify(globalThis.__myResult);
// { "componentId": "24:5678" }
```

Use unique key names per operation to avoid collisions. This is the most reliable pattern for async-to-sync data handoff when the async IIFE return is not needed.

---

## Performance Optimization

### Search Performance

```javascript
// CRITICAL: Set before any search operations on large documents
figma.skipInvisibleInstanceChildren = true

// Prefer type-filtered search (hundreds of times faster than findAll)
const frames = figma.currentPage.findAllWithCriteria({ types: ['FRAME'] })
const texts = figma.currentPage.findAllWithCriteria({ types: ['TEXT'] })

// AVOID: Unfiltered search scans every node including invisible instance children
// const allNodes = figma.currentPage.findAll()  // slow on large documents
```

### Batch Viewport Updates

```javascript
// CORRECT: Collect all created nodes, update viewport once
const createdNodes = []
for (const item of items) {
  const node = figma.createFrame()
  // ... configure node
  createdNodes.push(node)
}
figma.viewport.scrollAndZoomIntoView(createdNodes)  // single call at end

// AVOID: Calling scrollAndZoomIntoView per node in a loop
```

### Dynamic Page Loading

In dynamic-page mode (default for Console MCP), pages other than `currentPage` are lazily loaded. Many sync APIs throw or return stale data.

```javascript
// Load all pages upfront (preferred for cross-page workflows)
await figma.loadAllPagesAsync();

// Or load a specific page
const otherPage = figma.root.children.find(p => p.name === "Components")
if (otherPage) {
  await otherPage.loadAsync()  // load children before accessing
  const components = otherPage.findAllWithCriteria({ types: ['COMPONENT'] })
}
```

**Sync vs Async API in dynamic-page mode:**

| Operation | Sync (throws) | Async (use this) |
|-----------|--------------|-------------------|
| Get node by ID | `figma.getNodeById("1:23")` | `await figma.getNodeByIdAsync("1:23")` |
| Get main component | `instance.mainComponent` | `await instance.getMainComponentAsync()` |
| Set reactions | `node.reactions = [...]` | `await node.setReactionsAsync([...])` |
| Set vector network | `node.vectorNetwork = {...}` | `await node.setVectorNetworkAsync({...})` |
| Get local styles | `figma.getLocalTextStyles()` | `await figma.getLocalTextStylesAsync()` |
| Get local variables | — | `await figma.variables.getLocalVariablesAsync()` |

**Safe sync operations** (work without loading):
- `figma.root.children` — page list is always available
- `figma.root.children.find(p => p.name === "X")` — page metadata is available
- `page.findOne(n => n.id === "X")` — works if the page is loaded or is currentPage
- `node.clone()` — works on any accessible node

### Font Check Before Loading

```javascript
// Check for missing fonts on user-created text nodes before loading
if (textNode.hasMissingFont) {
  // Font file is not installed — loadFontAsync will fail
  // Handle gracefully: skip modification or notify user
} else {
  // Safe to load and modify
  await Promise.all(
    textNode.getRangeAllFontNames(0, textNode.characters.length).map(figma.loadFontAsync)
  )
}
```

> For complete working code recipes (cards, buttons, inputs, M3 components, composition patterns), see `recipes-components.md`, `recipes-advanced.md`, and `recipes-m3.md`. For common mistakes and fixes, see `anti-patterns.md`.