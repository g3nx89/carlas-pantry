# Multi-Judge Debate Protocol Reference (S6)

Complete protocol for multi-round debate validation in Complete mode.

## Overview

Multi-judge debate replaces single-round consensus with iterative argumentation to surface deeper insights and reach more robust conclusions.

```
┌─────────────────────────────────────────────────────────────────┐
│                 MULTI-JUDGE DEBATE PROTOCOL                      │
│                    (Complete Mode Only)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Round 1: INDEPENDENT ANALYSIS                                   │
│  ├── Each judge evaluates independently                         │
│  ├── No access to other judges' views                           │
│  └── Produces position statement with scores                    │
│       ↓                                                          │
│  Consensus Check: All scores within 0.5?                         │
│  ├── YES → Synthesize verdict, proceed                          │
│  └── NO → Continue to Round 2                                   │
│       ↓                                                          │
│  Round 2: REBUTTAL                                               │
│  ├── Each judge reads others' positions                         │
│  ├── Writes rebuttal with score revision                        │
│  └── Explains what changed or why position held                 │
│       ↓                                                          │
│  Consensus Check: All scores within 0.5?                         │
│  ├── YES → Synthesize verdict, proceed                          │
│  └── NO → Continue to Round 3                                   │
│       ↓                                                          │
│  Round 3: FINAL POSITIONS                                        │
│  ├── Final arguments from each judge                            │
│  ├── Force verdict via majority rule                            │
│  └── Document minority opinion                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

### Judge Lineup

```yaml
debate_judges:
  - model: gemini-3-pro-preview
    stance: neutral
    stance_prompt: "Evaluate objectively, weighing all factors equally"

  - model: gpt-5.2
    stance: for
    stance_prompt: "Advocate for this plan's strengths while acknowledging weaknesses"

  - model: grok-4
    stance: against
    stance_prompt: "Challenge this plan. Find weaknesses and risks others might miss."
```

### Consensus Criteria

```yaml
consensus:
  overall_score_range: 0.5  # Max difference between highest and lowest overall score
  dimension_score_range: 1.0  # Max difference per dimension
  critical_finding_agreement: true  # All must agree on CRITICAL findings
```

## Round 1: Independent Analysis

### Execution

1. Launch all 3 judges in parallel
2. Each writes to separate file (no cross-reading)
3. No awareness of other judges' positions

### Judge Prompt Template

```markdown
You are evaluating the planning artifacts for feature: {FEATURE_NAME}

Your stance: {stance}
Stance guidance: {stance_prompt}

Artifacts to evaluate:
- {FEATURE_DIR}/design.md
- {FEATURE_DIR}/plan.md
- {FEATURE_DIR}/tasks.md

Evaluation dimensions:
1. Problem Understanding (weight: 20%)
2. Architecture Quality (weight: 25%)
3. Risk Mitigation (weight: 20%)
4. Implementation Clarity (weight: 20%)
5. Feasibility (weight: 15%)

Output your independent evaluation following the Round 1 template.
Do NOT consider what other judges might think.
Evaluate based on your stance perspective.
```

### Round 1 Output Template

```yaml
judge_id: "{model_name}"
stance: "neutral|for|against"
round: 1

overall_score: X.X  # 1-5 scale
dimension_scores:
  problem_understanding: X  # 1-5
  architecture_quality: X
  risk_mitigation: X
  implementation_clarity: X
  feasibility: X

position_statement: |
  ## My Assessment

  ### Strengths (with evidence)
  1. {strength} - Evidence: {specific reference}
  2. {strength} - Evidence: {specific reference}

  ### Concerns (with evidence)
  1. {concern} - Evidence: {specific reference}
  2. {concern} - Evidence: {specific reference}

  ### Overall Verdict
  {summary of position from my stance perspective}

key_claims:
  - claim: "{specific claim}"
    evidence: "{supporting reference from artifacts}"
    confidence: "HIGH|MEDIUM|LOW"

critical_findings:
  - finding: "{if any CRITICAL issue}"
    severity: "CRITICAL"
    evidence: "{reference}"
```

## Consensus Check

### After Round 1

```python
def check_consensus(round_results):
    scores = [r.overall_score for r in round_results]
    max_score = max(scores)
    min_score = min(scores)

    if max_score - min_score <= 0.5:
        # Check dimension scores
        for dimension in dimensions:
            dim_scores = [r.dimension_scores[dimension] for r in round_results]
            if max(dim_scores) - min(dim_scores) > 1.0:
                return False  # Dimension disagreement

        # Check critical findings
        critical_findings = flatten([r.critical_findings for r in round_results])
        if not all_agree_on_critical(critical_findings):
            return False

        return True  # Consensus reached

    return False  # Overall score disagreement
```

### If Consensus Reached

Skip to synthesis:
1. Average scores across judges
2. Merge convergent findings
3. Note stance-balanced perspective

## Round 2: Rebuttal

### Execution

1. Each judge reads other judges' Round 1 outputs
2. Writes rebuttal addressing specific points
3. May revise score with justification

### Judge Prompt Template

```markdown
You are continuing the debate for feature: {FEATURE_NAME}

Your stance: {stance}
Your Round 1 score: {previous_score}

Other judges' positions:
---
{Judge 1 Round 1 output}
---
{Judge 2 Round 1 output}
---

