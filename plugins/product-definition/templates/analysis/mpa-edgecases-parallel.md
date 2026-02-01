# MPA Edge Cases Report (Parallel Multi-Model)

**Phase:** 4.3 - Edge Case Mining
**Mode:** Parallel (v4)
**Timestamp:** {ISO_DATE}
**Total Duration:** {TOTAL_DURATION_MS}ms

---

## Model Execution Summary

| Model | Focus Area | Duration | Findings | Status |
|-------|------------|----------|----------|--------|
| pro | Security / Performance | {DURATION_MS}ms | {N} | {STATUS} |
| gpt5.2 | User Experience | {DURATION_MS}ms | {N} | {STATUS} |
| grok-4 | Accessibility / i18n | {DURATION_MS}ms | {N} | {STATUS} |

> **Note:** Some models may show `SKIPPED` or `ERROR` status if unavailable during execution.
> Partial results are valid - analysis continues with available models.
> Cross-model findings and severity boosts will reflect only responding models.

---

## Synthesis Summary

| Metric | Value |
|--------|-------|
| Total Edge Cases (pre-dedup) | {TOTAL_PRE_DEDUP} |
| Deduplicated | {DEDUP_COUNT} |
| **Final Edge Cases** | {FINAL_COUNT} |
| Cross-Model Cases (severity boosted) | {BOOSTED_COUNT} |
| Injected as Clarifications | {INJECTED_COUNT} |

---

## Severity Distribution (Post-Synthesis)

| Severity | Count | Boosted? | Injected |
|----------|-------|----------|----------|
| CRITICAL | {N} | {N} boosted | {N} |
| HIGH | {N} | {N} boosted | {N} |
| MEDIUM | {N} | - | 0 |
| LOW | {N} | - | 0 |

---

## Cross-Model Edge Cases (Severity Boosted)

> Edge cases identified by 2+ models receive severity boost.

### EC-001: {EDGE_CASE_TITLE} CRITICAL (boosted from HIGH)

**Model Agreement Matrix:**

| Model | Identified? | Original Severity | Focus |
|-------|-------------|-------------------|-------|
| pro | {CHECK} | {SEVERITY} | Security |
| gpt5.2 | {CHECK} | {SEVERITY} | UX |
| grok-4 | {CHECK} | - | - |

- **Category:** {CATEGORY}
- **Scenario (Synthesized):** {MERGED_DESCRIPTION}
- **Gemini View:** {SECURITY_PERFORMANCE_PERSPECTIVE}
- **GPT View:** {UX_PERSPECTIVE}
- **Combined Impact:** {UNIFIED_IMPACT}
- **Suggested Requirement:** {REQUIREMENT_TEXT}
- **Injected as Clarification:** Yes - Question #{N}

---

### EC-002: {EDGE_CASE_TITLE} HIGH (2/3 agreement, no boost needed)

**Model Agreement Matrix:**

| Model | Identified? | Original Severity | Focus |
|-------|-------------|-------------------|-------|
| pro | {CHECK} | HIGH | {FOCUS} |
| gpt5.2 | {CHECK} | HIGH | {FOCUS} |
| grok-4 | {CHECK} | - | - |

- **Category:** {CATEGORY}
- **Scenario:** {DESCRIPTION}
- **Suggested Requirement:** {REQUIREMENT_TEXT}
- **Injected as Clarification:** Yes - Question #{N}

---

## Model-Specific Edge Cases

### From pro (Security / Performance Focus)

| ID | Edge Case | Category | Severity | Scenario |
|----|-----------|----------|----------|----------|
| EC-G-001 | {TITLE} | Security | {SEVERITY} | {BRIEF} |
| EC-G-002 | {TITLE} | Performance | {SEVERITY} | {BRIEF} |
| ... | ... | ... | ... | ... |

### From gpt5.2 (User Experience Focus)

| ID | Edge Case | Category | Severity | Scenario |
|----|-----------|----------|----------|----------|
| EC-GPT-001 | {TITLE} | Error Handling | {SEVERITY} | {BRIEF} |
| EC-GPT-002 | {TITLE} | Concurrency | {SEVERITY} | {BRIEF} |
| ... | ... | ... | ... | ... |

### From grok-4 (Accessibility / i18n Focus)

| ID | Edge Case | Category | Severity | Scenario |
|----|-----------|----------|----------|----------|
| EC-C-001 | {TITLE} | Accessibility | {SEVERITY} | {BRIEF} |
| EC-C-002 | {TITLE} | i18n | {SEVERITY} | {BRIEF} |
| ... | ... | ... | ... | ... |

---

## Edge Cases by Category (Aggregated)

| Category | CRITICAL | HIGH | MEDIUM | LOW | Primary Model |
|----------|----------|------|--------|-----|---------------|
| Error Handling | {N} | {N} | {N} | {N} | gpt5.2 |
| Concurrency | {N} | {N} | {N} | {N} | gpt5.2 |
| Security | {N} | {N} | {N} | {N} | pro |
| Performance | {N} | {N} | {N} | {N} | pro |
| Accessibility | {N} | {N} | {N} | {N} | grok-4 |
| i18n | {N} | {N} | {N} | {N} | grok-4 |

---

## Injected Clarification Questions

Questions automatically injected for user response:

1. **EC-001 (CRITICAL, boosted):** {QUESTION}
   - Models: pro + gpt5.2
   - Why: 2/3 model agreement on HIGH severity -> boosted to CRITICAL

2. **EC-003 (HIGH):** {QUESTION}
   - Model: pro
   - Why: Security-related, CRITICAL/HIGH auto-inject policy

3. **EC-007 (HIGH):** {QUESTION}
   - Model: grok-4
   - Why: Accessibility-related, compliance requirement

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

## Deduplication Log

| Removed Case | Merged Into | Similarity | Decision |
|--------------|-------------|------------|----------|
| EC-G-003 | EC-GPT-002 | {SCORE} | Keep GPT (more detailed) |
| EC-C-002 | EC-001 | {SCORE} | Merge into cross-model |
| ... | ... | ... | ... |

---

## Synthesis Metadata

- **Synthesizer Model:** {MODEL}
- **Strategy:** {STRATEGY}
- **Severity Boost Applied:** {YES_NO}
- **Execution Time:** {DURATION_MS}ms
