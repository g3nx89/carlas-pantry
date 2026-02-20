# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

```
READ state file at {FEATURE_DIR}/.planning-state.local.md
IF state.version == 1 OR state.version is missing: MIGRATE to v2 (see Migration below)

READ config at $CLAUDE_PLUGIN_ROOT/config/planning-config.yaml
BUILD dispatch_table from SKILL.md Phase Dispatch Table

# Check for pending deep reasoning escalation (resume case)
IF state.deep_reasoning AND state.deep_reasoning.pending_escalation:
  pending = state.deep_reasoning.pending_escalation
  ASK user via AskUserQuestion:
    header: "Pending Deep Reasoning Escalation"
    question: "A deep reasoning escalation was started for Phase {pending.phase}
      ({pending.type}) but no response was received.
      The prompt is saved at: {FEATURE_DIR}/{pending.prompt_file}"
    options:
      - label: "Provide the response now"
        description: "I have the deep reasoning model's response ready"
      - label: "Skip this escalation"
        description: "Continue the workflow without the escalation response"

  IF user provides response:
    # Follow Step D-F from deep-reasoning-dispatch-pattern.md
    INGEST response → WRITE to file → UPDATE state → RE-DISPATCH pending.phase
  ELSE:
    CLEAR state.deep_reasoning.pending_escalation
    WRITE state
    LOG: "Pending escalation cleared — continuing normal flow"

FOR phase IN [1, 2, 3, 4, 5, 6, 6b, 7, 8, 8b, 9]:
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
    DISPATCH_COORDINATOR(phase)

  # Read and validate summary
  summary_path = {FEATURE_DIR}/.phase-summaries/phase-{phase}-summary.md
  IF NOT file_exists(summary_path): CRASH_RECOVERY(phase)

  summary = READ(summary_path)
  VALIDATE summary has required fields: [phase, status, checkpoint, artifacts_written, summary]
  IF validation fails: mark degraded, ask user: retry / continue / abort

  # Handle summary status
  IF summary.status == "needs-user-input":
    ASK user the question from summary.flags.block_reason
    WRITE answer to {FEATURE_DIR}/.phase-summaries/phase-{phase}-user-input.md
    RE-DISPATCH_COORDINATOR(phase)  # coordinator reads user-input file
    RE-READ summary

  IF summary.status == "failed":
    ASK user: retry / skip / abort

  # Handle gate failures (RED)
  IF summary.gate AND summary.gate.verdict == "RED":
    IF summary.gate.retries < 2:
      INCREMENT retry counter in state
      LOOP BACK to same phase (or to Phase 4 if Phase 6 RED, Phase 7 if Phase 8 RED)

    ELSE:
      # 2 retries exhausted — check deep reasoning escalation eligibility
      # Reference: $CLAUDE_PLUGIN_ROOT/skills/plan/references/deep-reasoning-dispatch-pattern.md
      dr_config = config.deep_reasoning_escalation
      dr_state = state.deep_reasoning OR { escalations: [], pending_escalation: null }
      escalations_for_phase = dr_state.escalations.count(e => e.phase == phase)
      total_escalations = dr_state.escalations.length

      IF dr_config.circular_failure_recovery.enabled
         AND analysis_mode in dr_config.circular_failure_recovery.modes
         AND escalations_for_phase < dr_config.limits.max_escalations_per_phase
         AND total_escalations < dr_config.limits.max_escalations_per_session:

        # Determine escalation type (specific beats generic)
        IF phase == "6" AND dr_config.architecture_wall_breaker.enabled:
          escalation_type = "architecture_wall"
          escalation_flag = "architecture_wall_breaker"
          template = "architecture_wall"
          target_phase = "4"  # Loop back to Phase 4
        ELIF phase in ["4", "7"]
             AND state.deep_reasoning.algorithm_detected
             AND summary.flags.algorithm_difficulty == true
             AND dr_config.abstract_algorithm_detection.enabled
             AND analysis_mode in dr_config.abstract_algorithm_detection.modes:
          escalation_type = "algorithm_escalation"
          escalation_flag = "abstract_algorithm_detection"
          template = "algorithm_escalation"
          target_phase = phase  # Re-dispatch same phase
        ELSE:
          escalation_type = "circular_failure"
          escalation_flag = "circular_failure_recovery"
          template = "circular_failure"
          target_phase = redirect_target(phase)  # same phase or loop-back target

        # Execute deep reasoning dispatch pattern (Steps A-F)
        DEEP_REASONING_DISPATCH(
          ESCALATION_TYPE: escalation_type,
          ESCALATION_FLAG: escalation_flag,
          PHASE: phase,
          TEMPLATE: template,
          CONTEXT_SOURCES: [summary files + failing artifacts for this phase],
          GATE_HISTORY: {
            retries: summary.gate.retries,
            scores: [retry_1_score, retry_2_score],
            failing_dimensions: summary.gate.failing_dimensions or [],
            feedback: [retry_1_feedback, retry_2_feedback]
          },
          SPECIFIC_FOCUS: summary.gate.lowest_dimension or "overall quality"
        )

        IF user accepted escalation AND response received:
          # Re-dispatch with deep reasoning context (Step F)
          RE-DISPATCH_COORDINATOR(target_phase)
          # Continue to summary read/validation for the re-dispatched phase
        ELSE:
          # User declined — fall through to existing behavior
          ASK user: retry / skip / abort

      ELSE:
        # Deep reasoning not available or limits exceeded — existing behavior
        ASK user: retry / skip / abort

  # Post-phase deep reasoning checks (non-gate triggers)
  # Security Deep Dive: check after Phase 6b completes
  IF phase == "6b" AND summary.status == "completed":
    dr_config = config.deep_reasoning_escalation
    critical_count = summary.flags.critical_security_count OR 0

    IF dr_config.security_deep_dive.enabled
       AND analysis_mode in dr_config.security_deep_dive.modes
       AND critical_count >= dr_config.security_deep_dive.trigger.min_critical_findings:

      LOG: "Security deep dive trigger: {critical_count} CRITICAL findings"
      DEEP_REASONING_DISPATCH(
        ESCALATION_TYPE: "security_deep_dive",
        ESCALATION_FLAG: "security_deep_dive",
        PHASE: "6b",
        TEMPLATE: "security_deep_dive",
        CONTEXT_SOURCES: ["analysis/expert-review.md", "analysis/cli-security-report.md", "design.md"],
        GATE_HISTORY: null,
        SPECIFIC_FOCUS: "CRITICAL severity security findings requiring CVE-level analysis"
      )

      IF user accepted AND response received:
        # Append to expert review (do NOT re-dispatch Phase 6b)
        APPEND deep reasoning response summary to {FEATURE_DIR}/analysis/expert-review.md
        UPDATE phase-6b-summary.md: flags.deep_reasoning_supplement = true
      # Continue to next phase regardless

  # Post-phase: update requirements digest after Phase 3
  # Phase 3 produces requirements-anchor.md which consolidates spec + user clarifications.
  # Update the requirements_digest in state so subsequent dispatches use the enriched version.
  IF phase == "3" AND summary.status == "completed":
    IF file_exists({FEATURE_DIR}/requirements-anchor.md):
      # Re-extract digest from enriched source (budget: config.requirements_context.digest_max_tokens)
      anchor = READ({FEATURE_DIR}/requirements-anchor.md)
      state.requirements_digest = EXTRACT_DIGEST(anchor, max_tokens=config.requirements_context.digest_max_tokens)
      LOG: "Requirements digest updated from requirements-anchor.md (post-Phase 3)"

  # Update state
  ADD phase to state.completed_phases
  SET state.phase_summaries[phase] = summary_path
  SET state.current_phase = next_phase
  UPDATE checkpoint timestamp
  WRITE state
```

