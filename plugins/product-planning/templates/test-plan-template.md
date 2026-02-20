# Test Plan: {FEATURE_NAME}

> **V-Model Test Strategy**
> **Spec Version:** {SPEC_VERSION}
> **Plan Version:** {PLAN_VERSION}
> **Design Version:** {DESIGN_VERSION}
> **Created:** {DATE}
> **Last Updated:** {UPDATED_DATE}
> **Coverage Score:** {COVERAGE_PERCENT}%
> **CLI Consensus:** {CONSENSUS_PERCENT}%

---

## Executive Summary

**Feature:** {brief description}
**Test Approach:** V-Model with TDD for unit tests
**Inner Loop Tests:** {UT_COUNT} unit, {INT_COUNT} integration
**Outer Loop Tests:** {E2E_COUNT} E2E, {UAT_COUNT} UAT
**Estimated Test Effort:** {EFFORT_ESTIMATE}

---

## 1. Risk Assessment

### 1.1 Failure Point Analysis

| Risk ID | Description | Severity | Likelihood | Priority | Mitigation |
|---------|-------------|----------|------------|----------|------------|
| R-01 | {description} | Critical/High/Medium/Low | High/Medium/Low | P0/P1/P2 | {test_refs} |
| R-02 | {description} | {severity} | {likelihood} | {priority} | {test_refs} |

**Severity Definitions:**
- **Critical:** Data loss, security breach, system unavailable
- **High:** Feature broken, user blocked, no workaround
- **Medium:** Degraded experience, workaround available
- **Low:** Cosmetic issues, minor inconvenience

### 1.2 Risk Coverage Summary

| Priority | Risk Count | Tests Covering | Coverage |
|----------|------------|----------------|----------|
| P0 (Critical) | {count} | {test_count} | {percent}% |
| P1 (High) | {count} | {test_count} | {percent}% |
| P2 (Medium) | {count} | {test_count} | {percent}% |

---

## 2. Unit Tests (Inner Loop - TDD)

**Executor:** CI Pipeline (automated)
**Trigger:** Every commit
**Pattern:** Write test BEFORE implementation

### 2.1 Test Specifications

| ID | Component | Scenario | Input | Expected | AC Ref | Risk Ref |
|----|-----------|----------|-------|----------|--------|----------|
| UT-01 | {component} | {happy_path} | {input} | {output} | AC-1 | - |
| UT-02 | {component} | {error_case} | {invalid} | {error} | AC-2 | R-01 |
| UT-03 | {component} | {edge_case} | {boundary} | {expected} | AC-1 | R-02 |

### 2.2 Required Edge Cases

Every component MUST have unit tests for:

- [ ] **Null/Empty Inputs** - Handle gracefully, no crashes
- [ ] **Boundary Conditions** - Min/max values, empty collections
- [ ] **Error States** - Expected exceptions thrown with proper messages
- [ ] **State Transitions** - Valid and invalid state changes
- [ ] **Concurrency** (if applicable) - Thread-safe operations

### 2.3 TDD Checklist

Before implementation:
- [ ] UT-01 written and failing
- [ ] UT-02 written and failing
- [ ] Edge case tests written and failing
- [ ] Test reviewed with tech lead

---

## 3. Integration Tests (Inner Loop)

**Executor:** CI Pipeline (automated)
**Trigger:** Every PR
**Focus:** Component boundaries and data flow

### 3.1 Test Specifications

| ID | Components | Scenario | Preconditions | Assertions | AC Ref |
|----|------------|----------|---------------|------------|--------|
| INT-01 | {A} + {B} | {interaction} | {setup} | {expected} | AC-1 |
| INT-02 | {B} + {C} | {integration} | {setup} | {expected} | AC-2 |

### 3.2 Contract Tests (if APIs involved)

| ID | Consumer | Provider | Contract | Verification |
|----|----------|----------|----------|--------------|
| CTR-01 | {frontend} | {backend} | {endpoint} | {tool: Pact/etc} |

### 3.3 Integration Test Guidelines

- Use real database (in-memory or testcontainers)
- Mock only external third-party services
- Test both success and failure paths
- Verify data integrity across boundaries

---

## 4. E2E Tests (Outer Loop)

