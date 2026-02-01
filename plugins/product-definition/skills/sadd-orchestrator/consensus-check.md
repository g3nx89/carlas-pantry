# Consensus Check Protocol

## Purpose

Analyze judge recommendations to determine if consensus exists. This protocol provides clear rules for detecting agreement, majority, and deadlock situations.

## When to Use

Use consensus check:
- After each debate round
- After parallel judge evaluations
- When aggregating multiple perspectives

## Consensus Rules

### Rule 1: Unanimous Agreement

```yaml
condition: "All judges recommend same option"
result: "UNANIMOUS_CONSENSUS"
confidence: "HIGH"
action: "Proceed with recommended option"

example:
  recommendations:
    - judge: "risk", option: "A"
    - judge: "value", option: "A"
    - judge: "effort", option: "A"

  verdict: "UNANIMOUS_CONSENSUS on Option A"
```

### Rule 2: Majority Agreement (2/3)

```yaml
condition: "At least 2 of 3 judges recommend same option"
result: "MAJORITY_CONSENSUS"
confidence: "HIGH"
action: "Proceed with majority option, note dissent"

example:
  recommendations:
    - judge: "risk", option: "A"
    - judge: "value", option: "B"
    - judge: "effort", option: "A"

  verdict: "MAJORITY_CONSENSUS on Option A (2/3)"
  dissent: "Value judge favors B: {reason}"
```

### Rule 3: No Consensus

```yaml
condition: "All judges recommend different options"
result: "NO_CONSENSUS"
confidence: "REQUIRES_INPUT"
action: "Present as contested, escalate to user"

example:
  recommendations:
    - judge: "risk", option: "A"
    - judge: "value", option: "B"
    - judge: "effort", option: "C"

  verdict: "NO_CONSENSUS - all perspectives diverge"
```

## Algorithm

```python
def check_consensus(recommendations, threshold=0.67):
    """
    Check if judges have reached consensus.

    Args:
        recommendations: List of {judge, option, confidence}
        threshold: Minimum agreement ratio (default 2/3)

    Returns:
        ConsensusResult with verdict and details
    """
    # Count votes per option
    vote_counts = {}
    for rec in recommendations:
        option = rec['option']
        if option not in vote_counts:
            vote_counts[option] = []
        vote_counts[option].append(rec['judge'])

    total_judges = len(recommendations)

    # Check for consensus
    for option, voters in vote_counts.items():
        ratio = len(voters) / total_judges

        if ratio == 1.0:
            return ConsensusResult(
                consensus=True,
                type="UNANIMOUS",
                option=option,
                voters=voters,
                confidence="HIGH"
            )

        if ratio >= threshold:
            dissenters = [r for r in recommendations if r['option'] != option]
            return ConsensusResult(
                consensus=True,
                type="MAJORITY",
                option=option,
                voters=voters,
                confidence="HIGH",
                dissent=dissenters
            )

    # No consensus
    return ConsensusResult(
        consensus=False,
        type="NONE",
        distribution=vote_counts,
        confidence="REQUIRES_INPUT"
    )
```

## Input Format

```yaml
consensus_check_input:
  recommendations:
    - judge: "risk"
      option: "A"
      confidence: "HIGH"
      reasoning: "{summary of reasoning}"

    - judge: "value"
      option: "B"
      confidence: "MEDIUM"
      reasoning: "{summary of reasoning}"

    - judge: "effort"
      option: "A"
      confidence: "HIGH"
      reasoning: "{summary of reasoning}"

  threshold: 0.67
```

## Output Format

### Consensus Found

```yaml
consensus_result:
  consensus: true
  type: "MAJORITY"

  majority_option: "A"
  majority_count: 2
  majority_judges: ["risk", "effort"]

  confidence: "HIGH"

  dissent:
    - judge: "value"
      option: "B"
      reasoning: "{reason for disagreement}"

  recommendation: |
    Proceed with Option A (2/3 consensus).
    Note: Value judge dissents, favoring B for user value reasons.
```

### No Consensus

```yaml
consensus_result:
  consensus: false
  type: "NONE"

  distribution:
    "A":
      count: 1
      judges: ["risk"]
    "B":
      count: 1
      judges: ["value"]
    "C":
      count: 1
      judges: ["effort"]

  confidence: "REQUIRES_INPUT"

  recommendation: |
    No consensus reached after debate.
    Present all perspectives to user for decision.
```

## Edge Cases

### Equal Split (2 Options, Even Votes)

```yaml
scenario: "2 judges pick A, 1 picks B in 3-judge panel"
result: "MAJORITY_CONSENSUS on A"
note: "2/3 meets threshold"
```

### Abstention or Invalid

```yaml
scenario: "Judge fails to provide valid recommendation"
handling: "Exclude from consensus calculation"
note_in_result: "Risk judge abstained/failed"
adjusted_total: "Consensus calculated from 2 judges"
```

### Single Judge

```yaml
scenario: "Only 1 judge provided recommendation"
result: "INSUFFICIENT_DATA"
confidence: "LOW"
action: "Treat as single recommendation, not consensus"
```

## Confidence Mapping

| Consensus Type | Agreement | Confidence |
|----------------|-----------|------------|
| UNANIMOUS | 3/3 | HIGH |
| MAJORITY | 2/3 | HIGH |
| NONE | 1/3 each | REQUIRES_INPUT |

## Integration

```typescript
// After collecting judge recommendations
const result = consensusCheck({
  recommendations: [
    { judge: "risk", option: "A", confidence: "HIGH" },
    { judge: "value", option: "B", confidence: "MEDIUM" },
    { judge: "effort", option: "A", confidence: "HIGH" }
  ],
  threshold: 0.67
});

if (result.consensus) {
  // Proceed with recommendation
  presentRecommendation(result.majority_option, result.dissent);
} else {
  // Escalate to user
  presentContested(result.distribution);
}
```

## Reporting

When reporting consensus results:

### For Consensus

```markdown
## Recommendation

**Option A** (Recommended)

Judges agreed (2/3):
- ✅ Risk Judge: Minimizes technical risk
- ✅ Effort Judge: Best ROI
- ❌ Value Judge: Prefers B for user value (dissent)

Confidence: **HIGH**
```

### For No Consensus

```markdown
## ⚠️ Contested Decision

Judges could not reach consensus. Your input is needed.

| Option | Judge | Reasoning |
|--------|-------|-----------|
| A | Risk | {reasoning} |
| B | Value | {reasoning} |
| C | Effort | {reasoning} |

Please select your preferred option: [A] [B] [C]
```
