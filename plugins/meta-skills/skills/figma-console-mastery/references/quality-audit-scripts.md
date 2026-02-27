# Quality Audit Scripts

> JavaScript audit scripts A-I, screen diff templates, per-element position analysis, and scrollability checks.
> Part of the Unified Quality Model for figma-console design validation.
> Version: 1.1.0

**Load when**: Any Standard or Deep audit execution (referenced by Handoff Audit Template and Deep judges)

**Related files**: This file is part of a 3-file split:
- **quality-dimensions.md** — 11 dimensions, rubrics, composite scoring, depth tiers, contradiction resolutions
- **quality-audit-scripts.md** (this file) — JavaScript audit scripts A-I, diff templates, positional analysis
- **quality-procedures.md** — Spot/Standard/Deep audit procedures, fix cycles, 3+1 judge templates

---

## 1. Script A: Parent Context Check (MANDATORY first step)

Run BEFORE any other audit step. Verifies screen is direct child of SECTION/PAGE with no wrapper GROUP and no orphaned siblings.

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

**Flag as Critical** if `parent.type === 'GROUP'` — screen must not be wrapped in GROUP.
**Flag as Major** if `siblings.length > 0` — orphaned elements in parent container.

---

## 2. Script B: Positional Diff (Draft vs Handoff)

Run only if Draft reference is provided. Detects metric discrepancies that screenshots miss.

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

**Flag as Major** if `|dx| > 8px` or `|dwidth| > 8px`.
**Flag as Minor** if `|dx| > 3px` or `|dwidth| > 3px`.

---

## 3. Script C: Design System Registry Enumeration

Build registry of all components available in Components section.

```js
const section = await figma.getNodeByIdAsync('{{COMPONENTS_SECTION_ID}}');
const comps = section.findAll(n =>
  n.type === 'COMPONENT' || n.type === 'COMPONENT_SET'
);
return JSON.stringify(comps.map(c => ({
  id: c.id, name: c.name, type: c.type
})), null, 2);
```

---

## 4. Script D: Screen Structure + Instance Compliance

Collect full node tree + resolve each INSTANCE to its mainComponent.

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

---

## 5. Script E: Spurious Raw Frames Detection

Identify raw FRAMEs that should be instances.

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

---

## 6. Script F: Auto-Layout Inspection (6 Checks A-F)

Full auto-layout inspection with 6 automated checks. This is the ONLY source of D4 findings.

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

