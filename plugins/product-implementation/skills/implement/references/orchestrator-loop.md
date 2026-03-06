# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

1. **Read state**: Read `{FEATURE_DIR}/.implementation-state.local.md`. If `state.version < 3`, migrate (see Migration below).

1a. **Top-of-loop stall check** (ralph mode only): If `state.orchestrator.ralph_mode` is `true`:
    ```
    entry_fingerprint = HASH(state.current_stage, state.current_phase,
                             len(state.phases_completed), state.phase_stages)
    IF entry_fingerprint == state.orchestrator.ralph_last_fingerprint:
      state.orchestrator.ralph_stall_count += 1
      APPLY_GRADUATED_STALL_RESPONSE(state.orchestrator.ralph_stall_count)
    ELSE:
      state.orchestrator.ralph_stall_count = 0
      state.orchestrator.ralph_stall_level = 0
    state.orchestrator.ralph_last_fingerprint = entry_fingerprint
    WRITE_STATUS_FILE(state, "top-of-loop stall check")
    WRITE state
    ```
    This catches stalls where the orchestrator never reaches a coordinator dispatch (e.g., state file corruption, config error). The end-of-phase check (step 5i) updates the fingerprint again after progress is made.

2. **Read config**: Read `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`. Build `dispatch_table` from SKILL.md Stage Dispatch Table. Read `per_phase_review` section.

3. **Stage 1** (inline): If `state.stage_summaries["1"]` is null, execute Stage 1 inline per `stage-1-setup.md`. Write summary. Set `state.stage_summaries["1"] = path`. If already done, skip.

4. **Determine dispatch mode**: Read `per_phase_review.enabled` from config (default: `true`).
   - If `true` → execute **Phase Loop** (step 5)
   - If `false` → execute **Linear Mode** (step 5L)

### Phase Loop (default — per_phase_review.enabled: true)

5. **Phase Loop**: For each phase in `state.phases_remaining` (in order):

   a. Set `state.current_phase = phase`. Extract phase index N from phase name (e.g., "Phase 3: Integration" → N=3).

   b. **Stage 2** (per-phase): If `state.phase_stages[phase].s2` != `"completed"`:
      - Set `state.phase_stages[phase].s2 = "in_progress"`. Write state.
      - `DISPATCH_COORDINATOR(stage=2, phase_scope=phase)`
      - `VALIDATE_AND_HANDLE("phase-{N}-stage-2-summary.md", stage=2, phase=phase)`
      - Set `state.phase_stages[phase].s2 = "completed"`

   c. **Stage 3** (per-phase, conditional): If `per_phase_review.s3_per_phase` is `true` AND `state.phase_stages[phase].s3` != `"completed"`:
      - Set `state.phase_stages[phase].s3 = "in_progress"`. Write state.
      - `DISPATCH_COORDINATOR(stage=3, phase_scope=phase)`
      - `VALIDATE_AND_HANDLE("phase-{N}-stage-3-summary.md", stage=3, phase=phase)`
      - Set `state.phase_stages[phase].s3 = "completed"`

   d. **Stage 4** (per-phase, conditional): If `per_phase_review.s4_per_phase` is `true` AND `state.phase_stages[phase].s4` != `"completed"`:
      - Set `state.phase_stages[phase].s4 = "in_progress"`. Write state.
      - `DISPATCH_COORDINATOR(stage=4, phase_scope=phase)`
      - `VALIDATE_AND_HANDLE("phase-{N}-stage-4-summary.md", stage=4, phase=phase)`
      - If S4 review requests fixes → re-dispatch S2 for same phase (fix loop), then re-run S3+S4
      - Set `state.phase_stages[phase].s4 = "completed"`

   e. **Stage 5** (per-phase, conditional): If `per_phase_review.s5_per_phase` is `true` AND `state.phase_stages[phase].s5` != `"completed"`:
      - Set `state.phase_stages[phase].s5 = "in_progress"`. Write state.
      - `DISPATCH_COORDINATOR(stage=5, phase_scope=phase)`
      - `VALIDATE_AND_HANDLE("phase-{N}-stage-5-summary.md", stage=5, phase=phase)`
      - Set `state.phase_stages[phase].s5 = "completed"`

   f. Move phase from `phases_remaining` to `phases_completed`. Set `state.current_phase = null`.
      If `state.orchestrator.ralph_mode` is `true`: reset `ralph_same_error_count = 0`, `ralph_last_error = null` (phase success clears error accumulator).

   g. **Auto-Commit Phase**: Follow auto-commit dispatch procedure (`auto-commit-dispatch.md`) with `template_key=phase_complete`, `substitution_vars={feature_name=FEATURE_NAME, phase_name=current_phase_name}`, `skip_target=next phase`, `summary_field=append to commits_made`.

   h. Update `state.last_checkpoint`. Write state. If `state.orchestrator.ralph_mode` is `true`: `WRITE_STATUS_FILE(state, "phase {phase} checkpoint")`.

   i. **Stall Detection** (ralph mode only): If `state.orchestrator.ralph_mode` is `true` AND `config.ralph_loop.circuit_breaker` exists:
      ```
      current_fingerprint = HASH(state.current_stage, state.current_phase,
                                  len(state.phases_completed), state.phase_stages)

      IF current_fingerprint == state.orchestrator.ralph_last_fingerprint:
        state.orchestrator.ralph_stall_count += 1
        APPLY_GRADUATED_STALL_RESPONSE(state.orchestrator.ralph_stall_count)
      ELSE:
        state.orchestrator.ralph_stall_count = 0
        state.orchestrator.ralph_stall_level = 0

      state.orchestrator.ralph_last_fingerprint = current_fingerprint
      WRITE_STATUS_FILE(state, "end-of-phase stall check")
      WRITE state
      ```

