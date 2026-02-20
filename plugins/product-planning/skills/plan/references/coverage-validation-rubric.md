# Test Coverage Validation Rubric

Detailed scoring criteria for Phase 8 coverage validation via CLI dispatch.

## Consensus Configuration

### CLIs and Stances

| CLI | Stance | Role |
|-----|--------|------|
| gemini (CLI) | advocate | Highlight strong coverage areas, give benefit of doubt |
| codex (CLI) | challenger | Find coverage gaps, weaknesses, and overlooked edge cases |

Minimum CLIs required for valid consensus: 1 (single CLI with self-challenge suffices)

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

## CLI Consensus Dispatch Template

Follow CLI Multi-CLI Dispatch Pattern from `cli-dispatch-pattern.md`:

```
| Parameter | Value |
|-----------|-------|
| ROLE | `consensus` |
| PHASE_STEP | `8.2` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | "STANCE: advocate\n\nHighlight the strengths of this test coverage.\n\nTEST PLAN:\n{FULL_TEST_PLAN_CONTENT}\n\nSPEC:\n{SPEC_WITH_ACS}\n\nScore dimensions (weighted %):\n1. AC Coverage (25%)\n2. Risk Coverage (25%)\n3. UAT Completeness (20%)\n4. Test Independence (15%)\n5. Maintainability (15%)" |
| CODEX_PROMPT | "STANCE: challenger\n\nFind coverage gaps, missing edge cases, and unclear UAT scripts.\n\n(same test plan, spec, and scoring dimensions)" |
| FILE_PATHS | ["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/spec.md"] |
| REPORT_FILE | "analysis/cli-coverage-consensus-report.md" |
| PREFERRED_SINGLE_CLI | `gemini` |
```

The coordinator synthesizes scores from both CLIs:
- **Convergent scores** (delta ≤ 5%): Use average → HIGH confidence
- **Divergent scores** (delta > 15%): FLAG for user review, re-dispatch with clarification
- **Moderate divergence** (5% < delta ≤ 15%): Use average, note disagreement

---

## Output Template

```markdown
# Test Coverage Validation Report

> Generated: {TIMESTAMP}
> CLIs: gemini (advocate), codex (challenger)

## Overall Score: {TOTAL}% - {STATUS}

### Per-CLI Scores

| Dimension | Weight | Gemini (Advocate) | Codex (Challenger) | Avg |
|-----------|--------|-------------------|--------------------|----|
| AC Coverage | 25% | X% | X% | X% |
| Risk Coverage | 25% | X% | X% | X% |
| UAT Completeness | 20% | X% | X% | X% |
| Test Independence | 15% | X% | X% | X% |
| Maintainability | 15% | X% | X% | X% |
| **Total** | 100% | XX% | XX% | **XX%** |

### Coverage Matrix Summary

| Category | Covered | Total | Percentage |
|----------|---------|-------|------------|
| Acceptance Criteria | X | Y | Z% |
| Critical Risks | X | Y | Z% |
| High Risks | X | Y | Z% |
| User Stories | X | Y | Z% |

### Strengths (Advocate)

{Gemini highlights}

### Gaps Found (Challenger)

{Codex concerns}

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

If CLI dispatch unavailable, use self-assessment:

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
