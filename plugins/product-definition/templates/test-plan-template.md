# Test Plan: {FEATURE_NAME}

> **V-Model Test Strategy**
> **Feature ID:** {FEATURE_ID}
> **Spec Version:** {SPEC_VERSION}
> **Created:** {DATE}
> **QA Strategist:** Agent-generated

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Tests Planned** | {N} |
| **Unit Tests** | {N} (Inner Loop - TDD) |
| **Integration Tests** | {N} (Inner Loop - CI) |
| **E2E Tests** | {N} (Outer Loop - Manual/Agentic) |
| **Visual Tests** | {N} (Outer Loop - Design Compliance) |
| **AC Coverage** | {N}/{Total} ({%}) |
| **Risk Areas** | {N} Critical, {N} High, {N} Medium |

---

## 1. Risk Assessment

> Failure modes identified BEFORE test definition.

### 1.1 Failure Point Analysis

| Risk Area | Severity | Component | Test Mitigation |
|-----------|----------|-----------|-----------------|
| {Network failure} | {High/Medium/Low} | {Component} | {Test IDs} |
| {Permission denial} | {Severity} | {Component} | {Test IDs} |
| {Empty state handling} | {Severity} | {Component} | {Test IDs} |
| {Process death} | {Severity} | {Component} | {Test IDs} |
| {Configuration changes} | {Severity} | {Component} | {Test IDs} |

### 1.2 Critical User Flows

**Primary Flow**: {Description of most common user journey}
- Entry: {Starting point}
- Actions: {Key action sequence}
- Success: {End state}
- Tests: {E2E-xxx, E2E-xxx}

**Secondary Flows**: {Important alternative paths}
- {Flow description → Test IDs}

**Error Recovery**: {How users recover from failures}
- {Recovery path → Test IDs}

---

## 2. Unit Tests (TDD - Inner Loop)

> **Executor:** Build tool (`gradle testDebugUnitTest`, `npm test`, `pytest`)
> **Pattern:** Write test BEFORE implementation (TDD)
> **Characteristics:** Fast, isolated, deterministic, no external dependencies

### 2.1 ViewModel/Controller Tests

| ID | Component | Scenario | Expected Result | AC Ref |
|----|-----------|----------|-----------------|--------|
| UT-001 | {ViewModel} | {Initial state scenario} | {Expected state} | AC-{N} |
| UT-002 | {ViewModel} | {User action scenario} | {State change} | AC-{N} |
| UT-003 | {ViewModel} | {Error handling scenario} | {Error state} | AC-{N} |

### 2.2 UseCase/Business Logic Tests

| ID | Component | Scenario | Expected Result | AC Ref |
|----|-----------|----------|-----------------|--------|
| UT-010 | {UseCase} | {Happy path} | {Expected result} | AC-{N} |
| UT-011 | {UseCase} | {Edge case} | {Expected handling} | AC-{N} |

### 2.3 Repository Tests (with Mocks)

| ID | Component | Scenario | Expected Result | AC Ref |
|----|-----------|----------|-----------------|--------|
| UT-020 | {Repository} | {Data fetch success} | {Returns data} | AC-{N} |
| UT-021 | {Repository} | {Network error} | {Throws exception} | AC-{N} |

### 2.4 Edge Cases (MANDATORY Unit Tests)

- [ ] Handle null/empty API responses
- [ ] Handle malformed data gracefully
- [ ] Handle boundary values (min/max)
- [ ] Handle special characters in input
- [ ] Handle concurrent state updates
- [ ] Handle process death state restoration
- [ ] Handle configuration changes (rotation)

---

## 3. Integration Tests (Inner Loop)

> **Executor:** Instrumented test task (`gradle connectedDebugAndroidTest`, integration test suite)
> **Focus:** Component interaction with real dependencies
> **Characteristics:** Slower than unit, uses real database/navigation

### 3.1 Component Boundary Tests