6. **Final Passes** (after all phases complete):

   a. **Final Review Pass** (optional): If `per_phase_review.final_review_pass` is `true`:
      - `DISPATCH_COORDINATOR(stage=3, phase_scope=null)` → writes `final-stage-3-summary.md`
      - `VALIDATE_AND_HANDLE("final-stage-3-summary.md", stage=3, phase=null)`
      - `DISPATCH_COORDINATOR(stage=4, phase_scope=null)` → writes `final-stage-4-summary.md`
      - `VALIDATE_AND_HANDLE("final-stage-4-summary.md", stage=4, phase=null)`

   b. **Final Documentation Pass**: If `per_phase_review.final_docs_pass` is `true`:
      - `DISPATCH_COORDINATOR(stage=5, phase_scope=null)` → writes `final-stage-5-summary.md`
      - `VALIDATE_AND_HANDLE("final-stage-5-summary.md", stage=5, phase=null)`
      - Lock release happens inside Stage 5 coordinator (same as current behavior)

   c. **Stage 6** (retrospective): `DISPATCH_COORDINATOR(stage=6)`. Validate summary.

   d. **Ralph Completion Signal** (ralph mode only): If `state.orchestrator.ralph_mode` is `true` AND Stage 6 summary status is `"completed"`:
      - Output the completion promise tag so the ralph-loop Stop Hook detects it:
        ```
        <promise>{config.ralph_loop.completion_promise}</promise>
        ```
      - The Stop Hook will read this from the transcript and allow the session to exit

### Linear Mode (per_phase_review.enabled: false — backward compatible)

5L. **Iterate stages** (2 through 6): For each stage, execute steps 6L-8L. This restores the original behavior where S2 processes all phases, then S3/S4/S5 run once across the entire implementation.

6L. **Skip check**: If `state.stage_summaries[stage] != null`, skip (already done).

7L. **Dispatch**: `DISPATCH_COORDINATOR(stage=stage, phase_scope=null)`. Summary path: `stage-{N}-summary.md`.

8L. **Validate and handle**: `VALIDATE_AND_HANDLE("stage-{N}-summary.md", stage=stage, phase=null)`. Update `state.stage_summaries[stage]`. Set `state.current_stage = next_stage`.

8La. **Stall Detection** (linear mode, ralph mode only): If `state.orchestrator.ralph_mode` is `true` AND `config.ralph_loop.circuit_breaker` exists:
      ```
      current_fingerprint = HASH(state.current_stage, len(state.stage_summaries), state.orchestrator.coordinator_failures)
      # Same comparison logic as step 5i (fingerprint match → increment stall count → APPLY_GRADUATED_STALL_RESPONSE)
      WRITE_STATUS_FILE(state, "linear mode stage completion")
      ```

9L. **Ralph Completion Signal** (linear mode, ralph mode only): After Stage 6 completes, if `state.orchestrator.ralph_mode` is `true`, output `<promise>{config.ralph_loop.completion_promise}</promise>`.

