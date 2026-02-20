# Draft-to-Handoff Workflow

> **Compatibility**: Verified against figma-console-mcp v1.10.0, figma-use v0.11.3 (February 2026)
>
> **Scope**: End-to-end workflow for converting hand-designed Draft pages into structured, component-based Handoff pages. For tool selection guidance, see `tool-playbook.md`. For error recovery, see `anti-patterns.md`.

---

## Operational Rules

These 11 rules are derived from empirical analysis of 6 production sessions (~480 MCP calls, 14 context compactions). Violating any rule risks context overflow, orphaned components, or silent data loss.

| # | Rule | Rationale |
|---|------|-----------|
| 1 | Max 5-6 components per session (calibrate based on actual token usage) | Prevents context overflow |
| 2 | Write node IDs to local file after each batch (see Session State Persistence below) | Survives context compaction |
| 3 | Components before screens — Phase 1 before Phase 2 | Prevents orphaned components |
| 4 | Use figma-use for all atomic operations | 60-85% less token consumption |
| 5 | Reserve figma-console `figma_execute` for conditional logic only | Reduces fire-log-verify overhead |
| 6 | `figma_clear_console` before any `figma_execute` batch | Prevents buffer rotation data loss |
| 7 | Verify with `figma_export_node` or screenshot after each phase | Catches problems early |
| 8 | Never use `figma_status` or `figma_page_current` from figma-use | 100% failure rate confirmed — see `figma-use-overview.md` Known Broken Tools |
| 9 | Use `figma_node_children` instead of `figma_node_tree` on large files (>500 nodes) | Prevents token limit errors |
| 10 | **Fallback protocol**: If a figma-use tool fails twice consecutively on the same operation, fall back to the equivalent figma-console approach and log the failure | Prevents figma-use-first from becoming a single point of failure |
| 11 | **Error recovery**: After a multi-call figma-use sequence fails mid-way, verify partial state via `figma_node_children` before retrying or falling back; delete incomplete nodes to avoid orphaned partial components | Prevents partial-state accumulation |

---

## Session State Persistence Pattern

After each batch of operations, write created node IDs and phase state to a local JSON file. This survives context compaction and enables session resumption.

**File path**: `specs/figma/session-state.json` (relative to project root)

**Template**:
```json
{
  "phase": 1,
  "timestamp": "2026-02-20T14:30:00Z",
  "file_name": "My Design File",
  "components": {
    "StatusBar": "24:4271",
    "TopBar": "24:4274",
    "PrimaryButton": "24:4280"
  },
  "screens": {},
  "connections": {},
  "notes": "Phase 1 complete — 3 of 6 components created"
}
```

**Update cadence**:
- Phase 1: After every 5 components
- Phase 2: After every 8 screens
- Phase 3: After all prototype connections are wired
- Phases 4-5: After completion

---

## Phase 0 — Inventory and Plan (Read-Only)

**Goal**: Produce a written plan with concrete node IDs before touching the file.

**Tools**: figma-use for reads, local file for output.

1. `figma_page_list` — list all pages
2. `figma_node_children(id: draftPageId)` — get top-level structure
3. For each screen frame: `figma_node_children(id: screenId)` — catalog all layers
4. `figma_find(query: "COMPONENT", scope: draftPageId)` — find existing components
5. `figma_lint(page: "Draft", preset: "design-system", verbose: true)` — baseline quality (experimental — not confirmed in figma-use v0.11.3; skip if unavailable)

**Output**: Local markdown file with:
- List of screens (name, size, node ID)
- List of recurring visual patterns (candidates for componentization)
- List of existing components and usage
- Decision table: what becomes a component vs what stays inline

**Quality gate**: Plan must be reviewed and approved before proceeding to Phase 1.

---

## Phase 1 — Component Library

**Goal**: Create all components that screens will reference.

