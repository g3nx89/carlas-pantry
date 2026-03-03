---
lens: multi-agent-patterns
lens_source: sadd:multi-agent-patterns
target_skill: feature-specify
target_path: plugins/product-definition/skills/specify
fallback_used: false
finding_counts:
  critical: 1
  high: 3
  medium: 3
  low: 2
  info: 2
strengths_count: 4
date: 2026-03-01
---

# Architecture & Coordination Quality Analysis: feature-specify

## Summary

The feature-specify skill implements a 7-stage supervisor/orchestrator pattern with coordinator delegation. The architecture is well-suited for its complexity level: a central orchestrator dispatches focused coordinators via the Task tool, communicates through file-based summaries and a persistent state file, and manages an iteration loop between Stages 3 and 4. The design demonstrates strong context isolation, graceful degradation, and crash recovery fundamentals.

The primary architectural risks center on supervisor context accumulation over long-running workflows (especially through the Stage 3-4 iteration loop), the absence of inter-stage output validation beyond lightweight quality gates, and a subtle consensus vulnerability in the CLI dispatch synthesis step. The skill's multi-CLI dispatch pattern is creative but introduces serial dependency risks where a single synthesis agent becomes the interpretive bottleneck for three independent analyses.

**Files analyzed:**
- `SKILL.md` (orchestrator dispatch table, critical rules, state schema)
- `references/orchestrator-loop.md` (dispatch loop, variable defaults, iteration logic, quality gates)
- `references/error-handling.md` (failure recovery, graceful degradation)
- `references/cli-dispatch-patterns.md` (tri-CLI parallel dispatch, synthesis, evaluation)
- `references/stage-2-spec-draft.md` (spec draft, MPA-Challenge, incremental gates)
- `references/recovery-migration.md` (crash recovery, state migration v2-v5)
- `references/README.md` (file index, cross-references)

---

## Findings

### Finding 1: Supervisor Context Accumulation in Iteration Loop

**Severity:** CRITICAL
**Category:** Bottleneck identification / Supervisor context accumulation
**File:** `references/orchestrator-loop.md`

**Current state:** The orchestrator dispatches Stage 3 (Checklist), reads the summary, then dispatches Stage 4 (Clarification), reads that summary, and loops back. Each iteration adds coordinator summaries, quality gate results, stall detection logic, and user interaction history to the orchestrator's context. While summary size limits are defined (500 chars YAML, 1000 chars body), the orchestrator accumulates:
- All prior stage summaries (passed to each coordinator via "Prior Stage Summaries")
- Iteration tracking state (`iterations` array in state file)
- Quality gate warnings logged to state file
- User interaction history from AskUserQuestion calls

Over 3+ iterations, the orchestrator context grows substantially. The dispatch template includes `{CONTENTS OF specs/{FEATURE_DIR}/.stage-summaries/stage-*-summary.md}` which means every coordinator receives the full history of all prior stage summaries, not just the immediately preceding one.

**Recommendation:** Implement a rolling summary window for the iteration loop. When dispatching Stages 3 or 4 in iteration > 1, pass only: (a) the most recent Stage 3 summary, (b) the most recent Stage 4 summary, and (c) a compact iteration history (coverage percentages only, not full summaries). Archive older summaries to `stage-N-summary-iter-M.md` files that coordinators can load on-demand if needed. Add a `max_prior_summaries` config value (default: 3) to cap how many summaries are passed in the dispatch template.

---

### Finding 2: Synthesis Agent as Single Point of Failure and Interpretation Bottleneck

**Severity:** HIGH
**Category:** Bottleneck identification / Single point of failure
**File:** `references/cli-dispatch-patterns.md`

**Current state:** After tri-CLI parallel dispatch, a single haiku-tier synthesis agent merges all outputs:

```
SYNTHESIZE:
    CALL Task(subagent_type="general-purpose", model="haiku") with:
        inputs: [all captured outputs from CLIs that succeeded]
        strategy: union_with_dedup (for analysis) or weighted_score (for evaluation)
        Output: merged findings written to specs/{FEATURE_DIR}/analysis/{output_file}
```

This introduces two risks:
1. **Telephone game problem** (identified in the lens criteria): The haiku model interprets and paraphrases three independent analyses, potentially losing nuance or misrepresenting findings. Using haiku (the least capable tier) for synthesis of outputs from more capable models is a capability mismatch.
2. **No validation of synthesis fidelity**: There is no check that the synthesis accurately represents the individual CLI outputs. A finding from one CLI could be dropped or mischaracterized without detection.