### Shared: VALIDATE_AND_HANDLE

```
FUNCTION VALIDATE_AND_HANDLE(summary_path, stage, phase):
  summary_file = "{FEATURE_DIR}/.stage-summaries/{summary_path}"
  summary = READ(summary_file)

  # Output-decline detection (T2-7, ralph mode only)
  # Only compare within the same stage to avoid false positives (Stage 3 summaries are
  # naturally shorter than Stage 2 summaries). Tracks per-stage baseline.
  IF state.orchestrator.ralph_mode == true AND summary_file exists:
    current_length = LEN(summary)
    length_key = "stage_{stage}"  # e.g., "stage_2", "stage_3"
    previous_length = state.orchestrator.ralph_last_summary_lengths[length_key] OR null
    IF previous_length IS NOT NULL AND previous_length > 0:
      ratio = current_length / previous_length
      IF ratio < config.ralph_loop.circuit_breaker.output_decline_threshold:
        state.orchestrator.ralph_stall_count += 1
        LOG "[{timestamp}] Ralph output decline (stage {stage}): summary shrank from {previous_length} to {current_length} chars (ratio {ratio})"
    state.orchestrator.ralph_last_summary_lengths[length_key] = current_length

  # Validate required fields
  IF summary_file missing → CRASH_RECOVERY(stage, phase)
  IF validation fails → apply infrastructure failure handling per autonomy policy:
    | Policy infrastructure action | Behavior |
    |------------------------------|----------|
    | `retry_then_continue` | Retry stage once, then continue with degraded summary |
    | `retry_then_ask` | Retry once, then ask user: retry / continue / abort |
    | *(no policy set)* | Ask user: retry / continue / abort |

  # Cumulative failure check
  IF status=failed OR degraded:
    state.orchestrator.coordinator_failures += 1
    IF coordinator_failures >= config.orchestrator.max_coordinator_failures (default: 3):
      HALT: "Cumulative coordinator failures ({N}) exceeded threshold."

  # Handle needs-user-input
  IF summary.status == "needs-user-input":
    # Autonomy policy already attempted inside coordinator. This is a fallthrough.

    # --- Ralph Mode Guard ---
    # In ralph mode, no user is present. Auto-resolve ALL questions.
    IF state.orchestrator.ralph_mode == true:
      question = summary.flags.block_reason
      # Derive answer from question type using keyword matching on block_reason.
      # Categories are matched by checking if question contains any keyword from the set.
      # First match wins. Catchall ensures the loop never blocks.
      IF question MATCHES_ANY("validation", "check failed", "spec alignment", "coverage", "test count"):
        answer = "proceed"           # Stage 3 validation outcomes
      ELIF question MATCHES_ANY("review", "finding", "fix", "severity", "critical", "high"):
        answer = "fix"               # Stage 4 review findings — full_auto default; policy already resolved critical/high
      ELIF question MATCHES_ANY("documentation", "doc", "tech-writer", "incomplete"):
        answer = "complete"          # Stage 5 documentation decisions
      ELIF question MATCHES_ANY("infrastructure", "timeout", "unreachable", "CLI", "dispatch failed"):
        answer = "continue"          # Infrastructure failures — ralph will retry next iteration if needed
      ELSE:
        LOG warning: "Unhandled AskUserQuestion in ralph mode: {question}"
        answer = "continue"          # safe default — never block
      Write answer to "{FEATURE_DIR}/.stage-summaries/{summary_path_base}-user-input.md"
      LOG "[{timestamp}] [AUTO-ralph] Stage {state.current_stage} Phase {state.current_phase}: auto-resolved '{question}' -> '{answer}' (flags: {summary.flags})"
      Re-dispatch coordinator with continuation_mode=true
      Re-read summary
      CONTINUE  # skip the interactive path below
    # --- End Ralph Mode Guard ---

    Ask user the question from summary.flags.block_reason
    Write answer to "{FEATURE_DIR}/.stage-summaries/{summary_path_base}-user-input.md"
    Re-dispatch coordinator with continuation_mode=true
    Re-read summary

  # Handle failed
  IF summary.status == "failed":
    # --- Ralph Mode Rate Limit / Timeout Exemption (T2-8) ---
    IF state.orchestrator.ralph_mode == true:
      raw_error_lower = LOWERCASE(summary.flags.block_reason OR summary.summary OR "unknown error")
      rate_limit_patterns = config.ralph_loop.circuit_breaker.rate_limit_patterns
      timeout_patterns = config.ralph_loop.circuit_breaker.timeout_patterns
      IF raw_error_lower MATCHES_ANY(rate_limit_patterns) OR raw_error_lower MATCHES_ANY(timeout_patterns):
        state.orchestrator.ralph_rate_limit_count += 1
        tag = "[RATE-LIMIT]" IF MATCHES_ANY(rate_limit_patterns) ELSE "[TIMEOUT]"
        LOG "[{timestamp}] {tag} Rate limit/timeout detected — exempt from stall counting. Backing off {config.ralph_loop.circuit_breaker.rate_limit_backoff_seconds}s"
        WAIT config.ralph_loop.circuit_breaker.rate_limit_backoff_seconds
        RETRY stage once
        WRITE_STATUS_FILE(state, "rate limit backoff retry")
        WRITE state
        CONTINUE  # skip normal error-pattern tracking
    # --- End Rate Limit / Timeout Exemption ---

    # --- Ralph Mode Error-Pattern Tracking ---
    IF state.orchestrator.ralph_mode == true:
      # Normalize error: extract core error message, strip timestamps/paths/line numbers
      raw_error = summary.flags.block_reason OR summary.summary OR "unknown error"
      normalized_error = REGEX_REPLACE(raw_error, r'[\d]{4}-[\d]{2}-[\d]{2}[T\s][\d:]+[Z]?', '')  # strip timestamps
      normalized_error = REGEX_REPLACE(normalized_error, r'/[\w/\-\.]+/(\w+[\.\w]*)', '\1')      # strip directory paths, keep basename
      normalized_error = REGEX_REPLACE(normalized_error, r'line \d+', 'line <N>')                 # strip line numbers
      normalized_error = TRIM(normalized_error)

      IF normalized_error == state.orchestrator.ralph_last_error:
        state.orchestrator.ralph_same_error_count += 1
        IF ralph_same_error_count >= config.ralph_loop.circuit_breaker.same_error_threshold:
          LOG "[{timestamp}] Ralph same-error stall: {ralph_same_error_count} iterations with error: {normalized_error}"
          APPLY_GRADUATED_STALL_RESPONSE(ralph_same_error_count)
      ELSE:
        state.orchestrator.ralph_same_error_count = 1  # first occurrence of new error
      state.orchestrator.ralph_last_error = normalized_error
      WRITE state

      # In ralph mode: retry once, then continue (never ask, never abort)
      RETRY stage once
      IF retry succeeded AND config.ralph_loop.learnings.enabled:
        APPEND_LEARNING(category="error", learning="Stage {stage} Phase {phase}: failed with '{normalized_error}', succeeded on retry")
      IF still failed:
        LOG "[{timestamp}] [AUTO-ralph] Stage {stage} failed after retry — continuing with degraded summary"
        CONTINUE  # ralph loop will detect stall if this persists
    # --- End Ralph Mode Guard (failed) ---

    | Policy infrastructure action | Behavior |
    |------------------------------|----------|
    | `retry_then_continue` | Retry once; if still failed, skip and continue |
    | `retry_then_ask` | Retry once; if still failed, ask: retry / skip / abort |
    | *(no policy set)* | Ask: retry / skip / abort |
    IF user chooses "abort": RELEASE_LOCK and HALT

  # --- Ralph Mode Test Result Stall Detection (T2-9) ---
  # Runs AFTER the failed/needs-user-input handlers. Only fires when Stage 3 completes
  # (status != "failed") but still reports failing tests. Uses a dedicated counter
  # (ralph_test_stall_count) independent of ralph_same_error_count.
  IF state.orchestrator.ralph_mode == true AND stage == 3 AND summary.status != "failed":
    failing_tests = EXTRACT_FAILING_TEST_NAMES(summary)
    IF failing_tests IS NOT EMPTY:
      test_signature = JOIN(SORT(failing_tests), ",")
      IF test_signature == state.orchestrator.ralph_last_test_signature:
        state.orchestrator.ralph_test_stall_count += 1
        LOG "[{timestamp}] Ralph test-result stall: same {LEN(failing_tests)} test(s) failing for {ralph_test_stall_count} iterations"
        IF ralph_test_stall_count >= config.ralph_loop.circuit_breaker.same_error_threshold:
          APPLY_GRADUATED_STALL_RESPONSE(ralph_test_stall_count)
      ELSE:
        state.orchestrator.ralph_test_stall_count = 1  # new failure set
      state.orchestrator.ralph_last_test_signature = test_signature
    ELSE:
      # All tests passing — clear test signature and counter
      state.orchestrator.ralph_last_test_signature = null
      state.orchestrator.ralph_test_stall_count = 0
    WRITE state
  # --- End Test Result Stall Detection ---
```

