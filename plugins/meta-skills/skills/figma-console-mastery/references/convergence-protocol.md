# Convergence Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Anti-regression rules, operation journaling, batch scripting, and subagent delegation for Figma design workflows. For the Draft-to-Handoff workflow that uses these patterns, see the `design-handoff` skill (product-definition plugin). For error recovery, see `anti-patterns.md`.

---

## Problem Statement

In long Figma design sessions, context compaction erases the AI's memory of what has already been done. Without a durable, operation-level record, the system **regresses** — renaming already-renamed nodes, recreating already-created components, or restructuring already-restructured screens. This regression is not just wasteful (it doubles token consumption) — it is **destructive** because it can undo deliberate decisions, revert carefully tuned values, and break references between nodes.

**Root causes**:
1. **State file granularity** — session state written at batch boundaries (every 5 components) misses individual operations
2. **No convergence check** — operations are issued without verifying whether the target was already processed
3. **Context-dependent memory** — the AI relies on in-context conversation history, which vanishes on compact
4. **Monotonic assumption** — no mechanism ensures the system converges toward completion rather than oscillating

---

## 1. Operation Journal

The Operation Journal is an **append-only** JSONL file that records every mutating Figma operation as it completes. It is the single source of truth for what has been done, surviving all context compactions.

### File Location

```
specs/figma/journal/
  {screen-name}.jsonl          # Per-screen operation journal
  _session-summary.jsonl       # Cross-screen session events (start, end, mode selection)
```

Per-screen journals replace the previous monolithic `operation-journal.jsonl`. Each screen gets its own JSONL file named after the screen (slugified: lowercase, hyphens for spaces, no special characters).

**Rules**:
- Session-level events (session start, mode selection, session end) go to `_session-summary.jsonl`
- Per-screen operations go to the screen's journal file
- Convergence checks (C1-C9) apply per-screen journal
- Crash recovery reads per-screen journal to determine completed operations
- Subagents receive only the journal for their assigned screen (context reduction)

Create journal directory and screen file at first operation on that screen if they don't exist.

### Cross-Screen Operations Journal

For operations that affect multiple screens simultaneously (batch token binding, global naming rules, cross-screen component extraction), use a dedicated cross-screen journal:

```
specs/figma/journal/_cross-screen.jsonl
```

**When to use**: Any operation that modifies nodes across 2+ screens in a single batch.

**Entry format**:
```json
{"v":1,"ts":"...","op":"cross_screen_batch","target":"screens:ONB-01,ONB-02,ONB-03","detail":{"action":"batch_token_bind","variables_bound":12,"screens_affected":3},"phase":3}
```

**Rules**:
- Cross-screen operations are logged to `_cross-screen.jsonl`, NOT to individual screen journals
- After cross-screen operation completes, append a summary entry to each affected screen's journal: `{"op":"cross_screen_ref","ref":"_cross-screen.jsonl","entry_ts":"..."}`
- Convergence checks for a screen must read BOTH the screen journal AND `_cross-screen.jsonl` entries referencing that screen

### Entry Format

One JSON object per line. Every entry MUST include these fields:

| Field | Required | Description |
|-------|----------|-------------|
| `v` | Yes | Schema version — always `1` (enables future format migration) |
| `ts` | Yes | ISO 8601 timestamp |
| `op` | Yes | Operation type (see table below) |
| `target` | Yes | Node ID or `"batch"` / `"session"` for aggregate entries |
| `detail` | Yes | Operation-specific payload |
| `phase` | Yes | Workflow phase number (0-5) |

```jsonl
{"v":1,"ts":"2026-02-20T14:30:01Z","op":"rename","target":"24:4271","detail":{"from":"Frame 42","to":"StatusBar"},"phase":1}
{"v":1,"ts":"2026-02-20T14:30:02Z","op":"create_component","target":"24:4271","detail":{"name":"StatusBar","parent":"24:4200"},"phase":1}
{"v":1,"ts":"2026-02-20T14:30:05Z","op":"set_layout","target":"24:4271","detail":{"mode":"VERTICAL","padding":"16,16,16,16","gap":"8"},"phase":1}
{"v":1,"ts":"2026-02-20T14:30:10Z","op":"clone_screen","target":"24:4300","detail":{"source":"24:100","name":"ONB-01","handoff_id":"24:4300"},"phase":2}
{"v":1,"ts":"2026-02-20T14:30:15Z","op":"batch_rename","target":"batch","detail":{"count":12,"nodes":["24:4301","24:4302"]},"phase":2}
{"v":1,"ts":"2026-02-20T14:30:20Z","op":"phase_complete","target":"phase_1","detail":{"components_created":6,"total_ops":24},"phase":1}
```

