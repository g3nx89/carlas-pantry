# Tree of Thoughts (ToT) Hybrid Workflow Reference (S5)

Complete workflow for Hybrid ToT-MPA architecture exploration in Complete mode.

## Overview

The Hybrid ToT-MPA approach combines systematic exploration (Tree of Thoughts) with grounded perspectives (MPA seeding) for superior architecture discovery.

```
┌─────────────────────────────────────────────────────────────────┐
│              HYBRID ToT-MPA ARCHITECTURE WORKFLOW                │
│                      (Complete Mode Only)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 4a: SEEDED EXPLORATION (8 approaches)                    │
│  ├── Minimal perspective: 2 approaches                          │
│  ├── Clean perspective: 2 approaches                            │
│  ├── Pragmatic perspective: 2 approaches                        │
│  └── Wildcard agent: 2 approaches (unconstrained)               │
│       ↓                                                          │
│  Phase 4b: MULTI-CRITERIA PRUNING                                │
│  ├── 3 judges evaluate all 8 approaches                         │
│  ├── Ranked-choice voting                                        │
│  ├── Diversity preservation check                                │
│  └── Select top 4                                                │
│       ↓                                                          │
│  Phase 4c: COMPETITIVE EXPANSION                                 │
│  ├── 4 agents develop full designs                              │
│  ├── Each incorporates pruning feedback                         │
│  └── Constitutional AI self-critique                            │
│       ↓                                                          │
│  Phase 4d: EVALUATION + ADAPTIVE SELECTION                       │
│  ├── 3 judges evaluate all 4 designs                            │
│  ├── Apply Adaptive Strategy (S4)                                │
│  │   ├── CLEAR_WINNER → Polish                                  │
│  │   ├── TIE → Synthesize top 2                                 │
│  │   └── ALL_WEAK → Return to 4a                                │
│  └── Final design with documentation                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Phase 4a: Seeded Exploration

### Launch Configuration

```yaml
exploration:
  seeded_agents:
    - perspective: minimal
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches prioritizing MINIMAL CHANGE.
        Focus on:
        - Smallest footprint modification
        - Reusing existing patterns exactly
        - Lowest risk path
        - Quick time-to-implement

        Generate:
        - Approach M1: High probability (>0.8) - safest minimal change
        - Approach M2: Moderate probability (0.5-0.8) - slightly bolder minimal

    - perspective: clean
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches prioritizing CLEAN ARCHITECTURE.
        Focus on:
        - Proper separation of concerns
        - Dependency inversion
        - Testability
        - Long-term maintainability

        Generate:
        - Approach C1: High probability (>0.8) - standard clean approach
        - Approach C2: Moderate probability (0.5-0.8) - stricter clean principles

    - perspective: pragmatic
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches prioritizing PRAGMATIC BALANCE.
        Focus on:
        - Balance of cleanliness and speed
        - Technical debt management
        - Team capabilities
        - Business timeline

        Generate:
        - Approach P1: High probability (>0.8) - balanced pragmatic
        - Approach P2: Moderate probability (0.5-0.8) - slightly more ambitious

  wildcard_agent:
    agent: wildcard-architect
    prompt_prefix: |
      Generate 2 UNCONSTRAINED architecture approaches.
      You are free to ignore conventional categories.

      Generate:
      - Approach W1: High probability (>0.8) - innovative but grounded
      - Approach W2: Low probability (<0.2) - experimental/radical

      See wildcard-architect.md for exploration strategies.
```

### Exploration Output

Each approach must include:
- Brief description (2-3 sentences)
- Probability estimate
- Key trade-offs
- Self-critique verification

```yaml
approach:
  id: "M1|M2|C1|C2|P1|P2|W1|W2"
  name: "{descriptive name}"
  category: "minimal|clean|pragmatic|wildcard"
  probability: 0.XX
  description: |
    {2-3 sentence description}
  trade_offs:
    pros:
      - "{advantage}"
    cons:
      - "{disadvantage}"
  self_verified: true|false
```

## Phase 4b: Multi-Criteria Pruning

### Judge Configuration

Launch 3 pruning judges in parallel:

```yaml
pruning_judges:
  - model: gemini-3-pro-preview
    prompt: "Evaluate all 8 approaches. See architecture-pruning-judge.md"

  - model: gpt-5.2
    prompt: "Evaluate all 8 approaches. See architecture-pruning-judge.md"

  - model: grok-4
    prompt: "Evaluate all 8 approaches. See architecture-pruning-judge.md"
