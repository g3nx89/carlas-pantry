# Adaptive Strategy Logic Reference (S4)

Decision tree and test vectors for adaptive strategy selection after architecture evaluation.

## Overview

After architecture options are evaluated (by judges in Complete/Advanced mode), select the appropriate synthesis strategy based on score distribution:

```
┌─────────────────────────────────────────────────────────────────┐
│                  STRATEGY SELECTION FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Evaluate all architecture options...                            │
│       ↓                                                          │
│  Parse judge scores for each option...                          │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Calculate:                                                 │  │
│  │   max_score = highest option score                        │  │
│  │   min_score = lowest option score                         │  │
│  │   score_gap = max_score - second_highest                  │  │
│  │   all_above_threshold = all scores >= 3.0                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ IF score_gap >= 0.5 AND max_score >= 3.0:                 │  │
│  │   → SELECT_AND_POLISH                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓ (else)                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ IF NOT all_above_threshold (any score < 3.0):             │  │
│  │   → REDESIGN                                               │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓ (else)                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ELSE (split decision, all >= 3.0, gap < 0.5):             │  │
│  │   → FULL_SYNTHESIS                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Strategy Definitions

### SELECT_AND_POLISH

**When:** Clear winner exists (score gap >= 0.5 from second place, winner >= 3.0)

**Actions:**
1. Select winning option as the base design
2. Review judge feedback for improvement areas
3. Polish winner with specific refinements
4. Skip synthesis step (save ~15-20% effort)

**Output:**
```yaml
strategy: SELECT_AND_POLISH
rationale: "Option A scores 4.5, others at 3.8 and 3.5. Clear winner by 0.7 gap."
selected_option: "A"
polish_actions:
  - "Address judge feedback on error handling"
  - "Add detail to integration specification"
```

### REDESIGN

**When:** All options are weak (any option scores < 3.0)

**Actions:**
1. Analyze common failure patterns across options
2. Extract constraints learned from failures
3. Return to exploration phase with new constraints
4. Log lessons learned for retry

**Output:**
```yaml
strategy: REDESIGN
rationale: "All options scored below adequate (2.8, 2.5, 2.3). Fundamental issues."
failure_patterns:
  - "All options ignored existing auth patterns"
  - "No option addressed the caching requirement"
constraints_for_retry:
  - "MUST follow existing auth pattern from research"
  - "MUST include caching strategy"
```

### FULL_SYNTHESIS

**When:** Multiple viable options (all >= 3.0, gap < 0.5)

**Actions:**
1. Identify strengths from each option
2. Synthesize best elements into combined design
3. Document trade-offs from synthesis
4. Create merged design with full rationale

**Output:**
```yaml
strategy: FULL_SYNTHESIS
rationale: "Options scored 4.0, 3.8, 3.7. All viable, gap only 0.3."
synthesis_plan:
  from_option_a:
    - "Error handling approach"
    - "API structure"
  from_option_b:
    - "Data model"
    - "Caching strategy"
  from_option_c:
    - "Testing approach"
```

## Decision Tree (Pseudocode)

```python
def select_strategy(option_scores: List[float]) -> Strategy:
    """
    Select synthesis strategy based on option scores.

    Args:
        option_scores: List of scores (1-5) for each architecture option

    Returns:
        Strategy: SELECT_AND_POLISH | REDESIGN | FULL_SYNTHESIS
    """
    # Sort scores descending
    sorted_scores = sorted(option_scores, reverse=True)

    max_score = sorted_scores[0]
    second_score = sorted_scores[1] if len(sorted_scores) > 1 else 0
    min_score = sorted_scores[-1]

    score_gap = max_score - second_score
    all_above_threshold = all(s >= 3.0 for s in option_scores)

    # Decision tree
    if score_gap >= 0.5 and max_score >= 3.0:
        return Strategy.SELECT_AND_POLISH
    elif not all_above_threshold:
        return Strategy.REDESIGN
    else:
        return Strategy.FULL_SYNTHESIS
