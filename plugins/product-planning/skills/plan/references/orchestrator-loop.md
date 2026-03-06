# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

```
READ state file at {FEATURE_DIR}/.planning-state.local.md
IF state.version == 1 OR state.version is missing: MIGRATE to v2 (see Migration v1→v2 below)
IF state.version == 2: MIGRATE to v3 (see Migration v2→v3 below)

READ config at $CLAUDE_PLUGIN_ROOT/config/planning-config.yaml
BUILD dispatch_table from SKILL.md Phase Dispatch Table

# Pending Escalation Resume
# See deep-reasoning-dispatch-pattern.md § Resume Handling for full escalation resume logic.
IF state.deep_reasoning AND state.deep_reasoning.pending_escalation:
  HANDLE_PENDING_ESCALATION(state)  # delegated to deep-reasoning-dispatch-pattern.md

# Pending Agents Resume (context compaction resilience — ISSUE-04/05)
# After context compaction, the orchestrator may have lost track of running agents.
# Check pending_agents in state before re-dispatching to avoid duplicate work.
IF state.pending_agents is not empty:
  RESOLVE_PENDING_AGENTS(state, config)  # see function below

FOR phase IN [1, 2, 3, 4, 5, 6, 6b, 7, 8, 8b, 9, 10]:
  IF phase IN state.completed_phases: SKIP (already done)
  IF phase requires feature_flag AND flag disabled in config: SKIP
  IF phase requires analysis_mode AND current mode not in phase.modes: SKIP

  delegation = dispatch_table[phase].delegation

  IF delegation == "inline":
    EXECUTE phase logic directly (only Phase 1)
    WRITE summary to {FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md
  ELIF delegation == "conditional":
    IF analysis_mode IN [standard, rapid]:
      EXECUTE phase logic inline
      WRITE summary
    ELSE:
      DISPATCH_COORDINATOR(phase)
  ELIF delegation == "coordinator":
    IF phase == "8" AND dispatch_table["8b"].eligible(state):
      # Phases 8 and 8b run concurrently — both are coordinator dispatches
      PARALLEL [
        DISPATCH_COORDINATOR("8"),
        DISPATCH_COORDINATOR("8b")
      ]
      # Process both summaries before continuing
    ELSE:
      DISPATCH_COORDINATOR(phase)

  # Read and validate summary
  summary_path = {FEATURE_DIR}/.phase-summaries/phase-{phase}-summary.md
  IF NOT file_exists(summary_path): CRASH_RECOVERY(phase)

  summary = READ(summary_path)
  VALIDATE summary has required fields: [phase, status, checkpoint, artifacts_written, summary]
  IF validation fails: mark degraded, ask user: retry / continue / abort

  # Handle summary status
  IF summary.status == "needs-user-input":
    SAFE_ASK_USER(summary.flags.block_reason, summary.flags.options or [])
    WRITE answer to {FEATURE_DIR}/.phase-summaries/phase-{phase}-user-input.md
    RE-DISPATCH_COORDINATOR(phase)  # coordinator reads user-input file
    RE-READ summary

  IF summary.status == "failed":
    ASK user: retry / skip / abort

  # Handle gate failures (RED) — see Gate Failure Decision Table below
  IF summary.gate AND summary.gate.verdict == "RED":
    HANDLE_GATE_FAILURE(phase, summary.gate)

  # Post-phase: security deep dive after Phase 6b
  # Delegated: see deep-reasoning-dispatch-pattern.md with ESCALATION_TYPE = security_deep_dive
  IF phase == "6b" AND summary.status == "completed":
    CHECK_SECURITY_DEEP_DIVE(summary, config)  # triggers if critical_count >= threshold

  # Post-phase: update requirements digest after Phase 3 (consolidates spec + user clarifications)
  IF phase == "3" AND summary.status == "completed" AND file_exists({FEATURE_DIR}/requirements-anchor.md):
    state.requirements_digest = EXTRACT_DIGEST(READ({FEATURE_DIR}/requirements-anchor.md), max_tokens=config.requirements_context.digest_max_tokens)

  # Update state
  ADD phase to state.completed_phases
  SET state.phase_summaries[phase] = summary_path
  SET state.current_phase = next_phase
  UPDATE checkpoint timestamp

  # Append human-readable log entry (ISSUE-08)
  APPEND to state markdown body:
    """
    ### Phase {phase}: {dispatch_table[phase].phase_name} ({date})
    - Outcome: {summary.status}
    - Key: {first 2 lines of summary.summary}
    - Artifacts: {summary.artifacts_written}
    """

  WRITE state
```

