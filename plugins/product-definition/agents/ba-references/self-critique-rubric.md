# Self-Critique Rubric (LLM-as-Judge Pattern)

This reference defines the rubric-based self-evaluation for specification quality.
Based on the LLM-as-Judge pattern from agent-evaluation best practices.

---

## Rubric Overview

| Dimension | Weight | Focus |
|-----------|--------|-------|
| Business Value | 20% | WHY this feature exists |
| Requirements | 20% | WHAT must be built |
| Testability | 20% | Can QA verify it? |
| Scope | 20% | Clear boundaries |
| Stakeholders | 20% | WHO is affected |
| Design Alignment* | +20% | Figma correlation (when provided) |

*Design Alignment only evaluated when Figma context is provided.

---

## Core Dimensions (Always Evaluated)

### Dimension 1: Business Value

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | No WHY stated. No problem statement. No success metrics. Feature exists without justification. |
| 2 | Adequate | Vague WHY. Generic problem statement. No measurable success criteria. |
| 3 | Good | Clear WHY. Specific problem statement. Success criteria defined but not all measurable. |
| 4 | Excellent | WHY with ROI/metrics. Compelling problem statement. All success criteria measurable with baselines. |

**Evidence to Look For:**
- Problem statement section exists and is specific
- Business goals are articulated
- Success metrics are defined
- ROI or business impact is quantified

**Remediation if Score 1-2:**
- Add explicit problem statement
- Define measurable success metrics
- Include ROI justification if applicable
- Connect feature to business objectives

---

### Dimension 2: Requirements

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Missing FRs. Incomplete coverage. No acceptance criteria. Major functionality gaps. |
| 2 | Adequate | Incomplete FRs. Some acceptance criteria present. Edge cases missing. |
| 3 | Good | Complete FRs. All have acceptance criteria. Most edge cases covered. |
| 4 | Excellent | Complete FRs + edge cases. Error scenarios documented. All paths covered. Given/When/Then format. |

**Evidence to Look For:**
- All core functionality has FR-XXX entries
- Each FR has acceptance criteria
- Error/failure scenarios documented
- Edge cases explicitly addressed

**Remediation if Score 1-2:**
- Add missing functional requirements
- Include error scenarios for each FR
- Document edge cases explicitly
- Ensure all user paths have requirements

---

### Dimension 3: Testability

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Untestable requirements. Vague language. No Given/When/Then. QA cannot write test cases. |
| 2 | Adequate | Some requirements testable. Inconsistent format. QA needs clarification on 50%+. |
| 3 | Good | All requirements testable. Given/When/Then present. Minor ambiguities. |
| 4 | Excellent | All requirements in Given/When/Then format. Unambiguous. QA can write test cases directly. |

**Evidence to Look For:**
- Given/When/Then format used consistently
- No vague terms (fast, responsive, user-friendly)
- Specific values where applicable
- Clear pass/fail criteria

**Testability Validation Checklist:**

| Requirement | Testable? | Issue if No |
|-------------|-----------|-------------|
| FR-001 | [Y/N] | {specific issue} |
| FR-002 | [Y/N] | {specific issue} |
| ... | ... | ... |

**Remediation if Score 1-2:**
- Rewrite all criteria in Given/When/Then format
- Replace vague terms with specific metrics
- Add concrete examples where helpful
- Ensure QA can write test cases from each criterion

---

### Dimension 4: Scope

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Undefined scope. No boundaries. Scope creep inevitable. |
| 2 | Adequate | Partial boundaries. Some exclusions listed. Gaps in coverage. |
| 3 | Good | Defined boundaries. "Out of Scope" section present. Most exclusions documented. |
| 4 | Excellent | Clear boundaries + explicit exclusions. Future considerations noted. No ambiguity about what's included/excluded. |

**Evidence to Look For:**
- "Out of Scope" section exists
- Explicit exclusions listed
- Boundary decisions documented
- Future considerations separated

**Remediation if Score 1-2:**
- Add "Out of Scope" section
- List explicit exclusions
- Document boundary decisions with rationale
- Separate current scope from future enhancements

---

### Dimension 5: Stakeholders

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Not identified. No stakeholder analysis. Unknown who is affected. |
| 2 | Adequate | Listed only. No needs analysis. No conflict identification. |
| 3 | Good | Needs analyzed. Primary/secondary identified. Most conflicts noted. |
| 4 | Excellent | Conflicts resolved with documented rationale. Complete stakeholder matrix. All needs addressed. |

**Evidence to Look For:**
- Stakeholder list with roles
- Needs documented per stakeholder
- Conflicts identified and resolved
- Priority decisions documented

**Remediation if Score 1-2:**
- Add stakeholder matrix
- Document needs per stakeholder
- Identify potential conflicts
- Resolve conflicts with documented rationale

---

## Design Alignment (Conditional)

**Only evaluated when `<figma-context>` is provided.**

| Score | Level | Observable Characteristics |
|-------|-------|---------------------------|
| 1 | Poor | Ignores Figma context entirely. No @FigmaRef annotations. No design-related questions generated. |
| 2 | Adequate | References some screens but mapping is incomplete or contains errors. Missing confidence levels. |
| 3 | Good | Maps most requirements to screens with confidence levels. Identifies major gaps. Some edge cases noted. |
| 4 | Excellent | Full correlation with HIGH/MEDIUM/LOW confidence. All gaps identified with actionable feedback. All edge case states flagged. Clear synthesis into clarification questions. |

