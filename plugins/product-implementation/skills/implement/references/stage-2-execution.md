---
stage: "2"
stage_name: "Phase-by-Phase Execution"
checkpoint: "EXECUTION"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-1-summary.md"
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "spec.md"
  - "design.md"
  - "data-model.md"
  - "contract.md"
  - "research.md"
  - "test-plan.md"
  - "test-cases/ (if exists)"
  - "analysis/task-test-traceability.md (if exists)"
artifacts_written:
  - "tasks.md (updated with [X] marks)"
  - ".implementation-state.local.md (updated phases)"
agents:
  - "product-implementation:developer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 2: Phase-by-Phase Execution

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the Stage 1 summary first to obtain FEATURE_NAME, FEATURE_DIR, TASKS_FILE,
> and the list of phases to execute.

## 2.1 Phase Loop

For each phase in `tasks.md` (in order), perform these steps:

### Step 1: Parse Phase Tasks

Extract from the current phase section in tasks.md:
- **Task list**: All `- [ ]` entries belonging to this phase
- **Parallel tasks**: Entries with `[P]` marker — can execute concurrently
- **Sequential tasks**: Entries without `[P]` — must execute in listed order
- **File targets**: Extract file paths from task descriptions
- **Dependencies**: Tasks targeting the same file MUST run sequentially regardless of `[P]` marker

### Step 2: Launch Developer Agent

Launch a single `developer` agent for the entire phase using the prompt template from `agent-prompts.md` (Section: Phase Implementation Prompt). The agent handles all tasks within the phase internally, including sequencing of parallel `[P]` tasks. Dispatch one agent per phase, not one agent per task.

```
Task(subagent_type="product-implementation:developer")
```

**Key variables to prefill in prompt:**
- `{phase_name}` — Current phase name from tasks.md
- `{user_input}` — Original user arguments (if any)
- `{FEATURE_NAME}` — From Stage 1 summary
- `{FEATURE_DIR}` — From Stage 1 summary
- `{TASKS_FILE}` — From Stage 1 summary
- `{context_summary}` — From Stage 1 summary "Context File Summaries" section. If section not present, use fallback: `"No context summary available — read planning artifacts from FEATURE_DIR as needed."`
- `{test_specs_summary}` — From Stage 1 summary "Test Specifications" section. If section not present, use fallback: `"No test specifications available — proceed with standard TDD approach."`
- `{test_cases_dir}` — If Stage 1 summary has `test_cases_available: true`, set to `{FEATURE_DIR}/test-cases/`. Otherwise set to `"Not available"`.
- `{traceability_file}` — If `analysis/task-test-traceability.md` was loaded per Stage 1 summary, set to `{FEATURE_DIR}/analysis/task-test-traceability.md`. Otherwise set to `"Not available"`.

### Step 3: Verify Phase Completion

After agent returns, verify:
1. All tasks in the phase are marked `[X]` in tasks.md
2. No task was skipped or left incomplete
3. Agent reported test results (all passing)

If verification fails:
- For sequential task failure: **Halt execution**. Report which task failed and why.
- For parallel task `[P]` failure: Continue with successful tasks, collect failures.

### Step 4: Update Progress

1. Mark phase as completed in tasks.md (ensure all `[X]` marks are persisted)
2. Update `.implementation-state.local.md`:
   - Move phase from `phases_remaining` to `phases_completed`
   - Update `current_stage` if needed
   - Update `last_checkpoint` timestamp
   - Append to Implementation Log
3. Report progress:
   ```
   Phase {N} completed: {phase_name}
   Tasks: {completed}/{total}
   Phases remaining: {count}
   ```

### Step 5: Repeat or Proceed

- If more phases remain → return to Step 1 for next phase
- If all phases complete → write Stage 2 summary and return to orchestrator

## 2.2 Execution Rules

### Dependency Rules

1. **Phase ordering**: Complete each phase entirely before starting the next
2. **Sequential tasks**: Execute in the order listed within a phase
3. **Parallel tasks `[P]`**: Can be dispatched to agents concurrently, BUT:
   - Tasks touching the same file must still run sequentially
   - All parallel tasks must complete before the phase is considered done
4. **Cross-phase dependencies**: Respect implicit ordering — Phase N tasks may depend on Phase N-1 outputs

### TDD Enforcement

The `developer` agent follows TDD internally (see `agents/developer.md`). This coordinator enforces:
- Test tasks (when present) execute before their corresponding implementation tasks
- Phase is NOT complete until all tests in the phase pass
- If tests fail, the agent must fix implementation until tests pass

### Error Handling

| Error Type | Action |
|-----------|--------|
| Sequential task fails | Halt phase. Report error with task ID, description, and error message. Suggest fix or manual intervention. |
| Parallel task fails | Continue other parallel tasks. Collect failure. Report all failures at phase end. |
| Agent crashes | Retry once with same prompt. If second failure, halt with full error context. |
| Tests fail after implementation | Agent retries fix internally (part of developer agent self-critique). If still failing after agent completes, report to orchestrator. |
| tasks.md corrupted | Re-read from disk. If unrecoverable, halt with guidance to check git history. |

### Progress Persistence

After EVERY completed task (not just phase), the developer agent must mark it `[X]` in tasks.md. This ensures:
- Crash recovery can identify exactly where execution stopped
- Resume picks up at the correct task, not just phase
- User has real-time visibility into progress

## 2.3 Write Stage 2 Summary

After all phases complete (or on halt), write summary to `{FEATURE_DIR}/.stage-summaries/stage-2-summary.md`:

```yaml
---
stage: "2"
stage_name: "Phase-by-Phase Execution"
checkpoint: "EXECUTION"
status: "completed"  # or "failed" if halted, or "needs-user-input" if user decision needed
artifacts_written:
  - "tasks.md (updated with [X] marks)"
  - ".implementation-state.local.md"
summary: |
  Executed {N}/{M} phases. {X} tasks completed, {Y} tasks remaining.
  All tests passing: {yes/no}.
  {Error details if halted}.
flags:
  block_reason: null  # or description of error if needs-user-input
---
## Context for Next Stage

- Phases completed: {list}
- Tasks completed: {count}/{total}
- Tests status: all passing / {N} failures
- Files modified: {list of key files}
- Errors encountered: {none / list}

## Stage Log

- [{timestamp}] Phase 1: {phase_name} — {task_count} tasks completed
- [{timestamp}] Phase 2: {phase_name} — {task_count} tasks completed
- ...
```