**Executor:** QA Engineer / Automation Framework
**Trigger:** Pre-merge, pre-release
**Evidence:** Screenshot + log required for each test

### 4.1 Test Scenarios

| ID | User Flow | Preconditions | Steps | Expected Outcome | Visual Ref |
|----|-----------|---------------|-------|------------------|------------|
| E2E-01 | {primary_flow} | {setup} | 1. {step1}<br>2. {step2}<br>3. {step3} | {success_state} | {figma_url} |
| E2E-02 | {error_flow} | {setup} | 1. {step1}<br>2. {invalid_action} | {error_state} | {figma_url} |
| E2E-03 | {recovery_flow} | {error_state} | 1. {recovery_step} | {recovered_state} | - |

### 4.2 E2E Test Protocol

For each E2E test, the executor must:

1. **Setup:** Ensure preconditions are met
2. **Execute:** Follow steps exactly as documented
3. **Capture:** Screenshot after each significant step
4. **Verify:** Compare actual vs expected outcome
5. **Document:** Record any deviations or issues

### 4.3 E2E Evidence Template

```
E2E-{id} RESULT
━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: PASS / FAIL / BLOCKED
Steps Completed: X/Y
Execution Time: {duration}

Evidence:
- Screenshot 1: {description} ✅
- Screenshot 2: {description} ✅
- Final State: {description} ✅

Issues Found:
- {issue description if any}

Notes:
- {observations}
```

---

## 5. User Acceptance Tests (Outer Loop)

**Executor:** Product Owner / Business Stakeholder
**Trigger:** Pre-release
**Format:** Given-When-Then (Gherkin)

### 5.1 UAT Scripts

#### UAT-01: {Story Title}

**User Story Reference:** {story_id}

> **As a** {persona}
> **I want to** {action}
> **So that** {benefit}

**Given:** {preconditions - plain language}
**And:** {additional conditions}

**When:** {action the user takes}
**And:** {additional actions}

**Then:** {expected outcome - observable by user}
**And:** {additional outcomes}

**Test Data:**
| Field | Value | Notes |
|-------|-------|-------|
| {field1} | {value1} | {optional notes} |
| {field2} | {value2} | {optional notes} |

**Evidence Checklist:**
- [ ] Screenshot of initial state
- [ ] Screenshot of action being performed
- [ ] Screenshot of success/result state
- [ ] User confirms expected behavior
- [ ] No unexpected side effects observed

**Tester Instructions:**
1. {step-by-step guidance for non-technical tester}
2. {what to look for}
3. {common issues and how to resolve}

**Pass Criteria:**
- All "Then" conditions are met
- User experience matches expectations
- No blocking defects encountered

---

#### UAT-02: {Story Title}

{Repeat format for each user story}

---

### 5.2 UAT Session Protocol

**Before Session:**
- [ ] Test environment is stable and accessible
- [ ] Test data is prepared
- [ ] Stakeholders have access to the system
- [ ] Recording/screenshot tools are ready

**During Session:**
- [ ] Walk through each UAT script
- [ ] Document any questions or concerns
- [ ] Capture screenshots for evidence
- [ ] Note any unexpected behaviors

**After Session:**
- [ ] Collect sign-off from Product Owner
- [ ] Document any accepted deviations
- [ ] Log any discovered issues as bugs
- [ ] Update test plan with lessons learned

---

## 6. Exploratory Testing Guide

**Executor:** QA Engineer
**Timing:** After formal tests pass, before release
**Goal:** Find issues not covered by scripted tests

### 6.1 Exploration Charters

| Charter | Focus Area | Time Box | Priority |
|---------|------------|----------|----------|
| EXP-01 | {boundary conditions} | 30 min | P1 |
| EXP-02 | {unusual user paths} | 30 min | P2 |
| EXP-03 | {error injection} | 45 min | P1 |

### 6.2 Exploration Ideas

Based on risk analysis, explore:

- **Data Edge Cases:** Very long inputs, special characters, Unicode
- **State Manipulation:** Use back button, refresh mid-action, timeout
- **Concurrent Actions:** Multiple tabs, rapid clicks, parallel requests
- **Resource Exhaustion:** Slow network, low disk space simulation

---

## 7. Test Execution Order (V-Model)

### Phase 1: Pre-Implementation (TDD)

