---
lens: "Architecture & Coordination Quality"
lens_id: "architecture"
skill_reference: "sadd:multi-agent-patterns"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: false
findings_count: 11
critical_count: 1
high_count: 3
medium_count: 4
low_count: 1
info_count: 2
---

# Architecture & Coordination Quality Analysis: design-handoff

## Summary

The design-handoff skill implements a well-structured supervisor/orchestrator pattern with 10 stages (6 functional + 4 judge checkpoints) coordinating 4 specialized agents. The architecture makes strong choices around context isolation (one-screen-per-dispatch), file-based inter-agent communication, and LLM-as-judge quality gates at critical boundaries. The core coordination pattern is appropriate for the task complexity and the constraints of figma-console MCP.

Key architectural strengths include robust crash recovery via step-level state tracking, graceful degradation from TIER downgrades and per-screen blocking, and explicit variable sourcing tables that eliminate ambiguity in agent dispatch. The main risks center on supervisor context accumulation across the screen loop, a single-threaded serial pipeline with no parallelism opportunities exploited, and a state file that serves as both coordination bus and crash recovery store without concurrency protection beyond a simple lock file.

11 findings identified: 1 CRITICAL, 3 HIGH, 4 MEDIUM, 1 LOW, 2 INFO.

---

## Findings

### Finding 1: State File as Single Point of Failure with Concurrent Write Risk

