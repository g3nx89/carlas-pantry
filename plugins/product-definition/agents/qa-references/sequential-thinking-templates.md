# QA Strategist Sequential Thinking Templates

> Reference file for `qa-strategist.md` agent.
> Load this file when starting V-Model test strategy generation.

---

## Template Overview

The QA Strategist uses **8 structured thoughts** to systematically generate a comprehensive V-Model test strategy.

| Thought | Focus Area | Output |
|---------|------------|--------|
| T1 | Failure Mode Analysis | Risk assessment table |
| T2 | Critical E2E Flows | Primary user journey mapping |
| T3 | Secondary/Recovery Flows | Alternative paths and error recovery |
| T4 | Component Boundaries | Integration test targets |
| T5 | Visual Oracles | UI state inventory |
| T6 | AC Traceability | AC → Test mapping |
| T7 | Edge Cases | Boundary and edge case tests |
| T8 | Synthesis | Complete test strategy |

---

## T1: Failure Mode Analysis

**Purpose:** Identify all ways the feature could FAIL before writing any tests.

**Invocation:**
```json
{
  "thought": "Step 1/8: Let me identify all the ways this feature could FAIL...",
  "thoughtNumber": 1,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Failure modes exist in: network, permissions, empty states, process death, config changes",
  "confidence": "exploring"
}
```

**Analysis Framework:**

| Category | Questions to Answer |
|----------|---------------------|
| Network Failures | What network operations exist? What happens when they fail? Timeout? Retry? |
| Permission Denials | What permissions are required? How to handle denial gracefully? |
| Empty States | What UI depends on data? What shows when data is absent? |
| Process Death | What state needs restoration? What happens mid-operation? |
| Configuration Changes | What components are rotation-sensitive? What survives config change? |
| Concurrency | What operations can happen simultaneously? Race conditions? |
| Data Edge Cases | Null values? Empty strings? Maximum lengths? Special characters? |

**Output:** Risk Assessment Table with Severity and Mitigation Tests

---

## T2: Critical E2E Flow Mapping

**Purpose:** Map the PRIMARY user journey that MUST work for acceptance.

**Invocation:**
```json
{
  "thought": "Step 2/8: Let me map CRITICAL user flows that require E2E coverage...",
  "thoughtNumber": 2,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Primary flow: [entry] → [key actions] → [success state]",
  "confidence": "low"
}
```

**Analysis Framework:**

1. **Identify Entry Point:** How does the user start this flow?
2. **Map Key Actions:** What are the essential steps in the happy path?
3. **Define Success State:** What indicates the flow completed successfully?
4. **Identify Checkpoints:** Where should we capture screenshot evidence?

**Output:** Primary flow description with E2E test IDs

---

## T3: Secondary and Recovery Flows

**Purpose:** Map alternative paths and error recovery scenarios.

**Invocation:**
```json
{
  "thought": "Step 3/8: Let me identify SECONDARY flows and error recovery paths...",
  "thoughtNumber": 3,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Secondary flows include: [alternatives]; Recovery: [how users recover]",
  "confidence": "low"
}
```

**Analysis Framework:**

1. **Alternative Paths:** What other routes lead to the same goal?
2. **Branch Points:** Where can the user take a different path?
3. **Error States:** What failure states can the user encounter?
4. **Recovery Actions:** How does the user get back on track after an error?

**Output:** Secondary flow descriptions and recovery path E2E test IDs

---

## T4: Component Boundary Analysis

**Purpose:** Identify integration test targets at component boundaries.

**Invocation:**
```json
{
  "thought": "Step 4/8: Let me find COMPONENT BOUNDARIES that need integration tests...",
  "thoughtNumber": 4,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Key boundaries: ViewModel↔Repository, Repository↔DataSource, UI↔State",
  "confidence": "medium"
}
```

**Analysis Framework:**

| Boundary | Test Focus |
|----------|------------|
| ViewModel ↔ Repository | Data transformation, state updates, error propagation |
| Repository ↔ DataSource | Caching, freshness, offline fallback |
| UI ↔ ViewModel | State synchronization, event handling |
| Navigation ↔ Screens | Deep links, back stack, argument passing |
| Cache ↔ Network | Stale data, refresh triggers, conflict resolution |

**Output:** Integration test table with component pairs and scenarios

---

## T5: Visual Oracle Mapping

**Purpose:** Identify all UI states requiring visual verification.

**Invocation:**
```json
{
  "thought": "Step 5/8: Let me locate VISUAL ORACLES from the design specs...",
  "thoughtNumber": 5,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Each screen has states: default, loading, error, empty, success",
  "confidence": "medium"
}
```

