# Convergence Protocol

> **Compatibility**: Verified against figma-console-mcp v1.11.2 (February 2026)
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

> **Additional convergence rules (C4–C9)** and **Quick Convergence Patterns**: See `convergence-execution.md` Sections 5–6.

---

## Cross-References

- **Execution patterns** (batch scripting, subagent delegation, session snapshots, compact recovery): `convergence-execution.md` (Tier 2)
- **Draft-to-Handoff workflow** (uses this protocol): `design-handoff` skill (product-definition plugin)
- **Quality Model** (unified quality dimensions, audit scripts, fix cycle protocol): `quality-dimensions.md`, `quality-audit-scripts.md`, `quality-procedures.md`
- **Anti-patterns** (regression patterns to avoid): `anti-patterns.md`
- **Advanced journal patterns** (cross-screen journal, compaction, C4-C9 rules, convergence patterns): `convergence-execution.md` (Tier 2)
- **Foundation patterns** (IIFE wrapper, outer-return requirement, font preloading for `figma_execute` code): `recipes-foundation.md`
