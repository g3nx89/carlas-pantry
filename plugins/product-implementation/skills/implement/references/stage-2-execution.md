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
  - "test files (conditional — created by CLI test author in Step 1.8 if enabled)"
  - "test files (conditional — created by CLI test augmenter in Section 2.1a if enabled)"
  - "source files (conditional — simplified by code-simplifier in Step 3.5 if enabled)"
  - ".uat-evidence/ (conditional — screenshots from UAT mobile testing in Step 3.7 if enabled)"
agents:
  - "product-implementation:developer"
  - "product-implementation:code-simplifier"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/cli-dispatch-procedure.md"
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

### Step 1.8: CLI Test Author (Option H)

> **Conditional**: Only runs when ALL of: `cli_dispatch.stage2.test_author.enabled` is `true`, `test_cases_available` is `true` (from Stage 1 summary), and `cli_availability.codex` is `true` (from Stage 1 summary). If any condition is false, skip to Step 2.

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
4. **Dispatch**: Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
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

The CLI agent writes to test directories following the project's existing test file naming conventions. It MUST NOT write to source directories. The coordinator verifies post-dispatch that no source files were created or modified.

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
     - **Check autonomy policy** (read `autonomy_policy` from Stage 1 summary):
       - If `autonomy_policy` is `full_auto` or `balanced` or `critical_only`: Auto-revert simplification changes (`git checkout -- {modified_files_list}`), log: `"[AUTO-{policy}] Simplification auto-reverted: {test_failures} test(s) failed"`. Proceed to Step 4.
       - *(All policy levels auto-revert here because simplification test failure is an infrastructure/tooling issue — the simplifier broke working code — not a severity-based finding. Reverting restores the known-good state with zero risk.)*
       - Otherwise (no policy set, edge case): Set `status: needs-user-input`, `block_reason: "Tests failed after code simplification. {test_failures} failures. Review and decide: revert simplification or fix manually."` → return to orchestrator
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

### Step 3.6: UX Test Coverage Review (Optional)

> **Conditional**: Only runs when ALL of:
>   1. `cli_dispatch.stage2.ux_test_reviewer.enabled` is `true`
>   2. `cli_availability.opencode` is `true` (from Stage 1 summary)
>   3. Phase touches UI files (task file paths match any domain in `ux_test_reviewer.phase_relevance.ui_domains`)
> If any condition is false, skip this step silently.

After tests are written and passing (Step 3), dispatch OpenCode to review test coverage for UX scenarios: empty states, loading states, error states, and accessibility assertions.

#### Procedure

1. **Phase relevance check**: Check if ANY task file path in the current phase matches UI domain indicators from `cli_dispatch.stage2.ux_test_reviewer.phase_relevance.ui_domains` (resolved via `dev_skills.domain_mapping` indicators). If no match, skip.

2. **Collect test files**: List all test files created or modified in this phase (from Step 3 output).

