# Draft-to-Handoff Workflow

> **Compatibility**: Verified against figma-console-mcp v1.10.0, figma-use v0.11.3 (February 2026)
>
> **Scope**: End-to-end workflow for converting hand-designed Draft pages into structured, component-based Handoff pages. For tool selection guidance, see `tool-playbook.md`. For error recovery, see `anti-patterns.md`. For operation journaling, anti-regression, batch scripting, and subagent delegation, see `convergence-protocol.md`.

---

## Critical Principles

These six principles override all other workflow guidance. They address systemic failures documented in production session post-mortems.

| # | Principle | Rationale |
|---|-----------|-----------|
| 1 | **Clone-first, build-never** (for existing designs) | Only cloning preserves IMAGE fills, exact fonts, and visual properties. The Plugin API cannot create IMAGE fills from external sources — see `anti-patterns.md` Hard Constraints |
| 2 | **Figma is the source of truth, text is supplementary** | Text docs (PRDs, reconstruction guides) provide naming and annotation context but NEVER replace reading the actual Figma design nodes |
| 3 | **Gate at every stage** | If any stage fails or source designs cannot be read, STOP and inform the user — never proceed silently |
| 4 | **Visual fidelity is the primary metric** | Every screen must pass `figma_diff_visual` against its Draft original during construction, not just at the end |
| 5 | **Converge, never regress** | Log every mutation to the operation journal; check journal before every operation; after context compaction, re-read journal — NEVER redo logged work. See `convergence-protocol.md` |
| 6 | **Batch for efficiency** | Use `figma_execute` batch scripts for 3+ homogeneous operations (renames, moves, fills) to save 70% tokens; see `convergence-protocol.md` |

---

## Simplified Entry Point (Recommended)

For the most common Draft-to-Handoff workflow, provide only:

1. **Source page** (Draft) — name or page ID
2. **Target page** (Handoff) — name or page ID (created if needed)
3. **Supplementary text documents** (optional) — PRD, design guidelines, reconstruction guide

The system executes the full workflow autonomously using the phased approach below. For 5+ screens, the orchestrator dispatches each phase as a subagent (see `convergence-protocol.md` Subagent Delegation Model). The detailed Phase 0-5 workflow provides manual control points for advanced users.

**Persistence files** (created automatically at Phase 0):
- `specs/figma/operation-journal.jsonl` — append-only log of every Figma mutation (anti-regression)
- `specs/figma/session-state.json` — periodic phase-level snapshot (quick resume)

---

## Operational Rules

These 15 rules are derived from empirical analysis of 7 production sessions (~600 MCP calls, 14 context compactions, 1 critical quality failure). Violating any rule risks context overflow, orphaned components, silent data loss, or 100% incorrect output.

| # | Rule | Rationale |
|---|------|-----------|
| 1 | Max 5-6 components per session (calibrate based on actual token usage); for 5+ screens, use subagent delegation | Prevents context overflow; see `convergence-protocol.md` |
| 2 | **Journal every mutation** — append to `operation-journal.jsonl` after EVERY successful Figma mutation; write session snapshot after each batch | Survives context compaction at operation granularity |
| 3 | **Check journal before every mutation** — if operation already logged, SKIP it | Prevents regression (redoing already-completed work) |
| 4 | Components before screens — Phase 1 before Phase 2 | Prevents orphaned components |
| 5 | Use figma-use for 1-2 atomic operations; use `figma_execute` batch scripts for 3+ same-type operations | 60-85% less token consumption; batch scripts save additional 70% |
| 6 | `figma_clear_console` before any `figma_execute` batch | Prevents buffer rotation data loss |
| 7 | Verify with `figma_export_node` or screenshot after each phase | Catches problems early |
| 8 | Use `figma_node_children` instead of `figma_node_tree` on large files (>500 nodes) | Prevents token limit errors |
| 9 | **Fallback protocol**: If a figma-use tool fails twice consecutively on the same operation, fall back to the equivalent figma-console approach and log the failure | Prevents figma-use-first from becoming a single point of failure |
| 10 | **Error recovery**: After a multi-call figma-use sequence fails mid-way, verify partial state via `figma_node_children` before retrying or falling back; delete incomplete nodes to avoid orphaned partial components | Prevents partial-state accumulation |
| 11 | **NEVER build Handoff screens from text descriptions alone** | Text cannot capture IMAGE fills, exact fonts, layer ordering, opacity overlays, gradients, or any visual property — produces 100% incorrect output |
| 12 | **If source Figma access fails, STOP and inform user** | Prevents hours of wasted work producing wrong output. Message: "I cannot access the Draft screen [name]. I need to read the actual Figma design to build an accurate Handoff version." |
| 13 | **Clone-first for existing designs** | When a Draft page contains finalized designs, ALWAYS clone screens to preserve IMAGE fills and visual fidelity. Only build from scratch for screens that do not exist in the Draft |
| 14 | **Mandatory `figma_diff_visual` during construction** | Run visual comparison after every 4 screens (not just at Phase 5). If fidelity score is below threshold, STOP and show the comparison before proceeding |
| 15 | **After context compaction, re-read journal** — rebuild completed-operations set from `operation-journal.jsonl` and resume from first uncompleted operation; NEVER restart a phase from scratch | See `convergence-protocol.md` Compact Recovery Protocol |

