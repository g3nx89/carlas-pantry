---
lens: "Reasoning & Decomposition Quality"
lens_id: "reasoning"
skill_reference: "customaize-agent:thought-based-reasoning"
fallback_used: true
target_skill: "feature-planning"
target_path: "plugins/product-planning/skills/plan/SKILL.md"
version_analyzed: "3.0.0"
date: "2026-03-01"
findings_count: 12
severity_distribution:
  critical: 0
  high: 2
  medium: 4
  low: 3
  info: 3
---

# Reasoning & Decomposition Quality Analysis

**Target Skill:** feature-planning v3.0.0
**Lens:** Reasoning & Decomposition Quality
**Evaluation Criteria:** Fallback criteria (lens skill `customaize-agent:thought-based-reasoning` not installed)

---

## Executive Summary

The feature-planning skill demonstrates sophisticated reasoning architecture with explicit use of multiple reasoning methodologies (CoT, ToT, ReAct, self-critique/Reflexion, MPA deliberation). The decomposition into 9+ phases with clear delegation boundaries is strong. The primary weaknesses are: (1) implicit reasoning transitions within the orchestrator loop where complex conditional logic lacks explicit decision rationale propagation, and (2) the convergence detection mechanism uses a weak proxy (Jaccard similarity) without an articulated degradation-aware reasoning chain. The skill would benefit from explicit "reasoning about reasoning" at two critical junctures: gate failure escalation and strategy selection.

---

## Strengths

### S1: Comprehensive Reasoning Methodology Portfolio

**Category:** Reasoning methodology selection
**File:** `SKILL.md`, `references/cot-prefix-template.md`, `references/self-critique-template.md`, `references/tot-workflow.md`

The skill explicitly deploys a diverse portfolio of reasoning methodologies matched to problem characteristics:

- **Chain-of-Thought (CoT):** Standardized via `cot-prefix-template.md` with agent-type-specific variations (research-heavy, design-heavy, evaluation agents). The 4-step template (Understand, Break Down, Anticipate, Verify) is well-structured with explicit activation phrases.
- **Tree of Thoughts (ToT):** The `tot-workflow.md` implements a genuine explore-prune-expand-evaluate cycle (Phases 4a-4d) with seeded perspectives, multi-criteria pruning via ranked-choice voting, and diversity preservation checks.
- **Self-Critique / Reflexion:** The `self-critique-template.md` implements Constitutional AI-style verification with calibrated question counts per agent type (4-7 questions), evidence requirements, and mode-specific thresholds.
- **Multi-Perspective Analysis (MPA):** Diagonal Matrix MPA crosses 3 perspectives (Inside-Out, Outside-In, Failure-First) with 3 concern axes (Structure, Data, Behavior), creating a systematic exploration space.
- **ReAct Pattern:** Referenced in agent prompts (e.g., code-explorer's "Analysis Approach (ReAct Pattern)") for interleaved reasoning and tool use.

This is a notably mature reasoning architecture that goes well beyond simple prompt chaining.

### S2: Explicit Decomposition with Clear Termination Criteria

**Category:** Decomposition of complex problems
**File:** `SKILL.md` (Phase Dispatch Table), `references/orchestrator-loop.md`

The 9-phase decomposition maps cleanly to a problem hierarchy:

1. Setup (environment) -> Research (knowledge) -> Clarification (requirements) -> Architecture (design) -> Deep Analysis (validation) -> Plan Validation (quality gate) -> Test Strategy (verification) -> Coverage Validation (quality gate) -> Completion (synthesis)

Each phase has explicit:
- Entry conditions (completed_phases, analysis_mode, feature_flags)
- Exit conditions (summary status, checkpoint)
- Termination criteria (gate verdicts: GREEN/YELLOW/RED)
- Fallback behavior (crash recovery, degraded summaries)
- Retry bounds (max 2 retries before escalation)

The dispatch table (SKILL.md lines 129-141) serves as a clean decomposition manifest with dependency tracking via "Prior Summaries" column.

### S3: Multi-Round Debate as Structured Disagreement Resolution

**Category:** Verification and self-correction
**File:** `references/debate-protocol.md`

The debate protocol (S6) implements a genuine dialectical reasoning process:
- Round 1: Independent analysis (no groupthink)
- Round 2: Rebuttal with evidence-based counterarguments
- Round 3: Final positions with majority rule

Consensus checks use explicit numeric criteria (score range <= 0.5, dimension range <= 1.0, critical finding agreement). The stance-differentiated judges (neutral, for, against) prevent confirmation bias. Minority opinions are preserved rather than discarded.

---

## Findings

### F1: Orchestrator Gate Escalation Lacks Explicit Reasoning Chain

**Severity:** HIGH
**Category:** Explicit step-by-step logic vs. implicit reasoning leaps
**File:** `references/orchestrator-loop.md` (lines 75-140)

**Current state:** The gate failure escalation logic is a deeply nested conditional tree with 6+ branches:

```
IF gate.verdict == "RED":
  IF retries < 2: retry
  ELSE:
    IF deep_reasoning enabled AND mode matches AND per-phase limit not exceeded AND session limit not exceeded:
      IF phase == "6" AND architecture_wall_breaker enabled: ...
      ELIF phase in [4,7] AND algorithm_detected AND difficulty flag: ...
      ELSE: circular_failure
    ELSE: ask user
```

This conditional chain makes 5-6 sequential decisions but never articulates WHY a particular escalation type was selected. The orchestrator chooses between `architecture_wall`, `algorithm_escalation`, and `circular_failure` based on flag-matching, but there is no reasoning trace explaining what about the failure pattern led to this classification.

**Recommendation:** Add an explicit `escalation_rationale` field that the orchestrator must populate before dispatching. For example:

```
escalation_rationale: |
  Gate failed 2x on Phase 6. Scores: [2.8, 3.1]. Lowest dimension: Architecture Quality (1.9).
  Phase 6 + architecture_wall_breaker enabled -> architecture_wall escalation.
  Rationale: Repeated failure on architecture quality suggests the design space
  needs external deep reasoning, not just re-iteration of the same agents.
```

This makes the reasoning auditable and debuggable when escalation paths produce poor outcomes.

---

### F2: Convergence Detection Uses Weak Proxy Without Reasoning Safeguards

**Severity:** HIGH
**Category:** Reasoning anti-patterns (assumptions without evidence)
**File:** `references/mpa-synthesis-pattern.md` (lines 69-124)

**Current state:** The convergence detection mechanism uses Jaccard similarity on keyword extraction to classify agent agreement as high/medium/low. The file acknowledges the limitation (line 86-89):

> "Jaccard measures vocabulary overlap, not semantic agreement. Agents sharing domain vocabulary may score high convergence even with different architectural conclusions."

However, the synthesis strategy is then directly derived from this convergence level (lines 103-111). A "high" convergence triggers "merge directly, highlight unique additions" -- meaning conflicting conclusions expressed with similar vocabulary will be merged without conflict resolution.

**Recommendation:** Insert an explicit verification step between convergence measurement and strategy selection:

```
AFTER classifying convergence level:
  IF convergence == "high":
    # VERIFY: Do agents actually agree, or just share vocabulary?
    EXTRACT position_statements from each agent
    CHECK for contradictory conclusions despite shared keywords
    IF contradictions found:
      DOWNGRADE convergence to "medium"
      LOG: "Convergence downgraded: vocabulary overlap masks disagreement on {topics}"
```

Additionally, consider requiring at least one explicit "agreement statement" from each agent pair to confirm high convergence, rather than relying solely on the keyword proxy.

---

### F3: Adaptive Strategy Decision Tree Has Ambiguous Boundary Behavior

**Severity:** MEDIUM
**Category:** Decision framework clarity
**File:** `references/adaptive-strategy-logic.md` (lines 121-151)

**Current state:** The strategy selection decision tree has a potential reasoning gap at the boundary between DIRECT_COMPOSITION and REFRAME. Consider scores `[3.0, 2.9, 2.5]`:

- `score_gap = 3.0 - 2.9 = 0.1` (< 0.5, so NOT DIRECT_COMPOSITION)
- `all_above_threshold = False` (2.9 < 3.0, so REFRAME)

But with scores `[3.5, 3.0, 2.9]`:
- `score_gap = 3.5 - 3.0 = 0.5` (>= 0.5 AND max >= 3.0, so DIRECT_COMPOSITION)

This means a single weak perspective (2.9) is ignored when there is a strong winner, but triggers a full reframe when perspectives are balanced. The decision tree does not reason about whether the weak perspective is relevant to the winning approach. A DIRECT_COMPOSITION anchored on a perspective whose weak sibling covers critical failure modes could produce a blind spot.

**Recommendation:** Add a relevance check to the DIRECT_COMPOSITION path:

```python
if score_gap >= 0.5 and max_score >= 3.0:
    # Check: does any below-threshold perspective cover a CRITICAL concern?
    weak_perspectives = [p for p in perspectives if p.score < 3.0]
    if any(p.primary_concern in CRITICAL_CONCERNS for p in weak_perspectives):
        return Strategy.NEGOTIATED_COMPOSITION  # Force negotiation on critical gaps
    return Strategy.DIRECT_COMPOSITION
```

The test vectors (lines 157-222) are excellent but do not cover this edge case. Add a test vector for `[3.5, 3.0, 2.9]` where the 2.9 perspective covers failure resilience.

---

### F4: Phase-to-Phase Reasoning Continuity Relies Solely on Summary Files

**Severity:** MEDIUM
**Category:** Decomposition -- information loss across subproblems
**File:** `SKILL.md` (lines 164-168), `references/orchestrator-loop.md` (lines 187-284)

**Current state:** Critical Rule 9 states: "Between phases, read ONLY summary files from `.phase-summaries/`. Never read full phase instruction files or raw artifacts in orchestrator context."

While this is architecturally sound for context management, it creates a reasoning continuity risk. Summary files are 30-80 lines (SKILL.md line 167). Complex reasoning chains -- such as why a particular architecture option was selected, what trade-offs were considered, or which risks were deprioritized and why -- may not survive the lossy compression into a summary.

The Context Pack (S6, orchestrator-loop.md lines 196-236) partially addresses this by accumulating decisions, questions, and risks. However, the token budgets are small (200/150/150 tokens per category), and the truncation strategies (`keep_high_confidence_first`, `keep_high_priority_first`) may discard reasoning context that becomes critical in later phases.

**Recommendation:** Add a "Reasoning Lineage" section to the phase summary template. This section (budget: ~100 tokens) would capture the key reasoning chain that led to the phase's primary conclusion, not just the conclusion itself:

```yaml
reasoning_lineage:
  primary_conclusion: "Selected microservices over monolith"
  key_reasoning_steps:
    - "Step 1: Identified 3 independent scaling domains (user, catalog, order)"
    - "Step 2: Monolith coupling analysis showed 2 circular dependencies"
    - "Step 3: Team structure favors independent deployment (3 squads)"
  assumptions_made:
    - "Assumed team has K8s experience (validated in Phase 2 research)"
  alternatives_rejected:
    - "Modular monolith -- rejected due to circular dependency cost"
```

---

### F5: Self-Critique Pass Threshold Is Static Despite Iterative Context

**Severity:** MEDIUM
**Category:** Verification and self-correction mechanisms
**File:** `references/self-critique-template.md` (lines 86-96)

**Current state:** The self-critique template uses fixed pass thresholds per mode (Rapid: 2/3, Standard: 4/5, Advanced: 4/5, Complete: 5/5). These thresholds do not account for the phase context. A Phase 2 research agent producing a 4/5 self-critique is very different from a Phase 9 task generation agent producing 4/5 -- the latter has access to all prior phase artifacts and should theoretically achieve higher verification scores.

Additionally, the "Revise If Needed" step (lines 67-73) says "If ANY question reveals a gap: STOP... FIX... RE-VERIFY" but provides no termination criterion for the revision loop. An agent could theoretically enter an infinite fix-verify cycle if each fix introduces a new gap.

**Recommendation:**
1. Add phase-aware threshold scaling. Later phases (7-9) that consume prior artifacts should require higher pass rates (e.g., 5/5 even in Advanced mode) because they have more information to verify against.
2. Add explicit revision loop termination: "Maximum 2 revision cycles. If gaps persist after 2 revisions, document remaining gaps in `limitations` and submit with LOW confidence."

---

### F6: ToT Workflow Lacks Explicit Reasoning About Pruning Decisions

**Severity:** MEDIUM
**Category:** Decision framework clarity (when to branch, when to converge)
**File:** `references/tot-workflow.md` (lines 136-200)

**Current state:** The ToT pruning phase (4b) uses a weighted formula: `Total = (Criteria Score x 0.7) + (Rank Points x 0.3)`. The diversity check forces inclusion of underrepresented perspectives. However, there is no explicit reasoning about why an approach was eliminated.

The pruning output (lines 174-200) records `verdict: ADVANCE` or implied elimination, plus `feedback_for_expansion` for advancing approaches. But eliminated approaches get no `elimination_reason` field. When the workflow later encounters problems in Phase 4c/4d, there is no way to reason about whether a pruned approach might have been the better path.

**Recommendation:** Add an `elimination_rationale` to the pruning output for each eliminated approach:

```yaml
eliminated:
  - id: "G1"
    elimination_reason: "Lowest criteria score (2.8). Structural approach too conservative for the scaling requirements."
    recoverable: true  # Could this be revisited if expansion fails?
  - id: "W2"
    elimination_reason: "Radical approach scored well on innovation (4.0) but 1.5 on feasibility."
    recoverable: false
```

This enables the REFRAME strategy (in Phase 4d) to consider resurrecting pruned approaches if all expanded designs score poorly, rather than only re-dispatching the same weak perspective.

---

### F7: Deep Reasoning Escalation Has No Reasoning Quality Validation

**Severity:** LOW
**Category:** Verification and self-correction after critical steps
**File:** `references/orchestrator-loop.md` (lines 82-140)

**Current state:** When deep reasoning escalation is triggered (e.g., via CTCO prompt to GPT-5 Pro), the orchestrator ingests the user-provided response and re-dispatches the target phase (line 131-132). There is no validation step to assess whether the deep reasoning response actually addresses the failing dimensions.

A user could paste an irrelevant or low-quality response from the external model, and the workflow would proceed to re-dispatch without verifying that the input resolves the identified weaknesses.

**Recommendation:** Add a lightweight validation step after deep reasoning ingestion:

```
IF user provides deep reasoning response:
  EXTRACT key recommendations from response
  COMPARE against summary.gate.failing_dimensions
  IF coverage < 50% of failing dimensions:
    WARN user: "The deep reasoning response addresses {N}/{M} failing dimensions.
    Missing coverage for: {uncovered_dimensions}. Proceed anyway?"
```

---

### F8: Circuit Breaker Pattern Is Described But Not Wired to Reasoning Outcomes

**Severity:** LOW
**Category:** Anti-patterns -- missing termination criteria
**File:** `references/orchestrator-loop.md` (lines 312-349)

**Current state:** The circuit breaker pattern is well-defined generically but its application table (lines 342-349) shows that `gate_retry` uses hardcoded `max_failures: 2` rather than the configurable circuit breaker pattern. The pattern exists as a reusable abstraction, but the most important use case (gate retries) bypasses it.

This means gate retries lack the structured escalation_action that the circuit breaker provides. Instead, the gate retry logic (lines 75-140) implements its own inline escalation tree, duplicating the concept without the pattern's discipline.

**Recommendation:** Refactor the gate retry logic to use the CIRCUIT_BREAKER function:

```
# Replace hardcoded retry logic with:
CIRCUIT_BREAKER(
  context_name="gate_retry_{phase}",
  action=RE_DISPATCH_PHASE(phase),
  max_failures=config.circuit_breaker.gate_retry.max_iterations,  # Move from hardcoded 2 to config
  escalation_action=DEEP_REASONING_OR_USER_CHOICE(phase)
)
```

This unifies the retry/escalation pattern and makes gate retry limits configurable.

---

### F9: MPA Deliberation Round 2 Is Mode-Gated But Not Reasoning-Gated

**Severity:** LOW
**Category:** Decision framework clarity
**File:** `references/mpa-synthesis-pattern.md` (lines 29-67)

**Current state:** MPA Deliberation Round 2 (re-dispatching agents with peer outputs) is gated purely on analysis mode:

```
IF analysis_mode == "complete": RE-DISPATCH agents for Round 2
ELSE: inline synthesis without re-dispatch
```

This means a Complete mode session always does Round 2 cross-review regardless of whether agents already agree. If all three agents produced highly convergent outputs in Round 1, the re-dispatch adds cost (~$0.15) and latency (~30s) without meaningful reasoning benefit.

**Recommendation:** Gate Round 2 on both mode AND convergence. If convergence detection (S2) is enabled and reports "high" convergence, skip Round 2 even in Complete mode:

```
IF analysis_mode == "complete" AND (NOT s8_convergence_detection.enabled OR convergence != "high"):
  RE-DISPATCH agents for Round 2
```

---

### F10: Least-to-Most Decomposition Is Implicit in Phase Ordering

**Severity:** INFO
**Category:** Reasoning methodology selection
**File:** `SKILL.md` (lines 71-118)

**Current state:** The 9-phase workflow implicitly follows a Least-to-Most decomposition pattern: simpler subproblems (Setup, Research) are solved first, and their outputs feed into progressively more complex subproblems (Architecture, Test Strategy, Task Generation). However, this is never explicitly identified as a Least-to-Most strategy.

This is an observation rather than a problem. The implicit use of this pattern is effective. Making it explicit (e.g., in a "Reasoning Architecture" section of SKILL.md) would help contributors understand why phases are ordered as they are and why reordering them would break the reasoning chain.

---

### F11: ReAct Pattern Is Referenced But Not Formalized

**Severity:** INFO
**Category:** Reasoning methodology selection
**File:** `references/cot-prefix-template.md` (line 113-116)

**Current state:** The CoT prefix template example shows a code-explorer agent with an "Analysis Approach (ReAct Pattern)" section, indicating that ReAct (Reason + Act interleaving) is used by some agents. However, unlike CoT (which has a dedicated template), ToT (which has a dedicated workflow), and self-critique (which has a dedicated template), ReAct has no standardized template or formalization.

Research-focused agents (code-explorer, researcher) inherently use ReAct when they interleave tool calls (Grep, Read) with reasoning. The pattern works naturally with Claude's tool-use capabilities. However, the lack of explicit formalization means there is no quality bar for how agents should structure their reason-act-observe cycles.

This is informational. The implicit ReAct usage appears effective, and over-formalizing it could add unnecessary overhead. However, if reasoning quality issues surface in research-heavy phases (2, 5), creating a lightweight ReAct template (similar to the CoT prefix) would be a natural improvement.

---

### F12: Diagonal Matrix MPA Is a Novel Reasoning Contribution

**Severity:** INFO
**Category:** Decomposition of complex problems
**File:** `SKILL.md` (lines 178-204), `references/tot-workflow.md`

**Current state:** The Diagonal Matrix MPA pattern -- crossing 3 architectural perspectives (Inside-Out, Outside-In, Failure-First) with 3 concern axes (Structure, Data, Behavior) -- is a thoughtful decomposition that ensures each agent has a primary concern and secondary concerns. This creates a 3x3 matrix where the diagonal elements (Inside-Out x Structure, Outside-In x Data, Failure-First x Behavior) are the primary assignments, while off-diagonal elements serve as cross-cutting enrichment.

This is a well-designed decomposition strategy that avoids the common anti-pattern of having parallel agents with overlapping but vaguely differentiated scopes. The explicit primary/secondary concern assignment gives each agent a clear reasoning anchor while ensuring comprehensive coverage of the design space.

---

## Summary Table

| ID | Title | Severity | Category |
|----|-------|----------|----------|
| S1 | Comprehensive Reasoning Methodology Portfolio | STRENGTH | Methodology selection |
| S2 | Explicit Decomposition with Clear Termination | STRENGTH | Decomposition |
| S3 | Multi-Round Debate as Structured Disagreement | STRENGTH | Verification |
| F1 | Gate Escalation Lacks Explicit Reasoning Chain | HIGH | Implicit reasoning leaps |
| F2 | Convergence Detection Uses Weak Proxy | HIGH | Reasoning anti-patterns |
| F3 | Adaptive Strategy Ambiguous Boundary Behavior | MEDIUM | Decision framework clarity |
| F4 | Phase-to-Phase Reasoning Continuity Loss | MEDIUM | Decomposition information loss |
| F5 | Self-Critique Pass Threshold Is Static | MEDIUM | Verification mechanisms |
| F6 | ToT Pruning Lacks Elimination Reasoning | MEDIUM | Decision framework clarity |
| F7 | Deep Reasoning Has No Quality Validation | LOW | Verification after critical steps |
| F8 | Circuit Breaker Not Wired to Gate Retries | LOW | Missing termination criteria |
| F9 | MPA Round 2 Not Reasoning-Gated | LOW | Decision framework clarity |
| F10 | Least-to-Most Decomposition Is Implicit | INFO | Methodology selection |
| F11 | ReAct Pattern Referenced But Not Formalized | INFO | Methodology selection |
| F12 | Diagonal Matrix MPA Is Novel Contribution | INFO | Decomposition |