3. **Dispatch**: Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="opencode"`, `role="ux_test_reviewer"`
   - `fallback_behavior` from `cli_dispatch.stage2.ux_test_reviewer.fallback_behavior` (default: `"skip"`)
   - `expected_fields=["test_files_reviewed", "components_covered", "ux_scenario_gaps", "top_gap"]`

4. **Coordinator-Injected Context** (appended per `cli-dispatch-procedure.md` variable injection convention):
   - `{phase_name}` — current phase name
   - `{FEATURE_DIR}` — feature directory
   - `{PROJECT_ROOT}` — project root
   - `{test_files}` — list of test files created/modified in this phase
   - `{source_files}` — list of source files the tests cover
   - `{skill_references}` — resolved in Section 2.0 (or fallback text)

5. **Result processing**: Parse `<SUMMARY>` block. If UX scenario gaps are found:
   - `[High]` gaps (missing accessibility tests on interactive components): log finding, include in phase metrics
   - `[Medium]`/`[Low]` gaps (missing empty/loading state tests): log as warning, continue
   - Gaps do NOT block phase progression — they are advisory for awareness

6. **If CLI fails, CLI unavailable, or times out**: follow `fallback_behavior` — default `"skip"` means continue without review, log warning

#### Latency Impact

Adds ~5-15s dispatch overhead + 30-90s agent execution per relevant phase. Skipped automatically when disabled, when OpenCode is unavailable, or when phase has no UI files.

### Step 3.7: UAT Mobile Testing (Optional)

> **Conditional**: Only runs when ALL of:
>   1. `uat_execution.enabled` is `true` (master switch from config)
>   2. `cli_dispatch.stage2.uat_mobile_tester.enabled` is `true`
>   3. `cli_availability.gemini` is `true` (from Stage 1 summary)
>   4. `mobile_mcp_available` is `true` (from Stage 1 summary)
>   5. Phase has mapped UAT specs OR touches UI files (see relevance check below)
> If any condition is false, check the Non-Skippable Gate rule below before skipping.

#### Non-Skippable Gate Check

Before skipping UAT, check if `"stage2.uat_mobile_tester"` appears in `cli_dispatch.non_skippable_gates` from config. If it does:

- **Conditions 1-2 false** (master switches disabled): Skip silently — the user explicitly disabled this dispatch.
- **Conditions 3-4 false** (prerequisites unavailable): Log a structured gate failure: `"[GATE_BLOCKED] Non-skippable gate 'stage2.uat_mobile_tester' cannot execute: {reason}. Prerequisites: gemini={cli_availability.gemini}, mobile_mcp={mobile_mcp_available}."` This failure is recorded in the Stage 2 summary for KPI tracking. Do NOT silently skip.
- **Condition 5 false** (phase not relevant): Skip silently — irrelevant phases are not a gate failure.

If `"stage2.uat_mobile_tester"` is NOT in `non_skippable_gates`, skip to Step 4 with a standard warning log.

After code completion (and optional simplification), run behavioral acceptance testing and Figma visual verification against the running app on a Genymotion emulator. The coordinator handles APK build and install; the CLI agent handles testing.

#### Phase Relevance Check

Determine if the current phase warrants UAT testing:

1. **UAT test ID check** (if `uat_mobile_tester.phase_relevance.check_uat_test_ids` is `true`):
   - Extract test IDs from current phase task descriptions
   - Filter for `UAT-*` pattern (from `handoff.test_cases.test_id_patterns`)
   - Map each `UAT-{ID}` to `{FEATURE_DIR}/test-cases/uat/UAT-{ID}.md`
   - If at least one UAT spec file exists for this phase → `uat_relevant = true`

2. **UI file path check** (if `uat_mobile_tester.phase_relevance.check_ui_file_paths` is `true`):
   - Collect file paths from current phase task descriptions
   - Check against domain indicators for domains listed in `uat_mobile_tester.phase_relevance.ui_domains` (resolved via `dev_skills.domain_mapping` in config)
   - If any file path matches a UI domain indicator → `uat_relevant = true`

3. If neither check matches → skip to Step 4, log: `"Phase '{phase_name}' has no UAT specs or UI files — skipping UAT"`

#### APK Build

1. Read build config from `cli_dispatch.stage2.uat_mobile_tester.gradle_build`
2. Run the build command:
   ```
   Bash("{gradle_build.command}")
   ```
   With timeout: `gradle_build.timeout_ms` (default: 180000 = 3 minutes)
3. If build fails: log warning `"Gradle build failed — skipping UAT for phase '{phase_name}'"`, skip to Step 4
4. Locate APK: use `Glob("{gradle_build.apk_search_pattern}")` to find the built APK
5. If no APK found: log warning `"No APK found matching '{apk_search_pattern}' — skipping UAT"`, skip to Step 4
6. Store `apk_path` for injection into CLI prompt

#### APK Install

1. Read install config from `uat_execution.apk_install`
2. If `uat_execution.apk_install.reinstall` is `true`:
   - Call `mobile_terminate_app` with `app_package` (if app running, ignore errors)
   - Call `mobile_uninstall_app` with `app_package` (if installed, ignore errors)
3. Call `mobile_install_app` with the located APK path
4. If install fails: log warning `"APK install failed — skipping UAT for phase '{phase_name}'"`, skip to Step 4
5. If `uat_execution.apk_install.launch_after_install` is `true`:
   - Determine `app_package`: use `uat_execution.apk_install.app_package` from config if set, otherwise auto-detect from APK via `aapt dump badging {apk_path}` or similar
   - Call `mobile_launch_app` with `app_package`
   - Wait 3-5 seconds for app initialization

#### Evidence Directory Setup

Create the evidence directory for this phase:
```
mkdir -p {FEATURE_DIR}/{uat_mobile_tester.evidence_dir}/{phase_name_sanitized}/
```
Where `phase_name_sanitized` converts the phase name to a safe directory name (lowercase, non-alphanumeric replaced with hyphens, e.g., "Phase 1: Setup" → "phase-1-setup").

#### CLI Dispatch

1. **Collect UAT specs**: Read content of all matched UAT spec files for this phase (from the relevance check above). If no specific specs matched but the phase was deemed relevant via UI file paths, use all available UAT specs from `{FEATURE_DIR}/test-cases/uat/` as context.

2. **Build prompt**: Read the role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_uat_mobile_tester.txt`

