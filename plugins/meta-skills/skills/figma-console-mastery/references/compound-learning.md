# Compound Learning Protocol

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Cross-session knowledge persistence for figma-console-mastery. Captures API quirks,
> effective strategies, error recovery patterns, and performance insights discovered during Figma
> design sessions. Learnings persist at `~/.figma-console-mastery/learnings.md` (user-home,
> cross-project).
>
> **Relationship**: Complements the intra-session convergence protocol (`convergence-protocol.md`).
> The convergence protocol prevents regression *within* a session; compound learning prevents
> re-discovery of solutions *across* sessions.

---

## 1. Learnings File

### Location

```
~/.figma-console-mastery/learnings.md
```

Cross-project, user-scoped. The file is **optional** — all workflows function identically without it.
Created automatically when the first learning is saved.

### Format

```markdown
# Figma Console Mastery — Learnings

> Auto-maintained by figma-console-mastery skill. Safe to edit manually.
> Entries are append-only during sessions. To remove a learning, delete its `### ` block.

## API Quirks & Workarounds

### short-descriptive-key
- **Discovered**: YYYY-MM-DD
- **Context**: 1-2 sentences (task being performed)
- **Problem**: 1-3 sentences (what went wrong)
- **Solution**: 1-3 sentences (effective resolution)
- **Tags**: comma, separated, keywords

## Effective Strategies

## Error Recovery

## Performance Patterns
```

### Entry Rules

| Rule | Description |
|------|-------------|
| **H3 key format** | Lowercase, hyphenated, 3-6 words (e.g., `group-nodes-drop-reactions`) |
| **No project-specific info** | Entries must be generalizable — no file names, node IDs, or project names |
| **No duplication of existing references** | Do not save what is already in SKILL.md, anti-patterns.md, or other reference files |
| **Concise** | Problem + Solution together should not exceed 6 sentences |
| **Tags required** | 2-5 lowercase keywords for relevance matching |

### Categories

| Category | What belongs here |
|----------|-------------------|
| **API Quirks & Workarounds** | Undocumented API behavior, silent failures, parameter edge cases |
| **Effective Strategies** | Approaches that proved significantly more effective than alternatives |
| **Error Recovery** | Recovery procedures for errors not covered in anti-patterns.md |
| **Performance Patterns** | Batch sizes, operation ordering, or tool choices that improved speed/token efficiency |

---

## 2. File Lifecycle

| Event | Action |
|-------|--------|
| First session ever | File does not exist; created when first learning is saved |
| Session start (Phase 1 Preflight) | Read file if it exists; note entries relevant to current task |
| Session end (Phase 4 Validation) | Review session for learning-worthy discoveries; append 0-3 entries |
| Between sessions | File persists at user-home; user may edit or delete entries manually |
| File exceeds ~50 entries | Consider archiving older entries to `~/.figma-console-mastery/learnings-archive.md`. Entries older than 6 months may reference fixed API behavior — verify before relying on them |
| File missing or empty | Normal — all workflows function identically without it |

---

## 3. Save Protocol

### Auto-Detect Triggers

During Phase 4 Validation, review the session for these triggers:

| # | Trigger | Category | Example |
|---|---------|----------|---------|
| T1 | **>1 attempt to solve** — an operation required retry with a different approach | API Quirks & Workarounds | `figma_set_layout` silently ignored because parent had constraints |
| T2 | **Workaround discovered** — standard approach failed, non-obvious alternative worked | API Quirks & Workarounds | Using `figma_execute` batch instead of individual `figma_set_fill` for gradient nodes |
| T3 | **Non-obvious recovery** — error recovery required investigation beyond anti-patterns.md | Error Recovery | CDP connection dropped mid-batch; re-launching with port reset resolved |
| T4 | **Strategy significantly outperformed** — a chosen approach was measurably better | Effective Strategies | Processing component variants in dependency order eliminated rework |
| T5 | **Performance surprise** — unexpected token/time savings or costs | Performance Patterns | `figma_render` JSX for 8+ nodes was 3x faster than individual `figma_create_*` |
| T6 | **Quality audit reveals systematic gap** — same dimension scored <7.0/10 across 2+ screens or 2+ sessions (see `quality-dimensions.md`) | Effective Strategies or Performance Patterns | Token binding consistently low — batch binding at phase boundary is more effective than per-screen |

### Save Procedure

```
1. Identify 0-3 learning candidates from the session (apply triggers T1-T6)
2. For T6 specifically (quality audit-driven):
   a. Read all op: "quality_audit" entries from the session journal
   b. Identify any dimension scoring <7.0 in 2+ quality audit entries (cross-screen or cross-phase)
   c. If found: compose entry with H3 key: <dimension>-systematic-gap (e.g., "token-binding-batch-at-phase-boundary")
   d. Include the corrective approach that improved scores when applied
