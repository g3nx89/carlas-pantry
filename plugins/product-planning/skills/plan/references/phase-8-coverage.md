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
artifacts_written:
  - "analysis/test-coverage-validation.md"
agents: []
mcp_tools:
  - "mcp__pal__consensus"
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags: []
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/coverage-validation-rubric.md"
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

## Step 8.1: Prepare Coverage Matrix

```
COLLECT all acceptance criteria from spec.md
COLLECT all identified risks from Phase 7
COLLECT all user stories from spec.md

MAP each AC to test IDs
MAP each risk to mitigation tests
MAP each story to UAT script
```

## Step 8.2: PAL Consensus Validation (Complete/Advanced)

IF mode in {Complete, Advanced} AND Consensus available:

```
# Step 1: Initialize test coverage consensus workflow
response = mcp__pal__consensus({
  step: """
    TEST COVERAGE VALIDATION:

    Evaluate test coverage completeness for feature: {FEATURE_NAME}

    TEST PLAN SUMMARY:
    {test_plan_summary}

    COVERAGE MATRIX:
    {coverage_matrix}

    Score dimensions (weighted percentage):
    1. AC Coverage (25%) - All acceptance criteria mapped to tests
    2. Risk Coverage (25%) - All Critical/High risks have tests
    3. UAT Completeness (20%) - Scripts clear for non-technical users
    4. Test Independence (15%) - Tests can run in isolation
    5. Maintainability (15%) - Tests verify behavior, not implementation
  """,
  step_number: 1,
  total_steps: 4,
  next_step_required: true,
  findings: "Initial test coverage analysis complete.",
  models: [
    {model: "gemini-3-pro-preview", stance: "neutral", stance_prompt: "Evaluate test coverage objectively"},
    {model: "gpt-5.2", stance: "for", stance_prompt: "Highlight test coverage strengths"},
    {model: "openrouter/x-ai/grok-4", stance: "against", stance_prompt: "Find coverage gaps and missing edge cases"}
  ],
  relevant_files: ["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/spec.md"]
})

# Continue workflow with continuation_id until complete
WHILE response.next_step_required:
  current_step = response.step_number + 1
  is_final = (current_step >= 4)  # Final step = synthesis

  response = mcp__pal__consensus({
    step: IF is_final THEN "Final synthesis of test coverage perspectives" ELSE "Processing model response",
    step_number: current_step,
    total_steps: 4,
    next_step_required: NOT is_final,
    findings: "Model evaluation: {summary}",
    continuation_id: response.continuation_id
  })
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

IF Consensus not available:

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
