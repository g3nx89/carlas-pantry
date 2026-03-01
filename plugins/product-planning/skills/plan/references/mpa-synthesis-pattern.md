---
purpose: "Shared parameterized MPA synthesis pattern"
used_by:
  - "phase-4-architecture.md (Steps 4.6, 4.7)"
  - "phase-7-test-strategy.md (Steps 7.8, 7.10)"
feature_flags:
  - "s7_mpa_deliberation"
  - "s8_convergence_detection"
---

# MPA Synthesis Pattern (Parameterized)

> **Shared reference.** Phase 4 and Phase 7 both invoke this pattern for MPA Deliberation (S1)
> and Convergence Detection (S2). Each phase provides parameters; this file provides the algorithm.
>
> **Do not duplicate this logic in phase files.** Instead, reference this file with your parameters.

## Parameters

| Parameter | Phase 4 (Architecture) | Phase 7 (Test Strategy) |
|-----------|------------------------|-------------------------|
| `AGENT_OUTPUTS` | `[grounding, ideality, resilience]` | `[general, security, performance]` |
| `AGENT_LIST` | Architecture agents from Step 4.4 | QA agents from Step 7.5 |
| `PHASE_ID` | `"4"` | `"7"` |
| `LOW_CONVERGENCE_STRATEGY` | `"present_all_options"` | `"include_all_flag_conflicts"` |
| `INSIGHT_FOCUS` | Key insights, unique patterns, novel approaches | Key test cases, unique risk findings, novel coverage approaches |
| `RESOLUTION_STRATEGY` | User decision for architectural conflicts | Higher severity for risk conflicts, broader coverage for scope conflicts |

## MPA Deliberation (S1: s7_mpa_deliberation)

```
IF feature_flags.s7_mpa_deliberation.enabled AND analysis_mode in {advanced, complete}:

  AFTER all agents complete:

  1. INSIGHT INTEGRATION
     FOR EACH agent_output IN {AGENT_OUTPUTS}:
       EXTRACT: {INSIGHT_FOCUS}
     BUILD: combined_insights = deduplicated list of all unique insights

  2. HYPOTHESIS REFINEMENT
     # Feed Round 1 outputs back to agents as "Round 2" prompt
     # (Only in Complete mode — Advanced uses inline synthesis)
     IF analysis_mode == "complete":
       FOR EACH agent IN {AGENT_LIST}:
         RE-DISPATCH agent with prompt including:
           "## Round 1 Peer Outputs\n{condensed findings from other agents}"
         # Agents have Round 2 Cross-Review awareness section

     ELSE:
       # Advanced mode: inline synthesis without re-dispatch
       SYNTHESIZE combined_insights into unified analysis

  3. GAP ANALYSIS + CONTRADICTION LOG
     IDENTIFY contradictions between agent outputs:
     | Agent A | Agent B | Topic | A's Position | B's Position | Resolution |
     |---------|---------|-------|-------------|-------------|------------|
     {populated from agent outputs}

     Resolution strategy: {RESOLUTION_STRATEGY}

     IF contradictions.length > 0:
       LOG: "MPA Deliberation found {N} contradictions — flagging for synthesis"

ELSE:
  # S1 disabled — proceed to next step (TAO Loop or direct synthesis)
```

## Convergence Detection (S2: s8_convergence_detection)