## Coordinator Dispatch

```
FUNCTION DISPATCH_COORDINATOR(phase):
  phase_file = dispatch_table[phase].file
  prior_summaries = dispatch_table[phase].prior_summaries
  checkpoint = dispatch_table[phase].checkpoint

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

    # Truncate per category to stay within budget
    budgets = config.state.context_protocol.context_pack.category_budgets
    #   decisions: 200 tokens, questions: 150 tokens, risks: 150 tokens
    context_pack = TRUNCATE_PER_CATEGORY(
      decisions=accumulated_decisions,
      questions=accumulated_questions,
      risks=accumulated_risks,
      decision_budget=budgets.decisions,     # 200
      question_budget=budgets.questions,     # 150
      risk_budget=budgets.risks,             # 150
      decision_strategy="keep_high_confidence_first",
      question_strategy="keep_high_priority_first",
      risk_strategy="keep_high_severity_first"
    )

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

  # --- Requirements Digest Injection ---
  # Inject the requirements digest extracted in Phase 1 (Step 1.6c) into every dispatch.
  # This ensures every coordinator has baseline visibility into the original requirements,
  # even if the phase file doesn't list spec.md in artifacts_read.
  # After Phase 3, the digest is updated with user clarifications if requirements-anchor.md exists.
  # Gated by config toggle: config.requirements_context.inject_in_dispatch (default: true)
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
  """

  # Coordinator health: if Task() exceeds max_turns or context limit,
  # it will return with partial output. Check for summary file after return.
  # If no summary written, fall through to CRASH_RECOVERY.
  result = Task(subagent_type="general-purpose", prompt=prompt)
  RETURN
```

