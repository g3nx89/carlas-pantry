# Debate Round Template (S6)

Templates for multi-round debate validation in Complete mode.

---

## Round 1: Independent Analysis

### Judge Position Statement

```yaml
---
judge_id: "{model_name}"
stance: "neutral|for|against"
round: 1
timestamp: "{ISO-8601}"

overall_score: X.X  # 1-5 scale

dimension_scores:
  problem_understanding: X  # 1-5
  architecture_quality: X   # 1-5
  risk_mitigation: X        # 1-5
  implementation_clarity: X # 1-5
  feasibility: X            # 1-5

position_statement: |
  ## My Assessment

  ### Strengths (with evidence)
  1. {strength} - Evidence: {specific reference from artifacts}
  2. {strength} - Evidence: {specific reference from artifacts}
  3. {strength} - Evidence: {specific reference from artifacts}

  ### Concerns (with evidence)
  1. {concern} - Evidence: {specific reference from artifacts}
  2. {concern} - Evidence: {specific reference from artifacts}

  ### Overall Verdict
  {Summary of position from my stance perspective. 2-3 sentences.}

key_claims:
  - claim: "{specific claim about the plan}"
    evidence: "{supporting reference from artifacts}"
    confidence: "HIGH|MEDIUM|LOW"

  - claim: "{specific claim about the plan}"
    evidence: "{supporting reference from artifacts}"
    confidence: "HIGH|MEDIUM|LOW"

critical_findings:
  - finding: "{if any CRITICAL issue found}"
    severity: "CRITICAL"
    evidence: "{reference}"
    blocks_consensus: true
---
```

---

## Round 2: Rebuttal

### Judge Rebuttal Statement

```yaml
---
judge_id: "{model_name}"
round: 2
timestamp: "{ISO-8601}"

# Score revision tracking
score_changed: true|false
previous_score: X.X
new_score: X.X
change_reason: |
  {Explanation of why score changed}
  OR
  {Explanation of why position maintained despite counterarguments}

# What I agree with
agreements:
  - with_judge: "{judge_id}"
    on_point: "{what I now agree with}"
    strengthening_evidence: |
      {Additional evidence that supports their point}
    impact_on_my_position: "{how this changes my view}"

# What I disagree with
disagreements:
  - with_judge: "{judge_id}"
    on_point: "{what I still disagree with}"
    their_argument: "{summary of their position}"
    my_counterargument: |
      {My rebuttal to their point}
    my_evidence: "{supporting reference from artifacts}"
    their_evidence_weakness: |
      {Why their evidence is insufficient or misinterpreted}

# Updated position
position_revision: |
  ## Updated Position

  Based on other judges' arguments:

  ### Points I Accept
  - {point} from Judge X - convinced by {reason}
  - {point} from Judge Y - convinced by {reason}

  ### Points I Reject
  - {point} from Judge X - because {counterargument}
  - {point} from Judge Y - because {counterargument}

  ### My Revised Assessment
  {Updated position summary. How has my view evolved?}

# Remaining disputes
unresolved_disputes:
  - topic: "{what remains disputed}"
    my_view: "{my position}"
    opposing_view: "{their position}"
    why_unresolved: "{fundamental disagreement reason}"
---
```

---

## Round 3: Final Position

### Judge Final Statement

```yaml
---
judge_id: "{model_name}"
round: 3
is_final: true
timestamp: "{ISO-8601}"

final_score: X.X

final_position: |
  ## Final Assessment

  After considering all arguments across two rounds of debate:

  {Comprehensive final position. 3-4 paragraphs covering:
   - Overall quality assessment
   - Key strengths that survived debate
   - Remaining concerns
   - Recommendation}

key_points_maintained:
  - point: "{argument I maintain despite challenges}"
    reason: "{why I'm confident in this position}"
    evidence: "{supporting reference}"

  - point: "{argument I maintain despite challenges}"
    reason: "{why I'm confident in this position}"
    evidence: "{supporting reference}"

concessions_made:
  - point: "{what I now accept that I initially rejected}"
    convinced_by: "{which judge and which argument}"
    impact: "{how this changed my overall assessment}"

unresolved_disagreements:
  - issue: "{remaining dispute that could not be resolved}"
    my_final_view: "{my position}"
    opposing_view: "{their position}"
    why_unresolved: |
      {Fundamental difference that prevents consensus.
       This may require user decision.}
    user_attention_needed: true|false
---
```

---

## Verdict Synthesis

### Consensus Verdict (all scores within 0.5)

