# Judge Report Template (S3)

Standard output format for phase-gate-judge evaluations.

---

## Gate Evaluation Report

**Gate:** {GATE_NAME}
**Phase Evaluated:** {PHASE_NUMBER}
**Evaluation Date:** {DATE}
**Judge Model:** {MODEL_NAME}
**Analysis Mode:** {rapid|standard|advanced|complete}

---

## 1. Evaluation Summary

```yaml
gate_result:
  gate_name: "{GATE_NAME}"
  verdict: "PASS|CONDITIONAL|FAIL"
  overall_score: X.X  # 1-5 scale
  confidence: "HIGH|MEDIUM|LOW"

  thresholds:
    pass: ">= 3.5"
    conditional: ">= 2.5 AND < 3.5"
    fail: "< 2.5"
```

### Verdict Explanation

{1-2 sentence summary of why this verdict was reached}

---

## 2. Criteria Scores

| Criterion | Weight | Score | Weighted | Notes |
|-----------|--------|-------|----------|-------|
| {criterion_1} | {weight}% | X/5 | X.XX | {brief note} |
| {criterion_2} | {weight}% | X/5 | X.XX | {brief note} |
| {criterion_3} | {weight}% | X/5 | X.XX | {brief note} |
| {criterion_4} | {weight}% | X/5 | X.XX | {brief note} |
| {criterion_5} | {weight}% | X/5 | X.XX | {brief note} |
| **Total** | **100%** | - | **X.XX** | - |

### Score Distribution

```
5 ████████░░ 2 criteria (Excellent)
4 ██████████ 2 criteria (Good)
3 ████░░░░░░ 1 criterion  (Adequate)
2 ░░░░░░░░░░ 0 criteria (Weak)
1 ░░░░░░░░░░ 0 criteria (Poor)
```

---

## 3. Detailed Findings

### Strengths

| ID | Finding | Evidence | Criterion |
|----|---------|----------|-----------|
| S1 | {strength description} | {reference to artifact} | {criterion} |
| S2 | {strength description} | {reference to artifact} | {criterion} |
| S3 | {strength description} | {reference to artifact} | {criterion} |

### Concerns

| ID | Finding | Severity | Evidence | Criterion | Blocking? |
|----|---------|----------|----------|-----------|-----------|
| C1 | {concern description} | CRITICAL | {reference} | {criterion} | Yes |
| C2 | {concern description} | HIGH | {reference} | {criterion} | Yes |
| C3 | {concern description} | MEDIUM | {reference} | {criterion} | No |
| C4 | {concern description} | LOW | {reference} | {criterion} | No |

### Missing Elements

| ID | Expected | Status | Impact |
|----|----------|--------|--------|
| M1 | {expected element} | Missing | {impact on verdict} |
| M2 | {expected element} | Partial | {impact on verdict} |

---

## 4. Calibration Reference

### How This Compares to Calibration Examples

| Calibration Example | Score | This Artifact | Delta |
|---------------------|-------|---------------|-------|
| "Adequate research" | 3.0 | {comparison} | {+/-X} |
| "Good architecture" | 4.0 | {comparison} | {+/-X} |
| "Excellent coverage" | 5.0 | {comparison} | {+/-X} |

### Score Justification

**Why not higher:**
- {reason this didn't score 4 or 5}
- {specific gap preventing higher score}

**Why not lower:**
- {strength that prevented lower score}
- {specific element that met criteria}

---

## 5. Recommendations

### If PASS

```yaml
recommendations:
  type: "proceed"
  notes:
    - "{optional improvement for next phase}"
  next_phase: {phase_number + 1}
```

### If CONDITIONAL

```yaml
recommendations:
  type: "minor_revision"
  required_actions:
    - action: "{specific action}"
      addresses: "C2"
      estimated_effort: "15-30 minutes"
    - action: "{specific action}"
      addresses: "C3"
      estimated_effort: "30-60 minutes"

  retry_guidance: |
    Focus on addressing the HIGH severity concerns.
    The MEDIUM concerns are optional but recommended.

  max_retries: 2
  current_attempt: 1
```

### If FAIL

```yaml
recommendations:
  type: "major_revision"
  blocking_issues:
    - issue: "C1"
      root_cause: "{why this occurred}"
      remediation: "{how to fix}"
    - issue: "M1"
      root_cause: "{why this occurred}"
      remediation: "{how to fix}"

  escalation_path: |
    After 2 failed attempts, escalate to user for:
    - Scope reduction decision
    - Accept risk and proceed
    - Abandon feature

  max_retries: 2
  current_attempt: 1
```

---

## 6. Retry Tracking (if applicable)

| Attempt | Date | Score | Delta | Key Changes | Verdict |
|---------|------|-------|-------|-------------|---------|
| 1 | {date} | X.X | - | Initial evaluation | FAIL |
| 2 | {date} | X.X | +X.X | {what improved} | CONDITIONAL |
| 3 | {date} | X.X | +X.X | {what improved} | PASS |

### Improvement Trajectory

```
Attempt 1: ████████░░░░░░░░░░░░ 2.5 (FAIL)
Attempt 2: ████████████░░░░░░░░ 3.2 (CONDITIONAL)
Attempt 3: ████████████████░░░░ 4.0 (PASS)
```

---

## 7. Artifacts Evaluated

| Artifact | Path | Last Modified |
|----------|------|---------------|
| {artifact_name} | {file_path} | {timestamp} |
| {artifact_name} | {file_path} | {timestamp} |

---

## Self-Critique

```yaml
self_critique:
  questions:
    - question: "Did I apply criteria consistently?"
      answer: "YES|NO|PARTIAL"
      notes: "{if not YES, explain}"

    - question: "Did I reference calibration examples?"
      answer: "YES|NO"
      notes: "{which examples used}"

    - question: "Are my findings evidence-based?"
      answer: "YES|NO|PARTIAL"
      notes: "{if not YES, explain}"

    - question: "Would another judge reach similar conclusion?"
      answer: "YES|LIKELY|UNLIKELY"
      notes: "{confidence in objectivity}"

  questions_passed: X/4
  evaluation_confidence: "HIGH|MEDIUM|LOW"
```

---

## Appendix: Scoring Scale Reference

| Score | Label | General Meaning |
|-------|-------|-----------------|
| 5 | Excellent | Exceeds expectations, comprehensive, production-ready |
| 4 | Good | Meets expectations, minor improvements possible |
| 3 | Adequate | Acceptable, notable gaps but workable |
| 2 | Weak | Below expectations, significant gaps |
| 1 | Poor | Unacceptable, fundamental issues |

---

*Report generated by phase-gate-judge. See `references/judge-gate-rubrics.md` for detailed criteria.*
