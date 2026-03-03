---
lens: "Architecture & Coordination Quality"
lens_id: "architecture"
skill_reference: "sadd:multi-agent-patterns"
target_skill: "feature-planning"
target_path: "plugins/product-planning/skills/plan/SKILL.md"
version: "3.0.0"
date: "2026-03-01"
fallback_used: false
finding_count: 12
severity_counts:
  critical: 0
  high: 2
  medium: 4
  low: 3
  info: 3
---

# Architecture & Coordination Quality Analysis

**Target:** `plugins/product-planning/skills/plan/SKILL.md` (feature-planning v3.0.0)

**Lens:** Architecture & Coordination Quality, evaluated against the `sadd:multi-agent-patterns` skill criteria covering coordination pattern selection, information flow, bottleneck identification, failure propagation, output validation, and agent specialization justification.

---

## Strengths

### S1: Well-Designed Supervisor with Context Isolation

The lean orchestrator pattern is a textbook application of the Supervisor/Orchestrator architecture from the multi-agent patterns lens. The orchestrator (SKILL.md) stays under 300 lines, delegates to coordinator subagents via `Task(general-purpose)`, and communicates through standardized summary files. This achieves an estimated 78% context reduction (stated in SKILL.md line 123). The Phase Summary Convention (lines 165-168) enforces a 30-80 line contract, preventing the "supervisor bottleneck" failure mode where the orchestrator accumulates unbounded context from workers.

**File:** `SKILL.md` (lines 36-54), `orchestrator-loop.md` (lines 186-284)

### S2: Explicit Crash Recovery and Graceful Degradation

The architecture includes a multi-layered resilience strategy:

1. **Crash recovery** (`orchestrator-loop.md` lines 290-299): If a coordinator produces no summary, the orchestrator reconstructs a minimal summary from artifacts on disk, marks it `degraded=true`, and asks the user whether to retry, continue, or abort.
2. **CLI circuit breaker** (`cli-dispatch-pattern.md` lines 96-107): After consecutive failures across phases, CLI dispatch is automatically disabled for the session rather than repeatedly failing.
3. **Mode degradation chain**: Complete -> Advanced -> Standard -> Rapid, with each mode requiring fewer external dependencies.
4. **Gate failure escalation**: RED gates trigger loop-back to earlier phases, with deep reasoning escalation as a last resort after 2 retries.

This demonstrates mature error isolation -- failures in one component do not cascade uncontrolled into downstream phases.

**Files:** `orchestrator-loop.md`, `cli-dispatch-pattern.md`, `SKILL.md` (lines 277-282)

### S3: Parameterized Shared Patterns (DRY Multi-Agent Coordination)

The `mpa-synthesis-pattern.md` file extracts the MPA Deliberation and Convergence Detection algorithms into a parameterized shared reference, used by both Phase 4 (Architecture) and Phase 7 (Test Strategy) with different parameter sets. This avoids the common anti-pattern of duplicating multi-agent coordination logic across phase files. The parameter table (lines 20-28) makes substitution explicit and auditable.

**File:** `mpa-synthesis-pattern.md`

---

## Findings

### F1: User Interaction Relay Doubles Dispatch Cost for Interactive Phases

**Severity:** HIGH
**Category:** Bottleneck / Coordination Overhead

**Current state:** The User Interaction Relay protocol (orchestrator-loop.md lines 302-308) requires that when a coordinator needs user input, it writes a `needs-user-input` summary, the orchestrator reads it, prompts the user, writes the answer to a file, and then re-dispatches the entire coordinator. The orchestrator-loop.md ADR (line 399) acknowledges this: "User interaction relay doubles dispatch cost for interactive phases."

The Phase Dispatch Table shows user interaction is possible in Phases 3, 4, 5, 6, 6b, 8b, and 9 -- seven of eleven phases. Each re-dispatch incurs 5-15s overhead plus full coordinator context reconstruction.

**Recommendation:** Introduce a lightweight "continuation" dispatch mode for user-input re-dispatches. Instead of re-dispatching the full coordinator with the complete phase instruction file, dispatch a minimal continuation prompt that references only the user-input file and the coordinator's previous summary. This could halve the re-dispatch overhead for interactive phases. Alternatively, for phases with predictable user interaction (Phase 3 clarification, Phase 4 architecture selection), consider a "pre-collect" pattern where the orchestrator extracts the questions from the coordinator's artifacts before re-dispatch, avoiding the round-trip entirely.

