# figma-use — JSX Rendering Patterns

> **Compatibility**: figma-use v0.11.3 (February 2026). Pre-1.0 — API surface may change.
>
> **Prerequisite**: figma-use server connected via CDP. See `figma-use-overview.md` for setup.
>
> **Scope**: JSX rendering via `figma_render`, shorthand props, translation from Plugin API, and JSX-only capabilities. For Plugin API patterns using `figma_execute`, see `recipes-foundation.md` and `recipes-components.md`.

---

## How figma_render Works

`figma_render` accepts a JSX string, transpiles it client-side via esbuild, walks the tree into a JSON structure, and sends the entire tree to Figma in a single CDP call. On the Figma side, `figma.createNodeFromJSXAsync()` creates all nodes atomically and returns the root node ID.

**Key characteristics:**

- **Token efficiency**: JSX ~120 characters vs Plugin API ~450+ characters for the same component (2-4x saving)
- **Single-call creation**: An entire multi-node tree is created in one `figma_render` invocation — no sequential `figma_execute` calls needed
- **Not React**: No hooks, no state, no lifecycle — pure declarative structure describing Figma nodes
- **Atomic creation**: All nodes in the JSX tree are created together; partial failures do not leave orphaned nodes

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `jsx` | Yes | JSX string to render |
| `x` | No | X position on canvas (default: 0) |
| `y` | No | Y position on canvas (default: 0) |
| `parent` | No | Parent node ID to render into |

### Important Rules

1. Always provide `x` and `y` to avoid stacking at (0,0) when rendering multiple trees
2. Always call `figma_viewport_zoom_to_fit` after rendering to see the result
3. Always verify with `figma_export_node` for visual validation
4. After initial render, prefer individual `figma_set_*` commands or `figma_diff_apply` for modifications — avoid re-rendering entire JSX trees
5. Row layouts need explicit width: `<Frame w={300} flex="row">` — without width, row frames collapse to 1x1

---

## Shorthand Props Reference

All JSX elements accept shorthand props that map to Figma node properties. The shorthands follow CSS/Tailwind naming conventions for familiarity.

### Size and Position

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `w` | width | number or `"fill"` | `w={320}` or `w="fill"` |
| `h` | height | number or `"fill"` | `h={400}` |
| `minW` | minWidth | number | `minW={200}` |
| `maxW` | maxWidth | number | `maxW={600}` |
| `minH` | minHeight | number | `minH={100}` |
| `maxH` | maxHeight | number | `maxH={400}` |
| `x` | x position | number | `x={100}` |
| `y` | y position | number | `y={200}` |

### Layout

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `flex` | flexDirection | `"row"`, `"col"` | `flex="col"` |
| `gap` | itemSpacing | number | `gap={16}` |
| `wrap` | layoutWrap | `true` | `wrap` |
| `justify` | justifyContent | `"start"`, `"center"`, `"end"`, `"between"` | `justify="center"` |
| `items` | alignItems | `"start"`, `"center"`, `"end"` | `items="center"` |
| `p` | padding (all sides) | number | `p={24}` |
| `px` | paddingLeft + paddingRight | number | `px={16}` |
| `py` | paddingTop + paddingBottom | number | `py={12}` |
| `pt` | paddingTop | number | `pt={8}` |
| `pr` | paddingRight | number | `pr={8}` |
| `pb` | paddingBottom | number | `pb={8}` |
| `pl` | paddingLeft | number | `pl={8}` |
| `position` | layoutPositioning | `"absolute"` | `position="absolute"` |
| `grow` | layoutGrow | number | `grow={1}` |
| `stretch` | layoutAlign STRETCH | `true` | `stretch` |

