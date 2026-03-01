# State Schema — Design Handoff

> **File:** `design-handoff/.handoff-state.local.md`
> **Format:** YAML frontmatter + markdown body
> **Schema version:** 1

---

## YAML Frontmatter Schema

```yaml
---
schema_version: 1
checksum: string                # SHA-256 of YAML body (excluding checksum field itself)
workflow_mode: "guided" | "quick" | "batch"
current_stage: "1" | "2" | "2:circuit_breaker" | "2J" | "3" | "3J" | "3.5" | "3.5J" | "4" | "5" | "5:supplement_written" | "5J" | "retrospective" | "complete"
started_at: "ISO-8601"
last_updated: "ISO-8601"

# ─── Stage 1 Output ───────────────────────────────────────────

figma_page:
  name: string
  node_id: string

tier_decision:
  tier: 1 | 2 | 3
  rationale: string
  passing_candidates: integer
  total_candidates: integer

effective_tier: 1 | 2 | 3         # Runtime tier — may differ from tier_decision.tier after downgrade.
                                   # Downstream stages MUST read effective_tier, not tier_decision.tier.

scenario: "draft_to_handoff" | "in_place_cleanup" | "already_clean"

screens:
  - node_id: string
    name: string
    dimensions: { width: integer, height: integer }
    child_count: integer
    image_fills: boolean
    group_count: integer
    readiness_score: { naming: float, tokens: float, structure: float, component_usage: float }
    max_nesting_depth: integer
    status: "pending" | "preparing" | "prepared" | "blocked"
    # Step-level progress for crash recovery (Stage 2)
    current_step: integer | null         # Current/last step number (1-9)
    completed_steps: []                  # [{step: integer, result: string, timestamp: string}]
    operation_journal: []                # [{operation: string, node_id: string, detail: string, timestamp: string}]
    scenario_escalated: boolean          # true if Scenario C escalated to Scenario B
    escalation_level: "micro" | "partial" | "full" | null  # Graduated escalation tier (Scenario C only)
    visual_diff_score: float | null
    fix_attempts: integer                # Visual diff fix cycle count (max 3)
    # Gap analysis (Stage 3)
    gap_count: { critical: integer, important: integer, nice_to_have: integer }
    has_supplement: boolean
    # Designer dialog (Stage 4)
    questions_answered: integer
    questions_total: integer

# ─── Component Library (TIER 2/3) ─────────────────────────────

component_library:
  status: "pending" | "created" | "skipped"
  components:
    - name: string
      figma_id: string
      code_name: string
      variant_props: [string]
      screens_used: [string]    # Screen names where this component should appear
      instances_verified: boolean

# ─── Missing Screens (Stage 3, Part B) ────────────────────────

missing_screens:
  - name: string
    reason: string
    classification: "MUST_CREATE" | "SHOULD_CREATE" | "OPTIONAL"
    designer_decision: "create_in_figma" | "create_manually" | "document_only" | "skip" | null
    created_node_id: string | null   # Populated if created in Stage 3.5
    extension_status: "pending" | "created" | "verified" | "pending_manual" | "error" | null

# ─── Cross-Screen Patterns ────────────────────────────────────

patterns:
  shared_behaviors: []
  common_transitions: []
  global_edge_cases: []

# ─── Judge Verdicts ────────────────────────────────────────────

judge_verdicts:
  stage_2j:
    verdict: "pass" | "needs_fix" | "block" | null
    fix_type: "re_prepare" | null
    cycle: integer
    prior_findings_count: integer | null  # For convergence check
    findings: [string]
  stage_3j:
    verdict: "pass" | "needs_fix" | null
    fix_type: "re_examine" | null
    cycle: integer
    prior_findings_count: integer | null
    findings: [string]
  stage_3_5j:
    verdict: "pass" | "needs_fix" | null
    fix_type: "re_prepare" | null
    cycle: integer
    prior_findings_count: integer | null
    findings: [string]
  stage_5j:
    verdict: "pass" | "needs_fix" | null
    fix_type: "re_assemble" | null
    cycle: integer
    prior_findings_count: integer | null
    findings: [string]

# ─── Artifacts Written ─────────────────────────────────────────

artifacts:
  handoff_manifest: string | null      # Path when written
  gap_report: string | null
  handoff_supplement: string | null
  operation_journal: string | null

---
```

---

## State Transitions

```
Screen status flow:
  pending → preparing → prepared → blocked (visual diff failed after max retries)
  Note: "preparing" is the ONLY in-progress status. Agents write "preparing" during work.

Extension status flow:
  pending → created → verified
  pending → pending_manual (designer creates) → verified (on resume)
  pending → error (creation failed)

Stage flow:
  1 → 2 → 2J → 3 → 3J → [3.5 → 3.5J] → 4 → 5 → 5:supplement_written → 5J → [retrospective] → complete
                           (conditional)

  2:circuit_breaker — Screen loop halted due to consecutive MCP failures.
                      Resume checks figma-console connectivity before re-entering loop.
  5:supplement_written — HANDOFF-SUPPLEMENT.md written, manifest not yet updated.
                         Resume from Step 5.6 (skip supplement regeneration).
  retrospective — Retrospective protocol in progress. Lock already released.
                   Resume re-dispatches retrospective coordinator.
  complete — terminal state. Lock released, all artifacts finalized.
             Resume protocol detects "complete" and skips all stages.
```

---

## Initialization Template

When creating a new state file:

```yaml
---
schema_version: 1
checksum: "{COMPUTED_SHA256}"
workflow_mode: "{MODE}"
current_stage: "1"
started_at: "{ISO_NOW}"
last_updated: "{ISO_NOW}"
figma_page: null
tier_decision: null
effective_tier: null
scenario: null
screens: []
# Per-screen entries initialized with: node_id, name, dimensions, child_count, image_fills,
# group_count, max_nesting_depth, readiness_score (naming, tokens, structure, component_usage),
# status: "pending", current_step: null, completed_steps: [], operation_journal: [],
# scenario_escalated: false, escalation_level: null, visual_diff_score: null, fix_attempts: 0,
# gap_count: {critical: 0, important: 0, nice_to_have: 0}, has_supplement: false,
# questions_answered: 0, questions_total: 0
component_library: { status: "pending", components: [] }
missing_screens: []
patterns: { shared_behaviors: [], common_transitions: [], global_edge_cases: [] }
judge_verdicts:
  stage_2j: { verdict: null, fix_type: null, cycle: 0, prior_findings_count: null, findings: [] }
  stage_3j: { verdict: null, fix_type: null, cycle: 0, prior_findings_count: null, findings: [] }
  stage_3_5j: { verdict: null, fix_type: null, cycle: 0, prior_findings_count: null, findings: [] }
  stage_5j: { verdict: null, fix_type: null, cycle: 0, prior_findings_count: null, findings: [] }
artifacts: { handoff_manifest: null, gap_report: null, handoff_supplement: null }
---

## Progress Log

[Append-only markdown log of stage completions and decisions]
```

---

## State File Integrity

**Single-writer constraint:** Only ONE agent or orchestrator writes to the state file at any time. Coordinators dispatched via `Task()` must NOT write concurrently. The orchestrator writes between dispatches; agents write during their dispatch window.

**Atomic writes:** All state file writes MUST use the write-to-tmp-then-rename pattern:
1. Write updated content to `{STATE_FILE}.tmp`
2. Rename `{STATE_FILE}.tmp` → `{STATE_FILE}` (atomic on POSIX)

This prevents mid-write corruption from crashes. If a `.tmp` file exists on resume, it indicates an interrupted write — discard the `.tmp` file and use the existing state file.

**Checksum verification:** After every state file read, compute SHA-256 of the YAML body (excluding the `checksum` field) and compare to the stored `checksum` value. If mismatch: HALT workflow, notify designer: "State file corruption detected. Last known good stage: {current_stage}."

**Checksum update:** Before every state file write, recompute the checksum from the new YAML body and include it in the written content.

---

## Lock Protocol

| Property | Value |
|----------|-------|
| Lock file | `design-handoff/.handoff-lock` |
| Stale timeout | 60 minutes (from config) |
| Acquisition | Write lock with timestamp at Stage 1 start |
| Release | Delete lock at workflow completion or explicit abort |
| Stale detection | If lock age > timeout → warn user, offer override |

---

## Resume Protocol

On re-invocation:

1. Check lock file exists → if stale, offer override
2. Read state file → verify checksum integrity (halt on mismatch)
3. Determine `current_stage`
4. **If `current_stage == "complete"`:** Notify designer: "Handoff already complete. Re-run to start a new handoff." STOP.
4a. **If `current_stage == "retrospective"`:** Lock is already released. Re-dispatch retrospective coordinator (`references/retrospective-protocol.md`). On completion, set `current_stage = "complete"`.
5. **If `current_stage == "5:supplement_written"`:** Resume from Step 5.6 (manifest update). Skip supplement regeneration.
6. **If `current_stage == "2:circuit_breaker"`:** Screen loop was halted due to consecutive MCP failures. Verify figma-console connectivity (`figma_get_status`). If available: reset `current_stage` to `"2"`, re-enter screen loop from next pending screen. If unavailable: notify designer "figma-console still unavailable" and STOP.
7. For Stage 2 resume: find first screen with `status != "prepared"` and `status != "blocked"`
8. For each screen: check `completed_steps` array → resume from `current_step + 1`
9. For Stage 3 resume: check if `gap_report` artifact exists
10. For Stage 4 resume: find first screen with `questions_answered < questions_total`
11. Present resume summary to designer: "Resuming from Stage {N}. {M} screens completed, {K} remaining."

---

## Completion Protocol

After Stage 5J passes, execute these steps to finalize the workflow:

```
1. DELETE lock file: design-handoff/.handoff-lock
2. SET last_updated = NOW()
3. APPEND to Progress Log: "## Lock Released\n- Released: {ISO_NOW}\n- Artifacts: HANDOFF-SUPPLEMENT.md, handoff-manifest.md"
4. Recompute checksum and WRITE state file (atomic)

5. READ config -> retrospective.enabled
   IF retrospective.enabled:
       SET current_stage = "retrospective"
       WRITE state file (atomic)
       DISPATCH coordinator with references/retrospective-protocol.md
       (Coordinator sets current_stage = "complete" upon completion)
   ELSE:
       SET current_stage = "complete"
       WRITE state file (atomic)
```

The `"complete"` stage is terminal. No further stages dispatch. On re-invocation, the resume protocol detects `current_stage == "complete"` and stops with a notification.

---

## Checkpoint Rules

1. Update `last_updated` timestamp on EVERY state write
2. Recompute `checksum` on EVERY state write; verify on EVERY state read
3. Use atomic writes (write-to-tmp-then-rename) for ALL state file updates
4. Update `current_stage` BEFORE dispatching a coordinator (not after)
5. Update per-screen `status`, `current_step`, and `completed_steps` AFTER each successful step
6. Write judge verdicts IMMEDIATELY after judge returns
7. Never overwrite `designer_decision` in missing_screens — once set, it's final
8. Update `effective_tier` whenever a TIER downgrade occurs (e.g., component library failure)
9. Append to Progress Log for human-readable audit trail
