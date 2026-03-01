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
- `PROJECT_ROOT` = git repository root (via `git rev-parse --show-toplevel`)
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

## 1.6 Domain Detection [Cost: zero file reads, zero dispatches — pure text matching]

Detect technology domains present in the feature to enable conditional skill injection by downstream coordinators. This step uses artifacts ALREADY loaded in Sections 1.4-1.5.

### Detection Procedure

1. **Scan task file paths** in `tasks.md`: extract all file path fragments from task descriptions (e.g., `src/routes/auth.ts`, `app/build.gradle.kts`)
2. **Scan plan.md content**: check tech stack, architecture decisions, and file structure sections
3. **Match against domain indicators** defined in `config/implementation-config.yaml` under `dev_skills.domain_mapping`

For each domain in the mapping, check if ANY of its `indicators` appear (case-sensitive) in the combined text of task file paths + plan.md content. If a match is found, add the domain key to `detected_domains`. Count the number of distinct indicator matches per domain.

### Output

Store the result as `detected_domains` in the Stage 1 summary YAML frontmatter (top-level field, not under `flags`; see Section 1.10). Flag domains with only a single indicator match as `tentative` — downstream stages may treat tentative domains with lower priority for skill injection.

```yaml
detected_domains: ["kotlin", "compose", "android", "api"]
domain_confidence:
  kotlin: 5        # 5 indicator matches — confident
  compose: 3       # 3 indicator matches — confident
  android: 1       # 1 indicator match — tentative
  api: 2           # 2 indicator matches — confident
```

If `dev_skills.enabled` is `false` in config, set `detected_domains: []` and skip detection.

## 1.6a MCP Availability Check

Probe available MCP tools to determine which research capabilities are reachable. This step runs ONCE during Stage 1 and stores results for all downstream stages.

### Procedure

1. Read `research_mcp` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
2. If `research_mcp.enabled` is `true`, proceed with probes below. Otherwise, set all availability flags to `false`, skip Sections 1.6b-1.6d, and proceed to Section 1.7.
3. **Probe Ref**: If `research_mcp.ref.enabled` is `true`, call `ref_search_documentation` with a minimal query derived from plan.md tech stack (e.g., the primary framework name). If the call succeeds (returns results or empty results without error), set `ref_available: true`. If it errors or times out, set `ref_available: false`.
4. **Probe Context7**: If `research_mcp.context7.enabled` is `true`, call `resolve-library-id` with the primary framework name from plan.md. If the call succeeds, set `context7_available: true`. If it errors, set `context7_available: false`.
5. **Probe Tavily**: If `research_mcp.tavily.enabled` is `true`, call `tavily_search` with a minimal query (e.g., `"{primary_framework} documentation"`). If the call succeeds, set `tavily_available: true`. If it errors, set `tavily_available: false`.

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
mcp_availability:
  ref: true       # or false
  context7: true   # or false
  tavily: true     # or false
```

### Cost

3 lightweight probe calls (~1-3s total). Skipped entirely when `research_mcp.enabled` is `false`.

## 1.6b URL Extraction from Planning Artifacts [Cost: zero MCP calls — regex on loaded content]

Extract documentation URLs from already-loaded planning artifacts for pre-reading in Stage 2.

### Procedure

1. If `research_mcp.url_extraction.enabled` is `false` OR `ref_available` is `false` → skip, set `extracted_urls: []`
2. Scan the text content of `plan.md`, `design.md`, and `research.md` (already loaded in Section 1.4) for URLs matching `research_mcp.url_extraction.url_patterns`
3. Filter out URLs matching any pattern in `research_mcp.url_extraction.ignore_patterns`
4. Deduplicate by exact URL string
5. Cap at 5 URLs (keep earliest-appearing)

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
extracted_urls:
  - "https://docs.example.com/api/v2"
  - "https://framework.dev/migration-guide"
```

## 1.6c Library ID Pre-Resolution (Context7)

Pre-resolve Context7 library IDs so downstream coordinators can skip the resolve step and query docs directly.

### Procedure