## Coordinator Dispatch

```
FUNCTION DISPATCH_COORDINATOR(phase):
  phase_file = dispatch_table[phase].file
  prior_summaries = dispatch_table[phase].prior_summaries
  checkpoint = dispatch_table[phase].checkpoint

  # --- Track pending agent in state (context resume resilience) ---
  APPEND to state.pending_agents:
    phase: {phase}
    dispatched_at: NOW_ISO()
    expected_artifacts: dispatch_table[phase].artifacts_written + [".phase-summaries/phase-{phase}-summary.md"]
  WRITE state  # persist BEFORE dispatch so context compaction can see it

  # --- CLI Verified Commands (cross-phase propagation — ISSUE-10) ---
  cli_section = ""
  IF state.cli.verified_commands AND any values are not null:
    cli_section = """
    ## CLI Verified Commands (from Phase 1 smoke test)
    When dispatching CLIs, set CLI_CMD_OVERRIDE env var to use these instead of script defaults:
    {FOR each cli, cmd IN state.cli.verified_commands WHERE cmd is not null:
      "- {cli}: `{cmd}`"}
    """

  # --- S6: Context Pack Builder (a6_context_protocol) ---
  IF config.feature_flags.a6_context_protocol.enabled:
    accumulated_decisions = []
    accumulated_questions = []
    accumulated_risks = []

    FOR EACH summary_path IN prior_summaries:
      summary = READ(summary_path)
      IF summary.key_decisions:
        accumulated_decisions += summary.key_decisions
      IF summary.open_questions:
        accumulated_questions += summary.open_questions
      IF summary.risks_identified:
        accumulated_risks += summary.risks_identified

    # Truncate per category to stay within budget (config.state.context_protocol.context_pack.category_budgets)
    # Strategies: decisions=keep_high_confidence_first, questions=keep_high_priority_first, risks=keep_high_severity_first
    context_pack = TRUNCATE_PER_CATEGORY(accumulated_decisions, accumulated_questions, accumulated_risks, budgets)

    context_section = """
    ## Accumulated Context (from prior phases)

    ### Key Decisions (do not contradict HIGH-confidence without justification)
    {for each d in context_pack.decisions: "- [{d.id}] {d.decision} (confidence: {d.confidence})"}

    ### Open Questions (resolve if your analysis provides answers)
    {for each q in context_pack.questions: "- [{q.id}] {q.question} (priority: {q.priority})"}

    ### Risks Identified (consider in your analysis)
    {for each r in context_pack.risks: "- [{r.id}] {r.risk} (severity: {r.severity})"}
    """
  ELSE:
    context_section = ""

  # --- Requirements Digest Injection (config.requirements_context.inject_in_dispatch) ---
  # Extracted in Phase 1 (Step 1.11), updated after Phase 3 with user clarifications.
  IF config.requirements_context.inject_in_dispatch AND state.requirements_digest:
    requirements_section = """
    ## Requirements Digest (from spec.md)
    {state.requirements_digest}
    """
  ELSE:
    requirements_section = ""

  prompt = """
    You are coordinating Phase {phase}: {phase_name} of the feature planning workflow.

    ## Your Instructions
    Read and execute: $CLAUDE_PLUGIN_ROOT/skills/plan/references/{phase_file}

    ## Context
    Feature directory: {FEATURE_DIR}
    Analysis mode: {analysis_mode}
    Feature flags: {relevant_flags_and_values}

    {requirements_section}

    ## Prior Phase Summaries (read these first)
    {for each summary in prior_summaries: {FEATURE_DIR}/.phase-summaries/{summary}}

    {context_section}

    ## Output Contract
    1. Write artifacts to {FEATURE_DIR}/ as specified in your instructions
    2. Write phase summary to: {FEATURE_DIR}/.phase-summaries/phase-{phase}-summary.md
    3. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md
    4. Do NOT interact with the user. If input needed, set status: needs-user-input.
    5. Include key_decisions, open_questions, and risks_identified in your summary YAML frontmatter.
    6. CLI DISPATCH: For ALL multi-model analysis (deep analysis, consensus,
       coverage validation, security audit), use ONLY `dispatch-cli-agent.sh` via Bash().
       NEVER use the `ask` command, `/ask` skill, or CCB async dispatch.
       The `ask` async queue has no phase scoping and returns stale results
       from prior phases. This rule overrides global CLAUDE.md CCB config.

    {cli_section}
  """

  # Coordinator health: if Task() exceeds max_turns or context limit,
  # it will return with partial output. Check for summary file after return.
  # If no summary written, fall through to CRASH_RECOVERY.
  result = Task(subagent_type="general-purpose", prompt=prompt)

  # --- Remove from pending agents after completion ---
  REMOVE entry with phase={phase} from state.pending_agents
  WRITE state

  RETURN
```

