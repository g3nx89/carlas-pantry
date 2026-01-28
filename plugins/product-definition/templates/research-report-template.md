# Research Report: {CATEGORY}

> **Report ID:** research-{category}.md
> **Researcher:** {Your name / "User" / "AI Agent"}
> **Date:** {YYYY-MM-DD}
> **Time Spent:** {X hours}
> **Questions Addressed:** RQ-{N}, RQ-{N}, ...

---

## Executive Summary

{2-3 sentences summarizing the most critical findings. Focus on what CHANGES our approach or VALIDATES key assumptions.}

---

## Questions Investigated

| Question ID | Question Title | Status | Confidence |
|-------------|----------------|--------|------------|
| RQ-{N} | {Title from RESEARCH-AGENDA.md} | ANSWERED / PARTIAL / UNANSWERED | HIGH/MEDIUM/LOW |
| RQ-{N} | {Title} | {Status} | {Confidence} |

---

## Sources Consulted

### Official/Primary Sources (High Reliability)

| # | Source | Type | URL | Language | Accessed |
|---|--------|------|-----|----------|----------|
| S1 | {Source name} | {Gov Doc / Legal Text / Official API / Academic Paper} | {URL} | {IT/EN} | {Date} |
| S2 | {Source name} | {Type} | {URL} | {Lang} | {Date} |

### Industry/Secondary Sources (Medium Reliability)

| # | Source | Type | URL | Language | Accessed |
|---|--------|------|-----|----------|----------|
| S3 | {Source name} | {Industry Report / News / Analysis} | {URL} | {Lang} | {Date} |

### Community/User Sources (Verify Claims)

| # | Source | Type | URL | Language | Accessed |
|---|--------|------|-----|----------|----------|
| S4 | {Forum/Reddit name} | {Forum Thread / Review / Discussion} | {URL} | {Lang} | {Date} |

**Source Summary:** {N} total | {N} primary | {N} secondary | {N} community

---

## Key Findings

### F-001: {Finding Title}

**One-line Summary:** {Single sentence capturing the finding}

**Evidence:**
```
{Direct quote, statistic, or specific observation}
```
**Source:** S{N} - {Source name}

**Confidence:** HIGH / MEDIUM / LOW
**Why this confidence:** {Multiple corroborating sources? Official source? Single anecdote?}

**Answers Question(s):** RQ-{N}

**Implication for Feature:**
- {Specific, actionable implication}
- {What to do differently based on this}

---

### F-002: {Finding Title}

**One-line Summary:** {Single sentence}

**Evidence:**
```
{Quote or data}
```
**Source:** S{N}

**Confidence:** HIGH / MEDIUM / LOW
**Why this confidence:** {Reasoning}

**Answers Question(s):** RQ-{N}

**Implication for Feature:**
- {Implication}

---

{Repeat F-{N} structure for each significant finding - aim for 5-10 findings per report}

---

## Quantitative Data Collected

| Metric | Value | Source | Year | Caveat |
|--------|-------|--------|------|--------|
| {e.g., "Italian rental contracts/year"} | {1.2M} | {S1} | {2023} | {Any limitations} |
| {e.g., "Average deposit dispute rate"} | {X%} | {S2} | {Year} | {Notes} |

---

## Contradictions Found

### Contradiction C-001: {Topic}

| View A | View B |
|--------|--------|
| {Finding from Source X} | {Conflicting finding from Source Y} |

**Possible Explanation:** {Why the contradiction exists}
**Recommended Resolution:** {Which view to trust, or "FLAG FOR USER DECISION"}

---

## Competitive/Alternative Analysis

{Include only if research involved competitive analysis}

| Solution | Type | Target Market | Key Features | Weakness/Gap |
|----------|------|---------------|--------------|--------------|
| {Name} | {App/Service} | {Segment} | {Features} | {Our opportunity} |

---

## Research Gaps

| Gap | Impact | Priority | Suggested Approach |
|-----|--------|----------|-------------------|
| {What couldn't be answered} | {Risk if unresolved} | HIGH/MED/LOW | {How to fill gap} |

---

## Specification Implications

### MUST Include (Validated by Research)

1. **{Requirement}**
   - Based on: F-{N}
   - Rationale: {Why non-negotiable}

2. **{Requirement}**
   - Based on: F-{N}
   - Rationale: {Why}

### SHOULD Consider

1. **{Consideration}**
   - Based on: F-{N}
   - Trade-off: {Benefit vs cost}

### MUST Avoid (Anti-Patterns)

1. **{What to avoid}**
   - Based on: F-{N}
   - Risk: {Consequence if ignored}

### OUT OF SCOPE (Research-Informed)

1. **{Item to exclude}**
   - Based on: F-{N}
   - Rationale: {Why not worth including}

---

## New Questions Emerged

| Question | Priority | Why It Matters |
|----------|----------|----------------|
| {New question from research} | HIGH/MED/LOW | {Impact on feature} |

---

## Research Quality Self-Check

| Criterion | Score (1-5) | Notes |
|-----------|-------------|-------|
| Source diversity | {1-5} | {Different source types?} |
| Source reliability | {1-5} | {Official vs anecdotal?} |
| Question coverage | {1-5} | {% of assigned questions answered?} |
| Finding actionability | {1-5} | {Clear implications?} |
| **Overall Quality** | **{avg}** | |

---

## Methodology Notes

**Search Strategy:**
- {Search queries used}
- {Platforms searched}
- {Filters applied}

**Limitations:**
- {e.g., "Paywall blocked detailed statistics"}
- {e.g., "Italian-language sources only"}

---

*This report will be analyzed during Research Synthesis (Phase 1.8).*
*Link findings to spec with: `@ResearchRef(finding="F-001", source="research-{category}.md")`*
