---
stage: "3"
stage_name: "Completion Validation"
checkpoint: "VALIDATION"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-1-summary.md"
  - ".stage-summaries/stage-2-summary.md"
artifacts_read:
  - "tasks.md"
  - "plan.md"
  - "spec.md"
  - "test-cases/ (if test_cases_available)"
  - "analysis/task-test-traceability.md (if exists)"
artifacts_written:
  - ".implementation-state.local.md (updated stage)"
agents:
  - "product-implementation:developer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/cli-dispatch-procedure.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 3: Completion Validation

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read the prior stage summaries first to understand execution results.

## 3.1 Validation Agent

Launch a `developer` agent for comprehensive validation using the prompt template from `agent-prompts.md` (Section: Completion Validation Prompt).

```
Task(subagent_type="product-implementation:developer")
```

**Key variables to prefill:**
- `{FEATURE_NAME}` — From Stage 1 summary
- `{FEATURE_DIR}` — From Stage 1 summary
- `{TASKS_FILE}` — From Stage 1 summary
- `{user_input}` — Original user arguments (if any)
- `{test_cases_dir}` — If Stage 1 summary has `test_cases_available: true`, set to `{FEATURE_DIR}/test-cases/`. Otherwise set to `"Not available"`.
- `{traceability_file}` — If `analysis/task-test-traceability.md` was loaded per Stage 1 summary, set to `{FEATURE_DIR}/analysis/task-test-traceability.md`. Otherwise set to `"Not available"`.
- `{research_context}` — If `mcp_availability` from Stage 1 summary shows Context7 available AND `resolved_libraries` is non-empty: call `query-docs` for key libraries with query `"API signatures common pitfalls"` (up to `context7.max_queries_per_stage`). Assemble into `{research_context}`. If MCP is unavailable or disabled, use fallback: `"No research context available — proceed with codebase knowledge and planning artifacts only."`

## 3.1a CLI Spec Validator (Option C)

> **Conditional**: Only runs when ALL of: `cli_dispatch.stage3.spec_validator.enabled` is `true` and `cli_availability.gemini` is `true` (from Stage 1 summary). If any condition is false, skip to Section 3.2.

Launch a cross-model spec validator in **parallel** with the native validation agent (Section 3.1). The CLI validator independently verifies implementation against specifications using a different model, providing a second perspective.

### Procedure

