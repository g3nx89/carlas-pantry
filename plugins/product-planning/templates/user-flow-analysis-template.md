# User Flow Analysis Template (A1)

Output format for flow-analyzer agent. Maps user journeys, decision points, and test permutations.

## Flow Analysis: {FEATURE_NAME}

**Analysis Date:** {DATE}
**Analyst:** flow-analyzer
**Spec Source:** {SPEC_FILE_PATH}

---

## 1. Identified User Flows

### Flow 1: {FLOW_NAME}

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLOW DIAGRAM                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [Entry Point] ──→ [Step 1] ──→ [Decision] ──┬──→ [Step 2a]     │
│                                              │                   │
│                                              └──→ [Step 2b]     │
│                                                      ↓           │
│                                               [Exit Point]       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

| Step | Description | Decision Point? | Branches |
|------|-------------|-----------------|----------|
| 1 | {description} | No | - |
| 2 | {description} | Yes | A: {condition}, B: {condition} |
| 3 | {description} | No | - |

**Actors involved:** {actor1}, {actor2}
**State changes:** {state1} → {state2}

---

### Flow 2: {FLOW_NAME}

{Repeat structure for each identified flow}

---

## 2. Decision Points Analysis

| ID | Decision Point | Condition | Branch A | Branch B | Branch C |
|----|----------------|-----------|----------|----------|----------|
| D1 | {description} | {condition} | {outcome} | {outcome} | - |
| D2 | {description} | {condition} | {outcome} | {outcome} | {outcome} |

### Decision Dependencies

```yaml
decision_tree:
  D1:
    condition: "{condition expression}"
    true_branch: D2
    false_branch: EXIT_FLOW_1
  D2:
    condition: "{condition expression}"
    true_branch: STEP_3A
    false_branch: STEP_3B
```

---

## 3. Permutation Matrix

### Complete Permutation Count

| Flow | Decision Points | Theoretical Permutations | Practical Permutations |
|------|-----------------|--------------------------|------------------------|
| Flow 1 | 3 | 8 | 5 (3 impossible) |
| Flow 2 | 2 | 4 | 4 |
| **Total** | **5** | **12** | **9** |

### Prioritized Test Paths

| Priority | Path ID | Flow | Decisions | Description | Rationale |
|----------|---------|------|-----------|-------------|-----------|
| P1 | PATH-001 | Flow 1 | D1→A, D2→A | Happy path | Most common user journey |
| P1 | PATH-002 | Flow 1 | D1→A, D2→B | Alt success | Second most common |
| P2 | PATH-003 | Flow 1 | D1→B | Error path | Validation failure |
| P3 | PATH-004 | Flow 2 | D3→A | Edge case | Rare but important |

---

## 4. Gap Questions (for Phase 3)

Based on flow analysis, the following questions need clarification:

### Missing Flow Information

| ID | Question | Context | Priority |
|----|----------|---------|----------|
| Q-FLOW-1 | {question about unclear flow} | Found at {decision point} | HIGH |
| Q-FLOW-2 | {question about missing path} | {context} | MEDIUM |

### Undefined Decision Conditions

| ID | Question | Context | Priority |
|----|----------|---------|----------|
| Q-DEC-1 | What happens when {condition}? | Decision D2 | HIGH |
| Q-DEC-2 | Is {edge case} supported? | Decision D1 | LOW |

### State Transition Gaps

| ID | Question | Context | Priority |
|----|----------|---------|----------|
| Q-STATE-1 | What is the state after {action}? | Step 3 | MEDIUM |

---

## 5. Test Scenario Recommendations

### E2E Test Scenarios (from flows)

| ID | Scenario | Flow Path | Priority | Estimated Duration |
|----|----------|-----------|----------|-------------------|
| E2E-001 | {scenario name} | PATH-001 | P1 | 2-3 min |
| E2E-002 | {scenario name} | PATH-002 | P1 | 2-3 min |
| E2E-003 | {scenario name} | PATH-003 | P2 | 1-2 min |

### UAT Script Recommendations

| ID | User Story | Flow | Given-When-Then Summary |
|----|------------|------|-------------------------|
| UAT-001 | As a {actor}, I want to {action} | Flow 1 | Given {state}, When {action}, Then {outcome} |
| UAT-002 | As a {actor}, I want to {action} | Flow 2 | Given {state}, When {action}, Then {outcome} |

---

## 6. Integration Points

### External System Touchpoints

| Flow Step | External System | Integration Type | Test Consideration |
|-----------|-----------------|------------------|-------------------|
| Step 2 | {system name} | API call | Mock/stub needed |
| Step 4 | {system name} | Event publish | Async verification |

### Data Dependencies

| Flow | Required Data | Source | Test Data Strategy |
|------|---------------|--------|-------------------|
| Flow 1 | {data type} | {source} | Seed data / fixtures |
| Flow 2 | {data type} | {source} | Factory generation |

---

## Summary

```yaml
flow_analysis_summary:
  feature: "{FEATURE_NAME}"

  flows_identified: {count}
  decision_points: {count}
  total_permutations: {count}
  prioritized_paths: {count}

  gap_questions_generated: {count}
  test_scenarios_recommended: {count}

  complexity_assessment: "LOW|MEDIUM|HIGH"

  next_steps:
    - "Address {count} HIGH priority gap questions in Phase 3"
    - "Generate E2E tests for {count} P1 scenarios"
    - "Create UAT scripts for {count} user stories"
```

---

## Appendix: Glossary

| Term | Definition |
|------|------------|
| **Decision Point** | A step in the flow where the path branches based on a condition |
| **Permutation** | A unique path through the flow based on decision outcomes |
| **Happy Path** | The expected successful journey through the flow |
| **Edge Case** | A rare but valid path through the flow |
| **E2E Test** | End-to-end test covering a complete user journey |
| **UAT** | User Acceptance Test - validation by business stakeholders |
