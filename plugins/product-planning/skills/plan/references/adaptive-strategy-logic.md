# Adaptive Strategy Logic Reference (S4)

Decision tree and test vectors for adaptive composition strategy selection after architecture evaluation.

## Overview

After architecture perspectives are evaluated (by judges in Complete/Advanced mode), select the appropriate composition strategy based on tension distribution across the Diagonal Matrix:

```
┌─────────────────────────────────────────────────────────────────┐
│                  STRATEGY SELECTION FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Evaluate all architecture perspectives...                      │
│       ↓                                                          │
│  Parse judge scores for each perspective...                     │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Calculate:                                                 │  │
│  │   max_score = highest perspective score                    │  │
│  │   min_score = lowest perspective score                     │  │
│  │   score_gap = max_score - second_highest                   │  │
│  │   all_above_threshold = all scores >= 3.0                  │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ IF score_gap >= 0.5 AND max_score >= 3.0:                  │  │
│  │   → DIRECT_COMPOSITION (low tension)                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓ (else)                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ IF NOT all_above_threshold (any score < 3.0):              │  │
│  │   → REFRAME (high tension)                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│       ↓ (else)                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ELSE (balanced perspectives, all >= 3.0, gap < 0.5):       │  │
│  │   → NEGOTIATED_COMPOSITION (medium tension)                │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Strategy Definitions

### DIRECT_COMPOSITION

**When:** Clear winning perspective exists (score gap >= 0.5 from second place, winner >= 3.0). Low tension across matrix cells.

**Actions:**
1. Use winning perspective's primary concern as the composition anchor
2. Enrich with secondary insights from other perspectives (no conflicts to resolve)
3. Apply tension map directly — all low/medium tensions merge automatically
4. Confirm winning perspective with user (minimal interaction)

**Output:**
```yaml
strategy: DIRECT_COMPOSITION
rationale: "Grounding scores 4.5, others at 3.8 and 3.5. Low tension across matrix."
winning_perspective: "grounding"
composition_anchor: "Structure (from Grounding primary)"
enrichments:
  - "Data contracts from Ideality secondary"
  - "Error handling from Resilience secondary"
```

### REFRAME

**When:** Any perspective scores < 3.0. High tension indicates fundamental conflict that cannot be composed.

**Actions:**
1. Identify which perspective(s) scored below threshold
2. Analyze what specific matrix cells caused the low score
3. Re-dispatch the specific conflicting agent with constraints from successful perspectives
4. No user interaction needed — automatic re-dispatch

**Output:**
```yaml
strategy: REFRAME
rationale: "Resilience scored 2.5 — failure scenarios poorly addressed. Re-dispatching."
weak_perspectives:
  - perspective: "resilience"
    score: 2.5
    failure_cells: ["Failure-First × Structure", "Failure-First × Data"]
constraints_for_redispatch:
  - "MUST address failure isolation patterns from Grounding analysis"
  - "MUST preserve data contracts defined in Ideality analysis"
```

### NEGOTIATED_COMPOSITION

**When:** All perspectives viable (all >= 3.0, gap < 0.5). Medium tension — perspectives are balanced, requiring user input to resolve specific tensions.

**Actions:**
1. Build tension map from T8a_RECONCILE output
2. Present high-tension cells to user for resolution
3. User resolves specific architectural trade-offs (richer interaction about real tensions)
4. Compose final design using user's tension resolutions

**Output:**
```yaml
strategy: NEGOTIATED_COMPOSITION
rationale: "Perspectives scored 4.0, 3.8, 3.7. Medium tension in 3 cells."
tension_map:
  high_tension:
    - cell: "Structure × Outside-In"
      grounding_says: "Reuse existing module boundaries"
      ideality_says: "New boundaries for cleaner contracts"
      user_resolution: null  # Pending user input
  medium_tension:
    - cell: "Data × Failure-First"
      ideality_says: "Strict validation at boundaries"
      resilience_says: "Lenient parsing with fallbacks"
      auto_resolution: "Strict at external boundaries, lenient internally"
composition_sources:
  structure: "Grounding primary + Ideality structural implications"
  data: "Ideality primary + Resilience data integrity"
  behavior: "Resilience primary + Grounding behavioral patterns"
```

## Decision Tree (Pseudocode)

```python
def select_strategy(perspective_scores: List[float]) -> Strategy:
    """
    Select composition strategy based on perspective scores.

    Args:
        perspective_scores: List of scores (1-5) for each architecture perspective

    Returns:
        Strategy: DIRECT_COMPOSITION | REFRAME | NEGOTIATED_COMPOSITION
    """
    # Sort scores descending
    sorted_scores = sorted(perspective_scores, reverse=True)

    max_score = sorted_scores[0]
    second_score = sorted_scores[1] if len(sorted_scores) > 1 else 0
    min_score = sorted_scores[-1]

    score_gap = max_score - second_score
    all_above_threshold = all(s >= 3.0 for s in perspective_scores)

    # Decision tree
    if score_gap >= 0.5 and max_score >= 3.0:
        return Strategy.DIRECT_COMPOSITION
    elif not all_above_threshold:
        return Strategy.REFRAME
    else:
        return Strategy.NEGOTIATED_COMPOSITION