**File:** `orchestrator-loop.md` (lines 302-308, 399-400)

---

### F2: Summary-Based Communication is Insufficient -- Coordinators Also Read Full Artifacts

**Severity:** HIGH
**Category:** Information Flow / Architectural Inconsistency

**Current state:** SKILL.md Critical Rule 9 (line 52) states: "Between phases, read ONLY summary files from `{FEATURE_DIR}/.phase-summaries/`. Never read full phase instruction files or raw artifacts in orchestrator context." However, the ADR in orchestrator-loop.md (line 401) contradicts this: "Summary-based communication is supplementary (coordinators also read full artifacts)."

This means the architecture has two information channels: (1) summaries passed via the orchestrator dispatch prompt, and (2) direct artifact reads by coordinators from the feature directory. The summary convention (30-80 lines) is designed to keep orchestrator context lean, but coordinators bypass this by reading full artifacts directly. This creates an implicit dependency graph that is not visible in the Phase Dispatch Table's "Prior Summaries" column.

**Recommendation:** Make the dual-channel design explicit in SKILL.md. Add a column to the Phase Dispatch Table showing "Direct Artifact Reads" per phase (e.g., Phase 7 reads `design.md`, `plan.md`). This makes the actual information flow auditable. Clarify that Critical Rule 9 applies to the orchestrator only, not to coordinators, and rename it to "Orchestrator Summary-Only Context" to remove the ambiguity.

**File:** `SKILL.md` (line 52), `orchestrator-loop.md` (line 401)

---

### F3: Jaccard Convergence Detection Measures Vocabulary, Not Agreement

**Severity:** MEDIUM
**Category:** Consensus / Sycophancy Risk

**Current state:** The MPA Convergence Detection algorithm (mpa-synthesis-pattern.md lines 69-124) uses Jaccard similarity over extracted keywords to measure agent agreement. The file itself acknowledges this limitation (lines 128-130): "Two agents could use different terms for the same concept (e.g., 'Repository pattern' vs 'Data Access Layer') and score low. Conversely, agents sharing domain vocabulary may score high while disagreeing on architecture."

This is a known trade-off for avoiding external API calls, but it means the convergence signal can be misleading in both directions. A false-high convergence score could cause the synthesis to "merge directly" (line 104) when agents actually disagree, suppressing important divergence. A false-low could trigger unnecessary escalation.

**Recommendation:** Add a secondary structural check alongside Jaccard: after keyword similarity, compare the top-level structure of agent outputs (e.g., number of components identified, risk categories flagged, test levels recommended). If structural similarity diverges from keyword similarity by more than one level (e.g., keywords say HIGH but structure says LOW), flag the convergence score as "ambiguous" and default to the medium strategy. This adds minimal overhead (no external calls) while catching the most dangerous false-convergence cases.

**File:** `mpa-synthesis-pattern.md` (lines 69-130)

---

### F4: Serial Phase Chain Creates Long Critical Path with No Parallelism

**Severity:** MEDIUM
**Category:** Bottleneck / Serial Dependencies