**Recommendation:** (a) Elevate the synthesis model to sonnet for Integrations 1, 2, and 4 (Challenge, EdgeCases, Evaluation) where interpretation quality matters most. Keep haiku for Integration 3 (Triangulation) where the task is primarily deduplication. (b) Add a post-synthesis validation step: compare the count of unique findings in individual outputs vs. the synthesis output. If the synthesis drops more than 20% of findings, flag for review. (c) For the Evaluation integration (Integration 4), preserve individual CLI scores alongside the aggregate to prevent the synthesis agent from altering scoring.

---

### Finding 3: Missing Pre-Condition Validation Between Stages

**Severity:** HIGH
**Category:** Output validation between stages
**File:** `references/orchestrator-loop.md`

**Current state:** The orchestrator performs quality gates after Stages 2, 4, and 5, but these are non-blocking notifications. Between stages, the only validation is summary schema validation (checking that required YAML fields exist). There is no validation that the content of artifacts meets the input requirements of the next stage.

Examples of unguarded transitions:
- Stage 3 (Checklist) assumes `spec.md` from Stage 2 has user stories with acceptance criteria, but never validates this before starting. If the BA agent produced a malformed spec, Stage 3 will fail mid-execution.
- Stage 5 (Design) assumes `spec.md` has been updated with clarification answers from Stage 4, but there is no content check.
- Stage 6 (Test Strategy) has pre-validation gates (documented in CLAUDE.md learnings), but this pattern is not applied to other stages.

**Recommendation:** Add a lightweight pre-condition check at the start of each stage reference file, following the pattern already established for Stage 6. Define required artifacts and minimum content checks (e.g., "spec.md exists AND contains at least 1 `## US-` heading") in each stage's CRITICAL RULES section. This catches upstream failures early rather than mid-execution, reducing wasted coordinator dispatches.

---

### Finding 4: CLI Evaluation Sequential-Then-Parallel Pattern Creates Anchoring Risk Despite Mitigation Claim

**Severity:** HIGH
**Category:** Consensus problems / Anchoring bias
**File:** `references/cli-dispatch-patterns.md`

**Current state:** Integration 4 (Evaluation) uses a "sequential-then-parallel" pattern where gemini (neutral) runs first, then codex (advocate) and opencode (challenger) run in parallel:

```
# Step 1: Run gemini (neutral) first — wait for completion
# Step 2: Run codex (advocate) + opencode (challenger) in parallel
```

The stated rationale is "This prevents anchoring -- the neutral baseline must be set before stances are applied." However, the advocate and challenger CLIs do NOT receive the neutral output — they receive the same spec content independently. This means the sequential ordering provides no anchoring prevention benefit for the CLI agents themselves. The only consumer of all three outputs is the synthesis agent, which reads them in a fixed order (gemini first), creating the exact anchoring risk the lens criteria warns about: "the first-read agent's framing anchors the synthesis."

**Recommendation:** Either (a) make all three evaluations fully parallel since the sequential ordering provides no benefit to the CLI agents, which would reduce latency, or (b) if the intent is to feed the neutral baseline into the synthesis prompt as a reference frame, make this explicit in the synthesis instructions and instruct the synthesis agent to read outputs in randomized order for the scoring dimensions. The current architecture pays a latency cost (sequential gemini dispatch) without the stated anchoring-prevention benefit.

---

### Finding 5: Graceful Degradation Removes Majority of Quality Assurance

**Severity:** MEDIUM
**Category:** Architecture simplification / Proportional value
**File:** `references/error-handling.md`

**Current state:** When CLI dispatch is unavailable, the skill skips Challenge (Stage 2), EdgeCases (Stage 4), Triangulation (Stage 4), and Evaluation (Stage 5). This removes all multi-perspective analysis and external quality validation. The skill falls back to "internal reasoning" but there is no defined internal reasoning protocol — it simply skips these steps.

From error-handling.md:
```
Skip Challenge, EdgeCases, Triangulation, and Evaluation steps —
proceed with internal reasoning
```

"Internal reasoning" is never defined. There are no substitute quality checks, no self-critique protocol for the degraded path, and no minimum quality threshold for the CLI-less workflow. A user running without CLIs gets a significantly lower quality spec with no warning about what quality checks were skipped.

