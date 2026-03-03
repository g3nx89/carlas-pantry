---
analyst: "Claude Opus 4.6"
lens: "Overall Effectiveness"
target_skill: "feature-refinement"
target_version: "3.0.0"
skill_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/refinement"
date: "2026-03-01"
evaluation_criteria: "fallback (customaize-agent:agent-evaluation skill unavailable)"
files_reviewed:
  - "SKILL.md"
  - "references/orchestrator-loop.md"
  - "references/error-handling.md"
  - "references/stage-1-setup.md"
findings_count:
  critical: 1
  high: 3
  medium: 3
  low: 2
  info: 2
strengths_count: 3
---

# Effectiveness Analysis: feature-refinement

## Summary

The feature-refinement skill is an ambitious, well-structured orchestration system for transforming rough product drafts into finalized PRDs through iterative multi-agent Q&A. It demonstrates strong architectural thinking -- the lean orchestrator pattern, dynamic MPA panel composition, and resumable state machine are sophisticated and well-documented. However, several effectiveness issues undermine its real-world reliability: the ThinkDeep call matrix creates a fragile dependency on expensive external services without sufficient fallback depth, the MCP availability detection relies on probing calls that may produce side effects, and the coordinator dispatch template embeds so many conditional variables that Claude is likely to mishandle edge cases in the variable interpolation. The skill would benefit from simplifying its happy path while hardening its degradation paths.

---

## Findings

### CRITICAL

#### F1: ThinkDeep Call Matrix Creates Unreliable Core Dependency

- **Severity:** CRITICAL
- **Category:** Edge Case Coverage / Reliability
- **File:** `SKILL.md` (lines 84-89), `references/error-handling.md` (lines 69-76)
- **Current State:** The Analysis Modes table specifies 27 ThinkDeep calls for Complete mode (3x3x3) and 18 for Advanced mode (2x3x3). The error-handling reference covers individual model failures but does not address cascade failure scenarios where multiple models fail in sequence. The "No Model Substitution" rule (error-handling.md line 161) means that if 2 of 3 models fail across ThinkDeep perspectives, the system accumulates partial results with no mechanism to assess whether the remaining single-model results are sufficient for question quality. The quality gate after Stage 3 checks `thinkdeep_completion_pct` but only warns -- it never triggers re-generation or mode downgrade.
- **Recommendation:** Add a threshold (e.g., `thinkdeep_completion_pct < 40%`) that triggers automatic mode downgrade from Complete to Standard, rather than just warning. When ThinkDeep is severely degraded, the marginal value of partial single-model results does not justify the cost and latency. The user should be informed of the automatic downgrade with an option to override. This transforms a silent quality degradation into an explicit, recoverable decision point.

---

### HIGH

#### F2: MCP Availability Detection via Probing Calls Risks Side Effects

- **Severity:** HIGH
- **Category:** Instruction-Following Quality
- **File:** `references/stage-1-setup.md` (lines 22-36)
- **Current State:** Step 1.1 instructs Claude to "Try invoking `mcp__pal__listmodels`" and "Try invoking `mcp__sequential-thinking__sequentialthinking` with a simple thought" to detect availability. The `listmodels` call is read-only, but invoking Sequential Thinking "with a simple thought" actually creates a thinking session as a side effect. There is no guidance on what constitutes a "simple thought" or how to clean up the session. Additionally, Claude may interpret "try invoking" in multiple ways -- some models may attempt a full invocation and wait for a response, while others may check tool availability through metadata. The instruction is ambiguous about the expected mechanism.
- **Recommendation:** Replace probing invocations with explicit tool existence checks. For Sequential Thinking, specify: "Check if `mcp__sequential-thinking__sequentialthinking` appears in the available tools list. Do NOT invoke it for detection purposes." For PAL, similarly check tool availability without invocation. If probing is truly necessary, specify the exact parameters and expected response format so Claude's behavior is deterministic.

#### F3: Coordinator Dispatch Template Has Too Many Conditional Branches for Reliable Interpolation

- **Severity:** HIGH
- **Category:** Instruction-Following Quality
- **File:** `references/orchestrator-loop.md` (lines 54-106)
- **Current State:** The dispatch template contains 10 variables, 5 conditional blocks (using `{IF ...}` syntax), and nested conditions for prior stage summaries vs. compacted digests. Claude must correctly interpolate all variables, evaluate all conditions, and compose the prompt string. The `{IF REFLECTION_CONTEXT is non-empty}` and `{IF current_round <= compaction.rounds_before_compaction}` conditions require Claude to read state, evaluate expressions, and conditionally include sections -- all within a string template. This is a significant cognitive load for the model and increases the probability of malformed coordinator prompts, especially in later rounds when more conditions become active simultaneously.
- **Recommendation:** Restructure the dispatch into 2-3 named profiles (e.g., `first-round-dispatch`, `subsequent-round-dispatch`, `reflection-dispatch`) with pre-evaluated conditions. Each profile would be a complete template with no conditional branches, selected by the orchestrator based on state. This trades some duplication for dramatically improved reliability of prompt construction.

