# Visual QA Protocol — Screen Validation & Audit

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Screen comparison, deep quality audits, and the Modification-Audit-Loop orchestrator pattern for Figma handoff workflows. For anti-patterns encountered during QA, see `anti-patterns.md`. For component recipes used in fixes, see `recipes-components.md`.

---

## Tool Constraints (MANDATORY)

| Rule | Detail |
|------|--------|
| **Baseline screenshots** | Use `figma_take_screenshot` (REST API) for screenshots of already-saved designs, initial baselines, and Draft references. NEVER use `mcp__plugin_figma_figma__get_screenshot`, `mcp__figma-desktop__get_screenshot`, or other non-standard screenshot tools |
| **Post-mutation screenshots** | After ANY `figma_execute` mutation in the current session, use `figma_capture_screenshot` (Desktop Bridge, live state). `figma_take_screenshot` (REST API) serves cloud-cached renders and will NOT reflect recent `figma_execute` changes. This applies inside Modification-Audit-Loop fix cycles |
| **Structural inspection** | Use `figma_execute` (Plugin API) for node structure, naming, layout modes, constraints — never infer structure from screenshots alone |

---

## Recommended Model for QA Subagents

**Sonnet** for all QA tasks. Opus adds latency with no quality gain for structured audit tasks. Haiku lacks sufficient vision fidelity for subtle spacing/component differences.

---

## Orchestrator Pattern — Modification-Audit-Loop

All Figma screen modifications MUST follow this pattern. Modifications NEVER happen in the main context — always delegated to subagents to preserve context cleanliness.

```
Orchestrator (main context)
  |
  |-- Modification Subagent (general-purpose, Sonnet)
  |     - Receives: nodeIds, what to change, reference values
  |     - Uses: figma_execute (Plugin API) to apply all changes
  |     - Returns: list of changes applied + node IDs modified
  |
  |-- Audit Subagent (general-purpose, Sonnet) <- use Handoff Audit below
  |     - Receives: screen nodeId, fileKey, optional reference nodeId
  |     - Uses: figma_take_screenshot (visual) + figma_execute (structural)
  |     - Returns: audit report with scores + list of issues
  |
  |-- Loop condition:
        if audit score < threshold OR any Critical/Major issues found:
          -> dispatch new Modification Subagent with audit findings as input
          -> re-run Audit Subagent
          -> max 3 iterations before escalating to user
        else:
          -> done, report to user
```

**Why this pattern:**
- Main context stays clean — only orchestrator decisions and audit summaries
- Each subagent has a focused, minimal context — fewer hallucinations, faster execution
- Modifications and audits are independently retryable
- Long Figma sessions don't exhaust the main context window

### Audit Fix Completeness Rule

After every fix subagent returns, ALWAYS run a new audit and explicitly verify that ALL issues from the previous audit report are addressed — not just the ones mentioned at the top. Fix subagents tend to address the most prominent issues and skip issues that appear lower in the list.

Pattern: take the previous audit's issue list, enumerate each by ID/description, check each one in the new audit output. If any issue is absent from the new audit report (not marked resolved), treat it as still open. Never accept a fix subagent's own "what I fixed" summary as ground truth — the audit is the only source of truth.

### Node Existence Pre-Check

Before spawning parallel subagents to audit/fix multiple screens, run a lightweight existence pre-check in the MAIN context:

```js
return (async () => {
  const ids = [/* all handoff_ids from session state */];
  const results = [];
  for (const id of ids) {
    const node = await figma.getNodeByIdAsync(id);
    results.push({ id, exists: !!node, name: node?.name || null });
  }
  return JSON.stringify(results);
})();
```

Fix stale IDs before any subagent is launched. Cost is one `figma_execute` sync call.

---

## Screen Diff — Visual Comparison (Draft vs Handoff)

Use when comparing two versions of the same screen (e.g., Draft vs Handoff). Replace `{{PLACEHOLDERS}}` and paste as the subagent prompt.

