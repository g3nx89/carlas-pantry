# Essential Rules

> **Compatibility**: Verified against figma-console-mcp v1.10.0 (February 2026)
>
> **Scope**: Complete MUST and AVOID rules for figma-console-mastery workflows.
> SKILL.md contains a top-8 summary; this file has the full list.
>
> **Load when**: Subagent dispatched for any Figma operation (included in subagent prompt template per convergence-protocol.md).

---

## MUST Rules (23)

1. **Call `figma_get_status` first** — gate check before any operation
2. **Wrap `figma_execute` in async IIFE with outer `return`** — `return (async () => { try { ... } catch(e) { return JSON.stringify({error: e.message}) } })()`. The outer `return` is required for the Desktop Bridge to await the Promise
3. **Use `figma.getNodeByIdAsync(id)`** — sync `figma.getNodeById()` **throws** in `dynamic-page` manifest mode (the API is disabled entirely). Use async variant inside async IIFE. (Async variant returns `null` if node doesn't exist — check for null separately)
4. **Load fonts before setting text** — `await figma.loadFontAsync({family, style})` before any `.characters` assignment
5. **Set `layoutMode` before layout properties** — padding, spacing, constraints all require auto-layout to be active first
6. **Use `figma_capture_screenshot` for post-Plugin-API validation** — `figma_take_screenshot` uses the REST API (cloud-synced, cached) and will NOT reflect recent `figma_execute` mutations
7. **Check before creating (idempotency)** — before creating a named node, check if it already exists: `figma.currentPage.findOne(n => n.name === "Target")`. Re-running a script must not produce duplicates
8. **Native-tools-first** — use `figma_search_components` and `figma_instantiate_component` for library components; use batch variable tools for token management
9. **Converge, never regress** — read per-screen journal (`specs/figma/journal/{screen-name}.jsonl`) before every mutating operation; if the operation is already logged, SKIP it (see `convergence-protocol.md`)
10. **Journal every mutation** — append to per-screen journal (`specs/figma/journal/{screen-name}.jsonl`) immediately after each successful Figma mutation; write session snapshot after each batch
11. **Respect tool constraints** — use `figma_get_file_for_plugin` instead of `figma_get_file_data` on large files; call `figma_clear_console` before each `figma_execute` batch (buffer holds ~100 entries, each `console.log` emits 3 entries)
12. **Smart componentization** — componentize only elements meeting all 3 criteria: recurrence (3+), behavioral variants exist, codebase match. See `workflow-code-handoff.md` TIER system
13. **Subagents inherit figma-console-mastery** — all subagents dispatched for Figma workflows must load the skill references before starting work (see `convergence-protocol.md` Subagent Prompt Template)
14. **Real timestamps only** — journal `ts` fields must come from `new Date().toISOString()` inside `figma_execute` or from the orchestrator's real clock
15. **Verify prototype reactions after wiring** — after `setReactionsAsync`, re-read `node.reactions`. If reactions.length is 0 but wiring was attempted, log as `group_unsupported`
16. **Load learnings at session start** — if `~/.figma-console-mastery/learnings.md` exists, read it during Phase 1
17. **Save discoveries at session end** — during Phase 4, review for compound learning triggers. Deduplicate by H3 key before appending
18. **`createInstance()` on COMPONENT, not COMPONENT_SET` — get COMPONENT_SET → find variant child → `createInstance()` on the child
19. **Never call `group.remove()` after moving children** — GROUP auto-deletes when all children are moved out. Explicit `remove()` throws and silently skips subsequent code
20. **Run quality audit per tier** — Spot after each screen pipeline, Standard at phase boundaries, Deep at session end. Quality model defines 11 dimensions, depth tiers, audit scripts. See `quality-dimensions.md`.
21. **Log quality audit to journal** — append `op: "quality_audit"` entry with tier, scores, and verdict after every audit evaluation
22. **Always include "Let's discuss this" option in AskUserQuestion calls** — never force users into constrained choices; always provide open-ended escape
23. **All Figma modifications and audits delegated to Sonnet subagents** — main context orchestrates only; never execute `figma_execute` or quality audits in main context

---

## AVOID Rules (14)

1. **Never skip Discovery** — always check existing components/tokens before building from scratch
2. **Never mutate Figma arrays directly** — fills, strokes, effects are immutable references; clone, modify, reassign
3. **Never return raw Figma nodes** from `figma_execute` — return plain data: `{ id: node.id, name: node.name }`
4. **Never leave nodes floating on canvas** — always place inside a Section or Frame container
5. **Never use individual variable calls for bulk operations** — use `figma_batch_create_variables` / `figma_batch_update_variables` (10-50x faster)
6. **Never use individual calls for 3+ same-type operations** — use batch `figma_execute` scripts with idempotency checks
7. **Never redo an operation already in the journal** — journal is the single source of truth for completed work
8. **Never trust in-context memory after compaction** — re-read per-screen journal before resuming
9. **Never save trivial or already-documented learnings** — only save insights NOT already covered by existing reference files
10. **Never set constraints on GROUP nodes** — convert to FRAME first
11. **Never use `figma_take_screenshot` to validate recent Plugin API mutations** — it serves stale cloud-cached renders; use `figma_capture_screenshot` instead
12. **Never split page-switch and data-read across calls** — `setCurrentPageAsync()` only affects the current async IIFE; subsequent calls revert to Figma Desktop active page. Always read in the same IIFE as the `setCurrentPageAsync` call
13. **Never use `primaryAxisSizingMode = "FILL"` on a frame** — invalid enum; use `"AUTO"` or `"FIXED"` on frames and set `child.layoutSizingHorizontal = "FILL"` on children instead
14. **Never skip Standard/Deep audit at phase boundaries** — the per-phase quality gate catches structural and token-binding issues that screenshots alone miss; suppress only when explicit conditions are met (see `quality-dimensions.md`)

---

## Cross-References

- **SKILL.md** (top 8 summary for orchestrator context)
- **convergence-protocol.md** (Subagent Prompt Template includes these rules)
- **anti-patterns.md** (error catalog supporting AVOID rules)