```

## Test Vectors

Use these test cases to validate strategy selection implementation:

```yaml
test_cases:
  # SELECT_AND_POLISH cases
  - name: "Clear winner - large gap"
    scores: [4.5, 3.8, 3.5]
    expected_strategy: SELECT_AND_POLISH
    reason: "Gap of 0.7 >= 0.5 threshold, winner >= 3.0"

  - name: "Clear winner - exact threshold"
    scores: [4.0, 3.5, 3.4]
    expected_strategy: SELECT_AND_POLISH
    reason: "Gap of 0.5 equals threshold (>=)"

  - name: "Clear winner - two options"
    scores: [4.2, 3.5]
    expected_strategy: SELECT_AND_POLISH
    reason: "Gap of 0.7 >= 0.5, works with 2 options"

  # REDESIGN cases
  - name: "All weak - clear failure"
    scores: [2.8, 2.5, 2.3]
    expected_strategy: REDESIGN
    reason: "All scores < 3.0"

  - name: "One weak option - triggers redesign"
    scores: [3.5, 3.2, 2.9]
    expected_strategy: REDESIGN
    reason: "Not all scores >= 3.0 (one at 2.9)"

  - name: "Borderline weak"
    scores: [3.0, 2.9, 2.8]
    expected_strategy: REDESIGN
    reason: "2.9 and 2.8 are < 3.0"

  # FULL_SYNTHESIS cases
  - name: "Split decision - tight cluster"
    scores: [4.0, 3.8, 3.7]
    expected_strategy: FULL_SYNTHESIS
    reason: "Gap of 0.2 < 0.5, all scores >= 3.0"

  - name: "Split decision - all equal"
    scores: [3.5, 3.5, 3.5]
    expected_strategy: FULL_SYNTHESIS
    reason: "Gap of 0.0 < 0.5, all >= 3.0"

  - name: "Split decision - just under gap"
    scores: [4.0, 3.6, 3.5]
    expected_strategy: FULL_SYNTHESIS
    reason: "Gap of 0.4 < 0.5 threshold"

  # Edge cases
  - name: "Single option - high score"
    scores: [4.0]
    expected_strategy: SELECT_AND_POLISH
    reason: "Only one option, score >= 3.0, polish it"

  - name: "Single option - low score"
    scores: [2.5]
    expected_strategy: REDESIGN
    reason: "Only option is below threshold"

  - name: "Winner but below threshold"
    scores: [2.8, 2.3, 2.0]
    expected_strategy: REDESIGN
    reason: "Even though gap exists, winner < 3.0"
```

## Integration with Workflow

### In Phase 4 (Architecture Design)

After MPA or ToT generates options and judges evaluate them:

```markdown
### Step 4.5: Strategy Selection

1. COLLECT judge scores for all architecture options
2. APPLY decision tree to determine strategy
3. EXECUTE selected strategy:

   IF SELECT_AND_POLISH:
     - Set design.md = winning_option
     - Apply polish_actions from judge feedback
     - SKIP synthesis step
     - LOG: "Strategy: SELECT_AND_POLISH - {winning_option} selected"

   IF REDESIGN:
     - Document failure_patterns
     - Add constraints_for_retry to state
     - RETURN to Step 4.1 with constraints
     - MAX 1 redesign loop, then escalate to user
     - LOG: "Strategy: REDESIGN - returning to exploration"

   IF FULL_SYNTHESIS:
     - Merge best elements from each option
     - Document what came from where
     - Create unified design.md
     - LOG: "Strategy: FULL_SYNTHESIS - merged {option_list}"

4. UPDATE state with strategy_selected and rationale
```

## State Tracking

Add to `.planning-state.local.md`:

```yaml
architecture:
  options_evaluated: 3
  scores: [4.0, 3.8, 3.7]
  strategy_selected: FULL_SYNTHESIS
  strategy_rationale: "Split decision - scores within 0.3, all viable"
  synthesis_sources:
    option_a: ["API structure", "error handling"]
    option_b: ["data model"]
    option_c: ["test approach"]
```

## Cost Impact

| Strategy | Effort Saved | When Worth It |
|----------|--------------|---------------|
| SELECT_AND_POLISH | 15-20% | Clear winner, minor refinements needed |
| REDESIGN | +1 iteration | Better than building on flawed foundation |
| FULL_SYNTHESIS | Baseline | Multiple good options, worth combining |