**Current state:** The workflow executes 11 phases strictly in sequence (SKILL.md lines 73-118, orchestrator-loop.md line 37: `FOR phase IN [1, 2, 3, 4, 5, 6, 6b, 7, 8, 8b, 9]`). While some phases have logical dependencies (Phase 4 depends on Phase 2's research), others are potentially parallelizable. For example:
- Phase 8b (Asset Consolidation) has no dependency on Phase 8 (Test Coverage Validation) -- it reads Phase 8's summary but only for completeness, not for content dependency.
- Phase 5 (ThinkDeep) and Phase 6b (Expert Review) analyze the same artifacts from Phase 4 from different perspectives and could theoretically run concurrently.

With 5-15s dispatch overhead per phase and 11 sequential dispatches, the cumulative coordination overhead alone is 55-165s, acknowledged in the ADR (line 399).

**Recommendation:** Identify parallelizable phase pairs and document them in the Phase Dispatch Table with a "Parallelizable With" column. Even if parallel dispatch is not implemented immediately, documenting the dependency graph explicitly enables future optimization. The most promising candidate is Phase 8 + Phase 8b, which share no data dependencies beyond the Phase 7 summary.

**File:** `SKILL.md` (lines 73-118), `orchestrator-loop.md` (line 37)

---

### F5: Deep Reasoning Escalation Introduces Human-in-the-Loop Latency Without Bounds

**Severity:** MEDIUM
**Category:** Bottleneck / User Interaction

**Current state:** The deep reasoning escalation pattern (SKILL.md lines 125-126, orchestrator-loop.md lines 82-140) requires the user to manually copy a prompt to an external model's web interface, wait 3-15 minutes, and paste the response back. If the user walks away, the workflow stalls indefinitely. On resume, the orchestrator checks for pending escalations (orchestrator-loop.md lines 16-35), but there is no timeout or automatic skip-after-delay mechanism.

**Recommendation:** Add a configurable stale escalation timeout (e.g., `deep_reasoning_escalation.stale_timeout_minutes: 30` in config). On resume, if the pending escalation is older than the timeout, automatically offer "skip" as the default option rather than requiring the user to explicitly choose. This prevents workflow stalls when users forget about pending escalations.

**File:** `orchestrator-loop.md` (lines 16-35)

---

### F6: Tri-CLI Synthesis Grouping Uses Undefined "Semantic Similarity"

**Severity:** MEDIUM
**Category:** Output Validation / Algorithmic Ambiguity

**Current state:** The CLI dispatch synthesis algorithm (cli-dispatch-pattern.md line 199) states: `finding_groups = GROUP(all_findings by topic_similarity)`. The term "topic_similarity" is not defined -- there is no algorithm specified for how findings from three different CLIs are grouped as semantically related. This is the most critical step in tri-CLI synthesis (it determines which findings are "unanimous" vs "unique"), yet it relies on undefined heuristics.

**Recommendation:** Define the grouping algorithm explicitly. Options include: (1) keyword-based grouping using shared entity/component names (similar to the MPA Jaccard approach), (2) structured output format where CLIs use a shared taxonomy of finding categories (e.g., "performance/latency", "security/auth", "maintainability/coupling"), or (3) coordinator-level judgment with explicit criteria (e.g., "two findings are related if they reference the same component AND the same concern category"). Option 2 is the most reliable -- add a finding taxonomy to the CLI role prompt templates.

**File:** `cli-dispatch-pattern.md` (line 199)

---

### F7: 20+ Agents May Be Over-Specialized for the Coordination Overhead

**Severity:** LOW
**Category:** Agent Specialization Justification

**Current state:** SKILL.md (lines 179-203) lists 20+ specialized agents across 6 categories: Planning (5), Explorer (1), Judge (3), Reviewer (2), QA (3), plus CLI roles and the tech-writer/learnings-researcher specialists. Many of these are mode-gated (Complete/Advanced only), but the sheer count raises the question of whether the specialization is justified by proportional quality improvement.

The multi-agent patterns lens advises: "Could consensus problems (sycophancy, false agreement) occur in multi-agent steps?" and "Is the architecture simpler than it could be, or does it add coordination overhead without proportional value?" With 20+ agents, the risk of diminishing returns increases -- each additional perspective adds coordination overhead (dispatch, synthesis, conflict resolution) while providing incrementally less unique insight.

**Recommendation:** Add a "Justification" or "Unique Value" column to the MPA Agents table in SKILL.md that briefly explains what each agent provides that no other agent covers. This forces periodic review of whether agents are truly orthogonal. Consider auditing whether the `flow-analyzer` and `learnings-researcher` agents (both flagged as optional/mode-gated) have produced unique findings in past sessions that were not covered by other agents.

**File:** `SKILL.md` (lines 179-203)

---

### F8: Phase Gate Loop-Back Target Asymmetry

**Severity:** LOW
**Category:** Failure Propagation

**Current state:** When a RED gate is encountered (orchestrator-loop.md line 78), the loop-back targets are asymmetric: Phase 6 RED loops back to Phase 4, but Phase 8 RED loops back to Phase 7. The Phase 6 -> Phase 4 loop skips Phase 5 (ThinkDeep), meaning that after revising architecture in Phase 4, the deep analysis of Phase 5 is not re-run. If the architectural revision was significant, the ThinkDeep analysis from the first pass may be stale.

**Recommendation:** Document the rationale for skipping Phase 5 on Phase 6 RED loop-back. If the rationale is "ThinkDeep adds latency and the Phase 4 revision is typically minor," state this explicitly. If significant architectural revisions do occur after Phase 6 RED, consider a conditional re-dispatch of Phase 5 when the Phase 4 revision changes more than N% of the design.md content (measurable via diff).

**File:** `orchestrator-loop.md` (line 78)

---

### F9: State File Lock Protocol Lacks Implementation Detail

**Severity:** LOW
**Category:** Coordination / State Management

**Current state:** SKILL.md Critical Rule 5 (line 48) states: "Acquire lock at start, release at completion. Check for stale locks (>60 min)." However, the orchestrator-loop.md file contains no implementation of lock acquisition, release, or stale lock detection. The state file format (`{FEATURE_DIR}/.planning-state.local.md`) is a markdown file with YAML frontmatter -- there is no `.lock` file or lock field defined.

**Recommendation:** Either implement the lock protocol (add a `lock` section to the state YAML with `acquired_at`, `owner`, and implement stale check in the dispatch loop) or remove the critical rule if concurrent execution is not a realistic scenario. Dead rules reduce trust in the specification.

**File:** `SKILL.md` (line 48), `orchestrator-loop.md`

---

### F10: Context Pack Builder Provides Valuable Cross-Phase Memory

**Severity:** INFO
**Category:** Information Flow (Positive)

**Current state:** The S6 Context Protocol (orchestrator-loop.md lines 196-238) accumulates decisions, questions, and risks from prior phase summaries and injects them into coordinator dispatch prompts with per-category token budgets. This is an excellent implementation of the "summary-as-context-bus" pattern from the multi-agent patterns lens. The truncation strategies (keep high-confidence decisions first, high-priority questions first, high-severity risks first) are well-designed for maintaining signal quality under budget constraints.

**File:** `orchestrator-loop.md` (lines 196-238)

---

### F11: ADR Documents Trade-offs and Simplification Triggers

**Severity:** INFO
**Category:** Architectural Documentation (Positive)

**Current state:** The Architecture Decision Record in orchestrator-loop.md (lines 387-403) explicitly documents: (1) the chosen approach (delegation), (2) the alternative considered (inline loading), (3) why delegation was chosen (fault isolation, future parallelism, clean summary contract), (4) trade-offs accepted (latency, doubled dispatch for interactive phases), and (5) a simplification trigger ("if coordination overhead becomes problematic, migrate to inline for non-interactive phases"). This is exemplary architectural documentation that enables future maintainers to make informed decisions about when to simplify.

**File:** `orchestrator-loop.md` (lines 387-403)

---

### F12: Requirements Digest Injection Ensures Baseline Context

**Severity:** INFO
**Category:** Information Flow (Positive)

**Current state:** The orchestrator injects a requirements digest (~300 tokens from spec.md) into every coordinator dispatch prompt (orchestrator-loop.md lines 241-252, SKILL.md Critical Rule 11). After Phase 3, this digest is updated with user clarifications from `requirements-anchor.md`. This ensures every coordinator has baseline requirements visibility without reading the full spec, preventing the common failure mode where downstream phases lose sight of original requirements.

**File:** `SKILL.md` (line 54), `orchestrator-loop.md` (lines 241-252)

---

## Summary

The feature-planning skill implements a well-structured supervisor/orchestrator pattern that successfully addresses the primary multi-agent concern of context isolation. The 78% context reduction through delegation, the parameterized shared patterns (MPA synthesis, CLI dispatch), and the multi-layered error recovery demonstrate mature architectural thinking.

The most significant issues are:

1. **User interaction relay overhead (F1)** -- the re-dispatch cost for interactive phases is a meaningful performance concern affecting 7 of 11 phases.
2. **Dual-channel information flow ambiguity (F2)** -- the gap between the stated "summary-only" rule and the actual "coordinators read full artifacts" behavior creates confusion about the true dependency graph.
3. **Undefined synthesis grouping (F6)** -- the most critical step in tri-CLI synthesis lacks an explicit algorithm.

The architecture is appropriately complex for its scope (9+ phases, multi-mode analysis, V-Model test planning, CLI integration). The mode hierarchy (Complete -> Rapid) provides a natural complexity dial that allows simpler projects to avoid unnecessary coordination overhead. The explicit ADR with simplification triggers (F11) shows awareness that this complexity is a trade-off, not a permanent commitment.