3. **Dispatch**: Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="gemini"`, `role="uat_mobile_tester"`
   - `file_paths=[FEATURE_DIR/test-cases/uat/, FEATURE_DIR, PROJECT_ROOT]`
   - `timeout_ms` from `cli_dispatch.stage2.uat_mobile_tester.timeout_ms` (default: 600000 = 10 minutes)
   - `fallback_behavior` from `cli_dispatch.stage2.uat_mobile_tester.fallback_behavior` (default: `"skip"`)
   - `expected_fields=["total_scenarios", "passed", "failed", "blocked", "critical_issues", "visual_mismatches", "recommendation"]`

4. **Coordinator-Injected Context** (appended per `cli-dispatch-procedure.md` variable injection convention):
   - `{phase_name}` — current phase name
   - `{FEATURE_DIR}` — feature directory
   - `{PROJECT_ROOT}` — project root
   - `{uat_spec_content}` — content of matched UAT spec files (concatenated, with file headers)
   - `{apk_path}` — path to the built APK
   - `{evidence_dir}` — full path to `{FEATURE_DIR}/{evidence_dir}/{phase_name_sanitized}/`
   - `{mobile_device_name}` — from Stage 1 summary
   - `{figma_default_url}` — from `uat_mobile_tester.figma.default_node_url` config (or `"Not provided"`)
   - `{app_package}` — from `uat_execution.apk_install.app_package` config (or `"Auto-detected from APK"`)

5. **MCP Tool Budget** (appended per standard convention, values from `cli_dispatch.mcp_tool_budgets.per_cli_dispatch`):
   ```
   ## MCP Tool Budget (Advisory)
   - Mobile MCP: max {mobile_mcp.max_screenshots} screenshots, {mobile_mcp.max_interactions} interactions, {mobile_mcp.max_device_queries} device queries
   - Figma: max {figma.max_calls} calls
   - Sequential Thinking: max {sequential_thinking.max_chains} chains
   ```

#### Result Processing

1. **Parse `<SUMMARY>` block**: Extract `total_scenarios`, `passed`, `failed`, `blocked`, `critical_issues`, `visual_mismatches`, `recommendation`

2. **Severity gating** (from `cli_dispatch.stage2.uat_mobile_tester.severity_gating`):
   - If `recommendation` is `"PASS"` or `"PASS_WITH_NOTES"` and no `[Critical]` or `[High]` findings:
     - Log: `"UAT passed for phase '{phase_name}': {passed}/{total_scenarios} scenarios, {visual_mismatches} visual mismatches"`
     - Proceed to Step 4
   - If findings are `[Medium]` or `[Low]` only:
     - Log warning: `"UAT found {count} medium/low findings in phase '{phase_name}' — continuing"`
     - Proceed to Step 4
   - If `critical_issues > 0` OR raw output contains `[Critical]` or `[High]` findings:
     - **Check autonomy policy** (read `autonomy_policy` from Stage 1 summary, read policy level from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml` `autonomy_policy.levels.{policy}`):
       - **Categorize findings by severity**: separate `[Critical]` findings from `[High]` findings
       - **Per-severity iteration** (matches Stage 4 pattern): for each severity level present (`critical`, then `high`), look up `policy.findings.{severity}` action and build action lists:
         - Findings where action is `"fix"` → add to `fix_list`
         - Findings where action is `"defer"` → add to `defer_list`
         - Findings where action is `"accept"` → add to `accept_list`
       - **Apply fix_list** (if non-empty): Launch developer agent to address these specific findings, log: `"[AUTO-{policy}] UAT {severity} findings — auto-fixing for phase '{phase_name}'"`. After fix, re-build and re-run UAT (one retry). If retry still fails for these findings, persist them to `{FEATURE_DIR}/review-findings.md` (append under a `## UAT Findings — {phase_name}` section), log warning.
       - **Apply defer_list** (if non-empty): Persist findings to `{FEATURE_DIR}/review-findings.md` (append under a `## UAT Findings — {phase_name}` section), log: `"[AUTO-{policy}] UAT {severity} findings deferred for phase '{phase_name}'"`.
       - **Apply accept_list** (if non-empty): Log: `"[AUTO-{policy}] UAT {severity} findings accepted for phase '{phase_name}'"`.
       - After processing all severity levels → proceed to Step 4
       - If no policy set (edge case): fall through to manual escalation below
     - **Manual escalation** (when no autonomy policy applies):
       - Set `status: needs-user-input`
       - Set `block_reason: "UAT testing found critical/high issues in phase '{phase_name}': {critical_issues} critical issue(s), {failed} scenario(s) failed. Review findings and decide: fix implementation / skip UAT for this phase / proceed anyway."`
       - Include the raw findings section from CLI output in the block_reason for user context
       - Return to orchestrator (orchestrator mediates user interaction per standard protocol)

