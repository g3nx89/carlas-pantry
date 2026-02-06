# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

```
READ state file at {FEATURE_DIR}/.planning-state.local.md
IF state.version == 1 OR state.version is missing: MIGRATE to v2 (see Migration below)

READ config at $CLAUDE_PLUGIN_ROOT/config/planning-config.yaml
BUILD dispatch_table from SKILL.md Phase Dispatch Table

FOR phase IN [1, 2, 3, 4, 5, 6, 6b, 7, 8, 9]:
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
  IF summary.gate AND summary.gate.verdict == "RED" AND summary.gate.retries < 2:
    INCREMENT retry counter in state
    LOOP BACK to same phase (or to Phase 4 if Phase 6 RED, Phase 7 if Phase 8 RED)

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

  prompt = """
    You are coordinating Phase {phase}: {phase_name} of the feature planning workflow.

    ## Your Instructions
    Read and execute: $CLAUDE_PLUGIN_ROOT/skills/plan/references/{phase_file}

    ## Context
    Feature directory: {FEATURE_DIR}
    Analysis mode: {analysis_mode}
    Feature flags: {relevant_flags_and_values}

    ## Prior Phase Summaries (read these first)
    {for each summary in prior_summaries: {FEATURE_DIR}/.phase-summaries/{summary}}

    ## Output Contract
    1. Write artifacts to {FEATURE_DIR}/ as specified in your instructions
    2. Write phase summary to: {FEATURE_DIR}/.phase-summaries/phase-{phase}-summary.md
    3. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md
    4. Do NOT interact with the user. If input needed, set status: needs-user-input.
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
     test_coverage_completed (all null)
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