#### F4: Contradictory Guidance on User Interaction in Stage 1

- **Severity:** HIGH
- **Category:** Internal Consistency
- **File:** `SKILL.md` (line 48, Rule 22), `references/stage-1-setup.md` (lines 90-105, 135-149, 216-246)
- **Current State:** SKILL.md Rule 22 states: "Coordinators NEVER interact with users directly -- set `status: needs-user-input` in summary; orchestrator mediates ALL prompts via AskUserQuestion." Rule 23 then states: "Stage 1 runs inline." Stage-1-setup.md directly uses `AskUserQuestion` for lock management (line 90), PRD mode selection (line 135), analysis mode selection (line 216), and panel validation (lines 272-394). This is technically consistent because Stage 1 IS the orchestrator (inline execution), but the phrasing of Rule 22 ("Coordinators NEVER interact with users directly") could easily be misinterpreted to apply to Stage 1's inline execution as well, since Stage 1 still follows the coordinator pattern (writes a summary, has a checkpoint). A Claude instance might hesitate to call `AskUserQuestion` during Stage 1 if it over-applies Rule 22.
- **Recommendation:** Amend Rule 22 to explicitly exclude Stage 1: "Coordinators (Stages 2-6) NEVER interact with users directly. Stage 1 runs inline as part of the orchestrator and uses `AskUserQuestion` directly." This eliminates any ambiguity about Stage 1's interaction privileges.

---

### MEDIUM

#### F5: No Explicit Timeout or Token Budget for Coordinator Dispatches

- **Severity:** MEDIUM
- **Category:** Edge Case Coverage
- **File:** `references/orchestrator-loop.md` (lines 40-106)
- **Current State:** The dispatch template references "per-stage dispatch profile" from config (`token_budgets.stage_dispatch_profiles`) in the stage dispatch profiles table, but no actual timeout or maximum token values are specified in the orchestrator-loop.md or SKILL.md. If a coordinator enters an infinite loop (e.g., repeatedly attempting a failed MCP call), there is no mechanism for the orchestrator to detect the hang and intervene. The crash recovery section handles missing summaries (coordinator produced no output) but not the case where a coordinator is still running and consuming tokens.
- **Recommendation:** Define explicit per-stage token budget ceilings in the dispatch profiles table (even if approximate) and add a note that the `Task()` dispatch should include a reasonable output limit. This provides a natural circuit breaker for runaway coordinators.

#### F6: Circuit Breaker at 100 Rounds Is Effectively Unreachable

- **Severity:** MEDIUM
- **Category:** Coverage Completeness
- **File:** `SKILL.md` (line 63), `references/orchestrator-loop.md` (lines 408-416)
- **Current State:** The circuit breaker is set at `max_rounds: 100`. Given that each round involves user interaction (answering questions offline, re-invoking the command), 100 rounds would take weeks or months of calendar time. In practice, a user stuck in a loop would abandon the workflow long before reaching 100. A more realistic scenario is a logic bug causing infinite `loop_questions` decisions where the system never reaches "proceed" -- but even then, the user must manually re-invoke each time, making a true infinite loop impossible. The circuit breaker protects against a scenario that cannot occur in practice.
- **Recommendation:** Lower the circuit breaker to a practical value (e.g., 10-15 rounds) and add a "soft warning" at round 5 that asks the user whether the workflow is making progress. This catches genuine stalling (e.g., Stage 4 repeatedly finding gaps in the same sections) at a point where intervention is still useful.

#### F7: Panel Builder Failure Fallback Skips User Validation

- **Severity:** MEDIUM
- **Category:** Edge Case Coverage
- **File:** `references/stage-1-setup.md` (lines 321-329), `references/error-handling.md` (lines 144-156)
- **Current State:** When the Panel Builder crashes, the fallback writes the default preset directly to `.panel-config.local.md` and skips steps 4-7 (which include user validation of the panel). The user is notified ("Panel Builder failed. Falling back to default preset.") but has no opportunity to choose a different preset or customize members. For a domain-specific product (e.g., a regulated healthcare app), the default `product-focused` panel may miss critical perspectives (e.g., Compliance & Regulatory).
- **Recommendation:** After the fallback notification, present the user with the preset selection question (Step 6 from the normal flow) so they can override the default. This adds one `AskUserQuestion` call but ensures the user is never silently locked into an inappropriate panel for their domain.