## Crash Recovery

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

## Circuit Breaker Pattern

Provides a generic retry-with-escalation mechanism used by multiple strategies (S8, S9, S13).

```
FUNCTION CIRCUIT_BREAKER(context_name, action, max_failures, escalation_action):
  """
  Generic circuit breaker for iterative improvement loops.

  Parameters:
    context_name: Identifier for this circuit breaker instance (e.g., "specify_gate", "expert_review")
    action: The callable action to attempt (e.g., re-score, re-dispatch)
    max_failures: Maximum attempts before escalating (from config.circuit_breaker)
    escalation_action: What to do when max_failures exceeded
  """

  failure_count = 0

  WHILE failure_count < max_failures:
    result = EXECUTE(action)

    IF result.success:
      RETURN result

    failure_count += 1
    LOG: "Circuit breaker '{context_name}': attempt {failure_count}/{max_failures} failed"

  # Max failures reached — escalate
  LOG: "Circuit breaker '{context_name}': max failures ({max_failures}) reached — escalating"
  RETURN EXECUTE(escalation_action)
```

**Application Table:**

| Context | Strategy | Max Failures | Escalation Action |
|---------|----------|-------------|-------------------|
| `specify_gate` | S8 (Phase 3) | `config.circuit_breaker.specify_gate.max_iterations` (3) | Set `flags.low_specify_score: true`, proceed |
| `expert_review` | S9 (Phase 6b) | `config.circuit_breaker.expert_review.max_iterations` (2) | Present findings to user with override option |
| `mpa_convergence` | S2 (Phase 4/7) | `config.circuit_breaker.convergence.max_rounds` (2) | Accept low convergence, flag for user |
| `gate_retry` | Existing | 2 (hardcoded) | Deep reasoning escalation or user choice |

## v1-to-v2 State Migration

```
ON resume, IF state.version == 1 OR state.version is missing:
  1. ADD phase_summaries section (all values = null)
  2. ADD orchestrator section:
     version: 2
     delegation_model: "lean_orchestrator"
     coordinator_failures: 0
     summaries_reconstructed: 0
  3. ADD missing timestamps: expert_review_completed, test_strategy_completed,
     test_coverage_completed, asset_consolidation_completed (all null)
  4. SET version: 2
  5. WRITE updated state
  6. LOG "Migrated state file from v1 to v2"

  # Reconstruct phase_summaries from existing checkpoint data:
  FOR each phase in state.completed_phases:
    IF file exists at {FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md:
      SET state.phase_summaries[phase] = path
    # (v1 sessions won't have summaries, but artifacts still exist - OK to continue)
```

Non-breaking: all existing v1 fields are preserved. Orchestrator continues from last checkpoint.

## Summary Validation

Required fields in every phase summary YAML:
- `phase` (string)
- `status` (completed | needs-user-input | failed | skipped)
- `checkpoint` (string matching expected checkpoint name)
- `artifacts_written` (array, may be empty)
- `summary` (non-empty string)

If validation fails, mark summary as degraded and ask user whether to retry, continue, or abort.

## Architecture Decision Record: Delegation vs Inline Loading

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