| ID | Components | Scenario | Assertion |
|----|------------|----------|-----------|
| INT-001 | {ViewModel + Repository} | {Data flow scenario} | {State persisted correctly} |
| INT-002 | {Screen + Navigation} | {Navigation scenario} | {Correct destination reached} |
| INT-003 | {Repository + Database} | {Persistence scenario} | {Data survives restart} |

### 3.2 State Persistence Tests

| ID | Components | Scenario | Assertion |
|----|------------|----------|-----------|
| INT-010 | {State + Storage} | {Process death simulation} | {State restored correctly} |
| INT-011 | {Cache + Network} | {Offline → Online transition} | {Sync completes} |

---

## 4. E2E Tests (Acceptance - Outer Loop)

> **Executor:** QA agent, manual tester, or automation framework
> **Evidence:** Screenshot REQUIRED for each checkpoint
> **Characteristics:** Full user journey, real device/emulator

### 4.1 Happy Path Tests

| ID | Scenario | Pre-conditions | Steps | Expected Outcome | Visual Oracle |
|----|----------|----------------|-------|------------------|---------------|
| E2E-001 | {Primary flow name} | {Setup required} | 1. {Step 1}<br>2. {Step 2}<br>3. {Step 3} | {Success state} | {Figma URL or design-brief ref} |
| E2E-002 | {Secondary flow name} | {Setup required} | 1. {Step 1}<br>2. {Step 2} | {Success state} | {Visual ref} |

### 4.2 Error Handling Tests

| ID | Scenario | Pre-conditions | Steps | Expected Outcome | Visual Oracle |
|----|----------|----------------|-------|------------------|---------------|
| E2E-010 | {Invalid input scenario} | {Setup} | {Steps} | {Error message shown} | {Visual ref} |
| E2E-011 | {Network error scenario} | No network | {Steps} | {Offline error shown} | {Visual ref} |

### 4.3 Edge Case Tests

| ID | Scenario | Pre-conditions | Steps | Expected Outcome | Visual Oracle |
|----|----------|----------------|-------|------------------|---------------|
| E2E-020 | {Boundary condition} | {Setup} | {Steps} | {Expected handling} | {Visual ref} |
| E2E-021 | {Concurrent action} | {Setup} | {Steps} | {No race condition} | {Visual ref} |

---

## 5. Visual Regression Tests

> **Executor:** Visual diff tool, PAL Consensus, or manual design review
> **Tolerance:** Strict (< 1% difference) unless animation/dynamic content
> **Source of Truth:** Figma designs or design-brief.md

### 5.1 Screen State Matrix

| ID | Screen | State | Reference | Tolerance | Notes |
|----|--------|-------|-----------|-----------|-------|
| VIS-001 | {ScreenName} | Default | {Figma URL / design-brief section} | Strict | |
| VIS-002 | {ScreenName} | Loading | {Reference} | Flexible | Animation |
| VIS-003 | {ScreenName} | Error | {Reference} | Strict | |
| VIS-004 | {ScreenName} | Empty | {Reference} | Strict | |
| VIS-005 | {ScreenName} | Success | {Reference} | Strict | |

### 5.2 Visual Oracle Inventory

| Screen | States Documented | Visual References | Gaps |
|--------|-------------------|-------------------|------|
| {Screen 1} | {N} states | {All/Partial/None} | {Missing states} |
| {Screen 2} | {N} states | {All/Partial/None} | {Missing states} |

---

## 6. AC → Test Traceability Matrix

> Proves EVERY acceptance criterion has test coverage.

| AC ID | AC Description | Unit | Integration | E2E | Visual | Status |
|-------|----------------|------|-------------|-----|--------|--------|
| AC-001 | {Description} | UT-001 | - | E2E-001 | VIS-001 | COVERED |
| AC-002 | {Description} | UT-002 | INT-001 | E2E-001 | - | COVERED |
| AC-003 | {Description} | UT-003 | - | E2E-010 | VIS-003 | COVERED |
| AC-004 | {Description} | - | - | - | - | **GAP** |

