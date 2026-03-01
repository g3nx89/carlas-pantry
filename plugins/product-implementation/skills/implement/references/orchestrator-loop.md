# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

1. **Read state**: Read `{FEATURE_DIR}/.implementation-state.local.md`. If `state.version == 1` or missing, migrate to v2 (see Migration below).

2. **Read config**: Read `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`. Build `dispatch_table` from SKILL.md Stage Dispatch Table.

3. **Iterate stages** (1 through 6): For each stage, execute steps 4-10.

4. **Skip check**: If `state.stage_summaries[stage] != null`, skip (already done). Proceed to next stage.

5. **Dispatch**: Use the delegation type to determine action:

   | Delegation | Action |
   |-----------|--------|
   | `inline` | Execute stage logic directly (Stage 1 only). Write summary to `{FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md`. |
   | `coordinator` | Call `DISPATCH_COORDINATOR(stage)` (see below). |

6. **Validate summary**: Read `{FEATURE_DIR}/.stage-summaries/stage-{stage}-summary.md`. Check required fields: `stage`, `status`, `checkpoint`, `artifacts_written`, `summary`.
   - If file missing → `CRASH_RECOVERY(stage)`
   - If validation fails → apply infrastructure failure handling per autonomy policy:

     | Policy infrastructure action | Behavior |
     |------------------------------|----------|
     | `retry_then_continue` | Retry stage once, then continue with degraded summary |
     | `retry_then_ask` | Retry stage once, then ask user: retry / continue / abort |
     | *(no policy set)* | Ask user: retry / continue / abort |

   - **Cumulative failure check**: After setting `status=failed` or degraded summary, increment `state.orchestrator.coordinator_failures`. If `coordinator_failures >= config.orchestrator.max_coordinator_failures` (default: 3), halt with diagnostic: `"Cumulative coordinator failures ({N}) exceeded threshold. Review system health before continuing."`

7. **Handle needs-user-input**: If `summary.status == "needs-user-input"`:
   - When autonomy policy is active, most needs-user-input cases are resolved INSIDE the coordinator. If a coordinator still sets this status, it means (a) the policy doesn't cover this case, or (b) auto-resolution failed. In both cases, the orchestrator falls through to asking the user.
   - Stage 4 applies an auto-decision matrix internally (see `stage-4-quality-review.md` Section 4.4). Low-severity-only findings are auto-accepted — the orchestrator sees `status=completed`, not `needs-user-input`.
   - Ask user the question from `summary.flags.block_reason`.
   - Write answer to `{FEATURE_DIR}/.stage-summaries/stage-{stage}-user-input.md`.
   - Re-dispatch coordinator (coordinator reads user-input file).
   - Re-read summary.

8. **Handle failed**: If `summary.status == "failed"`:

   | Policy infrastructure action | Behavior |
   |------------------------------|----------|
   | `retry_then_continue` | Retry once; if still failed, skip stage and continue |
   | `retry_then_ask` | Retry once; if still failed, ask user: retry / skip / abort |
   | *(no policy set)* | Ask user: retry / skip / abort |

   If user chooses "abort": `RELEASE_LOCK` and halt.

9. **Update state**: Set `state.stage_summaries[stage] = summary_path`. Set `state.current_stage = next_stage`. Update checkpoint timestamp. Write state.

10. **Continue**: Proceed to next stage (step 3).

## Coordinator Dispatch