**Severity:** CRITICAL
**Category:** Failure Propagation and Recovery
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/state-schema.md`

**Current state:** The state file `.handoff-state.local.md` serves as the sole coordination bus between the orchestrator and all dispatched agents. Both the orchestrator and the dispatched agent write to the same file. The figma-preparation reference (lines 153-180) shows the orchestrator writing `screen.status = "preparing"` before dispatch, then the agent writes step-level progress during execution, and the orchestrator reads back after dispatch. The lock protocol (state-schema.md lines 179-186) only guards against concurrent *workflow* runs, not concurrent writes between orchestrator and agent within the same run.

In Claude Code's `Task` dispatch model, the subagent runs to completion before control returns to the orchestrator, so concurrent writes should not occur under normal execution. However, the architecture documents no explicit contract about this. If the dispatch model ever changes (e.g., parallel screen processing is attempted for performance), the state file becomes a race condition vector.

More critically, the state file uses YAML frontmatter in a markdown file. YAML frontmatter is not append-safe -- any write to the frontmatter must rewrite the entire YAML block. If a crash occurs mid-write (between reading and writing state), the file could be left in an inconsistent or corrupted state, with no checksumming or journaling to detect this.

**Recommendation:**
1. Add a state integrity check at the top of the resume protocol: compute a simple hash of the YAML block and store it as a `_checksum` field. On resume, verify the checksum before trusting the state. If corrupted, fall back to reconstructing state from artifact existence (screenshots, manifest, etc.).
2. Add an explicit architectural constraint in SKILL.md: "State file writes are SINGLE-WRITER. Only the active agent OR the orchestrator writes at any given time. Parallel screen dispatch is architecturally prohibited without a state-per-screen refactor."
3. Consider writing state atomically (write to `.handoff-state.local.md.tmp`, then rename) to prevent partial-write corruption.

---

### Finding 2: Orchestrator Context Accumulation Across Screen Loop

**Severity:** HIGH
**Category:** Bottleneck Identification
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** The orchestrator runs the screen loop directly (figma-preparation.md lines 141-188). For each screen, the orchestrator: (a) reads state, (b) dispatches agent, (c) reads state back, (d) collects manifest entries, (e) logs progress. With N screens, the orchestrator accumulates N dispatch prompts + N state reads + N manifest entries in its context window. For a 15-screen design file (not uncommon for a production app), this means the orchestrator's context grows substantially by the end of the loop.

The "telephone game" problem from the multi-agent patterns lens applies here: the orchestrator is reading back agent results and re-interpreting them. While the file-based approach mitigates this (the orchestrator reads structured state rather than paraphrasing agent prose), the context accumulation still degrades orchestrator reasoning quality for late-loop screens.

**Recommendation:**
1. Extract the screen loop into a dedicated coordinator agent that receives the full screen inventory and manages the sequential dispatch loop. The orchestrator dispatches this coordinator once for Stage 2, reads back the assembled manifest and updated state, and proceeds to Stage 2J. This isolates the loop context from the orchestrator's multi-stage context.
2. If keeping the loop in the orchestrator (for simplicity), add an explicit context management rule: "After every 5 screens, the orchestrator MUST write a compact loop-progress summary to the Progress Log and discard per-screen operation details from working memory. Only the summary and the current screen's data should be in active consideration."

---

### Finding 3: Judge (Opus) Dispatched 4 Times -- Cost and Latency Without Proportional Value at Every Checkpoint

**Severity:** HIGH
**Category:** Agent Specialization Justification
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** The `handoff-judge` (opus model) is dispatched at 4 separate checkpoints: 2J, 3J, 3.5J, 5J. Each dispatch loads the full judge prompt, reads multiple artifacts, and evaluates against checkpoint-specific rubrics. Opus is the most expensive model tier. The Stage 3J checkpoint has `max_review_cycles: 1` (judge-protocol.md line 110, config line 123), meaning it allows only one re-examination -- this is a "lightweight check" per the config comment. Similarly, Stage 5J allows only `max_revision_cycles: 1`.

For stages 3J and 5J, a single-cycle lightweight check dispatched to an opus-tier model is disproportionate. The rubric for 3J (lines 99-104) evaluates 4 dimensions that are largely structural checks (navigation dead-ends, classification accuracy) rather than nuanced quality judgments that require opus-level reasoning. The 5J rubric's "no Figma duplication" check (line 154) is essentially pattern matching -- scanning for layout/color keywords in the supplement.

**Recommendation:**
1. Downgrade Stage 3J and 5J judge dispatches to sonnet. These checkpoints perform structural verification, not nuanced quality assessment. Reserve opus for Stage 2J (visual fidelity requires sophisticated spatial reasoning) and Stage 3.5J (evaluating newly created screens against existing design language).
2. Alternatively, make the model tier configurable per checkpoint in `handoff-config.yaml` (add a `model` key under each checkpoint) so users can tune cost vs. quality.

---

### Finding 4: Strictly Serial Pipeline Misses Parallelism Opportunity Between Stages 2 and 3

**Severity:** HIGH
**Category:** Bottleneck Identification
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The pipeline is fully serial: 1 -> 2 -> 2J -> 3 -> 3J -> 3.5 -> 3.5J -> 4 -> 5 -> 5J. Stage 3 (gap analysis) reads the prepared Figma screens but does NOT depend on Stage 2's `handoff-manifest.md` output. The gap analyzer inspects the Figma file directly via MCP (SKILL.md line 191: "The analyzer uses figma-console for all queries"). The manifest is a separate artifact consumed in Stages 4 and 5.

This means that for screens already prepared (e.g., the first 5 out of 10), gap analysis could begin on those screens while the remaining screens are still being prepared in Stage 2. The current architecture forces the gap analyzer to wait until ALL screens are prepared, adding unnecessary wall-clock latency.

However, this must be weighed against the single-writer state file constraint (Finding 1). Parallel execution between Stage 2 (screen loop) and Stage 3 (gap analysis) would require both to write to the state file, which the current architecture prohibits.

**Recommendation:**
1. If the coordinator extraction from Finding 2 is implemented, enable a "streaming" pattern: the Stage 2 coordinator writes per-screen completion markers to a separate file (`design-handoff/.screens-ready-for-gap.md`). A Stage 3 coordinator can consume completed screens incrementally. This requires a secondary coordination file rather than sharing the main state file.
2. Even without full parallelism, consider allowing Stage 3 to start on already-prepared screens while the Stage 2J judge evaluates (since the judge is read-only). This would overlap judge evaluation with gap analysis.

---

### Finding 5: No Timeout or Circuit Breaker on Agent Dispatches

**Severity:** MEDIUM
**Category:** Failure Propagation and Recovery
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** The screen loop (figma-preparation.md lines 141-188) dispatches `handoff-figma-preparer` and then reads state. There is no timeout mechanism. If the figma-console MCP server becomes unresponsive during a dispatch (network issue, Figma Desktop crash, plugin hang), the agent will stall indefinitely. The crash recovery protocol (lines 437-463) handles the case where the *workflow* is re-invoked after a crash, but not the case where an agent hangs within a session.

Additionally, there is no circuit breaker. If 3 consecutive screens fail with "error" status, the loop continues attempting every remaining screen. With 15 screens and a systematic MCP issue, this could mean 15 failed dispatches before the orchestrator notices the pattern.

**Recommendation:**
1. Add a `consecutive_error_threshold` config key (suggested: 3). After N consecutive screen errors, halt the loop and notify the designer: "MCP appears unavailable. {N} consecutive screens failed. Resume when Figma connection is stable."
2. Document in SKILL.md that per-dispatch timeout is delegated to Claude Code's Task timeout mechanism (if one exists), or recommend the designer set Figma Desktop's keep-alive timeout in their environment.

---

### Finding 6: TIER Downgrade on Component Library Failure Lacks Downstream Propagation Check

**Severity:** MEDIUM
**Category:** Information Flow Between Components
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** When the component library dispatch fails (figma-preparation.md lines 126-130), the orchestrator downgrades TIER to 1 for "all subsequent screen dispatches." However, this downgrade is described only in the post-dispatch state update section. The downstream stages (3, 3.5, 5) are not documented as checking the effective TIER. Stage 3.5 dispatches `handoff-figma-preparer` in "extend mode" -- if the TIER was downgraded from 2 to 1, the extend-mode agent should know not to attempt component integration for new screens, but this constraint is not explicit.

The TIER value in the state file (`tier_decision.tier`) is the *original* decision. The downgrade is a runtime override. If the workflow crashes and resumes, the resume protocol reads `tier_decision.tier` from state -- the original value, not the downgraded one.

**Recommendation:**
1. Add an `effective_tier` field to the state schema (separate from `tier_decision.tier`) that records the runtime-effective TIER. The component library failure handler should set `effective_tier: 1` in the state file.
2. All downstream stage dispatches should read `effective_tier` (falling back to `tier_decision.tier` if not set, for backward compatibility).
3. Document this in the state-schema.md transitions section.

---

### Finding 7: Visual Diff Threshold is "Advisory" but Presented as a Numeric Config Value

**Severity:** MEDIUM
**Category:** Output Validation Between Stages
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/config/handoff-config.yaml`

