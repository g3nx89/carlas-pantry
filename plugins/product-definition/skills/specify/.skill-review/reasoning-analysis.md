---
lens: thought-based-reasoning
lens_source: fallback_criteria
fallback_used: true
target_skill: feature-specify
target_path: plugins/product-definition/skills/specify
skill_version: 1.2.0
analysis_date: "2026-03-01"
findings_count:
  critical: 1
  high: 3
  medium: 4
  low: 2
  info: 0
strengths_count: 4
files_reviewed:
  - SKILL.md
  - references/orchestrator-loop.md
  - references/stage-4-clarification.md
  - references/auto-resolve-protocol.md
  - references/error-handling.md
  - references/stage-2-spec-draft.md
---

# Reasoning & Decomposition Quality Analysis: feature-specify

## Summary

The feature-specify skill is an ambitious 7-stage orchestrated workflow for producing feature specifications. It demonstrates strong decomposition at the macro level (stages, coordinator delegation, iteration loops) and includes several explicit reasoning patterns (auto-resolve classification, severity boosting, quality gates). However, the skill suffers from critical gaps in reasoning chain explicitness at decision boundaries, over-reliance on implicit coordinator judgment for complex synthesis tasks, absence of self-consistency mechanisms where they would add the most value, and missing termination guarantees in its iteration loop. The skill would benefit from adopting Chain-of-Thought scaffolding at key decision points, Reflexion-style verification after synthesis operations, and explicit Least-to-Most decomposition for its most complex subproblems.

---

## Findings

### Finding 1: Iteration Loop Lacks Hard Termination Guarantee

**Severity:** CRITICAL
**Category:** Missing termination criteria / Reasoning anti-pattern
**File:** `references/orchestrator-loop.md` (lines 292-340)

**Current state:** The Stage 3 <-> Stage 4 iteration loop terminates on two conditions: (1) coverage >= 85%, or (2) user forces proceed after stall detection (improvement < 5%). However, there is no hard iteration cap. The stall detection itself depends on a numeric coverage metric that may not decrease monotonically -- a coordinator could re-evaluate coverage differently across iterations (e.g., discovering new checklist items that lower the denominator), causing oscillation without triggering the < 5% stall detector. The pseudocode says:

```
LOOP again (Stage 4 -> Stage 3) until coverage met or user forces proceed
```

This is an unbounded loop with a soft exit condition that depends on both correct metric computation and user awareness.

**Recommendation:** Add a hard iteration ceiling (e.g., `max_iterations: 5` in config) as a safety net independent of coverage metrics. When reached, automatically present the user with a summary of coverage trajectory and force a proceed/abort decision. This prevents infinite loops in degenerate cases where coverage oscillates (e.g., 78% -> 82% -> 79% -> 83% -> 80%...) without ever triggering the < 5% stall detector because each pair of adjacent iterations shows >= 5% swing. Document the ceiling as a circuit breaker, not a quality target, to preserve the "no artificial limits" philosophy. Add the following reasoning chain to the orchestrator loop:

```
BEFORE re-dispatching Stage 3:
  IF iteration_count >= config.max_iterations:
    FORCE user decision (proceed/abort)
    LOG: "Circuit breaker: {N} iterations without convergence"
  ELIF coverage decreased from previous iteration:
    LOG: "Coverage regression detected: {prev}% -> {curr}%"
    INCREMENT regression_count
    IF regression_count >= 2:
      FORCE user decision with regression analysis
```

---

### Finding 2: Gate Self-Evaluation Is an Implicit Reasoning Leap

**Severity:** HIGH
**Category:** Implicit reasoning / Missing Chain-of-Thought scaffolding
**File:** `references/stage-2-spec-draft.md` (lines 178-217)

**Current state:** Gates 1 and 2 each evaluate 4 criteria and assign a binary pass/fail per criterion. The instruction says "Auto-evaluate 4 criteria" but provides no explicit reasoning methodology for how the coordinator should perform this evaluation. For example, Gate 1 criterion 1 is "Problem statement is specific (not generic)" -- the coordinator must determine specificity, but there is no rubric, no worked examples, no Chain-of-Thought scaffold. The same coordinator that drafted the spec is implicitly asked to evaluate its own work (or the work of a BA subagent it dispatched), which is a rubber-stamping anti-pattern.

