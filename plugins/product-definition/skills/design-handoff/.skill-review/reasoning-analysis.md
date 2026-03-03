---
lens: "Reasoning & Decomposition Quality"
lens_id: "reasoning"
skill_reference: "customaize-agent:thought-based-reasoning"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: true
findings_count: 11
critical_count: 0
high_count: 3
medium_count: 5
low_count: 1
info_count: 2
---

# Reasoning & Decomposition Quality Analysis: design-handoff

## Summary

The design-handoff skill demonstrates strong overall reasoning architecture. It correctly decomposes a complex multi-stage workflow into discrete, independently recoverable stages with explicit dispatch protocols. The LLM-as-Judge pattern at stage boundaries is a well-reasoned simplification over MPA+PAL consensus, and the one-screen-per-dispatch strategy shows mature understanding of context limitations. However, the skill exhibits several reasoning gaps: implicit decision criteria at key branching points, missing termination conditions in retry loops, absent self-correction after gap analysis, and under-specified escalation logic in Scenario C. The gap analysis stage (Stage 3) is the strongest in reasoning explicitness; the orchestrator integration section in judge-protocol.md is the weakest, relying on implicit judgment where explicit criteria would prevent rubber-stamping or infinite cycling.

---

## Findings

### Finding 1: Judge Verdict "NEEDS_FIX" Re-dispatch Lacks Convergence Criteria

**Severity:** HIGH
**Category:** Missing termination criteria / anti-pattern (infinite loop risk)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** The Orchestrator Integration section (lines 193-206) specifies that on NEEDS_FIX, the orchestrator increments a cycle counter and re-dispatches the stage coordinator with judge findings. The termination condition is `cycle >= max_cycles`, at which point it escalates to the designer. However, there is no convergence check between cycles. The orchestrator does not verify that the number or severity of findings decreased between cycle N and cycle N+1. A stage coordinator could "fix" one issue while introducing another, cycling at the same severity level indefinitely until max_cycles is exhausted.

**Recommendation:** Add an explicit convergence gate between judge cycles. After each re-judge, compare `findings.length` and the set of `dimension` values against the prior cycle. If findings count did not decrease OR new dimensions appear that were not in the prior cycle's findings, escalate immediately rather than continuing to cycle. Document this as a "convergence check" step in the Orchestrator Integration section:

```
3b. CONVERGENCE CHECK: Compare current findings against prior cycle.
    - IF findings_count >= prior_cycle_findings_count: ESCALATE (no progress)
    - IF new dimensions appear not in prior cycle: ESCALATE (regression)
    - ELSE: continue to next fix cycle
```

---

### Finding 2: Scenario C Escalation to Scenario B Has No Reasoning Chain

**Severity:** HIGH
**Category:** Implicit reasoning leap / missing chain-of-thought
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** Scenario C (Already Clean, lines 299-315) says: "If verification discovers ANY issues (naming fixes > 0 OR unbound tokens > 0), the agent escalates to Scenario B and executes the full 9-step checklist." This is a binary escalation with no graduated reasoning. A single unbound token (which might be intentional, e.g., a one-off brand color) triggers the same full 9-step pipeline as a screen with 50 naming violations. The agent has no mechanism to reason about whether the discovered issues are genuine preparation gaps or intentional design decisions.

**Recommendation:** Introduce a Least-to-Most decomposition for Scenario C escalation:

1. **Micro-fix threshold** (from config): If naming fixes <= N AND unbound tokens <= M, apply fixes in-place without full escalation. Record as `scenario_micro_fix: true`.
2. **Partial escalation**: If issues exceed micro-fix threshold but are concentrated in one category (only naming OR only tokens), escalate to the relevant subset of steps (Steps 3-4 for naming; Step 6 for tokens) rather than the full 9-step pipeline.
3. **Full escalation**: Only if issues span multiple categories or exceed a higher threshold, escalate to full Scenario B.

Add thresholds to config under `figma_preparation.scenario_detection.clean_escalation_threshold`.

---

### Finding 3: Gap Analysis Has No Self-Verification Step