## Coordinator Dispatch

```
FUNCTION DISPATCH_COORDINATOR(stage, phase_scope=null, continuation_mode=false):
  stage_file = dispatch_table[stage].file
  checkpoint = dispatch_table[stage].checkpoint

  # Determine summary path and prior summaries based on phase_scope
  IF phase_scope IS NOT NULL:
    phase_index = EXTRACT_INDEX(phase_scope)  # "Phase 3: Integration" → 3
    summary_path = "phase-{phase_index}-stage-{stage}-summary.md"
    # Per-phase prior summaries (phase-scoped chain)
    prior_summaries = ["stage-1-summary.md"]  # Always include Stage 1
    IF stage == 3: prior_summaries += ["phase-{phase_index}-stage-2-summary.md"]
    IF stage == 4: prior_summaries += ["phase-{phase_index}-stage-2-summary.md", "phase-{phase_index}-stage-3-summary.md"]
    IF stage == 5: prior_summaries += ["phase-{phase_index}-stage-3-summary.md", "phase-{phase_index}-stage-4-summary.md"]
  ELIF summary is for a final pass:
    summary_path = "final-stage-{stage}-summary.md"
    # Final pass reads all per-phase summaries for this stage
    prior_summaries = ["stage-1-summary.md"] + ALL "phase-*-stage-{stage-1}-summary.md" files
  ELSE:
    summary_path = "stage-{stage}-summary.md"
    prior_summaries = dispatch_table[stage].prior_summaries

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

  # Build phase scope block for coordinator prompt
  phase_scope_block = ""
  IF phase_scope IS NOT NULL:
    phase_scope_block = """
    ## Phase Scope
    This coordinator is scoped to a SINGLE PHASE: {phase_scope}
    Process ONLY tasks, files, and checks relevant to this phase.
    Write summary to: {FEATURE_DIR}/.stage-summaries/{summary_path}
    """

  prompt = """
    You are coordinating Stage {stage}: {stage_name} of the feature implementation workflow.

    ## Your Instructions
    Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/{stage_file}
    {IF continuation_mode: "This is a continuation after user input. Skip re-reading already-processed references. Read the user-input file and resume from where you left off."}

    {phase_scope_block}

    ## Context
    Feature name: {FEATURE_NAME}
    Feature directory: {FEATURE_DIR}
    Tasks file: {TASKS_FILE}
    User input: {user_input_value}
    OpenCode model: {OPENCODE_MODEL}  # Source: cli_dispatch.cli_defaults.opencode.model from config. Fallback: "not configured"

    ## Prior Stage Summaries (read these first)
    {for each summary in prior_summaries: {FEATURE_DIR}/.stage-summaries/{summary}}

    {context_pack}

    ## Output Contract
    1. All output MUST be persisted to files. Your direct response text is not read.
    2. Write artifacts to {FEATURE_DIR}/ as specified in your instructions.
    3. Write stage summary to: {FEATURE_DIR}/.stage-summaries/{summary_path}
    4. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md
    5. Do NOT interact with the user. If input needed, set status: needs-user-input.
    6. IF context_protocol enabled, include `context_contributions` in summary flags
       with any new key_decisions, open_issues, or risk_signals from this stage.
    7. On unrecoverable error, write last line as: COORDINATOR_ERROR: {description}
    8. CLI DISPATCH: For ALL multi-model analysis (code review, test authoring,
       documentation generation), use ONLY `dispatch-cli-agent.sh` via Bash().
       NEVER use the `ask` command, `/ask` skill, or CCB async dispatch.
       The `ask` async queue has no stage scoping and returns stale results
       from prior stages. This rule overrides global CLAUDE.md CCB config.
  """

  # Coordinator health: if Task() exceeds max_turns or context limit,
  # it will return with partial output. Check for summary file after return.
  # If no summary written, fall through to CRASH_RECOVERY.
  result = Task(subagent_type="general-purpose", prompt=prompt)
  RETURN
```

