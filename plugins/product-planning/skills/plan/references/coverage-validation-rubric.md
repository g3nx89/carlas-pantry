# Test Coverage Validation Rubric

Detailed scoring criteria for Phase T5 coverage validation using PAL Consensus.

## Consensus Configuration

### Models and Stances

| Model | Stance | Role |
|-------|--------|------|
| gemini-3-pro-preview | neutral | Evaluate objectively |
| gpt-5.2 | for | Highlight strong coverage areas |
| grok-4 | against | Find coverage gaps and weaknesses |

Minimum models required for valid consensus: 2

---

## Scoring Dimensions (100% Total)

### 1. Acceptance Criteria Coverage (25%)

**Criteria:** Every acceptance criterion has at least one test at an appropriate level.

| Score | Description |
|-------|-------------|
| 100% | All ACs mapped to tests with appropriate coverage depth |
| 80-99% | Most ACs covered, minor gaps in edge cases |
| 60-79% | Significant ACs missing tests |
| <60% | Critical ACs not tested |

**Evidence to Check:**
- Is every AC from spec.md listed in the coverage matrix?
- Does each AC have at least one test ID reference?
- Are critical ACs covered by multiple test levels (unit + E2E)?
- Are edge cases within ACs addressed?

### 2. Risk Coverage (25%)

**Criteria:** All Critical and High severity risks have dedicated test coverage.

| Score | Description |
|-------|-------------|
| 100% | All Critical/High risks have mitigation tests; Medium risks documented |
| 80-99% | Critical risks covered; some High risks have gaps |
| 60-79% | Coverage gaps in Critical risks |
| <60% | Critical risks not adequately mitigated |

**Evidence to Check:**
- Are all risks from risk analysis listed?
- Does each Critical risk map to at least one test?
- Does each High risk map to at least one test?
- Are mitigation tests at the right level (failure handling → integration)?

### 3. UAT Completeness (20%)

**Criteria:** UAT scripts are clear, actionable, and executable by non-technical stakeholders.

| Score | Description |
|-------|-------------|
| 100% | UAT scripts are crystal clear with complete Given-When-Then |
| 80-99% | Minor clarity issues; some steps need more detail |
| 60-79% | Significant ambiguity; technical jargon present |
| <60% | UAT scripts not usable by non-technical testers |

**Evidence to Check:**
- Is Given-When-Then format used consistently?
- Are preconditions clearly stated?
- Are action steps numbered and unambiguous?
- Are expected outcomes observable (not technical)?
- Is test data provided?
- Are evidence collection steps included?

### 4. Test Independence (15%)

**Criteria:** Tests can run in isolation without dependencies on other tests.

| Score | Description |
|-------|-------------|
| 100% | All tests are self-contained with explicit setup/teardown |
| 80-99% | Most tests independent; few shared state concerns |
| 60-79% | Some tests require ordering or shared state |
| <60% | Tests are coupled and order-dependent |

**Evidence to Check:**
- Do tests have explicit preconditions (not relying on previous tests)?
- Is test data created fresh for each test?
- Can tests run in any order?
- Are cleanup steps documented?

### 5. Maintainability (15%)

**Criteria:** Tests are not brittle or over-specified; they test behavior, not implementation.

| Score | Description |
|-------|-------------|
| 100% | Tests focus on behavior; resilient to implementation changes |
| 80-99% | Mostly behavior-focused with minor implementation coupling |
| 60-79% | Some tests coupled to implementation details |
| <60% | Tests are brittle and will break on refactoring |

**Evidence to Check:**
- Do unit tests mock only external dependencies (not internal)?
- Are assertions on outcomes, not intermediate steps?
- Do E2E tests verify user-visible outcomes?
- Are test IDs semantically meaningful?

---

## Score Thresholds

| Total Score | Status | Action |
|-------------|--------|--------|
| ≥80% | GREEN | Proceed with TDD implementation |
| 65-79% | YELLOW | Proceed with documented coverage gaps |
| <65% | RED | Add more tests before proceeding |

---

## Consensus Call Template

The PAL Consensus tool uses a single call with a `models` array, not separate calls per model.
The workflow continues using `continuation_id` until all models have responded.