**Severity:** HIGH
**Category:** Missing self-correction / Reflexion pattern
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The gap analyzer produces a gap report and then immediately transitions to Stage 3J (judge). The analyzer itself has no self-check step. It does not verify: (a) that every screen in the inventory appears in Section 1 of the report, (b) that the navigation model in Section 3 accounts for all screens, or (c) that the severity distribution is plausible (e.g., zero CRITICAL gaps across all screens would be suspicious for a Draft scenario). The transition protocol (lines 416-471) verifies `total_screens_analyzed == count of prepared screens` at the orchestrator level, but this is a count check, not a reasoning verification.

**Recommendation:** Add an explicit self-verification step to the gap analyzer's workflow, executed BEFORE writing the final gap-report.md. This follows the Reflexion pattern:

1. **Coverage check**: Every screen in the inventory must appear in Section 1 (either with gaps or with "No supplement needed").
2. **Navigation completeness**: Every node in the Section 3 navigation model must correspond to either an inventory screen or a missing screen entry in Section 2.
3. **Severity plausibility**: If scenario == "draft" AND total CRITICAL gaps == 0, flag for re-examination (drafts almost always have behavioral gaps). If a form screen has zero "behaviors" gaps, flag as suspicious.
4. **Cross-reference integrity**: Every missing screen in Section 2 must have an `implied_by` that references an element on an actual inventory screen.

Document this as "Step 0: Self-Verification" in the gap report format section.

---

### Finding 4: TIER Decision Logic Is Opaque

**Severity:** MEDIUM
**Category:** Decision framework clarity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Stage 1, Step 7 (line 147) says "TIER Decision — Smart Componentization analysis, recommend TIER 1/2/3" and defers to `references/setup-protocol.md` (which was not read, but the SKILL.md provides no inline reasoning criteria). The TIER decision cascades through the entire workflow (TIER determines whether component library is created, whether component integration steps run, whether prototype wiring runs). Despite being a critical branching decision, the SKILL.md provides zero criteria for how TIER is determined. A reader of SKILL.md alone cannot reason about why a given file would be TIER 1 vs TIER 3.

**Recommendation:** Add a 3-line decision summary to the Stage 1 section in SKILL.md, even though the full logic lives in setup-protocol.md. For example:

```
**TIER heuristic:** TIER 1 (no componentization) when < 3 repeated patterns detected.
TIER 2 (component library) when >= 3 patterns across >= 2 screens. TIER 3 (full integration
+ prototype wiring) when TIER 2 criteria met AND >= 5 screens with navigational relationships.
Exact thresholds in config: `tier.*`
```

This makes the reasoning chain visible at the dispatch-table level without duplicating the full logic.

---

### Finding 5: Scenario Detection Criteria Use Implicit AND/OR Composition Without Decision Tree

**Severity:** MEDIUM
**Category:** Decision framework clarity / reasoning methodology
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** Scenarios A, B, and C (lines 251-315) define detection criteria using prose AND/OR conditions:
- Scenario A: "Average naming score < X, OR Average token score < Y, OR GROUP count > Z"
- Scenario B: "Average naming score >= X, AND Average token score >= Y, AND Readiness composite < W, AND GROUP count <= Z"
- Scenario C: "Readiness composite >= W, AND GROUP count == 0, AND Naming score >= X, AND Token score >= Y"

These are presented as three independent condition blocks, but they are actually a decision tree (C is checked first, then B, then A as fallback). The evaluation order is never stated. If a screen matches both A and B criteria (e.g., GROUP count is exactly at the threshold boundary), the outcome is ambiguous.

**Recommendation:** Restructure as an explicit decision tree with evaluation order:

```
1. CHECK Scenario C conditions → IF ALL pass → Scenario C
2. ELSE CHECK Scenario B conditions → IF ALL pass → Scenario B
3. ELSE → Scenario A (default fallback)
```

This also reveals that Scenario A is not truly a detection — it is the default when neither C nor B matches. Making this explicit prevents the reasoning gap where an implementor tries to evaluate A's OR conditions independently.

---

### Finding 6: FSB Generation Logic Buries Complex Reasoning in a Single Pseudocode Block