**Recommendation:** Define an explicit "internal reasoning" fallback for each skipped integration point. At minimum: (a) for Challenge — the BA agent's self-critique score (already generated) serves as the sole quality signal; lower the GREEN threshold to 14/20 to reflect reduced confidence. (b) For EdgeCases — have the Stage 4 coordinator generate edge cases using internal reasoning with a structured checklist (security, performance, accessibility, etc.) rather than skipping entirely. (c) For Evaluation — add a self-evaluation step with explicit limitations documented in the output. (d) Add a degradation notice to the completion report listing all skipped quality checks.

---

### Finding 6: Coordinator Summary Size Limits May Cause Silent Information Loss

**Severity:** MEDIUM
**Category:** Information flow between components
**File:** `references/orchestrator-loop.md`

**Current state:** Coordinator summaries are capped at 500 chars (YAML `summary` field) and 1000 chars (Context for Next Stage body). The rationale is sound — keep orchestrator context lean. However, there is no mechanism for coordinators to signal when they have more context to pass than fits in the summary.

For example, Stage 4 may generate 15 clarification questions, 8 edge cases from 3 CLIs, and triangulation findings. The 1000-char "Context for Next Stage" cannot meaningfully summarize all of this. The rule says "Detailed analysis belongs in artifact files, not coordinator summaries." But the next coordinator must know what to read — and pointing to 5+ artifact files with one-line descriptions in 1000 chars is tight.

**Recommendation:** Add an `artifacts_for_next_stage` structured field to the summary YAML that lists file paths the next coordinator should read, separate from the 1000-char context body. This way the context body can focus on interpretive guidance ("coverage improved 12% this iteration, remaining gaps are in NFRs") while the file list ensures nothing is overlooked. This is analogous to the "summary-as-context-bus" pattern from the project CLAUDE.md.

---

### Finding 7: RTM Disposition Gate Has Inconsistent Blocking Semantics

**Severity:** MEDIUM
**Category:** Information flow / Error propagation
**File:** `references/orchestrator-loop.md`, `SKILL.md`

**Current state:** SKILL.md Rule 28 states:

```
RTM Disposition Gate: Zero UNMAPPED requirements before proceeding past Stage 4.
Every source requirement must have a conscious disposition.
```

But `orchestrator-loop.md` contradicts this with a non-blocking check:

```
RTM QUALITY CHECK (after Stage 4 if proceeding to Stage 5):
IF RTM_ENABLED AND Stage 4 summary flags.rtm.remaining_unmapped > 0:
    NOTIFY user (non-blocking): "RTM: {N} requirements still UNMAPPED."
    ...
NOTE: This check is intentionally NON-BLOCKING (notification only, does not halt).
```

The orchestrator-loop.md includes a rationale explaining why it is non-blocking (to avoid infinite loops when users decline to answer). The rationale is sound, but it directly contradicts Rule 28 which says "Zero UNMAPPED." A coordinator reading Rule 28 would implement blocking behavior; the orchestrator reading orchestrator-loop.md would implement non-blocking behavior.

**Recommendation:** Reconcile Rule 28 in SKILL.md with the actual orchestrator behavior. Either: (a) change Rule 28 to "RTM Disposition Gate: All UNMAPPED requirements must be offered for disposition in Stage 4. Any remaining UNMAPPED after user interaction are reported in completion (non-blocking)." Or (b) if blocking is truly intended, remove the non-blocking note from orchestrator-loop.md. The current contradiction means behavior depends on which file the agent reads first.

---

### Finding 8: State File Lock Protocol Lacks Timeout Definition

**Severity:** LOW
**Category:** Failure propagation and recovery
**File:** `SKILL.md`

**Current state:** Rule 7 states "Lock Protocol: Always acquire lock at start, release at completion." The lock file is at `specs/{FEATURE_DIR}/.specify.lock`. However, there is no defined stale lock timeout. The project CLAUDE.md pattern guidance says "Lock protocol: acquire at start, release at completion; define stale timeout in config (e.g., 60 min)." If a coordinator crashes without releasing the lock, the next invocation would see a lock file with no mechanism to determine if it is stale.

**Recommendation:** Add a `lock_stale_timeout_minutes` config value (suggest 60 minutes). Write the lock file with a timestamp. On lock acquisition, check if existing lock is older than the stale timeout. If stale, forcibly acquire with a warning to the user. Document this in `checkpoint-protocol.md`.

---

### Finding 9: Stage 1 Inline Exception Lacks Justification for Scope

**Severity:** LOW
**Category:** Agent/component specialization justification
**File:** `SKILL.md`, `references/stage-1-setup.md` (per README: ~400 lines)

