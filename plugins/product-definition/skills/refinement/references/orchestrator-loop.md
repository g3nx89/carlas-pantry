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
    ELSE IF stage == 3 AND ANALYSIS_MODE in {complete, advanced}:
        ## Stage 3 Sub-Coordinator Split (F-016)
        DISPATCH 3A coordinator (ThinkDeep only -- reads stage-3-analysis-questions.md Part A)
        READ 3A summary, HANDLE status
        DISPATCH 3B coordinator (MPA only -- reads stage-3-analysis-questions.md Part B)
        READ 3B summary, HANDLE status
    ELSE IF stage == 3 AND ANALYSIS_MODE in {standard, rapid}:
        DISPATCH single coordinator (Part B only -- skips ThinkDeep)
        READ coordinator summary, HANDLE status
    ELSE:
        DISPATCH coordinator (see Coordinator Dispatch below)

    READ coordinator summary
    HANDLE summary status (see Summary Handling)
```

---

## Coordinator Dispatch

For stages 2-6, dispatch a coordinator subagent using the **per-stage dispatch profile** from config (`token_budgets.stage_dispatch_profiles`). Each stage loads ONLY the shared references it needs.

### Stage Dispatch Profiles

| Stage | Shared Refs | Config YAML | Extra Refs |
|-------|-------------|-------------|------------|
| 2 (Research) | checkpoint-protocol, error-handling | No | research-mcp-reference (if research MCP available) |
| 3 (Analysis) | checkpoint-protocol, error-handling | Yes | option-generation-reference |
| 4 (Response) | checkpoint-protocol, error-handling | Yes | consensus-call-pattern |
| 5 (Validation) | checkpoint-protocol, error-handling | Yes | consensus-call-pattern |
| 6 (Completion) | checkpoint-protocol | No | -- |

### Dispatch Profiles

Select the appropriate profile based on dispatch context. Each profile is self-contained.

#### Profile A: First-Round Dispatch (no reflection, no prior summaries)

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
- Entry type: {ENTRY_TYPE}
- Panel config: {PANEL_CONFIG_PATH}
- Research MCP available: {RESEARCH_MCP_AVAILABLE}

## Shared References
{SHARED_REFS_FOR_STAGE}

## State File (frontmatter only)
{YAML FRONTMATTER OF requirements/.requirements-state.local.md}

## Rules
- Do not interact with users directly. Use status: needs-user-input with flags.block_reason.
- Write summary to requirements/.stage-summaries/stage-{N}-summary.md per `references/summary-contract.md`.
- Update state file after completing work.
- Run self-verification checks before writing summary.
""")
```

#### Profile B: Subsequent-Round Dispatch (prior summaries, no reflection)

Same as Profile A, plus:

```
## Prior Stage Summaries
{IF current_round <= compaction.rounds_before_compaction:}
  {CONTENTS OF requirements/.stage-summaries/stage-*-summary.md}
{ELSE:}
  {CONTENTS OF requirements/.stage-summaries/rounds-digest.md}
  {CONTENTS OF current round stage summaries only}
```

#### Profile C: Reflection Dispatch (prior summaries + REFLECTION_CONTEXT)

Same as Profile B, plus:

```
## Reflection from Previous Round
{REFLECTION_CONTEXT}

## Prior Reflection Accountability
{REFLECTION_DIFF from cross-round reflection analysis}
```

### ENTRY_TYPE Variable

Set `ENTRY_TYPE` based on orchestrator state:
- `"re_entry_after_user_input"` -- when `waiting_for_user` was true and user has returned
- `"first_entry"` -- all other cases

This eliminates ambiguity for Stage 4 (present questions vs parse answers) and Stage 2 (research agenda vs synthesis).

### Variable Defaults

Every dispatch variable must have a defined fallback to prevent malformed coordinator prompts:

| Variable | Default | Rationale |
|----------|---------|-----------|
| `ENTRY_TYPE` | `"first_entry"` | Guards against orchestrator bugs; safe default |
| `PAL_AVAILABLE` | `false` | Assume unavailable if Stage 1 didn't detect; prevents PAL calls that would fail |
| `ST_AVAILABLE` | `false` | Assume unavailable; coordinators use internal reasoning as fallback |
| `REFLECTION_CONTEXT` | `""` (empty) | First round or non-RED re-entry; Stage 3 checks presence before using |
| `ROUND_NUMBER` | `1` | First invocation default |
| `ANALYSIS_MODE` | `"standard"` | Safest mode -- no MCP dependency |
| `PRD_MODE` | `"NEW"` | Default to new PRD creation |
| `PANEL_CONFIG_PATH` | `null` | null = rapid mode (single agent); otherwise path to `.panel-config.local.md` |
| `RESEARCH_MCP_AVAILABLE` | `false` | Assume unavailable; Stage 2 falls back to manual research |
| `TIMEOUT_MINUTES` | Per-stage from config `stage_dispatch_profiles` | Coordinators self-enforce soft timeout |

**Precedence rule:** State file values always override defaults. Apply defaults only when the variable has no value in state AND was not explicitly set by a prior stage.

**Rule:** If a variable is not set by the orchestrator at dispatch time, substitute the default from this table. Never pass `null` or empty strings for required variables.

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

## Quality Gate Protocol

**Full protocol:** `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/quality-gates.md`

