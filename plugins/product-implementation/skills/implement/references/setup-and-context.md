# Stage 1: Setup & Context Loading

## 1.1 Branch Parsing

Derive implementation variables from the current git branch:

```
git branch --show-current
```

**Branch format:** `feature/<number-padded-to-3-digits>-<kebab-case-title>`

**Variable derivation:**
- `FEATURE_NAME` = part after `feature/` (e.g., `001-user-auth`)
- `FEATURE_DIR` = `specs/{FEATURE_NAME}` (e.g., `specs/001-user-auth`)
- `TASKS_FILE` = `{FEATURE_DIR}/tasks.md`

**Fallback:** If branch does not match the expected format, ask the user to provide FEATURE_NAME explicitly via `AskUserQuestion`.

## 1.2 Required Files

These files MUST exist. Halt implementation if missing.

| File | Purpose | If Missing |
|------|---------|------------|
| `{FEATURE_DIR}/tasks.md` | Complete task list and execution plan | Halt: "Run `/product-planning:tasks` to generate tasks" |
| `{FEATURE_DIR}/plan.md` | Tech stack, architecture, file structure | Halt: "Run `/product-planning:plan` to generate plan" |

## 1.3 Optional Files

Read these if they exist. They provide additional implementation context.

| File | Purpose |
|------|---------|
| `{FEATURE_DIR}/data-model.md` | Entity definitions and relationships |
| `{FEATURE_DIR}/contracts.md` | API specifications and test requirements |
| `{FEATURE_DIR}/research.md` | Technical decisions and constraints |
| `{FEATURE_DIR}/spec.md` | Feature specification and user stories |
| `{FEATURE_DIR}/design.md` | Architecture design document |
| `{FEATURE_DIR}/test-plan.md` | V-Model test strategy |

## 1.4 Context Loading Procedure

1. Read `tasks.md` — extract phase list, task count, dependency structure
2. Read `plan.md` — extract tech stack, file structure, architecture decisions
3. For each optional file that exists — read and note key information
4. Read `CLAUDE.md` and `constitution.md` at project root (if they exist) for coding conventions

## 1.5 Tasks.md Structure Validation

Parse tasks.md and verify it has the expected structure:

- **Phase headers**: Sections grouping tasks (e.g., "Phase 1: Setup", "Phase 3: US1")
- **Task entries**: Checkbox format `- [ ] T001 [P?] [Story?] Description with file path`
- **Parallel markers**: `[P]` indicates tasks that can run in parallel
- **Story labels**: `[US1]`, `[US2]` etc. map tasks to user stories

Extract and store:
- Total phase count
- Total task count
- List of phase names in order
- Which tasks are already marked `[X]` (for resume scenarios)

**Validation:** If tasks.md exists but contains zero phases (empty or malformed), halt with guidance: "tasks.md has no parseable phases. Verify the file was generated correctly by `/product-planning:tasks`."

## 1.6 Lock Acquisition

Before initializing or resuming state, acquire the execution lock:

1. If state file does not exist → no lock to check, proceed to initialization (Section 1.7)
2. If state file exists, read `lock` field:
   - If `lock.acquired: false` → acquire lock (set `lock.acquired: true`, `lock.acquired_at: "{ISO_TIMESTAMP}"`, `lock.session_id: "{unique_id}"`)
   - If `lock.acquired: true` → check `lock.acquired_at` against the stale timeout in `config/implementation-config.yaml` (default: 60 minutes):
     - If older than the configured timeout → treat as stale, override with new lock, log warning: "Overriding stale lock from {timestamp}"
     - If within the configured timeout → halt with guidance: "Another implementation session is active (started {timestamp}). Wait for it to complete or manually release the lock in `.implementation-state.local.md`."

## 1.7 State Initialization

**Template:** `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md`

### New Implementation

Create `{FEATURE_DIR}/.implementation-state.local.md` from the template, filling in:
- `feature_name` with `{FEATURE_NAME}`
- `feature_dir` with `{FEATURE_DIR}`
- `phases_remaining` with all phases extracted from tasks.md
- `lock.acquired: true`, `lock.acquired_at`, `lock.session_id`
- `last_checkpoint` with current ISO timestamp

### Resume Implementation

If `.implementation-state.local.md` already exists (and lock was acquired in 1.6):

1. Read state file
2. Parse `current_stage`, `phases_completed`, `phases_remaining`, and `user_decisions`
3. Verify state consistency with tasks.md:
   - Check that tasks marked `[X]` in tasks.md match completed phases
   - If inconsistent, reconcile by trusting tasks.md as source of truth
4. Determine resume entry point using stage-level routing (see SKILL.md "Stage-Level Resume"):
   - If `current_stage` < 2 → restart from Stage 1
   - If `current_stage` = 2 → resume from first phase in `phases_remaining`
   - If `current_stage` >= 3 and the corresponding `user_decisions` key exists → advance to next stage
5. Report resume point to user:
   ```
   Resuming implementation from Stage {S}, Phase {N}: {phase_name}
   Completed: {X}/{Y} phases ({Z} tasks done)
   ```
6. Continue from the determined resume point

## 1.8 User Input Handling

If user provided arguments (non-empty `$ARGUMENTS`):
- Parse for specific phase/task preferences (e.g., "start from Phase 3", "only US1")
- Parse for implementation preferences (e.g., "focus on backend", "start from Phase 3", "only US1")
- NOTE: "skip tests" is NOT a valid preference — TDD is enforced unconditionally (see Critical Rule 3)
- Apply these as filters/overrides to the execution plan
- Store in state file under `user_decisions`
