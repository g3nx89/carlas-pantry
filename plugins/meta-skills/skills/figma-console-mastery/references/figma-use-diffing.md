# figma-use — Diffing, Queries & Specialty Operations

> **Compatibility**: figma-use v0.11.3 (February 2026). Pre-1.0 — API surface may change.
>
> **Prerequisite**: figma-use server connected via CDP. See `figma-use-overview.md` for setup.
>
> **Scope**: Visual/structural diffing, XPath queries, boolean operations, vector path manipulation, arrange algorithms, Storybook export, and comment-driven workflows. For analysis tools, see `figma-use-analysis.md`. For JSX rendering, see `figma-use-jsx-patterns.md`.

## Visual Diffing

### figma_diff_visual

Pixel-by-pixel comparison of two Figma nodes, producing a PNG highlighting changes in red.

**Parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `from` | Yes | string | — | Source node ID |
| `to` | Yes | string | — | Target node ID |
| `output` | Yes | string | — | Output file path for the diff PNG |
| `scale` | No | number | 1 | Export scale (2 for retina) |
| `threshold` | No | number | 0.1 | Color sensitivity threshold 0-1 (lower = more sensitive) |

**Output**: Saves a PNG where unchanged pixels are dimmed and changed pixels are highlighted in red. Console output reports: `N pixels differ (X.XX%)`.

**Prerequisites**: Requires `pngjs` and `pixelmatch` installed (`npm install pngjs pixelmatch`). Both nodes must have the same dimensions for accurate comparison.

**When to use**: Visual regression checking after restructuring, verifying that a refactored layout matches the original, validating Phase 5 (Polish) visual fidelity in the Restructuring Workflow.

**Workflow Pattern**:
1. Before changes: `figma_export_node(id="1:23", output="/tmp/before.png")`
2. Apply changes via `figma_execute` or `figma_set_*` tools
3. After changes: `figma_diff_visual(from="1:23", to="1:24", output="/tmp/diff.png")`
4. Inspect the diff PNG — red areas indicate visual changes

---

### figma_diff_create

Creates a git-style text diff of node property trees.

**Parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `from` | Yes | string | — | Source node ID |
| `to` | Yes | string | — | Target node ID |
| `depth` | No | number | 10 | Maximum tree depth to compare |

**Output**: Unified diff format showing property differences:

```diff
--- /Card/Header #123:457
+++ /Card/Header #789:013
 type: FRAME
 size: 200 50
-fill: #FFFFFF
+fill: #F0F0F0
```

**When to use**: Auditing what changed structurally between two versions of a design element. Useful for design review and documenting changes.

---

### figma_diff_show

Previews what would change without applying — a dry-run visualization.

**Parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `id` | Yes | string | — | Target node ID |
| `fill` | No | string | — | Proposed fill color |
| `opacity` | No | number | — | Proposed opacity |
| (other props) | No | — | — | Any property to preview |

**When to use**: Always before `figma_diff_apply` — preview proposed changes to verify correctness.

---

### figma_diff_apply

Applies a patch file to nodes, with safety options.

**Parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `file` | No | string | — | Path to patch file |
| `stdin` | No | boolean | false | Read patch from stdin |
| `dry-run` | No | boolean | false | Preview changes without applying |
| `force` | No | boolean | false | Skip old-value validation (apply even if current state differs) |

**Supported changes**: `fill`, `stroke`, `opacity`, `radius`, `size`, `pos`, `text`, `visible`, `locked`.

**Safety**: By default, validates that the current node state matches the "old" values in the patch. If values have drifted, the patch is rejected unless `--force` is used. Always use `--dry-run` first.

**Limitation**: Does not create new nodes — for additions, use `figma_render` (see `figma-use-jsx-patterns.md`).

---

### figma_diff_jsx

Compares two nodes at the JSX level — shows differences in the exported JSX representation rather than raw properties.

**Parameters**:

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| `from-id` | Yes | string | Source node ID |
| `to-id` | Yes | string | Target node ID |

**When to use**: Comparing design variants at a structural level. More readable than property diffs for designers familiar with JSX.

## XPath Queries

### figma_query

Queries the Figma node tree using XPath 3.1 expressions (powered by fontoxpath). Returns matching nodes with selected fields.

**Parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `selector` | Yes | string | — | XPath expression |
| `root` | No | string | current page | Node ID to scope the search |
| `select` | No | string | `"id,name,type"` | Comma-separated fields to return |
| `limit` | No | number | 1000 | Maximum results |

### Queryable Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `name` | string | Node name |
| `width` | number | Node width |
| `height` | number | Node height |
| `x` | number | X position |
| `y` | number | Y position |
| `cornerRadius` | number | Corner radius |
| `opacity` | number | Opacity (0-1) |
| `visible` | boolean | Visibility |
| `characters` | string | Text content (TEXT nodes only) |
| `fontSize` | number | Font size (TEXT nodes only) |
| `layoutMode` | string | Auto-layout mode (VERTICAL/HORIZONTAL/NONE) |
| `itemSpacing` | number | Auto-layout gap |
| `paddingTop` | number | Top padding |
| `paddingRight` | number | Right padding |
| `paddingBottom` | number | Bottom padding |
| `paddingLeft` | number | Left padding |
| `strokeWeight` | number | Stroke weight |
| `rotation` | number | Rotation in degrees |

### Supported XPath Functions

`contains()`, `starts-with()`, `string-length()`, `not()`, `and`, `or`

Axes: `/` (child), `//` (descendant), `..` (parent)

### Practical Query Examples

