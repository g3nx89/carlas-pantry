---
analysis_type: reasoning-quality
skill: feature-refinement
skill_version: 3.0.0
analyst_model: claude-opus-4-6
date: 2026-03-01
evaluation_criteria: fallback (skill invocation failed)
files_analyzed:
  - skills/refinement/SKILL.md
  - skills/refinement/references/orchestrator-loop.md
  - skills/refinement/references/stage-3-analysis-questions.md
  - skills/refinement/references/stage-5-validation-generation.md
  - skills/refinement/references/error-handling.md
  - skills/refinement/references/stage-4-response-analysis.md
finding_count:
  critical: 1
  high: 3
  medium: 3
  low: 2
  info: 0
strength_count: 4
---

# Reasoning & Decomposition Quality Analysis: feature-refinement

## Summary

The feature-refinement skill (v3.0.0) demonstrates a sophisticated multi-stage workflow with several well-chosen reasoning patterns, including Least-to-Most decomposition, Reflexion-style feedback loops, and multi-perspective analysis (MPA). However, the analysis reveals gaps in how reasoning chains are made explicit at critical decision points, missing termination criteria for iterative loops, and areas where implicit judgment replaces structured decision frameworks. The skill's strongest reasoning contributions are its Section Decomposition pattern (Step 3B.2) and its Reflexion loop between Stages 3-5, though both have notable improvement opportunities.

---

## Findings

### CRITICAL

#### F-01: Unbounded Iteration Loop with Effectively Unreachable Circuit Breaker

**Severity:** CRITICAL
**Category:** Missing Termination Criteria / Anti-pattern

**Current state:** The iteration loop between Stages 3, 4, and 5 has no meaningful convergence criteria beyond the circuit breaker at `max_rounds: 100`. The loop continues as long as Stage 5 validation scores RED (`< conditional` threshold), but there is no mechanism to detect stagnation -- rounds that produce no improvement in validation scores. A RED validation always generates REFLECTION_CONTEXT and re-dispatches Stage 3, but nothing ensures the reflection produces meaningfully different questions. The circuit breaker at 100 rounds is a nominal safeguard but is practically unreachable in interactive use; by round 5-10, the actual failure mode is user abandonment, not a controlled exit.

Additionally, the "gap analysis" in Stage 4 that determines `next_action` relies on implicit coordinator judgment ("If significant gaps remain" vs "If gaps are minimal") without quantified thresholds for what constitutes "significant." This means the decision to loop vs proceed is opaque and non-reproducible.

**Recommendation:**
1. Add a **stagnation detector** in `orchestrator-loop.md`: if `validation_score` has not improved by at least N points (configurable) over the last 2 consecutive RED rounds, present the user with an explicit "stagnation detected" decision rather than silently looping. This is a Reflexion best practice -- reflect on *whether reflection itself is working*.
2. Reduce the circuit breaker to a practical value (e.g., 10 rounds) or replace it with the stagnation detector entirely.
3. Define quantified gap significance thresholds in Stage 4 Step 4.7: e.g., "significant gaps = more than 2 PRD sections with MISSING status OR any CRITICAL-priority gap unresolved." Move this from implicit judgment to an explicit decision tree.

**File:** `references/orchestrator-loop.md` (lines 278-320), `references/stage-4-response-analysis.md` (lines 168-191)

---

### HIGH

#### F-02: Validation Scoring Protocol Lacks Explicit Reasoning Chain (CoT Gap)

**Severity:** HIGH
**Category:** Implicit Reasoning Leap

**Current state:** Stage 5 validation (Step 5.2) asks the consensus models to score 7 dimensions on a 1-4 scale with `SCORING PROTOCOL (MANDATORY -- evidence before score)`. This is a good start toward Chain-of-Thought enforcement. However, the protocol only applies to the PAL Consensus path. When "Single model / Internal validation" is selected (Step 5.2), the instruction is a single sentence: "Perform internal evaluation using the same 7 dimensions. Score 1-4 each." There is no CoT enforcement, no evidence requirement, and no structured reasoning template. Given that internal validation is the fallback for the most common case (PAL unavailable), this path handles potentially the majority of executions with the weakest reasoning discipline.

Furthermore, even in the Consensus path, the scoring anchors (what distinguishes a score of 2 from 3 for each dimension) are undefined. The prompt says "score 1-4" but never defines what each score level means per dimension. This invites rubber-stamping -- models tend to cluster around 2-3 without calibrated anchors.