### Operation Types

| `op` value | When to log | Key `detail` fields |
|-----------|-------------|-------------------|
| `rename` | After renaming any node | `from`, `to` |
| `create_component` | After creating a component | `name`, `parent` |
| `create_instance` | After instantiating a component in a screen | `component_name`, `screen`, `replaced` (original node ID) |
| `clone_screen` | After cloning a screen | `source`, `name`, `handoff_id`, `childCount` |
| `clone_failure` | After clone produces 0 children | `source`, `expected_children`, `actual_children` |
| `clone_partial` | After clone produces <50% expected children | `source`, `expected`, `actual` |
| `screen_complete` | After full per-screen pipeline finishes | `screen`, `source`, `childCount`, `instance_count`, `diff_score`, `status` |
| `set_layout` | After setting auto-layout | `mode`, `padding`, `gap` |
| `set_fill` | After changing fill | `color` or `variable` |
| `set_props` | After setting instance properties | `props` (key-value map) |
| `replace_instance` | After swapping component instances | `old_component`, `new_component` |
| `delete_node` | After deleting a node | `name`, `reason` |
| `wire_prototype` | After setting prototype reactions | `wired`, `group_unsupported`, `failed`, `total_attempted` |
| `annotate` | After adding annotation text | `screen_name`, `content_summary` |
| `batch_rename` | After batch rename script | `count`, `nodes` (sample) |
| `batch_move` | After batch move script | `count` |
| `batch_set_fill` | After batch fill script | `count`, `color` |
| `no_instances` | When screen has 0 component instances but should have some | `screen`, `expected_components` |
| `preflight_content_decision` | After user decides about existing target page content | `choice` (A/B/C), `existing_nodes` |
| `phase_complete` | At phase boundary | phase-specific summary |
| `validation_pass` | After diff/lint passes | `screen_name`, `score` |
| `validation_fail` | After diff/lint fails | `screen_name`, `score`, `issues` |
| `quality_audit` | After quality audit completes | `composite_score`, `scores` (per-dimension), `verdict`, `issues`, `improvements_applied` |

### Journal Rules

1. **Write immediately** — log AFTER the operation succeeds, BEFORE moving to the next operation
2. **Append only** — never modify or delete existing entries
3. **One truth** — if journal says a node was renamed, it WAS renamed regardless of what the AI "remembers"
4. **Journal is authoritative** — when journal and session snapshot disagree, the journal wins (written more frequently, append-only)
5. **Read before doing** — ALWAYS read relevant journal entries before performing any mutating operation (see Convergence Check below)
6. **Survive compact** — the journal is on disk, immune to context compaction
7. **Human-readable** — JSONL format allows `grep` and `tail` inspection by the user
8. **Log rollbacks** — after any rollback, append `{"op":"rollback","target":"session","detail":{"deleted_ids":["id1","id2"],"reason":"..."}}` so convergence checks know those operations were undone
9. **Real timestamps only** — the `ts` field MUST contain a real wall-clock timestamp, never a hardcoded placeholder. Inside `figma_execute` scripts, use `new Date().toISOString()`. For subagents, the orchestrator injects current time in the prompt: `"Current time: 2026-02-20T15:42:33Z"` and the subagent uses it as reference. Fabricated timestamps (e.g., incrementing by 1 hour per batch) destroy the audit trail's value for performance analysis and debugging

### Journal Lifecycle (Between Sessions)

The journal is scoped to a **single workflow** on a single Figma file. Between-session management:

| Event | Action |
|-------|--------|
| Starting a new workflow on the same file | Archive the existing journal: rename to `operation-journal-YYYY-MM-DD.jsonl`, create a fresh `operation-journal.jsonl` |
| Resuming an interrupted workflow | Keep the existing journal as-is; the resume procedure reads it to determine where to continue |
| Workflow fully completed (Phase 5 done) | Archive: rename to `operation-journal-completed-YYYY-MM-DD.jsonl` for audit trail; optionally delete if no longer needed |
| Journal exceeds 500 entries | Still functional but convergence checks will consume more tokens. Consider: (1) using `grep` instead of full reads for convergence checks, (2) for subagents, pass only the relevant phase entries instead of the full journal |

