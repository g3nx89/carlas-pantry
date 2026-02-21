# Draft-to-Handoff Workflow

> **Compatibility**: Verified against figma-console-mcp v1.10.0, figma-use v0.11.3 (February 2026)
>
> **Scope**: End-to-end workflow for converting hand-designed Draft pages into structured, component-based Handoff pages. For tool selection guidance, see `tool-playbook.md`. For error recovery, see `anti-patterns.md`. For operation journaling, anti-regression, batch scripting, and subagent delegation, see `convergence-protocol.md`.

---

## Critical Principles

These seven principles override all other workflow guidance. They address systemic failures documented in production session post-mortems (7 sessions, 3 retrospectives, 2 critical failures).

| # | Principle | Rationale |
|---|-----------|-----------|
| 1 | **Clone-first, build-never** (for existing designs) | Only cloning preserves IMAGE fills, exact fonts, and visual properties. The Plugin API cannot create IMAGE fills from external sources — see `anti-patterns.md` Hard Constraints |
| 2 | **Figma is the source of truth, text is supplementary** | Text docs (PRDs, reconstruction guides) provide naming and annotation context but NEVER replace reading the actual Figma design nodes |
| 3 | **Gate at every stage** | If any stage fails or source designs cannot be read, STOP and inform the user — never proceed silently |
| 4 | **One screen at a time — validate before proceeding** | Process each screen through the full pipeline (clone, validate, restructure, integrate components, visual diff) and confirm correctness before starting the next screen. Never batch screens — batch processing hides silent failures (e.g., empty clones marked complete) and delays error detection |
| 5 | **Smart componentization** | Componentize elements meeting ALL 3 criteria: recurrence (3+ screens), behavioral variants, codebase match. TIER 1 (naming + tokens) is always applied; TIER 2 (smart components) is recommended; TIER 3 (heavy) is optional. See `workflow-code-handoff.md` TIER System |
| 6 | **Converge, never regress** | Log every mutation to the operation journal; check journal before every operation; after context compaction, re-read journal — NEVER redo logged work. See `convergence-protocol.md` |
| 7 | **Batch homogeneous ops within a screen** | Use `figma_execute` batch scripts for 3+ same-type operations (renames, fills) within a single screen to save tokens; see `convergence-protocol.md`. This applies to operations within a screen — screen-level processing is always sequential |

---

## Simplified Entry Point (Recommended)

For the most common Draft-to-Handoff workflow, provide only:

1. **Source page** (Draft) — name or page ID
2. **Target page** (Handoff) — name or page ID (created if needed)
3. **Supplementary text documents** (optional) — PRD, design guidelines, reconstruction guide

The system executes the full workflow autonomously using the phased approach below. For 5+ screens, the orchestrator dispatches one subagent per screen (see `convergence-protocol.md` Subagent Delegation Model). Each screen is fully completed and validated before the next starts.

**Persistence files** (created automatically at Phase 0):
- `specs/figma/operation-journal.jsonl` — append-only log of every Figma mutation (anti-regression)
- `specs/figma/session-state.json` — periodic phase-level snapshot (quick resume)

---

## Operational Rules

These 22 rules are derived from empirical analysis of 9 production sessions (~750 MCP calls, 14 context compactions, 2 critical quality failures, 1 empty clone, 13 silently dropped prototype connections). Violating any rule risks context overflow, orphaned components, silent data loss, or 100% incorrect output.

