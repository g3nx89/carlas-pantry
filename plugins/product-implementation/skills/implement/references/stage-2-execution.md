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
  - "test files (conditional — created by clink test author in Step 1.8 if enabled)"
  - "test files (conditional — created by clink test augmenter in Section 2.1a if enabled)"
  - "source files (conditional — simplified by code-simplifier in Step 3.5 if enabled)"
agents:
  - "product-implementation:developer"
  - "product-implementation:code-simplifier"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/clink-dispatch-procedure.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 2: Phase-by-Phase Execution

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the Stage 1 summary first to obtain FEATURE_NAME, FEATURE_DIR, TASKS_FILE,
> and the list of phases to execute.

## 2.0 Skill Reference Resolution

Before entering the phase loop, resolve domain-specific skill references for developer agent prompts. This step runs ONCE per Stage 2 dispatch, not per phase.

### Procedure

1. Read `detected_domains` from the Stage 1 summary YAML frontmatter
2. If `detected_domains` is empty or not present, set `skill_references` to the fallback text: `"No domain-specific skills available — proceed with standard implementation patterns from the codebase."`  and skip to Section 2.1
3. Read `dev_skills` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
4. If `dev_skills.enabled` is `false`, use fallback text and skip to Section 2.1
5. Build the skill reference list:

   a. Start with `always_include` skills (e.g., `clean-code`)
   b. For each domain in `detected_domains`, look up `domain_mapping[domain].skills` and add them
   c. Deduplicate
   d. Cap at `max_skills_per_dispatch` (default: 3). If more skills matched, keep `always_include` first, then prioritize by order of appearance in `detected_domains`

6. Format `skill_references` as:

```markdown
The following dev-skills are relevant to this implementation domain. Consult their SKILL.md
for patterns, anti-patterns, and decision trees. Read on-demand — do NOT read all upfront.
Codebase conventions (CLAUDE.md, constitution.md) always take precedence over skill guidance.

{for each skill:}
- **{skill_name}**: `$PLUGINS_DIR/{plugin_path}/skills/{skill_name}/SKILL.md` — {reason or domain}
```

Where `$PLUGINS_DIR` resolves to the plugins installation directory and `{plugin_path}` comes from `dev_skills.plugin_path` in config.

### Example Output

```markdown
The following dev-skills are relevant to this implementation domain. Consult their SKILL.md
for patterns, anti-patterns, and decision trees. Read on-demand — do NOT read all upfront.
Codebase conventions (CLAUDE.md, constitution.md) always take precedence over skill guidance.

- **clean-code**: `$PLUGINS_DIR/dev-skills/skills/clean-code/SKILL.md` — Universal code quality patterns
- **kotlin-expert**: `$PLUGINS_DIR/dev-skills/skills/kotlin-expert/SKILL.md` — Kotlin domain patterns
- **api-patterns**: `$PLUGINS_DIR/dev-skills/skills/api-patterns/SKILL.md` — API design patterns
```

### Context Budget

This resolution adds ~5-10 lines to the agent prompt. The agent reads skill files on-demand only when encountering relevant implementation decisions — it does NOT preload all skills into context.

## 2.0a Research Context Resolution

Before entering the phase loop, build the `{research_context}` block for developer agent prompts. This step runs ONCE per Stage 2 dispatch, not per phase.

### Procedure

1. Read `mcp_availability` from the Stage 1 summary YAML frontmatter
2. Read `research_mcp` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
3. If `research_mcp.enabled` is `false` OR all MCP tools are unavailable → set `research_context` to the fallback text from `research_mcp.graceful_degradation.fallback_text` and skip to Section 2.1

4. **Pre-read extracted URLs** (Ref):
   - Read `extracted_urls` from Stage 1 summary
   - For each URL (up to `ref.max_reads_per_stage`): call `ref_read_url(url)` and capture a summary (cap each at `ref.token_budgets.per_source` tokens)
   - If Ref is unavailable, skip this step