The skill does have a dedicated `gate-judge` agent (referenced in SKILL.md Agent References table), but the stage-2 reference file never explicitly dispatches this agent for gate evaluation. Instead, it says "Auto-evaluate" which implies the coordinator itself performs the assessment.

**Recommendation:**
1. Make gate evaluation explicit: always dispatch the `gate-judge` agent for Gates 1 and 2 (never have the coordinator self-evaluate). This separates the "author" from the "evaluator" role.
2. Add a Chain-of-Thought scaffold to the gate-judge dispatch prompt:

```
For each criterion, reason step-by-step:
  1. Quote the relevant section of spec.md
  2. State what the criterion requires
  3. Identify evidence FOR passing
  4. Identify evidence AGAINST passing
  5. Render verdict (pass/fail) with confidence
```

3. If the gate-judge is already intended for this role, make the dispatch explicit in `stage-2-spec-draft.md` Steps 2.4 and 2.5 rather than leaving it implicit.

---

### Finding 3: CLI Synthesis Lacks Explicit Reasoning Methodology

**Severity:** HIGH
**Category:** Implicit reasoning / Missing decomposition
**File:** `references/stage-4-clarification.md` (lines 162-215), `references/stage-2-spec-draft.md` (lines 104-176)

**Current state:** Multiple CLI dispatch points (Challenge in Stage 2, EdgeCases in Stage 4, Triangulation in Stage 4) produce parallel outputs that must be synthesized. The synthesis instructions are minimal:

- Stage 2 Challenge: "Synthesize findings using haiku agent (union_with_dedup strategy)" (one line)
- Stage 4 EdgeCases: "Synthesize with severity boost: 2+ CLIs identify same edge case -> boost severity" (two lines)
- Stage 4 Triangulation: "Semantic deduplication against existing questions (similarity threshold: 0.85)" (one line)

Each of these is a complex multi-step reasoning task (reading 3 divergent outputs, identifying semantic overlaps, resolving contradictions, boosting confidence) compressed into a single-sentence instruction. There is no explicit reasoning chain for how to determine if two findings from different CLIs are "the same edge case" or how semantic similarity is computed.

**Recommendation:** For each synthesis point, provide an explicit Least-to-Most decomposition:

```
SYNTHESIS PROTOCOL (per dispatch type):
  Step 1: INVENTORY — List all findings from each CLI with source tag
  Step 2: CLUSTER — Group findings by semantic topic (same feature area + same concern type)
  Step 3: OVERLAP — Within each cluster, identify cross-CLI agreement:
    - Same concern raised by 2+ CLIs -> mark as corroborated
    - Contradictory findings -> flag for explicit resolution
  Step 4: BOOST — Apply severity boost rules to corroborated findings
  Step 5: DEDUPLICATE — Merge corroborated findings into single entry, cite all sources
  Step 6: VERIFY — Count final findings; if count > 2x any single CLI's count, re-examine for over-splitting
```

This makes the reasoning chain auditable and prevents the haiku synthesis agent from silently dropping or over-merging findings.

---

### Finding 4: Auto-Resolve Classification Depends on Unstated Judgment

**Severity:** HIGH
**Category:** Decision framework clarity
**File:** `references/auto-resolve-protocol.md` (lines 36-100)

**Current state:** The auto-resolve protocol classifies questions into AUTO_RESOLVED, INFERRED, or REQUIRES_USER. The classification logic includes match criteria such as:

- "Document explicitly states the answer (not implied)"
- "Answer is specific enough to act on"
- "Question intent matches (not just keyword overlap)"

These criteria require significant judgment but provide no worked examples or boundary cases. The distinction between "explicitly states" and "reasonable inference" is the entire crux of the classification, yet it is left to a single sentence. A coordinator processing 20+ questions will apply inconsistent standards across them without a more explicit reasoning scaffold.

