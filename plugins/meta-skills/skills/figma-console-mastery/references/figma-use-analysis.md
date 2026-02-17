# figma-use — Design Analysis Tools

> **Compatibility**: figma-use v0.11.3 (February 2026). Pre-1.0 — API surface may change.
>
> **Prerequisite**: figma-use server connected via CDP. See `figma-use-overview.md` for setup.
>
> **Scope**: Dedicated `figma_analyze_*` commands for design auditing. For figma-console equivalents using `figma_execute` code, see `recipes-restructuring.md`.

---

## Why Dedicated Analysis Commands

The figma-use server provides five dedicated analysis commands that return structured JSON
without requiring any `figma_execute` code. These complement the custom analysis recipes
in `recipes-restructuring.md`:

| Approach | Strengths | Limitations |
|----------|-----------|-------------|
| `figma_analyze_*` (figma-use) | No code to write, structured JSON output, consistent format | Fixed analysis logic, fewer customization options |
| `figma_execute` recipes (figma-console) | Fully customizable analysis, deeper property inspection | Requires writing Plugin API code, more tokens consumed |

**Guideline**: Use `figma_analyze_*` for quick discovery and initial audits. Switch to
`figma_execute` recipes from `recipes-restructuring.md` when deeper or custom analysis
is needed.

---

## Tool Reference

### figma_analyze_clusters

Finds repeated node patterns that are candidates for extraction as components.

**Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | number | 20 | Maximum clusters to return |
| `min-size` | number | 30 | Minimum node size in pixels (skip smaller nodes) |
| `min-count` | number | 2 | Minimum instances to form a cluster |

**Output Shape** (JSON):

```json
{
  "clusters": [
    {
      "signature": "FRAME:200x40|TEXT:1,FRAME:1",
      "nodes": [
        { "id": "1:23", "name": "Card Header", "width": 200, "height": 40, "type": "FRAME" }
      ],
      "avgWidth": 200,
      "avgHeight": 40,
      "widthRange": [195, 205],
      "heightRange": [38, 42],
      "confidence": 92
    }
  ],
  "totalNodes": 450
}
```

- `signature` — structural fingerprint: node type, size, and child composition
- `confidence` — 0-100 match confidence (computed from size variance and child similarity)
- `nodes` — all instances matching this pattern, with IDs for further inspection

**When to use**: Identifying component candidates before restructuring. Maps to Phase 1
step 5 (Pattern Detection) in the Restructuring Workflow.

---

### figma_analyze_colors

Analyzes color usage across the design with optional similarity grouping.

**Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | number | 30 | Maximum colors to return |
| `threshold` | number | 15 | Distance threshold for similarity clustering (0-50, Euclidean RGB) |
| `show-similar` | boolean | false | Group similar colors and suggest canonical hex for each cluster |

**Output Shape** (JSON):

```json
{
  "colors": [
    {
      "hex": "#3B82F6",
      "count": 42,
      "nodes": ["1:23", "1:45", "1:67"],
      "variableName": "Colors/Primary",
      "isStyle": true
    },
    {
      "hex": "#3A80F5",
      "count": 3,
      "nodes": ["1:89"],
      "variableName": null,
      "isStyle": false
    }
  ],
  "totalNodes": 320
}
```

With `show-similar: true`, the output additionally groups nearby hex values within
`threshold` distance and suggests a canonical color for each group.

- `variableName` — non-null if the color is bound to a Figma variable (properly tokenized)
- `isStyle` — true if the color is applied via a Figma style

**When to use**: Auditing color consistency, identifying hardcoded colors not bound to
tokens, finding near-duplicate colors to consolidate. Maps to Phase 1 step 6 (Design
System Inventory) in the Restructuring Workflow.

---

### figma_analyze_typography

Analyzes font usage across all text nodes.

**Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | number | 30 | Maximum typography styles to return |
| `group-by` | string | (none) | Group results by: `family`, `size`, or `weight` |

**Output Shape** (JSON):

```json
{
  "styles": [
    {
      "family": "Inter",
      "size": 16,
      "weight": 400,
      "lineHeight": 24,
      "count": 85,
      "nodes": ["1:23", "1:45"],
      "styleName": "Body/Regular"
    }
  ],
  "totalTextNodes": 210
}
```

- `styleName` — non-null if the text uses a Figma text style
- Histogram output shows frequency of each font/size/weight combination
- Hardcoded text (no style) is easily identifiable by `styleName: null`

