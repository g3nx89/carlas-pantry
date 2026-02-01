# PAL Consensus: Specification Evaluation

## Purpose

Multi-model consensus validation for feature specifications.
This template defines the evaluation criteria and decision thresholds.

## Evaluation Criteria (Score 1-4 each)

### Criterion 1: Business Value Clarity
**Question:** Is the "WHY" clearly articulated with measurable success criteria?

**Scoring:**
- 4 (Excellent): Clear business case, quantified outcomes, stakeholder buy-in evident
- 3 (Good): Business value stated, success criteria defined
- 2 (Adequate): General value proposition, vague success metrics
- 1 (Poor): No clear business justification or measurable outcomes

**Evidence to look for:**
- ROI or impact statements
- KPIs or success metrics
- Stakeholder benefits

---

### Criterion 2: Requirements Completeness
**Question:** Are all functional requirements testable with clear acceptance criteria?

**Scoring:**
- 4 (Excellent): All requirements testable, Given/When/Then format, edge cases covered
- 3 (Good): Most requirements testable, acceptance criteria clear
- 2 (Adequate): Some requirements vague, missing edge cases
- 1 (Poor): Requirements untestable or missing acceptance criteria

**Evidence to look for:**
- Gherkin-style acceptance criteria
- Boundary conditions defined
- Error scenarios covered

---

### Criterion 3: Scope Boundaries
**Question:** Are in-scope and out-of-scope items explicitly defined?

**Scoring:**
- 4 (Excellent): Clear boundaries, explicit exclusions, dependencies listed
- 3 (Good): Scope defined, some exclusions noted
- 2 (Adequate): Implicit scope, boundaries unclear
- 1 (Poor): Scope creep risk, no clear boundaries

**Evidence to look for:**
- "Out of Scope" section
- System integration boundaries
- Feature version limits (v1 vs future)

---

### Criterion 4: Stakeholder Coverage
**Question:** Are all affected parties identified with their needs addressed?

**Scoring:**
- 4 (Excellent): All personas identified, edge users considered, accessibility addressed
- 3 (Good): Primary personas covered, main needs addressed
- 2 (Adequate): Some personas missing, limited perspective
- 1 (Poor): Single user type considered, stakeholder gaps

**Evidence to look for:**
- User personas list
- Admin/support scenarios
- Accessibility requirements

---

### Criterion 5: Technology Agnosticism
**Question:** Are success criteria free of implementation details?

**Scoring:**
- 4 (Excellent): Pure behavior focus, platform-neutral, no tech specifics in requirements
- 3 (Good): Mostly behavior-focused, minimal tech leakage
- 2 (Adequate): Some implementation details mixed with requirements
- 1 (Poor): Requirements tied to specific technologies

**Evidence to look for:**
- "What" vs "how" language
- Implementation notes separated
- Database/API details absent from user stories

---

## Decision Thresholds

### APPROVED
- **Score:** >= 16/20
- **Agreement:** >= 80%
- **Action:** Proceed to implementation planning

### CONDITIONAL
- **Score:** 12-15/20
- **Agreement:** 60-79%
- **Action:** Proceed with documented warnings

### REJECTED
- **Score:** < 12/20
- **Agreement:** < 60%
- **Action:** Address gaps before proceeding

---

## Required Output Format

### Individual Model Response

```yaml
model: "{model_name}"
scores:
  business_value_clarity: {1-4}
  requirements_completeness: {1-4}
  scope_boundaries: {1-4}
  stakeholder_coverage: {1-4}
  technology_agnosticism: {1-4}
total: {sum}/20
decision: APPROVED | CONDITIONAL | REJECTED
justification: |
  {2-3 sentences with specific citations from spec}
gaps_identified:
  - criterion: {name}
    issue: "{specific problem}"
    suggestion: "{how to fix}"
```

### Consensus Summary

```yaml
consensus:
  final_decision: APPROVED | CONDITIONAL | REJECTED
  average_score: {X.X}/20
  agreement_percentage: {X}%
  models_agreed: {count}/{total}

  criterion_breakdown:
    business_value_clarity:
      average: {X.X}
      agreement: {%}
    requirements_completeness:
      average: {X.X}
      agreement: {%}
    # ... etc

  key_strengths:
    - "{specific positive aspect}"

  key_gaps:
    - criterion: "{name}"
      consensus_issue: "{agreed problem}"
      suggested_fix: "{agreed solution}"

  dissenting_views:
    - model: "{model}"
      disagreement: "{what they disagree on}"
```