```
You are a visual QA specialist for a Figma design file. Compare two screen versions
and produce a structured report. For baseline screenshots of saved screens, use figma_take_screenshot.
After any figma_execute mutations in this session, use figma_capture_screenshot (live state) instead.

## File Details
- **File key**: `{{FILE_KEY}}`
- **Screen A ({{LABEL_A}})**: node `{{NODE_ID_A}}`
- **Screen B ({{LABEL_B}})**: node `{{NODE_ID_B}}`

## Steps
1. Take screenshot of Screen A: `mcp__figma-console__figma_take_screenshot`
   with nodeId "{{NODE_ID_A}}" and fileKey "{{FILE_KEY}}".
2. Take screenshot of Screen B: `mcp__figma-console__figma_take_screenshot`
   with nodeId "{{NODE_ID_B}}" and fileKey "{{FILE_KEY}}".
3. Examine both screenshots systematically and identify ALL differences.

## What to Compare
- **Layout & Spacing**: positions, margins, padding, vertical rhythm, alignment
- **Typography**: size, weight, line-height, text content, truncation, alignment
- **Colors**: backgrounds, text, icon fills, overlays, opacity
- **Components**: which components are used, size, variant state, nested content
- **Missing / Extra elements**: present in one screen, absent in the other
- **Constraints & Anchoring**: how elements anchor to screen edges

## Output Format

# Figma Visual Comparison — {{LABEL_A}} vs {{LABEL_B}}

## Screen Summaries

### {{LABEL_A}}
[Brief description]

### {{LABEL_B}}
[Brief description]

---

## Differences Found

### [Category]: [Short title]

| Property | {{LABEL_A}} | {{LABEL_B}} |
|---|---|---|
| [property] | [value A] | [value B] |

**Severity**: Critical / Major / Minor / Cosmetic
**Notes**: [1-2 sentences on user impact]

[Repeat for each difference]

---

## Summary

| Metric | Value |
|---|---|
| Total differences | N |
| Critical | N |
| Major | N |
| Minor | N |
| Cosmetic | N |
| **Visual consistency score** | **X / 10** |

## Key Findings
- [Bullet list of most important differences]

## Recommendation
[**Ready** / **NOT READY** — rationale + required actions]

---

## Severity Definitions
| Severity | Definition |
|---|---|
| **Critical** | Missing content, wrong copy, broken component, non-functional element |
| **Major** | Significant visual difference clearly visible to users |
| **Minor** | Small spacing/sizing difference, noticeable only on close inspection |
| **Cosmetic** | Negligible, no user impact |
```

---

## Handoff Audit — Deep Quality Check (Single Screen)

Use after a modification subagent applies changes, or as a standalone quality gate. Combines visual inspection (screenshot) + structural inspection (Plugin API) + component compliance (design system registry). Replace `{{PLACEHOLDERS}}` and paste as the subagent prompt.

### Placeholders Reference

| Placeholder | Description | Example |
|---|---|---|
| `{{FILE_KEY}}` | Figma file key | `ygStDl4bV47BLbbPrQhLo0` |
| `{{NODE_ID}}` | Handoff screen node ID | `157:1296` |
| `{{SCREEN_NAME}}` | Human-readable screen name | `ONB-01 — Welcome` |
| `{{DRAFT_NODE_ID}}` | Draft reference node ID (optional) | `24:3558` |
| `{{COMPONENTS_SECTION_ID}}` | Node ID of the Components section/frame | `139:2121` |
| `{{EXPECTED_COMPONENTS}}` | Comma-separated `name:componentId` pairs required on this screen. ID match is authoritative — name is for readability only | `SwipeGestureIcon:157:1092, TitleBodyGroup:157:539` |
| `{{VIEWPORT_WIDTH}}` | Target device viewport width (default: 360px) | `360` |
| `{{VIEWPORT_HEIGHT}}` | Target device viewport height (default: 871px) | `871` |

### Pre-Audit: Verify Expected Component IDs

Before setting `{{EXPECTED_COMPONENTS}}`, always run Step 2 (DS registry enumeration) first. Cross-check each expected `componentId` against the registry output. If an expected ID is not in the registry: (a) search by name to find the actual current ID, (b) update session-state metadata, (c) use the corrected ID. Never blindly copy IDs from session-state without this verification — stale IDs produce Critical false positives.

### Audit Prompt Template

