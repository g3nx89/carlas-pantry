# Convergence Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0, figma-use v0.11.3+ (February 2026)
>
> **Scope**: Anti-regression rules, operation journaling, batch scripting, and subagent delegation for Figma design workflows. For the Draft-to-Handoff workflow that uses these patterns, see `workflow-draft-to-handoff.md`. For error recovery, see `anti-patterns.md`.

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
specs/figma/operation-journal.jsonl
```

Create the file at session start if it does not exist. Never delete or truncate it during a session.

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
| `create_instance` | After instantiating a component | `component_name`, `parent` |
| `clone_screen` | After cloning a screen | `source`, `name`, `handoff_id` |
| `set_layout` | After setting auto-layout | `mode`, `padding`, `gap` |
| `set_fill` | After changing fill | `color` or `variable` |
| `set_props` | After setting instance properties | `props` (key-value map) |
| `replace_instance` | After swapping component instances | `old_component`, `new_component` |
| `delete_node` | After deleting a node | `name`, `reason` |
| `wire_prototype` | After setting prototype reactions | `source_name`, `target_name` |
| `annotate` | After adding annotation text | `screen_name`, `content_summary` |
| `batch_rename` | After batch rename script | `count`, `nodes` (sample) |
| `batch_move` | After batch move script | `count` |
| `batch_set_fill` | After batch fill script | `count`, `color` |
| `phase_complete` | At phase boundary | phase-specific summary |
| `validation_pass` | After diff/lint passes | `screen_name`, `score` |
| `validation_fail` | After diff/lint fails | `screen_name`, `score`, `issues` |

### Journal Rules

1. **Write immediately** — log AFTER the operation succeeds, BEFORE moving to the next operation
2. **Append only** — never modify or delete existing entries
3. **One truth** — if journal says a node was renamed, it WAS renamed regardless of what the AI "remembers"
4. **Journal is authoritative** — when journal and session snapshot disagree, the journal wins (written more frequently, append-only)
5. **Read before doing** — ALWAYS read relevant journal entries before performing any mutating operation (see Convergence Check below)
6. **Survive compact** — the journal is on disk, immune to context compaction
7. **Human-readable** — JSONL format allows `grep` and `tail` inspection by the user
8. **Log rollbacks** — after any rollback, append `{"op":"rollback","target":"session","detail":{"deleted_ids":["id1","id2"],"reason":"..."}}` so convergence checks know those operations were undone

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

---

## 2. Convergence Check (Anti-Regression)

The Convergence Check is the mandatory pre-operation verification that prevents regression. Before ANY mutating Figma operation, the AI MUST check the journal to determine if the operation (or an equivalent) has already been completed.

### Check Procedure

```
BEFORE mutating operation:
  1. Read operation-journal.jsonl (or grep for target node ID)
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
| C6 | **Treat journal as append-only truth** — if the journal says X was done, do not redo X even if you "think" it needs redoing | Breaks the regression loop |
| C7 | **When in doubt, verify via Figma** — if a journal entry seems stale or wrong, use `figma_node_get` or `figma_node_children` to check the actual Figma state, then decide whether to proceed or add a correction entry | Safety valve for journal integrity |

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
2. If batch_rename logged with count=12 and you need 12 renames → skip
3. If batch_rename logged with count=8 and you need 12 → rename only the 4 missing nodes
4. Log the completion of remaining operations
```

---

## 3. Batch Scripting Protocol

When 3+ nodes need the same operation type (rename, move, set fill, set layout), use a **single `figma_execute` call** with a batch script instead of N individual figma-use calls. This reduces token consumption by 70-90% for homogeneous operations.

### When to Batch

| Condition | Action |
|-----------|--------|
| 3+ nodes, same operation type, independent | **BATCH** via `figma_execute` |
| 1-2 nodes, any operation | **INDIVIDUAL** via figma-use |
| Operations depend on each other's results | **SEQUENTIAL** via figma-use |
| Debugging a failure | **INDIVIDUAL** via figma-use (easier to isolate) |
| Operation needs figma-use-only features (diff, lint, analyze) | **INDIVIDUAL** via figma-use |

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
| B6 | **Verify after batch** — screenshot or `figma_node_children` after each batch to confirm | Catches silent partial failures |

### Token Savings Comparison

| Operation | Individual (N calls) | Batched (1 call) | Savings |
|-----------|---------------------|-------------------|---------|
| Rename 20 nodes | ~2,000 tokens (20 figma-use calls) | ~600 tokens (1 figma_execute) | **70%** |
| Move 15 nodes | ~1,500 tokens (15 figma-use calls) | ~500 tokens (1 figma_execute) | **67%** |
| Set fill on 10 nodes | ~1,000 tokens (10 figma-use calls) | ~350 tokens (1 figma_execute) | **65%** |
| Mixed: 20 renames + 15 moves + 10 fills | ~4,500 tokens (45 calls) | ~1,450 tokens (3 batches) | **68%** |

> **Trade-off**: Batch scripts are harder to debug when they fail. If a batch returns errors, switch to individual figma-use calls for the failing nodes to isolate the issue. The batch + individual fallback combination is still far cheaper than all-individual.

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
│   ├── reads: session-state.json, operation-journal.jsonl
│   ├── reads: workflow-draft-to-handoff.md (Phase 1 section)
│   ├── creates components, logs to journal
│   └── writes: session-state.json (phase 1 complete)
│
├── Phase 2: Task(general-purpose) × N batches → "Screen Transfer Agent"
│   ├── reads: session-state.json, operation-journal.jsonl
│   ├── reads: workflow-draft-to-handoff.md (Phase 2 section)
│   ├── clones/restructures batch of 4-6 screens
│   ├── runs visual fidelity gate per batch
│   └── writes: journal entries + session-state updates
│
├── Phase 3: Task(general-purpose) → "Prototype Wiring Agent"
│   ├── reads: session-state.json (all screen IDs)
│   └── wires prototype connections in batch scripts
│
├── Phase 4: Task(general-purpose) → "Annotation Agent"
│   ├── reads: session-state.json, supplementary text docs
│   └── adds annotations to all screens
│
└── Phase 5: Task(general-purpose) → "Validation Agent"
    ├── reads: session-state.json, operation-journal.jsonl
    ├── runs diff, lint, audit
    └── writes: final validation report
```

