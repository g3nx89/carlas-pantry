# Tasks: {FEATURE_NAME}

> **Generated:** {DATE}
> **Mode:** {ANALYSIS_MODE}
> **Test Plan:** {FEATURE_DIR}/test-plan.md

## Overview

| Metric | Value |
|--------|-------|
| Total Tasks | {TASK_COUNT} |
| User Stories | {STORY_COUNT} |
| Parallel Tasks | {PARALLEL_COUNT} |
| TDD Coverage | {TDD_PERCENT}% |
| Critical Path | {CRITICAL_PATH_LENGTH} tasks |

## Implementation Strategy

**Approach:** {top-down | bottom-up | mixed}

**Rationale:** {Why this approach was chosen based on feature characteristics}

**MVP Scope:** {Minimum viable first deliverable - typically Phase 1-3}

---

## Phase 1: Setup

Project initialization and configuration tasks. No story labels.

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Configure build tooling and dependencies
- [ ] T003 Set up linting and formatting rules

---

## Phase 2: Foundational

Blocking prerequisites required before user story implementation. No story labels.
These tasks have ZERO story-specific dependencies and enable all subsequent work.

- [ ] T004 [P] Set up test infrastructure in tests/setup.ts
- [ ] T005 [P] Create base types and interfaces in src/types/
- [ ] T006 [P] Configure database connection in src/lib/db.ts
- [ ] T007 Implement shared utilities in src/utils/

**Test Infrastructure:**
- Test framework configuration
- Mock utilities
- Test data factories

---

## Phase 3: {User Story 1 Title} (P1)

**User Story:** As a {persona}, I want {action} so that {benefit}

**Acceptance Criteria:**
- [ ] AC1: {criterion}
- [ ] AC2: {criterion}

**Test References:** UAT-001, E2E-001, INT-001, UT-001-003

### Tasks

- [ ] T010 [US1] Write failing unit tests: UT-001, UT-002 in tests/unit/
- [ ] T011 [US1] Implement {Model} in src/models/
- [ ] T012 [P] [US1] Write failing unit tests: UT-003 in tests/unit/
- [ ] T013 [US1] Implement {Service} in src/services/
- [ ] T014 [US1] Verify integration tests: INT-001 in tests/integration/
- [ ] T015 [US1] Implement {Endpoint} in src/routes/
- [ ] T016 [US1] Verify E2E test: E2E-001 passes

**Definition of Done:**
- [ ] All unit tests (UT-001 to UT-003) passing
- [ ] Integration test INT-001 passing
- [ ] E2E test E2E-001 passing
- [ ] UAT-001 script executable

---

## Phase 4: {User Story 2 Title} (P2)

**User Story:** As a {persona}, I want {action} so that {benefit}

**Acceptance Criteria:**
- [ ] AC1: {criterion}

**Test References:** UAT-002, E2E-002, INT-002, UT-004-006

### Tasks

- [ ] T020 [US2] Write failing unit tests: UT-004, UT-005 in tests/unit/
- [ ] T021 [US2] Implement {Component} in src/components/
- [ ] T022 [US2] Verify integration test: INT-002
- [ ] T023 [US2] Implement {Feature} endpoint in src/routes/
- [ ] T024 [US2] Verify E2E test: E2E-002 passes

**Definition of Done:**
- [ ] All unit tests (UT-004 to UT-006) passing
- [ ] Integration test INT-002 passing
- [ ] E2E test E2E-002 passing
- [ ] UAT-002 script executable

---

## Phase N: Polish & Cross-Cutting

Final refinements and cross-cutting concerns. No story labels.

- [ ] T090 Add error handling and logging
- [ ] T091 Implement performance optimizations
- [ ] T092 Add documentation and comments
- [ ] T093 Run full test suite and fix failures
- [ ] T094 Code review and final cleanup

---

## Dependencies

### Story Completion Order

```
Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2) → Phase N (Polish)
                                              ↓
                                    [Can run in parallel if independent]
```

### Dependency Graph

| Task | Depends On | Blocks |
|------|------------|--------|
| T001 | - | T002, T003 |
| T004 | T001 | T010, T020 |
| T010 | T004 | T011 |
| T011 | T010 | T013 |
| ... | ... | ... |

### Critical Path

```
T001 → T004 → T010 → T011 → T013 → T015 → T016
```

Estimated critical path: {N} tasks

---

## Parallel Opportunities

Tasks marked with **[P]** can run in parallel with other [P] tasks at the same phase level.

**Phase 2 Parallel Group:**
- T004, T005, T006 (independent foundational tasks)

**Phase 3 Parallel Group:**
- T010, T012 (independent test writing)

---

## Task-to-Test Traceability

| Task ID | User Story | Test IDs | Test Level |
|---------|------------|----------|------------|
| T010 | US1 | UT-001, UT-002 | Unit |
| T011 | US1 | - | Implementation |
| T012 | US1 | UT-003 | Unit |
| T014 | US1 | INT-001 | Integration |
| T016 | US1 | E2E-001 | E2E |
| T020 | US2 | UT-004, UT-005 | Unit |
| T022 | US2 | INT-002 | Integration |
| T024 | US2 | E2E-002 | E2E |

---

## High-Risk Tasks

| Task | Complexity | Uncertainty | Context |
|------|------------|-------------|---------|
| T0XX | High | Medium | {Why this is risky} |
| T0YY | Medium | High | {What is unclear} |

**Mitigation:**
- {Task}: {How risk is addressed - spike, decomposition, etc.}

---

## Validation Summary

```yaml
self_critique:
  questions_passed: X/5
  revisions_made: N
  revision_summary: "Brief description of changes made"
  confidence: "HIGH|MEDIUM|LOW"
  high_risk_tasks: ["T0XX", "T0YY"]

tdd_integration:
  tasks_with_test_refs: X/Y
  percentage: Z%

format_compliance:
  valid_tasks: X/Y
  issues: []
```

---

## Glossary

| Term | Definition |
|------|------------|
| **[P]** | Parallelizable - task can run concurrently with others at same level |
| **[US#]** | User Story reference - maps to P1, P2, etc. from spec.md |
| **TDD** | Test-Driven Development: RED (write failing test) → GREEN (implement) → REFACTOR |
| **UT-###** | Unit Test ID from test-cases/unit/ |
| **INT-###** | Integration Test ID from test-cases/integration/ |
| **E2E-###** | End-to-End Test ID from test-cases/e2e/ |
| **UAT-###** | User Acceptance Test ID from test-cases/uat/ |
| **DoD** | Definition of Done - criteria for task completion |
| **Critical Path** | Longest sequence of dependent tasks determining minimum completion time |

---

*Generated by `/product-planning:plan` Phase 9*
