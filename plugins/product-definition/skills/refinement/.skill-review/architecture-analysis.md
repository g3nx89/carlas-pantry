---
skill: feature-refinement
version: 3.0.0
lens: architecture-coordination-quality
analyst: claude-opus-4-6
date: 2026-03-01
criteria_source: skill (sadd:multi-agent-patterns)
files_analyzed:
  - skills/refinement/SKILL.md
  - skills/refinement/references/orchestrator-loop.md
  - skills/refinement/references/error-handling.md
  - skills/refinement/references/stage-3-analysis-questions.md
  - skills/refinement/references/consensus-call-pattern.md
  - skills/refinement/references/panel-builder-protocol.md
  - skills/refinement/references/stage-5-validation-generation.md
finding_counts:
  critical: 0
  high: 2
  medium: 4
  low: 2
  info: 0
strengths: 3
---

# Architecture & Coordination Quality Analysis: feature-refinement v3.0.0

## Summary

The feature-refinement skill implements a supervisor/orchestrator pattern with 6 stages, delegating stages 2-6 to coordinator subagents via `Task(general-purpose)` while running Stage 1 inline. The architecture is well-suited for the iterative, multi-round nature of PRD generation: file-based communication avoids context bloat, the orchestrator maintains clear control flow, and graceful degradation handles MCP unavailability. The dynamic MPA panel system (v3.0.0) is a strong design choice that enables domain-specialized question generation without hardcoding agent definitions.

Two high-severity findings relate to supervisor context accumulation risk during the ThinkDeep-heavy Stage 3 and a lack of inter-stage output validation beyond self-verification. Four medium findings address consensus sycophancy mitigation gaps, an over-serialized ThinkDeep execution model, coordinator-to-coordinator information coupling, and the absence of timeout/circuit-breaker mechanisms at the coordinator dispatch level. Overall, the architecture is sound and demonstrates mature multi-agent design patterns with clearly documented contracts, but specific bottleneck and validation gaps warrant attention.

---

## Findings

### HIGH Severity

#### H1: Supervisor Context Accumulation in Stage 3 Coordinator

**Category:** Bottleneck Risk / Context Isolation Failure

**Current State:** The Stage 3 coordinator is responsible for (a) executing up to 27 ThinkDeep calls across 3 perspectives x 3 models x 3 steps, (b) synthesizing ThinkDeep insights into a file, (c) dispatching 2-5 MPA panel member agents in parallel, and (d) dispatching the synthesis agent. Each ThinkDeep call returns analysis content that the coordinator must process before moving to the next step in the chain. By the time Part B (MPA dispatch) begins, the coordinator's context contains the accumulated outputs of all ThinkDeep chains plus the synthesized insights file, plus the draft content, plus the stage reference file, plus error handling references. In Complete mode, this is the single densest context window in the entire workflow.

The coordinator acts as a supervisor that accumulates context from 27 ThinkDeep responses before dispatching MPA agents. This directly contradicts the sadd:multi-agent-patterns guidance that "supervisor context becomes bottleneck" and "implement output constraints so workers return only distilled summaries." While the ThinkDeep insights ARE written to a file, the coordinator still holds all raw responses in its context window during synthesis.

**Recommendation:** Split Stage 3 into two sub-coordinators: (1) a ThinkDeep coordinator that executes all PAL calls and writes `thinkdeep-insights.md`, and (2) an MPA coordinator that reads only the synthesized insights file and dispatches panel members. The orchestrator dispatches them sequentially. This keeps each coordinator's context lean and isolates ThinkDeep failures from MPA dispatch. The orchestrator already has the machinery for sequential stage dispatch; adding a sub-stage split (3A -> 3B) is a minimal structural change.

**File:** `references/stage-3-analysis-questions.md` (lines 22-232 for ThinkDeep, lines 238-451 for MPA)

---

#### H2: No Inter-Stage Output Validation by Orchestrator Beyond Quality Gates

**Category:** Output Validation Between Components