### Appearance

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `bg` | fill | hex or `$Variable` | `bg="#3B82F6"` or `bg="$Colors/Primary"` |
| `stroke` | strokeColor | hex | `stroke="#E5E7EB"` |
| `strokeWidth` | strokeWeight | number | `strokeWidth={1}` |
| `strokeAlign` | strokeAlign | `"inside"`, `"outside"` | `strokeAlign="inside"` |
| `opacity` | opacity | 0-1 | `opacity={0.8}` |
| `blendMode` | blendMode | `"multiply"`, `"screen"`, etc. | `blendMode="multiply"` |

### Corners and Effects

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `rounded` | cornerRadius | number | `rounded={12}` |
| `roundedTL` | topLeftRadius | number | `roundedTL={12}` |
| `roundedTR` | topRightRadius | number | `roundedTR={12}` |
| `roundedBL` | bottomLeftRadius | number | `roundedBL={12}` |
| `roundedBR` | bottomRightRadius | number | `roundedBR={12}` |
| `cornerSmoothing` | cornerSmoothing | 0-1 | `cornerSmoothing={0.6}` (iOS squircle) |
| `shadow` | dropShadow | CSS shadow string | `shadow="0px 4px 8px rgba(0,0,0,0.25)"` |
| `blur` | layerBlur | number | `blur={4}` |
| `overflow` | clipsContent | `"hidden"` | `overflow="hidden"` |
| `rotate` | rotation | degrees | `rotate={45}` |

### Text

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `size` | fontSize | number | `size={18}` |
| `weight` | fontWeight | `"bold"`, number | `weight="bold"` |
| `font` | fontFamily | string | `font="Roboto"` |
| `color` | textColor | hex | `color="#111827"` |

### CSS Grid

| Shorthand | Full Name | Values | Example |
|-----------|-----------|--------|---------|
| `display` | layoutMode | `"grid"` | `display="grid"` |
| `cols` | gridTemplateColumns | CSS-like string | `cols="100px 1fr auto"` |
| `rows` | gridTemplateRows | CSS-like string | `rows="auto auto"` |
| `colGap` | columnGap | number | `colGap={16}` |
| `rowGap` | rowGap | number | `rowGap={12}` |
| `gridTemplateColumns` | `string` | Long form of `cols` — e.g. `"1fr 2fr 1fr"` |
| `gridTemplateRows` | `string` | Long form of `rows` — e.g. `"auto auto auto"` |
| `columnGap` | `number` | Long form of `colGap` |

---

## Available Elements

Both PascalCase and lowercase forms are accepted:

`Frame`, `Rectangle`, `Ellipse`, `Text`, `Line`, `Star`, `Polygon`, `Vector`, `Group`, `Icon`, `Image`, `Instance`, `Page`

---

## Variable Binding Syntax

Two equivalent syntaxes for binding Figma variables in any color prop:

- **Dollar prefix**: `bg="$Colors/Primary"` or `color="$Text/Default"`
- **Var prefix**: `bg="var:Colors/Primary"` or `stroke="var:Border/Default"`

If the referenced variable does not exist, the `$` or `var:` prefix is treated as a literal string (no error thrown).

> For programmatic variable binding via Plugin API (`setBoundVariable`, `setBoundVariableForPaint`), see `recipes-advanced.md` — Variable Binding to Nodes recipe.

---

## Plugin API to JSX Translation Table

For each operation: the Plugin API approach is referenced by recipe file (not duplicated here), and the JSX equivalent is shown in full.