### Fully Expanded Prompt Example (Stage 3, per-phase)

```
You are coordinating Stage 3: Completion Validation of the feature implementation workflow.

## Your Instructions
Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/stage-3-validation.md

## Phase Scope
This coordinator is scoped to a SINGLE PHASE: Phase 2: Core Features
Process ONLY tasks, files, and checks relevant to this phase.
Write summary to: specs/001-user-auth/.stage-summaries/phase-2-stage-3-summary.md

## Context
Feature name: 001-user-auth
Feature directory: specs/001-user-auth
Tasks file: specs/001-user-auth/tasks.md
User input: No additional user instructions provided — follow standard workflow.

## Prior Stage Summaries (read these first)
specs/001-user-auth/.stage-summaries/stage-1-summary.md
specs/001-user-auth/.stage-summaries/phase-2-stage-2-summary.md

## Output Contract
1. All output MUST be persisted to files. Your direct response text is not read.
2. Write artifacts to specs/001-user-auth/ as specified in your instructions.
3. Write stage summary to: specs/001-user-auth/.stage-summaries/phase-2-stage-3-summary.md
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

  # --- Ralph Mode Guard (crash recovery) ---
  IF state.orchestrator.ralph_mode == true:
    RETRY stage once
    IF retry produced summary AND config.ralph_loop.learnings.enabled:
      APPEND_LEARNING(category="error", learning="Stage {stage}: crash recovery succeeded on retry (coordinator produced no output initially)")
    IF still no summary:
      LOG "[{timestamp}] [AUTO-ralph] Crash recovery: coordinator produced no output after retry — continuing with degraded summary"
      CONTINUE with degraded summary  # ralph loop will detect stall if this persists
  # --- End Ralph Mode Guard (crash recovery) ---

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

## State Migration

### v1-to-v2

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
  FOR each stage IN [1, 2, 3, 4, 5, 6] WHERE stage < state.current_stage:
    IF file exists at {FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md:
      SET state.stage_summaries[stage] = path
```