3. **If CLI fails, CLI unavailable, or times out**: follow `fallback_behavior` — default `"skip"` means continue without UAT results, log warning

4. **Track metrics**: Record in phase-level tracking for summary:
   - `uat_ran: true`
   - `uat_scenarios: {total_scenarios}`
   - `uat_passed: {passed}`
   - `uat_failed: {failed}`
   - `uat_blocked: {blocked}`
   - `uat_visual_mismatches: {visual_mismatches}`
   - `uat_recommendation: {recommendation}`

#### Write Boundaries

The CLI agent writes ONLY screenshot files to the evidence directory (`{FEATURE_DIR}/{evidence_dir}/{phase_name_sanitized}/`). It MUST NOT write to source directories, test directories, or spec directories. The coordinator verifies post-dispatch that no files outside the evidence directory were created or modified.

#### Latency Impact

Adds ~30-60s for Gradle build + ~10-30s for APK install + ~120-600s for UAT execution per phase. Total overhead per relevant phase: ~3-10 minutes. Skipped automatically when disabled, when no relevant UAT specs or UI files exist for the phase, when mobile-mcp is unavailable, or when Gemini CLI is not installed.

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

## 2.1a CLI Test Augmenter (Option I)

> **Conditional**: Only runs when ALL of: `cli_dispatch.stage2.test_augmenter.enabled` is `true`, `cli_availability.gemini` is `true` (from Stage 1 summary), and all phases have completed successfully. If any condition is false, skip to Section 2.2.

After all phases complete but before writing the Stage 2 summary, run an edge case discovery pass using an external model with full visibility into all implemented code and tests.

### Procedure