### Subagent Prompt Template

Each subagent receives a standardized prompt structure:

```
## Context
- Project: {project_name}
- Figma file: {file_name}
- Current phase: {phase_number} — {phase_name}
- State file: specs/figma/session-state.json
- Journal: specs/figma/operation-journal.jsonl

## Instructions
Read the phase instructions from:
  $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/workflow-draft-to-handoff.md
  (Phase {N} section)

Read the convergence protocol from:
  $CLAUDE_PLUGIN_ROOT/skills/figma-console-mastery/references/convergence-protocol.md

## Mandatory Rules
1. Read the journal FIRST — build a set of completed operations
2. SKIP any operation already in the journal
3. Log EVERY mutating operation to the journal immediately after completion
4. Use batch scripts for 3+ homogeneous operations
5. Write updated session-state.json at phase completion
6. If blocked, write status: "needs-user-input" in session-state.json and STOP

## Scope
{phase-specific scope: which screens, which components, which operations}
```

### Delegation Rules

| # | Rule | Rationale |
|---|------|-----------|
| D1 | **Phase 0 always inline** | Lightweight inventory doesn't justify dispatch overhead |
| D2 | **Phase 2 splits by screen batches** (4-6 screens per subagent) | Keeps each agent's context focused; allows parallel dispatch |
| D3 | **Journal is the coordination bus** | Subagents don't need to communicate directly; they read/write the same journal |
| D4 | **Orchestrator checks journal between dispatches** | Ensures phase N truly completed before dispatching phase N+1 |
| D5 | **Failed subagent = retry once, then escalate** | Orchestrator reads journal to determine what was completed, dispatches a new agent for remaining work |
| D6 | **Screen batches are independent** | Batch A's screens don't depend on Batch B; safe for parallel dispatch |
| D7 | **Subagents NEVER interact with users** | If user input is needed, subagent writes `needs-user-input` to session state and stops; orchestrator mediates |
| D8 | **Sequential journal writes** | Even when batches are dispatched "in parallel," journal appends must not interleave. In practice, Claude Code `Task` agents run sequentially (each completes before the next starts), so this is satisfied automatically. If the execution model changes to true parallelism, introduce a file lock or per-batch journal files merged by the orchestrator |

### When to Use Subagent Delegation

| Workflow Size | Strategy |
|---------------|----------|
| 1-4 screens, 0-3 components | **Inline** — run everything in main session with journal |
| 5-15 screens, 3-6 components | **Phased delegation** — subagent per phase |
| 16+ screens, 6+ components | **Batch delegation** — subagent per phase + screen batches in Phase 2 |

For small workflows (1-4 screens), the overhead of dispatching subagents exceeds the benefit. Use the journal and batch scripting patterns inline.

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
  "version": 2,
  "phase": 2,
  "timestamp": "2026-02-20T15:00:00Z",
  "file_name": "My Design File",
  "source_page": { "name": "Draft", "id": "24:2" },
  "target_page": { "name": "Handoff", "id": "24:500" },
  "journal_entries": 47,
  "screens": {
    "ONB-01": { "draft_id": "24:100", "handoff_id": "24:4300", "status": "complete", "diff_score": 98 },
    "ONB-02": { "draft_id": "24:200", "handoff_id": "24:4400", "status": "complete", "diff_score": 95 },
    "ONB-03": { "draft_id": "24:300", "handoff_id": null, "status": "pending" }
  },
  "components": {
    "StatusBar": { "id": "24:4271", "status": "complete" },
    "TopBar": { "id": "24:4274", "status": "complete" }
  },
  "connections": {},
  "notes": "Phase 2 — transferred 2/3 screens, resuming ONB-03"
}
```

### Snapshot Update Cadence

| Event | Action |
|-------|--------|
| Session start | Read existing snapshot or create new |
| Phase boundary | Write full snapshot |
| Every 3-4 screens in Phase 2 | Write snapshot |
| Every 5 components in Phase 1 | Write snapshot |
| Before and after batch script | Write snapshot |
| Subagent completion | Orchestrator writes snapshot |

### Resume Procedure

```
1. Read session-state.json → determine current phase
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
- `figma_node_children` on current working area → confirm nodes match journal

### Step 4 — Resume from first uncompleted operation
- DO NOT restart the phase from the beginning
- DO NOT re-execute any operation logged in the journal
- Continue from the exact point where work stopped

### Step 5 — Log recovery
```jsonl
{"ts":"...","op":"compact_recovery","target":"session","detail":{"phase":2,"journal_entries":47,"resumed_from":"ONB-03"},"phase":2}
```

---

## Cross-References

- **Draft-to-Handoff workflow** (uses this protocol): `workflow-draft-to-handoff.md`
- **Anti-patterns** (regression patterns to avoid): `anti-patterns.md`
- **figma-use tool inventory**: `figma-use-overview.md`
- **Foundation patterns** (IIFE wrapper, font preloading for `figma_execute` code): `recipes-foundation.md`