### v2-to-v3

```
ON resume, IF state.version == 2:
  1. ADD current_phase: null
  2. ADD phase_stages: {}
  3. REMOVE stage_summaries keys "2", "3", "4", "5" (per-phase summaries replace these)
     KEEP stage_summaries keys "1" and "6" only
  4. SET version: 3
  5. WRITE updated state
  6. LOG "Migrated state file from v2 to v3"

  # Reconstruct phase_stages from phases_completed:
  FOR each phase IN state.phases_completed:
    phase_index = EXTRACT_INDEX(phase)
    state.phase_stages[phase] = {}
    # Check which per-phase summaries exist on disk
    FOR each stage IN [2, 3, 4, 5]:
      IF file exists at {FEATURE_DIR}/.stage-summaries/phase-{phase_index}-stage-{stage}-summary.md:
        state.phase_stages[phase]["s{stage}"] = "completed"
      ELIF stage == 2:
        # v2 had a single stage-2-summary.md for ALL phases — mark all completed phases as s2=completed
        state.phase_stages[phase].s2 = "completed"
    # Note: v2 sessions ran S3/S4/S5 once for all phases, not per-phase.
    # Per-phase S3/S4/S5 summaries won't exist. This is OK — phases are already completed.

  # If there's a current stage 2 in progress with some phases done:
  IF state.current_stage == 2 AND len(state.phases_completed) > 0:
    # Phase loop will resume from first phase in phases_remaining
    LOG "v2→v3: Phase loop will resume from first remaining phase"
```

Non-breaking: all existing fields are preserved. Orchestrator continues from last checkpoint. v1 sessions migrate through v2 to v3 (chain: v1→v2→v3).

## Lock Release

```
FUNCTION RELEASE_LOCK:
  SET state.lock.acquired = false
  UPDATE state.last_checkpoint
  WRITE state
  LOG "Lock released"
```

Called at:
- Final Stage 5 completion (normal path — after all phases or final docs pass) — Stage 6 runs post-lock-release (read-only analysis)
- Per-phase Stage 5 does NOT release the lock (only the final S5 pass does)
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

## Helper: Identify Stuck Task

