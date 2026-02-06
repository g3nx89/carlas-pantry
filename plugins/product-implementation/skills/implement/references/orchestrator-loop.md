# Orchestrator Dispatch Loop and Recovery

> This file is read by the orchestrator (SKILL.md) at workflow start. It contains the
> dispatch loop, error recovery, state migration logic, and user interaction relay protocol.

## Dispatch Loop

```
READ state file at {FEATURE_DIR}/.implementation-state.local.md
IF state.version == 1 OR state.version is missing: MIGRATE to v2 (see Migration below)

READ config at $CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml
BUILD dispatch_table from SKILL.md Stage Dispatch Table

FOR stage IN [1, 2, 3, 4, 5]:
  IF state.stage_summaries[stage] != null: SKIP (already done)

  delegation = dispatch_table[stage].delegation

  IF delegation == "inline":
    EXECUTE stage logic directly (only Stage 1)
    WRITE summary to {FEATURE_DIR}/.stage-summaries/stage-{N}-summary.md
  ELIF delegation == "coordinator":
    DISPATCH_COORDINATOR(stage)

  # Read and validate summary
  summary_path = {FEATURE_DIR}/.stage-summaries/stage-{stage}-summary.md
  IF NOT file_exists(summary_path): CRASH_RECOVERY(stage)

  summary = READ(summary_path)
  VALIDATE summary has required fields: [stage, status, checkpoint, artifacts_written, summary]
  IF validation fails: mark degraded, ask user: retry / continue / abort

  # Handle summary status
  IF summary.status == "needs-user-input":
    ASK user the question from summary.flags.block_reason
    WRITE answer to {FEATURE_DIR}/.stage-summaries/stage-{stage}-user-input.md
    RE-DISPATCH_COORDINATOR(stage)  # coordinator reads user-input file
    RE-READ summary

  IF summary.status == "failed":
    ASK user: retry / skip / abort
    IF user chooses "abort": RELEASE_LOCK and HALT

  # Update state (stage_summaries is the source of truth for stage completion)
  SET state.stage_summaries[stage] = summary_path
  SET state.current_stage = next_stage
  UPDATE checkpoint timestamp
  WRITE state
```

## Coordinator Dispatch

```
FUNCTION DISPATCH_COORDINATOR(stage):
  stage_file = dispatch_table[stage].file
  prior_summaries = dispatch_table[stage].prior_summaries
  checkpoint = dispatch_table[stage].checkpoint

  prompt = """
    You are coordinating Stage {stage}: {stage_name} of the feature implementation workflow.

    ## Your Instructions
    Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/{stage_file}

    ## Context
    Feature name: {FEATURE_NAME}
    Feature directory: {FEATURE_DIR}
    Tasks file: {TASKS_FILE}
    User input: {user_input}

    ## Prior Stage Summaries (read these first)
    {for each summary in prior_summaries: {FEATURE_DIR}/.stage-summaries/{summary}}

    ## Output Contract
    1. Write artifacts to {FEATURE_DIR}/ as specified in your instructions
    2. Write stage summary to: {FEATURE_DIR}/.stage-summaries/stage-{stage}-summary.md
    3. Use summary template: $CLAUDE_PLUGIN_ROOT/templates/stage-summary-template.md
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
FUNCTION CRASH_RECOVERY(stage):
  # Coordinator completed but no summary written
  artifacts = dispatch_table[stage].artifacts_written

  IF key artifacts exist on disk (e.g., tasks.md has new [X] marks for Stage 2):
    RECONSTRUCT minimal summary from artifact state, set degraded=true
    SET state.orchestrator.summaries_reconstructed += 1
  ELSE:
    SET status=failed, block_reason="Coordinator produced no output"

  ASK user: Retry stage / Continue with degraded summary / Abort
  IF user chooses "Abort": RELEASE_LOCK and HALT
```

## User Interaction Relay

Coordinators NEVER interact with users directly. All user interaction flows through the orchestrator:

1. Coordinator writes summary with `status: needs-user-input` and `flags.block_reason` explaining what is needed
2. Orchestrator reads summary, presents question to user via `AskUserQuestion`
3. Orchestrator writes user's answer to `{FEATURE_DIR}/.stage-summaries/stage-{N}-user-input.md`
4. Orchestrator re-dispatches same coordinator (coordinator reads the user-input file and continues)

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
  FOR each stage IN [1, 2, 3, 4, 5] WHERE stage < state.current_stage:
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
- Stage 5 completion (normal path)
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

## Architecture Decision Record: Delegation vs Direct Dispatch

**Chosen:** Coordinator delegation via `Task(subagent_type="general-purpose")`

**Previous approach:** Direct agent dispatch — orchestrator read reference files inline and launched developer/tech-writer agents directly. This accumulated all 5 stages' context in the orchestrator.

**Why delegation was chosen:**
- Context reduction: orchestrator holds only SKILL.md + orchestrator-loop.md + stage-1-setup.md + summaries
- Fault isolation: coordinator crash does not crash orchestrator
- Consistent pattern: matches the product-planning:plan skill architecture
- Clean separation via summary contract enforces explicit inter-stage communication

**Trade-offs accepted:**
- 5-15s latency per coordinator dispatch (~20-60s cumulative for 4 delegated stages)
- User interaction relay adds a round-trip for interactive stages (3, 4, 5)
- Coordinators must read context files independently (agents load spec files in their own context)

**Simplification trigger:** If coordination overhead becomes problematic, Stage 3 could be merged into Stage 2's coordinator (they share the same developer agent and reference file pattern).

**Known risk — Stage 2 context load:** Stage 2's coordinator reads up to 8 artifact files (tasks.md, plan.md, spec.md, design.md, data-model.md, contracts.md, research.md, test-plan.md) plus launches developer agents per phase. For features with large spec files or many phases, this may approach context limits. Mitigation: crash recovery can reconstruct state from artifacts, and the coordinator processes phases sequentially (not all at once). If this becomes a practical issue, consider splitting Stage 2 into per-phase coordinator dispatches.