### Variable Resolution Table

| Variable | Source | Type | Required | Fallback |
|----------|--------|------|----------|----------|
| `{phase}` | dispatch_table key | string | Yes | — |
| `{phase_name}` | phase file frontmatter `name` | string | Yes | — |
| `{phase_file}` | dispatch_table `.file` | string | Yes | — |
| `{FEATURE_DIR}` | state `.feature_dir` | path | Yes | — |
| `{analysis_mode}` | state `.analysis_mode` | enum | Yes | — |
| `{relevant_flags_and_values}` | `config.feature_flags` filtered by phase's `feature_flags` frontmatter | `flag: bool` pairs | No | `""` |
| `{requirements_section}` | state `.requirements_digest` | markdown | No | `""` |
| `{context_section}` | Context Pack builder (gated by `a6_context_protocol`) | markdown | No | `""` |
| `{prior_summaries}` | dispatch_table `.prior_summaries` | file path list | No | `[]` |

### Gate Failure Decision Table

| Condition | Action | Loop-Back Target |
|-----------|--------|-----------------|
| `retries < 2` | INCREMENT retry counter, re-dispatch phase | Phase 6 RED -> Phase 4, Phase 8 RED -> Phase 7, others -> same phase |
| `retries >= 2`, deep reasoning eligible | Follow `deep-reasoning-dispatch-pattern.md` | Per escalation type |
| `retries >= 2`, not eligible | ASK user: retry / skip / abort | — |

> **Why Phase 6 RED loops to Phase 4, not Phase 5:** Phase 5 (ThinkDeep) analyzes the *existing* architecture. If the architecture itself is flawed (Phase 6 RED), re-analyzing the same flawed design is unproductive. Looping to Phase 4 forces a fresh architecture design that Phase 5 can then analyze.

**Mandatory field for all escalations:**
```
escalation_rationale: "{gate} failed {retries}x. Scores: {scores}. Failing dims: {dims}. Selected: {type} because {reason}."
```

## Summary Validation

Required fields in every phase summary YAML:
- `phase` (string)
- `status` (completed | needs-user-input | failed | skipped)
- `checkpoint` (string matching expected checkpoint name)
- `artifacts_written` (array, may be empty)
- `summary` (non-empty string)

If validation fails, mark summary as degraded and ask user whether to retry, continue, or abort.

> **Lock protocol:** Orchestrator-level locking is deferred. Current implementation uses phase-level locks: Phase 1 acquires `.planning.lock` after precondition checks, Phase 9 releases it at completion. See `phase-9-completion.md` for lock lifecycle details.

## On-Demand: Crash Recovery

```
FUNCTION CRASH_RECOVERY(phase):
  # Coordinator completed but no summary written
  artifacts = dispatch_table[phase].artifacts_written
  IF ALL artifacts exist on disk:
    RECONSTRUCT minimal summary from artifact contents, set degraded=true
    SET state.orchestrator.summaries_reconstructed += 1
  ELSE:
    SET status=failed, block_reason="Coordinator produced no output"
  ASK user: Retry phase / Continue with degraded summary / Abort
```

## User Interaction Relay

Coordinators NEVER interact with users directly. All user interaction flows through the orchestrator:

1. Coordinator writes summary with `status: needs-user-input` and `block_reason` explaining what is needed
2. Orchestrator reads summary, presents question to user via `AskUserQuestion`
3. Orchestrator writes user's answer to `{FEATURE_DIR}/.phase-summaries/phase-{N}-user-input.md`
4. Orchestrator re-dispatches same coordinator (coordinator reads the user-input file and continues)

### Post-Phase-9 Menu Handlers

After Phase 9 completes, the orchestrator presents a completion menu (gated by `a5_post_planning_menu`). Handlers execute in orchestrator context (NOT coordinator).

See `phase-9-completion.md` Step 9.13 for the definitive menu options and handler implementations. The six options are: **Review**, **Expert**, **Simplify**, **GitHub**, **Commit**, **Quit**. The orchestrator relays the user's choice and executes the corresponding handler from that file.

### Post-Phase-9 to Phase-10 Sequencing

Phase 10 (Retrospective) runs after Phase 9 fully resolves — including after the
`a5_post_planning_menu` round-trip completes. Phase 10 runs post-lock (released in
Phase 9 Step 9.12) and requires no lock operations.