| # | Rule | Rationale |
|---|------|-----------|
| 1 | Max 5-6 components per session (calibrate based on actual token usage); for 5+ screens, use subagent delegation | Prevents context overflow; see `convergence-protocol.md` |
| 2 | **Journal every mutation** — append to `operation-journal.jsonl` after EVERY successful Figma mutation; write session snapshot after each screen | Survives context compaction at operation granularity |
| 3 | **Check journal before every mutation** — if operation already logged, SKIP it | Prevents regression (redoing already-completed work) |
| 4 | Components before screens — Phase 1 before Phase 2 | Prevents orphaned components |
| 5 | Use figma-use for 1-2 atomic operations; use `figma_execute` batch scripts for 3+ same-type operations within a screen | 60-85% less token consumption; batch scripts save additional 70% |
| 6 | `figma_clear_console` before any `figma_execute` batch | Prevents buffer rotation data loss |
| 7 | Verify with screenshot or `figma_diff_visual` after EVERY screen — not after every 4 | Catches problems immediately; prevents cascading failures |
| 8 | Use `figma_node_children` instead of `figma_node_tree` on large files (>500 nodes) | Prevents token limit errors |
| 9 | **Fallback protocol**: If a figma-use tool fails twice consecutively on the same operation, fall back to the equivalent figma-console approach and log the failure | Prevents figma-use-first from becoming a single point of failure |
| 10 | **Error recovery**: After a multi-call figma-use sequence fails mid-way, verify partial state via `figma_node_children` before retrying or falling back; delete incomplete nodes to avoid orphaned partial components | Prevents partial-state accumulation |
| 11 | **NEVER build Handoff screens from text descriptions alone** | Text cannot capture IMAGE fills, exact fonts, layer ordering, opacity overlays, gradients, or any visual property — produces 100% incorrect output |
| 12 | **If source Figma access fails, STOP and inform user** | Prevents hours of wasted work producing wrong output. Message: "I cannot access the Draft screen [name]. I need to read the actual Figma design to build an accurate Handoff version." |
| 13 | **Clone-first for existing designs** | When a Draft page contains finalized designs, ALWAYS clone screens to preserve IMAGE fills and visual fidelity. Only build from scratch for screens that do not exist in the Draft |
| 14 | **Mandatory `figma_diff_visual` per screen** | Run visual comparison after EVERY screen transfer (not every 4). If fidelity score is below threshold, STOP and show the comparison before proceeding to the next screen |
| 15 | **After context compaction, re-read journal** — rebuild completed-operations set from `operation-journal.jsonl` and resume from first uncompleted operation; NEVER restart a phase from scratch | See `convergence-protocol.md` Compact Recovery Protocol |
| 16 | **childCount validation after clone** — after every clone operation, compare clone's childCount against source's childCount. If clone has 0 children but source has >0, this is a clone failure — retry once, then halt if still 0. NEVER mark a 0-child clone as complete | Prevents silent empty-frame failures (WK-01 incident) |
| 17 | **Smart componentization** — apply the TIER system from `workflow-code-handoff.md`. TIER 2 (default): componentize only elements passing all 3 gates (recurrence 3+, behavioral variants, codebase match). TIER 1: naming + tokens only (no component creation). TIER 3: componentize every recurring element | Prevents over-engineering without Enterprise plan; focuses effort on high-value components (typically 5-8) |
| 18 | **Real timestamps via Plugin API** — journal timestamps MUST come from `new Date().toISOString()` inside `figma_execute`, or from the orchestrator's real clock injected into the subagent prompt. NEVER use hardcoded placeholder timestamps | Prevents fabricated audit trails (6.5-hour span for 40-minute session in v2) |
| 19 | **Preflight existing content declaration** — before creating any content on the target page, check for existing nodes and present options to user (delete, continue, add alongside). Log decision in journal | Prevents silent overlap with content from previous sessions |
| 20 | **GROUP prototype verification** — after `setReactionsAsync`, immediately re-read `node.reactions` via `figma_execute`. If reactions.length is 0 but wiring was attempted, log as `group_unsupported` (not as success). GROUP nodes silently drop reactions | Prevents false `wired: 34, failed: 0` reports (13 silently lost in v2) |
| 21 | **One screen at a time** — process each screen through the full pipeline (clone → validate childCount → restructure → integrate components → visual diff) before starting the next. Never batch-process screens | Catches failures immediately; WK-01 empty clone would have been caught before processing 31 more screens |
| 22 | **Subagents inherit skill context** — every subagent dispatched for this workflow must load the `figma-console-mastery` skill references. See `convergence-protocol.md` Subagent Prompt Template | Prevents subagents from missing critical rules (clone-first, journal protocol, visual fidelity gates) |

---

## Progress Reporting

At each phase boundary and per-screen, emit a brief status message to the user. This provides real-time visibility without requiring the user to check session state files.

