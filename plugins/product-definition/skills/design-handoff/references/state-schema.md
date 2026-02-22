# State Schema — Design Handoff

> **File:** `design-handoff/.handoff-state.local.md`
> **Format:** YAML frontmatter + markdown body
> **Schema version:** 1

---

## YAML Frontmatter Schema

```yaml
---
schema_version: 1
workflow_mode: "guided" | "quick" | "batch"
current_stage: "1" | "2" | "2J" | "3" | "3J" | "3.5" | "3.5J" | "4" | "5" | "5J" | "complete"
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
    cycle: integer
    findings: [string]
  stage_3j:
    verdict: "pass" | "needs_deeper" | null
    cycle: integer
    findings: [string]
  stage_3_5j:
    verdict: "pass" | "needs_fix" | null
    cycle: integer
    findings: [string]
  stage_5j:
    verdict: "pass" | "needs_revision" | null
    cycle: integer
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
  1 → 2 → 2J → 3 → 3J → [3.5 → 3.5J] → 4 → 5 → 5J → complete
                           (conditional)
```

---

## Initialization Template

When creating a new state file:

```yaml
---
schema_version: 1
workflow_mode: "{MODE}"
current_stage: "1"
started_at: "{ISO_NOW}"
last_updated: "{ISO_NOW}"
figma_page: null
tier_decision: null
scenario: null
screens: []
# Per-screen entries initialized with: node_id, name, dimensions, child_count, image_fills,
# group_count, max_nesting_depth, readiness_score (naming, tokens, structure, component_usage),
# status: "pending", current_step: null, completed_steps: [], operation_journal: [],
# scenario_escalated: false, visual_diff_score: null, fix_attempts: 0,
# gap_count: {critical: 0, important: 0, nice_to_have: 0}, has_supplement: false,
# questions_answered: 0, questions_total: 0
component_library: { status: "pending", components: [] }
missing_screens: []
patterns: { shared_behaviors: [], common_transitions: [], global_edge_cases: [] }
judge_verdicts:
  stage_2j: { verdict: null, cycle: 0, findings: [] }
  stage_3j: { verdict: null, cycle: 0, findings: [] }
  stage_3_5j: { verdict: null, cycle: 0, findings: [] }
  stage_5j: { verdict: null, cycle: 0, findings: [] }
artifacts: { handoff_manifest: null, gap_report: null, handoff_supplement: null }
---

## Progress Log

[Append-only markdown log of stage completions and decisions]
```

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
2. Read state file → determine `current_stage`
3. For Stage 2 resume: find first screen with `status != "prepared"` and `status != "blocked"`
4. For each screen: check `completed_steps` array → resume from `current_step + 1`
5. For Stage 3 resume: check if `gap_report` artifact exists
6. For Stage 4 resume: find first screen with `questions_answered < questions_total`
7. Present resume summary to designer: "Resuming from Stage {N}. {M} screens completed, {K} remaining."

---

## Checkpoint Rules

1. Update `last_updated` timestamp on EVERY state write
2. Update `current_stage` BEFORE dispatching a coordinator (not after)
3. Update per-screen `status`, `current_step`, and `completed_steps` AFTER each successful step
4. Write judge verdicts IMMEDIATELY after judge returns
5. Never overwrite `designer_decision` in missing_screens — once set, it's final
6. Append to Progress Log for human-readable audit trail