Additionally, the Exclusion Rules (lines 106-113) list categories like "Trade-off questions" and "Scope decisions" but do not define how to detect them. Is "Should we support offline mode?" a scope decision or a feature question? The answer depends on context that is not captured in the protocol.

**Recommendation:**
1. Add 3-4 worked examples showing the exact reasoning chain for each classification level:

```
EXAMPLE — AUTO_RESOLVED:
  Question: "What currency should prices be displayed in?"
  Source: Input document says "The app targets US consumers exclusively"
  Reasoning: US-exclusive market implies USD. Source is explicit about geography.
  Classification: AUTO_RESOLVED
  Citation: "input.md: 'targets US consumers exclusively' (section 1)"

EXAMPLE — INFERRED:
  Question: "Should the app support dark mode?"
  Source: Input document says "follow iOS design guidelines"
  Reasoning: iOS guidelines recommend dark mode support but do not require it.
  Classification: INFERRED (guideline suggests but does not dictate)

EXAMPLE — REQUIRES_USER (exclusion: scope decision):
  Question: "Should we support offline mode?"
  Detection: This determines feature scope boundary — not answerable from documents
  Classification: REQUIRES_USER regardless of any document mentions
```

2. Add a detection heuristic for each exclusion category (e.g., "Scope decision: question contains 'should we include/support/add' AND answer would add or remove a feature boundary").

---

### Finding 5: No Self-Consistency Check for BA Spec Draft

**Severity:** MEDIUM
**Category:** Missing self-consistency / verification mechanism
**File:** `references/stage-2-spec-draft.md` (lines 23-62)

**Current state:** The BA agent produces a spec draft in a single pass using Sequential Thinking for 8 phases. The only post-draft verification is the self-critique score (N/20) which is generated by the same agent that wrote the draft. There is no independent verification of internal consistency -- for example, whether all user stories referenced in acceptance criteria actually exist, whether NFRs are consistent with stated user stories, or whether the problem statement aligns with the proposed solution.

The MPA-Challenge CLI dispatch (Step 2.3) checks problem framing but not internal consistency of the spec document itself.

**Recommendation:** Add a lightweight internal consistency check between Step 2.2 (Parse BA Response) and Step 2.3 (MPA-Challenge), either as a coordinator-internal step or as a separate subagent dispatch:

```
CONSISTENCY CHECK (before MPA-Challenge):
  1. Extract all US-NNN IDs from spec -> expected_stories
  2. Extract all US-NNN references from ACs -> referenced_stories
  3. VERIFY: referenced_stories is subset of expected_stories
  4. Extract all NFR constraints -> nfr_list
  5. VERIFY: each NFR references at least one US or system-wide scope
  6. Extract problem statement keywords -> problem_terms
  7. VERIFY: at least 60% of problem_terms appear in US titles or descriptions
  IF violations found: log and feed back to BA for correction BEFORE MPA-Challenge
```

This is a Reflexion-style pattern where the output is verified against structural invariants before proceeding to external review.

---

### Finding 6: Severity Boost Logic Is Under-Specified for Edge Cases

**Severity:** MEDIUM
**Category:** Decision framework clarity
**File:** `references/stage-4-clarification.md` (lines 200-211)

**Current state:** The severity boost rule is:

```
2+ CLIs identify same edge case -> boost severity (MEDIUM->HIGH)
3/3 CLIs identify -> boost severity (HIGH->CRITICAL)
```

This raises several unaddressed questions:
- What if a finding is already CRITICAL and 3/3 agree? (No further boost possible -- is this intentional?)
- What if 2 CLIs agree but at different severity levels (one says MEDIUM, one says HIGH)? Which is the base for boosting?
- What constitutes "same edge case" for agreement detection? (Same as Finding 3 -- no semantic matching protocol)
- The boost is one-directional (up only). Should disagreement ever lower severity? (e.g., 1 CLI says CRITICAL but 2 say LOW)

**Recommendation:** Formalize the boost logic as a decision table:

```
| Agreement | Base Severity | Boosted Severity |
|-----------|---------------|------------------|
| 2/3 agree | LOW           | MEDIUM           |
| 2/3 agree | MEDIUM        | HIGH             |
| 2/3 agree | HIGH          | CRITICAL         |
| 2/3 agree | CRITICAL      | CRITICAL (cap)   |
| 3/3 agree | LOW           | HIGH             |
| 3/3 agree | MEDIUM        | CRITICAL         |
| 3/3 agree | HIGH+         | CRITICAL (cap)   |
| Base severity conflict | Take MAX of individual severities, then apply boost |
```

Also define the semantic matching criteria for "same edge case" (reusable across all synthesis points per Finding 3).

---

### Finding 7: Coordinator Crash Recovery Reasoning Is Incomplete

**Severity:** MEDIUM
**Category:** Missing verification / ReAct interleaving
**File:** `references/orchestrator-loop.md` (lines 369-381)

**Current state:** Crash recovery is described at a high level: "If summary file missing for stage N, check for artifacts. If found, reconstruct minimal summary. If not, ask user to retry or skip." The full procedures are deferred to `recovery-migration.md` (not reviewed in detail), but the orchestrator loop itself lacks a reasoning chain for the critical decision of whether artifacts are "sufficiently complete" to reconstruct from.

For example, if Stage 4 crashes after writing `clarification-questions.md` but before writing the summary, the orchestrator needs to determine: Was the file fully generated or partially written? Are the questions valid or corrupt? Should the user be notified that the file may be incomplete?

**Recommendation:** Add a ReAct-style verification sequence to the crash recovery path:

```
ON CRASH DETECTED (no summary for stage N):
  OBSERVE: List all artifacts in specs/{FEATURE_DIR}/ matching stage N's artifact list
  REASON: For each artifact found:
    - Check file size > 0 (not empty)
    - Check YAML frontmatter is parseable (not truncated)
    - Check for stage-specific completeness markers (e.g., clarification-questions.md should have both "Auto-Resolved" and "Requires Your Input" sections)
  ACT: Based on completeness assessment:
    - All artifacts complete + valid: reconstruct summary, mark stage completed
    - Some artifacts incomplete: reconstruct partial summary, re-dispatch stage with ENTRY_TYPE = "crash_recovery"
    - No valid artifacts: treat as fresh start for this stage
  OBSERVE: Verify reconstructed summary passes schema validation
```

---

### Finding 8: RTM Disposition Gate Has Contradictory Blocking Semantics

**Severity:** MEDIUM
**Category:** Circular logic / Reasoning anti-pattern
**File:** `SKILL.md` (line 55, Rule 28), `references/orchestrator-loop.md` (lines 260-273)

**Current state:** SKILL.md Rule 28 states: "Zero UNMAPPED requirements before proceeding past Stage 4. Every source requirement must have a conscious disposition." However, the orchestrator loop (lines 260-273) explicitly makes the RTM quality check after Stage 4 **non-blocking**:

```
NOTE: This check is intentionally NON-BLOCKING (notification only, does not halt).
```

The rationale given is that blocking again would "create an infinite loop" because the user already had a chance to resolve dispositions in Stage 4. But this contradicts Rule 28's "Zero UNMAPPED" gate. The resolution is buried in a paragraph-long NOTE comment rather than being a first-class decision in the reasoning chain.