---

## Progress Reporting

At each phase boundary, emit a brief status message to the user. This provides real-time visibility without requiring the user to check session state files.

| Phase | Message Template |
|-------|-----------------|
| Phase 0 start | "Starting inventory of Draft page — scanning [N] screens..." |
| Phase 0 complete | "Inventory complete: [N] screens found, [M] with images (will clone), [K] unique fonts. Proceeding to component library." |
| Phase 1 complete | "Component library ready: [N] components created. Proceeding to screen transfer." |
| Phase 2 progress | "Transferred [N]/[T] screens. Visual fidelity gate: [P] passed, [F] flagged." |
| Phase 2 complete | "All [T] screens transferred. Proceeding to prototype wiring." |
| Phase 3 complete | "Prototype wiring complete: [N] connections. Proceeding to annotations." |
| Phase 4 complete | "Annotations added to [N] screens. Proceeding to final validation." |
| Phase 5 complete | "Validation complete. [P]/[T] screens passed visual fidelity. Health score: [S]/100." |

**Rule**: Never skip progress messages. They are the user's primary feedback channel during autonomous execution.

---

## Rollback Protocol

If validation fails at a Phase 2 gate or at Phase 5, offer the user a clean rollback option:

1. **Detect failure**: `figma_diff_visual` shows significant deviation, or Phase 5 reports <80% visual fidelity pass rate
2. **Present options to user**:
   - **Option A**: Fix specific screens — identify which screens failed and attempt repair (max 3 fix cycles per screen)
   - **Option B**: Full rollback — delete ALL generated Handoff content and restart from Phase 0
3. **Execute rollback** (if Option B chosen):
   - Read all `handoff_id` values from session state file
   - `figma_node_delete(ids: "handoffId1 handoffId2 ...")` — delete all generated screens
   - Delete component section if components were created: `figma_node_delete(ids: dsSectionId)`
   - **Log rollback to journal**: append `{"op":"rollback","target":"session","detail":{"deleted_ids":["id1","id2",...],"reason":"Visual fidelity below threshold"}}` — this ensures convergence checks know these operations were undone and need re-execution
   - Reset session state file to Phase 0 with `"notes": "Rollback performed — restarting"`
   - Re-run Phase 0 to refresh inventory (node IDs may have shifted)

**Prerequisite**: Rollback depends on complete session state tracking. Every created node ID (screens, components, sections) MUST be recorded in the session state file at creation time. If session state is incomplete, rollback will leave orphaned nodes.

---

## Dual-Layer State Persistence

Two complementary persistence files provide operation-level granularity and quick-resume capability. See `convergence-protocol.md` for the full specification (JSONL format, entry types, session snapshot schema, and resume procedure). **When journal and snapshot disagree, the journal is authoritative** (append-only, written more frequently).

| File | Purpose | Update Cadence |
|------|---------|---------------|
| `specs/figma/operation-journal.jsonl` | Append-only log of every Figma mutation (anti-regression) | After EVERY mutating operation — no exceptions |
| `specs/figma/session-state.json` | Periodic full-state snapshot (quick phase-level resume) | Phase boundaries + every 4-5 items + after batch scripts |