```
FUNCTION DISPATCH_COORDINATOR(stage, continuation_mode=false):
  stage_file = dispatch_table[stage].file
  prior_summaries = dispatch_table[stage].prior_summaries
  checkpoint = dispatch_table[stage].checkpoint

  # Context Pack (if enabled)
  context_pack = ""
  IF config.context_protocol.enabled:
    decisions = []
    open_issues = []
    risk_signals = []

    FOR EACH summary_path IN prior_summaries:
      summary = READ("{FEATURE_DIR}/.stage-summaries/{summary_path}")
      contributions = summary.flags.context_contributions
      IF contributions IS NOT NULL:
        decisions += contributions.key_decisions OR []
        open_issues += contributions.open_issues OR []
        risk_signals += contributions.risk_signals OR []

    # Sort by priority using config-driven strategies, truncate to budget
    FOR EACH category IN [decisions, open_issues, risk_signals]:
      strategy = config.context_protocol.truncation_strategies[category]
      budget = config.context_protocol.category_budgets[category]
      items[category] = APPLY_STRATEGY(items[category], strategy, budget)
      # Strategies: "keep_high_confidence_first" → SORT by confidence DESC
      #             "keep_highest_severity_first" → SORT by severity DESC

    IF any non-empty:
      context_pack = FORMAT as "## Accumulated Context Pack" with 3 subsections

    # Post-formatting validation: approximate total token count
    total_chars = len(context_pack)
    approx_tokens = total_chars / 4
    IF approx_tokens > config.context_protocol.total_budget_tokens:
      # Truncate lowest-priority items until within budget
      WHILE approx_tokens > config.context_protocol.total_budget_tokens:
        REMOVE last item from lowest-priority category (risk_signals → open_issues → decisions)
        REFORMAT context_pack
        approx_tokens = len(context_pack) / 4

  user_input_value = user_input OR "No additional user instructions provided — follow standard workflow."

  prompt = """
    You are coordinating Stage {stage}: {stage_name} of the feature implementation workflow.

    ## Your Instructions
    Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/{stage_file}
    {IF continuation_mode: "This is a continuation after user input. Skip re-reading already-processed references. Read the user-input file and resume from where you left off."}

    ## Context
    Feature name: {FEATURE_NAME}
    Feature directory: {FEATURE_DIR}
    Tasks file: {TASKS_FILE}
    User input: {user_input_value}

    ## Prior Stage Summaries (read these first)
    {for each summary in prior_summaries: {FEATURE_DIR}/.stage-summaries/{summary}}

    {context_pack}

    ## Output Contract
    1. All output MUST be persisted to files. Your direct response text is not read.
    2. Write artifacts to {FEATURE_DIR}/ as specified in your instructions.
    3. Write stage summary to: {FEATURE_DIR}/.stage-summaries/stage-{stage}-summary.md
    4. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md
    5. Do NOT interact with the user. If input needed, set status: needs-user-input.
    6. IF context_protocol enabled, include `context_contributions` in summary flags
       with any new key_decisions, open_issues, or risk_signals from this stage.
    7. On unrecoverable error, write last line as: COORDINATOR_ERROR: {description}
  """

  # Coordinator health: if Task() exceeds max_turns or context limit,
  # it will return with partial output. Check for summary file after return.
  # If no summary written, fall through to CRASH_RECOVERY.
  result = Task(subagent_type="general-purpose", prompt=prompt)
  RETURN
```

### Fully Expanded Prompt Example (Stage 3)

```
You are coordinating Stage 3: Completion Validation of the feature implementation workflow.

## Your Instructions
Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-3-validation.md

## Context
Feature name: 001-user-auth
Feature directory: specs/001-user-auth
Tasks file: specs/001-user-auth/tasks.md
User input: No additional user instructions provided — follow standard workflow.

## Prior Stage Summaries (read these first)
specs/001-user-auth/.stage-summaries/stage-1-summary.md
specs/001-user-auth/.stage-summaries/stage-2-summary.md

## Output Contract
1. All output MUST be persisted to files. Your direct response text is not read.
2. Write artifacts to specs/001-user-auth/ as specified in your instructions.
3. Write stage summary to: specs/001-user-auth/.stage-summaries/stage-3-summary.md
4. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md
5. Do NOT interact with the user. If input needed, set status: needs-user-input.
6. IF context_protocol enabled, include `context_contributions` in summary flags.
7. On unrecoverable error, write last line as: COORDINATOR_ERROR: {description}
```

## Crash Recovery

