---
stage: all
artifacts_written:
  - design-narration/.narration-state.local.md
---

# State File Schema

> Reference for the structure of `design-narration/.narration-state.local.md`.
> State uses YAML frontmatter with append-only workflow log.

## CRITICAL RULES (must follow)

1. **Schema version required**: Always include `schema_version: 3` in frontmatter.
2. **Decisions are append-only**: Never overwrite a decision — append revision records with `revises` pointer.
3. **Checkpoint before interaction**: Update state BEFORE presenting any AskUserQuestion to the user.

---

## Top-Level Fields

```yaml
schema_version: 3
current_stage: 1-5
workflow_mode: interactive | batch   # v2: "interactive" (default, one-at-a-time) or "batch" (all screens per cycle)
screens_completed: 0
context_document: null  # path or null
```

---

## Per-Screen Structure

```yaml
screens:
  - node_id: "{NODE_ID}"
    name: "{SCREEN_NAME}"
    source: figma | batch_description+figma   # v2: "figma" (interactive) or "batch_description+figma" (batch mode with textual description)
    status: pending | in_progress | described | critiqued | questions_asked | refined | signed_off
    narrative_file: "screens/{nodeId}-{name}.md"
    screenshot_file: "figma/{nodeId}-{name}.png"
    critique_scores:
      completeness: [1-4]
      interaction_clarity: [1-4]
      state_coverage: [1-4]
      navigation_context: [1-4]
      ambiguity: [1-4]
      total: [X]
    flagged_for_review: false
    flag_reason: null          # "stall_plateau" | "user_flagged" | null — diagnostic context for review
    refinement_rounds: 0       # Tracks 2B refinement count for stall detection (survives crash recovery)
```

### Status Transitions

Valid screen status transitions (any other transition is invalid):

```
pending → in_progress        (2A dispatch begins)
in_progress → described      (2A completes, narrative file written)
described → critiqued         (self-critique scores populated)
critiqued → questions_asked   (maieutic questions generated)
questions_asked → refined     (2B refinement completes with user answers)
refined → critiqued           (re-critique after refinement — loop back)
refined → signed_off          (score >= good threshold OR user signs off)
critiqued → signed_off        (score >= good threshold on first pass, no questions needed)

# Non-standard transitions (recovery/user override):
any → pending                 (crash recovery reset)
in_progress → skipped         (user chose to skip screen on error)
```

**Terminal states:** `signed_off`, `skipped` — no further transitions allowed.

---

## Patterns (Accumulated Across Screens)

```yaml
patterns:
  shared_components: []
  navigation_patterns: []
  naming_conventions: []
  interaction_patterns: []
```

---

## Decision Audit Trail (Mutable With Tracking)

```yaml
decisions_audit_trail:
  - id: "screen-1-q3"
    screen: "login-screen"
    question: "What happens on failed login?"
    answer: "Show inline error"
    cycle: null                  # null for interactive mode; integer for batch mode cycle number
    timestamp: "{ISO}"

  - id: "screen-1-q3-rev1"
    screen: "home-screen"
    revises: "screen-1-q3"
    question: "What happens on failed login?"
    answer: "Show error toast notification"
    revision_reason: "Toast pattern used consistently across app"
    cycle: null
    timestamp: "{ISO}"
```

---

## Stage Tracking

```yaml
coherence:
  status: pending | completed
  inconsistencies_found: 0
  inconsistencies_resolved: 0

validation:
  status: pending | completed
  mpa_status: completed | partial   # All 3 MPA agents succeeded, or only 2/3 produced output
  quality_score: 0
  recommendation: ready | needs-revision
  pal_status: completed | partial | skipped

output:
  mode: null                        # "single-file" | "multi-file" | null (set in Stage 5, Step 5.0c)
```

---

## Auto-Resolved Questions (v3)

Questions automatically answered by the auto-resolve protocol (see `references/auto-resolve-protocol.md`).
Append-only — entries are never modified or removed.