1. **Collect modified files**: Gather all source files and test files modified or created during Stage 2 (from tasks.md `[X]` entries and any test files written in Step 1.8 or by developer agents)
2. **Build prompt**: Read the role prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_test_augmenter.txt`. Inject variables:
   - `{modified_source_files}` — list of source files modified during Stage 2
   - `{modified_test_files}` — list of test files modified during Stage 2
   - `{max_additional_tests}` — from config `cli_dispatch.stage2.test_augmenter.max_additional_tests` (default: 10)
   - `{focus_areas}` — from config `cli_dispatch.stage2.test_augmenter.focus` (default: `["boundary", "error", "concurrency", "security"]`)
   - `{FEATURE_DIR}` — from Stage 1 summary
3. **Dispatch**: Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
   - `cli_name="gemini"`, `role="test_augmenter"`
   - `file_paths=[...modified_source_files, ...modified_test_files]`
   - `fallback_behavior="skip"`
   - `expected_fields=["tests_added", "bug_discoveries", "coverage_improvements", "top_risk_area"]`
4. **Parse bug discoveries**: If the output contains a "Bug Discoveries" section with tests expected to FAIL:
   - Run those specific tests and confirm actual failures
   - Record confirmed bug discoveries in `augmentation_bugs_found` for the Stage 2 summary
   - If all augmented tests PASS: record as coverage improvements (no bugs found)
5. **Run full test suite**: Update `test_count_verified` with the post-augmentation count
6. **If CLI fails, CLI unavailable, or times out**: skip silently — no impact on main workflow

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
  - "augmented test files (conditional — from CLI test augmenter Section 2.1a if enabled)"
  - ".uat-evidence/ (conditional — from UAT mobile testing Step 3.7 if enabled)"
summary: |
  Executed {N}/{M} phases. {X} tasks completed, {Y} tasks remaining.
  All tests passing: {yes/no}.
  {Error details if halted}.
flags:
  block_reason: null  # or description of error if needs-user-input
  test_count_verified: {N}  # Verified test count from last phase's developer agent final test run (null if agent did not report)
  commits_made: ["sha1", "sha2"]  # Array: one SHA per phase (per_phase strategy) or single SHA (batch). Stages 4/5 use scalar commit_sha instead.
  research_urls_discovered: []  # URLs successfully read during research context resolution (Section 2.0a). Consumed by Stages 4/5 for session accumulation.
  augmentation_bugs_found: 0    # Confirmed bug discoveries from CLI test augmenter (Section 2.1a). 0 if skipped or no bugs found.
  simplification_stats: null     # null if code_simplification.enabled is false.
    # When enabled, replace null with an object containing these keys:
    # phases_simplified: {N}     — Phases where simplification ran successfully
    # phases_skipped: {N}        — Phases where simplification was skipped (too many files, no eligible files, disabled)
    # phases_reverted: {N}       — Phases where simplification was reverted due to test failure
    # total_files_simplified: {N} — Sum of files_simplified across all phases
    # total_changes_made: {N}    — Sum of changes_made across all phases
  cli_dispatch_metrics: null      # null if no CLI dispatches occurred. When CLI dispatches ran, replace with:
    # dispatches_total: {N}        — Total CLI dispatch invocations across all phases
    # dispatches_succeeded: {N}    — Dispatches that returned exit code 0
    # dispatches_fallback: {N}     — Dispatches that fell back to native agents
    # tier_distribution: {1: N, 2: N, 3: N, 4: N}  — Count of dispatches by output extraction tier
    # total_timeout_ms: {N}        — Sum of dispatch durations
  cli_circuit_state: null     # Updated by CLI dispatches in this stage
  context_contributions: null # When context_protocol enabled, populate with:
    # key_decisions: phase completion decisions, build/test strategy choices
    # open_issues: unresolved build warnings, deferred test failures
    # risk_signals: flaky tests, high-complexity files touched, coverage gaps
  uat_results: null              # null if UAT mobile testing disabled or not applicable for any phase.
    # When enabled and run on at least one phase, replace null with an object containing these keys:
    # phases_tested: {N}           — Phases where UAT ran successfully
    # phases_skipped: {N}          — Phases where UAT was skipped (not relevant, build failure, etc.)
    # total_scenarios: {N}         — Sum of scenarios across all phases
    # total_passed: {N}            — Sum of passed scenarios
    # total_failed: {N}            — Sum of failed scenarios
    # total_blocked: {N}           — Sum of blocked scenarios
    # total_visual_mismatches: {N} — Sum of visual mismatches (major + minor)
    # critical_issues: {N}         — Total critical/high issues found across all phases
    # evidence_dir: "{path}"       — Base evidence directory path (FEATURE_DIR/.uat-evidence/)
---
## Context for Next Stage

- Phases completed: {list}
- Tasks completed: {count}/{total}
- Tests status: all passing / {N} failures
- Verified test count: {N} (from last phase's developer agent report)
- Commits: {count} auto-commits ({list of SHAs or "disabled"})
- Files modified: {list of key files}
- Errors encountered: {none / list}
- UAT results: {phases_tested}/{phases_total} phases tested, {total_passed}/{total_scenarios} scenarios passed, {total_visual_mismatches} visual mismatches (or "disabled" or "not applicable — no relevant phases")

## Stage Log

Use ISO 8601 timestamps with seconds precision per `config/implementation-config.yaml` `timestamps` section (e.g., `2026-02-10T14:30:45Z`). Never round to hours or minutes.

- [{timestamp}] Phase 1: {phase_name} — {task_count} tasks completed — commit: {sha or skipped}
- [{timestamp}] Phase 2: {phase_name} — {task_count} tasks completed — commit: {sha or skipped}
- ...
```