1. If `research_mcp.context7.pre_resolve_in_stage1` is `false` OR `context7_available` is `false` → skip, set `resolved_libraries: []`
2. Extract library/framework names from `plan.md` tech stack section (e.g., "React", "Express", "Prisma")
3. For each library name (up to `research_mcp.context7.max_pre_resolve`, default 5):
   - Call `resolve-library-id` with `libraryName` = the library name and `query` = a brief description of how it's used in the project
   - If successful, record `{name, library_id}` pair
   - If the call fails, skip that library (do not halt)

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
resolved_libraries:
  - name: "React"
    library_id: "/facebook/react"
  - name: "Express"
    library_id: "/expressjs/express"
```

### Cost

Up to 5 `resolve-library-id` calls (~2-5s total). Skipped when disabled or Context7 unavailable.

## 1.6d Private Documentation Discovery [Cost: 1 Ref call, skipped when disabled]

Discover private documentation sources via Ref for use in downstream stages.

### Procedure

1. If `research_mcp.private_docs.enabled` is `false` OR `ref_available` is `false` → skip, set `private_doc_urls: []`
2. Call `ref_search_documentation` with query: `"{primary_framework} {feature_description} ref_src=private"` (use plan.md tech stack and feature name)
3. Extract up to `research_mcp.private_docs.max_private_results` (default 3) result URLs

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
private_doc_urls:
  - "https://internal.docs.company.com/api-guide"
```

## 1.6e Mobile Device Availability Check [Cost: 1 MCP probe ~1-2s, skipped when UAT disabled]

Probe mobile-mcp to determine if a mobile testing emulator is available for UAT execution. This step runs ONCE during Stage 1 and stores results for all downstream stages.

### Procedure

1. Read `uat_execution` and `cli_dispatch.stage2.uat_mobile_tester` sections from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
2. If either `uat_execution.enabled` or `cli_dispatch.stage2.uat_mobile_tester.enabled` is `true`, proceed with probe below. Otherwise, set `mobile_mcp_available: false`, `mobile_device_name: null`, skip to Section 1.6f.
3. **Probe mobile-mcp**: Call `mobile_list_available_devices`
   - If call succeeds AND returns at least one device: set `mobile_mcp_available: true`, store `mobile_device_name` from the first available emulator device (prefer emulator over physical device for UAT reproducibility)
   - If call fails, times out, or returns empty device list: set `mobile_mcp_available: false`, `mobile_device_name: null`, log warning: `"Mobile MCP not available or no emulator running — UAT mobile testing will be skipped for all phases"`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
mobile_mcp_available: true    # or false
mobile_device_name: "emulator-5554"  # or null
```

## 1.6f Plugin Availability Check [Cost: zero MCP calls — skill listing check]

Probe available plugins to determine which optional skill-based capabilities are reachable. This step runs ONCE during Stage 1 and stores results for downstream coordinators.

### Procedure

1. Check if the `code-review:review-local-changes` skill is listed in available skills (query the Skill tool listing)
2. If listed: set `plugin_availability.code_review: true`
3. If not listed: set `plugin_availability.code_review: false`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
plugin_availability:
  code_review: true    # or false
```

## 1.7a CLI Availability Detection (CLI)

Detect which external CLI tools are available for CLI dispatch. This step runs ONCE during Stage 1 and stores results for all downstream coordinators. It only executes when at least one CLI option is enabled in config.

### Procedure

1. Read `cli_dispatch` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
2. Collect all unique `cli_name` values from enabled options across all stages (skip options where `enabled: false` or `cli_name` is `null`)
3. If no enabled options have a `cli_name` → set `cli_availability: {}` and skip to Section 1.7
4. **Verify dispatch infrastructure** — check that the dispatch script and parsing tools are available:
   a. Check `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh` exists and is executable
   b. Check `jq --version` via Bash (required for Tier 1 JSON parsing)
   c. Check `python3 --version` via Bash (required for Tier 2 partial recovery)
   d. If dispatch script is missing → set all `cli_availability` values to `false`, log error: `"dispatch-cli-agent.sh not found — all CLI dispatches disabled"`, skip to Section 1.7
   e. If `jq` missing → log warning: `"jq not found — Tier 1 JSON parsing unavailable, Tier 2+ fallback will be used"`
   f. If `python3` missing → log warning: `"python3 not found — Tier 2 partial recovery unavailable"`
