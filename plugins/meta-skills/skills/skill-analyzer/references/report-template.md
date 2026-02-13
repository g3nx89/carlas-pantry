# Report Template

This file defines the structure of the final `skill-review-report.md` output. The coordinator fills this template after applying synthesis rules.

## Template

````markdown
---
target_skill: "{TARGET_SKILL_NAME}"
target_path: "{TARGET_SKILL_PATH}"
analysis_date: "{YYYY-MM-DD}"
lenses_applied:
  - "{lens_name_1}"
  - "{lens_name_2}"
  - "{lens_name_3}"
  - "{lens_name_4}"
  - "{lens_name_5}"
  - "{lens_name_6}"
  - "{lens_name_7}"
  # Add optional lenses here if used
lenses_degraded: ["{lens_name if fallback used}"]
overall_score: "{N.N}/5.0"
findings_total: N
findings_critical: N
findings_high: N
findings_medium: N
findings_low: N
findings_info: N
---

# Skill Review Report: {TARGET_SKILL_NAME}

## Executive Summary

{3-4 sentences covering:
- What was reviewed (skill name, purpose, size)
- Overall quality assessment (score and interpretation)
- Top concern (highest priority finding)
- Top strength (most notable positive aspect)}

## Scores by Lens

| Lens | Score | Key Finding |
|------|-------|-------------|
| Structure & Progressive Disclosure | {N}/5 | {one-liner: most impactful finding} |
| Prompt Engineering Quality | {N}/5 | {one-liner} |
| Context Engineering Efficiency | {N}/5 | {one-liner} |
| Writing Quality & Conciseness | {N}/5 | {one-liner} |
| Overall Effectiveness | {N}/5 | {one-liner} |
| Reasoning & Decomposition | {N}/5 | {one-liner} |
| Architecture & Coordination | {N}/5 | {one-liner} |
{Add rows for any optional lenses applied}

**Overall: {N.N}/5.0** — {one-word assessment: Excellent/Good/Adequate/Needs Work/Poor}

Score interpretation:
- 4.5-5.0: Excellent — production-ready, minimal improvements needed
- 3.5-4.4: Good — solid skill with some improvement opportunities
- 2.5-3.4: Adequate — functional but has notable quality gaps
- 1.5-2.4: Needs Work — significant issues affecting effectiveness
- 1.0-1.4: Poor — fundamental problems requiring major revision

## Modification Plan

| # | Priority | Action | File | Section | Effort | Lenses |
|---|----------|--------|------|---------|--------|--------|
| 1 | {CRITICAL/HIGH/MEDIUM/LOW} | {concise action description} | {file} | {section} | {S/M/L} | {lens1, lens2} |
| 2 | ... | ... | ... | ... | ... | ... |

{Maximum 15 rows. If more items exist, include "Additional Improvements" section below.}

### Additional Improvements

{Grouped list of lower-priority items that exceeded the 15-item cap, if any.}

## Detailed Findings

### Structure & Organization

{Findings from the structure lens analysis, ordered by severity.
Each finding formatted as:}

**{Finding Title}** `{SEVERITY}`
- **File**: {relative path}
- **Current**: {quote or description}
- **Recommendation**: {actionable change}
- **Cross-validated by**: {other lens names, if applicable}

### Content Quality & Clarity

{Findings from the writing lens analysis + any writing-related findings from other lenses.}

### Prompt & Instruction Effectiveness

{Findings from the prompt lens analysis.}

### Context & Token Efficiency

{Findings from the context lens analysis.}

### Completeness & Coverage

{Findings from the effectiveness lens analysis + cross-cutting completeness issues.}

### Reasoning & Logic

{Findings from the reasoning lens analysis — explicit chains, decomposition, verification.}

### Architecture & Coordination

{Findings from the architecture lens analysis — coordination patterns, bottlenecks, failure propagation.}

{Include additional sections for any optional lenses applied.}

## Strengths

{Consolidated strengths from all lenses, ordered by cross-validation count.}

1. **{Strength title}** — {description} _(identified by: {lens1, lens2})_
2. **{Strength title}** — {description} _(identified by: {lens1})_

## Metadata

- **Analysis date**: {YYYY-MM-DD}
- **Lenses applied**: {count} ({comma-separated list})
- **Fallback used**: {count} lenses ({list, or "none"})
- **Target skill size**: {word count} words (SKILL.md) + {N} reference files + {N} example files + {N} script files
- **Individual analyses**: `{TARGET_SKILL_PATH}/.skill-review/`
````

## Template Notes

- The `lenses_degraded` frontmatter field lists lenses that used fallback criteria instead of the full skill. This signals to downstream consumers that those assessments may be less precise.
- The Modification Plan table is the primary actionable output. Order it for maximum impact: CRITICAL issues first, quick wins within each tier.
- The "Cross-validated by" annotation on findings shows when multiple lenses independently identified the same issue — these are the highest-confidence findings.
- Individual lens analyses in `.skill-review/` are preserved for reference but the consolidated report supersedes them.