| Query | Purpose |
|-------|---------|
| `//FRAME[@width < 300]` | Find narrow frames |
| `//TEXT[contains(@name, 'Title')]` | Find all title text layers |
| `//FRAME[@layoutMode = 'NONE']` | Find non-auto-layout frames (restructuring audit) |
| `//*[@opacity < 1]` | Find semi-transparent elements |
| `//COMPONENT[starts-with(@name, 'Button')]` | Find button components by name prefix |
| `//INSTANCE[not(@visible)]` | Find hidden component instances |
| `//FRAME[@width > 100 and @width < 500]` | Find medium-width frames |
| `//TEXT[@characters = 'Submit']` | Find text nodes with exact content |
| `//SECTION/FRAME` | Find direct frame children of sections |
| `//FRAME[contains(@name, 'Card')]` | Find all card-related frames |

### XPath in the Restructuring Workflow

`figma_query` can replace or augment the Node Tree Analysis recipe from `recipes-restructuring.md` for targeted structural queries:

- **Find non-auto-layout frames**: `//FRAME[@layoutMode = 'NONE']` — instant list of frames needing conversion
- **Find hardcoded spacing**: `//FRAME[@itemSpacing > 0 and @itemSpacing mod 4 != 0]` — off-4px-grid gaps
- **Find unnamed nodes**: `//*[starts-with(@name, 'Frame ') or starts-with(@name, 'Rectangle ')]` — generic auto-names
- **Scope to selection**: use `root` parameter to limit queries to a specific subtree

## Additional Capabilities

### Boolean Operations

Dedicated tools for boolean shape operations — cleaner than the `figma_execute` equivalent with `figma.union()`, `figma.subtract()`, etc.

| Tool | Operation | Input |
|------|-----------|-------|
| `figma_boolean_union` | Merge shapes into one | Space-separated node IDs |
| `figma_boolean_subtract` | First shape minus rest | Space-separated node IDs |
| `figma_boolean_intersect` | Keep only overlapping area | Space-separated node IDs |
| `figma_boolean_exclude` | Remove overlapping area | Space-separated node IDs |

All operations return the resulting node ID. Minimum 2 node IDs required.

---

### Vector Path Manipulation

Direct SVG path editing without Plugin API code.

| Tool | Purpose | Key Parameters |
|------|---------|---------------|
| `figma_path_get` | Get SVG path data string | `id` |
| `figma_path_set` | Replace path with new SVG path | `id`, SVG path string |
| `figma_path_move` | Translate path | `id`, `dx`, `dy` |
| `figma_path_scale` | Scale path from origin | `id`, `factor`, optional `origin-x`/`origin-y` |
| `figma_path_flip` | Mirror path on axis | `id`, `axis` (`x` or `y`) |

**Workflow**: Create vector → export screenshot to check → refine with path tools → re-export.

For complex illustrations or icons from file: `figma_import --svg "$(cat icon.svg)"` imports an SVG string directly.

---

### Arrange Algorithms

Canvas organization tools for tidying up scattered nodes.

| Mode | Description | Best For |
|------|-------------|----------|
| `grid` | Standard grid layout | Even-sized elements (default) |
| `row` | Single horizontal row | Navigation items, button groups |
| `column` | Single vertical stack | List items, form fields |
| `squarify` | d3-hierarchy treemap packing | Mixed-size frames (size-aware) |
| `binary` | Balanced binary split | Balanced mixed-size layouts |

**Parameters**: `figma_arrange(ids?, mode, gap, cols, width)`

- `ids` — optional; defaults to all top-level children on the current page
- `gap` — spacing between nodes (default: 40)
- `cols` — column count for grid mode (default: auto)
- `width` — bounding width for squarify/binary modes

**When to use**: After batch-creating multiple components or frames, organizing a component library page, or tidying up after a restructuring session.

---

### Storybook Export (Experimental)

Converts Figma ComponentSets into React or Vue components with Storybook stories.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `out` | `./stories` | Output directory |
| `page` | `"Components"` | Figma page to export from |
| `match-icons` | false | Match vectors to Iconify icons |
| `prefer-icons` | — | Preferred icon sets (comma-separated) |
| `framework` | `react` | Target framework: `react` or `vue` |

**Output files**: `Component.tsx` (typed component), `Component.stories.tsx` (Storybook stories with args), `fonts.css` (Google Fonts imports).

**Property mapping**: VARIANT properties → union type props, TEXT properties → editable string props.

**Caveat**: Experimental in v0.11.3. May not handle all ComponentSet structures correctly. Verify generated code before use.

---

### Comment-Driven Workflows

Event-driven design automation triggered by Figma comments.

| Tool | Purpose |
|------|---------|
| `figma_comment_add` | Post a comment at specific coordinates, with optional reply |
| `figma_comment_list` | List all comments on the file |
| `figma_comment_delete` | Delete a comment |
| `figma_comment_resolve` | Resolve (close) a comment thread |
| `figma_comment_watch` | **Poll for new comments** — blocks until a new comment arrives |

**`figma_comment_watch` parameters**: `interval` (poll frequency, default: 3s), `timeout` (max wait, seconds), `include-resolved` (boolean).

**Output** (JSON):

```json
{
  "id": "123456",
  "message": "Make this button bigger",
  "user": { "handle": "designer" },
  "client_meta": { "node_id": "1:23" }
}
```

The `client_meta.node_id` field contains the specific Figma node under the comment pin — this enables targeted automated responses.

**Agent workflow pattern**:
1. `figma_comment_watch` → wait for new comment
2. Parse `message` and `node_id`
3. Apply changes to the target node using `figma_set_*` or `figma_execute`
4. `figma_comment_add(reply=comment_id, message="Done — resized to 48px")` → reply
5. `figma_comment_resolve(id=comment_id)` → close thread
6. Loop back to step 1

**When to use**: Automated design review response, designer-in-the-loop workflows where designers leave feedback as comments and an AI agent responds.