**Recommendation:**
1. Add a structured CoT template for the internal validation path that mirrors the Consensus path's `SCORING PROTOCOL` section, requiring per-dimension evidence citation before scoring.
2. Define scoring anchors for each dimension. Example: "Product Definition: 1=no vision stated, 2=vision stated but unbounded, 3=vision with Is/IsNot boundaries, 4=vision with boundaries and measurable success criteria."
3. Consider a Self-Consistency check: run internal validation twice with different temperature/prompt framings and flag dimensions where scores diverge by 2+.

**File:** `references/stage-5-validation-generation.md` (lines 108-109, 86-103)

---

#### F-03: Reflexion Context Generation Has No Structured Diff Against Prior Reflections

**Severity:** HIGH
**Category:** Reasoning Anti-pattern (Circular Reflection)

**Current state:** When Stage 5 returns RED, the orchestrator generates REFLECTION_CONTEXT (orchestrator-loop.md lines 282-307) by reading the current round's Stage 4 and 5 summaries. The reflection template includes "What We Tried," "Why It Wasn't Enough," and "What To Do Differently." However, there is no mechanism to compare the *current* reflection against *prior* reflections. If round 2 and round 3 both return RED for the same weak dimensions, the round 3 reflection may generate nearly identical guidance to round 2 -- "focus on workflow_coverage" -- without acknowledging that the previous round already tried this and it was insufficient.

The Persistent Gap Tracker in the Rounds-Digest Template (orchestrator-loop.md lines 386-395) tracks cross-round gap persistence, but this data is only included in the digest (generated after round 3+). For rounds 2-3, no cross-round comparison occurs. Even when the digest exists, the REFLECTION_CONTEXT template includes `{cross-round gap intersection}` as a variable but nothing ensures the orchestrator actually computes this intersection.

**Recommendation:**
1. Add an explicit diff step in REFLECTION_CONTEXT generation: "Read prior reflection files (requirements/.stage-summaries/reflection-round-{N-1}.md). For each item in 'What To Do Differently,' check if the current round addressed it and whether the dimension score improved. Report: addressed-and-improved, addressed-but-no-improvement, not-addressed."
2. When a gap persists across 2+ rounds with no score improvement, escalate the reflection guidance: suggest a *different approach* (e.g., switch analysis mode, suggest user research on the specific topic) rather than repeating "focus on X."
3. Ensure `{cross-round gap intersection}` is computed from state data (not just the digest), so it works in rounds 2-3 before the digest is generated.

**File:** `references/orchestrator-loop.md` (lines 278-320)

---

#### F-04: Stage 4 Gap Analysis Decision Framework is Entirely Implicit

**Severity:** HIGH
**Category:** Decision Point Without Structured Criteria

**Current state:** Stage 4 Step 4.7 determines the most consequential routing decision in the entire workflow: whether to loop back for more questions, loop back for research, or proceed to PRD generation. The decision criteria are stated as: "If significant gaps remain" -> present options, "If gaps are minimal" -> proceed. There are no quantified definitions of "significant" or "minimal." The `gap_descriptions` in the summary contract are free-text strings with no severity or confidence tagging. This means the same objective state could route to "proceed" or "loop_questions" depending on how the coordinator subjectively interprets "significant."

Furthermore, when the user is presented with the interactive choice, the option descriptions provide no reasoning support: "Another round focusing on gaps" gives the user no information about *what* the gaps are or how many rounds might be needed. The gap descriptions exist in `flags.gap_descriptions` but are not surfaced in the `question_context.question` text.

**Recommendation:**
1. Define explicit gap significance criteria in config (e.g., `gap_analysis.significant_threshold: { missing_sections: 2, critical_gaps: 1, ambiguous_answers: 3 }`).
2. Add a scoring rubric to Step 4.7: count MISSING sections, CRITICAL-priority unresolved gaps, and contradictions. Map counts to a recommendation (proceed/loop).
3. Surface gap details in the user-facing interactive question: "Gap analysis found 3 areas: Revenue Model (MISSING), Target Users (AMBIGUOUS), Workflows (PARTIAL). How to proceed?"
4. Tag each gap in `gap_descriptions` with a severity (CRITICAL/HIGH/MEDIUM) to enable downstream reasoning (e.g., REFLECTION_CONTEXT can prioritize CRITICAL gaps).

**File:** `references/stage-4-response-analysis.md` (lines 168-191)

---

### MEDIUM

#### F-05: ThinkDeep Chain Lacks Explicit Reasoning Verification Between Steps

**Severity:** MEDIUM
**Category:** Missing Self-Correction (Reflexion Gap)

**Current state:** Stage 3 Part A executes ThinkDeep as a 3-step chain per perspective/model combination. Step 2 is "Deepen analysis based on step 1 findings" and Step 3 is "Validate and synthesize." However, between steps, there is no verification that the model's reasoning is progressing rather than repeating. The `confidence` parameter progresses from "exploring" to "low" to "high," but this is a cosmetic signal -- the model may still repeat the same analysis with higher stated confidence.