| Operation | Plugin API (reference) | JSX Equivalent |
|-----------|----------------------|----------------|
| Frame + vertical auto-layout + padding | `recipes-foundation.md` — Page Container recipe | `<Frame flex="col" gap={16} p={24} w={400} h="fill" bg="#FFF" />` |
| Text with font/size/weight | `recipes-foundation.md` — Font Preloading pattern | `<Text size={24} weight="bold" font="Inter" color="#000">Title</Text>` |
| Solid fill color | `plugin-api.md` — Colors section | `<Frame bg="#3B82F6" />` or `<Rectangle bg="#F00" w={100} h={100} />` |
| Rounded corners | `plugin-api.md` — Effects section | `<Frame rounded={12} />` or `<Frame roundedTL={12} roundedBR={12} />` |
| Drop shadow | `plugin-api.md` — Effects section | `<Frame shadow="0px 4px 12px rgba(0,0,0,0.15)" />` |
| Variable binding | `recipes-advanced.md` — Variable Binding recipe | `<Frame bg="$Colors/Primary" />` or `<Text color="var:Text/Default">` |
| Component instance | `figma-use-overview.md` — Node Creation tools | `<Instance component="COMPONENT_ID" />` |
| Nested hierarchy | `recipes-foundation.md` — all layout recipes | Nest elements: `<Frame><Frame><Text /></Frame></Frame>` |
| Horizontal row with fill children | `recipes-foundation.md` — Horizontal Row recipe | `<Frame flex="row" gap={12} w={400}><Frame grow={1} /><Frame grow={1} /></Frame>` |
| Wrap layout (tag cloud) | `recipes-foundation.md` — Wrap Layout recipe | `<Frame flex="row" wrap gap={8} w={300}>...</Frame>` |
| Absolute positioned badge | `recipes-foundation.md` — Absolute Badge recipe | `<Frame position="absolute" x={-8} y={-8}>...</Frame>` |

---

## JSX-Only Patterns

These patterns leverage capabilities unique to JSX rendering that have no direct `figma_execute` equivalent or would require significantly more code.

### Pattern 1: CSS Grid Layout

CSS Grid is native in `figma_render` JSX. The equivalent in `figma_execute` requires complex auto-layout workarounds.

```jsx
<Frame display="grid" cols="1fr 1fr 1fr" rows="auto auto" gap={16} p={24} bg="#F9FAFB" rounded={12}>
  <Frame bg="#3B82F6" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 1</Text></Frame>
  <Frame bg="#10B981" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 2</Text></Frame>
  <Frame bg="#F59E0B" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 3</Text></Frame>
  <Frame bg="#EF4444" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 4</Text></Frame>
  <Frame bg="#8B5CF6" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 5</Text></Frame>
  <Frame bg="#EC4899" rounded={8} p={16}><Text color="#FFF" size={14}>Cell 6</Text></Frame>
</Frame>
```

Grid unit types: `px` (fixed), `fr` (fractional), `auto` (content-sized).

**Grid child properties** (on direct children of a Grid frame):

| Prop | Type | Maps to |
|------|------|---------|
| `gridColumnSpan` | `number` | `gridColumnSpan` on the child node |
| `gridRowSpan` | `number` | `gridRowSpan` on the child node |

```jsx
<Frame display="grid" cols="1fr 1fr 1fr" gap={16}>
  <Frame gridColumnSpan={2} fill="#E8DEF8">Featured</Frame>
  <Frame fill="#F3EDF7">Card B</Frame>
  <Frame fill="#F3EDF7">Card C</Frame>
</Frame>
```

### Pattern 2: Iconify Icon Integration

Access 150K+ icons from any Iconify set in a single element. No SVG import or path manipulation needed.

```jsx
<Frame flex="row" gap={12} items="center" p={16} bg="#FFF" rounded={8}>
  <Icon name="mdi:home" size={24} color="#3B82F6" />
  <Text size={16} color="#111827">Home</Text>
</Frame>
```

Common icon sets: `mdi:` (Material Design Icons), `lucide:` (Lucide), `tabler:` (Tabler Icons), `heroicons:` (Heroicons), `ph:` (Phosphor).

Icon as component: `figma_create_icon --name "mdi:home" --component` creates a reusable Figma component from the icon.

### Pattern 3: Complex Single-Call Composition

An entire card grid in one `figma_render` call — what would require 4+ sequential `figma_execute` calls with the Plugin API:

