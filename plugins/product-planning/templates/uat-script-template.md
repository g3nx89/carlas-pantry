# User Acceptance Test Scripts: {FEATURE_NAME}

> **Version:** {VERSION}
> **Created:** {DATE}
> **Story Count:** {STORY_COUNT}
> **Estimated Duration:** {DURATION}
> **Tester:** {TESTER_ROLE}

---

## Test Session Information

**Test Environment:** {environment_url}
**Test Account:** {test_credentials_ref}
**Browser/Device:** {browser_or_device}
**Date Executed:** {execution_date}
**Executed By:** {tester_name}

---

## Pre-Test Checklist

Before starting the UAT session:

- [ ] Environment is accessible and stable
- [ ] Test accounts are set up
- [ ] Test data is prepared
- [ ] Screenshot tool is ready
- [ ] This document is printed or accessible
- [ ] Stakeholder is available for questions

---

## UAT-01: {User Story Title}

### User Story

> **As a** {persona - who is the user?}
> **I want to** {goal - what do they want to do?}
> **So that** {benefit - why do they want it?}

**Story ID:** {STORY-XXX}
**Priority:** {P0/P1/P2}
**Acceptance Criteria Reference:** AC-1, AC-2

---

### Scenario 1.1: {Happy Path Scenario Name}

**Purpose:** Verify the primary success path works as expected.

#### Preconditions (Given)

- [ ] {precondition 1 - e.g., "User is logged in"}
- [ ] {precondition 2 - e.g., "No existing data conflicts"}
- [ ] {precondition 3 - e.g., "Network is available"}

#### Actions (When)

| Step | Action | Expected Visual Feedback |
|------|--------|-------------------------|
| 1 | {action description} | {what user should see} |
| 2 | {action description} | {what user should see} |
| 3 | {action description} | {what user should see} |

#### Expected Results (Then)

| # | Expected Outcome | Actual Result | Pass/Fail |
|---|------------------|---------------|-----------|
| 1 | {expected outcome 1} | {fill during test} | ☐ |
| 2 | {expected outcome 2} | {fill during test} | ☐ |
| 3 | {expected outcome 3} | {fill during test} | ☐ |

#### Test Data

| Field | Value | Notes |
|-------|-------|-------|
| {field_name} | {test_value} | {any special notes} |
| {field_name} | {test_value} | {any special notes} |

#### Evidence Collection

- [ ] **Screenshot 1:** Initial state before action
  - File: `uat-01-1-1-initial.png`
- [ ] **Screenshot 2:** After primary action
  - File: `uat-01-1-2-action.png`
- [ ] **Screenshot 3:** Final success state
  - File: `uat-01-1-3-success.png`

#### Tester Notes

{Space for tester to write observations, questions, or issues discovered}

---

### Scenario 1.2: {Error/Edge Case Scenario Name}

**Purpose:** Verify error handling and edge case behavior.

#### Preconditions (Given)

- [ ] {precondition that sets up error scenario}

#### Actions (When)

| Step | Action | Expected Visual Feedback |
|------|--------|-------------------------|
| 1 | {action that triggers error} | {error indicator} |

#### Expected Results (Then)

| # | Expected Outcome | Actual Result | Pass/Fail |
|---|------------------|---------------|-----------|
| 1 | {error message shown} | {fill during test} | ☐ |
| 2 | {data is NOT modified} | {fill during test} | ☐ |
| 3 | {user can recover} | {fill during test} | ☐ |

#### Evidence Collection

- [ ] **Screenshot:** Error state displayed
  - File: `uat-01-2-error.png`

---

## UAT-02: {User Story Title}

### User Story

> **As a** {persona}
> **I want to** {goal}
> **So that** {benefit}

**Story ID:** {STORY-XXX}

{Repeat the scenario structure above}

---

## UAT-03: {User Story Title}

{Continue for each user story}

---

## Cross-Functional Tests

### CFT-01: {Cross-Story Scenario}

**Purpose:** Verify behavior that spans multiple user stories.

**Stories Involved:** UAT-01, UAT-02

#### Scenario

1. Complete UAT-01 Scenario 1.1
2. Without logging out, navigate to UAT-02 context
3. Verify data from step 1 is correctly reflected

#### Expected Results

| # | Expected Outcome | Actual Result | Pass/Fail |
|---|------------------|---------------|-----------|
| 1 | {cross-functional expectation} | {fill during test} | ☐ |