This creates a reasoning ambiguity: is the RTM disposition a hard gate or a soft warning? The answer depends on where in the flow you are (Stage 4's Step 4.0a = blocking; orchestrator post-Stage-4 = non-blocking), but this nuance is not surfaced in SKILL.md's critical rules.

**Recommendation:**
1. Clarify Rule 28 to reflect the actual two-tier enforcement: "Zero UNMAPPED requirements before **completing** Stage 4 (Step 4.0a is blocking). Any remaining UNMAPPED after Stage 4 are reported in Stage 7 (non-blocking)."
2. Move the infinite-loop prevention rationale from an inline NOTE to a dedicated "RTM Gate Rationale" section in the orchestrator loop, structured as explicit reasoning:

```
RTM GATE REASONING:
  IF blocking at post-Stage-4: user already had disposition opportunity in Step 4.0a
  Blocking again = same questions re-presented = infinite loop risk
  THEREFORE: post-Stage-4 check is WARNING-only, deferred to completion report
  INVARIANT: Step 4.0a remains BLOCKING (first opportunity is always enforced)
```

---

### Finding 9: Quality Gate Thresholds Are Context-Free

**Severity:** LOW
**Category:** Decision framework clarity
**File:** `references/stage-2-spec-draft.md` (lines 192-196)

**Current state:** Gate thresholds are defined as:
- 4 = GREEN
- 3 = YELLOW
- <= 2 = RED

These are numeric thresholds applied identically regardless of feature complexity, domain, or prior context. A simple CRUD feature and a complex real-time collaboration feature would be evaluated against the same 4-point rubric with the same thresholds.

**Recommendation:** This is a minor concern because the gates are intentionally lightweight. However, consider adding a single sentence acknowledging that the thresholds are calibrated for typical features and that domain-specific overrides can be set in config:

```yaml
# In specify-config.yaml:
thresholds:
  gates:
    problem_quality: 3  # default, override per-feature if needed
    true_need: 3
```

This is low severity because the existing thresholds are reasonable defaults, but documenting the override path improves the decision framework.

---

### Finding 10: Semantic Similarity Threshold Is a Magic Number

**Severity:** LOW
**Category:** Assumptions without evidence
**File:** `references/stage-4-clarification.md` (line 352)

**Current state:** The triangulation step uses "semantic deduplication against existing questions (similarity threshold: 0.85)" but does not define:
- What similarity metric is used (cosine similarity? LLM-judged? keyword overlap?)
- Why 0.85 was chosen (no justification or calibration data)
- How the coordinator should compute this (no implementation guidance)

Since this runs inside a coordinator subagent (an LLM), "0.85 similarity" is likely interpreted as a rough guideline rather than a computed metric, making it effectively decorative.

**Recommendation:** Either:
(a) Remove the specific threshold and replace with qualitative guidance: "Discard questions that ask the same thing in different words. Keep questions that address the same topic but from a meaningfully different angle." This is more honest about what an LLM coordinator will actually do.
(b) If precise deduplication is important, define the computation method explicitly and move the threshold to config.

---

## Strengths

### Strength 1: Excellent Macro-Level Decomposition (Least-to-Most Pattern)

The skill breaks a complex specification problem into 7 well-defined stages with clear boundaries, inputs, outputs, and checkpoints. Each stage is further decomposed into numbered steps. The progression from Setup -> Draft -> Validate -> Clarify -> Evaluate -> Test -> Complete follows a natural Least-to-Most pattern where each stage builds on the outputs of the previous one. The Stage Dispatch Table (SKILL.md lines 143-152) serves as a clear dispatch map that makes the decomposition auditable.

### Strength 2: Robust State Preservation and Resumability

The state management design (schema versioning, immutable user decisions, checkpoint protocol, lock files) demonstrates careful reasoning about failure modes. The IMMUTABLE annotation on `user_decisions` prevents a common reasoning anti-pattern in iterative workflows where previously resolved questions get silently re-opened. The chained migration path (v2->v3->v4->v5) shows forward-thinking decomposition of the state evolution problem.

### Strength 3: Auto-Resolve Protocol Is a Well-Structured Decision Framework

Despite the worked-example gaps noted in Finding 4, the auto-resolve protocol (references/auto-resolve-protocol.md) is one of the strongest reasoning artifacts in the skill. It implements a clear classification taxonomy (AUTO_RESOLVED / INFERRED / REQUIRES_USER), explicit exclusion rules for subjective questions, mandatory citation requirements, and user override capability. This is a textbook Chain-of-Thought scaffold -- the protocol makes the reasoning chain explicit even if it could benefit from more examples.

### Strength 4: Multi-Perspective Analysis Addresses Confirmation Bias

The CLI dispatch pattern (Codex for technical depth, Gemini for coverage breadth, OpenCode for contrarian perspective) is a deliberate application of self-consistency through diversity. By dispatching three different models with three different analytical roles, the skill avoids the single-model confirmation bias that would occur if one agent both drafted and reviewed the spec. The severity boost on cross-model agreement is a principled way to convert agreement into confidence.
