# MPA Challenge Report (Parallel Multi-Model)

**Phase:** 2.3 - Problem Challenge
**Mode:** Parallel (v4)
**Timestamp:** {ISO_DATE}
**Total Duration:** {TOTAL_DURATION_MS}ms

---

## Model Execution Summary

| Model | Focus Area | Duration | Findings | Status |
|-------|------------|----------|----------|--------|
| gpt5.2 | Root Cause Analysis | {DURATION_MS}ms | {FINDING_COUNT} | {STATUS} |
| pro | Alternative Interpretations | {DURATION_MS}ms | {FINDING_COUNT} | {STATUS} |
| grok-4 | Assumption Validation | {DURATION_MS}ms | {FINDING_COUNT} | {STATUS} |

> **Note:** Some models may show `SKIPPED` or `ERROR` status if unavailable during execution.
> Partial results are valid - analysis continues with available models.
> Cross-model findings will reflect only responding models.

---

## Synthesis Summary

| Metric | Value |
|--------|-------|
| Total Findings (pre-dedup) | {TOTAL_PRE_DEDUP} |
| Deduplicated | {DEDUP_COUNT} |
| **Final Findings** | {FINAL_COUNT} |
| Cross-Model Findings (2+/3) | {CROSS_MODEL_COUNT} |
| Risk Level | {RISK_LEVEL} |

---

## Priority Distribution

| Priority | Count | Criteria |
|----------|-------|----------|
| CRITICAL | {N} | 3/3 model agreement |
| HIGH | {N} | 2/3 model agreement |
| MEDIUM | {N} | Single model finding |
| LOW | {N} | Low confidence single model |

---

## Cross-Model Findings (High Confidence)

> Issues identified by multiple models receive priority boost.

### CM-001: {FINDING_TITLE} CRITICAL (3/3 agreement)

**Model Agreement Matrix:**

| Model | Identified? | Quote |
|-------|-------------|-------|
| gpt5.2 | {CHECK} | "{QUOTE}" |
| pro | {CHECK} | "{QUOTE}" |
| grok-4 | {CHECK} | "{QUOTE}" |

- **Synthesized Finding:** {MERGED_DESCRIPTION}
- **Recommendation:** {ACTION}
- **Action:** REQUIRES-DECISION

---

### CM-002: {FINDING_TITLE} HIGH (2/3 agreement)

**Model Agreement Matrix:**

| Model | Identified? | Quote |
|-------|-------------|-------|
| gpt5.2 | {CHECK} | "{QUOTE}" |
| pro | {CHECK} | "{QUOTE}" |
| grok-4 | {CHECK} | - |

- **Synthesized Finding:** {MERGED_DESCRIPTION}
- **Dissenting View:** {WHY_ONE_MODEL_DISAGREED}
- **Recommendation:** {ACTION}
- **Action:** AUTO-INCORPORATED | REQUIRES-DECISION

---

## Single-Model Findings

### SM-001: {FINDING_TITLE} (gpt5.2 only)

- **Source Model:** gpt5.2
- **Focus Area:** Root Cause Analysis
- **Finding:** {DESCRIPTION}
- **Recommendation:** {ACTION}
- **Priority:** MEDIUM
- **Action:** NOTED

### SM-002: {FINDING_TITLE} (pro only)

- **Source Model:** pro
- **Focus Area:** Alternative Interpretations
- **Finding:** {DESCRIPTION}
- **Recommendation:** {ACTION}
- **Priority:** MEDIUM
- **Action:** NOTED

### SM-003: {FINDING_TITLE} (grok-4 only)

- **Source Model:** grok-4
- **Focus Area:** Assumption Validation
- **Finding:** {DESCRIPTION}
- **Recommendation:** {ACTION}
- **Priority:** MEDIUM
- **Action:** NOTED

---

## Model-Specific Insights

### gpt5.2 (Root Cause Analysis)

> GPT excels at narrative and business logic analysis.

1. {INSIGHT_1}
2. {INSIGHT_2}

### pro (Alternative Interpretations)

> Gemini provides structured reasoning and technical alternatives.

1. {INSIGHT_1}
2. {INSIGHT_2}

### grok-4 (Assumption Validation)

> Grok provides extended thinking and assumption validation.

1. {INSIGHT_1}
2. {INSIGHT_2}

---

## Auto-Incorporated Changes

Changes applied automatically (cross-model confidence > 80%):

1. **{CHANGE_TITLE}** (CM-{ID})
   - Models Agreed: {N}/3
   - Before: "{ORIGINAL_TEXT}"
   - After: "{UPDATED_TEXT}"
   - Rationale: {WHY_SAFE}

---

## Requires User Decision

Issues requiring explicit user input:

1. **{ISSUE_TITLE}** (CM-{ID})
   - Model Agreement: {N}/3 ({PRIORITY})
   - Finding: {DESCRIPTION}
   - Options:
     - A) {OPTION_1}
     - B) {OPTION_2}
   - Model Recommendations:
     - gpt5.2: {RECOMMENDATION}
     - pro: {RECOMMENDATION}
     - grok-4: {RECOMMENDATION}
   - Synthesizer Recommendation: {FINAL_RECOMMENDATION}

---

## RED Flag Details (if applicable)

> This section appears only when `risk_level == "red"`

**CRITICAL ISSUE DETECTED** (3/3 model agreement)

- **Issue:** {DESCRIPTION}
- **Impact:** {WHAT_HAPPENS_IF_NOT_ADDRESSED}
- **All Models Agree:** This is a blocking issue
- **Required Action:** User must acknowledge or revise before proceeding

---

## Deduplication Log

| Removed Finding | Merged Into | Similarity | Decision |
|-----------------|-------------|------------|----------|
| {FINDING_ID} | {TARGET_ID} | {SCORE} | {REASON} |

---

## Synthesis Metadata

- **Synthesizer Model:** {MODEL}
- **Strategy:** {STRATEGY}
- **Execution Time:** {DURATION_MS}ms
