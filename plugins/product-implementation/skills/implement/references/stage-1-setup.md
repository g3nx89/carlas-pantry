---
stage: "1"
stage_name: "Setup & Context Loading"
checkpoint: "SETUP"
delegation: "inline"
prior_summaries: []
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "test-cases/ (if exists)"
  - "analysis/task-test-traceability.md (if exists)"
artifacts_written: []
agents: []
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 1: Setup & Context Loading

> **INLINE STAGE:** This stage executes directly in the orchestrator's context.
> After completion, the orchestrator MUST write a Stage 1 summary to
> `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`.

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
| `{FEATURE_DIR}/contract.md` | API specifications and test requirements |
| `{FEATURE_DIR}/research.md` | Technical decisions and constraints |
| `{FEATURE_DIR}/spec.md` | Feature specification and user stories |
| `{FEATURE_DIR}/design.md` | Architecture design document |
| `{FEATURE_DIR}/test-plan.md` | V-Model test strategy |
| `{FEATURE_DIR}/test-cases/` | Test specifications by level (e2e, integration, unit, uat) |
| `{FEATURE_DIR}/analysis/task-test-traceability.md` | Mapping of tasks to test cases and acceptance criteria |

## 1.3a Expected Files

These files are not strictly required (implementation can proceed without them), but their absence usually indicates the planning phase was incomplete. **Emit a warning** for each missing expected file so the user is aware.

The expected file list and warning messages are defined in `config/implementation-config.yaml` under `handoff.expected_files`. Current defaults:

| File | Warning If Missing |
|------|-------------------|
| `{FEATURE_DIR}/design.md` | "design.md not found — developer agents will rely on plan.md only for architecture context" |
| `{FEATURE_DIR}/test-plan.md` | "test-plan.md not found — TDD will proceed without a V-Model test strategy document" |

Log each warning in the Stage 1 summary. Do NOT halt execution for missing expected files.

## 1.3b Test Cases Discovery

Scan for pre-generated test specifications from the planning phase:

1. Check if `{FEATURE_DIR}/test-cases/` directory exists
2. If it exists:
   - List subdirectories (expected subdirectories and test ID patterns are defined in `config/implementation-config.yaml` under `handoff.test_cases`; defaults: `e2e/`, `integration/`, `unit/`, `uat/`)
   - Count `.md` spec files per level
   - Extract test IDs from spec files (default patterns: `E2E-*`, `INT-*`, `UT-*`, `UAT-*`)
   - Cross-reference test IDs against `test-plan.md` (if available) to verify alignment
   - Store results as `test_cases_available: true` with per-level counts
3. If it does not exist:
   - Set `test_cases_available: false`
   - All test-case-dependent sections in later stages will be skipped

**Output variable:** `test_cases_summary` — included in Stage 1 summary for consumption by later stages.

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

**Structural checks** (warn if missing, do not halt):
- **Overview section**: Verify tasks.md contains a top-level overview or summary section. If missing, warn: "tasks.md has no overview section — phase context may be limited."
- **Test ID references**: If `test_cases_available` is true, scan task descriptions for test ID patterns (configured in `config/implementation-config.yaml` under `handoff.test_cases.test_id_patterns`; defaults: `E2E-*`, `INT-*`, `UT-*`, `UAT-*`). If no test IDs are found in tasks.md but test-cases/ exists, warn: "tasks.md does not reference test IDs from test-cases/ — traceability may be incomplete."
- **Test ID cross-validation**: If both tasks.md test IDs and test-cases/ specs are present, verify that referenced test IDs have corresponding spec files. Log any orphaned references.

## 1.6 Domain Detection

Detect technology domains present in the feature to enable conditional skill injection by downstream coordinators. This step uses artifacts ALREADY loaded in Sections 1.4-1.5 — no additional file reads.

### Detection Procedure

1. **Scan task file paths** in `tasks.md`: extract all file path fragments from task descriptions (e.g., `src/routes/auth.ts`, `app/build.gradle.kts`)
2. **Scan plan.md content**: check tech stack, architecture decisions, and file structure sections
3. **Match against domain indicators** defined in `config/implementation-config.yaml` under `dev_skills.domain_mapping`

For each domain in the mapping, check if ANY of its `indicators` appear (case-sensitive) in the combined text of task file paths + plan.md content. If a match is found, add the domain key to `detected_domains`.

### Output

Store the result as `detected_domains` in the Stage 1 summary YAML frontmatter (top-level field, not under `flags`; see Section 1.10). Example:

```yaml
detected_domains: ["kotlin", "compose", "android", "api"]
```

If `dev_skills.enabled` is `false` in config, set `detected_domains: []` and skip detection.

### Cost

Zero additional file reads. Zero additional agent dispatches. Pure text matching against already-loaded content.

## 1.7 Lock Acquisition

Before initializing or resuming state, acquire the execution lock:

1. If state file does not exist → no lock to check, proceed to initialization (Section 1.8)
2. If state file exists, read `lock` field:
   - If `lock.acquired: false` → acquire lock (set `lock.acquired: true`, `lock.acquired_at: "{ISO_TIMESTAMP}"`, `lock.session_id: "{unique_id}"`)
   - If `lock.acquired: true` → check `lock.acquired_at` against the stale timeout in `config/implementation-config.yaml` (default: 60 minutes):
     - If older than the configured timeout → treat as stale, override with new lock, log warning: "Overriding stale lock from {timestamp}"
     - If within the configured timeout → halt with guidance: "Another implementation session is active (started {timestamp}). Wait for it to complete or manually release the lock in `.implementation-state.local.md`."

