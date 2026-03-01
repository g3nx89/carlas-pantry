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
│  ├── Inside-Out perspective: 2 approaches (Structural Grounding)│
│  ├── Outside-In perspective: 2 approaches (Contract Ideality)   │
│  ├── Failure-First perspective: 2 approaches (Resilience Arch.) │
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
    - perspective: inside_out
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches from the INSIDE-OUT perspective (Structural Grounding).
        PRIMARY concern: Structure — module boundaries, dependency graph, abstraction layers.
        SECONDARY concerns: Data flow through existing structure, behavioral patterns from structural choices.
        Focus on:
        - Existing codebase internals as starting point
        - Structural integrity and proven patterns
        - Leveraging existing module boundaries
        - Low structural risk

        Generate:
        - Approach G1: High probability (>0.8) - safest structural grounding
        - Approach G2: Moderate probability (0.5-0.8) - bolder structural evolution

    - perspective: outside_in
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches from the OUTSIDE-IN perspective (Contract Ideality).
        PRIMARY concern: Data — API contracts, validation schemas, data transformation boundaries.
        SECONDARY concerns: Structural implications of ideal contracts, behavioral guarantees contracts enforce.
        Focus on:
        - Consumer/external perspective as starting point
        - Ideal data contracts and API shapes
        - Clean interface boundaries
        - Long-term contract stability

        Generate:
        - Approach I1: High probability (>0.8) - standard contract-driven design
        - Approach I2: Moderate probability (0.5-0.8) - stricter contract ideality

    - perspective: failure_first
      agent: software-architect
      prompt_prefix: |
        Generate 2 architecture approaches from the FAILURE-FIRST perspective (Resilience Architecture).
        PRIMARY concern: Behavior — error propagation, recovery paths, degraded operation modes.
        SECONDARY concerns: Structural patterns for failure isolation, data integrity under failure.
        Focus on:
        - Failure scenarios as starting point
        - Production robustness from day one
        - Graceful degradation paths
        - Observable and recoverable behavior

        Generate:
        - Approach R1: High probability (>0.8) - balanced resilience
        - Approach R2: Moderate probability (0.5-0.8) - more comprehensive resilience

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
  id: "G1|G2|I1|I2|R1|R2|W1|W2"
  name: "{descriptive name}"
  perspective: "inside_out|outside_in|failure_first|wildcard"
  primary_concern: "structure|data|behavior|unconstrained"
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
    - id: "R1"
      total_score: 4.2
      rank: 1
      verdict: ADVANCE
    - id: "I1"
      total_score: 3.9
      rank: 2
      verdict: ADVANCE
    # ... continue for all 8

  advancing: ["R1", "I1", "W1", "G2"]
  eliminated:
    - option_id: "G1"
      elimination_rationale: "Duplicates R1 structural approach with lower resilience coverage"
      recoverable: true   # Could reconsider if R1 proves infeasible
    - option_id: "I2"
      elimination_rationale: "Exceeds complexity budget by 2x with no proportional benefit over I1"
      recoverable: true   # Could reconsider if stricter contracts become a requirement
    - option_id: "R2"
      elimination_rationale: "Comprehensive resilience adds latency incompatible with performance SLAs"
      recoverable: false  # Architecturally incompatible with latency requirements
    - option_id: "W2"
      elimination_rationale: "Experimental approach lacks proven patterns for production readiness"
      recoverable: true   # Could reconsider if constraints relax on maturity requirements

  diversity_check:
    perspectives_represented: ["failure_first", "outside_in", "wildcard", "inside_out"]
    concerns_represented: ["behavior", "data", "unconstrained", "structure"]
    diversity_satisfied: true

  feedback_for_expansion:
    R1: "Strengthen error handling section"
    I1: "Add performance considerations"
    W1: "Ground in existing patterns more"
    G2: "Expand on integration points"
```

## Phase 4c: Competitive Expansion

### Expansion Configuration

For each advancing approach, launch full design agent:

```yaml
expansion_agents:
  - approach_id: "R1"
    agent: software-architect
    prompt: |
      Develop complete architecture design for approach R1.

      Original brief: {R1_description}
      Pruning feedback: {R1_feedback}

      Requirements:
      - Full component design with file paths
      - Integration mapping with file:line refs
      - Data flow documentation
      - Build sequence
      - Error handling strategy
      - Self-critique verification

  # ... repeat for I1, W1, G2
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
scores = [R1_score, I1_score, W1_score, G2_score]

if max(scores) - second_max(scores) >= 0.5 and max(scores) >= 3.0:
    strategy = DIRECT_COMPOSITION
    # Compose from winning perspective with enrichment
elif any(score < 3.0 for score in scores):
    strategy = REFRAME
    # Re-dispatch specific conflicting agent
else:
    strategy = NEGOTIATED_COMPOSITION
    # User resolves tensions from tension map
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
    strategy: "DIRECT_COMPOSITION|REFRAME|NEGOTIATED_COMPOSITION"
    final_design: "R1"  # or composed

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
  behavior: "Use standard Diagonal Matrix MPA (3 diagonal perspectives)"
  cost_savings: "$0.16"
```

## State Tracking

Add to `.planning-state.local.md`:

```yaml
tot_workflow:
  enabled: true
  phases_completed: ["4a", "4b", "4c", "4d"]

  exploration:
    approaches: ["G1", "G2", "I1", "I2", "R1", "R2", "W1", "W2"]

  pruning:
    advanced: ["R1", "I1", "W1", "G2"]
    eliminated: ["G1", "I2", "R2", "W2"]
    diversity_satisfied: true

  expansion:
    designs_completed: 4

  selection:
    strategy: "DIRECT_COMPOSITION"
    winner: "R1"
    final_score: 4.2

  metrics:
    agent_calls: 15
    estimated_cost_usd: 0.38
```