**Current state:** The config defines `visual_diff_threshold: 0.95` (line 116) with a comment: "Advisory: qualitative visual comparison (no computed metric). Agent evaluates visual fidelity holistically." This is a contradiction: the value 0.95 implies a quantitative threshold, but the comment says there is no computed metric. The per-screen dispatch prompt (figma-preparation.md line 229) passes this value as `Visual Diff Config - Threshold: {VISUAL_DIFF_THRESHOLD}`, which the agent receives and must interpret.

This creates ambiguity for the agent. Does 0.95 mean "95% pixel match"? Or is it a qualitative anchor? The state schema stores `visual_diff_score: float | null` (state-schema.md line 48), implying the agent IS expected to produce a numeric score. But no scoring methodology is defined.

**Recommendation:**
1. Either define a concrete scoring methodology (e.g., "Agent rates visual fidelity on a 0-1 scale across 5 sub-dimensions and averages them. Score >= threshold passes.") and document it in the agent or judge-protocol.
2. Or remove the numeric threshold entirely and replace with a qualitative instruction: "Agent performs holistic visual comparison and returns PASS/FAIL with evidence." Update the state schema to store `visual_diff_result: "pass" | "fail"` instead of a float.
3. The current mixed approach invites inconsistent agent behavior across screens and sessions.

---

### Finding 8: Quick Mode Skips Stage 2 but Stage 3 Gap Analyzer May Receive Unprepared Figma Data

**Severity:** MEDIUM
**Category:** Information Flow Between Components
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Quick mode skips Stage 2 (Figma Preparation) entirely (SKILL.md line 171: "Skip entirely in Quick mode"). Stage 3 (Gap Analysis) then runs on the raw, unprepared Figma file. The gap analyzer uses `figma-console` to query the file (SKILL.md line 191). However, the gap analyzer was designed to analyze *prepared* screens -- screens with semantic naming, token bindings, and clean structure.

When the gap analyzer encounters raw Figma data (generic names like "Group 47", no token bindings, deep GROUP nesting), its gap detection quality will degrade. It may flag naming issues as "gaps" (when they are actually preparation deficiencies, not design gaps). The mode table in config (line 141) confirms quick mode runs stages `[1, 3, 4, 5]` -- no judge checkpoints either.

**Recommendation:**
1. Add a "Quick Mode Constraints" section to `references/gap-analysis.md` that instructs the gap analyzer: "In Quick mode, the Figma file has NOT been prepared. Ignore naming, structure, and token issues. Focus exclusively on behavioral gaps, missing states, and missing screens."
2. Pass a `mode: quick` variable in the Stage 3 dispatch prompt so the gap analyzer can apply mode-specific filtering.

---

### Finding 9: Judge Verdict File vs. State File Dual-Write Could Diverge

**Severity:** LOW
**Category:** Information Flow Between Components
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** The judge writes verdicts to two locations (judge-protocol.md lines 170-172): (1) state file `judge_verdicts.{checkpoint_id}` for orchestrator decisions, and (2) verdict file `judge-verdicts/{CHECKPOINT}-verdict.md` for audit trail. The state file is declared "canonical" (line 19). However, there is no validation that both locations agree. If the judge writes the state file but crashes before writing the verdict file (or vice versa), the audit trail diverges from the operational state.