1. **Dispatch both in parallel**:
   - **Native**: `Task(subagent_type="product-implementation:developer")` with the Completion Validation Prompt (already dispatched in Section 3.1)
   - **CLI**: Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_spec_validator.txt`. Inject variables:
     - `{FEATURE_DIR}`, `{PROJECT_ROOT}` — from Stage 1 summary
     - `{spec_content}` — spec.md content (or tasks.md ACs if spec.md unavailable)
     - `{plan_content}` — plan.md content
     - `{tasks_content}` — tasks.md content
     - `{test_cases_dir}` — path to test-cases/ directory (or `"Not available"`)
   - Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
     - `cli_name="gemini"`, `role="spec_validator"`
     - `file_paths=[FEATURE_DIR, PROJECT_ROOT]`
     - `fallback_behavior="skip"` (native validator is always running)
     - `expected_fields=["requirements", "tests", "baseline_test_count", "gaps", "recommendation"]`

2. **Wait for both to complete**

3. **Merge results**:
   - **Both agree**: high confidence, proceed with combined findings (deduplicated)
   - **Both find same gaps**: consolidated, deduplicated by file:line matching
   - **Disagreement on a requirement**: mark as "NEEDS MANUAL REVIEW", add to `block_reason` for Critical/High items

4. **`baseline_test_count`**: Use the LOWER of the two independently verified counts (conservative approach per `merge_strategy: "conservative"` in config)

5. **If CLI fails or CLI unavailable**: native validation result used alone — no degradation from current behavior

### Impact on Section 3.2

When both validators run, Section 3.2 validation checks operate on the **merged** result set. Disagreements appear as additional findings with the "NEEDS MANUAL REVIEW" label.

## 3.1b CLI UX Validator (Option D)

> **Conditional**: Only runs when ALL of: `cli_dispatch.stage3.ux_validator.enabled` is `true` and `cli_availability.opencode` is `true` (from Stage 1 summary). If any condition is false, skip to Section 3.2.

Launch a UX completeness validator in **parallel** with the native validation agent (Section 3.1) and Gemini spec validator (Section 3.1a if enabled). The OpenCode validator independently verifies implementation completeness from a UX/accessibility perspective: state coverage, user flows, accessibility attributes, and error recovery paths.

### Procedure

1. **Dispatch in parallel** with Sections 3.1 and 3.1a:
   - Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/opencode_ux_validator.txt`. Inject variables:
     - `{FEATURE_DIR}`, `{PROJECT_ROOT}` — from Stage 1 summary
     - `{spec_content}` — spec.md content (or tasks.md ACs if spec.md unavailable)
     - `{tasks_content}` — tasks.md content
     - `{detected_domains}` — from Stage 1 summary
   - Follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`) with:
     - `cli_name="opencode"`, `role="ux_validator"`
     - `file_paths=[FEATURE_DIR, PROJECT_ROOT]`
     - `fallback_behavior="skip"` (native validator is always running)
     - `expected_fields=["user_flows_verified", "state_coverage", "accessibility_checks", "gaps", "recommendation"]`

2. **Wait for all dispatched validators to complete**

3. **Merge results**:
   - UX gaps from OpenCode are added to the merged finding set
   - If OpenCode reports missing states (loading, error, empty) that the native validator didn't flag, add them as new findings
   - Disagreements on completeness: mark as "NEEDS MANUAL REVIEW" for Critical/High items

4. **If CLI fails or CLI unavailable**: native validation result used alone — no UX-specific validation, no degradation

### Impact on Section 3.2

When the UX validator runs, its findings (missing states, accessibility gaps) are included in the merged validation result. Section 3.2 validation checks operate on the full merged set.

## 3.2 Validation Checks

The validation agent verifies:

1. **Task completeness**: Every task in tasks.md is marked `[X]`
2. **Specification alignment**: Implemented features match the original spec
3. **Test coverage**: All tests pass, coverage meets project requirements
4. **Plan adherence**: Implementation follows the technical plan (architecture, patterns, file structure)
5. **Integration integrity**: All components integrate correctly
6. **Test ID traceability** *(conditional — only if Stage 1 summary has `test_cases_available: true`)*: Verify that test IDs referenced in tasks.md have both (a) corresponding test-case spec files in `test-cases/` and (b) implemented test files in the codebase. Report any test IDs that are specified but not implemented, or implemented but not specified.
7. **Constitution compliance** *(conditional — only if `constitution.md` or `CLAUDE.md` exists at the project root)*: Verify that the implementation adheres to architectural constraints declared in these files (e.g., layering rules, dependency directions, naming conventions). Flag violations as High severity — constitution documents are project contracts.
8. **Test coverage delta** *(conditional — only if `test-plan.md` is available)*: Count implemented automated tests by level (unit, integration, e2e). Compare against planned targets from test-plan.md. Report delta as `{implemented}/{planned} {level} ({pct}%)`. Apply thresholds from `config/implementation-config.yaml` under `test_coverage.thresholds`: if unit tests < `unit_minimum_pct` (default 80%), flag High; if any other level < `other_minimum_pct` (default 50%), flag Medium.
8b. **Strategy risk alignment** *(conditional — only if `test-strategy.md` is available)*: Cross-reference critical/high risks from test-strategy.md against implemented test coverage. For each risk area, verify at least one test addresses it. Report uncovered risks as Medium severity. If test-plan.md Section 10 (Strategy Traceability) exists, validate that claimed coverage matches actual implementation.
9. **Independent test count verification**: Run the full test suite independently (do not rely on Stage 2's count) and record the result as `baseline_test_count`. This becomes the reference for Stage 4 post-fix validation.
10. **Stage 2 cross-validation** *(conditional — only if Stage 2 summary has `test_count_verified` in flags)*: Compare the independently verified `baseline_test_count` against Stage 2's `test_count_verified`. If the values differ, log a warning: "Test count discrepancy: Stage 2 reported {test_count_verified} but independent verification found {baseline_test_count}. Investigate possible agent reporting error." The `baseline_test_count` (independently verified) takes precedence.
11. **Test quality gate** *(always runs)*: Scan all test files created or modified during implementation for tautological/placeholder assertions. Use patterns from `config/implementation-config.yaml` under `test_coverage.tautological_patterns`. For each test file: if ALL assertions match tautological patterns (no substantive assertions), flag the file. If flagged file count >= `placeholder_file_threshold_high` (default 2), flag as **High** severity: "Placeholder tests detected: {N} test file(s) contain only tautological assertions ({file_list})." If count > 0 but below threshold, flag as Medium.
12. **API documentation alignment** *(advisory, optional — only if `{research_context}` is provided)*: Cross-check implemented API usage (method signatures, parameter types, return values) against the documentation excerpts in `{research_context}`. Flag discrepancies as **Low** severity (advisory). This check uses Context7 library docs when available. If `{research_context}` is absent, skip this check entirely.

## 3.3 Validation Report

Agent produces a summary:

```text
## Implementation Validation Report

