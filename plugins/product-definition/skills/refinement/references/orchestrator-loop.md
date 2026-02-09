# Orchestrator Dispatch Loop and Recovery

> Read this file at the start of orchestration. It governs how stages are dispatched,
> how the iteration loop works, and how the orchestrator recovers from failures.

---

## Dispatch Loop

```
READ state file -> determine current_stage and waiting_for_user

IF waiting_for_user == true:
    ROUTE to the stage that set the pause (from state.pause_stage)
    The coordinator will detect user has returned and check for input

IF state.current_stage exists AND status != "completed":
    RESUME from state.current_stage

OTHERWISE:
    START from Stage 1

FOR each stage in dispatch order [1, 2, 3, 4, 5, 6]:
    IF stage already completed in this round (check stage summaries):
        SKIP

    IF stage == 1:
        EXECUTE inline (read stage-1-setup.md, execute directly)
    ELSE:
        DISPATCH coordinator (see Coordinator Dispatch below)

    READ coordinator summary
    HANDLE summary status (see Summary Handling)
```

---

## Coordinator Dispatch

For stages 2-6, dispatch a coordinator subagent:

```
Task(subagent_type="general-purpose", prompt="""
You are a coordinator for the Requirements Refinement workflow.

## Your Stage
Read and execute: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/{STAGE_FILE}

## Context
- Feature directory: requirements/
- Analysis mode: {ANALYSIS_MODE}
- PRD mode: {PRD_MODE}
- Current round: {ROUND_NUMBER}
- PAL available: {PAL_AVAILABLE}
- Sequential Thinking available: {ST_AVAILABLE}
- Config: @$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml
- Checkpoint protocol: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/checkpoint-protocol.md
- Error handling: @$CLAUDE_PLUGIN_ROOT/skills/refinement/references/error-handling.md

## Prior Stage Summaries
{CONTENTS OF requirements/.stage-summaries/stage-*-summary.md}

## State File
{CONTENTS OF requirements/.requirements-state.local.md}

## CRITICAL RULES
- You MUST NOT interact with users directly. If you need user input,
  write your summary with status: needs-user-input and describe what
  you need in flags.block_reason.
- You MUST write a summary file at requirements/.stage-summaries/stage-{N}-summary.md
  with YAML frontmatter following the summary contract in SKILL.md.
- You MUST update the state file after completing your work.
""")
```

---

## Summary Schema Validation

After each coordinator returns, validate its summary before acting:

```
READ summary file at requirements/.stage-summaries/stage-{N}-summary.md

VALIDATE required fields exist in YAML frontmatter:
  - stage: non-empty string
  - stage_number: integer 1-6
  - status: one of [completed, needs-user-input, failed]
  - checkpoint: non-empty string
  - artifacts_written: array
  - summary: non-empty string
  - flags: object

IF any required field is missing or malformed:
    LOG warning: "Stage {N} summary has missing/malformed fields: {list}"
    IF status field is present and valid:
        PROCEED with available data (best-effort)
    ELSE:
        TREAT as crash (see Crash Recovery below)
```

---

## Summary Handling

After each coordinator returns, read its validated summary and act:

### `status: completed`
Advance to next stage in sequence.

### `status: needs-user-input`
Check `flags.pause_type`:

**If `pause_type: exit_cli`:**
- Update state: `waiting_for_user: true`, `pause_stage: {N}`
- Display coordinator's `flags.block_reason` to user
- Display instructions for resuming
- **TERMINATE** the session (user works offline)

**If `pause_type: interactive`:**
- Read `flags.block_reason` for the question context
- Use `AskUserQuestion` to relay the question to the user
- Pass user's response back to coordinator by re-dispatching the same stage
  with the user's answer appended to context

### `status: failed`
- Log the failure
- Attempt crash recovery (see Crash Recovery below)
- If unrecoverable, notify user and terminate

---

## Iteration Loop Logic

The iteration loop is between Stages 3, 4, and 5. The orchestrator controls it.

### After Stage 4 Summary

Read `flags.next_action` from Stage 4 summary:

```
IF next_action == "loop_questions":
    INCREMENT state.current_round
    Ask user for analysis mode for new round (via AskUserQuestion)
    DISPATCH Stage 3 (new round)

IF next_action == "loop_research":
    DISPATCH Stage 2 (focused on gap areas)

IF next_action == "proceed":
    DISPATCH Stage 5
```

### After Stage 5 Summary

If Stage 5 validation result is RED (score < config -> `scoring.prd_readiness.conditional`):

```
IF flags.validation_decision == "NOT_READY":
    INCREMENT state.current_round
    Notify user: "PRD not ready. Score: {score}/20. Generating more questions."
    DISPATCH Stage 3 (new round)

IF flags.validation_decision in ["READY", "CONDITIONAL"]:
    PRD was generated successfully
    DISPATCH Stage 6
```

### Round Counter

Track in state file:
```yaml
current_round: {N}
rounds:
  - round_number: 1
    analysis_mode: "complete"
    questions_count: 15
    stage_3_completed: true
    stage_4_completed: true
  - round_number: 2
    analysis_mode: "standard"
    ...
```

### Circuit Breaker

From config: `limits.max_rounds: 100`

```
IF current_round > max_rounds:
    Notify user: "Circuit breaker: {max_rounds} rounds reached."
    Ask: "Force PRD generation with current information?" or "Continue?"
```

---

## User Pause Handling

Two EXIT pause points exist in this workflow:

### Research Pause (Stage 2)
- User exits to conduct offline research
- State: `waiting_for_user: true`, `pause_stage: 2`
- On re-invocation: orchestrator routes to Stage 2
- Stage 2 coordinator checks for research reports in `requirements/research/reports/`

### Question Response Pause (Stage 4)
- User exits to fill in QUESTIONS-{NNN}.md file
- State: `waiting_for_user: true`, `pause_stage: 4`
- On re-invocation: orchestrator routes to Stage 4
- Stage 4 coordinator checks for filled answers in the QUESTIONS file

### Resume Routing

```
ON REINVOCATION:
    READ state file
    IF waiting_for_user == true:
        stage = state.pause_stage
        CLEAR waiting_for_user
        DISPATCH stage coordinator (it will detect the user's input)
    ELSE IF current_stage < 6 AND phase_status != "completed":
        RESUME from current_stage
    ELSE:
        START fresh (Stage 1)
```

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