Write your rebuttal:
1. Where do you AGREE with other judges? Strengthen shared points.
2. Where do you DISAGREE? Provide counterarguments with evidence.
3. Do you revise your score? Explain why or why not.

You may be persuaded by good arguments. You may also maintain your position if you have stronger evidence.
```

### Round 2 Output Template

```yaml
judge_id: "{model_name}"
round: 2

score_changed: true|false
previous_score: X.X
new_score: X.X
change_reason: |
  {Why score changed}
  OR
  {Why position maintained despite counterarguments}

agreements:
  - with_judge: "{judge_id}"
    on_point: "{what agreed}"
    strengthening_evidence: "{additional support}"

disagreements:
  - with_judge: "{judge_id}"
    on_point: "{what disagreed}"
    my_counterargument: "{rebuttal}"
    my_evidence: "{supporting reference}"
    their_evidence_weakness: "{why their evidence is insufficient}"

position_revision: |
  ## Updated Position

  Based on other judges' arguments:

  ### Points I Accept
  - {point} from Judge X - convinced by {reason}

  ### Points I Reject
  - {point} from Judge Y - because {counterargument}

  ### My Revised Assessment
  {updated position summary}

unresolved_disputes:
  - topic: "{what remains disputed}"
    my_view: "{my position}"
    opposing_view: "{their position}"
```

## Round 3: Final Positions

Only if consensus not reached after Round 2.

### Execution

1. Each judge writes final arguments
2. Majority rule determines verdict
3. Minority opinion documented

### Judge Prompt Template

```markdown
You are giving your FINAL position for feature: {FEATURE_NAME}

Your stance: {stance}
Your current score: {current_score}

Other judges' Round 2 positions:
---
{All Round 2 outputs}
---

This is the FINAL round. Write your conclusive position:
1. Your final score (unlikely to change, but may adjust)
2. Your strongest arguments
3. Concessions you've made
4. Disagreements you maintain

After this round, verdict will be determined by majority rule if no consensus.
```

### Round 3 Output Template

```yaml
judge_id: "{model_name}"
round: 3
is_final: true

final_score: X.X

final_position: |
  ## Final Assessment

  {Comprehensive final position}

key_points_maintained:
  - point: "{argument I maintain}"
    reason: "{why I'm confident}"
    evidence: "{supporting reference}"

concessions_made:
  - point: "{what I now accept}"
    convinced_by: "{which judge/argument}"

unresolved_disagreements:
  - issue: "{remaining dispute}"
    my_final_view: "{my position}"
    opposing_view: "{their position}"
    why_unresolved: "{fundamental difference}"
```

## Verdict Synthesis

### Consensus Verdict

When all scores within 0.5:

```yaml
verdict_type: "consensus"
consensus_score: {average of all scores}
confidence: "HIGH"

convergent_findings:
  - finding: "{all judges agree}"
    priority: "CRITICAL|HIGH|MEDIUM"
    source_judges: ["all"]

balanced_assessment: |
  {Synthesis incorporating all stance perspectives}
```

### Majority Verdict

When Round 3 completes without consensus:

```yaml
verdict_type: "majority"
majority_score: {average of majority scores}
minority_score: {dissenting score}
confidence: "MEDIUM"

majority_judges: ["{judge_ids}"]
minority_judges: ["{judge_ids}"]

majority_opinion: |
  {Summary of winning position}

minority_opinion: |
  {Summary of dissenting view}

user_attention_needed:
  - issue: "{what majority and minority disagree on}"
    majority_view: "{majority position}"
    minority_view: "{minority position}"
    recommendation: "{how to proceed}"
```

## Integration with Workflow

### In Phase 6 (Validation)

```yaml
IF feature_flags.s6_multi_judge_debate.enabled AND analysis_mode == complete:

  1. EXECUTE Round 1 (parallel)
  2. CHECK consensus
     IF reached → synthesize, proceed
  3. EXECUTE Round 2 (sequential - each reads others)
  4. CHECK consensus
     IF reached → synthesize, proceed
  5. EXECUTE Round 3 (final positions)
  6. SYNTHESIZE with majority rule if needed
  7. FLAG divergent findings for user
```

### Fallback Behavior

```yaml
IF NOT feature_flags.s6_multi_judge_debate.enabled OR analysis_mode != complete:
  USE single-round PAL Consensus (current behavior)
```

## Cost Analysis

| Scenario | Rounds | Judge Calls | Estimated Cost |
|----------|--------|-------------|----------------|
| Round 1 consensus | 1 | 3 | ~$0.05 |
| Round 2 consensus | 2 | 6 | ~$0.10 |
| Round 3 (max) | 3 | 9 | ~$0.15 |
| **Average** | ~2 | ~5-6 | ~$0.08-0.10 |

**Comparison:**
- Single-round consensus: ~$0.05
- Debate adds: +$0.03-0.10 average
- Value: Deeper analysis, minority opinions preserved

## State Tracking

```yaml
debate_validation:
  enabled: true
  rounds_completed: 2
  consensus_reached_at: 2  # or null if majority rule

  round_1:
    scores: [3.8, 4.2, 3.5]
    range: 0.7
    consensus: false

  round_2:
    scores: [4.0, 4.1, 3.9]
    range: 0.2
    consensus: true

  verdict:
    type: "consensus"
    final_score: 4.0
    confidence: "HIGH"

  convergent_findings: 3
  divergent_findings: 1
```