**Current state:** Stage 1 runs inline (not coordinator-delegated) per Rule 23: "Stage 1 runs inline -- all other stages are coordinator-delegated." The lean orchestrator pattern from the project CLAUDE.md says "Inline exception: Stage 1 (lightweight setup) runs inline to avoid dispatch overhead."

However, Stage 1 per the README is ~400 lines and includes MCP checks, workspace creation, Figma capture (a multi-step protocol with its own reference file), and RTM inventory extraction. This is not "lightweight setup" — it is comparable in complexity to some delegated stages (Stage 3 is ~230 lines, Stage 7 is ~130 lines). Running this inline means the orchestrator's context is loaded with all of Stage 1's execution detail before it begins dispatching coordinators.

**Recommendation:** Consider splitting Stage 1 into: (a) truly lightweight inline setup (workspace creation, lock acquisition, state init — ~100 lines) and (b) a coordinator-delegated "discovery" stage for MCP checks, Figma capture, and RTM inventory extraction. This would keep the orchestrator context lean at the start. Alternatively, if the inline approach is retained for latency reasons, document why the 400-line inline execution is acceptable despite the stated "lightweight" pattern.

---

### Finding 10: CLI Dispatch Script Dependency Is Not Validated at Architecture Level

**Severity:** INFO
**Category:** Failure propagation
**File:** `references/error-handling.md`

**Current state:** The architecture depends on an external shell script (`$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh`) for all multi-CLI operations. Rule 19 says "Before dispatching CLI, check if `scripts/dispatch-cli-agent.sh` is executable and at least one CLI binary is in PATH." This is validated at Stage 1, but the check result is stored as a boolean `CLI_AVAILABLE` flag. If the script is modified or deleted between Stage 1 and Stage 5, the stale flag would cause failures.

This is a minor concern in practice (scripts rarely change mid-workflow), but worth noting as an architectural assumption. The error handling for exit code 3 (CLI not found) provides a safety net.

---

### Finding 11: Dispatch Template Explicitly Lists All Variables with Defaults

**Severity:** INFO
**Category:** Information flow / Explicit coordination
**File:** `references/orchestrator-loop.md`

**Current state:** The Variable Defaults table in orchestrator-loop.md explicitly lists every dispatch variable with its default value and rationale. This follows the "Agent Prompt Variable Discipline" pattern from the project CLAUDE.md precisely. The two variables without defaults (`FEATURE_DIR` and `FEATURE_NAME`) are correctly marked as abort-on-missing, creating a clear fail-fast boundary.

This is a positive architectural choice that prevents null/empty variable propagation — a common source of subtle failures in multi-agent systems.

---

## Strengths

### Strength 1: Well-Designed Context Isolation via File-Based Communication

The architecture achieves strong context isolation. Each coordinator receives only its stage reference file, shared references appropriate to its needs (via the Stage Dispatch Profiles table), prior stage summaries, and state file frontmatter. Coordinators write results to artifact files and summaries, never directly to the orchestrator's context. This is textbook file-system-as-shared-memory pattern and keeps each coordinator's context focused on its specific task.

### Strength 2: Comprehensive Graceful Degradation Design

The skill degrades across four independent capability axes (CLI dispatch, Sequential Thinking, Figma MCP, individual CLI binaries) with explicit fallback behavior for each. The error-handling reference file provides structured recovery procedures for every integration point. Exit code semantics for CLI dispatch are well-defined with clear retry vs. skip decisions. The circuit breaker pattern (`skip_on_all_fail`) prevents cascading failures from blocking the workflow.

### Strength 3: Crash Recovery with Artifact-Based Reconstruction

The crash recovery protocol in `recovery-migration.md` uses artifact presence as a proxy for stage completion. If a coordinator crashes after writing its artifacts but before writing its summary, the orchestrator can reconstruct a minimal summary. This is a pragmatic approach that avoids data loss in the most common crash scenario (context exhaustion at the end of a long coordinator run). The chained state migration (v2 through v5) with additive-only fields ensures backward compatibility.

### Strength 4: Immutable User Decisions Prevent Re-Ask Loops

The `user_decisions` section of the state file is explicitly immutable (Rule 2). This prevents a common multi-agent failure mode where a resumed workflow re-asks questions the user already answered. Combined with the file-based clarification pattern (answers persisted in markdown files that survive crashes), user work is never lost even in degraded scenarios.
