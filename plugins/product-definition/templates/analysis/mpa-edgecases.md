# MPA Edge Cases Report

**Phase:** 4.3 - Edge Case Mining
**Model:** {MODEL_ALIAS} (thinking_mode: {THINKING_MODE})
**Timestamp:** {ISO_DATE}
**Duration:** {DURATION_MS}ms

---

## Summary

| Severity | Count | Injected to Clarification |
|----------|-------|---------------------------|
| CRITICAL | {N} | {N} |
| HIGH | {N} | {N} |
| MEDIUM | {N} | 0 |
| LOW | {N} | 0 |

---

## CRITICAL Edge Cases

> These MUST be addressed before implementation.

### EC-001: {EDGE_CASE_TITLE}
- **Category:** {CATEGORY}
- **Scenario:** {DETAILED_DESCRIPTION}
- **Current Coverage:** Not addressed in spec
- **Potential Impact:** {WHAT_COULD_GO_WRONG}
- **Suggested Requirement:** {SPECIFIC_REQUIREMENT_TEXT}
- **Injected as Clarification:** Yes - Question #{N}

### EC-002: {EDGE_CASE_TITLE}
...

---

## HIGH Edge Cases

> Should be addressed; may cause poor UX.

### EC-003: {EDGE_CASE_TITLE}
- **Category:** {CATEGORY}
- **Scenario:** {DESCRIPTION}
- **Current Coverage:** Partially addressed in {SECTION}
- **Gap:** {WHATS_MISSING}
- **Suggested Requirement:** {REQUIREMENT_TEXT}
- **Injected as Clarification:** Yes - Question #{N}

---

## MEDIUM Edge Cases

> Minor inconvenience if not addressed.

### EC-004: {EDGE_CASE_TITLE}
- **Category:** {CATEGORY}
- **Scenario:** {DESCRIPTION}
- **Current Coverage:** {COVERAGE_STATUS}
- **Gap:** {WHATS_MISSING}
- **Suggested Requirement:** {REQUIREMENT_TEXT}
- **Injected as Clarification:** No (severity too low)

---

## LOW Edge Cases

> Nice to have, not essential.

### EC-005: {EDGE_CASE_TITLE}
- **Category:** {CATEGORY}
- **Scenario:** {DESCRIPTION}
- **Note:** {WHY_LOW_PRIORITY}

---

## Edge Cases by Category

| Category | CRITICAL | HIGH | MEDIUM | LOW |
|----------|----------|------|--------|-----|
| Error Handling | {N} | {N} | {N} | {N} |
| Concurrency | {N} | {N} | {N} | {N} |
| Security | {N} | {N} | {N} | {N} |
| Performance | {N} | {N} | {N} | {N} |
| Accessibility | {N} | {N} | {N} | {N} |
| i18n | {N} | {N} | {N} | {N} |

---

## Coverage Analysis

| Aspect | Covered | Gap |
|--------|---------|-----|
| Error States | {STATUS} | {GAP_DESCRIPTION} |
| Network Failures | {STATUS} | {GAP_DESCRIPTION} |
| Concurrent Access | {STATUS} | {GAP_DESCRIPTION} |
| Security Boundaries | {STATUS} | {GAP_DESCRIPTION} |
| Performance Limits | {STATUS} | {GAP_DESCRIPTION} |
| Accessibility (A11y) | {STATUS} | {GAP_DESCRIPTION} |
| Internationalization | {STATUS} | {GAP_DESCRIPTION} |

---

## Injected Clarification Questions

Questions automatically injected for user response (CRITICAL + HIGH):

1. **EC-001:** {QUESTION_DERIVED_FROM_EDGE_CASE}
2. **EC-002:** {QUESTION_DERIVED_FROM_EDGE_CASE}
...

---

## ThinkDeep Analysis Details

### Prompt Used

```
{THINKDEEP_PROMPT}
```

### Focus Areas

- {FOCUS_AREA_1}
- {FOCUS_AREA_2}
- {FOCUS_AREA_3}
