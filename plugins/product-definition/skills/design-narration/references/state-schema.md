---
stage: all
artifacts_written:
  - design-narration/.narration-state.local.md
---

# State File Schema

> Reference for the structure of `design-narration/.narration-state.local.md`.
> State uses YAML frontmatter with append-only workflow log.

## CRITICAL RULES (must follow)

1. **Schema version required**: Always include `schema_version: 1` in frontmatter.
2. **Decisions are append-only**: Never overwrite a decision — append revision records with `revises` pointer.
3. **Checkpoint before interaction**: Update state BEFORE presenting any AskUserQuestion to the user.

---

## Top-Level Fields

```yaml
schema_version: 1
current_stage: 1-5
screens_completed: 0
context_document: null  # path or null
```

---

## Per-Screen Structure

```yaml
screens:
  - node_id: "{NODE_ID}"
    name: "{SCREEN_NAME}"
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
    timestamp: "{ISO}"

  - id: "screen-1-q3-rev1"
    screen: "home-screen"
    revises: "screen-1-q3"
    question: "What happens on failed login?"
    answer: "Show error toast notification"
    revision_reason: "Toast pattern used consistently across app"
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
```

---

## Initialization Template

When creating a new state file:

```yaml
---
schema_version: 1
current_stage: 2
screens_completed: 0
context_document: null
screens: []
patterns:
  shared_components: []
  navigation_patterns: []
  naming_conventions: []
  interaction_patterns: []
decisions_audit_trail: []
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
---
```

## Schema Migration

When `schema_version` in the state file is older than the current version in config:

```
READ state file schema_version
READ config state.schema_version

IF state.schema_version < config.schema_version:
    RUN migration for each version step:

    # v1 → v2 (placeholder — no migration needed yet)
    # When adding fields in future versions:
    # 1. Add new fields with sensible defaults (never remove existing fields)
    # 2. Preserve all existing decision_audit_trail entries unchanged
    # 3. Update schema_version in state file after successful migration
    # 4. Log migration in workflow log: "Migrated state schema v{old} → v{new}"

    NOTIFY user: "State file migrated from schema v{old} to v{new}."
```

**Non-breaking guarantee:** Migrations MUST only add fields, never remove or rename existing ones. Existing user decisions and screen data are never modified during migration.

---

## CRITICAL RULES REMINDER

1. Schema version required
2. Decisions are append-only
3. Checkpoint before interaction
