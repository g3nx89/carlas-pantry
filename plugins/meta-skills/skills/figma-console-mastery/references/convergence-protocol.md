# Convergence Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Anti-regression rules and operation journaling for Figma design workflows. For batch scripting, subagent delegation, session snapshots, and compact recovery, see `convergence-execution.md` (Tier 2). For the Draft-to-Handoff workflow that uses these patterns, see the `design-handoff` skill (product-definition plugin). For error recovery, see `anti-patterns.md`.

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
{"v":1,"ts":"...","op":"cross_screen_batch","target":"screens:ONB-01,ONB-02,ONB-03","detail":{"action":"batch_token_bind","variables_bound":12,"screens_affected":3},"flow":1,"phase":3}
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
| `flow` | Yes | Flow number (1 = Design Session, 2 = Handoff QA) |
| `phase` | Yes | Phase number within the flow (1-4) |

```jsonl
{"v":1,"ts":"2026-02-20T14:30:01Z","op":"rename","target":"24:4271","detail":{"from":"Frame 42","to":"StatusBar"},"flow":1,"phase":1}
{"v":1,"ts":"2026-02-20T14:30:02Z","op":"create_component","target":"24:4271","detail":{"name":"StatusBar","parent":"24:4200"},"flow":1,"phase":1}
{"v":1,"ts":"2026-02-20T14:30:05Z","op":"set_layout","target":"24:4271","detail":{"mode":"VERTICAL","padding":"16,16,16,16","gap":"8"},"flow":1,"phase":1}
{"v":1,"ts":"2026-02-20T14:30:10Z","op":"clone_screen","target":"24:4300","detail":{"source":"24:100","name":"ONB-01","handoff_id":"24:4300"},"flow":1,"phase":2}
{"v":1,"ts":"2026-02-20T14:30:15Z","op":"batch_rename","target":"batch","detail":{"count":12,"nodes":["24:4301","24:4302"]},"flow":1,"phase":2}
{"v":1,"ts":"2026-02-20T14:30:20Z","op":"phase_complete","target":"phase_1","detail":{"components_created":6,"total_ops":24},"flow":1,"phase":1}
```

**Legacy compatibility**: Entries with `phase` values 0-5 and no `flow` field are from the legacy design-handoff workflow. New entries MUST include `flow`.

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

## Cross-References

- **Execution patterns** (batch scripting, subagent delegation, session snapshots, compact recovery): `convergence-execution.md` (Tier 2)
- **Draft-to-Handoff workflow** (uses this protocol): `design-handoff` skill (product-definition plugin)
- **Quality Model** (unified quality dimensions, audit scripts, fix cycle protocol): `quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`
- **Anti-patterns** (regression patterns to avoid): `anti-patterns.md`
- **Foundation patterns** (IIFE wrapper, outer-return requirement, font preloading for `figma_execute` code): `recipes-foundation.md`