**Severity:** MEDIUM
**Category:** Decomposition into subproblems / Least-to-Most
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The FSB (Figma Screen Brief) generation logic in the "Transition to Stage 3J" section (lines 428-461) is a dense 30-line pseudocode block that combines: (1) iteration over missing screens, (2) filtering by classification, (3) numbering logic, (4) reference screen selection with a composite score formula and tiebreaker, (5) template loading, (6) field population with inference rules for 8+ fields, and (7) state file updates. This is a complex multi-step reasoning chain compressed into a single procedural block with no decomposition.

**Recommendation:** Decompose into named sub-procedures, each with a clear single responsibility:

1. **Filter eligible missing screens** (classification IN MUST_CREATE, SHOULD_CREATE)
2. **Select reference screen** (extract the composite score formula and tiebreaker into a named decision: `SELECT_REFERENCE_SCREEN(implied_by, state)`)
3. **Populate FSB fields** (separate the inference rules per field — Entry/Exit/Layout/States/Behaviors each have different reasoning)
4. **Write and register** (file write + state update)

Each sub-procedure should state its inputs, reasoning, and outputs. This makes the chain auditable and allows the judge to verify each step independently.

---

### Finding 7: Visual Diff "Pass/Fail" Is Binary Without Graduated Assessment

**Severity:** MEDIUM
**Category:** Verification and self-correction mechanisms
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** The visual diff enforcement (lines 319-359) treats the diff result as binary: pass or fail. On failure, the agent is re-dispatched with "fix instructions" containing `{VISUAL_DIFF_ISSUES}`. However, the protocol does not distinguish between categories of visual diff failure. A 1px misalignment and a completely missing element are treated identically. The fix re-dispatch sends the same generic prompt regardless of failure type, giving the agent no reasoning framework for prioritizing which issues to address first.

**Recommendation:** Classify visual diff failures into tiers that inform the re-dispatch reasoning:

| Tier | Example | Re-dispatch Strategy |
|------|---------|---------------------|
| Layout shift | Element repositioned, missing, or resized | Target specific node IDs in fix prompt |
| Color/token drift | Hex value changed from source | Check token binding for affected fills |
| Content change | Text content altered | Revert text, verify layer name mapping |
| Rendering artifact | Anti-aliasing, shadow clipping | Often MCP artifact — verify via second screenshot before counting as failure |

Include the tier in the re-dispatch prompt so the agent can apply targeted reasoning rather than re-running the entire checklist.

---

### Finding 8: Judge Rubric Dimensions Lack Weighting or Priority Order

**Severity:** MEDIUM
**Category:** Decision framework clarity
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** Each judge checkpoint defines 4-5 rubric dimensions as equal peers in a table. For example, Stage 2J has: Visual fidelity, Naming compliance, Token binding, Component instantiation, GROUP residue. The verdict logic says "One or more dimensions below threshold" triggers NEEDS_FIX. But it does not specify whether failing on Visual fidelity (which is the BLOCK-eligible dimension) should be weighted differently during the NEEDS_FIX assessment than failing on GROUP residue (a cleanup concern). A judge agent reading this rubric has no explicit guidance on which dimension failures are more severe.

**Recommendation:** Add a priority column to each rubric table:

| # | Dimension | Priority | How to Evaluate | Pass Condition |
|---|-----------|----------|----------------|----------------|
| 1 | Visual fidelity | P0 (block-eligible) | ... | ... |
| 2 | Naming compliance | P1 | ... | ... |
| 5 | GROUP residue | P2 | ... | ... |

Then add a rule: "When multiple dimensions fail, list findings in priority order. P0 failures in the first fix cycle; P1/P2 in subsequent cycles if P0 passes."

---

### Finding 9: "No Supplement Needed" Verification Reasoning Could Be Stronger

**Severity:** LOW
**Category:** Self-correction / verification
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** Lines 393-409 describe "No supplement needed" screens and provide three verification checks: (1) no interactive elements, (2) no component instances with missing variants, (3) no navigation elements implying missing destinations. This is good but the reasoning chain for the verification is one-directional — it checks for the absence of gap indicators. It does not include a positive confirmation step (e.g., "Verify the screen IS purely static by checking that all child nodes are non-interactive types: Image, Text, Frame without click handlers").

