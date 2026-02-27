# Session Index Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: L2 session-scoped cache for name-to-ID resolution. Sits between L1 (native tool server-side cache) and L3 (deep `figma_execute` queries). Built once per session from `figma_get_file_data`, consulted via `Grep`, invalidated via `figma_get_design_changes`.
>
> **Load when**: Multi-screen workflows needing name-to-ID resolution (Tier 2 — by task).

---

## Problem Statement

The figma-console-mastery skill repeatedly navigates Figma file elements (screens, components, frames) across multiple phases and subagent dispatches. Each time a screen name needs resolving to a node ID, the skill calls `figma_get_file_for_plugin`, `figma_get_file_data`, or `figma_execute` with discovery scripts — each a full MCP roundtrip (~2-5s + token overhead).

In a Standard Audit of 5 screens, the same screen node is fetched ~5 times and the full tree traversed ~4 times per screen. This redundancy costs **20-40 seconds** and **5-15K tokens** in unnecessary MCP traffic per workflow.

---

## Three-Tier Access Model

| Tier | Mechanism | Latency | Token Cost | When to Use |
|------|-----------|---------|------------|-------------|
| **L1** | Native tools (server-side cache) | ~1s | Low | `figma_search_components`, `figma_get_variables(filtered)`, `figma_get_design_system_summary` — always prefer |
| **L2** | Session Index (this protocol) | ~0s | ~0 | Name-to-ID lookups, page inventory, type filtering — `Grep` on local JSONL file |
| **L3** | Deep queries (`figma_execute`) | ~2-5s | Medium-High | Depth 2+ children, visual properties, post-mutation live state — on-demand, not cached |

**Rule**: Check L1 → L2 → L3 in order. Never skip to L3 when L2 can answer the query.

---

## File Locations

```
specs/figma/
  session-index.jsonl          # One JSONL entry per depth-1 node
  session-index-meta.json      # Build metadata (version, timestamps, entry count)
```

Both files are session-scoped — they live alongside `session-state.json` and `journal/` in the `specs/figma/` directory. A session spans one Flow 1 or Flow 2 invocation on a single Figma file; the index persists on disk for resume but is logically scoped to the active flow.

---

## Index Entry Format

One JSON object per line. Each entry represents a depth-1 node (direct child of a page).