```javascript
// Single consensus call with all models
response = mcp__pal__consensus({
  step: """
    TEST COVERAGE VALIDATION:

    Evaluate test coverage completeness for feature: {FEATURE_NAME}

    TEST PLAN SUMMARY:
    {FULL_TEST_PLAN_CONTENT}

    SPEC WITH ACCEPTANCE CRITERIA:
    {SPEC_WITH_ACS}

    Score dimensions (weighted percentage):
    1. AC Coverage (25%) - All acceptance criteria mapped to tests
    2. Risk Coverage (25%) - All Critical/High risks have tests
    3. UAT Completeness (20%) - Scripts clear for non-technical users
    4. Test Independence (15%) - Tests can run in isolation
    5. Maintainability (15%) - Tests verify behavior, not implementation
  """,
  step_number: 1,
  total_steps: 4,  // Initial analysis + 3 model responses
  next_step_required: true,
  findings: "Initial test coverage analysis complete.",
  models: [
    {
      model: "gemini-3-pro-preview",
      stance: "neutral",
      stance_prompt: "Evaluate test coverage objectively against the scoring dimensions."
    },
    {
      model: "gpt-5.2",
      stance: "for",
      stance_prompt: "Highlight the strengths of this test coverage."
    },
    {
      model: "openrouter/x-ai/grok-4",
      stance: "against",
      stance_prompt: "Find coverage gaps, missing edge cases, and unclear UAT scripts."
    }
  ],
  relevant_files: ["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/spec.md"]
})

// Continue workflow until all models have responded
WHILE response.next_step_required:
  response = mcp__pal__consensus({
    step: "Processing model response",
    step_number: response.step_number + 1,
    total_steps: 4,
    next_step_required: true,
    findings: "Model evaluation: {summary_of_latest_response}",
    continuation_id: response.continuation_id
  })

// Final synthesis happens automatically when all models complete
```

---

## Output Template

```markdown
# Test Coverage Validation Report

> Generated: {TIMESTAMP}
> Models: gemini-3-pro-preview, gpt-5.2, grok-4

## Overall Score: {TOTAL}% - {STATUS}

### Per-Model Scores

| Dimension | Weight | Gemini | GPT-5.2 | Grok-4 | Avg |
|-----------|--------|--------|---------|--------|-----|
| AC Coverage | 25% | X% | X% | X% | X% |
| Risk Coverage | 25% | X% | X% | X% | X% |
| UAT Completeness | 20% | X% | X% | X% | X% |
| Test Independence | 15% | X% | X% | X% | X% |
| Maintainability | 15% | X% | X% | X% | X% |
| **Total** | 100% | XX% | XX% | XX% | **XX%** |

### Coverage Matrix Summary

| Category | Covered | Total | Percentage |
|----------|---------|-------|------------|
| Acceptance Criteria | X | Y | Z% |
| Critical Risks | X | Y | Z% |
| High Risks | X | Y | Z% |
| User Stories | X | Y | Z% |

### Strengths (Advocate)

{GPT-5.2 highlights}

### Gaps Found (Challenger)

{Grok-4 concerns}

### Recommendations

1. {actionable improvement}
2. {actionable improvement}

## Verdict

**Status:** {GREEN/YELLOW/RED}
**Action:** {Proceed with TDD / Address gaps / Major revision needed}
```

---

## RED Status Handling

When validation score < 65%:

1. **Identify critical gaps:**
   - Which ACs lack tests?
   - Which Critical/High risks are uncovered?
   - Which UAT scripts are unclear?

2. **Generate improvement guidance:**
   - Map low scores to specific test plan sections
   - Provide concrete suggestions for each gap

3. **Iterate:**
   - Update test plan to address feedback
   - Re-run validation (max 2 iterations before manual review)

---

## Internal Validation Fallback

If PAL Consensus unavailable, use self-assessment:

```markdown
## Self-Assessment Checklist

### AC Coverage
- [ ] Listed all ACs from spec.md
- [ ] Each AC has at least one test
- [ ] Critical ACs have multi-level coverage

### Risk Coverage
- [ ] Listed all identified risks
- [ ] Critical risks have mitigation tests
- [ ] High risks have mitigation tests

### UAT Completeness
- [ ] Given-When-Then format used
- [ ] No technical jargon
- [ ] Evidence collection documented
- [ ] Test data provided

### Test Independence
- [ ] Tests have explicit preconditions
- [ ] No shared mutable state
- [ ] Can run in any order

### Maintainability
- [ ] Tests verify behavior, not implementation
- [ ] Assertions are on outcomes
- [ ] Test names are descriptive
```

Mark validation as "INTERNAL" in output to distinguish from multi-model consensus.

---

## V-Model Alignment Check

Additional validation to ensure V-Model compliance:

| Development Phase | Required Test Level | Check |
|------------------|---------------------|-------|
| Requirements | UAT (Given-When-Then) | ☐ At least one UAT per user story |
| Architecture | E2E (Full flows) | ☐ Critical paths covered |
| Design | Integration | ☐ Component boundaries tested |
| Implementation | Unit (TDD) | ☐ All business logic has unit tests |

**V-Model Compliance Score:**
- 4/4 phases covered = Fully compliant
- 3/4 phases covered = Mostly compliant
- <3 phases covered = Non-compliant (RED flag)
