# Stage 2: Phase-by-Phase Execution

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

Launch a `developer` agent for the phase using the prompt template from `agent-prompts.md` (Section: Phase Implementation Prompt).

```
Task(subagent_type="product-implementation:developer")
```

**Key variables to prefill in prompt:**
- `{phase_name}` — Current phase name from tasks.md
- `{user_input}` — Original user arguments (if any)
- `{FEATURE_NAME}` — Derived from git branch
- `{FEATURE_DIR}` — Spec directory path
- `{TASKS_FILE}` — Path to tasks.md

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
3. Report progress to user:
   ```
   Phase {N} completed: {phase_name}
   Tasks: {completed}/{total}
   Phases remaining: {count}
   ```

### Step 5: Repeat or Proceed

- If more phases remain → return to Step 1 for next phase
- If all phases complete → proceed to Stage 3: Completion Validation

## 2.2 Execution Rules

### Dependency Rules

1. **Phase ordering**: Complete each phase entirely before starting the next
2. **Sequential tasks**: Execute in the order listed within a phase
3. **Parallel tasks `[P]`**: Can be dispatched to agents concurrently, BUT:
   - Tasks touching the same file must still run sequentially
   - All parallel tasks must complete before the phase is considered done
4. **Cross-phase dependencies**: Respect implicit ordering — Phase N tasks may depend on Phase N-1 outputs

### TDD Enforcement

The `developer` agent follows TDD internally (see `agents/developer.md`). The orchestrator enforces:
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

---

# Stage 3: Completion Validation

After all phases complete, launch a final `developer` agent for comprehensive validation.

## 3.1 Validation Agent

Launch using the validation prompt template from `agent-prompts.md` (Section: Completion Validation Prompt).

```
Task(subagent_type="product-implementation:developer")
```

## 3.2 Validation Checks

The validation agent verifies:

1. **Task completeness**: Every task in tasks.md is marked `[X]`
2. **Specification alignment**: Implemented features match the original spec
3. **Test coverage**: All tests pass, coverage meets project requirements
4. **Plan adherence**: Implementation follows the technical plan (architecture, patterns, file structure)
5. **Integration integrity**: All components integrate correctly

## 3.3 Validation Report

Agent produces a summary:

```text
## Implementation Validation Report

Tasks: {completed}/{total} (100%)
Tests: {passing}/{total} (100% pass rate)
Spec Coverage: {covered ACs}/{total ACs}

### Issues Found
- [severity] Description — file:line
- ...

### Recommendation
PASS / PASS WITH NOTES / NEEDS ATTENTION
```

## 3.4 Handling Validation Failures

If validation reveals issues:
1. Present findings to user via `AskUserQuestion`
2. Options: "Fix now", "Proceed to quality review anyway", "Stop here"
3. If "Fix now": launch developer agent to address specific issues, then re-validate
4. Store decision in state file under `user_decisions.validation_outcome`

## 3.5 Lock Release

Lock is released at the end of Stage 5 (Feature Documentation) — see `documentation.md` Section 5.4. If execution halts permanently at any earlier stage, release the lock in `.implementation-state.local.md`:
- Set `lock.acquired: false`
- Update `last_checkpoint` with current timestamp