**Evidence to Look For:**
- @FigmaRef annotations on requirements
- Confidence levels (HIGH/MEDIUM/LOW)
- Gap identification
- Edge case states flagged
- Design-related clarification questions

**Remediation if Score 1-2:**
- Execute full Design-Spec Correlation Protocol
- Add @FigmaRef to all mappable requirements
- Document confidence levels
- Flag missing screens and edge cases

---

## Scoring Calculation

### Without Figma Context

```
Total Score = Business Value + Requirements + Testability + Scope + Stakeholders
Maximum = 4 + 4 + 4 + 4 + 4 = 20 points
```

### With Figma Context

```
Raw Score = Business Value + Requirements + Testability + Scope + Stakeholders + Design Alignment
Raw Maximum = 24 points

Scaled Score = (Raw Score / 24) × 20
```

---

## Score Interpretation

| Score Range | Status | Action |
|-------------|--------|--------|
| 16-20 | PASS | Ready for submission to PAL Consensus |
| 12-15 | CONDITIONAL | Minor revisions needed, iterate once |
| <12 | FAIL | Significant rework required, multiple iterations |

---

## Failure Mode Checklist

Before submitting, verify all failure modes are CLEAR:

| Failure Mode | Status | Evidence |
|--------------|--------|----------|
| Vague acceptance criteria | FOUND/CLEAR | [quote or "None found"] |
| Missing stakeholder needs | FOUND/CLEAR | [quote or "None found"] |
| Unclear scope boundaries | FOUND/CLEAR | [quote or "None found"] |
| Untestable requirements | FOUND/CLEAR | [quote or "None found"] |
| Orphan requirements (no business justification) | FOUND/CLEAR | [quote or "None found"] |
| Technology in success criteria | FOUND/CLEAR | [quote or "None found"] |

**If any FOUND:** Fix before proceeding. Iterate until all CLEAR.

---

## Gap Remediation Actions

| Low-Scoring Dimension | Remediation Action |
|----------------------|-------------------|
| Business Value (1-2) | Add explicit problem statement, success metrics, ROI justification |
| Requirements (1-2) | Add missing FRs, include error scenarios, edge cases |
| Testability (1-2) | Rewrite criteria in Given/When/Then format |
| Scope (1-2) | Add "Out of Scope" section with explicit exclusions |
| Stakeholders (1-2) | Add stakeholder matrix, resolve documented conflicts |
| Design Alignment (1-2) | Execute Design-Spec Correlation Protocol fully |

---

## Required Output Format

Include this summary at the end of every specification:

```markdown
## Self-Critique Summary

### Rubric Scores (out of 4)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Business Value | [1-4] | [Brief citation] |
| Requirements | [1-4] | [Brief citation] |
| Testability | [1-4] | [Brief citation] |
| Scope | [1-4] | [Brief citation] |
| Stakeholders | [1-4] | [Brief citation] |
{IF FIGMA CONTEXT PROVIDED:}
| Design Alignment | [1-4] | [Brief citation] |
{END IF}
| **TOTAL** | **[X]/20** | |

{IF FIGMA CONTEXT PROVIDED:}
### Design Correlation Summary
- **Screens Captured:** [N]
- **Requirements Mapped:** [N] of [TOTAL] ([%])
- **Gaps Identified:** [N]
- **Edge Cases Flagged:** [list]
- **Confidence Distribution:** [N] HIGH, [N] MEDIUM, [N] LOW
{END IF}

### Gaps Addressed
- [Gap 1]: [How it was fixed]
- [Gap 2]: [How it was fixed]

### Failure Mode Check
All failure modes: CLEAR ✓

### Readiness
Specification is READY for PAL Consensus validation.
```

---

## Sequential Thinking Integration

Use templates T24 and T25 from `sequential-thinking-templates.md`:

**T24: Rubric Evaluation**
```json
{
  "thought": "Step 1/2: Evaluating specification against 5-dimension rubric. Business Value: [1-4] because [evidence]. Requirements: [1-4] because [evidence]. Testability: [1-4] because [evidence]. Scope: [1-4] because [evidence]. Stakeholders: [1-4] because [evidence]. TOTAL: [X]/20.",
  "thoughtNumber": 1,
  "totalThoughts": 2,
  "nextThoughtNeeded": true,
  "hypothesis": "Specification scores [X]/20. Weakest dimensions: [list]",
  "confidence": "high"
}
```

**T25: Gap Remediation**
```json
{
  "thought": "Step 2/2: Addressing gaps. Dimension [X] scored [N] because [specific gap]. Remediation: [specific action]. Updating spec section [Y] with [improvement]. Re-evaluating: new score is [N+improvement].",
  "thoughtNumber": 2,
  "totalThoughts": 2,
  "nextThoughtNeeded": false,
  "hypothesis": "After remediation, total score: [X]/20. All dimensions ≥3.",
  "confidence": "high"
}
```

---

## Checkpoint Output

After completing Self-Critique, emit:

```markdown
<!-- CHECKPOINT: SELF_CRITIQUE -->
Phase: SELF_CRITIQUE
Status: completed
Timestamp: {ISO_DATE}
Key Outputs:
- Total score: [X]/20
- Dimension scores: BV=[N], REQ=[N], TEST=[N], SCOPE=[N], STAKE=[N]
- Gaps addressed: [N]
- Failure modes: All CLEAR
<!-- END_CHECKPOINT -->
```
