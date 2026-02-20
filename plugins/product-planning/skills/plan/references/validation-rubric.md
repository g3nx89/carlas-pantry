# Consensus Validation Rubric

Detailed scoring criteria for Phase 6 consensus validation via CLI dispatch.

## Consensus Configuration

### Models and Stances

| Model | Stance | Role |
|-------|--------|------|
| gemini (CLI) | advocate | Highlight strengths, give benefit of doubt |
| codex (CLI) | challenger | Find gaps, risks, and overlooked failure modes |

Minimum CLIs required for valid consensus: 1 (single CLI with self-challenge suffices)

---

## Scoring Dimensions (20 Points Total)

### 1. Problem Understanding (20% / 4 points)

**Criteria:** Clear problem statement, root cause identified, scope defined

| Score | Description |
|-------|-------------|
| 4 | Problem is exceptionally well-defined with clear root cause, scope, and constraints |
| 3 | Problem is well-understood with minor ambiguities |
| 2 | Problem is partially understood; some aspects unclear |
| 1 | Problem statement is vague or missing critical elements |

**Evidence to check:**
- Is the problem clearly stated?
- Are root causes identified (not just symptoms)?
- Is scope explicitly defined with boundaries?
- Are constraints documented?

### 2. Architecture Quality (25% / 5 points)

**Criteria:** Sound design principles, appropriate patterns, good abstractions

| Score | Description |
|-------|-------------|
| 5 | Excellent architecture with clear patterns, strong abstractions, and elegant design |
| 4 | Good architecture with minor improvement opportunities |
| 3 | Adequate architecture with some questionable decisions |
| 2 | Architecture has significant issues or anti-patterns |
| 1 | Poor architecture or missing critical components |

**Evidence to check:**
- Are design patterns appropriate for the problem?
- Is separation of concerns maintained?
- Are abstractions at the right level?
- Does it follow codebase conventions?
- Is complexity managed appropriately?

### 3. Risk Mitigation (20% / 4 points)

**Criteria:** Risks identified, mitigations planned, fallback strategies

| Score | Description |
|-------|-------------|
| 4 | Comprehensive risk analysis with clear mitigations and fallbacks |
| 3 | Good risk coverage with some mitigations |
| 2 | Partial risk identification; mitigations unclear |
| 1 | Risks not adequately addressed |

**Evidence to check:**
- Are technical risks identified?
- Are business/schedule risks considered?
- Do mitigations address root causes?
- Are fallback strategies defined?
- Is there a monitoring/alerting plan?

### 4. Implementation Clarity (20% / 4 points)

**Criteria:** Clear steps, dependencies mapped, acceptance criteria defined

| Score | Description |
|-------|-------------|
| 4 | Crystal clear implementation path with well-defined steps and criteria |
| 3 | Clear implementation with minor gaps |
| 2 | Implementation path has ambiguities |
| 1 | Implementation unclear or unrealistic |

**Evidence to check:**
- Are implementation steps clearly defined?
- Are dependencies mapped and ordered?
- Is each task independently verifiable?
- Are acceptance criteria testable?
- Is the critical path identified?

### 5. Feasibility (15% / 3 points)

**Criteria:** Realistic scope, resource considerations, timeline alignment

| Score | Description |
|-------|-------------|
| 3 | Highly feasible with realistic scope and clear resource alignment |
| 2 | Feasible with some concerns about scope or resources |
| 1 | Questionable feasibility; significant scope/resource issues |

**Evidence to check:**
- Is the scope achievable?
- Are skill requirements identified?
- Are external dependencies accounted for?
- Is the timeline realistic?
- Are there resource constraints?

---

## Score Thresholds

| Total Score | Status | Action |
|-------------|--------|--------|
| ≥16 | GREEN | Proceed to implementation |
| 12-15 | YELLOW | Proceed with documented risks |
| <12 | RED | Requires revision (return to Phase 4) |

---

## CLI Consensus Dispatch Template

Follow CLI Multi-CLI Dispatch Pattern from `cli-dispatch-pattern.md`:

```
| Parameter | Value |
|-----------|-------|
| ROLE | `consensus` |
| PHASE_STEP | `6.1` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | "STANCE: advocate\n\nEvaluate this plan. Highlight strengths...\n\nPLAN:\n{FULL_PLAN_CONTENT}\n\nScore dimensions (max 20 total):\n1. Problem Understanding (20%) score 1-4\n2. Architecture Quality (25%) score 1-5\n3. Risk Mitigation (20%) score 1-4\n4. Implementation Clarity (20%) score 1-4\n5. Feasibility (15%) score 1-3" |
| CODEX_PROMPT | "STANCE: challenger\n\nChallenge this plan. Find weaknesses...\n\nPLAN:\n{FULL_PLAN_CONTENT}\n\n(same scoring dimensions)" |
| FILE_PATHS | ["{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"] |
| REPORT_FILE | "analysis/cli-consensus-report.md" |
| PREFERRED_SINGLE_CLI | `gemini` |
```

The coordinator synthesizes scores from both CLIs:
- **Convergent scores** (delta ≤ 1.0): Use average → HIGH confidence
- **Divergent scores** (delta > 4.0): FLAG for user review, re-dispatch with clarification
- **Moderate divergence** (1.0 < delta ≤ 4.0): Use average, note disagreement

---

## Output Template

```markdown
# Consensus Validation Report

> Generated: {TIMESTAMP}
> CLIs: gemini (advocate), codex (challenger)

## Overall Score: {TOTAL}/20 - {STATUS}

### Per-CLI Scores

| Dimension | Weight | Gemini (Advocate) | Codex (Challenger) | Avg |
|-----------|--------|-------------------|--------------------|----|
| Problem Understanding | 20% | X | X | X.X |
| Architecture Quality | 25% | X | X | X.X |
| Risk Mitigation | 20% | X | X | X.X |
| Implementation Clarity | 20% | X | X | X.X |
| Feasibility | 15% | X | X | X.X |
| **Total** | 100% | XX | XX | **XX** |

### Assessment Summary

#### Gemini (Advocate) Highlights
{strengths identified}

#### Codex (Challenger) Concerns
{weaknesses and risks}

### Convergent Points
- {point where both CLIs agree} → HIGH confidence

### Divergent Points
- {point where CLIs disagree} → FLAG for human decision

### Recommendations
1. {actionable recommendation}
2. {actionable recommendation}

## Verdict

**Status:** {GREEN/YELLOW/RED}
**Action:** {Proceed / Proceed with documented risks / Return to Phase 4}
```

---

## RED Status Handling

When validation score < 12:

1. **Identify critical failures:**
   - Which dimensions scored lowest?
   - What specific concerns did the challenger raise?

2. **Generate improvement guidance:**
   - Map low scores to specific plan sections
   - Provide concrete suggestions for each issue

3. **Return to Phase 4:**
   - Preserve user decisions (immutable)
   - Mark previous architecture as "rejected"
   - Generate new architecture options addressing feedback

4. **Re-validate:**
   - After Phase 4 revision, return to Phase 6
   - Maximum 2 revision cycles before manual intervention

---

## Internal Validation Fallback

If CLI dispatch unavailable, use the Sequential Thinking fallback defined in `phase-6-validation.md` Step 6.4 (templates T14-T16 from `sequential-thinking-templates.md` Group 5).

Scoring for internal validation:
- Apply same 5 dimensions
- Self-assess using rubric criteria
- Document reasoning for each score
- Status thresholds remain the same

Mark validation as "INTERNAL" in output to distinguish from multi-model consensus.