**When to use**: Auditing typography consistency, identifying text not bound to styles,
planning a typography scale. Maps to Phase 1 step 6 (Design System Inventory) in the
Restructuring Workflow.

---

### figma_analyze_spacing

Analyzes gap and padding values with grid compliance checking.

**Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `grid` | number | 8 | Base grid size — values not divisible by this are flagged as off-grid |

**Output Shape** (JSON):

```json
{
  "gaps": [
    { "value": 16, "type": "itemSpacing", "count": 34, "nodes": ["1:23"] },
    { "value": 12, "type": "itemSpacing", "count": 12, "nodes": ["1:45"] },
    { "value": 5, "type": "itemSpacing", "count": 3, "nodes": ["1:67"] }
  ],
  "paddings": [
    { "value": 24, "type": "padding", "count": 28, "nodes": ["1:89"] },
    { "value": 7, "type": "padding", "count": 2, "nodes": ["1:101"] }
  ],
  "totalNodes": 180
}
```

- Off-grid values are flagged with a warning marker in human-readable output (values of 5
  and 7 above would be flagged with `grid=8`)
- Set `grid=4` for tighter compliance (standard Figma 4px grid)
- Histograms show frequency distribution of spacing values

**When to use**: Identifying off-grid spacing violations, auditing spacing consistency
before restructuring. Maps to Phase 1 step 4 (Deep Analysis) in the Restructuring
Workflow.

---

### figma_analyze_snapshot

Extracts an accessibility tree representation of the design.

**Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | string | (current page) | Node ID to analyze (default: entire current page) |
| `interactive` | boolean | false | Show only interactive elements (buttons, inputs, links) |
| `depth` | number | (unlimited) | Maximum tree depth to traverse |
| `no-compact` | boolean | false | Show all wrapper nodes (default: collapse non-semantic wrappers) |

**Output**: A hierarchical text representation of the design's semantic structure, showing
interactive elements, roles, and reading order.

**When to use**: Accessibility audits — verifying touch targets, reading order, interactive
element coverage. Useful in Phase 5 (Polish) of the Restructuring Workflow for the
accessibility check step.

---

## Enhancing the Restructuring Workflow

The analysis tools map directly to Phase 1 steps of the Design Restructuring Workflow
defined in SKILL.md. When figma-use is available, these tools can augment or replace
the `figma_execute`-based analysis recipes in `recipes-restructuring.md`:

| SKILL.md Phase 1 Step | figma-console Approach | figma-use Augmentation |
|------------------------|----------------------|----------------------|
| Step 3: Node tree scan | `figma_get_file_for_plugin({ selectionOnly: true })` | `figma_query` — XPath for targeted structural queries (see `figma-use-diffing.md`) |
| Step 4: Deep analysis | Deep Node Tree Analysis recipe (`recipes-restructuring.md`) | `figma_analyze_clusters` + `figma_analyze_spacing` — no code, structured output |
| Step 5: Pattern detection | Repeated Pattern Detection recipe (`recipes-restructuring.md`) | `figma_analyze_clusters` — single call with confidence scores |
| Step 6: Design system inventory | `figma_get_design_system_summary` + `figma_get_variables` | `figma_analyze_colors` + `figma_analyze_typography` — adds hardcoded-vs-tokenized breakdown |
| Step 7: Health baseline | `figma_audit_design_system` (figma-console only) | No figma-use equivalent — continue using figma-console |

**Important**: `figma_audit_design_system` (figma-console) provides a 0-100 health score
with category breakdowns. There is no figma-use equivalent. Always use figma-console for
Step 7 regardless of which server handles Steps 3-6.

---

## Dual-Server Analysis Workflow

A complete audit workflow combining both servers:

1. **Discover patterns** — `figma_analyze_clusters` (figma-use) to identify component
   candidates
2. **Audit colors** — `figma_analyze_colors --show-similar` (figma-use) to find hardcoded
   and near-duplicate colors
3. **Audit spacing** — `figma_analyze_spacing --grid 4` (figma-use) to flag off-grid values
4. **Check library coverage** — `figma_search_components` (figma-console) to verify which
   patterns already exist in the team library
5. **Apply fixes** — `figma_execute` (figma-console) to restructure nodes using recipes
   from `recipes-restructuring.md`
6. **Verify changes** — `figma_diff_visual` (figma-use) for pixel-level before/after
   comparison (see `figma-use-diffing.md`)

This workflow leverages each server's strengths: figma-use for code-free analysis,
figma-console for the Plugin API mutations and design system scoring.