---

## Non-Functional Acceptance

### Performance Perception

| Action | Maximum Acceptable Time | Actual Time | Pass/Fail |
|--------|------------------------|-------------|-----------|
| Page load | 3 seconds | {measured} | ☐ |
| Form submit | 2 seconds | {measured} | ☐ |
| Search results | 1 second | {measured} | ☐ |

### Accessibility Quick Check

- [ ] Can navigate using keyboard only
- [ ] Text is readable (contrast, size)
- [ ] Interactive elements have visible focus
- [ ] Error messages are clear and helpful

### Mobile Responsiveness (if applicable)

- [ ] Layout adapts to mobile screen
- [ ] Touch targets are large enough
- [ ] No horizontal scrolling required

---

## Test Session Summary

### Results Overview

| UAT | Scenarios | Passed | Failed | Blocked |
|-----|-----------|--------|--------|---------|
| UAT-01 | 2 | {count} | {count} | {count} |
| UAT-02 | {count} | {count} | {count} | {count} |
| CFT-01 | 1 | {count} | {count} | {count} |
| **Total** | {total} | {total} | {total} | {total} |

### Issues Discovered

| Issue # | UAT Ref | Severity | Description | Action |
|---------|---------|----------|-------------|--------|
| ISS-01 | UAT-01.2 | High | {description} | Bug filed |
| ISS-02 | UAT-02.1 | Low | {description} | Noted |

### Deviations Accepted

| Deviation | UAT Ref | Reason for Acceptance | Approved By |
|-----------|---------|----------------------|-------------|
| {deviation} | UAT-01.1 | {reason} | {name} |

### Open Questions

- {Question that arose during testing}
- {Question for product team}

---

## Sign-Off

### Acceptance Criteria Verification

| AC | Description | Verified In | Status |
|----|-------------|-------------|--------|
| AC-1 | {description} | UAT-01.1 | ✅ Accepted |
| AC-2 | {description} | UAT-01.2 | ✅ Accepted |
| AC-3 | {description} | UAT-02.1 | ⚠️ Accepted with deviation |

### Final Decision

- [ ] **APPROVED:** Feature meets acceptance criteria
- [ ] **APPROVED WITH CONDITIONS:** Accepted with documented deviations
- [ ] **REJECTED:** Feature requires changes before release

### Signatures

**Product Owner:**
- Name: _______________________
- Date: _______________________
- Signature: ___________________

**QA Lead:**
- Name: _______________________
- Date: _______________________
- Signature: ___________________

**Development Lead:**
- Name: _______________________
- Date: _______________________
- Signature: ___________________

---

## Appendix A: Test Data Reference

### Test Accounts

| Role | Username | Password Location |
|------|----------|-------------------|
| Admin | test.admin@example.com | Vault: /test/admin |
| User | test.user@example.com | Vault: /test/user |

### Test Data Sets

| Data Set | Description | Reset Procedure |
|----------|-------------|-----------------|
| {dataset} | {description} | {how to reset} |

---

## Appendix B: Evidence File Index

| File Name | UAT Ref | Description |
|-----------|---------|-------------|
| uat-01-1-1-initial.png | UAT-01.1 | Initial state |
| uat-01-1-2-action.png | UAT-01.1 | After action |
| uat-01-1-3-success.png | UAT-01.1 | Success state |

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **Given** | The preconditions or initial state before the test action is performed |
| **When** | The action or event that triggers the behavior being tested |
| **Then** | The expected outcome or result that should occur after the action |
| **And** | Used to add additional conditions to Given, When, or Then clauses |
| **UAT** | User Acceptance Testing - Tests performed by end users or stakeholders to validate business requirements |
| **Evidence** | Proof of test execution, typically screenshots or logs |
| **Sign-off** | Formal approval that the feature meets acceptance criteria |
| **Pass/Fail** | Test result indicating whether the expected outcome was achieved |
| **Blocked** | Test cannot be executed due to a dependency or technical issue |
| **Deviation** | Difference between expected and actual behavior (may or may not be a defect) |
| **Precondition** | State or setup required before a test can be executed |
| **Test Data** | Specific input values used during test execution |
| **Happy Path** | The primary success scenario where everything works as expected |
| **Edge Case** | Unusual or boundary scenarios that test limits of the system |
| **AC** | Acceptance Criterion - A specific condition that must be met |
| {term} | {definition relevant to this feature} |