**IMPORTANT — script-only rule**: Report ONLY issues detected by these 6 checks. Do NOT add manual findings. Screen root on fixed viewport exempt from Check B (it's a stage, not a layout container).

---

## 7. Script G: Accessibility Compliance Check (5 Sub-Checks G1-G5)

Single `figma_execute` script for D11 Accessibility Compliance. Runs in Standard and Deep tiers only (NOT Spot — Spot is inline ~1K tokens; accessibility checks are better caught at phase boundaries).

```js
return (async () => {
  const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
  if (!screen) return JSON.stringify({ error: 'Screen node not found', nodeId: '{{NODE_ID}}' });

  const allNodes = screen.findAll(n => true);
  const issues = [];

  // Helper: WCAG 2.1 relative luminance
  const luminance = (r, g, b) => {
    const [rs, gs, bs] = [r, g, b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
  };
  const contrastRatio = (l1, l2) => {
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  };
  const getSolidFillRGB = (node) => {
    const fills = node.fills;
    if (!fills || !Array.isArray(fills)) return null;
    const solid = fills.find(f => f.type === 'SOLID' && f.visible !== false);
    if (!solid) return null;
    return { r: Math.round(solid.color.r * 255), g: Math.round(solid.color.g * 255), b: Math.round(solid.color.b * 255) };
  };
  const getBackgroundRGB = (node) => {
    let current = node.parent;
    while (current) {
      const rgb = getSolidFillRGB(current);
      if (rgb) return rgb;
      current = current.parent;
    }
    return { r: 255, g: 255, b: 255 }; // assume white if no background found
  };

  // Helper: detect interactive elements
  const isInteractive = (node) => {
    if (node.type === 'INSTANCE') return true;
    if (node.reactions && node.reactions.length > 0) return true;
    const nameLower = (node.name || '').toLowerCase();
    return /button|btn|cta|link|tab|toggle|switch|checkbox|radio|input|select|chip|fab/.test(nameLower);
  };

  // CHECK G1: Color contrast (WCAG luminance formula, SOLID fills, parent-walk for background)
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    const fgRGB = getSolidFillRGB(node);
    if (!fgRGB) continue;
    const bgRGB = getBackgroundRGB(node);
    const fgL = luminance(fgRGB.r, fgRGB.g, fgRGB.b);
    const bgL = luminance(bgRGB.r, bgRGB.g, bgRGB.b);
    const ratio = contrastRatio(fgL, bgL);
    const fontSize = node.fontSize || 16;
    const isLargeText = fontSize >= 18 || (fontSize >= 14 && (node.fontWeight >= 700 || (node.fontName && node.fontName.style && /bold/i.test(node.fontName.style))));
    const requiredRatio = isLargeText ? 3.0 : 4.5;
    if (ratio < requiredRatio) {
      const severity = ratio < 3.0 ? 'Critical' : 'Major';
      issues.push({
        check: 'G1', severity,
        msg: `Text "${node.characters?.slice(0, 30)}" contrast ${ratio.toFixed(2)}:1 (need ${requiredRatio}:1, ${isLargeText ? 'large' : 'normal'} text)`,
        nodeId: node.id, nodeName: node.name,
        fg: fgRGB, bg: bgRGB, ratio: +ratio.toFixed(2), required: requiredRatio
      });
    }
  }

  // CHECK G2: Touch target size (>=44x44 for interactive elements)
  for (const node of allNodes) {
    if (!isInteractive(node)) continue;
    const w = Math.round(node.width);
    const h = Math.round(node.height);
    if (w < 44 || h < 44) {
      const minDim = Math.min(w, h);
      const severity = minDim < 32 ? 'Critical' : 'Major';
      issues.push({
        check: 'G2', severity,
        msg: `Interactive element ${w}x${h}px (minimum 44x44)`,
        nodeId: node.id, nodeName: node.name, size: { w, h }
      });
    }
  }

  // CHECK G3: Text size (>=14px body, >=12px caption by name pattern)
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    const fontSize = node.fontSize || 16;
    const nameLower = (node.name || '').toLowerCase();
    const isCaption = /caption|footnote|helper|hint|sub/.test(nameLower);
    if (isCaption && fontSize < 12) {
      issues.push({
        check: 'G3', severity: 'Minor',
        msg: `Caption text "${node.characters?.slice(0, 20)}" at ${fontSize}px (minimum 12px)`,
        nodeId: node.id, nodeName: node.name, fontSize
      });
    } else if (!isCaption && fontSize < 14) {
      const severity = fontSize < 12 ? 'Major' : 'Minor';
      issues.push({
        check: 'G3', severity,
        msg: `Body text "${node.characters?.slice(0, 20)}" at ${fontSize}px (minimum 14px)`,
        nodeId: node.id, nodeName: node.name, fontSize
      });
    }
  }

  // CHECK G4: Interactive spacing (>=8px between sibling interactive elements)
  const interactiveByParent = {};
  for (const node of allNodes) {
    if (!isInteractive(node) || !node.parent) continue;
    const pid = node.parent.id;
    if (!interactiveByParent[pid]) interactiveByParent[pid] = [];
    interactiveByParent[pid].push(node);
  }
  for (const [pid, nodes] of Object.entries(interactiveByParent)) {
    if (nodes.length < 2) continue;
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        const a = nodes[i], b = nodes[j];
        const gapX = Math.abs(a.x > b.x ? a.x - (b.x + b.width) : b.x - (a.x + a.width));
        const gapY = Math.abs(a.y > b.y ? a.y - (b.y + b.height) : b.y - (a.y + a.height));
        const gap = Math.min(gapX, gapY);
        if (gap >= 0 && gap < 8) {
          issues.push({
            check: 'G4', severity: 'Minor',
            msg: `Interactive elements "${a.name}" and "${b.name}" spaced ${Math.round(gap)}px apart (minimum 8px)`,
            nodeIds: [a.id, b.id], gap: Math.round(gap)
          });
        }
      }
    }
  }

  // CHECK G5: Missing descriptions on interactive components
  for (const node of allNodes) {
    if (node.type !== 'INSTANCE' && node.type !== 'COMPONENT') continue;
    if (!isInteractive(node)) continue;
    if (!node.description || node.description.trim() === '') {
      issues.push({
        check: 'G5', severity: 'Minor',
        msg: `Interactive component "${node.name}" has no description (assists downstream a11y labeling)`,
        nodeId: node.id, nodeName: node.name
      });
    }
  }

  return JSON.stringify({
    totalIssues: issues.length,
    critical: issues.filter(i => i.severity === 'Critical').length,
    major: issues.filter(i => i.severity === 'Major').length,
    minor: issues.filter(i => i.severity === 'Minor').length,
    issues
  }, null, 2);
})();
```

**IMPORTANT — script-only rule**: Report ONLY issues detected by checks G1-G5. Same principle as D4/Script F.

---

## 8. Script H: UX Copy Quality Check (4 Sub-Checks H1-H4)

Single `figma_execute` script for D8 Instance Integrity copy quality sub-checks. Heuristic checks — auditor should verify flagged items.

```js
return (async () => {
  const screen = await figma.getNodeByIdAsync('{{NODE_ID}}');
  if (!screen) return JSON.stringify({ error: 'Screen node not found', nodeId: '{{NODE_ID}}' });

  const allNodes = screen.findAll(n => true);
  const issues = [];

  const GENERIC_CTA = /^(submit|ok|send|click here|go|done|cancel|yes|no|confirm|next|back|close|continue)$/i;
  const ACTION_VERBS = /^(add|create|save|delete|remove|update|edit|share|download|upload|sign|log|view|open|start|join|buy|get|try|learn|explore|discover|browse|search|find|filter|sort|reset|apply|clear|copy|paste|cut|undo|redo|refresh|retry|dismiss|skip|accept|decline|approve|reject|submit|publish|send|reply|forward|attach|pin|unpin|archive|restore|mute|unmute|block|unblock|follow|unfollow|like|dislike|rate|review|comment|report|flag|mark|set|enable|disable|toggle|switch|expand|collapse|show|hide|minimize|maximize)/i;

  // CHECK H1: CTA quality — detect button/CTA TEXT nodes, check against generic patterns
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    const parentName = (node.parent?.name || '').toLowerCase();
    const nodeName = (node.name || '').toLowerCase();
    const isButtonText = /button|btn|cta|action|primary|secondary/.test(parentName) ||
                         /button|btn|cta|action/.test(nodeName);
    if (!isButtonText) continue;
    const text = (node.characters || '').trim();
    if (!text) continue;
    if (GENERIC_CTA.test(text)) {
      const isPrimary = /primary|cta|main/.test(parentName);
      issues.push({
        check: 'H1', severity: isPrimary ? 'Major' : 'Minor',
        msg: `${isPrimary ? 'Primary' : 'Secondary'} CTA text "${text}" is generic — use specific action verb (e.g., "Save Changes", "Add to Cart")`,
        nodeId: node.id, nodeName: node.name, text
      });
    } else if (!ACTION_VERBS.test(text)) {
      issues.push({
        check: 'H1', severity: 'Minor',
        msg: `CTA text "${text}" does not start with action verb`,
        nodeId: node.id, nodeName: node.name, text
      });
    }
  }

  // CHECK H2: Error message structure — detect error TEXT, check sentence count >= 2
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    const nameLower = (node.name || '').toLowerCase();
    const parentNameLower = (node.parent?.name || '').toLowerCase();
    const isError = /error|alert|warning|danger|invalid|fail/.test(nameLower) ||
                    /error|alert|warning|danger/.test(parentNameLower);
    if (!isError) continue;
    const text = (node.characters || '').trim();
    if (!text || text.length < 5) continue;
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
    if (sentences.length < 2) {
      issues.push({
        check: 'H2', severity: 'Minor',
        msg: `Error message "${text.slice(0, 40)}..." has ${sentences.length} sentence — should follow What+Why+How structure (>=2 sentences)`,
        nodeId: node.id, nodeName: node.name, text: text.slice(0, 80)
      });
    }
  }

  // CHECK H3: Empty state structure — detect empty state TEXT, check sentence count >= 2
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    const nameLower = (node.name || '').toLowerCase();
    const parentNameLower = (node.parent?.name || '').toLowerCase();
    const isEmptyState = /empty.?state|no.?data|no.?results|no.?items|placeholder.?text/.test(nameLower) ||
                         /empty.?state|no.?data|no.?results/.test(parentNameLower);
    if (!isEmptyState) continue;
    const text = (node.characters || '').trim();
    if (!text || text.length < 5) continue;
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
    if (sentences.length < 2) {
      issues.push({
        check: 'H3', severity: 'Minor',
        msg: `Empty state text "${text.slice(0, 40)}..." has ${sentences.length} sentence — should follow What+Why+How structure (>=2 sentences)`,
        nodeId: node.id, nodeName: node.name, text: text.slice(0, 80)
      });
    }
  }

  // CHECK H4: Dialog button labels — detect dialog ancestor, check button text isn't generic
  for (const node of allNodes) {
    if (node.type !== 'TEXT') continue;
    // Walk up to find dialog ancestor
    let ancestor = node.parent;
    let isInDialog = false;
    let depth = 0;
    while (ancestor && depth < 6) {
      const aName = (ancestor.name || '').toLowerCase();
      if (/dialog|modal|confirm|alert|popup|overlay/.test(aName)) {
        isInDialog = true;
        break;
      }
      ancestor = ancestor.parent;
      depth++;
    }
    if (!isInDialog) continue;
    // Check if this is a button text inside the dialog
    const parentName = (node.parent?.name || '').toLowerCase();
    const isButtonText = /button|btn|action/.test(parentName);
    if (!isButtonText) continue;
    const text = (node.characters || '').trim();
    if (/^(ok|cancel|yes|no)$/i.test(text)) {
      issues.push({
        check: 'H4', severity: 'Minor',
        msg: `Dialog button "${text}" is generic — use action-labeled text (e.g., "Delete Account", "Keep Editing")`,
        nodeId: node.id, nodeName: node.name, text
      });
    }
  }

  return JSON.stringify({
    totalIssues: issues.length,
    issues
  }, null, 2);
})();
```

**Note**: These are heuristic checks based on node naming patterns. The auditor should verify flagged items — false positives are expected for non-standard naming conventions.

---

## 9. Screen Diff Template (Draft vs Handoff Visual Comparison)

> **Note**: Sections 9-12 were renumbered from 7-10 in v1.1.0 after inserting Scripts G and H.

Use when comparing two versions of the same screen. Dispatch as `Task(subagent_type="general-purpose", model="sonnet")`.

### Prompt Template

Replace `{{PLACEHOLDERS}}` before dispatching.

```
You are a visual QA specialist for Figma design validation. Compare two screen versions
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
3. Run positional diff script (Script B from quality-audit-scripts.md) to detect metric deltas.
4. Examine both screenshots systematically and identify ALL differences.

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
```

---

## 10. Per-Element Position Analysis

For each element in a screen, evaluate if current positioning (absolute, auto-layout child, anchored) is appropriate.

### Decision Tree

```
Is this element inside an auto-layout container?
  Yes ->
    Is it a badge, icon overlay, or absolutely-positioned decoration?
      Yes -> layoutPositioning=ABSOLUTE is appropriate
      No  -> layoutPositioning=AUTO (default) — element flows with container
  No ->
    Is the screen scrollable?
      Yes ->
        Is this element pinned (header, bottom CTA)?
          Yes -> Use constraints (MAX for bottom, MIN for top)
          No  -> Use auto-layout vertical stack for main content
      No (fixed viewport) ->
        What type of element is this?
          Full-width surface (header, footer, card) -> constraints STRETCH or LEFT_RIGHT horizontal, MIN or MAX vertical per position
          Centered element (modal, dialog) -> constraints CENTER horizontal, CENTER or MIN vertical
          Bottom-anchored (CTA, nav bar) -> constraints STRETCH or CENTER horizontal, MAX vertical
          Top-left content -> constraints MIN+MIN (Top+Left)
          Other -> evaluate per intent, use constraints for fixed positioning
```

### Per-Type Constraint Rules

| Element Type | Horizontal | Vertical | Notes |
|--------------|------------|----------|-------|
| Full-width surface (header, card) | STRETCH or LEFT_RIGHT | MIN (Top) or MAX (Bottom) per position | Top surfaces: MIN, bottom surfaces: MAX |
| Centered element (modal, alert) | CENTER | CENTER or MIN | Use CENTER vertical if vertically centered, MIN if top-aligned |
| Bottom-anchored (CTA, nav bar) | STRETCH or CENTER | MAX (Bottom) | Use STRETCH for full-width, CENTER if centered |
| Top-left content | MIN | MIN | Default for most content anchored to top-left |

### Scrollable Screen Rules

- **Main content area**: Use auto-layout VERTICAL with itemSpacing. All children have constraints MIN+MIN (content flows top-down).
- **Pinned elements** (header, bottom CTA): Absolute positioning OR constraints MAX (bottom) / MIN (top) if outside main content flow.
- **DO NOT** use absolute positioning for main content blocks in scrollable screens — breaks responsive behavior.

### Fixed Viewport Rules

- **Screen root**: FRAME, no auto-layout (it's a stage). Use constraints on direct children.
- **Overlays/badges**: layoutPositioning=ABSOLUTE inside auto-layout containers.
- **Content blocks**: Use auto-layout for internal structure, constraints for positioning relative to screen edges.

---

## 11. Scrollability Check

Verify whether screen is intended as scrollable or fixed viewport, and whether structure matches intent.

### Indicators of Scrollable Intent

- Screen height > viewport height (e.g., 1200px vs 871px)
- Design includes long content lists, repeated cards, or vertical content that extends beyond one screen
- User stories mention scrolling behavior

### Indicators of Fixed Viewport Intent

- Screen height = viewport height exactly (e.g., 871px)
- All content visible within one screen, no indication of "more content below"
- Bottom-pinned CTA or navigation bar

### Structural Verification

**If scrollable:**
- Main content area: auto-layout VERTICAL with itemSpacing
- All main content children: constraints MIN+MIN (content flows top-down)
- Pinned elements (header, bottom CTA): absolute positioning OR outside main content flow

**If fixed viewport:**
- Screen root: FRAME without auto-layout (stage)
- Direct children: per-type constraint rules (Section 10)
- Bottom-anchored elements: constraints MAX vertical
- Full-width elements: constraints STRETCH or LEFT_RIGHT horizontal

### Common Errors

- **Scrollable screen with all absolute positioning**: Content won't adapt to content height changes
- **Fixed viewport screen with auto-layout root**: Unnecessary complexity, root should be stage
- **Scrollable screen with mixed constraints**: Some children MIN+MIN, others MAX — breaks flow

---

## 12. Positional Diff Script (Enhanced)

Alternative to Script B for more detailed positional analysis. Use when Draft reference is available and detailed metric tracking is needed.

```js
return (async () => {
  const draft    = await figma.getNodeByIdAsync('{{DRAFT_NODE_ID}}');
  const handoff  = await figma.getNodeByIdAsync('{{NODE_ID}}');
  if (!draft || !handoff) return JSON.stringify({ error: 'Node not found' });

  // Build name-based lookup map from Draft
  const draftMap = new Map();
  const buildMap = (node, prefix = '') => {
    const path = prefix ? `${prefix}/${node.name}` : node.name;
    draftMap.set(path, {
      x: Math.round(node.x),
      y: Math.round(node.y),
      w: Math.round(node.width),
      h: Math.round(node.height),
      type: node.type
    });
    if ('children' in node) {
      for (const child of node.children) {
        buildMap(child, path);
      }
    }
  };
  buildMap(draft);

  // Compare Handoff nodes to Draft
  const diffs = [];
  const compare = (node, prefix = '') => {
    const path = prefix ? `${prefix}/${node.name}` : node.name;
    const draftData = draftMap.get(path);
    if (draftData) {
      const dx = Math.round(node.x) - draftData.x;
      const dy = Math.round(node.y) - draftData.y;
      const dw = Math.round(node.width) - draftData.w;
      const dh = Math.round(node.height) - draftData.h;
      const absDx = Math.abs(dx);
      const absDy = Math.abs(dy);
      const absDw = Math.abs(dw);
      const absDh = Math.abs(dh);

      if (absDx > 3 || absDy > 3 || absDw > 3 || absDh > 3) {
        let severity = 'Minor';
        if (absDx > 8 || absDy > 8 || absDw > 8 || absDh > 8) severity = 'Major';
        if (absDx > 16 || absDy > 16) severity = 'Critical';

        diffs.push({
          path,
          nodeId: node.id,
          type: node.type,
          handoff: { x: Math.round(node.x), y: Math.round(node.y), w: Math.round(node.width), h: Math.round(node.height) },
          draft: { x: draftData.x, y: draftData.y, w: draftData.w, h: draftData.h },
          delta: { dx, dy, dw, dh },
          severity
        });
      }
    }
    if ('children' in node) {
      for (const child of node.children) {
        compare(child, path);
      }
    }
  };
  compare(handoff);

  return JSON.stringify({
    draftSize: { w: draft.width, h: draft.height },
    handoffSize: { w: handoff.width, h: handoff.height },
    totalDiffs: diffs.length,
    criticalDiffs: diffs.filter(d => d.severity === 'Critical').length,
    majorDiffs: diffs.filter(d => d.severity === 'Major').length,
    minorDiffs: diffs.filter(d => d.severity === 'Minor').length,
    diffs
  }, null, 2);
})();
```

**Usage**: Use this enhanced version when you need hierarchical path tracking and automatic severity classification. Use Script B for lighter-weight top-level comparison.

---

## Cross-References

- **quality-dimensions.md** — 11 dimension rubrics, composite scoring formula, depth tier definitions, contradiction resolutions
- **quality-procedures.md** — Spot/Standard/Deep audit execution procedures, fix cycles, Handoff Audit Template that references these scripts, Deep judge templates
- **Convergence Protocol** (journal schema for audit results): `convergence-protocol.md`
- **Plugin API** (figma_execute patterns): `plugin-api.md`
- **Design Rules** (MUST/SHOULD/AVOID — context for interpreting script findings): `design-rules.md`

---

## Maintenance Notes

### Updating Audit Scripts

When modifying scripts A-I:

- [ ] Update script in this file (Sections 1-6)
- [ ] Update corresponding dimension rubric in quality-dimensions.md Section 2
- [ ] Update quality-procedures.md Handoff Audit Template (Section 4) if script inputs/outputs change
- [ ] Update quality-procedures.md Judge 2 prompt (Section 7) if script A-F changes affect D2/D4
- [ ] Test script in live Figma file before committing
- [ ] Document any new placeholder variables in quality-procedures.md Section 4

### Adding New Scripts

When adding Script G or beyond:

- [ ] Add script to this file with clear documentation
- [ ] Assign to a quality dimension (update quality-dimensions.md Section 2 rubric)
- [ ] Reference script in quality-procedures.md Handoff Audit Template
- [ ] Add to appropriate Deep judge template if needed
- [ ] Update cross-references in all 3 quality model files