```

### Voting Aggregation

1. **Sum ranked-choice points:**
   - 1st choice = 3 points
   - 2nd choice = 2 points
   - 3rd choice = 1 point

2. **Calculate weighted criteria scores:**
   - Average across judges per criterion

3. **Aggregate scoring:**
   ```
   Total = (Criteria Score × 0.7) + (Rank Points × 0.3)
   ```

4. **Select top 4 with diversity check:**
   - If top 4 are from same 2 categories, force include option from missing category

### Pruning Output

```yaml
pruning_result:
  ranked_options:
    - id: "P1"
      total_score: 4.2
      rank: 1
      verdict: ADVANCE
    - id: "C1"
      total_score: 3.9
      rank: 2
      verdict: ADVANCE
    # ... continue for all 8

  advancing: ["P1", "C1", "W1", "M2"]
  eliminated: ["M1", "C2", "P2", "W2"]

  diversity_check:
    categories_represented: ["pragmatic", "clean", "wildcard", "minimal"]
    diversity_satisfied: true

  feedback_for_expansion:
    P1: "Strengthen error handling section"
    C1: "Add performance considerations"
    W1: "Ground in existing patterns more"
    M2: "Expand on integration points"
```

## Phase 4c: Competitive Expansion

### Expansion Configuration

For each advancing approach, launch full design agent:

```yaml
expansion_agents:
  - approach_id: "P1"
    agent: software-architect
    prompt: |
      Develop complete architecture design for approach P1.

      Original brief: {P1_description}
      Pruning feedback: {P1_feedback}

      Requirements:
      - Full component design with file paths
      - Integration mapping with file:line refs
      - Data flow documentation
      - Build sequence
      - Error handling strategy
      - Self-critique verification

  # ... repeat for C1, W1, M2
```

### Expansion Output

Each expanded design follows standard software-architect output format:
- Problem decomposition
- Pattern alignment
- Component design
- Integration map
- Data flow
- Build sequence
- Self-critique summary

## Phase 4d: Evaluation + Adaptive Selection

### Evaluation Configuration

Launch 3 judges to evaluate expanded designs:

```yaml
evaluation_judges:
  - model: gemini-3-pro-preview
    prompt: "Evaluate architecture quality. See judge-gate-rubrics.md Gate 2"

  - model: gpt-5.2
    prompt: "Evaluate architecture quality. See judge-gate-rubrics.md Gate 2"

  - model: grok-4
    prompt: "Evaluate architecture quality. See judge-gate-rubrics.md Gate 2"
```

### Adaptive Strategy Application

After evaluation, apply S4 logic:

```python
scores = [P1_score, C1_score, W1_score, M2_score]

if max(scores) - second_max(scores) >= 0.5 and max(scores) >= 3.0:
    strategy = SELECT_AND_POLISH
    # Polish winner with feedback
elif any(score < 3.0 for score in scores):
    strategy = REDESIGN
    # Return to Phase 4a with constraints
else:
    strategy = FULL_SYNTHESIS
    # Combine best elements from top 2
```

### Final Output

```yaml
tot_result:
  workflow_completed: true
  phases_executed: ["4a", "4b", "4c", "4d"]

  exploration:
    approaches_generated: 8
    approaches_advanced: 4

  selection:
    strategy: "SELECT_AND_POLISH|REDESIGN|FULL_SYNTHESIS"
    final_design: "P1"  # or synthesized

  design_file: "{FEATURE_DIR}/design.md"

  metrics:
    total_agent_calls: 15  # 4 seeded + 1 wildcard + 3 prune + 4 expand + 3 eval
    estimated_cost: "$0.38"
```

## Cost Analysis

| Phase | Agent Calls | Estimated Cost |
|-------|-------------|----------------|
| 4a: Exploration | 5 (4 seeded + 1 wildcard) | ~$0.12 |
| 4b: Pruning | 3 judges | ~$0.05 |
| 4c: Expansion | 4 architects | ~$0.16 |
| 4d: Evaluation | 3 judges | ~$0.05 |
| **Total** | **15** | **~$0.38** |

**Comparison:**
- Standard MPA (Complete mode): ~$0.22
- ToT adds: +$0.16 (+73%)
- Value: Significantly better exploration, reduced risk of missing optimal solution

## Fallback Behavior

If MCP tools unavailable or S5 disabled:

```yaml
fallback:
  condition: "feature_flags.s5_tot_architecture.enabled == false"
  behavior: "Use standard MPA (3 predetermined perspectives)"
  cost_savings: "$0.16"
```

## State Tracking

Add to `.planning-state.local.md`:

```yaml
tot_workflow:
  enabled: true
  phases_completed: ["4a", "4b", "4c", "4d"]

  exploration:
    approaches: ["M1", "M2", "C1", "C2", "P1", "P2", "W1", "W2"]

  pruning:
    advanced: ["P1", "C1", "W1", "M2"]
    eliminated: ["M1", "C2", "P2", "W2"]
    diversity_satisfied: true

  expansion:
    designs_completed: 4

  selection:
    strategy: "SELECT_AND_POLISH"
    winner: "P1"
    final_score: 4.2

  metrics:
    agent_calls: 15
    estimated_cost_usd: 0.38
```
