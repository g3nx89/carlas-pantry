# MPA Challenge Report

**Phase:** 2.3 - Problem Challenge
**Model:** {MODEL_ALIAS} (thinking_mode: {THINKING_MODE})
**Timestamp:** {ISO_DATE}
**Duration:** {DURATION_MS}ms

---

## Summary

| Metric | Value |
|--------|-------|
| Assumptions Challenged | {ASSUMPTIONS_COUNT} |
| Risk Level | {RISK_LEVEL} |
| Auto-Incorporated | {AUTO_COUNT} |
| Requires User Decision | {USER_DECISION_COUNT} |

---

## Challenged Assumptions

### CA-001: {ASSUMPTION_TITLE}
- **Spec Text:** "{QUOTED_SPEC_TEXT}"
- **Challenge:** {WHY_THIS_MIGHT_BE_WRONG}
- **Alternative Interpretation:** {DIFFERENT_UNDERSTANDING}
- **Recommendation:** {SPECIFIC_FIX}
- **Priority:** HIGH | MEDIUM | LOW
- **Action:** AUTO-INCORPORATED | REQUIRES-DECISION | NOTED

### CA-002: {ASSUMPTION_TITLE}
...

---

## Auto-Incorporated Changes

Changes applied automatically (confidence > 80%):

1. **{CHANGE_TITLE}**
   - Before: "{ORIGINAL_TEXT}"
   - After: "{UPDATED_TEXT}"
   - Rationale: {WHY_SAFE_TO_AUTO_APPLY}

---

## Requires User Decision

Issues requiring explicit user input:

1. **{ISSUE_TITLE}**
   - Finding: {DESCRIPTION}
   - Options:
     - A) {OPTION_1}
     - B) {OPTION_2}
   - Recommendation: {WHICH_AND_WHY}

---

## RED Flag Details (if applicable)

> This section appears only when `risk_level == "red"`

**CRITICAL ISSUE DETECTED**

- **Issue:** {DESCRIPTION}
- **Impact:** {WHAT_HAPPENS_IF_NOT_ADDRESSED}
- **Required Action:** User must acknowledge or revise before proceeding

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

### Raw Response Summary

{RESPONSE_SUMMARY}