**Current State:** Each coordinator performs self-verification before writing its summary (e.g., Stage 3 checks question count >= 5, options >= 3). The orchestrator performs "lightweight quality checks" after Stage 3 (section coverage, option distinctness) and after Stage 5 (section completeness, technical filter). However, these quality gates are explicitly **non-blocking** -- they log warnings but never halt progression.

The critical gap is that no component validates the *structural integrity* of a stage's output before the next stage consumes it. For example, Stage 4 assumes `QUESTIONS-{NNN}.md` has a specific checkbox format that it will parse. If Stage 3's synthesis agent produces a malformed file (wrong format, missing checkboxes, truncated output), Stage 4 will silently produce incorrect gap analysis. The summary schema validation (orchestrator-loop.md lines 138-160) validates the *summary* YAML structure, but not the *artifact* structure.

**Recommendation:** Add blocking structural validation for critical handoff artifacts:
1. After Stage 3: Validate that `QUESTIONS-{NNN}.md` matches the expected format (checkbox syntax, option blocks, priority tags). A simple regex-based check in the orchestrator before dispatching Stage 4.
2. After Stage 5 (PRD generation): Validate that `PRD.md` has all required section headings from config before dispatching Stage 6.

These should be blocking (not warnings) because downstream stages parse these artifacts structurally. Keep the existing non-blocking quality gates for content-level issues (option distinctness, technical keywords).

**File:** `references/orchestrator-loop.md` (lines 138-248, Quality Gate Protocol)

---

### MEDIUM Severity

#### M1: Consensus Unanimity Check Is Insufficient Sycophancy Mitigation

**Category:** Consensus Problem / Sycophancy Risk

**Current State:** The `consensus-call-pattern.md` includes a "Unanimity Check" (lines 73-82) that logs a warning when all models agree without dissent. This is the sole anti-sycophancy measure. However, the check fires only on *complete unanimity* and only adds a non-blocking log note. It does not:
- Detect *partial sycophancy* where models align on most dimensions but one model slightly defers to the framing of a prior model's response in the continuation chain
- Trigger any corrective action (e.g., re-run with adversarial framing)
- Detect when the "against" stance (grok-4) agrees with the "for" stance (gpt-5.2), which is a stronger sycophancy signal than all-neutral agreement

The sadd:multi-agent-patterns material explicitly warns that "without intervention, multi-agent discussions can devolve into consensus on false premises" and recommends debate protocols with adversarial critique.

**Recommendation:** Strengthen the unanimity check:
1. Add a *stance violation* detector: if the "against" model's score is within 1 point of the "for" model's score on all dimensions, flag as potential sycophancy (the against stance should naturally produce lower scores if it is genuinely adversarial).
2. When sycophancy is detected, append a note to the validation output recommending the user review the specific dimensions where all models agreed, rather than just logging silently.
3. Consider adding a "challenge round" consensus step where the coordinator explicitly asks models to critique the emerging consensus before final synthesis.

**File:** `references/consensus-call-pattern.md` (lines 73-82)

---

#### M2: ThinkDeep Execution Is Fully Sequential Within Each Perspective-Model Chain

**Category:** Bottleneck Risk / Serial Dependencies

**Current State:** ThinkDeep execution in Stage 3 runs 3 perspectives x 3 models x 3 steps = 27 calls. Each 3-step chain within a perspective-model combination is necessarily sequential (continuation_id threading). However, the stage reference file implies that different perspective-model combinations could run in parallel ("Each perspective x model combination gets its OWN continuation_id thread"), yet the execution pseudocode uses nested `FOR` loops without indicating parallelism:

```
FOR each perspective in [COMPETITIVE, RISK, CONTRARIAN]:
  FOR each model in config -> pal.thinkdeep.models[].id:
    # 3 sequential steps
```

This sequential execution of 9 independent chains means the ThinkDeep phase takes 9x the latency of a single chain, when it could theoretically take only 3x (parallelize across 9 chains, each 3 steps deep). In Complete mode, this is the single largest latency contributor.