### Coverage Summary

| Metric | Count | Percentage |
|--------|-------|------------|
| Total Acceptance Criteria | {N} | 100% |
| ACs with Unit Test coverage | {N} | {%} |
| ACs with Integration Test coverage | {N} | {%} |
| ACs with E2E Test coverage | {N} | {%} |
| ACs with Visual Test coverage | {N} | {%} |
| **ACs without ANY coverage** | {N} | {%} |

### Coverage Gaps (MUST be addressed)

{List any ACs without test coverage and recommended tests}

---

## 7. Test Execution Order

> TDD-compliant execution sequence.

### Phase 1: Pre-Implementation (TDD)

**Goal:** Write failing tests BEFORE writing any implementation code.

```
[ ] Write UT-001 through UT-{N} (ViewModels)
[ ] Write UT-010 through UT-{N} (UseCases)
[ ] Write UT-020 through UT-{N} (Repositories)
[ ] Verify ALL unit tests FAIL (no implementation yet)
```

### Phase 2: During Implementation

**Goal:** Implement components and verify unit tests pass.

```
[ ] Implement {Component 1} → Run UT-001, UT-002 → Should PASS
[ ] Implement {Component 2} → Run UT-010, UT-011 → Should PASS
[ ] Implement {Component 3} → Run UT-020, UT-021 → Should PASS
```

### Phase 3: Post-Implementation

**Goal:** Verify component integration works correctly.

```
[ ] Run INT-001 through INT-{N}
[ ] Verify all integration tests PASS
[ ] Fix any integration issues
```

### Phase 4: Acceptance Testing

**Goal:** Execute full user journeys with evidence.

```
[ ] Execute E2E-001 (Primary flow) - Capture screenshots
[ ] Execute E2E-002 through E2E-{N} - Capture screenshots
[ ] Document any failures with reproduction steps
```

### Phase 5: Visual Approval

**Goal:** Verify UI matches design specifications.

```
[ ] Compare VIS-001 through VIS-{N} against Figma oracles
[ ] Document any visual deviations
[ ] Get design sign-off on acceptable differences
```

---

## 8. Edge Cases from MPA Analysis

> Edge cases injected from MPA-EdgeCases phase (if available).

| MPA ID | Edge Case | Severity | Converted To Test |
|--------|-----------|----------|-------------------|
| EC-001 | {Edge case description} | CRITICAL | E2E-020, UT-030 |
| EC-002 | {Edge case description} | HIGH | INT-015 |
| EC-003 | {Edge case description} | MEDIUM | UT-031 |

---

## 9. Quality Gates Compliance

> How tests verify specification quality requirements.

| Quality Gate | Test Coverage | Tests |
|--------------|---------------|-------|
| Testability (AC have tests) | {%} coverage | All UT-*, INT-*, E2E-* |
| Edge Cases Documented | {N} edge cases | E2E-020+, UT-030+ |
| Visual Compliance | {N} states | VIS-* |
| Error Handling | {N} error scenarios | E2E-010+, UT-*error* |

---

## Self-Critique Summary

### Test Plan Quality Check

| Criterion | Status | Evidence |
|-----------|--------|----------|
| All ACs have tests? | {PASS/FAIL} | {AC count} with coverage |
| Risk areas covered? | {PASS/FAIL} | {N} risk mitigations |
| Visual oracles complete? | {PASS/FAIL} | {N}/{M} states documented |
| Edge cases documented? | {PASS/FAIL} | {N} edge case tests |
| TDD order specified? | {PASS/FAIL} | 5-phase execution plan |

### Gaps to Address Before Implementation

{List any identified gaps or concerns}

---

## Approval

| Role | Name | Date | Approved |
|------|------|------|----------|
| QA Strategist Agent | | {DATE} | [x] Generated |
| Product Owner | | | [ ] |
| Tech Lead | | | [ ] |
| QA Lead | | | [ ] |