```
You are a Figma design quality auditor. Perform a deep audit of a single screen,
combining visual inspection, structural analysis, and component compliance verification.
For baseline screenshots of saved screens, use figma_take_screenshot.
After any figma_execute mutations in this session, use figma_capture_screenshot (live state) instead.
Use figma_execute for all structural and component inspection.

## File Details
- **File key**: `{{FILE_KEY}}`
- **Screen node ID**: `{{NODE_ID}}`
- **Screen name**: `{{SCREEN_NAME}}`
- **Draft reference node ID** (optional): `{{DRAFT_NODE_ID}}`
- **Components section node ID**: `{{COMPONENTS_SECTION_ID}}`
- **Expected components on this screen**: `{{EXPECTED_COMPONENTS}}`
  Format: `name:componentId` pairs (e.g. `SwipeGestureIcon:157:1092, TitleBodyGroup:157:539`).
  Layer B matches on **componentId** (authoritative), not on name.

## Step 0 — Parent Context Check (MANDATORY — run before everything else)
Use figma_execute to verify the screen is a direct child of a SECTION or PAGE,
with no wrapper GROUP and no orphaned sibling nodes.

```js
const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
const parent = screen.parent;
const siblings = parent?.children?.filter(c => c.id !== screen.id) || [];
return JSON.stringify({
  screen: { id: screen.id, name: screen.name, type: screen.type },
  parent: {
    id: parent?.id, name: parent?.name, type: parent?.type,
    childCount: parent?.children?.length
  },
  siblings: siblings.map(n => ({
    id: n.id, name: n.name, type: n.type,
    x: n.x, y: n.y, w: n.width, h: n.height
  }))
}, null, 2);
```

**Flag as Critical** if `parent.type === 'GROUP'` — screen must not be wrapped in a GROUP.
**Flag as Major** if `siblings.length > 0` — orphaned elements in the parent container.
Expected: `parent.type` is `'SECTION'` or `'PAGE'`, `siblings` is empty `[]`.

## Step 1 — Visual Capture
Take a screenshot of the Handoff screen with `mcp__figma-console__figma_take_screenshot`
using nodeId "{{NODE_ID}}" and fileKey "{{FILE_KEY}}".
If a Draft reference exists, take a screenshot of it too (nodeId "{{DRAFT_NODE_ID}}").

## Step 1b — Positional Diff vs Draft (run only if DRAFT_NODE_ID is provided)

**Purpose**: detect metric discrepancies (x, y, width, height) that screenshots miss.
LLM visual comparison is unreliable for +/-10-40px differences on full-screen images.
This script compares absolute positions of all direct children of draft vs handoff.

**Flag as Major** if any direct child has `|dx| > 8px` or `|dwidth| > 8px`.
**Flag as Minor** if `|dx| > 3px` or `|dwidth| > 3px`.
> **Note**: These thresholds (3px minor / 8px major) are tunable defaults. Adjust per project — tighter for pixel-perfect targets, looser for early prototypes.
Skip nodes that don't have a name match (different structure = structural issue, not positional).

```js
return (async () => {
  const draft    = await figma.getNodeByIdAsync('{{DRAFT_NODE_ID}}');
  const handoff  = await figma.getNodeByIdAsync('{{NODE_ID}}');
  if (!draft || !handoff) return JSON.stringify({ error: 'Node not found' });

  const draftMap = {};
  for (const c of (draft.children || [])) {
    draftMap[c.name.toLowerCase().trim()] = {
      x: Math.round(c.x), y: Math.round(c.y),
      w: Math.round(c.width), h: Math.round(c.height)
    };
  }

  const draftTexts = (draft.findAll ? draft.findAll(n => n.type === 'TEXT') : [])
    .map(n => ({
      text: n.characters?.slice(0, 40),
      x: Math.round(n.absoluteBoundingBox?.x - draft.absoluteBoundingBox?.x || n.x),
      y: Math.round(n.absoluteBoundingBox?.y - draft.absoluteBoundingBox?.y || n.y),
      w: Math.round(n.width)
    }));

  const diffs = [];
  for (const c of (handoff.children || [])) {
    const key = c.name.toLowerCase().trim();
    const d = draftMap[key];
    if (!d) continue;
    const dx = Math.round(c.x) - d.x;
    const dw = Math.round(c.width) - d.w;
    const dy = Math.round(c.y) - d.y;
    const dh = Math.round(c.height) - d.h;
    if (Math.abs(dx) > 3 || Math.abs(dw) > 3 || Math.abs(dy) > 3 || Math.abs(dh) > 3) {
      diffs.push({
        name: c.name,
        handoff: { x: Math.round(c.x), y: Math.round(c.y), w: Math.round(c.width), h: Math.round(c.height) },
        draft:   { x: d.x, y: d.y, w: d.w, h: d.h },
        delta:   { dx, dy, dw, dh },
        severity: (Math.abs(dx) > 8 || Math.abs(dw) > 8) ? 'Major' : 'Minor'
      });
    }
  }

  return JSON.stringify({
    draftSize:   { w: draft.width, h: draft.height },
    handoffSize: { w: handoff.width, h: handoff.height },
    draftTexts:  draftTexts.slice(0, 20),
    positionalDiffs: diffs
  }, null, 2);
})();
```

Report findings under **Dimension 1: Visual Quality** — positional deltas are metric findings,
not subjective visual ones. Include the `delta` values in the issue table.

## Step 2 — Build Design System Registry
Use figma_execute to enumerate all components available in the Components section.

```js
const section = await figma.getNodeByIdAsync('{{COMPONENTS_SECTION_ID}}');
const comps = section.findAll(n =>
  n.type === 'COMPONENT' || n.type === 'COMPONENT_SET'
);
return JSON.stringify(comps.map(c => ({
  id: c.id, name: c.name, type: c.type
})), null, 2);
```

## Step 3 — Inspect Screen Structure + Instance Compliance
Use figma_execute to collect the full node tree AND resolve each INSTANCE to its
main component, verifying it belongs to the design system.

```js
const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
const all = screen.findAll ? screen.findAll(n => true) : [];
const result = { root: {}, nodes: [] };