The `findings` parameter for Step 2 instructs "[Key discoveries from step 1]" but does not require the coordinator to *evaluate* whether Step 1 produced useful discoveries. If Step 1 returns generic platitudes, Step 2 feeds those platitudes back with no correction.

**Recommendation:**
1. Add a lightweight quality check between steps: after Step 1, the coordinator should check if the response contains at least 2 specific, non-generic findings (e.g., named competitors, quantified risks). If not, log a warning and consider skipping remaining steps for that chain.
2. For Step 3 ("Validate and synthesize"), add an explicit instruction: "Identify any claims from Steps 1-2 that lack supporting evidence. Flag unsupported claims rather than synthesizing them as validated."
3. Consider adding a `contradictions_found` field to the ThinkDeep synthesis (Step 3A.3) that specifically tracks where multi-step chains within the same perspective contradicted themselves.

**File:** `references/stage-3-analysis-questions.md` (lines 62-116)

---

#### F-06: Self-Verification Checklists Are Existence-Only, Not Reasoning-Quality Checks

**Severity:** MEDIUM
**Category:** Verification Depth

**Current state:** Every stage includes a "Self-Verification (MANDATORY before writing summary)" section. These checklists verify structural correctness: file existence, non-empty content, placeholder removal, field presence. For example, Stage 3's checklist verifies "At least 5 questions generated" and "Each question has 3+ options with pros/cons." Stage 5 verifies "PRD does NOT contain any forbidden technical keywords."

None of these checklists verify *reasoning quality* of the output. A Stage 3 coordinator could generate 10 questions that all ask minor variations of the same thing, all targeting the same PRD section, and pass self-verification. A Stage 5 coordinator could produce a PRD with all sections present but internally contradictory, and pass self-verification.

**Recommendation:**
1. Add at least one reasoning-quality check per stage's self-verification. Examples:
   - Stage 3: "No two questions target the exact same sub-problem from the Section Decomposition."
   - Stage 4: "gap_descriptions include at least one actionable resolution path per gap."
   - Stage 5: "Per-dimension scores differ by at least 1 point across dimensions (no flat-line scoring)."
2. Frame these as non-blocking warnings rather than hard failures, consistent with the existing Quality Gate Protocol design.

**File:** `SKILL.md` (general pattern), `references/stage-3-analysis-questions.md` (lines 516-522), `references/stage-5-validation-generation.md` (lines 228-237)

---

#### F-07: Consensus Call Pattern Uses Fixed Stance Assignment Without Reasoning Justification

**Severity:** MEDIUM
**Category:** Reasoning Methodology Selection

**Current state:** The PAL Consensus pattern (referenced in Stages 4 and 5) uses three fixed stances: Neutral, For, Against. The stance prompts are hardcoded per stage (e.g., Stage 5 Neutral = "Objective assessment of readiness against all 7 dimensions," For = "Advocate for proceeding where reasonable," Against = "Find contradictions, gaps, ambiguities. Be skeptical of completeness.").

This is a form of structured debate, which is a valid reasoning pattern. However, the synthesis step that produces the final score is not documented in the stage files. After the 3 stances report, how are their scores reconciled? If Neutral says 14/20, For says 18/20, and Against says 9/20, what is the final score? The skill references `consensus-call-pattern.md` for the shared workflow but does not describe the aggregation logic in either stage file. This is an implicit reasoning leap at the most critical decision point in the workflow.

**Recommendation:**
1. Document the score aggregation logic explicitly in Stage 5: e.g., "Final score = median of 3 stance scores" or "Final score = weighted average (Neutral 50%, For 25%, Against 25%)" or "Use the consensus model's synthesis as final."
2. Add a divergence flag: if stance scores differ by more than 6 points (out of 20), flag for user review rather than auto-aggregating.
3. Consider reading `consensus-call-pattern.md` to verify this is covered there; if so, add a cross-reference note in Stage 5 explicitly stating where aggregation logic lives.

**File:** `references/stage-5-validation-generation.md` (lines 56-106), `references/stage-4-response-analysis.md` (lines 114-159)

---

### LOW

#### F-08: Section Decomposition is Static and Does Not Adapt to Draft Content

**Severity:** LOW
**Category:** Decomposition Rigidity (Least-to-Most)

**Current state:** Step 3B.2 provides a fixed decomposition of PRD sections into sub-problems (e.g., "Target Users" -> 1. Primary persona, 2. Secondary personas, 3. Anti-personas). This decomposition is the same regardless of draft content. A draft that already contains detailed persona descriptions would still decompose Target Users into the same 3 sub-problems, potentially generating redundant questions.