---

### LOW

#### F8: Summary Contract Example Has Hardcoded Panel Members

- **Severity:** LOW
- **Category:** Internal Consistency
- **File:** `SKILL.md` (lines 196-226)
- **Current State:** The example Stage 3 summary (line 217) shows `panel_member_ids: ["product-strategist", "ux-researcher", "functional-analyst"]`, which are the `product-focused` preset members. Since the skill emphasizes dynamic panel composition, this example could mislead Claude into thinking these are the only valid member IDs, or that the summary must always contain exactly these three.
- **Recommendation:** Add a comment to the example: `# Example only -- actual IDs come from panel config` or use generic placeholder IDs like `["member-1", "member-2", "member-3"]`.

#### F9: Git Suggestion in Stage 1 Uses Broad `git add`

- **Severity:** LOW
- **Category:** Instruction-Following Quality
- **File:** `references/stage-1-setup.md` (lines 439-441)
- **Current State:** The git suggestion recommends `git add requirements/` which stages the entire requirements directory. Per the project's CLAUDE.md Git Workflow guidelines: "Stage by explicit file path, not `git add .` or directory globs -- untracked files from other plugins can silently infiltrate the index." While `requirements/` is more targeted than `git add .`, it still risks staging user files that may have been placed in the directory outside the workflow.
- **Recommendation:** Replace with explicit file paths: `git add requirements/.requirements-state.local.md requirements/.requirements-lock requirements/.panel-config.local.md requirements/.stage-summaries/stage-1-summary.md`.

---

### INFO

#### F10: Excellent Resumability Design

- **Severity:** INFO
- **Category:** Positive Observation
- **File:** `SKILL.md`, `references/orchestrator-loop.md`
- **Current State:** The skill's resumability model is thorough and well-designed. The combination of `waiting_for_user` + `pause_stage` state tracking, `ENTRY_TYPE` variable for re-entry disambiguation, persisted reflection context for crash recovery during RED loops, and the immutable `user_decisions` log creates a robust resume experience. The distinction between `exit_cli` and `interactive` pause types correctly models the two interaction patterns (offline file editing vs. inline questions).

#### F11: Graceful Degradation Hierarchy Is Well-Structured

- **Severity:** INFO
- **Category:** Positive Observation
- **File:** `references/error-handling.md`
- **Current State:** The degradation from Complete -> Advanced -> Standard -> Rapid based on MCP availability is cleanly layered. Each degradation step removes exactly one capability tier without affecting others. Research MCP is correctly identified as orthogonal to the PAL/ST axis. The error notification format is consistent and actionable, with clear options at each failure point. The explicit "NEVER substitute models" rule, while it creates the cascade risk noted in F1, is well-justified by the traceability rationale.

---

## Strengths

### S1: Dynamic MPA Panel System Is a Genuine Innovation

The panel builder pattern -- where specialist agent perspectives are composed at runtime based on domain detection rather than hardcoded -- is a sophisticated approach to multi-perspective analysis. The combination of presets for common cases with full customization for edge cases, persisted across rounds, is well-designed. The template-based panel member dispatch (`requirements-panel-member.md` with injected variables) avoids agent proliferation while maintaining specialization.

### S2: Reflexion Loop Demonstrates Deep Understanding of Iterative Refinement

The REFLECTION_CONTEXT generation after RED validation (orchestrator-loop.md lines 278-315) goes beyond simple retry logic. It synthesizes what was tried, why it failed, which dimensions are weak, and what to do differently -- then persists this reflection to disk for crash recovery. This mirrors the Reflexion pattern from AI research and gives the next round of question generation meaningful guidance rather than blindly regenerating similar questions. The persistent gap tracker in the compaction digest adds cross-round memory.

### S3: Comprehensive State Schema Supports Complex Workflow Lifecycle

The state management design covers the full lifecycle: initialization, round tracking, user decision immutability, MCP availability caching, model failure logging, and schema versioning with migration. The separation between orchestrator-owned fields (`current_stage`, `current_round`, `waiting_for_user`) and coordinator-written nested structures (`rounds`, `phases`) creates clean ownership boundaries. The lock protocol with configurable staleness threshold prevents both stale locks blocking progress and fresh locks being prematurely removed.