```
IF feature_flags.s8_convergence_detection.enabled AND analysis_mode in {advanced, complete}:

  AFTER agents complete (and deliberation if enabled):

  1. KEYWORD EXTRACTION
     FOR EACH agent_output IN {AGENT_OUTPUTS}:
       keywords[agent] = EXTRACT top {config.mpa.convergence_detection.keyword_count} technical keywords

  2. JACCARD SIMILARITY
     FOR EACH pair (A, B) IN combinations(agents, 2):
       similarity[A,B] = |keywords[A] ∩ keywords[B]| / |keywords[A] ∪ keywords[B]|

     avg_similarity = MEAN(all pairwise similarities)

     NOTE: Jaccard measures vocabulary overlap, not semantic agreement.
     Agents sharing domain vocabulary may score high convergence even with
     different architectural conclusions. Use convergence level as a heuristic
     signal for synthesis strategy, not a definitive measure of agreement.

  3. CLASSIFY keyword convergence level:
     IF avg_similarity >= config.mpa.convergence_detection.high_threshold (default 0.7):
       keyword_level = "high"
       LOG: "MPA keyword convergence: HIGH ({avg_similarity:.2f}) — agents largely agree"
     ELIF avg_similarity >= config.mpa.convergence_detection.medium_threshold (default 0.4):
       keyword_level = "medium"
       LOG: "MPA keyword convergence: MEDIUM ({avg_similarity:.2f}) — partial agreement"
     ELSE:
       keyword_level = "low"
       LOG: "MPA keyword convergence: LOW ({avg_similarity:.2f}) — significant divergence"

  #### Step 3b: Structural Feature Similarity

     Extract structural features per agent output:
     - `component_count` — number of distinct components/modules proposed
     - `risk_category_count` — number of risk categories identified
     - `dependency_depth` — max dependency chain length
     - `interface_count` — number of API/interface boundaries

     Compute pairwise structural similarity per dimension:
     `structural_sim = 1 - (|features_A - features_B| / max(features_A, features_B))`
     IF both values are 0 for a dimension: `structural_sim = 1.0` (identical absence = full agreement).
     Average structural_sim across all 4 feature dimensions (arithmetic mean).

     Classify structural convergence using same thresholds as keyword convergence:
     IF avg_structural_sim >= config.mpa.convergence_detection.high_threshold (default 0.7):
       structural_level = "high"
     ELIF avg_structural_sim >= config.mpa.convergence_detection.medium_threshold (default 0.4):
       structural_level = "medium"
     ELSE:
       structural_level = "low"

  #### Step 3c: Divergence Guard

     IF `keyword_level` and `structural_level` diverge by >1 level (e.g., keyword=HIGH but structural=LOW):
       - Flag as **"ambiguous convergence"**
       - Default to **medium** synthesis strategy
       - LOG: `"Convergence ambiguity: keyword={keyword_level}, structural={structural_level}. Defaulting to medium."`

  4. DETERMINE effective convergence level:
     # Divergence guard may override (see Step 3c)
     IF ambiguous_convergence:
       convergence = "medium"
     ELSE:
       convergence = keyword_level  # structural_level confirmed alignment

  5. ADAPT synthesis behavior:
     IF convergence == "high":
       # Strong agreement — merge directly, highlight unique additions
       synthesis_strategy = config.mpa.convergence_detection.strategies.high
     ELIF convergence == "medium":
       # Partial agreement — weighted merge, flag divergent areas
       synthesis_strategy = config.mpa.convergence_detection.strategies.medium
     ELSE:
       # Low convergence — phase-specific handling
       synthesis_strategy = {LOW_CONVERGENCE_STRATEGY}
       LOG: "Low convergence — using phase-specific strategy: {LOW_CONVERGENCE_STRATEGY}"

  6. INCLUDE convergence metadata in phase summary:
     key_decisions += {
       id: "KD-{PHASE_ID}-convergence",
       decision: "MPA convergence: {convergence} (keyword: {keyword_level}, structural: {structural_level}, similarity: {avg_similarity:.2f})",
       rationale: "Synthesis strategy: {synthesis_strategy}",
       confidence: "HIGH"
     }

ELSE:
  synthesis_strategy = "merge_strategy" from config.mpa.synthesis
```

## Known Limitations

- **Jaccard vs semantic similarity:** Jaccard measures vocabulary overlap, not conceptual agreement. Two agents could use different terms for the same concept (e.g., "Repository pattern" vs "Data Access Layer") and score low. Conversely, agents sharing domain vocabulary may score high while disagreeing on architecture. This is a known trade-off for simplicity — no external embedding model or API calls required.
- **Top-N keyword sensitivity:** The `keyword_count` parameter (default 20) affects granularity. Too few keywords miss nuance; too many dilute signal with common terms.
- **Threshold calibration:** The 0.7/0.4 thresholds are reasonable starting points. Monitor convergence scores across sessions to calibrate for your domain.
- **Structural feature extraction:** Component/risk/dependency/interface counts are approximations derived from agent prose output, not parsed ASTs. Counts may vary based on agent verbosity and naming granularity. The divergence guard (Step 3c) mitigates false confidence from keyword-only convergence.