**Max expected size**: A 30-screen workflow typically produces 150-300 journal entries (~30-60KB). A 50+ screen workflow could reach 500+ entries (~100KB). JSONL scales linearly for `grep` lookups, so performance degrades gracefully.

**Never delete an active journal** — if in doubt whether a workflow is complete, keep the journal. An unnecessary journal is harmless; a prematurely deleted journal causes regression.

### Journal Compaction

For complex screens with heavy rework, journals can grow large. Compaction prevents context bloat when loading into subagents.

**Trigger**: When a per-screen journal exceeds 100 entries or ~4K tokens, compact before the next subagent load.

**Compaction procedure**:
1. Read the full journal
2. Identify completed operation sequences (create -> modify -> modify -> final state)
3. Collapse sequences into a summary entry: `{ "op": "compacted", "original_count": N, "summary": "Created frame X, applied auto-layout, renamed to Y", "final_state": {...}, "timestamp": "..." }`
4. Preserve: all `quality_audit` entries (score history), all `error` entries (learning), last entry per unique node ID (crash recovery)
5. Write compacted journal to `{screen-name}.jsonl` (replace in-place)
6. Archive original to `{screen-name}.pre-compact.jsonl` (safety net)

**What survives compaction**: latest state of every modified node, all audit results, all errors, session boundary markers.
**What gets collapsed**: intermediate modification steps for same node, redundant convergence checks, superseded retry sequences.

### Session Summary Compaction

For long-running projects with many rework sessions, `_session-summary.jsonl` can grow large.

**Trigger**: When `_session-summary.jsonl` exceeds 50 entries.

**Compaction procedure**:
1. Read all entries
2. Keep: latest `session_start` entry, all `mode_selection` entries (needed for history), latest `session_end` per session
3. Collapse intermediate entries (screen dispatches, status checks) into a per-session summary: `{"op":"session_compacted","original_count":N,"sessions_preserved":M,"timestamp":"..."}`
4. Write compacted file in-place
5. Archive original to `_session-summary.pre-compact.jsonl`

**What survives**: Session boundaries, mode selections, final outcomes
**What gets collapsed**: Intermediate dispatch entries, status checks, redundant session metadata

---

## 2. Convergence Check (Anti-Regression)

The Convergence Check is the mandatory pre-operation verification that prevents regression. Before ANY mutating Figma operation, the AI MUST check the journal to determine if the operation (or an equivalent) has already been completed.

### Check Procedure

```
BEFORE mutating operation:
  1. Read per-screen journal for target screen (or grep for target node ID)
  2. Check: has this exact operation already been logged?
     - rename(nodeId, newName) → grep for {"op":"rename","target":"<nodeId>"}
     - create_component(name) → grep for {"op":"create_component",...,"name":"<name>"}
     - clone_screen(sourceId) → grep for {"op":"clone_screen",...,"source":"<sourceId>"}
  3. If FOUND → SKIP the operation, log a note: "Convergence: skipped <op> on <target> — already done at <ts>"
  4. If NOT FOUND → proceed with the operation, then log it
```

### Convergence Rules

| # | Rule | Rationale |
|---|------|-----------|
| C1 | **Read journal at session start** — load the full journal and build an in-memory set of completed operations | Establishes baseline after compact |
| C2 | **Read journal after any compact** — if context is compacted mid-session, re-read the journal to rebuild the completed-operations set | Prevents post-compact regression |
| C3 | **Check before every mutating operation** — no exception; even "obviously needed" operations might have been done pre-compact | The 50ms cost of a check is negligible vs the cost of regression |
| C4 | **Node ID is the primary key** — convergence checks match on node ID + operation type, not node name (names can be ambiguous) | Prevents false negatives from renamed nodes |
| C5 | **Phase boundaries are logged** — `phase_complete` entries allow skipping entire phases on resume | Prevents re-executing completed phases |
| C6 | **Treat journal as append-only truth** — if the journal says X was done, do not redo X even if it appears to need redoing | Breaks the regression loop |
| C7 | **When in doubt, verify via Figma** — if a journal entry seems stale or wrong, use `figma_execute` to read node properties (`getNodeByIdAsync`, `findOne`, `children.map(c => ({id,name,type}))`) to check the actual Figma state, then decide whether to proceed or add a correction entry | Safety valve for journal integrity |
| C8 | **Consult Session Index before MCP discovery calls** — when resolving a screen/frame by name, `Grep` the Session Index (`specs/figma/session-index.jsonl`) before calling `figma_get_file_for_plugin` or `figma_execute` discovery scripts. See `session-index-protocol.md` | Eliminates redundant MCP roundtrips; lookup cost is ~0 (local Grep) vs ~2-5s (MCP call) |
| C9 | **Validate Session Index at phase boundaries** — before trusting index after a phase transition, compact recovery, or >5-min gap, check freshness via `figma_get_design_changes(since=last_validated)`. Rebuild if changes affect depth-1 nodes | Prevents stale ID references from external Figma edits or mutations by other subagents |