Tasks: {completed}/{total} (100%)
Tests: {passing}/{total} (100% pass rate)
Spec Coverage: {covered ACs}/{total ACs}
Test ID Traceability: {all traced / N gaps} (if test_cases_available)
Test Coverage Delta: unit {implemented}/{planned} ({pct}%) | integration {implemented}/{planned} ({pct}%) | e2e {implemented}/{planned} ({pct}%) (if test-plan.md available)
Strategy Risk Alignment: {all risks covered / N uncovered risks (MEDIUM)} (if test-strategy.md available)
Coverage Flags: {list of flags, e.g., "Unit tests below 80% threshold (HIGH)" / "All levels above minimum"}
Constitution Compliance: {compliant / N violations found (HIGH)}
Test Quality: {N placeholder files found / all tests substantive} {severity if applicable}
Baseline Test Count: {N} (independently verified)

### Issues Found
- [severity] Description — file:line
- ...

### Recommendation
PASS / PASS WITH NOTES / NEEDS ATTENTION
```

## 3.4 Handling Validation Failures

If validation reveals issues:

### Autonomy Policy Check

Read `autonomy_policy` from the Stage 1 summary. Read the policy level definition from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml` under `autonomy_policy.levels.{policy}`.

1. Determine the **highest severity** among all validation findings (Critical > High > Medium > Low)
2. Look up `policy.findings.{highest_severity}` action:
   - If action is `"fix"`: Auto-fix — launch developer agent to address issues at this severity and above, log: `"[AUTO-{policy}] Validation issues found — auto-fixing {severity}+ findings"`. After fix, re-validate. If re-validation passes or only lower-severity issues remain, set `validation_outcome: "fixed"`. If re-validation still finds issues at the same or higher severity, set `validation_outcome: "proceed_anyway"`, log, and proceed to quality review (do not loop infinitely).
   - If action is `"defer"`: Log findings, log: `"[AUTO-{policy}] Validation findings deferred — proceeding to quality review"`. Set `validation_outcome: "proceed_anyway"`.
   - If action is `"accept"`: Log: `"[AUTO-{policy}] Validation findings accepted"`. Set `validation_outcome: "proceed_anyway"`.
3. If no policy set (edge case): fall through to manual escalation below.

### Manual Escalation (when no autonomy policy applies)

Set `status: needs-user-input` in the stage summary with the validation report as the `block_reason`. The orchestrator will present options to the user:

**Options:**
1. **Fix now** — Launch developer agent to address specific issues, then re-validate
2. **Proceed to quality review anyway** — Continue with known issues
3. **Stop here** — Halt implementation

**Important:** The coordinator does NOT interact with the user directly. Write the summary with status `needs-user-input` and the orchestrator handles the interaction.

If orchestrator provides a user-input file with "Fix now":
1. Read `{FEATURE_DIR}/.stage-summaries/stage-3-user-input.md` for the user's decision
2. Launch developer agent to address specific issues
3. Re-validate
4. Rewrite the stage summary with updated results

## 3.5 Write Stage 3 Summary

Write summary to `{FEATURE_DIR}/.stage-summaries/stage-3-summary.md`:

```yaml
---
stage: "3"
stage_name: "Completion Validation"
checkpoint: "VALIDATION"
status: "completed"  # or "needs-user-input" if issues found
artifacts_written:
  - ".implementation-state.local.md"
summary: |
  Validation {passed/found issues}. Tasks: {N}/{M} complete.
  Tests: {all passing / N failures}. Spec coverage: {X}/{Y} ACs.
  Recommendation: {PASS / PASS WITH NOTES / NEEDS ATTENTION}.
flags:
  block_reason: null  # or full validation report if needs-user-input
  validation_outcome: "passed"  # passed | fixed | proceed_anyway | stopped
  baseline_test_count: {N}    # Independently verified by running test suite in Stage 3
  test_coverage_delta:        # Per-level coverage vs test-plan.md (null if test-plan.md unavailable)
    unit: "{implemented}/{planned} ({pct}%)"
    integration: "{implemented}/{planned} ({pct}%)"
    e2e: "{implemented}/{planned} ({pct}%)"
  cli_circuit_state: null     # Propagated (updated if Option C CLI runs)
  context_contributions: null # When context_protocol enabled, populate with:
    # key_decisions: validation pass/fail rationale, spec alignment findings
    # open_issues: partial coverage areas, checks deferred by policy
    # risk_signals: test quality concerns, coverage below thresholds
---
## Context for Next Stage

- Validation result: {PASS / PASS WITH NOTES / NEEDS ATTENTION}
- Tasks: {N}/{M} (100%)
- Tests: {all passing}
- Baseline test count: {N} (independently verified)
- Test coverage: {summary or "test-plan.md not available for comparison"}
- Issues found: {count} ({severity breakdown})
- User decision: {if applicable}

## Validation Details

{Full validation report from agent}
```