5. For each unique `cli_name`:
   a. Read `$CLAUDE_PLUGIN_ROOT/config/cli_clients/{cli_name}.json`
   b. Extract the `command` field (e.g., `"codex"`)
   c. Run a smoke test: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh --cli {command} --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-{cli_name}.txt --timeout 30`
   d. If exit code is 0 or 1 (CLI found, dispatch works): set `cli_availability[cli_name] = true`
   e. If exit code is 3 (CLI not found): set `cli_availability[cli_name] = false`, log warning: `"CLI '{cli_name}' not available — CLI options using this CLI will fall back to native behavior"`
   f. If exit code is 2 (timeout) on a smoke test: set `cli_availability[cli_name] = true` (CLI exists but was slow), log note

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
cli_availability:
  codex: true
  gemini: false
  opencode: true
dispatch_infrastructure:
  script_available: true
  jq_available: true
  python3_available: true
```

### Cost

1 dispatch script smoke test per unique enabled CLI (~3-5s total). Skipped entirely when no CLI options are enabled.

## 1.7b CLI Circuit Breaker Initialization

> Conditional: Only when `cli_dispatch.circuit_breaker.enabled` is `true` in config.
> If disabled, set `cli_circuit_state: null` in the summary and skip.

Initialize the circuit breaker state for all detected CLIs:

```yaml
cli_circuit_state:
  codex: {consecutive_failures: 0, status: "closed"}
  gemini: {consecutive_failures: 0, status: "closed"}
  opencode: {consecutive_failures: 0, status: "closed"}
```

Only include CLIs where `cli_availability.{cli_name}` is `true`. Omit unavailable CLIs.

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

## 1.9a Autonomy Policy Selection

Determine how the system should handle issues (findings, failures, incomplete tasks) during execution. This decision applies to all downstream stages and is stored in the Stage 1 summary for consumption by coordinators and the orchestrator.

### Procedure

1. Read `autonomy_policy` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
2. If `autonomy_policy.default_level` is NOT null:
   - Validate that the value matches a key in `autonomy_policy.levels` (one of: `full_auto`, `balanced`, `critical_only`)
   - If valid: set `autonomy_policy` to the configured value, log: `"Autonomy policy: {label} (from config default)"`
   - If invalid: log warning, fall through to user question
3. If `autonomy_policy.default_level` is null (or invalid):
   - Ask the user via `AskUserQuestion`:
     - **Question:** "How should I handle issues during implementation?"
     - **Options:**
       1. **Full Auto** — "Fix everything automatically, don't interrupt me" (description from config: `levels.full_auto.description`)
       2. **Balanced (Recommended)** — "Fix critical/high automatically, defer the rest" (description from config: `levels.balanced.description`)
       3. **Minimal** — "Fix only critical blockers, ask me for important decisions" (description from config: `levels.critical_only.description`)
   - Map user's selection to the level key: "Full Auto" → `full_auto`, "Balanced" → `balanced`, "Minimal" → `critical_only`
   - Log: `"Autonomy policy: {label} (user selected)"`

### Output

Store in Stage 1 summary YAML frontmatter:

```yaml
autonomy_policy: "balanced"  # or "full_auto" or "critical_only"
```

### Impact

This value is consumed by:
- **Orchestrator** (orchestrator-loop.md): determines behavior on summary validation failure, stage failure, and crash recovery
- **Stage 2 coordinator**: determines behavior on code simplification test failure (Step 3.5) and UAT findings (Step 3.7)
- **Stage 3 coordinator**: determines behavior on validation issues (Section 3.4)
- **Stage 4 coordinator**: extends the auto-decision matrix (Section 4.4) based on policy
- **Stage 5 coordinator**: determines behavior on incomplete tasks (Section 5.1)

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
cli_availability:              # from Section 1.7a (empty {} if no CLI options enabled)
  codex: {true/false}
  gemini: {true/false}
  opencode: {true/false}
mcp_availability:           # from Section 1.6a (all false if research_mcp.enabled is false)
  ref: {true/false}
  context7: {true/false}
  tavily: {true/false}
extracted_urls: [{list of doc URLs from planning artifacts}]  # from Section 1.6b
resolved_libraries:         # from Section 1.6c
  - name: "{library_name}"
    library_id: "{context7_library_id}"
private_doc_urls: [{list of private doc URLs}]  # from Section 1.6d
mobile_mcp_available: {true/false}  # from Section 1.6e (false if UAT config disabled or no emulator)
mobile_device_name: "{name or null}"  # from Section 1.6e (first available emulator device)
plugin_availability:             # from Section 1.6f
  code_review: {true/false}