### Quick Convergence Patterns

**Pattern: Resume after compact**
```
1. Read operation-journal.jsonl → build completed set
2. Read session-state.json → identify current phase + last checkpoint
3. Determine remaining operations for current phase
4. Continue from first uncompleted operation
```

**Pattern: Re-entering a screen already partially processed**
```
1. Grep journal for screen node ID → list all operations on this screen
2. Check which sub-operations are done (rename, set_layout, replace_instances, etc.)
3. Execute only missing sub-operations
4. Log each as completed
```

**Pattern: Batch operation with partial completion**
```
1. Grep journal for batch operation on target set
2. If batch_rename logged with count=12 and 12 renames are needed → skip
3. If batch_rename logged with count=8 and 12 are needed → rename only the 4 missing nodes
4. Log the completion of remaining operations
```

---

## 3. Batch Scripting Protocol

When 3+ nodes need the same operation type (rename, move, set fill, set layout), use a **single `figma_execute` call** with a batch script instead of N individual `figma_execute` calls. This reduces token consumption by 70-90% for homogeneous operations.

### When to Batch

| Condition | Action |
|-----------|--------|
| 3+ nodes, same operation type, independent | **BATCH** via single `figma_execute` script |
| 1-2 nodes, any operation | **INDIVIDUAL** `figma_execute` call |
| Operations depend on each other's results | **SEQUENTIAL** `figma_execute` calls |
| Debugging a failure | **INDIVIDUAL** `figma_execute` (easier to isolate) |
| Using native figma-console tools (search, instantiate, variables) | **NATIVE** tool call |

### Batch Script Templates

#### Batch Rename (most common regression target)