```

## Test Vectors

Use these test cases to validate strategy selection implementation:

```yaml
test_cases:
  # DIRECT_COMPOSITION cases
  - name: "Clear winner - large gap"
    scores: [4.5, 3.8, 3.5]
    expected_strategy: DIRECT_COMPOSITION
    reason: "Gap of 0.7 >= 0.5 threshold, winner >= 3.0"

  - name: "Clear winner - exact threshold"
    scores: [4.0, 3.5, 3.4]
    expected_strategy: DIRECT_COMPOSITION
    reason: "Gap of 0.5 equals threshold (>=)"

  - name: "Clear winner - two perspectives"
    scores: [4.2, 3.5]
    expected_strategy: DIRECT_COMPOSITION
    reason: "Gap of 0.7 >= 0.5, works with 2 perspectives"

  # REFRAME cases
  - name: "Weak perspective - clear failure"
    scores: [2.8, 2.5, 2.3]
    expected_strategy: REFRAME
    reason: "All scores < 3.0"

  - name: "One weak perspective - triggers reframe"
    scores: [3.5, 3.2, 2.9]
    expected_strategy: REFRAME
    reason: "Not all scores >= 3.0 (one at 2.9)"

  - name: "Borderline weak"
    scores: [3.0, 2.9, 2.8]
    expected_strategy: REFRAME
    reason: "2.9 and 2.8 are < 3.0"

  # NEGOTIATED_COMPOSITION cases
  - name: "Balanced perspectives - tight cluster"
    scores: [4.0, 3.8, 3.7]
    expected_strategy: NEGOTIATED_COMPOSITION
    reason: "Gap of 0.2 < 0.5, all scores >= 3.0"

  - name: "Balanced perspectives - all equal"
    scores: [3.5, 3.5, 3.5]
    expected_strategy: NEGOTIATED_COMPOSITION
    reason: "Gap of 0.0 < 0.5, all >= 3.0"

  - name: "Balanced perspectives - just under gap"
    scores: [4.0, 3.6, 3.5]
    expected_strategy: NEGOTIATED_COMPOSITION
    reason: "Gap of 0.4 < 0.5 threshold"

  # Edge cases
  - name: "Single perspective - high score"
    scores: [4.0]
    expected_strategy: DIRECT_COMPOSITION
    reason: "Only one perspective, score >= 3.0, compose directly"

  - name: "Single perspective - low score"
    scores: [2.5]
    expected_strategy: REFRAME
    reason: "Only perspective is below threshold"

  - name: "Winner but below threshold"
    scores: [2.8, 2.3, 2.0]
    expected_strategy: REFRAME
    reason: "Even though gap exists, winner < 3.0"
```

## Integration with Workflow

### In Phase 4 (Architecture Design)

After Diagonal Matrix MPA or ToT generates perspectives and judges evaluate them:

```markdown
### Step 4.5: Strategy Selection

1. COLLECT judge scores for all architecture perspectives
2. APPLY decision tree to determine strategy
3. EXECUTE selected strategy:

   IF DIRECT_COMPOSITION:
     - Use winning perspective as composition anchor
     - Enrich with secondary insights from other perspectives
     - Confirm with user (minimal interaction)
     - LOG: "Strategy: DIRECT_COMPOSITION - {winning_perspective} anchors composition"

   IF REFRAME:
     - Identify weak perspective(s) and failing matrix cells
     - Re-dispatch specific agent with constraints from successful perspectives
     - MAX 1 reframe loop, then escalate to user
     - LOG: "Strategy: REFRAME - re-dispatching {weak_perspective}"

   IF NEGOTIATED_COMPOSITION:
     - Present tension map to user
     - User resolves high-tension cells
     - Compose using user's resolutions + auto-resolved medium tensions
     - LOG: "Strategy: NEGOTIATED_COMPOSITION - {N} tensions resolved by user"

4. UPDATE state with strategy_selected and rationale
```

## State Tracking

Add to `.planning-state.local.md`:

```yaml
architecture:
  perspectives_evaluated: 3
  scores: [4.0, 3.8, 3.7]
  strategy_selected: NEGOTIATED_COMPOSITION
  strategy_rationale: "Balanced perspectives - scores within 0.3, all viable"
  tension_map:
    high_tension_count: 2
    medium_tension_count: 4
    low_tension_count: 3
  composition_sources:
    structure: "Grounding primary"
    data: "Ideality primary"
    behavior: "Resilience primary"
```

## Cost Impact

| Strategy | Effort Saved | When Worth It |
|----------|--------------|---------------|
| DIRECT_COMPOSITION | 15-20% | Clear winning perspective, low tension |
| REFRAME | +1 iteration | Better than composing from flawed perspective |
| NEGOTIATED_COMPOSITION | Baseline | Balanced perspectives, user resolves real trade-offs |