| Phase | Message Template |
|-------|-----------------|
| Phase 0 start | "Starting inventory of Draft page — scanning [N] screens..." |
| Phase 0 preflight | "Target page has [N] existing nodes: [names]. How to proceed? (A) Delete and start fresh (B) Continue from existing (C) Add alongside" |
| Phase 0 complete | "Inventory complete: [N] screens found, [M] with images (will clone), [K] unique fonts. Proceeding to component library." |
| Phase 1 complete | "Component library ready: [N] components created ([V] as COMPONENT_SETs). Proceeding to screen transfer." |
| Phase 2 per-screen | "Screen [N]/[T] — [name]: clone OK (children: [C]), restructured, [I] component instances placed, visual diff: [score]. Proceeding to next screen." |
| Phase 2 screen fail | "Screen [N]/[T] — [name]: FAILED — [reason]. Options: (A) Retry (B) Skip (C) Halt workflow" |
| Phase 2 complete | "All [T] screens transferred and validated. [I] total component instances. Proceeding to prototype wiring." |
| Phase 3 complete | "Prototype wiring: [W] confirmed, [G] GROUP nodes skipped (unsupported), [F] failed. Proceeding to annotations." |
| Phase 4 complete | "Annotations added to [N] screens. Proceeding to final validation." |
| Phase 5 complete | "Validation complete. [P]/[T] screens passed visual fidelity. [I] component instances total. Health score: [S]/100." |

**Rule**: Never skip progress messages. They are the user's primary feedback channel during autonomous execution.

---

## Rollback Protocol

If validation fails at a per-screen gate or at Phase 5, offer the user a clean rollback option:

1. **Detect failure**: `figma_diff_visual` shows significant deviation, clone produces 0 children, or Phase 5 reports <80% visual fidelity pass rate
2. **Present options to user**:
   - **Option A**: Fix this screen — attempt repair (max 3 fix cycles)
   - **Option B**: Delete this screen and re-clone from Draft
   - **Option C**: Full rollback — delete ALL generated Handoff content and restart from Phase 0
3. **Execute rollback** (if Option C chosen):
   - Read all `handoff_id` values from session state file
   - `figma_node_delete(ids: "handoffId1 handoffId2 ...")` — delete all generated screens
   - Delete component section if components were created: `figma_node_delete(ids: dsSectionId)`
   - **Log rollback to journal**: append `{"op":"rollback","target":"session","detail":{"deleted_ids":["id1","id2",...],"reason":"..."}}` — this ensures convergence checks know these operations were undone and need re-execution
   - Reset session state file to Phase 0 with `"notes": "Rollback performed — restarting"`
   - Re-run Phase 0 to refresh inventory (node IDs may have shifted)

**Per-screen rollback** (Option B) is lightweight: delete only the failed screen's handoff node, log the deletion, and re-clone from Draft. This is preferred over full rollback when a single screen fails.

**Prerequisite**: Rollback depends on complete session state tracking. Every created node ID (screens, components, sections) MUST be recorded in the session state file at creation time. If session state is incomplete, rollback will leave orphaned nodes.

---

## Dual-Layer State Persistence

Two complementary persistence files provide operation-level granularity and quick-resume capability. See `convergence-protocol.md` for the full specification (JSONL format, entry types, session snapshot schema, and resume procedure). **When journal and snapshot disagree, the journal is authoritative** (append-only, written more frequently).

| File | Purpose | Update Cadence |
|------|---------|---------------|
| `specs/figma/operation-journal.jsonl` | Append-only log of every Figma mutation (anti-regression) | After EVERY mutating operation — no exceptions |
| `specs/figma/session-state.json` | Periodic full-state snapshot (quick phase-level resume) | Phase boundaries + after every screen + after batch scripts |

**Draft-to-Handoff specific snapshot cadence**:
- Phase 0: After inventory is complete
- Phase 1: After every 5 components
- Phase 2: **After every screen** (each screen is a completion unit)
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
3. If files already exist (session resume): read both files, determine resume point — see Resume Procedure in `convergence-protocol.md`

### Step 0.1 — Preflight

1. `figma_get_status` — verify connection
2. `figma_page_list` — find source page ID and target page ID
3. **GATE**: If source page not found → STOP, inform user