```
FUNCTION IDENTIFY_STUCK_TASK(phase_stages):
  # Returns the description of the first incomplete task in the current phase.
  # Used by Level 3 graduated stall to annotate the stuck task in tasks.md.
  phase = state.current_phase
  phase_section = FIND_SECTION(READ("{FEATURE_DIR}/tasks.md"), phase)

  # Find the first task line not marked [X] (completed)
  FOR EACH line IN phase_section:
    IF line MATCHES r'^\s*- \[[ ]\]':   # unchecked task checkbox
      RETURN TRIM(line)
  # If all tasks are checked, return the phase name itself (stall is in stage logic, not tasks)
  RETURN phase
```

## Helper: Extract Failing Test Names

```
FUNCTION EXTRACT_FAILING_TEST_NAMES(summary):
  # Extracts failing test names from a Stage 3 validation summary.
  # Stage 3 summaries include a "failing_tests" list in flags when tests fail.
  # Falls back to parsing the summary body for test name patterns.
  IF summary.flags.failing_tests IS NOT NULL:
    RETURN summary.flags.failing_tests  # already a list

  # Fallback: scan summary body for lines matching common test failure patterns
  failing = []
  FOR EACH line IN summary.body:
    IF line MATCHES r'(FAIL|FAILED|✗|✘|×)\s+(.+)':
      failing += [MATCH_GROUP(2)]
    ELIF line MATCHES r'^\s*-\s+(test_\w+|it\s+".+"|\w+Test\.\w+).*(?:FAIL|ERROR)':
      failing += [MATCH_GROUP(1)]
  RETURN failing
```

## Graduated Stall Response

```
FUNCTION APPLY_GRADUATED_STALL_RESPONSE(stall_count):
  # Determine response level based on stall_count and config thresholds.
  # Backward compatible: stall_action "write_blockers" or "halt" still work as before.
  stall_action = config.ralph_loop.circuit_breaker.stall_action
  threshold = config.ralph_loop.circuit_breaker.no_progress_threshold

  # Legacy mode: non-graduated stall actions
  IF stall_action == "write_blockers":
    IF stall_count >= threshold:
      WRITE blockers file to {FEATURE_DIR}/.implementation-blockers.local.md
      LOG "[{timestamp}] Ralph stall: {stall_count} iterations — writing blockers (legacy mode)"
    RETURN
  IF stall_action == "halt":
    IF stall_count >= threshold:
      WRITE blockers file
      LOG "[{timestamp}] Ralph stall: {stall_count} iterations — halting (legacy mode)"
      RELEASE_LOCK and HALT
    RETURN

  # Graduated mode (stall_action == "graduated")
  offsets = config.ralph_loop.circuit_breaker.graduated_levels
  level_2_trigger = threshold + offsets.level_2_offset   # default: 3+0 = 3
  level_3_trigger = threshold + offsets.level_3_offset   # default: 3+2 = 5
  level_4_trigger = threshold + offsets.level_4_offset   # default: 3+4 = 7

  # Levels are CHAINED: higher levels always perform lower-level actions first.
  # This ensures blockers file and plan annotations are always produced even on jumps.

  # --- Level 1+ (Warning): always fires when stall_count >= 1 ---
  state.orchestrator.ralph_stall_level = 1
  LOG "[{timestamp}] Ralph graduated stall Level 1 (WARNING): {stall_count} iterations — no progress"

  # --- Level 2+ (Blockers): write diagnostic file ---
  IF stall_count >= level_2_trigger:
    state.orchestrator.ralph_stall_level = 2
    WRITE blockers file to {FEATURE_DIR}/.implementation-blockers.local.md
    LOG "[{timestamp}] Ralph graduated stall Level 2 (BLOCKERS): {stall_count} iterations"

  # --- Level 3+ (Scope Reduce): annotate stuck tasks and skip phase ---
  IF stall_count >= level_3_trigger:
    state.orchestrator.ralph_stall_level = 3
    LOG "[{timestamp}] Ralph graduated stall Level 3 (SCOPE REDUCE): {stall_count} iterations"
    IF config.ralph_loop.plan_mutability.enabled:
      stuck_phase = state.current_phase
      stuck_task = IDENTIFY_STUCK_TASK(state.phase_stages[stuck_phase])
      annotation = config.ralph_loop.plan_mutability.annotation_format
      annotation = annotation.replace("{reason}", "Stalled after {stall_count} iterations at stage {state.current_stage}")

      # Annotate task in tasks.md (HTML comment preserves rendering)
      APPEND annotation to the stuck task line in {FEATURE_DIR}/tasks.md

      # Record in state
      state.ralph_blocked_tasks += [{
        phase: stuck_phase,
        task: stuck_task,
        stall_count: stall_count,
        timestamp: NOW_ISO8601()
      }]

      # Skip to next phase if configured
      IF config.ralph_loop.plan_mutability.skip_blocked_phases:
        MOVE stuck_phase from phases_remaining to phases_completed with status "blocked"
        state.current_phase = null
        state.orchestrator.ralph_stall_count = 0  # reset for next phase
        state.orchestrator.ralph_stall_level = 0
        LOG "[{timestamp}] Skipped blocked phase: {stuck_phase}"

  # --- Level 4 (Halt): terminal ---
  IF stall_count >= level_4_trigger:
    state.orchestrator.ralph_stall_level = 4
    LOG "[{timestamp}] Ralph graduated stall Level 4 (HALT): {stall_count} iterations"
    RELEASE_LOCK and HALT

  WRITE state
```