**Draft-to-Handoff specific snapshot cadence**:
- Phase 0: After inventory is complete
- Phase 1: After every 5 components
- Phase 2: After every 4 screens (aligned with `figma_diff_visual` gate)
- Phase 3: After all prototype connections
- Phases 4-5: After completion
- After any batch script execution or subagent completion

---

## Phase 0 — Deep Inventory and Plan (Read-Only)

**Goal**: Produce a comprehensive inventory of every Draft screen's internal structure, including image fills, fonts, and component instances. This is the foundation for all subsequent phases.

**Delegation**: Run inline (lightweight, no dispatch overhead).

**Tools**: figma-use for reads, local file for output.

### Step 0.0 — Initialize Persistence

1. Create `specs/figma/operation-journal.jsonl` if it does not exist
2. Create `specs/figma/session-state.json` if it does not exist
3. If files already exist (session resume): read both files, determine resume point — see Resume Procedure above

### Step 0.1 — Preflight

1. `figma_get_status` — verify connection
2. `figma_page_list` — find source page ID
3. **GATE**: If source page not found → STOP, inform user

### Step 0.2 — Page-Level Scan

1. `figma_node_children(id: sourcePageId)` — list all top-level screen frames
2. Record each screen: name, dimensions, node ID

### Step 0.3 — Deep Screen Inspection (MANDATORY)

> **This step is the critical difference from the previous workflow.** Every screen MUST be deeply inspected before any construction begins.

For EACH screen on the source page:

1. `figma_node_children(id: screenId)` — full layer tree
2. Catalog for each screen:
   - **Dimensions**: width, height
   - **Fill types**: flag nodes with `type: 'IMAGE'` fills → these MUST be cloned, not rebuilt
   - **Fonts used**: extract `fontName` from all text nodes (family + style)
   - **Component instances**: map to existing library components
   - **Text content**: characters from each text node
   - **Auto-layout properties**: layoutMode, padding, spacing
   - **Effects**: shadows, blurs, corner radius
3. Write per-screen inventory to session state file

**GATE**: If ANY screen cannot be read (empty children, connection error, node not found):
- STOP immediately
- Report which screens failed
- Do NOT proceed to Phase 1

### Step 0.4 — Image and Font Inventory

1. **Image inventory**: aggregate all screens with IMAGE fills into a single list. These screens MUST use the clone approach in Phase 2 — there is no alternative
2. **Font inventory**: aggregate all unique font families and styles across all screens. Verify availability before Phase 2:
   - For screens being cloned: fonts are preserved automatically
   - For any manually created elements (annotations, labels): load required fonts explicitly

### Step 0.5 — Component Candidates

1. `figma_find(query: "COMPONENT", scope: draftPageId)` — find existing components
2. Identify recurring patterns across screens (shared headers, buttons, cards)
3. Cross-reference with existing library: `figma_search_components`

**Output**: Local markdown file with:
- List of screens (name, size, node ID, **image flag**, **fonts used**)
- Image inventory (screens requiring clone approach)
- Font inventory (all unique fonts)
- List of recurring patterns (candidates for componentization)
- List of existing components and usage
- Decision table: clone approach (default for all screens with images) vs build approach (only for screens with no source)

**Quality gate**: Plan must be reviewed and approved before proceeding to Phase 1.

---

## Phase 1 — Component Library

**Goal**: Create all components that screens will reference.