## On-Demand: Circuit Breaker Pattern

Provides a generic retry-with-escalation mechanism used by multiple strategies (S8, S9, S13).

```
FUNCTION CIRCUIT_BREAKER(context_name, action, max_failures, escalation_action):
  failure_count = 0
  WHILE failure_count < max_failures:
    result = EXECUTE(action)
    IF result.success: RETURN result
    failure_count += 1
    LOG: "Circuit breaker '{context_name}': attempt {failure_count}/{max_failures} failed"
  LOG: "Circuit breaker '{context_name}': max failures reached — escalating"
  RETURN EXECUTE(escalation_action)
```

**Application table:**

| Context | Strategy | Max Failures | Escalation Action |
|---------|----------|-------------|-------------------|
| `specify_gate` | S8 (Phase 3) | `config.circuit_breaker.specify_gate.max_iterations` (3) | Set `flags.low_specify_score: true`, proceed |
| `expert_review` | S9 (Phase 6b) | `config.circuit_breaker.expert_review.max_iterations` (2) | Present findings to user with override option |
| `mpa_convergence` | S2 (Phase 4/7) | `config.circuit_breaker.convergence.max_rounds` (2) | Accept low convergence, flag for user |
| `gate_retry` | Existing | 2 (hardcoded) | Deep reasoning escalation or user choice |

## Safe User Interaction

Utility function for all orchestrator-level user prompts. Validates non-empty responses
and provides graceful fallback to text-based questions. Use for all `AskUserQuestion` calls
in the orchestrator — especially irreversible decisions (mode, team, architecture selection).

```
FUNCTION SAFE_ASK_USER(question, options, max_retries=2, confirm_irreversible=false):
  FOR attempt IN [1..max_retries]:
    response = AskUserQuestion(question, options)

    # Guard 1: Empty response (race condition with SessionStart hooks — ISSUE-01)
    IF response is empty OR response == "." OR response matches /^User has answered.*:\s*\.?$/:
      LOG: "SAFE_ASK_USER: Empty response (attempt {attempt}/{max_retries})"
      IF attempt == max_retries:
        # Fallback: present as numbered text and parse user's text response
        DISPLAY: "The selection widget didn't work. Please type the number of your choice:"
        FOR i, opt IN enumerate(options):
          DISPLAY: "  {i+1}. {opt.label}" + (IF opt.description: " — {opt.description}" ELSE "")
        text_response = WAIT for user text message
        response = PARSE number from text_response → map to options[number - 1].label
        IF parse fails:
          # Try matching option label directly from text
          response = MATCH text_response against options.labels (case-insensitive)
      ELSE:
        CONTINUE

    # Guard 2: Response matches a known option (if options provided)
    IF options is not empty AND response NOT IN [opt.label for opt in options]:
      LOG: "SAFE_ASK_USER: Unrecognized response '{response}' — re-asking"
      IF attempt < max_retries:
        CONTINUE

    # Guard 3: Confirmation for irreversible decisions
    IF confirm_irreversible AND response is valid:
      confirm = AskUserQuestion(
        "Confirm: **{response}**. This cannot be changed later. Proceed?",
        [{label: "Yes, proceed"}, {label: "Change selection"}]
      )
      IF confirm contains "Change":
        CONTINUE  # Re-ask the original question

    RETURN response

  # Should not reach here — last attempt always returns via fallback
  ERROR: "SAFE_ASK_USER: Failed after {max_retries} attempts"
```

## Pending Agents Resume

Called on workflow start when `state.pending_agents` is not empty (context resume after compaction).
Prevents duplicate dispatch of agents that may have completed or are still running.