## 1.8 State Initialization

**Template:** `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md`

### New Implementation

Create `{FEATURE_DIR}/.implementation-state.local.md` from the template, filling in:
- `feature_name` with `{FEATURE_NAME}`
- `feature_dir` with `{FEATURE_DIR}`
- `phases_remaining` with all phases extracted from tasks.md
- `lock.acquired: true`, `lock.acquired_at`, `lock.session_id`
- `last_checkpoint` with current ISO timestamp

Create the `.stage-summaries/` directory:
```
mkdir -p {FEATURE_DIR}/.stage-summaries
```

### Resume Implementation

If `.implementation-state.local.md` already exists (and lock was acquired in 1.7):

1. Read state file
2. If `version: 1` → run v1-to-v2 migration (see `orchestrator-loop.md`)
3. Parse `current_stage`, `phases_completed`, `phases_remaining`, and `user_decisions`
4. Verify state consistency with tasks.md:
   - Check that tasks marked `[X]` in tasks.md match completed phases
   - If inconsistent, reconcile by trusting tasks.md as source of truth
5. Determine resume entry point using stage-level routing (see SKILL.md "Stage-Level Resume")
6. Report resume point to user:
   ```
   Resuming implementation from Stage {S}, Phase {N}: {phase_name}
   Completed: {X}/{Y} phases ({Z} tasks done)
   ```
7. Continue from the determined resume point

## 1.9 User Input Handling

If user provided arguments (non-empty `$ARGUMENTS`):
- Parse for specific phase/task preferences (e.g., "start from Phase 3", "only US1")
- Parse for implementation preferences (e.g., "focus on backend", "start from Phase 3", "only US1")
- NOTE: "skip tests" is NOT a valid preference — TDD is enforced unconditionally (see Critical Rule 3)
- Apply these as filters/overrides to the execution plan
- Store in state file under `user_decisions`

## 1.10 Write Stage 1 Summary

After completing all setup steps, write the summary to `{FEATURE_DIR}/.stage-summaries/stage-1-summary.md`:

```yaml
---
stage: "1"
stage_name: "Setup & Context Loading"
checkpoint: "SETUP"
status: "completed"
artifacts_written: []
summary: |
  Loaded context for {FEATURE_NAME}. Found {N} phases with {M} tasks.
  Required files: tasks.md, plan.md. Optional files loaded: {list}.
  Expected files missing: {list or "none"}.
  Test cases: {available with N specs / not available}.
  {Resume status if applicable}.
flags:
  block_reason: null
  test_cases_available: {true/false}
detected_domains: [{list of matched domain keys, e.g., "kotlin", "api"}]  # from Section 1.6
---
## Context for Next Stage

- FEATURE_NAME: {FEATURE_NAME}
- FEATURE_DIR: {FEATURE_DIR}
- TASKS_FILE: {TASKS_FILE}
- Total phases: {N}
- Total tasks: {M}
- Phases remaining: {list}
- Resume from: {phase_name or "beginning"}
- Detected domains: {list, e.g., ["kotlin", "compose", "api"] or [] if detection disabled}

## Planning Artifacts Summary

| File | Status | Key Content |
|------|--------|-------------|
| `tasks.md` | Required — loaded | {N} phases, {M} tasks |
| `plan.md` | Required — loaded | Tech stack: {stack}, {N} files planned |
| `design.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `test-plan.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `spec.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `contract.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `data-model.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `research.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `test-cases/` | {Available ({N} specs) / Not found} | {Level breakdown or "N/A"} |
| `analysis/task-test-traceability.md` | {Loaded / Not found} | {1-line summary or "N/A"} |

## Context File Summaries

For each loaded optional/expected file, provide a 1-line summary of its key content to give downstream coordinators and agents quick context without re-reading full files:

- **spec.md**: {1-line summary, e.g., "3 user stories covering registration, login, and password reset"}
- **design.md**: {1-line summary, e.g., "Clean architecture with 4 layers, PostgreSQL + Redis stack"}
- **contract.md**: {1-line summary, e.g., "5 REST endpoints, JWT auth, OpenAPI 3.0 format"}
- **data-model.md**: {1-line summary, e.g., "4 entities: User, Session, Token, AuditLog with relations"}
- **research.md**: {1-line summary, e.g., "Chose bcrypt over argon2 for password hashing, Redis for sessions"}
- **test-plan.md**: {1-line summary, e.g., "V-Model strategy: 12 e2e, 25 integration, 40 unit tests planned"}
- *(Omit lines for files that were not found)*

## Test Specifications

*(This section is only present if `test_cases_available: true`)*

- **Test cases directory**: `{FEATURE_DIR}/test-cases/`
- **Specs by level**:
  - E2E: {count} specs
  - Integration: {count} specs
  - Unit: {count} specs
  - UAT: {count} specs
- **Total test IDs discovered**: {count}
- **Traceability file**: {Loaded / Not found} (`analysis/task-test-traceability.md`)
- **Cross-validation**: {All test IDs in tasks.md have matching specs / {N} orphaned references}

## Stage Log

- [{timestamp}] Branch parsed: {branch_name}
- [{timestamp}] Context loaded: {N} phases, {M} tasks
- [{timestamp}] Expected file warnings: {list or "none"}
- [{timestamp}] Test cases: {discovered N specs / not available}
- [{timestamp}] Domain detection: {detected_domains list or "disabled"}
- [{timestamp}] Lock acquired
- [{timestamp}] State initialized / resumed from Stage {S}
```
