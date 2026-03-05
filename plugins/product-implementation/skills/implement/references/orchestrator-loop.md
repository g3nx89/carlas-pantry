# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

1. **Read state**: Read `{FEATURE_DIR}/.implementation-state.local.md`. If `state.version < 3`, migrate (see Migration below).

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

   g. **Auto-Commit Phase**: Follow auto-commit dispatch procedure (`auto-commit-dispatch.md`) with `template_key=phase_complete`, `substitution_vars={feature_name=FEATURE_NAME, phase_name=current_phase_name}`, `skip_target=next phase`, `summary_field=append to commits_made`.

   h. Update `state.last_checkpoint`. Write state.

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

### Linear Mode (per_phase_review.enabled: false — backward compatible)

5L. **Iterate stages** (2 through 6): For each stage, execute steps 6L-8L. This restores the original behavior where S2 processes all phases, then S3/S4/S5 run once across the entire implementation.

6L. **Skip check**: If `state.stage_summaries[stage] != null`, skip (already done).

7L. **Dispatch**: `DISPATCH_COORDINATOR(stage=stage, phase_scope=null)`. Summary path: `stage-{N}-summary.md`.

8L. **Validate and handle**: `VALIDATE_AND_HANDLE("stage-{N}-summary.md", stage=stage, phase=null)`. Update `state.stage_summaries[stage]`. Set `state.current_stage = next_stage`.

### Shared: VALIDATE_AND_HANDLE

```
FUNCTION VALIDATE_AND_HANDLE(summary_path, stage, phase):
  summary_file = "{FEATURE_DIR}/.stage-summaries/{summary_path}"
  summary = READ(summary_file)

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
    Ask user the question from summary.flags.block_reason
    Write answer to "{FEATURE_DIR}/.stage-summaries/{summary_path_base}-user-input.md"
    Re-dispatch coordinator with continuation_mode=true
    Re-read summary

  # Handle failed
  IF summary.status == "failed":
    | Policy infrastructure action | Behavior |
    |------------------------------|----------|
    | `retry_then_continue` | Retry once; if still failed, skip and continue |
    | `retry_then_ask` | Retry once; if still failed, ask: retry / skip / abort |
    | *(no policy set)* | Ask: retry / skip / abort |
    IF user chooses "abort": RELEASE_LOCK and HALT
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

> **ADR:** Coordinator delegation was chosen over direct dispatch for context reduction and fault isolation.
> Full rationale: see `references/README.md` § Architecture Decision Records.
