# Specification Quality Checklist: [FEATURE NAME]

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: [DATE]
**Feature**: [Link to spec.md]
**Type**: Generic (Non-Mobile)

---

## 1. Problem Framing Canvas

- [ ] **Persona Defined**: "I am" section describes a concrete persona with 3+ pain points
- [ ] **Goals Clear**: "Trying to" states desired outcomes in one sentence
- [ ] **Barriers Identified**: "But" lists 3+ specific barriers/obstacles
- [ ] **Root Cause Found**: "Because" explains the empathetic root cause
- [ ] **Emotional Impact**: "Which makes me feel" captures persona emotions
- [ ] **Problem Statement**: Final statement is concise, powerful, and captures WHO/WHAT/WHY

---

## 2. Jobs-to-be-Done Analysis

- [ ] **Functional Jobs**: At least 2 tasks the user needs to perform
- [ ] **Social Jobs**: How the user wants to be perceived (or marked N/A with rationale)
- [ ] **Emotional Jobs**: Feelings the user seeks to achieve/avoid
- [ ] **Pains Mapped**: Challenges, costliness, common mistakes, unresolved problems
- [ ] **Gains Mapped**: Expectations, savings, adoption factors, life improvements
- [ ] **JTBD-Story Alignment**: Each user story traces back to a documented job

---

## 3. Epic Hypothesis

- [ ] **If/Then Statement**: Clear action, target persona, and expected outcome
- [ ] **Experiments Defined**: At least 2 Tiny Acts of Discovery to test assumption
- [ ] **Validation Measures**: Quantitative AND qualitative measures with timeframe
- [ ] **Pivot Criteria**: Clear thresholds for when to abandon/pivot

---

## 4. User Stories Quality

### Obstacle-Aware Format
- [ ] **All Stories Have "but" Clause**: Every story identifies an obstacle/constraint
- [ ] **Persona in Context**: Stories specify persona AND context, not just role
- [ ] **JTBD Alignment**: "so that I can" connects to documented jobs

### Gherkin Acceptance Criteria
- [ ] **Single When**: Each story has exactly ONE atomic action
- [ ] **Single Then**: Each story has exactly ONE observable outcome
- [ ] **Rich Context**: Multiple "Given" clauses load sufficient context
- [ ] **Testable**: QA can write automated tests from criteria

### Story Atomicity
- [ ] **Splitting Check Passed**: All stories pass the 4-point splitting check
- [ ] **No Compound Logic**: No AND/OR in When or Then clauses
- [ ] **Single Role**: Each story addresses one user type
- [ ] **Sprint-Sized**: Each story completable in one sprint or less

---

## 5. Content Quality

- [ ] **No Implementation Details**: No references to languages, frameworks, APIs, databases, or architecture
- [ ] **User-Centric**: Requirements describe user experience and business needs, not developer tasks
- [ ] **Written for Non-Technical Stakeholders**: Product managers, designers, and business owners can understand and validate without engineering background
- [ ] **Clean Document**: No `[TBD]`, `[NEEDS CLARIFICATION]`, or `?` placeholders remain
- [ ] **Structure Complete**: All mandatory spec sections present and filled

---

## 6. Requirement Completeness

- [ ] **Scope Bounded**: In scope and out of scope explicitly defined
- [ ] **Primary Flows Covered**: User scenarios address all main use cases
- [ ] **Edge Cases Identified**: Boundary conditions and unhappy paths documented
- [ ] **Dependencies Documented**: External systems and integration points identified
- [ ] **Assumptions Stated**: Key assumptions explicitly listed

---

## 7. Success Criteria

- [ ] **Measurable**: All criteria include specific metrics (time, %, count)
- [ ] **Technology-Agnostic**: No mention of APIs, databases, or frameworks
- [ ] **User-Focused**: Describes outcomes from user/business perspective
- [ ] **Verifiable**: Can be tested without knowing implementation details
- [ ] **Cross-Validated**: Each criterion traces back to a functional requirement

---

## 8. Testability (The Gate)

### Basic Testability
- [ ] **All FRs Have AC**: Every functional requirement has acceptance criteria
- [ ] **Binary Pass/Fail**: All criteria are unambiguous
- [ ] **QA Ready**: Test cases can be written solely from this document
- [ ] **No Implementation Leakage**: AC don't depend on technical implementation
- [ ] **Feature Completeness**: Feature meets all measurable outcomes defined in Success Criteria

### V-Model Test Alignment
- [ ] **State Logic ACs**: ACs describing state/logic changes are unit-testable
- [ ] **Data Flow ACs**: ACs describing data persistence are integration-testable
- [ ] **User Journey ACs**: ACs describing user flows are E2E-testable
- [ ] **UI Appearance ACs**: ACs describing visual elements are visually verifiable
- [ ] **Edge Cases Documented**: Failure modes and boundary conditions specified

### Test Coverage Readiness
- [ ] **Happy Path Clear**: Primary success scenario fully described
- [ ] **Error States Defined**: How errors should appear/behave documented
- [ ] **Empty States Defined**: What shows when no data exists
- [ ] **Loading States Defined**: What shows during async operations
- [ ] **Offline Behavior Defined**: How app behaves without network (if applicable)

---

## 9. V-Model Traceability (Test Strategy)

> Validates the specification is ready for V-Model test planning.

### Acceptance Criteria Format
- [ ] **Gherkin Format**: All AC use Given/When/Then structure
- [ ] **Single When Clause**: Each AC has exactly ONE action (atomic)
- [ ] **Single Then Clause**: Each AC has exactly ONE outcome (verifiable)
- [ ] **Testable Assertions**: Then clauses are observable/measurable

### Test Level Mapping
- [ ] **Unit-Testable Logic**: Business rules can be tested in isolation
- [ ] **Component Boundaries Clear**: Integration points identifiable
- [ ] **User Flows Documented**: E2E scenarios extractable from stories
- [ ] **Visual States Enumerated**: UI states documented per screen

### Risk-Based Testing
- [ ] **Failure Modes Identified**: What can go wrong is documented
- [ ] **Critical Paths Marked**: Must-work scenarios distinguishable
- [ ] **Edge Cases Listed**: Boundary conditions explicitly stated
- [ ] **Error Recovery Defined**: How users recover from failures

---

## Checklist Summary

| Section | Items | Passed |
|---------|-------|--------|
| Problem Framing | 6 | [ ]/6 |
| JTBD Analysis | 6 | [ ]/6 |
| Epic Hypothesis | 4 | [ ]/4 |
| User Stories | 11 | [ ]/11 |
| Content Quality | 5 | [ ]/5 |
| Requirements | 5 | [ ]/5 |
| Success Criteria | 5 | [ ]/5 |
| Testability (Basic) | 5 | [ ]/5 |
| Testability (V-Model) | 5 | [ ]/5 |
| Test Coverage Readiness | 5 | [ ]/5 |
| V-Model Traceability | 12 | [ ]/12 |
| **TOTAL** | **69** | **[ ]/69** |

**Passing Threshold**: ≥62/69 items (90%) to proceed to `/sdd:02-plan`

---

## Notes

{Issues found during validation}

---

## Validator Sign-off

| Validator | Date | Result |
|-----------|------|--------|
| business-analyst | | PASS / FAIL |
| PAL Consensus | | APPROVED / CONDITIONAL / REJECTED |
