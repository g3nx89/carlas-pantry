# Recovery & State Migration

> Loaded on-demand by the orchestrator when crash recovery or state migration is needed.
> Not loaded during normal dispatch flow.

---

## Crash Recovery

If a coordinator produces no summary file (crash, timeout, context exhaustion):

```
IF summary file missing for stage N:
    CHECK for artifacts that stage N should have written
    (from artifacts_written in the stage reference frontmatter)

    IF artifacts found:
        RECONSTRUCT minimal summary:
        ---
        stage: "{stage_name}"
        stage_number: {N}
        status: completed
        checkpoint: "{CHECKPOINT}"
        artifacts_written: [{found artifacts}]
        summary: "Reconstructed from artifacts (coordinator crashed)"
        flags:
          recovered: true
        ---

    IF no artifacts found:
        MARK stage as failed
        Notify user: "Stage {N} failed. No output produced."
        Ask: "Retry stage?" or "Skip and continue?"
```

---

## State Migration (v2 to v3)

When resuming a workflow started under the command-era (schema_version: 2, phase-based),
migrate to skill-era (schema_version: 3, stage-based):

### Phase-to-Stage Mapping

```
v2 current_phase        -> v3 current_stage
─────────────────────────────────────────────
INIT                    -> 1
FIGMA_CAPTURE           -> 1
SPEC_DRAFT              -> 2
CHECKLIST_CREATION      -> 3
CHECKLIST_VALIDATION    -> 3
CLARIFICATION           -> 4
PAL_GATE                -> 5
DESIGN_FEEDBACK         -> 5
TEST_STRATEGY           -> 6
COMPLETE                -> 7
```

**Excluded phases (research):**
```
RESEARCH_DISCOVERY      -> SKIP (not in skill)
RESEARCH_ANALYSIS       -> SKIP (not in skill)
```

If the v2 state was at a research phase, migrate to Stage 2 (spec draft) since
research phases are not included in the skill workflow.

### MPA Phase Mapping

```
v2 mpa_challenge        -> Stage 2 (part of spec draft)
v2 mpa_edgecases        -> Stage 4 (part of clarification)
v2 mpa_triangulation    -> Stage 4 (part of clarification)
```

### Migration Procedure

```
IF state.schema_version == 2 OR state.schema_version is missing:
    MAP current_phase to current_stage (table above)
    SET schema_version: 3
    CONVERT phases.{phase} to stages.{stage} entries
    PRESERVE all existing fields (user_decisions, error_log, checkpoint_log)
    PRESERVE model_failures array
    ADD current_stage field
    RENAME phase_status to stage_status
    WRITE updated state file
```

All existing `user_decisions` and checkpoint data are preserved unchanged.

---

## State Migration (v3 to v4)

v4 adds file-based clarification and auto-resolve fields. This is an **additive migration** —
all new fields have null/empty defaults, so v3 state files continue to function.

### New Fields

```
stages.clarification:
  clarification_file_path: null        # NEW — path to clarification-questions.md
  clarification_status: null           # NEW — pending_write | awaiting_user | answers_received | processed
  auto_resolved_questions: []          # NEW — array of auto-resolved question records
  auto_resolve_stats:                  # NEW — aggregated auto-resolve statistics
    total_generated: 0
    auto_resolved: 0
    inferred: 0
    requires_user: 0
    user_overrides: 0
```

### Migration Procedure

```
IF state.schema_version == 3:
    SET schema_version: 4
    ADD stages.clarification.clarification_file_path: null
    ADD stages.clarification.clarification_status: null
    ADD stages.clarification.auto_resolved_questions: []
    ADD stages.clarification.auto_resolve_stats: {total_generated: 0, auto_resolved: 0, inferred: 0, requires_user: 0, user_overrides: 0}
    PRESERVE all existing fields unchanged
    WRITE updated state file
```

### Compatibility Notes

- v3 state files work without migration — coordinators treat missing fields as null/empty
- Migration is triggered automatically when orchestrator detects `schema_version: 3`
- `user_decisions.clarifications` array format is unchanged (still records per-question decisions)
- The old `questions_answered` counter remains for backward compatibility alongside new fields

---

## State Migration (v4 to v5)

v5 adds Requirements Traceability Matrix (RTM) fields. This is an **additive migration** —
all new fields have null/empty defaults, so v4 state files continue to function.
If RTM fields are missing, RTM features are treated as disabled.

### New Fields

```
rtm_enabled: null                            # NEW — true/false/null (null = not yet decided)
requirements_inventory:                      # NEW — inventory tracking
  file_path: null                            # Path to REQUIREMENTS-INVENTORY.md
  count: 0                                   # Number of confirmed requirements
  confirmed: false                           # Whether user has confirmed the inventory

stages.rtm:                                  # NEW — RTM stage tracking
  status: pending                            # pending | in_progress | completed
  total: 0                                   # Total REQ entries
  covered: 0                                 # COVERED disposition count
  partial: 0                                 # PARTIAL disposition count
  deferred: 0                                # DEFERRED disposition count
  removed: 0                                 # REMOVED disposition count
  unmapped: 0                                # UNMAPPED disposition count
  coverage_pct: 0                            # (covered + partial + deferred + removed) / total * 100
  disposition_status: null                   # null | pending | resolved
  dispositions_applied: 0                    # Count of user disposition decisions applied

user_decisions.rtm_dispositions: []          # NEW — immutable array of disposition decisions
```

### Migration Procedure

```
IF state.schema_version == 4:
    SET schema_version: 5
    ADD rtm_enabled: null
    ADD requirements_inventory: {file_path: null, count: 0, confirmed: false}
    ADD stages.rtm: {status: pending, total: 0, covered: 0, partial: 0, deferred: 0, removed: 0, unmapped: 0, coverage_pct: 0, disposition_status: null, dispositions_applied: 0}
    ADD user_decisions.rtm_dispositions: []
    PRESERVE all existing fields unchanged
    WRITE updated state file
```

### Compatibility Notes

- v4 state files work without migration — missing RTM fields mean RTM is disabled
- Migration is triggered automatically when orchestrator detects `schema_version: 4`
- `user_decisions.rtm_dispositions` follows the same immutable pattern as `user_decisions.clarifications`
- The `rtm_enabled: null` state means "not yet decided" — user is prompted during Stage 1