```jsx
<Frame name="Card Grid" display="grid" cols="1fr 1fr 1fr" gap={24} p={32} bg="#F3F4F6">
  <Frame name="Card 1" flex="col" gap={12} p={20} bg="#FFF" rounded={12}
         shadow="0px 2px 8px rgba(0,0,0,0.1)">
    <Icon name="lucide:zap" size={32} color="#F59E0B" />
    <Text size={18} weight="bold" color="#111827">Performance</Text>
    <Text size={14} color="#6B7280">Optimized for speed and efficiency</Text>
  </Frame>
  <Frame name="Card 2" flex="col" gap={12} p={20} bg="#FFF" rounded={12}
         shadow="0px 2px 8px rgba(0,0,0,0.1)">
    <Icon name="lucide:shield" size={32} color="#3B82F6" />
    <Text size={18} weight="bold" color="#111827">Security</Text>
    <Text size={14} color="#6B7280">Enterprise-grade protection</Text>
  </Frame>
  <Frame name="Card 3" flex="col" gap={12} p={20} bg="#FFF" rounded={12}
         shadow="0px 2px 8px rgba(0,0,0,0.1)">
    <Icon name="lucide:users" size={32} color="#10B981" />
    <Text size={18} weight="bold" color="#111827">Collaboration</Text>
    <Text size={14} color="#6B7280">Built for teams of any size</Text>
  </Frame>
</Frame>
```

This single call creates 3 cards with icons, text hierarchy, and shadows — ~15 Figma nodes total.

### Pattern 4: Token-Bound Design

Variable binding throughout a component, connecting to existing Figma variables:

```jsx
<Frame flex="col" gap={16} p={24} bg="$Surface/Default" rounded={12}
       stroke="$Border/Default" strokeWidth={1}>
  <Text size={24} weight="bold" color="$Text/Primary">Dashboard</Text>
  <Text size={14} color="$Text/Secondary">Overview of key metrics</Text>
  <Frame flex="row" gap={12}>
    <Frame grow={1} p={16} bg="$Surface/Elevated" rounded={8}>
      <Text size={12} color="$Text/Tertiary">Revenue</Text>
      <Text size={28} weight="bold" color="$Text/Primary">$12,450</Text>
    </Frame>
    <Frame grow={1} p={16} bg="$Surface/Elevated" rounded={8}>
      <Text size={12} color="$Text/Tertiary">Users</Text>
      <Text size={28} weight="bold" color="$Text/Primary">1,234</Text>
    </Frame>
  </Frame>
</Frame>
```

All `$Variable/Name` references are resolved to Figma variables at render time. If the variable does not exist, the `$` prefix is treated as a literal string.

---

## Round-Trip Workflow: Export, Edit, Render

The round-trip workflow enables iterative design refinement through a three-step cycle.

### Step 1 — Export

Extract an existing Figma node as JSX:

```
figma_export_jsx(id="1:23", pretty=true)
```

Returns formatted JSX representing the node hierarchy with all visual properties preserved as shorthand props.

### Step 2 — Edit

Modify the exported JSX: add elements, change props, restructure the layout. The AI agent or user can refine the design in code form before re-rendering.

### Step 3 — Re-render

Render the modified JSX back into Figma:

```
figma_render(jsx="<modified JSX>", x=500, y=0)
```

Creates a new node tree from the modified JSX. The original remains untouched — rendering always creates new nodes.

### Use Cases

- "Take this card and add a dark mode variant" — export, swap colors, render at offset
- "Refactor this layout from absolute positioning to auto-layout" — export, restructure, render
- "Add icons to this navigation bar" — export, insert `<Icon>` elements, render

### Limitations

- Round-trip is not lossless: some Plugin API properties (complex effects, multi-paint fills) may not survive export then render
- Exported JSX uses figma-use's element syntax — not directly usable as React code
- Large trees (50+ nodes) may produce verbose JSX output; consider exporting subtrees instead

---

## Combining figma_render with figma_set_* Tools

JSX rendering creates the initial structure; subsequent modifications should use targeted tools rather than re-rendering:

