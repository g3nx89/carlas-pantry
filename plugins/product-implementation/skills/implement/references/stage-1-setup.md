---
stage: "1a"
stage_name: "Setup & Context Loading (Inline)"
checkpoint: "SETUP_PARTIAL"
delegation: "inline"
prior_summaries: []
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "test-cases/ (if exists)"
  - "analysis/task-test-traceability.md (if exists)"
artifacts_written:
  - "{FEATURE_DIR}/.stage-summaries/stage-1a-partial.md"
agents: []
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 1a: Setup & Context Loading (Inline)

> **INLINE STAGE:** This stage executes directly in the orchestrator's context.
> After completion, the orchestrator writes a PARTIAL summary to
> `{FEATURE_DIR}/.stage-summaries/stage-1a-partial.md`, then dispatches the
> Stage 1b coordinator (`stage-1b-probes.md`) to execute all probes and write
> the full Stage 1 summary.

## 1.0b Ralph Mode Detection

Check if the session is running inside a ralph loop by looking for the ralph-loop state file.

### Procedure

1. Check if `.claude/ralph-loop.local.md` exists in `PROJECT_ROOT`
2. IF file exists AND `config.ralph_loop.enabled` is `true` (default):
   - Set `ralph_mode: true` in the implementation state file (under `orchestrator.ralph_mode`)
   - Read `ralph_loop.pre_seed_defaults` from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
   - For each startup question (`quality_preset`, `external_models`, `autonomy_policy.default_level`):
     - IF the config value is `null` AND `pre_seed_defaults` has a value → use pre-seed default
     - ELIF the config value is `null` AND no pre-seed default → HALT: "Ralph mode requires pre-seeded config. Set `{field}` in `implementation-config.yaml` or pass via `--quality`/`--autonomy`/`--external-models`"
   - Skip Section 1.5b (project setup analysis) entirely — it requires user selection via `AskUserQuestion`
   - Log: `"[{timestamp}] Ralph mode detected — autonomous execution, no user interaction"`
   - Write `ralph_mode: true` to Stage 1 summary YAML frontmatter
3. ELIF file exists AND `config.ralph_loop.enabled` is `false`:
   - Log: `"[{timestamp}] Ralph loop file detected but ralph_loop.enabled is false — running in normal mode"`
   - Set `ralph_mode: false` in state file
   - Write `ralph_mode: false` to Stage 1 summary YAML frontmatter
4. ELSE:
   - Set `ralph_mode: false` in state file (default)
   - Write `ralph_mode: false` to Stage 1 summary YAML frontmatter

### Impact

When `ralph_mode: true`:
- Section 1.5b (project setup analysis) is skipped entirely
- Section 1.9a (autonomy policy) uses pre-seeded config value directly, never calls `SAFE_ASK_USER`
- Section 1.9b (quality config) uses pre-seeded config values directly, never calls `SAFE_ASK_USER`
- All downstream user prompts are intercepted by the orchestrator ralph mode guard — `SAFE_ASK_USER` is never invoked in ralph mode (see `orchestrator-loop.md`)

## 1.0c Cross-Iteration Learnings (Ralph Mode)

If `ralph_mode` is `true` AND `config.ralph_loop.learnings.enabled` is `true`:

1. Check if `{FEATURE_DIR}/.implementation-learnings.local.md` exists
2. If it exists:
   - Read the file
   - Extract up to 10 most recent entries (last 10 `###` blocks)
   - Store as `operational_learnings` for inclusion in Stage 1 summary (Section 1.10)
3. If it does not exist: set `operational_learnings: []`

The learnings are included in the Stage 1 summary body under "## Operational Learnings" so downstream coordinators can avoid repeating past mistakes.

## 1.1 Branch Parsing

Derive implementation variables from the current git branch:

```
git branch --show-current
```

**Branch format:** `feature/<number-padded-to-3-digits>-<kebab-case-title>`

**Variable derivation:**
- `PROJECT_ROOT` = git repository root (via `git rev-parse --show-toplevel`)
- `FEATURE_NAME` = part after `feature/` (e.g., `001-user-auth`)
- `FEATURE_DIR` = `specs/{FEATURE_NAME}` (e.g., `specs/001-user-auth`)
- `TASKS_FILE` = `{FEATURE_DIR}/tasks.md`

**Fallback:** If branch does not match the expected format, ask the user to provide FEATURE_NAME explicitly via `SAFE_ASK_USER` (see `orchestrator-loop.md` Helper: Safe Ask User). Stage 1 runs inline in the orchestrator, so this function is directly available.

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
| `{FEATURE_DIR}/test-plan.md` | V-Model test plan (tactical — from plan) |
| `{FEATURE_DIR}/test-strategy.md` | V-Model test strategy (strategic — from specify, optional) |
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

> **Sections 1.5b through 1.7b have been moved to `stage-1b-probes.md`** (v3.4.0).
> These sections (project setup, domain detection, all MCP/mobile/Figma/CLI probes,
> circuit breaker init) are now executed by a Stage 1b coordinator subagent with clean
> context, preventing LLM compliance degradation on long instruction files.
> See `stage-1b-probes.md` for the full probe instructions.