autonomy_policy: "{full_auto/balanced/critical_only}"  # from Section 1.9a (user-selected or config default)
cli_circuit_state: null   # from Section 1.7b (null if disabled)
# IF context_protocol.enabled:
context_contributions:
  key_decisions:
    - text: "Autonomy policy: {selected_level}"
      confidence: "HIGH"
    - text: "Planning artifacts: {count} loaded ({list})"
      confidence: "HIGH"
  open_issues: []
  risk_signals:
    # Populate from expected-file warnings (e.g., "design.md missing")
# ELSE:
# context_contributions: null
---
## Context for Next Stage

- PROJECT_ROOT: {PROJECT_ROOT}
- FEATURE_NAME: {FEATURE_NAME}
- FEATURE_DIR: {FEATURE_DIR}
- TASKS_FILE: {TASKS_FILE}
- Total phases: {N}
- Total tasks: {M}
- Phases remaining: {list}
- Resume from: {phase_name or "beginning"}
- Detected domains: {list, e.g., ["kotlin", "compose", "api"] or [] if detection disabled}
- CLI availability: {map, e.g., codex=true, gemini=false or "no CLI options enabled"}
- MCP availability: ref={true/false}, context7={true/false}, tavily={true/false} (or "all disabled" if research_mcp.enabled is false)
- Extracted URLs: {count} documentation URLs from planning artifacts (or "disabled")
- Resolved libraries: {count} Context7 library IDs pre-resolved (or "disabled")
- Private doc URLs: {count} private documentation sources (or "disabled")
- Mobile MCP: {available with device "{name}" / not available} (or "UAT disabled")
- Plugin availability: code-review={true/false}
- Autonomy policy: {full_auto/balanced/critical_only} ({user selected / from config default})
- CLI circuit breaker: {initialized for N CLIs / disabled}
- Context protocol: {enabled with initial contributions / disabled}

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

For each loaded optional/expected file, provide a 1-line summary of its key content to give downstream coordinators and agents quick context without re-reading full files:

- **spec.md**: {1-line summary, e.g., "3 user stories covering registration, login, and password reset"}
- **design.md**: {1-line summary, e.g., "Clean architecture with 4 layers, PostgreSQL + Redis stack"}
- **contract.md**: {1-line summary, e.g., "5 REST endpoints, JWT auth, OpenAPI 3.0 format"}
- **data-model.md**: {1-line summary, e.g., "4 entities: User, Session, Token, AuditLog with relations"}
- **research.md**: {1-line summary, e.g., "Chose bcrypt over argon2 for password hashing, Redis for sessions"}
- **test-plan.md**: {1-line summary, e.g., "V-Model strategy: 12 e2e, 25 integration, 40 unit tests planned"}
- **test-strategy.md**: {1-line summary, e.g., "Specify's strategic analysis: 5 risks, 12 testable ACs, 3 critical journeys"}
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

Use ISO 8601 timestamps with seconds precision per `config/implementation-config.yaml` `timestamps` section (e.g., `2026-02-10T14:30:45Z`). Never round to hours or minutes.

- [{timestamp}] Branch parsed: {branch_name}
- [{timestamp}] Context loaded: {N} phases, {M} tasks
- [{timestamp}] Expected file warnings: {list or "none"}
- [{timestamp}] Test cases: {discovered N specs / not available}
- [{timestamp}] Domain detection: {detected_domains list or "disabled"}
- [{timestamp}] CLI availability: {map, e.g., codex=true, gemini=false or "no CLI options enabled"}
- [{timestamp}] MCP availability: ref={bool}, context7={bool}, tavily={bool} (or "research_mcp disabled")
- [{timestamp}] URL extraction: {N} URLs extracted from planning artifacts (or "disabled/skipped")
- [{timestamp}] Library pre-resolution: {N} libraries resolved via Context7 (or "disabled/skipped")
- [{timestamp}] Private docs: {N} private doc URLs discovered (or "disabled/skipped")
- [{timestamp}] Mobile MCP probe: {available with device "{name}" / not available / UAT disabled}
- [{timestamp}] Plugin availability: code-review={true/false}
- [{timestamp}] Autonomy policy: {level_key} ({source: user selected / config default})
- [{timestamp}] Circuit breaker: {initialized for N CLIs / disabled}
- [{timestamp}] Context protocol: {enabled / disabled}
- [{timestamp}] Lock acquired
- [{timestamp}] State initialized / resumed from Stage {S}
```