**Recommendation:** Add a positive confirmation heuristic alongside the negative checks: "Verify screen node tree contains ONLY non-interactive node types (TEXT, RECTANGLE, IMAGE, FRAME without prototype connections). If ANY node type suggests interactivity (INSTANCE of a Button component, FRAME with prototype connection), the screen cannot be zero-gap."

---

### Finding 10: ReAct Pattern Is Well-Applied in Stage 2 Dispatch Loop

**Severity:** INFO
**Category:** Reasoning methodology selection (positive observation)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** The Stage 2 screen loop (lines 136-188) implements a clean ReAct (Reasoning + Action) pattern: the orchestrator reasons about the current screen state, dispatches an action (agent), observes the result (reads state file), then reasons about the next action (continue, re-dispatch, or skip). The interleaving of reasoning and action is explicit, with state checkpoints between each cycle. This is the correct methodology for a workflow that depends on external tool outcomes (figma-console MCP).

---

### Finding 11: Confidence Tagging in Gap Analysis Enables Principled Deduplication

**Severity:** INFO
**Category:** Reasoning methodology (positive observation)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/gap-analysis.md`

**Current state:** The confidence tagging system (lines 174-183) with three levels (high/medium/low) and the explicit rule that "confidence never overrides severity" creates a principled two-axis classification. The rule that merged findings take the higher confidence (line 182) prevents information loss during cross-screen synthesis. This is a well-designed reasoning framework that avoids the common anti-pattern of conflating certainty with importance.

---

## Strengths

### Strength 1: Least-to-Most Decomposition via TIER System

The TIER system (1/2/3) decomposes the preparation complexity into graduated levels, where each tier adds capabilities on top of the prior tier. TIER 1 is the simplest subproblem (naming + tokens only), TIER 2 adds componentization, TIER 3 adds prototype wiring. This is textbook Least-to-Most prompting applied at the workflow architecture level — solve the simpler problem first, then use that solution as context for the harder problem. The graceful downgrade from TIER 2/3 to TIER 1 on component library failure (figma-preparation.md lines 126-131) demonstrates that the decomposition is not just structural but also resilient.

### Strength 2: LLM-as-Judge Replaces MPA+PAL with Clearer Reasoning

The decision to use a single judge agent at stage boundaries instead of MPA (multiple specialist agents) + PAL consensus is a well-reasoned architectural choice documented in the project's CLAUDE.md (Design Handoff v2.3.0 Patterns). The reasoning chain is explicit: MPA+PAL had synthesis bias (first-read anchoring), was context-heavy (8 agents), and produced ambiguous verdicts. The single judge with per-checkpoint rubrics provides clearer pass/fail criteria, eliminates synthesis bias, and reduces total agent dispatches. The judge-protocol.md file makes the rubric dimensions, pass conditions, and verdict actions explicit at each checkpoint — this is Chain-of-Thought reasoning baked into the evaluation framework.

### Strength 3: Crash Recovery via Step-Level State Tracking

The crash recovery protocol in figma-preparation.md (lines 432-467) demonstrates strong reasoning about failure modes. The state file tracks not just "which screen" but "which step within the screen," enabling mid-screen resume. The integrity check ("verify that all 'prepared' screens have corresponding screenshot files") adds a self-correction layer that catches state/artifact mismatches. This is a Reflexion-like pattern applied to infrastructure rather than content — the system reasons about its own state consistency before proceeding.

### Strength 4: Explicit "No Supplement Needed" Marking Eliminates Reasoning Ambiguity

The gap-analysis.md (lines 393-409) explicitly requires marking screens as "No supplement needed" rather than simply omitting them. The reasoning is stated clearly: "Omitting a screen from Section 1 is ambiguous — it could mean the screen was analyzed and found gap-free, or it could mean the screen was accidentally skipped." This eliminates a common reasoning anti-pattern where absence of information is treated as evidence of completeness.