result.root = {
  id: screen.id, name: screen.name, type: screen.type,
  w: screen.width, h: screen.height,
  cornerRadius: screen.cornerRadius,
  clipsContent: screen.clipsContent,
  layoutMode: screen.layoutMode
};

for (const n of all) {
  const entry = {
    id: n.id, name: n.name, type: n.type,
    x: n.x, y: n.y, w: n.width, h: n.height,
    layoutMode: n.layoutMode || null,
    constraints: n.constraints || null,
    depth: 0,
    mcId: null, mcName: null
  };
  let p = n.parent, d = 0;
  while (p && p.id !== screen.id) { d++; p = p.parent; }
  entry.depth = d;
  if (n.type === 'INSTANCE') {
    const mc = await n.getMainComponentAsync();
    entry.mcId = mc?.id || null;
    entry.mcName = mc?.name || null;
    entry.mcRemote = mc?.remote || false;
  }
  result.nodes.push(entry);
}
return JSON.stringify(result, null, 2);
```

## Step 4 — Check for Spurious Raw Frames (should-be-instances)

```js
const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
const rawFrames = screen.findAll(n =>
  n.type === 'FRAME' &&
  n.parent?.type !== 'INSTANCE' &&
  n.children?.length > 0
);
return JSON.stringify(rawFrames.map(f => ({
  id: f.id, name: f.name,
  w: f.width, h: f.height,
  childCount: f.children.length,
  childNames: f.children.map(c => c.name)
})), null, 2);
```

## Step 5 — Audit Against All 8 Dimensions

### Dimension 1: Visual Quality (via screenshots)
- Correct layout vs Draft reference
- Element positions, spacing, proportions, colors, typography
- No clipping, overflow, or visual glitches

### Dimension 2: Layer Structure & Hierarchy
- **Parent container**: screen FRAME must be a direct child of SECTION or PAGE — never wrapped in a GROUP (verified in Step 0)
- **No orphaned siblings**: parent container must have no sibling nodes alongside the screen FRAME (verified in Step 0)
- Screen root: FRAME (not GROUP), cornerRadius=32, clipsContent=true
- No orphaned nodes outside the screen frame
- Max nesting depth 5-6 levels; flag anything deeper
- FRAMEs for layout containers; GROUPs only for semantic groupings with no layout role

### Dimension 3: Semantic Naming
- No generic names: "Frame N", "Group N", "Rectangle N", "Vector N", "Ellipse N"
- All meaningful nodes have descriptive names (e.g., "button_settings", "content-frame")
- Text nodes named by semantic role (e.g., "text/title", "text/body", "label/cta")

### Dimension 4: Auto-Layout Correctness

**IMPORTANT — script-only rule**: Report ONLY issues detected by the 6 automated checks (A-F) below. Do NOT add manual findings like "root frame should have auto-layout" unless Check B fires. The screen root frame on fixed-size mobile screens (360x871px) is a **stage**, not a layout container. Screens with a bottom-pinned CTA have intentionally inconsistent gaps — Check B will never fire on them, which is correct.

Run the full auto-layout inspection with figma_execute:

```js
return (async () => {
  const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
  if (!screen) return JSON.stringify({ error: 'Screen node not found', nodeId: '{{NODE_ID}}' });

  const allNodes = screen.findAll(n => true);
  const issues = [];

  // SINGLE-PASS CLASSIFICATION: build typed buckets in one O(N) loop
  const instanceNodes = [];
  const frameNoAL     = [];
  const allFrames     = [];
  const frameVertAL   = [];
  const frameAnyAL    = [];

  for (const node of allNodes) {
    if (node.type === 'INSTANCE') { instanceNodes.push(node); continue; }
    if (node.type !== 'FRAME') continue;
    allFrames.push(node);
    const mode = node.layoutMode;
    if (!mode || mode === 'NONE')  { frameNoAL.push(node); continue; }
    if (mode === 'VERTICAL')       frameVertAL.push(node);
    frameAnyAL.push(node);
  }

  // Batch getMainComponentAsync + build parentCache
  const mainComponents = await Promise.all(instanceNodes.map(n => n.getMainComponentAsync()));
  const parentCache = new Map();

  // CHECK A: Repeated identical components without auto-layout container
  const instancesByParentAndComp = {};
  for (let i = 0; i < instanceNodes.length; i++) {
    const node = instanceNodes[i];
    if (!node.parent) continue;
    const mc = mainComponents[i];
    if (!mc) continue;
    parentCache.set(node.parent.id, node.parent);
    const compId = mc.parent?.type === 'COMPONENT_SET' ? mc.parent.id : mc.id;
    const key = `${node.parent.id}||${compId}`;
    if (!instancesByParentAndComp[key]) instancesByParentAndComp[key] = [];
    instancesByParentAndComp[key].push({ id: node.id, name: node.name, y: Math.round(node.y) });
  }
  for (const [key, instances] of Object.entries(instancesByParentAndComp)) {
    if (instances.length < 2) continue;
    const [parentId] = key.split('||');
    if (!parentId || parentId === 'undefined') continue;
    const parent = parentCache.get(parentId);
    if (!parent || !parent.layoutMode || parent.layoutMode === 'NONE') {
      issues.push({ check: 'A', severity: 'Major', msg: `${instances.length}x same component family as loose children — wrap in auto-layout container`, parentId, instances: instances.map(i => i.id) });
    }
  }

  // CHECK B: Frames with 3+ stacked/aligned children that lack auto-layout
  for (const node of frameNoAL) {
    const children = 'children' in node
      ? [...node.children].filter(c => c.type !== 'VECTOR' && c.type !== 'ELLIPSE' && c.type !== 'RECTANGLE')
      : [];
    if (children.length < 3) continue;

    const sortedY = [...children].sort((a, b) => a.y - b.y);
    const gapsY = [];
    for (let i = 1; i < sortedY.length; i++) gapsY.push(sortedY[i].y - (sortedY[i-1].y + sortedY[i-1].height));
    if (gapsY.every(g => g >= 0) && gapsY.length > 0 && Math.max(...gapsY) - Math.min(...gapsY) <= 4) {
      issues.push({ check: 'B', severity: 'Major', msg: `Frame has ${children.length} vertically stacked children with consistent ~${Math.round(gapsY[0])}px gap — use layoutMode=VERTICAL, itemSpacing=${Math.round(gapsY[0])}`, nodeId: node.id, nodeName: node.name, direction: 'VERTICAL', gap: Math.round(gapsY[0]) });
      continue;
    }

    const sortedX = [...children].sort((a, b) => a.x - b.x);
    const gapsX = [];
    for (let i = 1; i < sortedX.length; i++) gapsX.push(sortedX[i].x - (sortedX[i-1].x + sortedX[i-1].width));
    if (gapsX.every(g => g >= 0) && gapsX.length > 0 && Math.max(...gapsX) - Math.min(...gapsX) <= 4) {
      issues.push({ check: 'B', severity: 'Major', msg: `Frame has ${children.length} horizontally aligned children with consistent ~${Math.round(gapsX[0])}px gap — use layoutMode=HORIZONTAL, itemSpacing=${Math.round(gapsX[0])}`, nodeId: node.id, nodeName: node.name, direction: 'HORIZONTAL', gap: Math.round(gapsX[0]) });
    }
  }

  // CHECK C: Spacer frames (empty frames used as spacing shims)
  for (const node of allFrames) {
    const isEmpty = (!('children' in node) || node.children.length === 0) &&
                    (!node.fills  || node.fills.every(f => !f.visible)) &&
                    (!node.strokes || node.strokes.length === 0);
    const parent = node.parent;
    const parentIsAL = parent?.layoutMode && parent.layoutMode !== 'NONE';
    const parentHasNoSpacing = !parent?.itemSpacing || parent.itemSpacing === 0;
    if (isEmpty && parentIsAL && parentHasNoSpacing) {
      issues.push({ check: 'C', severity: 'Minor', msg: `Empty spacer frame inside auto-layout (parent itemSpacing=0) — replace with explicit itemSpacing`, nodeId: node.id, nodeName: node.name, parentId: parent?.id, w: Math.round(node.width), h: Math.round(node.height) });
    }
  }

  // CHECK D: Children with hardcoded width that should be FILL
  for (const node of frameVertAL) {
    const innerW = node.width - (node.paddingLeft || 0) - (node.paddingRight || 0);
    if (innerW <= 0) continue;
    for (const child of node.children) {
      if (child.layoutSizingHorizontal === 'FILL') continue;
      if (child.layoutPositioning === 'ABSOLUTE') continue;
      if (child.width <= 0) continue;
      if (Math.abs(child.width - innerW) <= 2) {
        issues.push({ check: 'D', severity: 'Minor', msg: `Child width ${Math.round(child.width)}px ~ parent inner width ${Math.round(innerW)}px — use layoutSizingHorizontal=FILL`, nodeId: child.id, nodeName: child.name, parentId: node.id });
      }
    }
  }

  // CHECK E: layoutPositioning=ABSOLUTE inside auto-layout
  for (const node of allNodes) {
    if (node.layoutPositioning === 'ABSOLUTE') {
      const parent = node.parent;
      if (parent?.layoutMode && parent.layoutMode !== 'NONE') {
        issues.push({ check: 'E', severity: 'Minor', msg: `layoutPositioning=ABSOLUTE inside auto-layout — ok for badges/icons, not ok for content blocks`, nodeId: node.id, nodeName: node.name, parentId: parent.id, parentName: parent.name });
      }
    }
  }

  // CHECK F: Auto-layout with all-zero padding but implicit content margin
  for (const node of frameAnyAL) {
    const p = [node.paddingTop||0, node.paddingBottom||0, node.paddingLeft||0, node.paddingRight||0];
    if (!p.every(v => v === 0)) continue;
    if (!('children' in node) || node.children.length === 0) continue;
    const firstChild = node.children[0];
    if (firstChild.layoutPositioning === 'ABSOLUTE') continue;
    const isVertical = node.layoutMode === 'VERTICAL';
    const offset = isVertical ? firstChild.y : firstChild.x;
    if (offset > 2) {
      issues.push({ check: 'F', severity: 'Minor', msg: `Auto-layout ${node.layoutMode} has padding=0 but first child ${isVertical ? 'y' : 'x'}=${Math.round(offset)}px — set padding${isVertical ? 'Top' : 'Left'}=${Math.round(offset)} explicitly`, nodeId: node.id, nodeName: node.name, direction: node.layoutMode, impliedPadding: Math.round(offset) });
    }
  }

  return JSON.stringify({ totalIssues: issues.length, issues }, null, 2);
})();
```

**Severity mapping:**
- Check A (repeated component family, no container): **Major**
- Check B (3+ stacked/aligned children, no auto-layout): **Major**
- Check C (spacer frames when parent itemSpacing=0): **Minor**
- Check D (hardcoded width ~ parent inner width): **Minor**
- Check E (absolute positioning in auto-layout): **Minor** — verify intent
- Check F (implicit padding via child offset): **Minor**

### Dimension 5: Component Compliance (3-layer check)

**Layer A — Instance-to-DS mapping**: For every INSTANCE in the screen, verify its
mainComponent ID appears in the design system registry (built in Step 2).
**SKIP instances where `mcRemote=true`** — remote components from external libraries are DS-compliant
and will never appear in the local section.

**Layer B — Expected components present (ID-authoritative)**: Parse the `{{EXPECTED_COMPONENTS}}`
list as `name:componentId` pairs. For each expected entry, verify at least one INSTANCE
in the screen has `mainComponent.id === componentId`. Match on **ID only** — name is
for readability. Flag as Critical if zero instances match the expected ID (missing component).
Flag if an instance has the right name but a different ID (wrong source — e.g. local
copy instead of library component).

**Layer C — No spurious raw frames**: From Step 4, examine raw FRAMEs.
Flag any FRAME whose name or child structure matches a design system component
(same name pattern, same child count/names). These should be converted to instances.

### Dimension 6: Constraints & Responsiveness
- All direct children of the screen root have explicit constraints
- Bottom-anchored elements: vertical = MAX (Bottom)
- Horizontally centered elements: horizontal = CENTER
- Full-width elements: horizontal = STRETCH or LEFT_RIGHT
- Default MIN+MIN (Top+Left) only acceptable for elements that are intentionally top-left anchored

### Dimension 7: Screen-Level Properties
- Screen root type = FRAME (not GROUP, COMPONENT, etc.)
- cornerRadius = 32
- clipsContent = true
- Width = `{{VIEWPORT_WIDTH}}` (default: 360px); Height = `{{VIEWPORT_HEIGHT}}` (default: 871px for viewport) or content height (scrollable). Adjust defaults per project target device

### Dimension 8: Instance Override Integrity
- For each INSTANCE, check that text overrides (characters) match the expected copy
  (compare against Draft screenshot, not against component defaults)
- Flag instances where the override appears to still show the component default placeholder text
  (e.g., "Title text here", "Body text here", "Label")
- Verify via figma_execute `.characters` read, NOT via screenshot alone
  (REST API screenshots may show stale component defaults, not live overrides)

## Output Format

# Screen Audit — {{SCREEN_NAME}}

## Visual Snapshot
[Describe what both screenshots show and overall visual impression. Note match/mismatch vs Draft.]

---

## Design System Registry
[List all components found in the Components section — name, type, node ID]

## Instances in Screen
[Table: instance name | mainComponent name | mainComponent ID | in DS registry? | expected ID match?]

---

## Audit Results

| Dimension | Score | Status |
|---|---|---|
| Visual Quality | X/10 | Pass / Issues / Fail |
| Layer Structure | X/10 | Pass / Issues / Fail |
| Semantic Naming | X/10 | Pass / Issues / Fail |
| Auto-Layout | X/10 | Pass / Issues / Fail |
| Component Compliance | X/10 | Pass / Issues / Fail |
| Constraints | X/10 | Pass / Issues / Fail |
| Screen Properties | X/10 | Pass / Issues / Fail |
| Instance Overrides | X/10 | Pass / Issues / Fail |
| **Overall** | **X/10** | **PASS / NEEDS WORK** |

---

## Issues Found

### [Dimension]: [Short title]

| Property | Current | Expected |
|---|---|---|
| [property] | [actual value] | [correct value] |

**Severity**: Critical / Major / Minor / Cosmetic
**Node**: `[node ID — name]`
**Action**: [specific fix required]

[Repeat for each issue]

---

## Summary

| Metric | Value |
|---|---|
| Total issues | N |
| Critical | N |
| Major | N |
| Minor | N |
| Cosmetic | N |

## Verdict
[**PASS** (overall >= 8, no Critical/Major) / **NEEDS WORK** — required fixes in priority order]

---

## Severity Definitions
| Severity | Definition |
|---|---|
| **Critical** | Expected component missing, wrong mainComponent reference, broken override, screen wrapped in GROUP wrapper |
| **Major** | Raw frame where a DS component should be used, wrong structural root type, orphaned sibling nodes in parent container |
| **Minor** | Constraint misconfiguration, naming issue, suboptimal layout |
| **Cosmetic** | Negligible, no user or developer impact |
```

---

## Parallelization Note

- For **Screen Diff**: one subagent per screen pair, max 4 parallel.
- For **Handoff Audit**: one subagent per screen, max 4 parallel.
- Subagents are independent — no shared state or output file needed.
- Orchestrator collects all reports and assembles aggregate summary.
- Pass threshold for loop exit: overall score >= 8/10 AND no Critical or Major issues.

---

## Cross-References

- **Anti-patterns** (errors found during audits): `anti-patterns.md`
- **Plugin API** (figma_execute patterns used in audit scripts): `plugin-api.md`
- **Design rules** (MUST/SHOULD rules referenced by audit dimensions): `design-rules.md`
- **Field learnings** (production strategies): `field-learnings.md`
- **Component recipes** (fixes for component issues): `recipes-components.md`
- **Convergence protocol** (journal + subagent model): `convergence-protocol.md`
- **Reflection protocol** (quality dimensions overlap with audit): `reflection-protocol.md`
