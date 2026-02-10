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