**Critical rule**: Components MUST exist before any screen is built on the Handoff page (Rule #4).

**Delegation**: Dispatch as `Task(general-purpose)` for 3+ components. Subagent reads `convergence-protocol.md` and `workflow-draft-to-handoff.md` (Phase 1 section). See `convergence-protocol.md` Subagent Delegation Model.

**Tools**: figma-use for creation; `figma_execute` batch scripts for homogeneous property-setting (3+ fills, 3+ renames).

### Convergence Gate (before any creation)

```
1. Read operation-journal.jsonl
2. Build set of already-created component names
3. For each component in the plan:
   - If journal has create_component with this name → SKIP
   - If not → proceed to create
```

### Creation Sequence

```
For each component NOT already in the journal:
  1. figma_create_component(name, x, y, width, height, fill, parent: dsSectionId)
  2. → LOG: {"op":"create_component","target":"<newId>","detail":{"name":"...","parent":"..."}}
  3. figma_set_layout(id, mode, padding, gap, align)
  4. → LOG: {"op":"set_layout","target":"<id>","detail":{...}}
  5. figma_create_text(parent: componentId, ...) — for text children
  6. figma_set_fill / figma_set_stroke / figma_set_radius — styling
  7. figma_component_add_prop(id, name, type, default) — exposed properties
  8. figma_node_rename(id, finalName)
  9. → LOG: {"op":"rename","target":"<id>","detail":{"from":"...","to":"..."}}

For variant sets:
  1. Create individual COMPONENT variants (each logged)
  2. figma_component_combine(ids: "id1 id2 id3", name: "ComponentName")
  3. → LOG: {"op":"create_variant_set","target":"<setId>","detail":{"name":"...","variants":["id1","id2","id3"]}}
```

**Batch optimization**: If 3+ components need the same fill or stroke, use a single `figma_execute` batch script (see `convergence-protocol.md` Batch Script Templates).

**Checkpoint**: After every 5 components, write session snapshot (Rule #2).

**Verification**: `figma_export_node(id: dsSectionId, format: "PNG")` — visual check.

---

## Phase 2 — Screen Transfer (Handoff Page)

**Goal**: Transfer each screen from Draft to Handoff, preserving visual fidelity.

**Delegation**: Dispatch as `Task(general-purpose)` per batch of 4-6 screens. Each batch is independent — safe for parallel dispatch if multiple agents are available. See `convergence-protocol.md` Subagent Delegation Model.

**Tools**: figma-use for cloning and modification, figma-console for screenshots and `figma_execute` batch scripts.

### Convergence Gate (before any transfer)

```
1. Read operation-journal.jsonl
2. Build set of already-transferred screen source IDs (op: clone_screen)
3. For each screen in the plan:
   - If journal has clone_screen with this source ID → SKIP
   - If not → proceed to clone + restructure
```

### Default Approach: Clone + Restructure (for ALL screens with Draft source)

This is the ONLY approach that preserves IMAGE fills, exact fonts, and visual properties. Use for every screen that exists in the Draft.

```
For each screen NOT already in the journal:
  1. figma_node_clone(ids: draftScreenId) — clone entire screen
  2. → LOG: {"op":"clone_screen","target":"<clonedId>","detail":{"source":"<draftId>","name":"<screenName>","handoff_id":"<clonedId>"}}
  3. figma_node_set_parent(id: clonedId, parent: handoffSectionId) — move to Handoff
  4. Restructure the cloned screen:
     a. Apply auto-layout where missing
     b. Replace inline elements with component instances (from Phase 1)
     c. Batch rename layers using figma_execute batch script (see convergence-protocol.md)
        — the batch script includes idempotency checks (skip if already named correctly)
     d. → LOG: {"op":"batch_rename","target":"batch","detail":{"screen":"<name>","count":N}}
  5. Update session snapshot with handoff_id
```

**Batch optimization**: After cloning 4-6 screens, batch all layer renames across screens into a single `figma_execute` call. The batch script template in `convergence-protocol.md` includes built-in `already_done` checks, making the batch safe to re-run after compaction.

### Fallback Approach: Build from Figma Node Data (ONLY when clone fails)

Use ONLY when `figma_node_clone` fails for a specific screen AND the screen has no IMAGE fills. Must justify in session state file why clone failed.

```
  1. Read ALL visual properties from the Draft screen via figma_node_children
  2. Build from FIGMA NODE DATA (NOT text), matching exact properties:
     - Same fills (colors, gradients — NOT images, which cannot be recreated)
     - Same fonts (fontName from source nodes, NOT defaults)
     - Same dimensions, spacing, padding
  3. For any child nodes with IMAGE fills: clone those individual nodes
     and reparent into the new screen
```

> **HARD CONSTRAINT**: If a screen contains IMAGE fills and cloning fails, STOP and inform the user. There is no way to recreate IMAGE fills programmatically. See `anti-patterns.md` Hard Constraints and `plugin-api.md` Image Handling.

### Mandatory Visual Fidelity Gate (Rule #15)

After every 4 screens:

1. `figma_diff_visual(from: draftScreenId, to: handoffScreenId)` — for each of the 4 screens
2. If ANY screen shows significant visual deviation:
   - STOP construction
   - Show the comparison to the user
   - Offer options: fix specific screens, continue anyway, or full rollback (see Rollback Protocol)
3. Record diff results in session state file

**Checkpoint**: After every 4 screens, write state file with screen IDs and diff results.

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

Text documents (PRDs, reconstruction guides, design guidelines) are used HERE — as the source for annotation content, route names, component descriptions, and developer notes. This is the correct use of supplementary text documents.

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

**Goal**: Comprehensive validation of ALL screens against Draft originals.

**Tools**: figma-use for lint/diff, figma-console for audit/screenshots.

### Step 5.1 — Visual Fidelity Validation (ALL screens)

```
For EACH screen:
  1. figma_diff_visual(from: draftScreenId, to: handoffScreenId)
  2. Record result in session state
  3. If visual deviation exceeds threshold:
     a. Take side-by-side screenshots (Draft + Handoff)
     b. Flag for user review
```

### Step 5.2 — Design System Audit

1. figma-console `figma_audit_design_system` — health score (naming, tokens, components, accessibility, consistency, coverage)

### Step 5.3 — Cleanup

1. Clean up orphaned nodes: `figma_node_delete(ids: "orphanId1 orphanId2 ...")`
2. Verify all screens in session state have `status: "complete"` + passing diff results

### Step 5.4 — Summary Report

Present to user (using Progress Reporting template):
- Screens transferred: N/N (passed/total)
- Visual fidelity: N screens passed `figma_diff_visual`
- Images preserved: N/N (via cloning)
- Font accuracy: all fonts match Draft
- Health score: N/100

If visual fidelity pass rate is below 80%, offer the user the Rollback Protocol options before declaring completion.

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
| 15 | **Screens built from text, not Figma** | NEVER use text docs as design source — always read Figma nodes via `figma_node_children` (Rule #12) |
| 16 | **All images lost (black rectangles)** | Use `figma_node_clone` for screens with IMAGE fills — Plugin API cannot create IMAGE fills (Rule #14) |
| 17 | **Wrong fonts (Inter instead of source)** | Read `fontName` from Draft text nodes; match exactly when building or verify after cloning |
| 18 | **No visual fidelity check during construction** | Mandatory `figma_diff_visual` after every 4 screens (Rule #14) |
| 19 | **Regression: redoing already-completed work** | Read `operation-journal.jsonl` before every mutation; skip logged operations (Rule #3) |
| 20 | **State lost after context compaction** | Re-read journal + snapshot; resume from first uncompleted operation (Rule #15) |

---

## Fallback Protocol

If figma-use-first fails, follow this escalation path:

1. **Retry once** with the same figma-use tool (transient failures are common)
2. **If second failure**: fall back to the equivalent figma-console approach
3. **Log the failure**: append `{"op":"fallback","target":"<nodeId>","detail":{"tool":"<figma-use tool>","error":"<msg>","fallback":"figma_execute"}}` to the operation journal
4. **After a multi-call sequence fails mid-way**: verify partial state via `figma_node_children` before retrying or falling back; delete incomplete nodes if needed

**Source access failure protocol** (supersedes the above for source read failures):
- If `figma_node_children` fails on ANY Draft screen → STOP immediately
- Do NOT fall back to text documents, PRDs, or reconstruction guides
- Inform user: "I cannot access Draft screen [name] (node [id]). I need to read the actual Figma design to build an accurate Handoff version."
- Suggest the user verify: (1) Figma file is open, (2) MCP connection is active via `figma_get_status`, (3) node IDs are correct

> **Cross-references**: For error details, see `anti-patterns.md`. For IMAGE fill limitations, see `anti-patterns.md` Hard Constraints and `plugin-api.md` Image Handling. For figma-use tool inventory, see `figma-use-overview.md`. For tool selection guidance, see `tool-playbook.md`. For operation journal spec, convergence rules, batch scripting, and subagent delegation, see `convergence-protocol.md`.