5. **Quick Context7 lookup**:
   - Read `resolved_libraries` from Stage 1 summary
   - For each resolved library (up to `context7.max_queries_per_stage`): call `query-docs(library_id, "{relevant_query}")` using the feature's primary use case from plan.md
   - If Context7 is unavailable, skip this step

6. **Pre-read private documentation** (Ref):
   - Read `private_doc_urls` from Stage 1 summary
   - For each URL: call `ref_read_url(url)` and capture key content
   - Counts against `ref.max_reads_per_stage` (shared budget with step 4)

7. **Assemble `{research_context}`**: Combine all gathered content, cap at `ref.token_budgets.research_context_total` tokens. Format as:

```markdown
### Documentation References
{for each pre-read URL:}
- **{source_title}** ({url}): {summary}

### Library Documentation
{for each Context7 query result:}
- **{library_name}**: {key_content}

### Private Documentation
{for each private doc:}
- **{doc_title}**: {key_content}
```

8. **Track discovered URLs**: Collect all URLs successfully read in this step into `research_urls_discovered` list for session accumulation in the Stage 2 summary.

### Context Budget

The assembled `{research_context}` block is capped at `research_context_total` (default: 4000) tokens. Same value reused for all phases within this Stage 2 dispatch.

## 2.1 Phase Loop

For each phase in `tasks.md` (in order), perform these steps:

### Step 1: Parse Phase Tasks

Extract from the current phase section in tasks.md:
- **Task list**: All `- [ ]` entries belonging to this phase
- **Parallel tasks**: Entries with `[P]` marker — can execute concurrently
- **Sequential tasks**: Entries without `[P]` — must execute in listed order
- **File targets**: Extract file paths from task descriptions
- **Dependencies**: Tasks targeting the same file MUST run sequentially regardless of `[P]` marker

### Step 1.8: Clink Test Author (Option H)

> **Conditional**: Only runs when ALL of: `clink_dispatch.stage2.test_author.enabled` is `true`, `test_cases_available` is `true` (from Stage 1 summary), and `cli_availability.codex` is `true` (from Stage 1 summary). If any condition is false, skip to Step 2.

Before launching the developer agent, generate executable tests from test-case specifications using an external coding agent. This creates TDD targets that the developer agent must make pass.

#### Procedure