### Step 0.1B — Preflight: Target Page Existing Content (Rule #19)

1. `figma_node_children(id: targetPageId)` — list existing top-level nodes on the Handoff page
2. **IF children.length > 0**:
   - Present to user: "The target page '[name]' has [N] existing nodes: [list names]. How to proceed?"
   - **(A) Delete all and start fresh** — execute deletion of all existing nodes, log each deletion
   - **(B) Continue from existing** — treat existing nodes as prior work, read journal to align
   - **(C) Add alongside** — create new sections alongside existing (warn: may cause coordinate overlap)
3. Log decision in journal: `{"op":"preflight_content_decision","target":"<pageId>","detail":{"choice":"A|B|C","existing_nodes":["id1","id2"]}}`
4. **IF choice A**: execute deletion, then proceed with empty page

### Step 0.2 — Page-Level Scan

1. `figma_node_children(id: sourcePageId)` — list all top-level screen frames
2. Record each screen: name, dimensions, node ID, **childCount** (used as baseline for clone validation)

### Step 0.3 — Deep Screen Inspection (MANDATORY)

> **This step is the critical difference from naive workflows.** Every screen MUST be deeply inspected before any construction begins. The per-screen childCount recorded here is the validation baseline for Phase 2 clone gates.

For EACH screen on the source page:

1. `figma_node_children(id: screenId)` — full layer tree
2. Catalog for each screen:
   - **Dimensions**: width, height
   - **childCount**: number of direct children (baseline for clone validation)
   - **Fill types**: flag nodes with `type: 'IMAGE'` fills → these MUST be cloned, not rebuilt
   - **Fonts used**: extract `fontName` from all text nodes (family + style)
   - **Component instances**: map to existing library components
   - **Node types**: count of FRAME, GROUP, TEXT, INSTANCE, COMPONENT nodes (GROUP nodes will not support prototype reactions — flag for Phase 3)
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

### Step 0.5 — Component Candidates + Smart Componentization Analysis

1. `figma_find(query: "COMPONENT", scope: draftPageId)` — find existing components
2. Identify recurring patterns across screens (shared headers, buttons, cards, toggles, nav bars)
3. Cross-reference with existing library: `figma_search_components`
4. For each candidate, note which screens contain instances → this drives the per-screen Component Integration step in Phase 2

**Smart Componentization Analysis** (determines TIER decision):

**Optional input**: If a `UX-NARRATIVE.md` exists (produced by the `design-narration` skill before this workflow), load it. The narrative's per-screen state/interaction descriptions directly inform Gate 2 — elements documented with state transitions are confirmed Gate 2 passes without manual inspection. If no UX-NARRATIVE exists, Gate 2 is evaluated by visual inspection of Figma nodes.

For each candidate element, evaluate the 3 gates from `workflow-code-handoff.md`:

```
For each candidate:
  Gate 1 — Recurrence:  count distinct screens containing this element
  Gate 2 — Variants:    identify meaningful state/size/type variations
                         (if UX-NARRATIVE available: check narrative for documented states)
  Gate 3 — Code match:  confirm or plan a corresponding code component

  Result: PASS (all 3 gates) or FAIL (any gate fails)
```

**TIER decision logic**:
- If 0 candidates pass all 3 gates → **TIER 1** (naming + tokens only, skip Phase 1)
- If 1+ candidates pass all 3 gates → **TIER 2** (smart componentization, default)
- If user explicitly requests full componentization → **TIER 3** (heavy)

Log the decision: `{"op":"tier_decision","target":"workflow","detail":{"tier":"TIER_2","passing_candidates":5,"total_candidates":12,"candidates":[{"name":"PrimaryButton","gates":[true,true,true]},...]}}`.

**Output**: Local markdown file with:
- List of screens (name, size, node ID, **childCount**, **image flag**, **fonts used**, **GROUP flag**)
- Image inventory (screens requiring clone approach)
- Font inventory (all unique fonts)
- List of recurring patterns (candidates for componentization)
- **Smart Componentization Scorecard** — per-candidate 3-gate evaluation with pass/fail
- **TIER decision** — TIER 1, 2, or 3 with rationale
- **Component-to-screen mapping** (which passing candidates appear in which screens)
- List of existing library components and usage
- Decision table: clone approach (default for all screens with images) vs build approach (only for screens with no source)