**Recommendation:** Explicitly mark the outer loops as parallelizable. Each perspective-model combination is independent (separate continuation_id threads). Dispatch all 9 initial steps in parallel, then batch the step-2 calls as their step-1 results return, etc. Add a note in stage-3-analysis-questions.md clarifying that the `FOR` loops represent logical grouping, not execution order, and that implementations SHOULD parallelize across chains.

**File:** `references/stage-3-analysis-questions.md` (lines 62-116)

---

#### M3: Stage 4 and Stage 5 Have Implicit Coupling Through Artifact Format

**Category:** Information Flow / Implicit Contracts

**Current State:** Stage 4 (Response & Gaps) reads and parses `QUESTIONS-{NNN}.md` to extract user answers. Stage 5 reads the same file plus the gap analysis output from Stage 4. The format of these artifacts is defined in `option-generation-reference.md` (referenced but not loaded in this analysis). However, the coupling is implicit:
- Stage 3 writes questions in a format defined in its reference
- Stage 4 parses that format based on its own reference
- Stage 5 consumes Stage 4's output format

There is no shared schema definition that all three stages reference. If the question format changes in Stage 3's reference, Stage 4's parsing logic must be updated independently. The summary contract (SKILL.md lines 166-248) governs stage-to-stage summary metadata, but not artifact content schemas.

**Recommendation:** Create a shared `references/artifact-schemas.md` file that defines the canonical format for:
1. `QUESTIONS-{NNN}.md` structure (sections, checkbox format, option blocks, priority tags)
2. `response-validation-round-{N}.md` structure (gap format, completion metrics)

All three stages should reference this shared schema rather than independently defining format expectations. This follows the cross-plugin artifact contract pattern from CLAUDE.md: "Externalize handoff contracts to config."

**File:** `SKILL.md` (Output Artifacts table, line 326) and `references/stage-3-analysis-questions.md`, `references/stage-4-response-analysis.md`, `references/stage-5-validation-generation.md`

---

#### M4: No Coordinator Dispatch Timeout or Liveness Check

**Category:** Failure Propagation / Recovery Gap

**Current State:** The orchestrator dispatches coordinators via `Task(general-purpose)` and waits for them to return with a summary file. The crash recovery mechanism (referenced in `recovery-migration.md`) handles the case where a coordinator produces *no summary file* -- it checks for artifacts and reconstructs a minimal summary. However, there is no mechanism to detect a *hung* coordinator (one that is still running but making no progress, e.g., stuck in an infinite retry loop with PAL, or waiting indefinitely for an MCP response).

The `limits.max_rounds` circuit breaker (100 rounds) protects against infinite iteration loops at the orchestrator level, but not against individual coordinator hangs. A single Stage 3 coordinator in Complete mode executing 27 ThinkDeep calls with retries could consume significant time and tokens with no liveness signal.

**Recommendation:** Add coordinator-level timeout guidance:
1. In the dispatch template, include a `max_duration_hint` variable (from config, e.g., `token_budgets.stage_dispatch_profiles.{stage}.timeout_minutes`) that coordinators should respect as a self-imposed deadline.
2. Add guidance in `error-handling.md` for coordinators to emit partial results and a `status: failed` summary with `flags.partial_results: true` if they exceed the timeout, rather than continuing indefinitely.
3. Document in `orchestrator-loop.md` that if a coordinator dispatch exceeds the timeout, the orchestrator should check for partial artifacts before treating it as a crash.

**File:** `references/orchestrator-loop.md` (Coordinator Dispatch, lines 38-106) and `references/error-handling.md`

---

### LOW Severity

#### L1: Panel Builder Is a Subagent Within Inline Stage 1

**Category:** Architecture Simplification Opportunity

**Current State:** Stage 1 runs inline (not coordinator-delegated), per Rule 23. Within Stage 1, the Panel Builder is dispatched as a subagent (`requirements-panel-builder` agent). This means the orchestrator itself dispatches a subagent during its inline execution phase, creating a mixed pattern: Stage 1 is "inline" but still uses Task dispatch for the panel builder. This is architecturally inconsistent with the stated pattern that "Stage 1 runs inline" -- it partially delegates.