1. **Identify relevant test-case specs**: Extract test IDs from current phase task descriptions. Map test IDs to spec files in `test-cases/{level}/` (e.g., `UT-001` → `test-cases/unit/UT-001.md`)
2. **If no relevant specs found** for this phase: skip to Step 2 (developer writes its own tests)
3. **Build prompt**: Read the role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/codex_test_author.txt`. Inject variables:
   - `{phase_name}` — current phase name
   - `{test_case_specs}` — content of relevant test-case spec files
   - `{plan_content}` — plan.md content
   - `{contract_content}` — contract.md content (or fallback: `"Not available — infer interfaces from plan.md and task descriptions"`)
   - `{data_model_content}` — data-model.md content (or fallback: `"Not available — infer data model from plan.md"`)
   - `{FEATURE_DIR}`, `{PROJECT_ROOT}` — from Stage 1 summary
4. **Dispatch**: Follow the Shared Clink Dispatch Procedure (`clink-dispatch-procedure.md`) with:
   - `cli_name="codex"`, `role="test_author"`
   - `file_paths=[FEATURE_DIR/test-cases/, plan.md, contract.md, data-model.md, PROJECT_ROOT/src/]`
   - `fallback_behavior="skip"` (developer writes its own tests)
   - `expected_fields=["test_files_created", "total_assertions", "edge_cases_added", "interface_assumptions", "coverage_vs_plan"]`
5. **Verify test files**: Check that test files were created on disk
6. **Run test suite**: All new tests should FAIL (Red phase confirmation)
   - If any test passes unexpectedly: log warning (may be tautological or testing existing functionality)
   - If tests don't compile: pass compilation errors as `{test_compilation_notes}` to developer agent in Step 2
7. **Update Step 2 prompt**: When pre-generated tests exist, modify `{context_summary}` for the developer agent to include:
   - Pre-generated test file locations
   - Instruction: "Pre-generated test files exist at: {list}. Make these tests PASS. You may adjust imports/setup but do NOT change assertions or remove tests."
   - If compilation notes exist: include them as `{test_compilation_notes}`

#### Write Boundaries

The clink agent writes to test directories following the project's existing test file naming conventions. It MUST NOT write to source directories. The coordinator verifies post-dispatch that no source files were created or modified.

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
- `{skill_references}` — Resolved in Section 2.0 above. Same value reused for all phases within this Stage 2 dispatch.

### Step 3: Verify Phase Completion

After agent returns, verify:
1. All tasks in the phase are marked `[X]` in tasks.md
2. No task was skipped or left incomplete
3. Agent reported test results (all passing)
4. No compilation errors reported in agent output (agent must compile after each file change per Build Verification Rule in Section 2.2)
5. Extract `test_count_verified` and `test_failures` from the agent's structured output (see `agent-prompts.md` Phase Implementation Prompt, "Final Step" section). If the agent did not report these values, log a warning: "Developer agent did not report verified test count — cross-validation will be limited."
6. Record the phase-level `test_count_verified` value. The LAST phase's `test_count_verified` becomes the final verified count for all of Stage 2 (since each phase runs the full suite).

If verification fails:
- For sequential task failure: **Halt execution**. Report which task failed and why.
- For parallel task `[P]` failure: Continue with successful tasks, collect failures.

### Step 3.5: Code Simplification (Optional)

> **Conditional**: Only runs when `code_simplification.enabled` is `true` in `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`. If disabled, skip to Step 4.

After phase completion is verified (all tasks `[X]`, tests passing), optionally simplify modified files for clarity and maintainability. This step runs BEFORE auto-commit, so rollback is a safe `git checkout`.

#### Procedure

1. **Check eligibility**:
   - Read `code_simplification` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
   - If `enabled` is `false` → skip to Step 4
   - Collect list of source files modified in this phase: prefer `git diff --name-only` against the pre-phase state for accuracy; fall back to extracting file paths from tasks.md `[X]` entries for the current phase if git diff is unavailable
   - Filter out files matching any pattern in `code_simplification.exclude_patterns` (substring match against file path)
   - If filtered file count is 0 → skip to Step 4 (nothing to simplify)
   - If filtered file count > `code_simplification.max_files_per_phase` → skip to Step 4, log: `"Skipping simplification: {N} files exceeds max_files_per_phase ({max})"`

2. **Dispatch code-simplifier agent**:
   ```
   Task(subagent_type="product-implementation:code-simplifier")
   ```
   Using the Code Simplification Prompt from `agent-prompts.md`. Prefill variables:
   - `{modified_files_list}` — filtered file list from step 1, formatted as a bullet list
   - `{FEATURE_NAME}` — from Stage 1 summary
   - `{FEATURE_DIR}` — from Stage 1 summary
   - `{phase_name}` — current phase name
   - `{skill_references}` — resolved in Section 2.0 (same value as used for the developer agent)

3. **Verify post-simplification**:
   - Extract `test_count_verified`, `test_failures`, `files_simplified`, and `changes_made` from agent output
   - If `test_failures > 0` AND `code_simplification.rollback_on_test_failure` is `true`:
     - Revert all simplification changes: `git checkout -- {modified_files_list}`
     - Log: `"Simplification reverted: {test_failures} test(s) failed after simplification"`
     - Proceed to Step 4 with original (unsimplified) code
   - If `test_failures > 0` AND `rollback_on_test_failure` is `false`:
     - Set `status: needs-user-input`, `block_reason: "Tests failed after code simplification. {test_failures} failures. Review and decide: revert simplification or fix manually."` → return to orchestrator
   - If `test_failures == 0`:
     - Log: `"Simplification complete: {files_simplified} files, {changes_made} changes, all tests passing"`
     - Proceed to Step 4

4. **Track metrics**: Record in phase-level tracking for summary:
   - `simplification_ran: true`
   - `files_simplified: {count}`
   - `changes_made: {count}`
   - `simplification_reverted: false` (or `true` if reverted)

#### Latency Impact

Adds ~5-15s dispatch overhead + 30-120s agent execution per phase. Skipped automatically when disabled, when no eligible files exist, or when file count exceeds threshold.

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

### Step 4.5: Auto-Commit Phase

After updating progress, optionally commit the phase's changes.

If `auto_commit.stage2_strategy` is `batch` in config, skip this step — a single commit runs after all phases complete (Step 5).

Otherwise (`per_phase`, the default), follow the Auto-Commit Dispatch Procedure in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/auto-commit-dispatch.md` with:

| Parameter | Value |
|-----------|-------|
| `template_key` | `phase_complete` |
| `substitution_vars` | `{feature_name}` = FEATURE_NAME, `{phase_name}` = current phase name (raw from tasks.md, e.g., "Phase 1: Setup") |
| `skip_target` | Step 5 |
| `summary_field` | Append to `commits_made` array |

### Step 5: Repeat or Proceed

- If more phases remain → return to Step 1 for next phase
- If all phases complete:
  - If `auto_commit.stage2_strategy` is `batch` and `auto_commit.enabled` is `true`: follow the Auto-Commit Dispatch Procedure in `auto-commit-dispatch.md` with `template_key` = `phase_batch`, `substitution_vars` = `{feature_name}` = FEATURE_NAME, `skip_target` = Section 2.3, `summary_field` = `commits_made` (single-element array)
  - Write Stage 2 summary and return to orchestrator

## 2.1a Clink Test Augmenter (Option I)

> **Conditional**: Only runs when ALL of: `clink_dispatch.stage2.test_augmenter.enabled` is `true`, `cli_availability.gemini` is `true` (from Stage 1 summary), and all phases have completed successfully. If any condition is false, skip to Section 2.2.

After all phases complete but before writing the Stage 2 summary, run an edge case discovery pass using an external model with full visibility into all implemented code and tests.

### Procedure