## Iteration Status File

```
FUNCTION WRITE_STATUS_FILE(state, last_action):
  # Write a monitoring-friendly status file after each stage/phase transition.
  # Only active in ralph mode when config.ralph_loop.status_file.enabled is true.
  IF NOT state.orchestrator.ralph_mode: RETURN
  IF NOT config.ralph_loop.status_file.enabled: RETURN

  filename = config.ralph_loop.status_file.filename  # default: ".implementation-ralph-status.local.md"
  status_path = "{FEATURE_DIR}/{filename}"

  phases_completed_count = LEN(state.phases_completed)
  phases_remaining_count = LEN(state.phases_remaining)
  total_phases = phases_completed_count + phases_remaining_count

  # Determine test status from latest Stage 3 summary (if available)
  tests_status = "unknown"
  IF state.orchestrator.ralph_last_test_signature IS NOT NULL:
    tests_status = "failing"
  ELIF state.current_stage > 3 OR phases_completed_count > 0:
    tests_status = "passing"

  WRITE to status_path:
    ---
    timestamp: "{NOW_ISO8601()}"
    current_stage: {state.current_stage}
    current_phase: "{state.current_phase}"
    phases_completed: {phases_completed_count}
    phases_remaining: {phases_remaining_count}
    total_phases: {total_phases}
    stall_count: {state.orchestrator.ralph_stall_count}
    stall_level: {state.orchestrator.ralph_stall_level}
    same_error_count: {state.orchestrator.ralph_same_error_count}
    rate_limit_count: {state.orchestrator.ralph_rate_limit_count}
    last_action: "{last_action}"
    tests_status: "{tests_status}"
    blocked_tasks_count: {LEN(state.ralph_blocked_tasks)}
    coordinator_failures: {state.orchestrator.coordinator_failures}
    ---
```

**Call sites:** After phase checkpoint update (step 5h), after linear mode stage completion (step 8L), after top-of-loop stall check (step 1a).

## Cross-Iteration Learning

```
FUNCTION APPEND_LEARNING(category, learning):
  # Appends a learning entry to the cross-iteration learnings file.
  # Only called when config.ralph_loop.learnings.enabled is true.
  learnings_file = "{FEATURE_DIR}/.implementation-learnings.local.md"
  max_entries = config.ralph_loop.learnings.max_entries  # default: 20
  timestamp = NOW_ISO8601()

  IF learnings_file does not exist:
    WRITE learnings_file from template ($CLAUDE_PLUGIN_ROOT/templates/ralph-learnings-template.local.md)

  READ learnings_file
  current_count = frontmatter.entry_count

  # FIFO truncation: if at max, remove oldest entry (first ### block after frontmatter)
  IF current_count >= max_entries:
    REMOVE oldest entry (first ### heading block)
    current_count -= 1

  APPEND to file body:
    ### [{timestamp}] {category}
    {learning}

  UPDATE frontmatter.entry_count = current_count + 1
  WRITE learnings_file
```

> **ADR:** Coordinator delegation was chosen over direct dispatch for context reduction and fault isolation.
> Full rationale: see `references/README.md` § Architecture Decision Records.