```
FUNCTION RESOLVE_PENDING_AGENTS(state, config):
  timeout_minutes = config.cli_integration.pending_agent_timeout_minutes  # default: 30
  check_interval = config.cli_integration.pending_agent_check_interval_seconds  # default: 60

  FOR each pending IN state.pending_agents:
    # Check if expected artifacts exist (agent may have finished during context compaction)
    all_exist = true
    FOR each artifact IN pending.expected_artifacts:
      path = {FEATURE_DIR}/{artifact}
      IF NOT file_exists(path) OR file_is_empty(path):
        all_exist = false
        BREAK

    IF all_exist:
      LOG: "Phase {pending.phase} completed during context break — processing summary"
      # Process the summary normally (validate, check gates, etc.)
      summary_path = {FEATURE_DIR}/.phase-summaries/phase-{pending.phase}-summary.md
      summary = READ(summary_path)
      ADD pending.phase to state.completed_phases
      SET state.phase_summaries[pending.phase] = summary_path

      # Re-read artifacts for definitive metrics (ISSUE-09)
      # Artifact counts in summary may be stale if duplicate agents overwrote files
      IF summary has metrics (test_count, task_count, etc.):
        # Count actual artifacts on disk for this phase
        actual_counts = {}
        FOR each artifact_path IN dispatch_table[pending.phase].artifacts_written:
          IF artifact_path ends with "/":  # directory — count files inside
            actual_counts[artifact_path] = COUNT files in {FEATURE_DIR}/{artifact_path}
          ELSE:  # single file — count sections/entries (grep for ## or | ID pattern)
            actual_counts[artifact_path] = COUNT matching sections in {FEATURE_DIR}/{artifact_path}
        IF actual_counts != summary.metrics:
          LOG: "Reconciled metrics: summary said {summary.metrics}, actual is {actual_counts}"
          UPDATE state with actual_counts
          SET state.orchestrator.duplicate_dispatches_detected += 1

      REMOVE pending from state.pending_agents
      WRITE state
      CONTINUE

    # Artifacts don't exist — agent either timed out or never finished.
    # No WAIT cycle: context compaction already implies significant elapsed time.
    # If artifacts aren't on disk now, re-dispatching is cheaper than blocking.
    age_minutes = (NOW() - pending.dispatched_at) / 60
    IF age_minutes > timeout_minutes:
      LOG: "Phase {pending.phase} agent timed out ({age_minutes} min > {timeout_minutes} min) — will re-dispatch"
    ELSE:
      LOG: "Phase {pending.phase} artifacts missing after context resume ({age_minutes} min elapsed) — will re-dispatch"
    REMOVE pending from state.pending_agents
    WRITE state
    # Phase will be re-dispatched by the normal dispatch loop (not in completed_phases)
```

## On-Demand: v1-to-v2 State Migration

```
ON resume, IF state.version == 1 OR state.version is missing:
  1. ADD phase_summaries section (all values = null)
  2. ADD orchestrator section: { version: 2, delegation_model: "lean_orchestrator", coordinator_failures: 0, summaries_reconstructed: 0 }
  3. ADD missing timestamps: expert_review_completed, test_strategy_completed, test_coverage_completed, asset_consolidation_completed (all null)
  4. SET version: 2, WRITE state, LOG "Migrated v1 to v2"
  5. Reconstruct phase_summaries from existing checkpoint data (v1 sessions may lack summaries — OK)
  6. IF retrospective_completed_at is absent: ADD null (Phase 10 forward-compat)
```

Non-breaking: all existing v1 fields are preserved.

## On-Demand: v2-to-v3 State Migration

```
ON resume, IF state.version == 2:
  1. ADD pending_agents: [] (if not present)
  2. ADD cli.verified_commands: { gemini: null, codex: null, opencode: null } (if not present)
  3. ADD cli.capabilities.opencode: null (if not present — v2 only had gemini/codex)
  4. ADD cli.dispatch_infrastructure.timeout_cmd: null (if not present)
  5. ADD cli.consecutive_failures: 0 (if not present)
  6. ADD orchestrator.duplicate_dispatches_detected: 0 (if not present)
  7. SET version: 3, WRITE state, LOG "Migrated v2 to v3"
```

Non-breaking: all existing v2 fields are preserved. New fields enable context resume
resilience (pending_agents), cross-phase CLI fix propagation (verified_commands), and
duplicate dispatch detection (duplicate_dispatches_detected).

## On-Demand: ADR — Delegation vs Inline Loading

**Chosen:** Coordinator delegation via `Task(subagent_type="general-purpose")`

**Alternative considered:** On-demand inline loading — orchestrator reads and executes each phase file directly, dropping context between phases. This achieves the same context reduction (336-838 lines per phase) without delegation overhead.

**Why delegation was chosen:**
- Fault isolation: coordinator crash does not crash orchestrator
- Enables future parallelism (e.g., Phase 7 QA agents could use different model tiers)
- Clean separation via summary contract enforces explicit inter-phase communication

**Trade-offs accepted:**
- 5-15s latency per coordinator dispatch (~40-120s cumulative)
- User interaction relay doubles dispatch cost for interactive phases
- Summary-based communication is supplementary (coordinators also read full artifacts)

**Simplification trigger:** If coordination overhead becomes problematic, consider migrating to inline loading for non-interactive phases (2, 5, 6, 6b, 7, 8) while keeping delegation for interactive phases (4, 9).