The EXTEND mode check ("Only decompose sections with PARTIAL or MISSING status") addresses this at the section level, but not at the sub-problem level. A section could be PARTIAL because sub-problem 3 (anti-personas) is missing while sub-problems 1-2 are complete, yet all 3 sub-problems would be decomposed.

**Recommendation:**
1. In EXTEND mode, add sub-problem-level status assessment: for each sub-problem, check if the existing PRD content or prior answers already address it. Mark as COVERED/PARTIAL/MISSING.
2. Pass sub-problem statuses to MPA agents so they can skip or reduce emphasis on COVERED sub-problems.
3. This is low severity because the synthesis agent (Step 3B.4) is expected to deduplicate, but pre-filtering would improve question relevance.

**File:** `references/stage-3-analysis-questions.md` (lines 248-299)

---

#### F-09: Variable Defaults Table Does Not Cover All Dispatch Variables

**Severity:** LOW
**Category:** Reasoning Completeness

**Current state:** The Variable Defaults table in `orchestrator-loop.md` covers 9 variables. However, the dispatch template also references `{STAGE_FILE}` (no default -- would cause coordinator to read nothing) and the coordinator prompt includes `{PANEL_CONFIG_PATH}` (documented default: null, meaning rapid mode). While `STAGE_FILE` should never be absent (it is selected by the dispatch loop), the absence of a default means a bug in the dispatch loop would silently produce a coordinator with no instructions. Other implicit variables like `{ABSOLUTE_PATH}` used in Stage 4 and 5 consensus `RELEVANT_FILES` have no documented defaults or sourcing instructions.

**Recommendation:**
1. Add `STAGE_FILE` to the defaults table with a note: "No default -- orchestrator bug if absent. Validate non-null before dispatch."
2. Document `ABSOLUTE_PATH` sourcing: "Resolved from `requirements/` directory's absolute path at runtime."
3. Add a pre-dispatch validation step: "Assert all dispatch template variables are non-null before launching coordinator."

**File:** `references/orchestrator-loop.md` (lines 118-134)

---

## Strengths

### S-01: Least-to-Most Decomposition in Section Decomposition (Step 3B.2)

The explicit decomposition of complex PRD sections into sub-problems before dispatching MPA agents is a textbook application of Least-to-Most prompting. By breaking "Target Users" into {primary persona, secondary personas, anti-personas} before agents generate questions, the skill ensures questions target specific, answerable aspects rather than broad, vague section-level prompts. The decomposition also serves as a natural checklist for coverage validation. This is one of the strongest reasoning patterns in the skill.

**File:** `references/stage-3-analysis-questions.md` (lines 245-305)

### S-02: Reflexion Loop with Persisted Reflection Context

The Stage 3-5 iteration loop with REFLECTION_CONTEXT generation is a well-implemented Reflexion pattern. Key design decisions that strengthen it: (1) reflection is generated by the orchestrator (not the coordinator that failed), providing an external perspective; (2) reflection context is persisted to a file (`reflection-round-{N}.md`), enabling crash recovery; (3) the reflection template explicitly separates "What We Tried" from "Why It Wasn't Enough" from "What To Do Differently," forcing structured analysis rather than vague "try harder" instructions. The integration of weak/strong dimension tracking from Stage 5 scores into the reflection is particularly effective at focusing subsequent rounds.

**File:** `references/orchestrator-loop.md` (lines 278-320)

### S-03: Graceful Degradation with Explicit Mode Guards

The skill implements a four-tier analysis mode hierarchy (Complete > Advanced > Standard > Rapid) with explicit mode guards at every step that uses optional tools. Each ThinkDeep, Consensus, and Sequential Thinking usage is gated by both the analysis mode AND tool availability. The fallback behavior is documented per tool (PAL -> limit modes, ST -> internal reasoning, Research MCP -> manual flow). This is a well-structured application of conditional reasoning -- the skill does not assume its most sophisticated reasoning path is always available and has pre-planned degradation paths.

**File:** `SKILL.md` (lines 82-91), `references/error-handling.md` (lines 87-106)

### S-04: Multi-Perspective Analysis with ThinkDeep Cross-Model Divergence Detection

The ThinkDeep synthesis step (3A.3) explicitly distinguishes convergent insights (all models agree) from divergent insights (models disagree) and uses this distinction to drive question priority: convergence -> CRITICAL priority, divergence -> HIGH priority requiring multiple question options. This is a sophisticated application of Self-Consistency -- rather than taking any single model's output as authoritative, the skill uses agreement/disagreement signals as a meta-reasoning layer. The cross-perspective synthesis further enriches this by checking for agreement patterns across the three analytical lenses (competitive, risk, contrarian).

**File:** `references/stage-3-analysis-questions.md` (lines 204-235)