After Stage 3 and Stage 5, the orchestrator performs structural validation (blocking) and quality checks (non-blocking). Load the quality-gates reference for detailed check procedures.

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

    ## STAGNATION CHECK (before generating reflection)
    IF current_round >= config -> scoring.stagnation.check_after_round (default: 3):
        READ validation scores from last 2 RED rounds
        IF score has NOT improved by >= config -> scoring.stagnation.min_improvement_points (default: 2) over last 2 RED rounds:
            Present user decision via AskUserQuestion:
            - "Force PRD generation with current information"
            - "Change analysis approach (try different mode or panel)"
            - "Continue with another round"
            IF user chooses "Force PRD": DISPATCH Stage 5 with flags.skip_validation = true
            IF user chooses "Change approach": ask for new mode, re-dispatch Stage 3
            IF user chooses "Continue": proceed to REFLEXION STEP below

    ## REFLEXION STEP -- generate reflection before re-dispatching Stage 3

    ### Prior Reflection Accountability (if round >= 3)
    IF prior reflection file exists at requirements/.stage-summaries/reflection-round-{N-1}.md:
        READ prior reflection recommendations
        FOR each recommendation:
            Classify as:
            - "addressed-improved": recommendation was followed AND score improved in that dimension
            - "addressed-no-improvement": recommendation was followed but dimension score unchanged
            - "not-addressed": recommendation was NOT followed in the latest round
        Build REFLECTION_DIFF table:
        | Recommendation | Status | Evidence |
        |---------------|--------|----------|
        | Focus on workflows | addressed-improved | workflow_coverage: 2 -> 3 |
        | Deeper persona options | not-addressed | target_users: 2 -> 2 |

        IF 2+ recommendations have status "not-addressed" for 2 consecutive rounds:
            ESCALATE: Include in REFLECTION_CONTEXT as "PERSISTENT BLIND SPOTS"
            Notify user: "These areas have not improved despite reflection: {list}"

    READ Stage 4 summary (gaps found, completion rate)
    READ Stage 5 summary (validation score, weak dimensions)
    READ prior round's Stage 3 summary (questions count, analysis mode)

    GENERATE REFLECTION_CONTEXT:
    """
    ## Round {previous_round} Reflection

    ### What We Tried
    - Analysis mode: {previous_analysis_mode}
    - Questions generated: {previous_questions_count}
    - Questions answered: {completion_rate}%

    ### Why It Wasn't Enough
    - Validation score: {Stage5.flags.validation_score}/20 (needed >= {conditional_threshold})
    - Weakest dimensions: {Stage5.flags.weak_dimensions}
    - Per-dimension scores: {Stage5.flags.dimension_scores}
    - Gaps identified: {Stage4.flags.gap_descriptions}
    - Persistent gaps (appeared in previous rounds too): {cross-round gap intersection}

    ### What To Do Differently
    - Focus question generation on these weak dimensions: {Stage5.flags.weak_dimensions}
    - These sub-problems remain unresolved: {unresolved from decomposition}
    - Avoid re-asking well-answered areas: {Stage5.flags.strong_dimensions}
    - Consider deeper options for: {areas where user chose "Other" or gave vague answers}
    """

    PERSIST REFLECTION_CONTEXT to: requirements/.stage-summaries/reflection-round-{N}.md
    LIMIT: config -> token_budgets.per_source.reflection_context (default: 1500 tokens)
    (Enables crash recovery -- if orchestrator crashes after generating reflection but
     before dispatching Stage 3, the reflection is recovered from this file on re-invocation)

    Notify user: "PRD not ready. Score: {score}/20. Generating more questions with reflection on gaps."
    Ask user for analysis mode for new round (via AskUserQuestion)
    DISPATCH Stage 3 (new round, with REFLECTION_CONTEXT in coordinator prompt)

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

### Prior Round Compaction

From config: `token_budgets.compaction.*`

```
IF current_round > compaction.rounds_before_compaction (default: 3):
    GENERATE rounds digest using the template below:
        READ all stage summaries from rounds 1 to (current_round - 1)
        SYNTHESIZE into the Rounds-Digest Template format
        WRITE to: requirements/.stage-summaries/rounds-digest.md
        LIMIT: config -> token_budgets.compaction.digest_max_lines (default: 100)

    In coordinator dispatch, use digest + current round summaries
    instead of all individual stage summaries
```

**Why:** Without compaction, accumulated summaries grow linearly (~150 lines per round). By round 5, prior summaries alone consume ~750 lines of coordinator context. Compaction keeps this under 100 lines regardless of round count.

#### Rounds-Digest Template

**Full template and rules:** See `quality-gates.md` -> "Rounds-Digest Template" section.

Summary: YAML frontmatter with `rounds_covered`, per-round table, cumulative user decisions, persistent gap tracker, and key insights. Max lines from config `token_budgets.compaction.digest_max_lines`.

### Circuit Breaker

From config: `limits.max_rounds` (default: 10)

```
IF current_round == 5:
    WARN user: "Round 5 of {max_rounds}. Consider forcing PRD generation if gaps are minor."

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
        # Check for persisted reflection context (crash recovery for RED loop)
        IF current_stage == 3 AND file exists requirements/.stage-summaries/reflection-round-{current_round}.md:
            LOAD REFLECTION_CONTEXT from that file
            DISPATCH Stage 3 with REFLECTION_CONTEXT
        ELSE:
            RESUME from current_stage
    ELSE:
        START fresh (Stage 1)
```

---

## Crash Recovery & State Migration

**Loaded on-demand.** Full procedures are in a separate reference file to keep the core dispatch loop lean.

**Load when:** A coordinator produces no summary file (crash recovery) OR state file has `schema_version: 1` (migration).

**Reference:** `@$CLAUDE_PLUGIN_ROOT/skills/refinement/references/recovery-migration.md`

### Quick Summary (for dispatch loop inline checks)

**Crash Recovery:** If summary file missing for stage N, check for artifacts. If found, reconstruct minimal summary with `flags.recovered: true`. If not found, ask user to retry or skip.

**State Migration:** If `schema_version == 1`, map `current_phase` to `current_stage` using the phase-to-stage mapping table in the reference file, then set `schema_version: 2`.