```
FUNCTION CRASH_RECOVERY(stage):
  # Coordinator completed but no summary written
  artifacts = dispatch_table[stage].artifacts_written

  IF key artifacts exist on disk (e.g., tasks.md has new [X] marks for Stage 2):
    RECONSTRUCT minimal summary from artifact state, set degraded=true
    SET state.orchestrator.summaries_reconstructed += 1
  ELSE:
    SET status=failed, block_reason="Coordinator produced no output"

  # Track cumulative failures
  SET state.orchestrator.coordinator_failures += 1

  policy = READ autonomy_policy from Stage 1 summary (or null if Stage 1 not yet complete)
  infra_action = LOOKUP policy infrastructure action from config (autonomy_policy.levels.{policy}.infrastructure)
  IF infra_action == "retry_then_continue": RETRY stage once; if still no summary, continue with degraded summary
  ELIF infra_action == "retry_then_ask": RETRY stage once; if still no summary, ASK user: Retry / Continue / Abort
  ELSE: ASK user: Retry stage / Continue with degraded summary / Abort
  IF user chooses "Abort": RELEASE_LOCK and HALT
```

## User Interaction Relay

Coordinators NEVER interact with users directly. All user interaction flows through the orchestrator:

1. Coordinator writes summary with `status: needs-user-input` and `flags.block_reason` explaining what is needed
2. Orchestrator reads summary, presents question to user via `AskUserQuestion`
3. Orchestrator writes user's answer to `{FEATURE_DIR}/.stage-summaries/stage-{N}-user-input.md`
4. Orchestrator re-dispatches same coordinator with `continuation_mode: true` (coordinator reads the user-input file, skips re-reading already-processed references, and resumes)

### User-Input File Format

```yaml
---
stage: "{N}"
question: "The original question from block_reason"
answer: "User's response"
timestamp: "{ISO_8601}"
---
```

## v1-to-v2 State Migration

```
ON resume, IF state.version == 1 OR state.version is missing:
  1. ADD stage_summaries section (all values = null)
  2. ADD orchestrator section:
     version: 2
     delegation_model: "lean_orchestrator"
     coordinator_failures: 0
     summaries_reconstructed: 0
  3. SET version: 2
  4. WRITE updated state
  5. LOG "Migrated state file from v1 to v2"

  # Reconstruct stage_summaries from existing checkpoint data:
  # Use current_stage to infer which stages completed (stages < current_stage)
  FOR each stage IN [1, 2, 3, 4, 5, 6] WHERE stage < state.current_stage:
    IF file exists at {FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md:
      SET state.stage_summaries[stage] = path
    # (v1 sessions won't have summaries, but artifacts still exist - OK to continue)
```

Non-breaking: all existing v1 fields are preserved. Orchestrator continues from last checkpoint.

## Lock Release

```
FUNCTION RELEASE_LOCK:
  SET state.lock.acquired = false
  UPDATE state.last_checkpoint
  WRITE state
  LOG "Lock released"
```

Called at:
- Stage 5 completion (normal path) — Stage 6 runs post-lock-release (read-only analysis)
- User chooses "abort" at any crash recovery or failure prompt
- User chooses "stop here" at validation (Stage 3)

## Summary Validation

Required fields in every stage summary YAML:
- `stage` (string)
- `status` (completed | needs-user-input | failed)
- `checkpoint` (string matching expected checkpoint name)
- `artifacts_written` (array, may be empty)
- `summary` (non-empty string)

If validation fails, mark summary as degraded and ask user whether to retry, continue, or abort.

## Late Agent Notifications

If a background coordinator `Task()` returns AFTER the orchestrator has already moved past that stage (e.g., via crash recovery + user "Continue"):

1. **Ignore late output** — do not re-read summaries for completed stages
2. **Log the event** — append to Implementation Log: `[{timestamp}] Late notification from Stage {N} coordinator — ignored (stage already resolved)`
3. **Do not overwrite** — the existing summary (reconstructed or user-resolved) takes precedence

The forward-only dispatch loop (`stage_summaries[stage] != null` -> SKIP) naturally handles this. Dismiss late notifications with a single-line acknowledgment to minimize context waste.

> **ADR:** Coordinator delegation was chosen over direct dispatch for context reduction and fault isolation.
> Full rationale: see `references/README.md` § Architecture Decision Records.