```jsonl
{"id":"24:4300","name":"Login Screen","type":"FRAME","page_id":"24:100","page_name":"Handoff","depth":1}
{"id":"24:4301","name":"Signup Screen","type":"FRAME","page_id":"24:100","page_name":"Handoff","depth":1}
{"id":"24:4500","name":"StatusBar","type":"COMPONENT","page_id":"24:200","page_name":"Components","depth":1}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Figma node ID |
| `name` | string | Node name as displayed in Figma layers panel |
| `type` | string | Node type (`FRAME`, `COMPONENT`, `COMPONENT_SET`, `SECTION`, `GROUP`, `INSTANCE`, etc.) |
| `page_id` | string | Parent page node ID |
| `page_name` | string | Parent page name |
| `depth` | number | Always `1` for indexed entries (direct page children) |

---

## Meta File Format

```json
{
  "version": 1,
  "file_key": "abc123XYZ",
  "created_at": "2026-02-20T14:00:00Z",
  "last_validated": "2026-02-20T14:00:00Z",
  "total_entries": 32
}
```

| Field | Description |
|-------|-------------|
| `version` | Schema version — always `1` |
| `file_key` | Figma file key from `figma_list_open_files` — used to detect file switches |
| `created_at` | ISO 8601 timestamp of initial build |
| `last_validated` | ISO 8601 timestamp of last freshness check |
| `total_entries` | Number of JSONL lines in `session-index.jsonl` |

---

## Build Procedure

### When to Build

- Phase 1 Preflight, **after `figma_navigate`** (Step 3.5 in `flow-procedures.md`)
- Only if:
  - `session-index.jsonl` does not exist, OR
  - `session-index-meta.json` `file_key` differs from the current file

If the index exists and `file_key` matches, skip to validation (see below).

### Steps

1. Call `figma_get_file_data(verbosity='summary', depth=1)` — returns page structure with depth-1 children
2. Parse response: iterate pages, then each page's children
3. Write one JSONL line per child to `specs/figma/session-index.jsonl`:
   ```jsonl
   {"id":"<child.id>","name":"<child.name>","type":"<child.type>","page_id":"<page.id>","page_name":"<page.name>","depth":1}
   ```
4. Write `specs/figma/session-index-meta.json` with `version`, `file_key`, `created_at`, `last_validated`, `total_entries`
5. Log to `_session-summary.jsonl`:
   ```jsonl
   {"v":1,"ts":"...","op":"session_index_built","target":"session","detail":{"total_entries":32,"file_key":"abc123XYZ"},"phase":1}
   ```

**Write order and recovery**: Write JSONL first (step 3), then meta (step 4). On resume, if JSONL exists but meta is missing, delete the orphaned JSONL and rebuild — partial writes without meta cannot be validated.

### Token Budget

A 30-screen file produces ~30-50 JSONL lines (~2-5K tokens for the `figma_get_file_data` response). This is a one-time cost that eliminates repeated full-tree fetches throughout the session.

---

## Lookup Patterns

### Name to ID

```
Grep(pattern='"name":"Login Screen"', path='specs/figma/session-index.jsonl', output_mode='content')
```

Parse the matching line as JSON to extract `id`. If multiple entries share the same name (e.g., frames on different pages), disambiguate using the `page_name` field or use the combined filter pattern below.

### Page Inventory

```
Grep(pattern='"page_name":"Handoff"', path='specs/figma/session-index.jsonl', output_mode='content')
```

Returns all depth-1 nodes on the "Handoff" page.

### Type Filter

```
Grep(pattern='"type":"COMPONENT"', path='specs/figma/session-index.jsonl', output_mode='content')
```

Returns all top-level components across all pages.

### Combined Filter (name + page)

Uses regex — `.*` matches any characters between the two fields within the same JSONL line:

```
Grep(pattern='"name":"Login.*page_name":"Handoff"', path='specs/figma/session-index.jsonl', output_mode='content')
```

### Miss Handling

If a `Grep` returns no matches:
1. **Do NOT treat this as "node doesn't exist"** — it may be a depth 2+ node not in the index
2. Fall back to L3: `figma_execute` with `figma.currentPage.findOne(n => n.name === "...")` or `figma.getNodeByIdAsync(id)`
3. If found via L3, consider whether the index needs rebuilding (the node may have been created after index build)

---

## Validation & Invalidation

### Staleness Check

Before trusting the index after a gap (phase transition, compact recovery, or >5 minutes since `last_validated`):

1. Read `session-index-meta.json` → get `last_validated` timestamp
2. Call `figma_get_design_changes(since=last_validated)`
3. If changes affect depth-1 nodes (page children added, removed, or renamed):
   - Rebuild the index (full build procedure)
4. If no relevant changes:
   - Update `last_validated` in meta file to current time
5. Staleness threshold: **5 minutes (300000ms)**

### Force Rebuild Triggers

| Trigger | Action |
|---------|--------|
| File switch detected (`file_key` mismatch) | Delete and rebuild |
| User explicitly requests rebuild | Delete and rebuild |
| Meta file missing or corrupt | Full rebuild |
| Index file missing | Full rebuild |
| Index file corrupt or unparseable | Delete both files, full rebuild |
| JSONL exists but meta missing (orphaned) | Delete JSONL, full rebuild |
| Compact recovery (convergence-protocol.md §6) | Validate, rebuild if stale |

---

## Subagent Integration

### Orchestrator Responsibilities

- **Builds** the Session Index during Phase 1 Preflight
- **Validates** freshness before dispatching subagents (C9 rule)
- Includes index path in subagent context block (see `convergence-execution.md` Subagent Prompt Template)

### Subagent Responsibilities

- **Read only** via `Grep` — subagents never build or modify the index
- Use for name-to-ID resolution before calling `figma_get_file_for_plugin` or `figma_execute` discovery scripts
- On cache miss, fall back to L3 (never treat miss as "doesn't exist")

### When NOT to Use the Session Index

- **Depth 2+ children** — the index only contains depth-1 nodes; use `figma_execute` for deeper traversal
- **Visual properties** (fills, strokes, effects) — not stored in the index; use `figma_execute` or native tools
- **Post-mutation live state** — after creating/deleting nodes, the index may be stale; use `figma_capture_screenshot` or `figma_execute` for verification
- **Component instance details** — use `figma_get_component_details` (L1) instead

---

## Cross-References

- **Build trigger location**: `flow-procedures.md` §1.1 Step 3.5
- **Convergence rules**: `convergence-protocol.md` C8 (consult before MCP discovery), C9 (validate at phase boundaries)
- **Subagent prompt template**: `convergence-protocol.md` §4 (Session Index line in context block)
- **Three-tier access model**: §Three-Tier Access Model above (L1/L2/L3 definitions and decision rule)
- **SKILL.md**: Phase 1 description, Selective Reference Loading, Loading Tiers