3. For each candidate:
   a. Compose entry per Entry Rules (H3 key, Discovered, Context, Problem, Solution, Tags)
   b. Deduplicate: grep learnings file for H3 key — if match found, skip
   c. Verify not already documented in existing reference files
   d. Append under the appropriate H2 category
3. If learnings file does not exist, create it with the template (header + 4 empty H2 categories)
   then append entries
```

### When NOT to Save

| Condition | Reason |
|-----------|--------|
| Solution is already in anti-patterns.md | Duplication — reference files are canonical |
| Solution is already in SKILL.md rules | Duplication |
| Solution is trivial (e.g., "wrap in try-catch") | Covered by Essential Rules |
| Solution is project-specific (only applies to one file/design) | Not generalizable |
| Session had no retries, workarounds, or surprises | Nothing to learn |

---

## 4. Load Protocol

### During Phase 1 Preflight

```
1. Check if ~/.figma-console-mastery/learnings.md exists
2. If yes: read the file
3. Scan entries — note any whose Tags overlap with the current task type
   (e.g., if task involves "components", note entries tagged "component", "instance", "variant")
4. Keep relevant entries in working context for proactive application
5. If no: proceed normally — no learnings is the expected state for new users
```

### Relevance Matching

Match by **Tags** field against the current task characteristics:

| Task Type | Relevant Tags |
|-----------|---------------|
| Component creation | `component`, `variant`, `instance`, `library` |
| Screen building | `clone`, `screen`, `layout`, `auto-layout` |
| Token/variable work | `variable`, `token`, `binding`, `collection` |
| Analysis/diffing | `analyze`, `diff`, `query`, `xpath` |
| Restructuring | `restructure`, `auto-layout`, `rename`, `reparent` |
| Prototype wiring | `prototype`, `reaction`, `navigation`, `group` |

---

## 5. Subagent Integration

### Orchestrator-Only Reads/Writes

- The **orchestrator** reads `~/.figma-console-mastery/learnings.md` during Phase 1
- The **orchestrator** writes new entries during Phase 4
- **Subagents never read or write the learnings file directly**

### Filtered Injection into Subagent Prompts

When dispatching subagents (per `convergence-execution.md` Subagent Prompt Template), the orchestrator
MAY inject relevant learnings into the subagent prompt:

```
## Compound Learnings (from prior sessions)

### group-nodes-drop-reactions
- **Problem**: GROUP nodes silently drop prototype reactions after setReactionsAsync
- **Solution**: Verify reactions.length after wiring; log as group_unsupported if 0
- **Tags**: prototype, reaction, group

### batch-fill-gradient-nodes
- **Problem**: figma_set_fill on gradient nodes returns success but doesn't apply
- **Solution**: Use figma_execute with explicit GradientPaint construction
- **Tags**: fill, gradient, batch
```

**Rules for injection**:
- Include only entries whose Tags match the subagent's task scope
- Maximum 3 entries per subagent prompt (context budget)
- Omit the Discovered and Context fields — subagents only need Problem + Solution + Tags
- If no relevant entries exist, omit the section entirely

---

## 6. Deduplication

Before appending a new entry, check for existing entries with the same or similar H3 key:

```
1. Grep learnings file for the proposed H3 key (exact match)
2. If found: skip — entry already exists
3. Secondary check: grep for the first 2-3 keywords of the Problem field. If any existing
   entry has 2+ keyword overlap, read it to assess semantic duplication:
   a. If same problem/solution: skip (already captured under a different key)
   b. If different aspect of same topic: use a distinct key and append
```

The deduplication check is lightweight — grep for `### proposed-key` plus a keyword spot-check
on the Problem field. No fuzzy matching or deep semantic analysis required.

---

## Cross-References

- **Convergence Protocol** (intra-session persistence): `convergence-protocol.md`
- **Quality Model** (unified quality dimensions, audit scripts): `quality-dimensions.md`
- **Anti-patterns** (known errors — do not duplicate in learnings): `anti-patterns.md`
- **SKILL.md** (session protocol Phase 1 load, Phase 4 save): `SKILL.md`