**Quality gate**: Plan (including TIER decision) must be reviewed and approved before proceeding to Phase 1.

---

## Phase 1 — Component Library (TIER 2/3 only)

**TIER gate**: Check `tier_decision` from Step 0.5. If TIER 1 → skip Phase 1 entirely (no component creation); proceed directly to Phase 2 with TIER 1 treatment (naming + tokens only). Log: `{"op":"phase1_skipped","target":"tier_gate","detail":{"tier":"TIER_1","reason":"No components meet Smart Componentization Criteria"}}`.

**Goal**: Create components that screens will reference. Only elements passing all 3 Smart Componentization Criteria (recurrence 3+, behavioral variants, codebase match) are componentized. Typically 5-8 components.

**Critical rule**: Components MUST exist before any screen is built on the Handoff page (Rule #4). For TIER 2/3, components with 0 instances at Phase 5 indicate a workflow issue.

**Delegation**: Dispatch as `Task(general-purpose)` for 3+ components. Subagent loads `figma-console-mastery` skill references (see `convergence-protocol.md` Subagent Prompt Template). See `convergence-protocol.md` Subagent Delegation Model.

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

For variant sets (MANDATORY — all variants must be combined):
  1. Create individual COMPONENT variants (each logged)
  2. figma_component_combine(ids: "id1 id2 id3", name: "ComponentName")
  3. → LOG: {"op":"create_variant_set","target":"<setId>","detail":{"name":"...","variants":["id1","id2","id3"]}}
  NEVER leave variants as individual COMPONENTs — always combine into COMPONENT_SETs
```

**Batch optimization**: If 3+ components need the same fill or stroke, use a single `figma_execute` batch script (see `convergence-protocol.md` Batch Script Templates).

**Checkpoint**: After every 5 components, write session snapshot (Rule #2).

**Verification**: `figma_take_screenshot` of the component section — visual check that all components are present and correctly structured.

---

## Phase 2 — Screen-by-Screen Pipeline (Handoff Page)

**Goal**: Transfer each screen from Draft to Handoff one at a time, ensuring each screen is visually faithful, built with component instances, and follows Figma best practices before proceeding to the next.

**Architecture**: Sequential screen-by-screen pipeline. NEVER batch-process screens.

**Delegation**: For 5+ screens, dispatch one `Task(general-purpose)` subagent per screen. Each subagent runs the full per-screen pipeline (Steps 2.1-2.7 below). The orchestrator waits for each subagent to complete and validates the result before dispatching the next. Subagents load `figma-console-mastery` skill references (see `convergence-protocol.md` Subagent Prompt Template).

**Tools**: figma-use for cloning and modification, figma-console for screenshots, `figma_execute` for batch operations within a screen and component instance creation.

### Convergence Gate (before each screen)

```
1. Read operation-journal.jsonl
2. Check: does journal have screen_complete for this source ID?
   - If YES with status "complete" + passing visual diff → SKIP this screen
   - If YES with status "failed" or "partial" → resume from last completed step
   - If NOT FOUND → proceed with full pipeline
```

### Per-Screen Pipeline (Steps 2.1–2.7)

Process EACH screen through ALL steps before starting the next screen:

#### Step 2.1 — Clone

```
figma_node_clone(ids: draftScreenId) — clone entire screen
→ LOG: {"op":"clone_screen","target":"<clonedId>","detail":{"source":"<draftId>","name":"<screenName>","childCount":<N>}}
figma_node_set_parent(id: clonedId, parent: handoffSectionId) — move to Handoff
```

#### Step 2.2 — childCount Validation Gate (Rule #16)

```
source_children = inventory[screenName].childCount   (from Phase 0)
clone_children  = clone result childCount

IF source is not "spec_only" AND clone_children == 0 AND source_children > 0:
  → LOG: {"op":"clone_failure","target":"<clonedId>","detail":{"source":"<draftId>","expected_children":<source_children>,"actual_children":0}}
  → Delete the empty clone: figma_node_delete(ids: clonedId)
  → Retry clone ONCE
  → IF still 0:
    → LOG: {"op":"clone_failure_permanent","target":"<clonedId>","detail":{"reason":"Empty clone after retry"}}
    → Inform orchestrator/user: "Screen [name] cloned as empty frame (0 children, expected [N]). Cannot proceed."
    → Mark screen status: "failed" in session state
    → STOP — do NOT annotate, wire, or mark as complete
  → IF retry succeeds (childCount > 0): continue to Step 2.3

IF clone_children < source_children * 0.5:
  → LOG WARNING: {"op":"clone_partial","target":"<clonedId>","detail":{"expected":<source_children>,"actual":<clone_children>}}
  → Flag for extra visual scrutiny in Step 2.6 (likely GROUP shallow copy)
```

#### Step 2.3 — Restructure

Apply Figma best practices to the cloned screen:

```
a. Apply auto-layout where missing (VERTICAL/HORIZONTAL based on content flow)
b. Rename layers with semantic names using batch figma_execute script:
   — the batch script includes idempotency checks (skip if already named correctly)
   → LOG: {"op":"batch_rename","target":"batch","detail":{"screen":"<name>","count":N}}
c. Clean up layer hierarchy: flatten unnecessary nesting, remove empty groups
d. Ensure proper constraints and responsive behavior
```

#### Step 2.4 — Component Integration (TIER 2/3 — skip for TIER 1)

**TIER 1 gate**: If `tier_decision` is TIER 1 → skip this step entirely. Screens retain their cloned elements with proper naming and token binding from Steps 2.1-2.3.

For TIER 2/3: this step replaces raw cloned elements with component instances from the Phase 1 library for elements that passed the Smart Componentization Criteria.

```
For each component in the Phase 1 library:
  1. Identify matching elements in the cloned screen:
     — Match by visual similarity (size, position, layer name patterns)
     — Match by inventory data from Phase 0 (component-to-screen mapping)
  2. For each match:
     a. Record the matching element's properties (position, size, any overrides)
     b. Create a component instance:
        figma_instantiate_component(component_key, variant_properties)
        OR via figma_execute:
        const comp = await figma.importComponentByKeyAsync(key);
        const instance = comp.createInstance();
     c. Position the instance to match the original element
     d. Apply property overrides (text content, colors from the original)
     e. Delete or hide the original raw element
     f. → LOG: {"op":"create_instance","target":"<instanceId>","detail":{"component":"<name>","screen":"<screenName>","replaced":"<originalId>"}}

Instance count check (TIER 2/3 only):
  — After processing all components for this screen, count instances created
  — IF instance_count == 0 AND component candidates exist for this screen (per Smart Componentization Scorecard):
    → LOG WARNING: {"op":"no_instances","target":"<screenId>","detail":{"screen":"<name>","tier":"TIER_2","expected_components":["TopBar","Button",...]}}
    → Flag for user review (may indicate matching failure, not necessarily a workflow error)
  — For TIER 1: instance_count is expected to be 0 — no warning needed
```

#### Step 2.5 — Visual Comparison: Screenshot Overlay

Take a screenshot of the cloned screen to visually verify structural integrity:

```
figma_take_screenshot — capture the current handoff screen
Compare visually: does the structure look correct? Are components in the right place?
IF obvious structural issues visible in screenshot:
  → Fix issues (max 3 fix cycles)
  → Re-screenshot after each fix
```

#### Step 2.6 — Visual Fidelity Gate: Diff Against Draft (Rule #14)

```
figma_diff_visual(from: draftScreenId, to: handoffScreenId)
Record diff result in session state

IF visual deviation exceeds threshold:
  → Take side-by-side screenshots: figma_take_screenshot of Draft area + Handoff area
  → Present to user: "Screen [name] visual diff: [score]. Deviations: [summary]"
  → Options:
    (A) Fix — attempt repair (max 3 fix cycles), then re-diff
    (B) Accept — mark as accepted with noted deviations
    (C) Re-clone — delete this screen and re-clone from Draft
    (D) Halt — stop the workflow for manual intervention

IF deviation is within acceptable range (component swaps cause expected differences):
  → Document expected deviations: "Component instances replace raw elements — expected visual delta"
  → Proceed
```

**Expected deviations**: When raw elements are replaced with component instances (Step 2.4), minor visual differences are expected and acceptable. The diff should flag these as "component integration deltas" rather than errors. Structural changes (missing elements, wrong positions, lost images) are NOT acceptable.

#### Step 2.7 — Screen Completion

```
→ LOG: {"op":"screen_complete","target":"<handoffId>","detail":{
    "screen":"<name>",
    "source":"<draftId>",
    "childCount":<N>,
    "instance_count":<I>,
    "diff_score":<S>,
    "status":"complete"
  }}
→ Update session-state.json with this screen's handoff_id, status, diff_score, instance_count
→ Report to user: "Screen [N]/[T] — [name]: complete. [I] instances, diff: [S]."
→ Proceed to next screen
```

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
  4. Apply Component Integration (Step 2.4) as normal
  5. Run Visual Fidelity Gate (Step 2.6) as normal
```

> **HARD CONSTRAINT**: If a screen contains IMAGE fills and cloning fails, STOP and inform the user. There is no way to recreate IMAGE fills programmatically. See `anti-patterns.md` Hard Constraints and `plugin-api.md` Image Handling.

---

## Phase 3 — Prototype Wiring

**Goal**: Connect screens with navigation flows.

**Tools**: figma-console `figma_execute` with `setReactionsAsync` (primary).

> **Note**: `figma_connector_create` likely creates FigJam connectors, not Figma prototype interactions — needs empirical validation before use here. Use figma-console approach until validated.

```javascript
// figma_execute — prototype wiring with GROUP verification (Rule #20)
(async () => {
  try {
    const results = { wired: 0, group_unsupported: 0, failed: 0, details: [] };
    for (const flow of flows) {
      const source = await figma.getNodeByIdAsync(flow.sourceId);
      if (!source) {
        results.failed++;
        results.details.push({ source: flow.sourceId, status: "not_found" });
        continue;
      }

      // Attempt to wire
      await source.setReactionsAsync([{
        trigger: { type: 'ON_CLICK' },
        actions: [{
          type: 'NODE',
          destinationId: flow.targetId,
          navigation: 'NAVIGATE',
          transition: { type: 'DISSOLVE', duration: 0.3 }
        }]
      }]);

      // VERIFY — re-read reactions to check if they stuck (Rule #20)
      const reactions = source.reactions;
      if (!reactions || reactions.length === 0) {
        // GROUP nodes silently drop reactions
        results.group_unsupported++;
        results.details.push({
          source: flow.sourceId,
          name: source.name,
          type: source.type,
          status: "group_unsupported"
        });
      } else {
        results.wired++;
        results.details.push({
          source: flow.sourceId,
          target: flow.targetId,
          status: "confirmed"
        });
      }
    }
    return JSON.stringify(results);
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Operational notes**:
- Use `figma_clear_console` before the batch script (Rule #6)
- Use `actions[]` array format, not singular `action` (see `anti-patterns.md` — Recurring Error #4)
- **Verify every connection** — re-read `node.reactions` after `setReactionsAsync`. GROUP nodes silently drop reactions; the script above detects this
- Journal entry MUST accurately report wired vs group_unsupported vs failed:
  ```jsonl
  {"op":"wire_prototype","target":"batch","detail":{"wired":21,"group_unsupported":13,"failed":0,"total_attempted":34}}
  ```
  NEVER report `failed: 0` when GROUP connections were silently dropped — use `group_unsupported` category
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

**Goal**: Comprehensive validation of ALL screens against Draft originals. Since each screen was already validated in Phase 2, this phase is a holistic cross-screen check.

**Tools**: figma-use for lint/diff, figma-console for audit/screenshots.

### Step 5.1 — Visual Fidelity Re-Validation (ALL screens)

```
For EACH screen:
  1. figma_diff_visual(from: draftScreenId, to: handoffScreenId)
  2. Record result in session state
  3. If visual deviation exceeds threshold:
     a. Take side-by-side screenshots (Draft + Handoff)
     b. Flag for user review
```

### Step 5.2 — Component Instance Audit + Handoff Manifest

**Component audit** (TIER 2/3 only — skip for TIER 1):
```
For EACH screen:
  1. Count INSTANCE nodes via figma_execute:
     const instances = handoffScreen.findAll(n => n.type === "INSTANCE");
  2. Record instance_count in session state
  3. IF any screen has 0 instances AND the Smart Componentization Scorecard lists
     passing candidates for this screen:
     → Flag as incomplete — component integration was skipped or failed
     → Present to user for decision: re-process this screen or accept as-is
```

**Handoff Manifest generation** (all TIERs):
Generate `specs/figma/handoff-manifest.md` using the template from `workflow-code-handoff.md` Step 7. Populate:
- Screen Inventory from session state (all screens with node IDs, dimensions, routes)
- Component-to-Code Mapping from Phase 1 library (TIER 2/3; empty table for TIER 1)
- Token Mapping from Phase 0 token inventory + Step 4 token alignment
- Naming Exceptions from Step 3 exception descriptions
- Health Score from Step 5.3 audit results

### Step 5.3 — Design System Audit

1. figma-console `figma_audit_design_system` — health score (naming, tokens, components, accessibility, consistency, coverage)

### Step 5.4 — Cleanup

1. Clean up orphaned nodes: `figma_node_delete(ids: "orphanId1 orphanId2 ...")`
2. Verify all screens in session state have `status: "complete"` + passing diff results

### Step 5.5 — Summary Report

Present to user (using Progress Reporting template):
- **TIER**: TIER [1|2|3] (Smart Componentization / Naming+Tokens / Heavy)
- Screens transferred: N/N (passed/total)
- Visual fidelity: N screens passed `figma_diff_visual`
- **Component instances**: N total instances across all screens (per-screen breakdown) — expected 0 for TIER 1
- Images preserved: N/N (via cloning)
- Font accuracy: all fonts match Draft
- Prototype connections: N wired, G GROUP-unsupported, F failed
- Health score: N/100
- **Handoff Manifest**: `specs/figma/handoff-manifest.md` (generated)
- **UX-NARRATIVE**: [consumed from path — informed Gate 2 analysis | not available — Gate 2 evaluated by visual inspection; recommend running `design-narration` skill before next handoff]

**Failure condition**: If visual fidelity pass rate is below 80%, offer the user the Rollback Protocol options before declaring completion. For TIER 2/3, also flag if total component instances is 0 when passing candidates existed.

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
| 18 | **No visual fidelity check during construction** | Mandatory `figma_diff_visual` after EVERY screen (Rule #14) |
| 19 | **Regression: redoing already-completed work** | Read `operation-journal.jsonl` before every mutation; skip logged operations (Rule #3) |
| 20 | **State lost after context compaction** | Re-read journal + snapshot; resume from first uncompleted operation (Rule #15) |
| 21 | **Empty clone (childCount=0)** | Validate childCount after every clone; retry once; halt if still 0. NEVER mark complete (Rule #16) |
| 22 | **Partial clone (childCount < 50% of source)** | Flag for extra visual scrutiny; likely GROUP shallow copy. Compare against Phase 0 inventory baseline (Rule #16) |
| 23 | **Component library with 0 instances (TIER 2/3)** | Per-screen component integration applies to TIER 2/3 only (Step 2.4). Audit at Phase 5 (Step 5.2). For TIER 1, 0 instances is expected. For TIER 2/3, 0 instances when passing candidates exist indicates a workflow issue (Rule #17) |
| 24 | **GROUP prototype reactions silently dropped** | Re-read `node.reactions` after `setReactionsAsync`; log as `group_unsupported` not as `wired` (Rule #20) |
| 25 | **Fabricated journal timestamps** | Use `new Date().toISOString()` inside `figma_execute` or orchestrator-injected real time (Rule #18) |
| 26 | **Existing content on target page not acknowledged** | Preflight check at Step 0.1B; present options to user; log decision (Rule #19) |
| 27 | **Batch screen processing hides failures** | Process one screen at a time; validate each before proceeding (Rule #21) |

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