## 1.7 Lock Acquisition

Before initializing or resuming state, acquire the execution lock:

1. If state file does not exist → no lock to check, proceed to initialization (Section 1.8)
2. If state file exists, read `lock` field:
   - If `lock.acquired: false` → acquire lock (set `lock.acquired: true`, `lock.acquired_at: "{ISO_TIMESTAMP}"`, `lock.session_id: "{unique_id}"`)
   - If `lock.acquired: true` → check `lock.acquired_at` against the stale lock timeout¹:
     - If older than the timeout → treat as stale, override with new lock, log warning: "Overriding stale lock from {timestamp}"
     - If within the timeout → halt with guidance: "Another implementation session is active (started {timestamp}). Wait for it to complete or manually release the lock in `.implementation-state.local.md`."

> ¹ Stale lock timeout: `config/implementation-config.yaml` → `lock.stale_timeout_minutes` (default: 60)

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

> **Sections 1.9a through 1.10 have been moved to `stage-1b-probes.md`** (v3.4.0).
> Autonomy policy selection, quality configuration, pre-summary checklist, and the full
> Stage 1 summary template are now executed by the Stage 1b coordinator subagent.

## 1.10a Write Stage 1a Partial Summary

After completing Sections 1.0b through 1.9 (above), write the PARTIAL summary to `{FEATURE_DIR}/.stage-summaries/stage-1a-partial.md`. This file is consumed by the Stage 1b coordinator and deleted after the full Stage 1 summary is written.

```yaml
---
stage: "1a"
stage_name: "Setup & Context Loading (Partial)"
checkpoint: "SETUP_PARTIAL"
status: "partial"
summary: |
  Loaded context for {FEATURE_NAME}. Found {N} phases with {M} tasks.
  Required files: tasks.md, plan.md. Optional files loaded: {list}.
  Expected files missing: {list or "none"}.
  Test cases: {available with N specs / not available}.
  {Resume status if applicable}.
flags:
  test_cases_available: {true/false}
  ralph_mode: {true/false}
  operational_learnings: [{list or empty}]
  user_arguments: "{parsed arguments or null}"
context:
  PROJECT_ROOT: "{PROJECT_ROOT}"
  FEATURE_NAME: "{FEATURE_NAME}"
  FEATURE_DIR: "{FEATURE_DIR}"
  TASKS_FILE: "{TASKS_FILE}"
  total_phases: {N}
  total_tasks: {M}
  phases_remaining: [{list}]
  resume_from: "{phase_name or beginning}"
---
## Planning Artifacts Summary

| File | Status | Key Content |
|------|--------|-------------|
| `tasks.md` | Required — loaded | {N} phases, {M} tasks |
| `plan.md` | Required — loaded | Tech stack: {stack}, {N} files planned |
| `design.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `test-plan.md` | {Loaded / Missing (expected)} | {1-line summary or "N/A"} |
| `test-strategy.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `spec.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `contract.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `data-model.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `research.md` | {Loaded / Not found} | {1-line summary or "N/A"} |
| `test-cases/` | {Available ({N} specs) / Not found} | {Level breakdown or "N/A"} |
| `analysis/task-test-traceability.md` | {Loaded / Not found} | {1-line summary or "N/A"} |

## Context File Summaries

For each loaded optional/expected file, provide a 1-line summary of its key content:

- **spec.md**: {1-line summary}
- **design.md**: {1-line summary}
- **contract.md**: {1-line summary}
- **data-model.md**: {1-line summary}
- **research.md**: {1-line summary}
- **test-plan.md**: {1-line summary}
- **test-strategy.md**: {1-line summary}
- *(Omit lines for files that were not found)*

## Test Specifications

*(Only present if `test_cases_available: true`)*

- **Test cases directory**: `{FEATURE_DIR}/test-cases/`
- **Specs by level**: E2E: {count}, Integration: {count}, Unit: {count}, UAT: {count}
- **Total test IDs discovered**: {count}
- **Traceability file**: {Loaded / Not found}
- **Cross-validation**: {status}

## Operational Learnings

*(Only present if `ralph_mode: true` AND learnings file exists)*

{operational_learnings — up to 10 most recent entries}

## Stage 1a Log

- [{timestamp}] Ralph mode: {true/false}
- [{timestamp}] Branch parsed: {branch_name}
- [{timestamp}] Context loaded: {N} phases, {M} tasks
- [{timestamp}] Expected file warnings: {list or "none"}
- [{timestamp}] Test cases: {discovered N specs / not available}
- [{timestamp}] Lock acquired
- [{timestamp}] State initialized / resumed from Stage {S}
```

> **After writing the partial summary**, the orchestrator dispatches the Stage 1b coordinator
> (`stage-1b-probes.md`) which reads this partial summary, executes all probe and configuration
> sections, and writes the FULL `stage-1-summary.md`.