**Critical rule**: Components MUST exist before any screen is built on the Handoff page (Rule #3).

**Tools**: figma-use exclusively.

```
For each component in the plan:
  1. figma_create_component(name, x, y, width, height, fill, parent: dsSectionId)
  2. figma_set_layout(id, mode, padding, gap, align)
  3. figma_create_text(parent: componentId, ...) — for text children
  4. figma_create_rect(parent: componentId, ...) — for decorative elements
  5. figma_set_fill / figma_set_stroke / figma_set_radius — styling
  6. figma_component_add_prop(id, name, type, default) — exposed properties
  7. figma_node_rename(id, finalName)

For variant sets:
  1. Create individual COMPONENT variants
  2. figma_component_combine(ids: "id1 id2 id3", name: "ComponentName")
```

**Checkpoint**: After every 5 components, write node IDs to session state file (Rule #2).

**Verification**: `figma_export_node(id: dsSectionId, format: "PNG")` — visual check.

---

## Phase 2 — Screen Assembly (Handoff Page)

**Goal**: Build each screen using component instances.

**Tools**: figma-use for creation, figma-console for screenshots.

**Primary approach** (building from instances):
```
For each screen in the plan:
  1. figma_create_frame(name, parent: handoffSectionId, width, height, fill)
  2. figma_create_instance(component: statusBarId, parent: screenId, x, y)
  3. figma_create_instance(component: topBarId, parent: screenId, x, y)
  4. ... (remaining component instances per screen blueprint)
  5. figma_set_props(id: instanceId, props: '{"Title": "Screen Name"}')
```

**Alternative approach** (for screens with complex non-component content):
```
  1. figma_node_clone(ids: draftScreenId) — clone from Draft
  2. figma_node_set_parent(id: clonedId, parent: handoffSectionId) — move to Handoff
  3. For each replaceable frame inside the cloned screen:
     figma_node_replace_with(id: oldFrameId, replacement: componentId)
```

**Checkpoint**: After every 8 screens, take screenshot and write state file.

---

## Phase 3 — Prototype Wiring

**Goal**: Connect screens with navigation flows.

**Tools**: figma-console `figma_execute` with `setReactionsAsync` (primary).

> **Note**: `figma_connector_create` likely creates FigJam connectors, not Figma prototype interactions — needs empirical validation before use here. Use figma-console approach until validated.

```javascript
// figma_execute — batch prototype wiring
(async () => {
  try {
    for (const flow of flows) {
      const source = await figma.getNodeByIdAsync(flow.sourceId);
      await source.setReactionsAsync([{
        trigger: { type: 'ON_CLICK' },
        actions: [{
          type: 'NODE',
          destinationId: flow.targetId,
          navigation: 'NAVIGATE',
          transition: { type: 'DISSOLVE', duration: 0.3 }
        }]
      }]);
    }
    return { success: true, wired: flows.length };
  } catch (e) {
    return { error: e.message };
  }
})()
```

**Operational notes**:
- Use `figma_clear_console` before the batch script (Rule #6)
- Use `actions[]` array format, not singular `action` (see `anti-patterns.md` — Recurring Error #4)
- Persist wired connection IDs to session state file after completion

---

## Phase 4 — Annotations and Documentation

**Goal**: Add developer annotations to each screen.

**Tools**: figma-use.

```
For each screen:
  figma_create_text(
    parent: sectionId,
    x: screenX, y: screenY + screenHeight + 12,
    text: "Route: WelcomeScreen\nComponents: StatusBar, PrimaryButton\nDialog triggers: none",
    font-family: "DM Sans", font-size: "10", fill: "#888888"
  )
```

For component documentation, use figma-console `figma_set_description` on COMPONENT nodes (not FRAME — see `anti-patterns.md` — Recurring Error #7).

---

## Phase 5 — Validation and Cleanup

**Goal**: Verify completeness and quality.

**Tools**: figma-use for lint, figma-console for audit.

1. `figma_lint(page: "Handoff", preset: "design-system", fix: true)` — auto-fix issues (experimental — not confirmed in figma-use v0.11.3; skip if unavailable)
2. `figma_lint(page: "Handoff", preset: "accessibility", verbose: true)` — a11y check (experimental — skip if unavailable)
3. figma-console `figma_audit_design_system` — health score
4. `figma_diff_visual(from: draftScreenId, to: handoffScreenId, output: "/tmp/diff.png")` — visual comparison per screen
5. Clean up: `figma_node_delete(ids: "orphanId1 orphanId2 ...")` — remove unused nodes

---

## Error Prevention Quick Reference

Condensed prevention-only table. For full error details, causes, and recovery procedures, see `anti-patterns.md`.

| # | Error | Prevention |
|---|-------|-----------|
| 1 | `combineAsVariants` page context | Use `figma_component_combine` (figma-use) |
| 2 | `node.reactions` throws in dynamic-page | Use `setReactionsAsync()` in `figma_execute` |
| 3 | `node.mainComponent` throws | Use `figma_node_get` (figma-use) |
| 4 | `action` vs `actions[]` format | Always use `actions: [...]` array |
| 5 | `componentPropertyDefinitions` on wrong node type | Use `figma_component_add_prop` (figma-use) |
| 6 | Screenshot scale type mismatch | Omit scale parameter |
| 7 | `figma_set_description` on FRAME | Only call on COMPONENT or STYLE nodes |
| 8 | `figma_status` returns `"8"` | Use `figma_get_status` (figma-console) or `figma_page_list` |
| 9 | `figma_page_current` returns `"8"` | Use `figma_page_list` + `figma_page_set` |
| 10 | `figma_node_tree` exceeds token limit | Use `figma_node_children` on large files |
| 11 | Console buffer rotation | `figma_clear_console` before batches |
| 12 | Plans with wrong node IDs | Verify all IDs in Phase 0 before proceeding |
| 13 | Orphaned components | Enforce Phase 1 before Phase 2 |
| 14 | Plan rejected for lacking concrete IDs | Phase 0 must produce verifiable plan with live-verified node IDs before proceeding |

---

## Fallback Protocol

If figma-use-first fails, follow this escalation path:

1. **Retry once** with the same figma-use tool (transient failures are common)
2. **If second failure**: fall back to the equivalent figma-console approach
3. **Log the failure**: note the tool name, error, and workaround in the session state file
4. **After a multi-call sequence fails mid-way**: verify partial state via `figma_node_children` before retrying or falling back; delete incomplete nodes if needed

> **Cross-references**: For error details, see `anti-patterns.md`. For figma-use tool inventory, see `figma-use-overview.md`. For tool selection guidance, see `tool-playbook.md`.
