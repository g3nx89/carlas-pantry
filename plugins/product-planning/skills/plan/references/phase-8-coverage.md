---
phase: "8"
phase_name: "Test Coverage Validation"
checkpoint: "TEST_COVERAGE_VALIDATION"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-7-summary.md"
artifacts_read:
  - "test-plan.md"
  - "spec.md"
  - "test-strategy.md"  # Optional — from specify's Stage 6 (for traceability validation)
artifacts_written:
  - "analysis/test-coverage-validation.md"
  - "analysis/cli-coverage-consensus-report.md"  # conditional: CLI dispatch enabled
agents: []
mcp_tools: []
feature_flags: ["cli_context_isolation", "cli_custom_roles"]
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/coverage-validation-rubric.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
---

# Phase 8: Test Coverage Validation

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-8-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 8.1: Prepare Coverage Matrix

```
COLLECT all acceptance criteria from spec.md
COLLECT all identified risks from Phase 7
COLLECT all user stories from spec.md

MAP each AC to test IDs
MAP each risk to mitigation tests
MAP each story to UAT script
```

## Step 8.2: CLI Consensus Validation (Complete/Advanced)

IF mode in {Complete, Advanced} AND state.cli.available:

```
# Dispatch ALL CLIs with coverage scoring prompts
Follow CLI Multi-CLI Dispatch Pattern from $CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md with:

| Parameter | Value |
|-----------|-------|
| ROLE | `consensus` |
| PHASE_STEP | `8.2` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | see below (advocate stance + coverage rubric) |
| CODEX_PROMPT | see below (challenger stance + coverage rubric) |
| OPENCODE_PROMPT | see below (product_lens stance + coverage rubric) |
| FILE_PATHS | `["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/test-strategy.md"]` |
| REPORT_FILE | `analysis/cli-coverage-consensus-report.md` |
| PREFERRED_SINGLE_CLI | `gemini` |
| POST_WRITE | none |

GEMINI_PROMPT:
  "STANCE: ADVOCATE — Highlight coverage strengths.

  Evaluate test coverage for feature: {FEATURE_NAME}

  TEST PLAN: {test_plan_summary}
  COVERAGE MATRIX: {coverage_matrix}

  Score dimensions (weighted percentage):
  1. AC Coverage (25%) - All acceptance criteria mapped to tests
  2. Risk Coverage (25%) - All Critical/High risks have tests
  3. UAT Completeness (20%) - Scripts clear for non-technical users
  4. Test Independence (15%) - Tests can run in isolation
  5. Maintainability (15%) - Tests verify behavior, not implementation

  Return per-dimension percentage scores with evidence."

CODEX_PROMPT:
  "STANCE: CHALLENGER — Find coverage gaps and missing edge cases.
  [same dimensions]
  Return per-dimension percentage scores with evidence."

OPENCODE_PROMPT:
  "STANCE: PRODUCT_LENS — Evaluate test coverage from user experience and product alignment perspective.
  [same dimensions]
  Return per-dimension percentage scores with evidence."

# Extract and average scores from all available CLI outputs
final_scores = AVERAGE(all available CLI scores) per dimension
weighted_total = WEIGHTED_SUM(final_scores, dimension_weights)
```

## Step 8.3: Score Calculation

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| AC Coverage | 25% | All acceptance criteria mapped to tests |
| Risk Coverage | 25% | All Critical/High risks have tests |
| UAT Completeness | 20% | Scripts are clear for non-technical users |
| Test Independence | 15% | Tests can run in isolation |
| Maintainability | 15% | Tests verify behavior, not implementation |

## Step 8.4: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| >=80% | GREEN | Proceed to completion |
| >=65% AND <80% | YELLOW | Proceed with documented gaps |
| <65% | RED | Return to Phase 7 |

**USER INTERACTION for YELLOW/RED:**

If YELLOW: Set `status: needs-user-input` with `block_reason` explaining coverage gaps and asking user to confirm proceeding or return to Phase 7.

If RED: Set `status: needs-user-input` with `block_reason` explaining what coverage is missing and that the orchestrator should loop back to Phase 7.

## Step 8.5: Internal Validation (Fallback)

IF CLI dispatch not available:

```
Self-Assessment Checklist:
- [ ] Every AC has at least one test
- [ ] Every Critical risk has mitigation test
- [ ] Every High risk has mitigation test
- [ ] UAT scripts use Given-When-Then
- [ ] UAT scripts have evidence checklists
- [ ] Tests don't depend on each other
```

## Step 8.6: Generate Coverage Report

Write `{FEATURE_DIR}/analysis/test-coverage-validation.md`

**Checkpoint: TEST_COVERAGE_VALIDATION**

IF status == RED: → orchestrator loops back to Phase 7