The Panel Builder also writes a summary file (`panel-builder-summary.md`) with `status: needs-user-input`, which the orchestrator must then handle with `AskUserQuestion`. This is coordinator behavior embedded within an inline stage.

**Recommendation:** This is a minor inconsistency, not a functional issue. Two options: (a) acknowledge in SKILL.md that Stage 1 is "mostly inline with one subagent dispatch for panel building," or (b) promote panel building to a mini-stage (Stage 1.5) that follows the coordinator pattern. Option (a) is simpler and sufficient -- just document the exception to avoid confusion for future contributors.

**File:** `SKILL.md` (lines 157-163, Stage 1 inline execution) and `references/panel-builder-protocol.md`

---

#### L2: Reflection Context Generation Has No Size Bound

**Category:** Context Management

**Current State:** When Stage 5 validation returns RED, the orchestrator generates `REFLECTION_CONTEXT` from Stage 4 and Stage 5 summaries (orchestrator-loop.md lines 281-315). This reflection is passed as a variable in the Stage 3 coordinator dispatch prompt. The template includes gap descriptions, dimension scores, cross-round gap intersections, and areas with vague answers -- but there is no maximum size constraint on this content.

After multiple RED loops, persistent gaps accumulate. While the reflection template has a defined structure, the variable-length fields (`gap_descriptions`, `unresolved from decomposition`, `areas where user chose 'Other'`) could grow unboundedly if the same gaps persist across many rounds.

**Recommendation:** Add a token budget for `REFLECTION_CONTEXT` in the config (e.g., `token_budgets.reflection_context_max_lines: 50`). If the reflection exceeds this limit, prioritize: (1) weak dimensions, (2) persistent gaps (appeared 2+ rounds), (3) new gaps from latest round. Truncate lower-priority content. This aligns with the repository convention of defining token budgets in config for all injected content.

**File:** `references/orchestrator-loop.md` (lines 281-315, REFLEXION STEP)

---

## Strengths

### S1: File-Based Communication with Explicit Summary Contracts

The architecture uses file-based communication as the primary inter-stage coordination mechanism (stage summaries, artifact files, state file). Each coordinator writes to well-defined paths with YAML frontmatter following a documented summary contract (SKILL.md lines 166-248). The orchestrator never needs to parse coordinator return values or hold multi-stage context -- it reads structured files. This is textbook application of the "files as shared memory" pattern from sadd:multi-agent-patterns, providing transparency, debuggability, and crash recovery. The summary schema validation step (orchestrator-loop.md lines 138-160) adds a layer of structural verification that many multi-agent systems lack entirely.

### S2: Dynamic Panel Composition with Domain-Aware Specialization

The v3.0.0 MPA panel system avoids the common anti-pattern of hardcoded specialist agents. Instead, a single parametric template (`requirements-panel-member.md`) is instantiated with variables from a runtime-composed panel configuration. The Panel Builder agent detects the product domain from draft signals and proposes a panel preset, which the user validates. This means the system adapts its specialist composition to the problem domain (marketplace vs enterprise vs consumer) without requiring new agent files. The weight distribution rules, validation checks, and fallback to default preset on builder failure demonstrate mature design thinking about the specialization-complexity tradeoff.

### S3: Graceful Degradation Hierarchy with Explicit Mode Constraints

The analysis mode hierarchy (Complete -> Advanced -> Standard -> Rapid) provides clean degradation when MCP tools are unavailable. Each mode has explicit constraints on which tools it uses (PAL ThinkDeep, Sequential Thinking, Consensus), and the system automatically restricts available modes based on MCP detection in Stage 1. This is not just error handling -- it is an architectural decision that the system works meaningfully at every capability tier. The fallback from Panel Builder failure to default preset (error-handling.md lines 144-156) and from research MCP failure to manual research (non-blocking) demonstrate consistent application of the "never block the workflow for optional features" principle.
