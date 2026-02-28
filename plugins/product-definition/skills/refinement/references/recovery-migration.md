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

## State Migration (v1 to v2)

When resuming a workflow started under the command-era (schema_version: 1),
migrate to skill-era (schema_version: 2):

### Phase-to-Stage Mapping

```
v1 current_phase        -> v2 current_stage
─────────────────────────────────────────────
INITIALIZATION          -> 1
WORKSPACE_INIT          -> 1
ANALYSIS_MODE_SELECTION -> 1
RESEARCH_DISCOVERY      -> 2
RESEARCH_ANALYSIS       -> 2
DEEP_ANALYSIS           -> 3
QUESTION_GENERATION     -> 3
USER_RESPONSE           -> 4
RESPONSE_ANALYSIS       -> 4
VALIDATION              -> 5
PRD_GENERATION          -> 5
COMPLETE                -> 6
```

### Migration Procedure

```
IF state.schema_version == 1 OR state.schema_version is missing:
    MAP current_phase to current_stage (table above)
    SET schema_version: 2
    SET orchestrator.delegation_model: "lean_orchestrator"
    PRESERVE all existing fields (user_decisions, rounds, phases)
    ADD current_stage field
    WRITE updated state file
```

All existing `user_decisions` and round data are preserved unchanged.

---

## Panel Config Compatibility

Panel config files (`requirements/.panel-config.local.md`) use `version: 1`.
If a future schema change is needed, add migration logic here.

**Current expectations:**
- `version: 1` — members array with `id`, `role`, `perspective_name`, `question_prefix`, `weight`, `focus_areas`, `prd_section_targets`, `analysis_steps` (step_1-5), `domain_guidance`
- Top-level fields: `preset`, `domain`, `created`, `updated`

**If panel config is missing or corrupt during resume:**
Fall back to default preset from `config/requirements-config.yaml` -> `panel.default_preset` (see `error-handling.md` → Panel Builder Failure Recovery).