```yaml
auto_resolved_questions:
  - id: "auto-001"
    stage: "2"
    screen: "CartScreen"
    question: "Empty state behavior?"
    answer: "Show illustration with CTA"
    rationale: "PRD Section 3.2 specifies empty state pattern"
    source_type: "context_document"
    source_ref: "Section 3.2"
    timestamp: "{ISO}"
```

---

## Batch Mode State (v2)

Present only when `workflow_mode == "batch"`:

```yaml
batch_mode:
  screens_input_document: "design-narration/screen-descriptions.md"   # Path to user's textual descriptions
  figma_page_node_id: "0:1"                                          # Figma page node containing all frames
  cycle: 1                                                           # Current batch Q&A cycle number
  screens_analyzed: 0                                                  # Incremented after each screen analysis; enables progress tracking
  status: parsing | analyzing | consolidating | waiting_for_user | refining | complete
  questions_file: "working/BATCH-QUESTIONS-001.md"                   # Current/most recent questions document
  questions_pending: 0                                                # Questions awaiting user answers
  questions_answered_total: 0                                        # Cumulative answers across all cycles
  dedup_stats:
    original: 0                # Raw questions before consolidation
    consolidated: 0            # Questions after dedup
    reduction_pct: 0           # Percentage reduction
  convergence:
    cycle_question_counts: []  # [23, 8, 0] — question count per cycle for trend tracking
    screens_at_good: 0         # Screens with critique score >= good threshold
    screens_below_good: 0      # Screens with critique score < good threshold
```

### Batch Status Transitions

```
parsing → analyzing           (screen descriptions parsed and matched to Figma frames)
analyzing → consolidating     (all screens analyzed, questions collected)
consolidating → waiting_for_user  (BATCH-QUESTIONS document written)
waiting_for_user → refining   (user answers read and validated)
refining → consolidating      (new questions emerged from refinement — next cycle)
refining → complete           (no new questions — convergence reached)

# Non-standard transitions (recovery):
any → analyzing               (crash recovery resume)
any → consolidating           (crash recovery — all screens analyzed but no questions doc)
```

---

## Initialization Template

When creating a new state file:

```yaml
---
schema_version: 3
current_stage: 2
workflow_mode: interactive    # Set to "batch" when --batch flag is used
screens_completed: 0
context_document: null
screens: []
patterns:
  shared_components: []
  navigation_patterns: []
  naming_conventions: []
  interaction_patterns: []
decisions_audit_trail: []
auto_resolved_questions: []
coherence:
  status: pending
  inconsistencies_found: 0
  inconsistencies_resolved: 0
validation:
  status: pending
  mpa_status: null
  quality_score: 0
  recommendation: null
  pal_status: null
output:
  mode: null
# batch_mode: (added only when workflow_mode == "batch" — see Batch Mode State section)
---
```

## Schema Migration

When `schema_version` in the state file is older than the current version in config:

```
READ state file schema_version
READ config state.schema_version

IF state.schema_version < config.schema_version:
    RUN migration for each version step:

    # v1 → v2: Add workflow_mode and per-screen source fields
    IF state.schema_version == 1:
        ADD top-level field: workflow_mode: "interactive"  (default — existing sessions are interactive)
        FOR each screen in screens[]:
            ADD field: source: "figma"  (default — existing screens were captured interactively)
        SET schema_version: 2
        # Note: batch_mode section is NOT added during migration
        # (only created when workflow starts in batch mode)

    # v2 → v3: Add auto_resolved_questions
    IF state.schema_version == 2:
        ADD top-level field: auto_resolved_questions: []  (append-only list, starts empty)
        SET schema_version: 3

    NOTIFY user: "State file migrated from schema v{old} to v{new}."
```

**Non-breaking guarantee:** Migrations MUST only add fields, never remove or rename existing ones. Existing user decisions and screen data are never modified during migration.

---

## CRITICAL RULES REMINDER

1. Schema version required
2. Decisions are append-only
3. Checkpoint before interaction