**Analysis Framework:**

For each screen in the feature:

1. **Enumerate States:**
   - Default (initial state)
   - Loading (async operation in progress)
   - Error (operation failed)
   - Empty (no data available)
   - Success (operation completed)
   - Disabled (interaction blocked)

2. **Identify Oracle Source:**
   - Figma design (preferred) → Extract nodeId/URL
   - Design Brief section → Reference section name
   - Spec description → Quote requirements

3. **Define Tolerance:**
   - Strict (< 1%) for static content
   - Flexible (< 5%) for animations
   - Relaxed (< 10%) for dynamic content

**Output:** Visual test table with Screen, State, Reference, Tolerance

---

## T6: AC → Test Traceability

**Purpose:** Map EVERY Acceptance Criterion to specific tests.

**Invocation:**
```json
{
  "thought": "Step 6/8: Let me map each ACCEPTANCE CRITERION to specific tests...",
  "thoughtNumber": 6,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "100% AC coverage required across test levels",
  "confidence": "medium"
}
```

**Analysis Framework:**

1. **Extract All ACs:** List every AC-XXX from the specification
2. **Classify Each AC:**
   - State/Logic → Unit Test
   - Data Persistence → Integration Test
   - User Journey → E2E Test
   - UI Appearance → Visual Test
3. **Assign Test IDs:** Map AC to specific test identifiers
4. **Identify Gaps:** Flag any AC without test coverage

**Traceability Rules:**
- Every AC MUST have at least one test
- Some ACs may have multiple tests at different levels
- No test should exist without an AC reference (except edge case tests)

**Output:** Traceability matrix with AC ID, Description, Unit, Integration, E2E, Visual columns

---

## T7: Edge Case Analysis

**Purpose:** Identify edge cases not covered by happy path tests.

**Invocation:**
```json
{
  "thought": "Step 7/8: Let me identify EDGE CASES not covered by happy path...",
  "thoughtNumber": 7,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,
  "hypothesis": "Edge cases exist in: boundary values, concurrency, offline, data limits",
  "confidence": "medium"
}
```

**Analysis Framework:**

| Category | Examples |
|----------|----------|
| Boundary Values | Min/max input lengths, zero, negative numbers, Unicode |
| Concurrent Access | Multiple devices, race conditions, optimistic locking |
| Offline Behavior | No network, intermittent connection, airplane mode |
| Data Limits | Empty lists, max list size, pagination boundaries |
| Timing | Rapid taps, slow network, operation timeout |
| State Transitions | Interrupted operations, partial completion |

**Integration with MPA-EdgeCases:**
If `mpa-edgecases*.md` exists from Phase 4.3, incorporate those findings:
- CRITICAL → E2E test
- HIGH → Integration test
- MEDIUM/LOW → Unit test

**Output:** Edge case test list with IDs and severity

---

## T8: Strategy Synthesis

**Purpose:** Compile complete test strategy with execution order.

**Invocation:**
```json
{
  "thought": "Step 8/8: Let me synthesize the complete TEST STRATEGY with priorities...",
  "thoughtNumber": 8,
  "totalThoughts": 8,
  "nextThoughtNeeded": false,
  "hypothesis": "Test strategy complete with TDD execution order",
  "confidence": "high"
}
```

**Synthesis Checklist:**

- [ ] All ACs have test coverage (100%)
- [ ] All identified risks have mitigation tests
- [ ] All screens have visual oracles
- [ ] All edge cases have tests
- [ ] TDD execution order defined (Unit → Integration → E2E → Visual)
- [ ] Test dependencies documented
- [ ] Quality gates mapped

**Output:** Complete test-plan.md using template

---

## Invocation Pattern Summary

```json
{
  "thought": "Step X/8: [Analysis description]",
  "thoughtNumber": X,
  "totalThoughts": 8,
  "nextThoughtNeeded": true,  // false only on T8
  "hypothesis": "[Current working hypothesis]",
  "confidence": "exploring|low|medium|high"
}
```

**Confidence Progression:**
- T1-T2: `exploring` → `low` (gathering information)
- T3-T5: `low` → `medium` (building understanding)
- T6-T7: `medium` (applying rules)
- T8: `high` (synthesizing complete strategy)

---

## Error Handling

If any thought reveals a blocker:

1. **Missing Spec Content:** Flag as clarification needed, continue with available info
2. **No Figma Context:** Use design-brief.md as fallback for visual oracles
3. **No MPA-EdgeCases:** Generate edge cases from scratch using T7 framework
4. **Coverage Gap:** Explicitly document in test plan for manual review