```javascript
// figma_execute — batch rename
(async () => {
  try {
    const renames = [
      { id: "24:4301", name: "Header/TopBar" },
      { id: "24:4302", name: "Content/WorkoutCard" },
      { id: "24:4303", name: "Footer/NavBar" },
      // ... up to 50 per batch
    ];
    const results = [];
    for (const r of renames) {
      const node = await figma.getNodeByIdAsync(r.id);
      if (!node) { results.push({ id: r.id, status: "not_found" }); continue; }
      if (node.name === r.name) { results.push({ id: r.id, status: "already_done" }); continue; }
      const oldName = node.name;
      node.name = r.name;
      results.push({ id: r.id, status: "renamed", from: oldName, to: r.name });
    }
    return JSON.stringify({ success: true, results });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

**Key feature**: The `already_done` check inside the script prevents regression even without journal checks — the script is idempotent.

#### Batch Move/Reparent

```javascript
// figma_execute — batch reparent to target container
(async () => {
  try {
    const moves = [
      { id: "24:4301", parentId: "24:5000", index: 0 },
      { id: "24:4302", parentId: "24:5000", index: 1 },
    ];
    const results = [];
    for (const m of moves) {
      const node = await figma.getNodeByIdAsync(m.id);
      const parent = await figma.getNodeByIdAsync(m.parentId);
      if (!node || !parent) { results.push({ id: m.id, status: "not_found" }); continue; }
      if (node.parent?.id === m.parentId) { results.push({ id: m.id, status: "already_done" }); continue; }
      parent.insertChild(m.index, node);
      results.push({ id: m.id, status: "moved", to: m.parentId });
    }
    return JSON.stringify({ success: true, results });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

#### Batch Set Fill

```javascript
// figma_execute — batch fill color
(async () => {
  try {
    const targets = ["24:4301", "24:4302", "24:4303"];
    const fill = { type: "SOLID", color: { r: 0.122, g: 0.122, b: 0.122 }, opacity: 1 };
    const results = [];
    for (const id of targets) {
      const node = await figma.getNodeByIdAsync(id);
      if (!node) { results.push({ id, status: "not_found" }); continue; }
      node.fills = [fill];
      results.push({ id, status: "filled" });
    }
    return JSON.stringify({ success: true, count: results.length, results });
  } catch (e) {
    return JSON.stringify({ error: e.message });
  }
})()
```

### Batch Rules

| # | Rule | Rationale |
|---|------|-----------|
| B1 | **Max 50 operations per batch** | Prevents script timeouts and overly large console output |
| B2 | **Idempotent by default** — every batch script checks current state before mutating | Prevents regression when re-run after compact |
| B3 | **Return structured results** — JSON with per-node status (success/already_done/not_found/error) | Enables accurate journal logging |
| B4 | **Log one journal entry per batch** — use `batch_rename`, `batch_move`, etc. with count and sample node IDs | Keeps journal concise for bulk operations |
| B5 | **Clear console before batch** — `figma_clear_console` before `figma_execute` | Prevents buffer rotation data loss |
| B6 | **Verify after batch** — `figma_capture_screenshot` or targeted `figma_execute` read after each batch to confirm | Catches silent partial failures |

### Token Savings Comparison

| Operation | Individual (N calls) | Batched (1 call) | Savings |
|-----------|---------------------|-------------------|---------|
| Rename 20 nodes | ~2,000 tokens (20 individual calls) | ~600 tokens (1 figma_execute) | **70%** |
| Move 15 nodes | ~1,500 tokens (15 individual calls) | ~500 tokens (1 figma_execute) | **67%** |
| Set fill on 10 nodes | ~1,000 tokens (10 individual calls) | ~350 tokens (1 figma_execute) | **65%** |
| Mixed: 20 renames + 15 moves + 10 fills | ~4,500 tokens (45 calls) | ~1,450 tokens (3 batches) | **68%** |

> **Trade-off**: Batch scripts are harder to debug when they fail. If a batch returns errors, switch to individual `figma_execute` calls for the failing nodes to isolate the issue. The batch + individual fallback combination is still far cheaper than all-individual.

---

## 4. Subagent Delegation Model

For large workflows (10+ screens, 5+ components), split work across focused subagents. Each subagent operates on a narrow scope with the journal and state files as its input/output bus.

### Why Subagents Help

| Problem | How subagents mitigate |
|---------|----------------------|
| Context compaction mid-phase | Each subagent has a fresh context window; no accumulated history to compact |
| Regression across phases | Each subagent reads the journal at start; no stale memory to regress from |
| Monolithic session bloat | Phase 0 inventory tokens don't pollute Phase 2 screen-building context |
| Single point of failure | A failed subagent loses only its phase; journal preserves all prior work |

### Delegation Architecture

```
Orchestrator (SKILL.md / main session)
├── reads: session-state.json (phase, progress)
├── reads: operation-journal.jsonl (convergence)
│
├── Phase 0: INLINE (lightweight — inventory only)
│   └── writes: session-state.json, operation-journal.jsonl
│
├── Phase 1: Task(general-purpose) → "Component Builder"
│   ├── loads: figma-console-mastery skill references
│   ├── reads: session-state.json, operation-journal.jsonl
│   ├── reads: design-handoff skill stage reference files (product-definition plugin)
│   ├── creates components, logs to journal
│   └── writes: session-state.json (phase 1 complete)
│
├── Phase 2: SEQUENTIAL per screen → "Screen Pipeline Agent" (one at a time)
│   │
│   ├── Screen 1: Task(general-purpose) → "Screen Pipeline: ONB-01"
│   │   ├── loads: figma-console-mastery skill references
│   │   ├── reads: session-state.json, operation-journal.jsonl
│   │   ├── executes Steps 2.1–2.7 (clone → validate → restructure → components → diff)
│   │   └── writes: journal entries + session-state (screen complete)
│   │
│   ├── Orchestrator: validates screen result, then dispatches next
│   │
│   ├── Screen 2: Task(general-purpose) → "Screen Pipeline: ONB-02"
│   │   └── ... same pipeline ...
│   │
│   └── ... one subagent per screen, strictly sequential ...
│
├── Phase 3: Task(general-purpose) → "Prototype Wiring Agent"
│   ├── loads: figma-console-mastery skill references
│   ├── reads: session-state.json (all screen IDs)
│   └── wires prototype connections with GROUP verification
│
├── Phase 4: Task(general-purpose) → "Annotation Agent"
│   ├── loads: figma-console-mastery skill references
│   ├── reads: session-state.json, supplementary text docs
│   └── adds annotations to all screens
│
└── Phase 5: Task(general-purpose) → "Validation Agent"
    ├── loads: figma-console-mastery skill references
    ├── reads: session-state.json, operation-journal.jsonl
    ├── runs diff, lint, instance audit
    └── writes: final validation report
```

**Phase 2 is strictly sequential**: the orchestrator dispatches one screen subagent, waits for it to complete, validates the result (childCount, instance_count, diff_score), then dispatches the next. This catches failures immediately — a WK-01 empty-clone failure halts after 1 screen, not after 4-6.

### Subagent Prompt Template

Every subagent receives a standardized prompt structure. The **skill loading block** is MANDATORY — it ensures subagents inherit the full figma-console-mastery knowledge (clone-first rules, journal protocol, visual fidelity gates, anti-patterns, tool selection).

```
## Context
- Project: {project_name}
- Figma file: {file_name}
- Current phase: {phase_number} — {phase_name}
- Current time: {ISO_8601_timestamp}  ← orchestrator injects real wall-clock time
- State file: specs/figma/session-state.json
- Journal: specs/figma/journal/{screen_name}.jsonl
- Session Index: specs/figma/session-index.jsonl (Grep for name→ID lookups; see session-index-protocol.md)

## Skill Loading (MANDATORY — NON-NEGOTIABLE)
Every subagent MUST load the figma-console-mastery skill references BEFORE starting any work.
Without these references, subagents miss critical rules (GROUP→FRAME conversion, constraint formulas,
COMPONENT_SET instantiation, clone-first architecture, journal protocol, visual fidelity gates)
and reproduce the exact failures documented in v1/v2 retrospectives.

Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md
  (Journal protocol, convergence checks, batch scripting)

Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/recipes-foundation.md
  (Required for ANY figma_execute code — IIFE wrapper, font preloading, constraint formulas, proportional resize)

Read: $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/anti-patterns.md
  (Error catalog, debugging, hard constraints, handoff-specific anti-patterns)

{Additional references by phase:}
  Phase 1 (components): + recipes-components.md (GROUP→FRAME, Componentize from Clone, COMPONENT_SET instantiation), design-rules.md
  Phase 2 (screens):    + recipes-components.md (GROUP→FRAME recipe — CRITICAL for Step 2.4), tool-playbook.md
  Phase 3 (wiring):     + (none additional)
  Phase 4 (annotations): + (none additional)
  Phase 5 (validation):  + anti-patterns.md (screenshot validation: use figma_capture_screenshot for live state)

## Mandatory Rules
1. Read the journal FIRST — build a set of completed operations
2. SKIP any operation already in the journal
3. Log EVERY mutating operation to the journal immediately after completion
4. Use REAL timestamps: new Date().toISOString() in figma_execute, or reference the Current time above
5. Use batch scripts for 3+ homogeneous operations WITHIN a single screen
6. Write updated session-state.json after completing each screen (Phase 2) or at phase completion
7. Validate childCount after every clone — 0 children on a non-empty source is a clone failure
8. Replace recurring elements with component instances — 0 instances = incomplete screen
9. Run `figma_capture_screenshot` on each screen after Phase 2 processing and compare visually against source — not just at the end
10. If blocked, write status: "needs-user-input" in session-state.json and STOP
11. Convert ALL GROUP nodes to FRAMEs BEFORE setting constraints — GROUPs silently ignore constraints
12. Use createInstance() on COMPONENT (variant child), NEVER on COMPONENT_SET
13. Analyze screen BEFORE cloning — for MODERATE/COMPLEX, write analysis with needs-user-input and STOP
14. Apply cornerRadius + clipsContent as FIRST post-clone step
15. NEVER interact with users directly — write needs-user-input to session state; orchestrator mediates

## Scope
{phase-specific scope: which screens, which components, which operations}

## Compound Learnings (from prior sessions)  ← OPTIONAL, injected by orchestrator
{Relevant entries if any. When present, apply these empirical findings proactively.
If absent, proceed normally — all workflows function identically without learnings.}
```

### Phase 2 Screen-Specific Prompt Extension

For Phase 2 per-screen subagents, append to the base template:

```
## Screen Assignment
- Screen name: {screen_name}
- Draft source ID: {draft_id}
- Draft childCount: {expected_child_count}  ← from Phase 0 inventory
- Target section ID: {handoff_section_id}
- Component library: {component_names_and_ids}  ← from Phase 1 results
- Component-to-screen mapping: {which_components_apply_to_this_screen}

## Pipeline Steps (execute in order — Steps 2.0-2.9)
0. Analyze draft screen structure (count GROUPs, determine viewport/scrollable, assess complexity)
0B. IF MODERATE/COMPLEX: write analysis to session state with status: needs-user-input, STOP
    (orchestrator will mediate user questions and resume with decisions)
1. Clone draft screen → validate childCount (HALT if 0)
2. Move clone to handoff section
3. Frame setup: cornerRadius=32, clipsContent=true
4. GROUP→FRAME conversion — convert ALL GROUP children to FRAMEs (CRITICAL)
5. Constraint assignment — per-type formulas (viewport) or all MIN (scrollable)
6. Component integration — replace raw elements with instances (TIER 2/3 only)
   Use COMPONENT variant child for createInstance(), NOT COMPONENT_SET
7. Visual validation: screenshot handoff + screenshot draft for comparison
8. IF non-trivial: write comparison to session state with status: needs-user-input, STOP
   (orchestrator mediates user approval)
9. Log screen_complete to journal + update session state
```

### Delegation Rules

| # | Rule | Rationale |
|---|------|-----------|
| D1 | **Phase 0 always inline** | Lightweight inventory doesn't justify dispatch overhead |
| D2 | **Phase 2: one subagent per screen, strictly sequential** | Each screen goes through the full pipeline (clone → validate → restructure → components → diff) before the next starts. The orchestrator validates each result before dispatching the next screen. This catches failures immediately — an empty-clone halts after 1 screen, not 4-6 |
| D3 | **Journal is the coordination bus** | Subagents don't need to communicate directly; they read/write the same journal |
| D4 | **Orchestrator validates between screen dispatches** | After each Phase 2 subagent completes, the orchestrator checks: childCount > 0, instance_count > 0 (when applicable), diff_score within threshold. Only then dispatch next screen |
| D5 | **Failed subagent = retry once, then escalate to user** | Orchestrator reads journal to determine what was completed, dispatches a new agent for remaining work. If retry also fails, present failure details to user |
| D6 | **Screens are independent but sequential** | Screen A's completion doesn't affect Screen B's content, but the orchestrator processes them in order for predictable progress tracking |
| D7 | **Subagents NEVER interact with users** | If user input is needed, subagent writes `needs-user-input` to session state and stops; orchestrator mediates |
| D8 | **Sequential journal writes** | Phase 2 subagents run one at a time, so journal interleaving is impossible. For Phases 3-5 (single subagent each), this is also automatic |
| D9 | **Subagents MUST load figma-console-mastery skill references** | Every subagent must read the Skill Loading block from the prompt template. Without it, subagents miss critical rules (GROUP→FRAME conversion, constraint formulas, COMPONENT_SET instantiation, clone-first architecture, journal protocol, visual fidelity gates, user consultation gates, handoff checklist) and produce the same failures documented in v1/v2/v3 retrospectives |

### When to Use Subagent Delegation

| Workflow Size | Strategy |
|---------------|----------|
| 1-4 screens, 0-3 components | **Inline** — run everything in main session with journal; per-screen pipeline still applies |
| 5-15 screens, 3-6 components | **Per-screen delegation** — subagent per phase; Phase 2 dispatches one subagent per screen sequentially |
| 16+ screens, 6+ components | **Per-screen delegation** — same as above; more screens = more subagents but still sequential in Phase 2. Consider splitting Phase 1 components across multiple subagents if >10 components |

For small workflows (1-4 screens), the overhead of dispatching subagents exceeds the benefit. Use the journal and batch scripting patterns inline. The per-screen pipeline (clone → validate → restructure → components → diff → next) applies regardless of whether subagents are used.

---

## 5. Session Snapshot (Quick Resume)

In addition to the journal (per-operation), maintain a **session snapshot** file for quick phase-level resume without parsing the entire journal.

### File Location

```
specs/figma/session-state.json
```

### Snapshot Schema

```json
{
  "version": 4,
  "phase": 2,
  "timestamp": "2026-02-20T15:00:00Z",
  "file_name": "My Design File",
  "source_page": { "name": "Draft", "id": "24:2" },
  "target_page": { "name": "Handoff", "id": "24:500" },
  "preflight_decision": "A",
  "journal_dir": "specs/figma/journal/",
  "journal_entries": 47,
  "screens": {
    "ONB-01": { "draft_id": "24:100", "handoff_id": "24:4300", "status": "complete", "childCount": 12, "instance_count": 3, "diff_score": 98 },
    "ONB-02": { "draft_id": "24:200", "handoff_id": "24:4400", "status": "complete", "childCount": 8, "instance_count": 2, "diff_score": 95 },
    "ONB-03": { "draft_id": "24:300", "handoff_id": null, "status": "pending", "childCount": null, "instance_count": null, "diff_score": null }
  },
  "components": {
    "StatusBar": { "id": "24:4271", "status": "complete" },
    "TopBar": { "id": "24:4274", "status": "complete" }
  },
  "connections": { "wired": 0, "group_unsupported": 0, "failed": 0 },
  "notes": "Phase 2 — transferred 2/3 screens, resuming ONB-03"
}
```

**Schema version 4 changes** (from v3):
- `journal_dir` — path to per-screen journal directory

**Schema version 3 changes** (from v2):
- `screens[].childCount` — clone validation baseline (compared against Phase 0 inventory)
- `screens[].instance_count` — component instances placed in this screen (0 = incomplete)
- `connections` — broken down into `wired`, `group_unsupported`, `failed` (not just a flat count)
- `preflight_decision` — user's choice for existing target page content (A/B/C)

**Migration from v3**: If `session-state.json` has `"version": 3`, add `journal_dir` field with value `"specs/figma/journal/"`, then set `"version": 4`. Existing screen status and IDs are preserved.

**Migration from v2**: If `session-state.json` has `"version": 2`, add missing fields with `null` defaults (`childCount`, `instance_count` per screen; `preflight_decision`; `connections` object with `wired/group_unsupported/failed`; `journal_dir`), then set `"version": 4`. Existing screen status and IDs are preserved.

### Snapshot Update Cadence

| Event | Action |
|-------|--------|
| Session start | Read existing snapshot or create new |
| Phase boundary | Write full snapshot |
| **After every screen in Phase 2** | Write snapshot (each screen is a completion unit) |
| Every 5 components in Phase 1 | Write snapshot |
| Before and after batch script | Write snapshot |
| Subagent completion | Orchestrator writes snapshot |

### Resume Procedure

```
1. Read session-state.json → determine current phase
1.5. Validate Session Index → if specs/figma/session-index-meta.json exists,
     check freshness via figma_get_design_changes(since=last_validated).
     Rebuild if stale or missing. See session-index-protocol.md.
2. Read operation-journal.jsonl → build completed-ops set
3. Cross-validate: snapshot says phase 2 with 2/3 screens done
   Journal confirms: clone_screen for ONB-01, ONB-02 logged
4. Resume Phase 2 from ONB-03
```

---

## 6. Compact Recovery Protocol

When context compaction occurs mid-session, follow this exact sequence to re-establish working state:

### Step 1 — Re-read persistent files
```
Read: specs/figma/session-state.json    → phase, screen/component status
Read: specs/figma/operation-journal.jsonl → completed operations
```

### Step 2 — Rebuild context
- Build in-memory set of completed operations from journal
- Identify current phase and remaining work from snapshot

### Step 3 — Verify Figma state
- `figma_get_status` → confirm connection
- `figma_execute`: `figma.currentPage.children.map(c => ({id:c.id,name:c.name}))` → confirm nodes match journal

### Step 4 — Resume from first uncompleted operation
- DO NOT restart the phase from the beginning
- DO NOT re-execute any operation logged in the journal
- Continue from the exact point where work stopped

### Step 5 — Log recovery
```jsonl
{"v":1,"ts":"...","op":"compact_recovery","target":"session","detail":{"phase":2,"journal_entries":47,"resumed_from":"ONB-03"},"phase":2}
```

---

## Cross-References

- **Draft-to-Handoff workflow** (uses this protocol): `design-handoff` skill (product-definition plugin)
- **Quality Model** (unified quality dimensions, audit scripts, fix cycle protocol): `quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`
- **Anti-patterns** (regression patterns to avoid): `anti-patterns.md`
- **Foundation patterns** (IIFE wrapper, outer-return requirement, font preloading for `figma_execute` code): `recipes-foundation.md`