| Task | Approach |
|------|----------|
| Initial creation | `figma_render` with full JSX tree |
| Change one fill color | `figma_set_fill` on the specific node ID |
| Update text content | `figma_set_text` on the text node ID |
| Resize a single node | `figma_node_resize` on the target node |
| Batch property changes | `figma_diff_apply` with a patch object |
| Major structural changes | Re-export with `figma_export_jsx`, edit, re-render |

This pattern minimizes unnecessary node recreation and preserves any manual adjustments made after the initial render.

---

## Common Gotchas

| Gotcha | Explanation | Fix |
|--------|-------------|-----|
| Row frame collapses to 1x1 | `flex="row"` without explicit `w` has no intrinsic width | Add `w={300}` or `w="fill"` |
| Text renders with default font | `font` prop only works if the font is installed on the system | Verify font availability; fall back to `"Inter"` |
| Nodes stack at origin | Multiple `figma_render` calls without `x`/`y` offsets | Always provide `x` and `y` params |
| Variable not bound | `$Variable/Name` treated as literal string | Variable must already exist in the file; check spelling and path |
| Shadow syntax rejected | Incorrect CSS shadow format | Use exact format: `"Xpx Ypx Rpx rgba(R,G,B,A)"` |
| Grid children misaligned | Missing `cols` or `rows` definition | Always specify at least `cols` when using `display="grid"` |
| Grid `display="grid"` without `cols` | Creates grid with 1 column (default) — probably not intended | Always specify `cols` (or `gridTemplateColumns`) when using grid display |
| Grid children missing `layoutSizingHorizontal="FILL"` | Children don't stretch to fill grid cells — look undersized | Add `layoutSizingHorizontal="FILL"` to grid children for responsive behavior |
| `h="fill"` ignored | Parent frame has no defined height or is not auto-layout | Ensure parent has `flex` and explicit dimensions |
| Instance not rendering | Wrong component ID | Use the full component ID from `figma_find` or node inspection |

---

## Naming Nodes in JSX

The `name` prop sets the layer name visible in the Figma layers panel. Follow slash-convention naming for organized hierarchies:

```jsx
<Frame name="Screen/Dashboard" flex="col" gap={16} p={24} bg="#FFF">
  <Frame name="Section/Header" flex="row" items="center" gap={12}>
    <Text name="Text/Title" size={24} weight="bold" color="#111827">Dashboard</Text>
  </Frame>
  <Frame name="Section/Metrics" flex="row" gap={12}>
    <Frame name="Card/Revenue" p={16} bg="#F9FAFB" rounded={8}>
      <Text name="Text/Label" size={12} color="#6B7280">Revenue</Text>
    </Frame>
  </Frame>
</Frame>
```

Omitting `name` causes Figma to assign generic names ("Frame 42", "Text 17"), making the layers panel difficult to navigate. Always name structural frames and significant elements.

> For naming conventions and rules, see `design-rules.md`.

---

## When NOT to Use figma_render

| Scenario | Better Alternative |
|----------|-------------------|
| Variable CRUD (create/update collections) | figma-console: `figma_setup_design_tokens`, `figma_batch_create_variables` |
| Complex component variant sets | figma-console: `figma_execute` with `combineAsVariants()` |
| Modifying existing node properties | figma-use: `figma_set_*` individual tools or `figma_diff_apply` |
| Plugin API methods not in JSX elements | figma-console: `figma_execute` or figma-use: `figma_eval` |
| Small property tweaks on existing nodes | figma-use: direct `figma_set_fill`, `figma_set_text`, etc. |
| Style creation (paint/text/effect styles) | figma-use: `figma_style_create_paint`, `figma_style_create_text`, `figma_style_create_effect` |
| Boolean operations on shapes | figma-use: `figma_boolean_union`, `figma_boolean_subtract`, etc. |
| Querying existing nodes | figma-use: `figma_query` (XPath) or `figma_find` (name/type search) |