```yaml
---
verdict_type: "consensus"
rounds_completed: {1|2|3}
consensus_reached_at_round: {1|2|3}

# Aggregated scores
consensus_score: X.X  # Average of all judges
score_range: [X.X, X.X]  # [min, max]
confidence: "HIGH"

dimension_consensus:
  problem_understanding:
    average: X.X
    range: X.X
  architecture_quality:
    average: X.X
    range: X.X
  risk_mitigation:
    average: X.X
    range: X.X
  implementation_clarity:
    average: X.X
    range: X.X
  feasibility:
    average: X.X
    range: X.X

# Merged findings
convergent_findings:
  - finding: "{all judges agree on this}"
    priority: "CRITICAL|HIGH|MEDIUM|LOW"
    source_judges: ["all"]
    action_required: true|false

  - finding: "{all judges agree on this}"
    priority: "CRITICAL|HIGH|MEDIUM|LOW"
    source_judges: ["all"]
    action_required: true|false

# Balanced synthesis
balanced_assessment: |
  ## Consensus Assessment

  {Synthesis incorporating all stance perspectives.
   Should reflect:
   - Neutral judge's objective view
   - "For" judge's identified strengths
   - "Against" judge's identified risks

   2-3 paragraphs.}

recommendations:
  - priority: "MUST"
    action: "{required action}"
    rationale: "{from consensus}"

  - priority: "SHOULD"
    action: "{recommended action}"
    rationale: "{from consensus}"
---
```

### Majority Verdict (Round 3 without consensus)

```yaml
---
verdict_type: "majority"
rounds_completed: 3
consensus_reached: false

# Vote breakdown
majority_score: X.X  # Average of majority judges
minority_score: X.X  # Dissenting judge's score
score_gap: X.X

majority_judges: ["{judge_id}", "{judge_id}"]
minority_judges: ["{judge_id}"]

confidence: "MEDIUM"

# Majority opinion
majority_opinion: |
  ## Majority Position

  {Summary of the position held by majority.
   What do they agree on?
   What is their recommendation?}

# Minority opinion (preserved for user review)
minority_opinion: |
  ## Minority Position (Dissent)

  {Summary of the dissenting view.
   Why do they disagree?
   What concerns do they maintain?}

# Items requiring user attention
user_attention_needed:
  - issue: "{what majority and minority fundamentally disagree on}"
    majority_view: "{majority position}"
    minority_view: "{minority position}"
    stakes: "{what's at risk}"
    recommendation: |
      {Suggested path forward. Options might include:
       - Accept majority view
       - Address minority concerns before proceeding
       - Seek additional input}

# Combined recommendations
recommendations:
  - priority: "MUST"
    action: "{required action from majority}"
    consensus_level: "majority"

  - priority: "SHOULD"
    action: "{recommended action}"
    consensus_level: "unanimous"

  - priority: "CONSIDER"
    action: "{minority concern to address}"
    consensus_level: "minority"
---
```

---

## Debate Metrics

### Round-by-Round Tracking

```yaml
debate_metrics:
  feature: "{FEATURE_NAME}"
  start_time: "{ISO-8601}"
  end_time: "{ISO-8601}"

  rounds:
    round_1:
      scores: [X.X, X.X, X.X]  # Per judge
      range: X.X
      consensus_check: false

    round_2:
      scores: [X.X, X.X, X.X]
      range: X.X
      consensus_check: true|false
      score_changes:
        - judge: "{judge_id}"
          delta: +X.X
          reason: "persuaded by..."

    round_3:  # If needed
      scores: [X.X, X.X, X.X]
      range: X.X
      final_verdict: "consensus|majority"

  position_evolution:
    agreements_formed: X  # Points where judges converged
    disputes_resolved: X  # Initially disagreed, now agree
    disputes_remaining: X # Still in disagreement

  cost:
    judge_calls: X
    estimated_usd: X.XX
```

---

## Appendix: Glossary

| Term | Definition |
|------|------------|
| **Stance** | The perspective a judge takes: neutral (objective), for (advocate), against (challenger) |
| **Consensus** | All judges' scores within 0.5 points of each other |
| **Majority Verdict** | Decision made by 2/3 judges when consensus fails |
| **Rebuttal** | Response to other judges' arguments, may include score revision |
| **Convergent Finding** | A conclusion all judges agree on |
| **Divergent Finding** | A conclusion where judges disagree |
| **Critical Finding** | A severe issue that blocks consensus until resolved |

---

*Templates used by debate-judge agent. See `references/debate-protocol.md` for full protocol.*