```
Day 1-2: Write failing unit tests
├── UT-01: {description} → RED
├── UT-02: {description} → RED
└── Review tests with tech lead
```

### Phase 2: During Implementation

```
Each component:
├── Write code to pass UT-XX → GREEN
├── Refactor if needed
└── Commit with passing tests
```

### Phase 3: Post-Implementation

```
Integration testing:
├── INT-01: Run and verify
├── INT-02: Run and verify
└── Fix any integration issues
```

### Phase 4: Pre-Merge

```
E2E validation:
├── E2E-01: Critical path
├── E2E-02: Error handling
└── Screenshot evidence collected
```

### Phase 5: Pre-Release

```
User acceptance:
├── UAT session scheduled
├── UAT-01: Execute with Product Owner
├── UAT-02: Execute with Product Owner
├── Sign-off obtained
└── Exploratory testing completed
```

### Phase 6: Post-Release (Optional)

```
Production validation:
├── Smoke tests in production
├── Monitor error rates
└── Gather user feedback
```

---

## 8. Coverage Matrix

| Acceptance Criterion | Risk Ref | Unit | Integration | E2E | UAT | Status |
|---------------------|----------|------|-------------|-----|-----|--------|
| AC-1: {criterion} | R-01 | UT-01 | INT-01 | E2E-01 | UAT-01 | ✅ |
| AC-2: {criterion} | R-02 | UT-02, UT-03 | INT-02 | E2E-02 | UAT-01 | ✅ |
| AC-3: {criterion} | - | UT-04 | - | E2E-01 | UAT-02 | ✅ |

**Coverage Summary:**
- Acceptance Criteria: {covered}/{total} ({percent}%)
- Critical Risks: {covered}/{total} ({percent}%)
- User Stories: {covered}/{total} ({percent}%)

---

## 9. Sign-Off Checklist

### Development Gate (Pre-Implementation)
- [ ] Test plan reviewed and approved
- [ ] Unit test specs written (TDD ready)
- [ ] Risk coverage verified

### Quality Gate (Pre-Merge)
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Critical E2E tests passing
- [ ] No P0/P1 bugs open

### Release Gate (Pre-Release)
- [ ] All E2E tests passing
- [ ] UAT completed and signed off
- [ ] Exploratory testing completed
- [ ] No Critical/High bugs open
- [ ] Product Owner approval obtained

---

## 10. Appendix

### A. Test Environment Requirements

| Environment | Purpose | Data | Access |
|-------------|---------|------|--------|
| Local | Unit tests | Mocked | Developer |
| CI | Unit + Integration | Test DB | Automated |
| Staging | E2E + UAT | Anonymized prod-like | QA + PO |
| Production | Smoke | Real | Limited |

### B. Test Data Management

| Data Set | Purpose | Refresh Frequency | Owner |
|----------|---------|-------------------|-------|
| {dataset} | {purpose} | {frequency} | {owner} |

### C. Known Limitations

- {limitation 1}
- {limitation 2}

### D. References

- Spec: `{FEATURE_DIR}/spec.md`
- Plan: `{FEATURE_DIR}/plan.md`
- Design: `{FEATURE_DIR}/design.md`

### E. Glossary

| Term | Definition |
|------|------------|
| **AC** | Acceptance Criterion - A specific, testable condition that must be met for a feature to be considered complete |
| **E2E** | End-to-End - Testing that validates complete user flows from start to finish |
| **Given-When-Then** | Gherkin format for writing acceptance tests: Given (preconditions), When (action), Then (expected outcome) |
| **Inner Loop** | Fast feedback tests run in CI pipeline (unit, integration) |
| **INT** | Integration Test - Tests that verify interaction between components |
| **Outer Loop** | Slower tests requiring human/agentic execution (E2E, UAT, exploratory) |
| **P0/P1/P2** | Priority levels - P0 (critical), P1 (high), P2 (medium) |
| **TDD** | Test-Driven Development - Write tests before implementation (RED → GREEN → REFACTOR) |
| **UAT** | User Acceptance Testing - Tests executed by stakeholders to validate business requirements |
| **UT** | Unit Test - Tests that verify a single function/class in isolation |
| **V-Model** | Testing methodology where each development phase has a corresponding test level |