1. **Collect modified files**: Gather all source files and test files modified or created during Stage 2 (from tasks.md `[X]` entries and any test files written in Step 1.8 or by developer agents)
2. **Build prompt**: Read the role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_test_augmenter.txt`. Inject variables:
   - `{modified_source_files}` — list of source files modified during Stage 2
   - `{modified_test_files}` — list of test files modified during Stage 2
   - `{max_additional_tests}` — from config `clink_dispatch.stage2.test_augmenter.max_additional_tests` (default: 10)
   - `{focus_areas}` — from config `clink_dispatch.stage2.test_augmenter.focus` (default: `["boundary", "error", "concurrency", "security"]`)
   - `{FEATURE_DIR}` — from Stage 1 summary
3. **Dispatch**: Follow the Shared Clink Dispatch Procedure (`clink-dispatch-procedure.md`) with:
   - `cli_name="gemini"`, `role="test_augmenter"`
   - `file_paths=[...modified_source_files, ...modified_test_files]`
   - `fallback_behavior="skip"`
   - `expected_fields=["tests_added", "bug_discoveries", "coverage_improvements", "top_risk_area"]`
4. **Parse bug discoveries**: If the output contains a "Bug Discoveries" section with tests expected to FAIL:
   - Run those specific tests and confirm actual failures
   - Record confirmed bug discoveries in `augmentation_bugs_found` for the Stage 2 summary
   - If all augmented tests PASS: record as coverage improvements (no bugs found)
5. **Run full test suite**: Update `test_count_verified` with the post-augmentation count
6. **If clink fails, CLI unavailable, or times out**: skip silently — no impact on main workflow

### Output

Adds to Stage 2 summary flags:
- `augmentation_bugs_found: {count}` — number of confirmed bug discoveries from test augmentation (0 if skipped or no bugs found)

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

### Build Verification

The developer agent must compile/build the project after writing or modifying each source file, before marking the corresponding task `[X]`. This is enforced via the Phase Implementation Prompt (see `agent-prompts.md`). The coordinator verifies compliance in Step 3: if the agent's output indicates compilation failures, the phase is NOT complete.

### Error Handling

| Error Type | Action |
|-----------|--------|
| Sequential task fails | Halt phase. Report error with task ID, description, and error message. Suggest fix or manual intervention. |
| Parallel task fails | Continue other parallel tasks. Collect failure. Report all failures at phase end. |
| Agent crashes | Retry once with same prompt. If second failure, halt with full error context. |
| Tests fail after implementation | Agent retries fix internally (part of developer agent self-critique). If still failing after agent completes, report to orchestrator. |
| Build error with MCP available | Agent uses build error smart resolution (see below). |
| tasks.md corrupted | Re-read from disk. If unrecoverable, halt with guidance to check git history. |

### Build Error Smart Resolution (MCP-Assisted)

When a build or compilation error occurs and MCP tools are available (per `mcp_availability` from Stage 1 summary), the developer agent can use research tools to diagnose and fix the error. This is controlled by `research_mcp.build_error_resolution` in config.

**Strategy: `ref_first`** (default):

1. **Ref lookup**: Call `ref_search_documentation("{library} {error_terms}")` using the library name and key error terms. If results are found, call `ref_read_url(best_result)` for the fix details.
2. **Context7 fallback** (after `escalation_after` failed Ref lookups, default 1): Call `query-docs(library_id, "error {error_terms}")` using the pre-resolved library ID from Stage 1 summary.
3. **Tavily last resort** (after all above fail): Call `tavily_search("{library} {version} {error_message}")` with `search_depth` and `max_results` from config.

**Budget**: Maximum `max_retries` (default 2) MCP lookup attempts per build error. If all attempts fail, the agent reports the error normally (no MCP-assisted fix).

**Note**: This resolution is performed by the developer agent itself within its implementation context — the coordinator does not make MCP calls for error resolution. The agent's Research MCP Awareness section (in `agents/developer.md`) describes how to use these tools.

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
  - "augmented test files (conditional — from clink test augmenter Section 2.1a if enabled)"
summary: |
  Executed {N}/{M} phases. {X} tasks completed, {Y} tasks remaining.
  All tests passing: {yes/no}.
  {Error details if halted}.
flags:
  block_reason: null  # or description of error if needs-user-input
  test_count_verified: {N}  # Verified test count from last phase's developer agent final test run (null if agent did not report)
  commits_made: ["sha1", "sha2"]  # Array: one SHA per phase (per_phase strategy) or single SHA (batch). Stages 4/5 use scalar commit_sha instead.
  research_urls_discovered: []  # URLs successfully read during research context resolution (Section 2.0a). Consumed by Stages 4/5 for session accumulation.
  augmentation_bugs_found: 0    # Confirmed bug discoveries from clink test augmenter (Section 2.1a). 0 if skipped or no bugs found.
  simplification_stats: null     # null if code_simplification.enabled is false.
    # When enabled, replace null with an object containing these keys:
    # phases_simplified: {N}     — Phases where simplification ran successfully
    # phases_skipped: {N}        — Phases where simplification was skipped (too many files, no eligible files, disabled)
    # phases_reverted: {N}       — Phases where simplification was reverted due to test failure
    # total_files_simplified: {N} — Sum of files_simplified across all phases
    # total_changes_made: {N}    — Sum of changes_made across all phases
---
## Context for Next Stage

- Phases completed: {list}
- Tasks completed: {count}/{total}
- Tests status: all passing / {N} failures
- Verified test count: {N} (from last phase's developer agent report)
- Commits: {count} auto-commits ({list of SHAs or "disabled"})
- Files modified: {list of key files}
- Errors encountered: {none / list}

## Stage Log

Use ISO 8601 timestamps with seconds precision per `config/implementation-config.yaml` `timestamps` section (e.g., `2026-02-10T14:30:45Z`). Never round to hours or minutes.

- [{timestamp}] Phase 1: {phase_name} — {task_count} tasks completed — commit: {sha or skipped}
- [{timestamp}] Phase 2: {phase_name} — {task_count} tasks completed — commit: {sha or skipped}
- ...
```