**Recommendation:**
1. Add a reconciliation step in the orchestrator's judge integration (after step 4 in the dispatch pattern): "Verify verdict file exists when state file verdict is non-null. If verdict file is missing, log warning but trust state file as canonical." This makes the divergence detectable without blocking the workflow.

---

### Finding 10: Well-Designed Context Isolation via One-Screen-Per-Dispatch

**Severity:** INFO
**Category:** Context Isolation (Positive Observation)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/figma-preparation.md`

**Current state:** The one-screen-per-dispatch pattern (figma-preparation.md lines 46-56) is an exemplary application of the context isolation principle from the multi-agent patterns lens. The rationale is concrete and well-documented: "figma-console MCP returns large node trees, variable collections, and component metadata per call. Processing multiple screens in a single agent dispatch leads to context compaction."

The dispatch prompt template (lines 200-231) passes minimal, focused context per screen with explicit variable sourcing. Cross-screen state (component library) is passed as a compact summary, not raw data. Resume context is parameterized for crash recovery. This is a textbook implementation of the "instruction passing" isolation mechanism.

**Recommendation:** None. This is a reference-quality implementation of context isolation for MCP-heavy workloads.

---

### Finding 11: LLM-as-Judge Replaces MPA+PAL with Measurable Architectural Simplification

**Severity:** INFO
**Category:** Agent Specialization Justification (Positive Observation)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/judge-protocol.md`

**Current state:** The CLAUDE.md documents this as an explicit architectural evolution from design-narration: "design-narration used 3 MPA specialist agents + PAL Consensus + validation synthesis (8 total agents) for quality verification. This was slow, context-heavy, and the synthesis step often produced biased results (first-read anchoring)." The replacement -- a single reusable `handoff-judge` with 4 checkpoint-specific rubrics -- eliminates the synthesis bias problem entirely and reduces total agent dispatches for quality verification.

The judge is correctly modeled as a dedicated PHASE (not an inline afterthought), with its own dispatch protocol, verdict format, and escalation paths. The anti-patterns table (judge-protocol.md lines 209-217) explicitly guards against common implementation mistakes like skipping the judge or running it inline.

**Recommendation:** None. The architectural decision is well-motivated and the implementation guards against known anti-patterns.

---

## Strengths

### Strength 1: Comprehensive Crash Recovery with Step-Level Granularity

The state schema tracks progress at the individual step level within each screen (9 steps per screen). The resume protocol (state-schema.md lines 189-199) can determine exactly where a crash occurred and resume from the next uncompleted step. This goes beyond stage-level recovery (which would require re-processing an entire screen) to provide fine-grained recovery. Combined with the "preparing" status sentinel (state-schema.md line 124: "preparing is the ONLY in-progress status"), the system can distinguish between "never started" and "started but interrupted" screens.

The state integrity check on resume (figma-preparation.md lines 465-467: "verify that all prepared screens have corresponding screenshot files") adds a secondary validation layer that catches cases where state was written but the corresponding artifact was not.

### Strength 2: Explicit Variable Sourcing Tables Eliminate Dispatch Ambiguity

Every dispatch prompt in the skill includes a companion "Variable Sourcing" table (figma-preparation.md lines 112-117, 233-247) that specifies: the variable name, its source (which state field or config key), and a default value. This eliminates the common failure mode documented in the CLAUDE.md under "Agent Prompt Variable Discipline": coordinators filling only what is explicitly listed. By making every variable's source explicit, the skill prevents both missing variables and incorrect sourcing.

### Strength 3: Graceful Degradation at Multiple Levels

The architecture degrades gracefully at three distinct levels:
1. **TIER downgrade** -- If component library creation fails, TIER downgrades to 1 and the workflow continues with simpler preparation.
2. **Per-screen blocking** -- A screen that fails visual diff is marked `blocked` and excluded from downstream stages, but all other screens proceed normally.
3. **All-screens-blocked halt** -- Only if every screen is blocked does the workflow fully halt (figma-preparation.md lines 185-188).

This three-tier degradation ensures the workflow produces maximum value even when individual components fail, rather than using an all-or-nothing approach.

### Strength 4: Mode System with Stage-Level Granularity

The config (lines 133-144) defines three modes (guided, quick, batch) with explicit stage lists. This makes it unambiguous which stages execute in which mode, preventing the common problem of mode guards scattered across reference files with inconsistent coverage. The stage dispatch table in SKILL.md (lines 118-129) cross-references mode applicability, creating a single source of truth for the execution plan.
