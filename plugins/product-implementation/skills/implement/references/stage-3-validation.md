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
9. **Independent test count verification**: Run the full test suite independently (do not rely on Stage 2's count) and record the result as `baseline_test_count`. This becomes the reference for Stage 4 post-fix validation.
10. **Stage 2 cross-validation** *(conditional — only if Stage 2 summary has `test_count_verified` in flags)*: Compare the independently verified `baseline_test_count` against Stage 2's `test_count_verified`. If the values differ, log a warning: "Test count discrepancy: Stage 2 reported {test_count_verified} but independent verification found {baseline_test_count}. Investigate possible agent reporting error." The `baseline_test_count` (independently verified) takes precedence.

## 3.3 Validation Report

Agent produces a summary:

```text
## Implementation Validation Report

Tasks: {completed}/{total} (100%)
Tests: {passing}/{total} (100% pass rate)
Spec Coverage: {covered ACs}/{total ACs}
Test ID Traceability: {all traced / N gaps} (if test_cases_available)
Test Coverage Delta: unit {implemented}/{planned} ({pct}%) | integration {implemented}/{planned} ({pct}%) | e2e {implemented}/{planned} ({pct}%) (if test-plan.md available)
Coverage Flags: {list of flags, e.g., "Unit tests below 80% threshold (HIGH)" / "All levels above minimum"}
Constitution Compliance: {compliant / N violations found (HIGH)}
Baseline Test Count: {N} (independently verified)

### Issues Found
- [severity] Description — file:line
- ...

### Recommendation
PASS / PASS WITH NOTES / NEEDS ATTENTION
```

## 3.4 Handling Validation Failures

If validation reveals issues, set `status: needs-user-input` in the stage summary with the validation report as the `block_reason`. The orchestrator will present options to the user:

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
