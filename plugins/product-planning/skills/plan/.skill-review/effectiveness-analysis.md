---
lens: "Overall Effectiveness"
lens_id: "effectiveness"
skill_name: "feature-planning"
skill_version: "3.0.0"
skill_path: "plugins/product-planning/skills/plan"
skill_reference: "customaize-agent:agent-evaluation"
fallback_used: true
date: "2026-03-01"
files_reviewed:
  - "SKILL.md"
  - "references/orchestrator-loop.md"
  - "references/phase-1-setup.md"
  - "references/phase-9-completion.md"
findings_count:
  critical: 0
  high: 2
  medium: 4
  low: 3
  info: 0
strengths_count: 5
---

# Overall Effectiveness Analysis: feature-planning

## Summary

The feature-planning skill is a sophisticated 9-phase orchestrator that transforms feature specifications into actionable implementation plans with integrated V-Model test strategy. It demonstrates advanced engineering in delegation patterns, state management, crash recovery, and multi-tool integration. The skill clearly states its purpose and delivers a comprehensive workflow that would produce high-quality planning artifacts.

However, several effectiveness gaps reduce its reliability in real-world execution: ambiguous coordinator prompt variable resolution, incomplete error recovery for edge cases in the completion phase, and a complex conditional feature matrix that creates combinatorial paths difficult for Claude to navigate consistently.

## Evaluation Criteria (Fallback)

The following fallback criteria were used because the `customaize-agent:agent-evaluation` skill was not available:

1. Does the skill clearly state its purpose and deliver on it?
2. Would Claude follow these instructions correctly in a real scenario?
3. Are edge cases, error paths, and "when NOT to use" scenarios covered?
4. Is the skill internally consistent (no contradictory instructions)?
5. Does the skill provide enough context for Claude to make good decisions?
6. Is the skill complete -- or are there obvious gaps in coverage?

---

## Strengths

### S1: Exceptionally Clear Delegation Architecture

The lean orchestrator pattern is well-designed. SKILL.md stays under 300 lines of core logic, acting as a dispatch table rather than embedding procedural detail. The Phase Dispatch Table (lines 129-141 of SKILL.md) is an exemplary reference -- any developer or Claude instance can immediately see which phases are delegated, which are inline, what prior summaries feed each phase, and what checkpoint it produces. The separation between orchestrator (summary-only context) and coordinators (full artifact access) is enforced both by design and by explicit rules (Critical Rules 9 and 10).

### S2: Robust State Management and Resume

The state file design with immutable user decisions, v1-to-v2 auto-migration, and checkpoint-based resume is production-grade. The lock protocol with stale timeout (60 min) prevents concurrent execution issues. The orchestrator loop's crash recovery function (reconstructing summaries from artifacts when coordinators fail to write them) demonstrates defensive programming that real-world usage demands.

### S3: Graceful Degradation Chain

The skill handles missing dependencies with a clear degradation hierarchy: if CLIs are unavailable, fall back to internal agents; if ST MCP is unavailable, fall back to inline reasoning; if research MCP is unavailable, use internal knowledge. Each degradation point is explicitly documented with a LOG statement, ensuring traceability. Phase 1 (Steps 1.5, 1.5b, 1.5c, 1.5d) thoroughly probes the environment before committing to a mode.

### S4: Comprehensive V-Model Integration

The V-Model test planning is deeply integrated rather than bolted on. The workflow diagram (lines 73-119 of SKILL.md) visually maps each planning phase to its corresponding test level. Phase 9's TDD structure (TEST -> IMPLEMENT -> VERIFY per task) with explicit test ID extraction and traceability matrix generation ensures that test artifacts are not orphaned -- every test ID must map to a task and vice versa.

### S5: Well-Defined Summary Contract

The summary convention (lines 165-168 of SKILL.md) and validation logic in orchestrator-loop.md (lines 378-385) create a reliable inter-phase communication protocol. Required fields are enumerated, validation failure triggers user-facing options (retry/continue/abort), and the context pack builder (S6 feature flag) accumulates decisions, questions, and risks across phases with explicit token budgets per category.

---

## Findings

### F1: Coordinator Prompt Variable Resolution is Ambiguous

**Severity:** HIGH
**Category:** Instruction-following quality
**File:** `references/orchestrator-loop.md` (lines 254-278)

**Current state:** The coordinator dispatch prompt template uses placeholder variables like `{phase_name}`, `{relevant_flags_and_values}`, `{FEATURE_DIR}`, and `{analysis_mode}` without specifying where each variable is sourced from or what format it should take. For example:

```
Feature flags: {relevant_flags_and_values}
```

There is no instruction telling the orchestrator which flags are "relevant" for each phase, nor what format they should be rendered in (YAML? comma-separated? key=value pairs?).

**Recommendation:** Add a variable resolution table to the DISPATCH_COORDINATOR function, or cross-reference the phase file frontmatter's `feature_flags` array. For example: "For `{relevant_flags_and_values}`, read the dispatched phase file's frontmatter `feature_flags` array, then look up each flag's current value from `config/planning-config.yaml` and format as `flag_name: true/false` pairs." This ensures Claude does not guess which flags to include or omit.

---

### F2: Phase 9 Task Regeneration Has No Lock Release on Abort

**Severity:** HIGH
**Category:** Edge case / error path coverage
**File:** `references/phase-9-completion.md` (lines 66-110)

**Current state:** Step 9.0 (Task Regeneration Check) acquires a lock at line 93:
```
# Acquire lock for Phase 9 only
CREATE {FEATURE_DIR}/.planning.lock
```

But the two abort paths (lines 99-101 and lines 103-105) set `status: needs-user-input` and return to the orchestrator without releasing the lock. If the user chooses to abort after seeing "Planning not complete" or "No planning state found", the lock file remains, blocking future planning sessions until it goes stale (60 minutes).

**Recommendation:** Add explicit lock release before any abort path in Step 9.0. Alternatively, move lock acquisition to after all pre-condition checks pass (i.e., between line 95 "Proceed directly to Step 9.1" and the actual Step 9.1 start). This is consistent with the fail-fast principle -- do not acquire resources before validating preconditions.

---

### F3: Post-Planning Menu Option Handlers Are Orchestrator Responsibilities Described in Coordinator File

**Severity:** MEDIUM
**Category:** Internal consistency / architecture coherence
**File:** `references/phase-9-completion.md` (lines 582-671)

**Current state:** Step 9.10 sets `status: needs-user-input` with a 6-option menu, then describes "Option Handlers (executed by orchestrator after receiving user choice)" in the same coordinator instruction file. But the coordinator cannot execute these handlers (it has already returned to the orchestrator by setting needs-user-input), and the orchestrator only reads summary files, not phase instruction files.

The handlers reference launching agents (`security-analyst`, `simplicity-reviewer`), running git commands, and creating GitHub issues -- all orchestrator-level actions. Yet they are documented in a file the orchestrator never reads at this point.

**Recommendation:** Either (a) move the Option Handlers to `orchestrator-loop.md` as a "Post-Phase-9 Menu Handling" section that the orchestrator reads after receiving the user's choice, or (b) restructure Step 9.10 so the coordinator includes sufficient detail in its summary's `block_reason` field that the orchestrator can execute each option without reading the phase file. Currently, these handlers are effectively dead documentation.

---

### F4: Deep Reasoning Escalation Adds Cognitive Complexity Without Clear Mode Guard

**Severity:** MEDIUM
**Category:** Decision-making context for Claude
**File:** `references/orchestrator-loop.md` (lines 82-140)

**Current state:** The deep reasoning escalation logic in the gate failure path spans 58 lines of pseudocode with nested conditionals: check feature flag enabled, check analysis mode, check per-phase escalation count, check total escalation count, then determine escalation type through a three-way branch (architecture_wall vs algorithm_escalation vs circular_failure), each with its own sub-conditions. This is embedded within the already-complex gate failure handling path.

While each individual branch is documented, the combined decision tree is difficult for Claude to hold in context alongside the main dispatch loop. In a real execution, Claude would need to evaluate 6+ conditions to determine whether to offer escalation, what type, and what template to use.

**Recommendation:** Extract the deep reasoning eligibility check into a named function (e.g., `DETERMINE_ESCALATION_ELIGIBILITY(phase, summary, config, state) -> EscalationType | null`) with a compact decision table format rather than nested if-else. This follows the same pattern used for CIRCUIT_BREAKER (lines 314-340) which successfully abstracts a reusable pattern. The function could return a simple struct `{type, template, target_phase}` or `null` if ineligible.

---

### F5: "When NOT to Use" Scenarios Are Absent

**Severity:** MEDIUM
**Category:** Coverage completeness
**File:** `SKILL.md`

**Current state:** The skill's frontmatter `description` field (line 3) lists trigger phrases ("plan a feature", "create an implementation plan", etc.) but nowhere does the skill define when it should NOT be invoked. For example:
- Should it be used for bug fixes? (Probably not -- but this is not stated.)
- Should it be used for documentation-only changes? (No, but unstated.)
- Should it be used when the user already has tasks and just wants test planning? (Unclear.)
- What if `spec.md` describes multiple independent features? (The skill assumes a single feature.)

**Recommendation:** Add a "When NOT to Use" section after the Quick Start (line 267). Include at minimum: (1) Bug fixes and hotfixes -- use a lighter workflow, (2) Documentation-only changes, (3) Features already planned (direct to task regeneration via Step 9.0 instead), (4) Multi-feature specs -- split first. This helps Claude avoid triggering the full 9-phase workflow for inappropriate requests.

---

### F6: Phase 9 Summary Report References Variables Not Available to Coordinator

**Severity:** MEDIUM
**Category:** Instruction-following quality
**File:** `references/phase-9-completion.md` (lines 518-567)

**Current state:** The summary report template at Step 9.8 references variables that come from phases the coordinator never reads:
- `{selected_approach}` -- from Phase 4 architecture selection (not in Phase 9's prior_summaries)
- `{score}/20` -- from Phase 6 validation (not in prior_summaries)
- `{coverage_score}%` -- from Phase 8 coverage validation (in prior_summaries)

Phase 9's frontmatter lists prior_summaries as phase-7, phase-8, and phase-8b only. It does not include phase-4 or phase-6 summaries. So `{selected_approach}` and `{score}/20` are not available to the coordinator unless it reads additional files beyond its contract.

**Recommendation:** Either (a) add phase-4-summary.md and phase-6-summary.md to Phase 9's `prior_summaries` frontmatter so the coordinator has access to architecture and validation data, or (b) simplify the summary report to only reference data available from the listed prior summaries (phases 7, 8, 8b) plus the artifacts the coordinator reads (design.md, plan.md, tasks.md). Option (a) is preferred since the completion report should be comprehensive.

---

### F7: CLI Smoke Test Uses /dev/null as Prompt File

**Severity:** LOW
**Category:** Edge case coverage
**File:** `references/phase-1-setup.md` (lines 121-123)

**Current state:** The CLI smoke test runs:
```
Bash("{SCRIPT} --cli gemini --role smoke_test --prompt-file /dev/null --output-file /tmp/cli-smoke-gemini.txt --timeout 30")
```

Passing `/dev/null` as `--prompt-file` means the dispatch script receives an empty prompt. Depending on the CLI's behavior, this could succeed (proving the CLI is installed) or fail with a confusing error (some CLIs reject empty prompts). The success/failure semantics are defined only by exit code 3 meaning "CLI not found", but a CLI that is installed but rejects empty input would return a non-3 exit code, passing the check despite potentially being misconfigured.

**Recommendation:** Document that the smoke test is intended to verify binary availability only (not correct configuration). Consider using a minimal non-empty prompt (e.g., writing "echo test" to a temp file) to avoid CLI-specific empty-input handling issues, or add a comment clarifying that any non-3 exit code counts as "available" regardless of actual output.

---

### F8: Phase 1 Has 8 Sub-Steps Creating a Long Inline Execution

**Severity:** LOW
**Category:** Instruction-following quality
**File:** `references/phase-1-setup.md`

**Current state:** Phase 1 is designated as "inline" (executed directly in the orchestrator context), yet it contains 8 sub-steps (1.1 through 1.8), several of which have their own sub-steps (1.5b has 4 steps, 1.5c has 6 steps, 1.5d has 4 steps, 1.6 has 5 steps). The total instruction length for Phase 1 alone is approximately 460 lines. This is a significant amount of procedural detail for the orchestrator to hold in context alongside the dispatch loop logic from orchestrator-loop.md and the SKILL.md phase table.

The SKILL.md justification for inline execution is "avoid dispatch overhead" (line 123), but the context cost of 460 lines of Phase 1 instructions may offset the latency savings.

**Recommendation:** Consider splitting Phase 1 into two parts: Steps 1.1-1.4 (prerequisites, path detection, state detection, lock) remain truly inline as they are short and require orchestrator state. Steps 1.5-1.6 (MCP checks, CLI detection, dev-skills detection, algorithm detection, mode selection) could be delegated to a lightweight coordinator, reducing orchestrator context by approximately 350 lines. Alternatively, accept the current design but add a comment in SKILL.md acknowledging the trade-off explicitly.

---

### F9: Constitution Path Assumes Fixed Location

**Severity:** LOW
**Category:** Edge case coverage
**File:** `references/phase-1-setup.md` (line 34), `references/phase-9-completion.md` (line 125)

**Current state:** Phase 1 (Step 1.1) checks:
```
Constitution exists at specs/constitution.md
```

And Phase 9 (Step 9.1) reads:
```
specs/constitution.md (project conventions)
```

The path `specs/constitution.md` is hardcoded relative to the project root. If a project uses a different conventions file location (e.g., `docs/conventions.md`, `.github/CONTRIBUTING.md`), the skill will either error (Phase 1) or miss project conventions (Phase 9). The path is not externalized to `config/planning-config.yaml`.

**Recommendation:** Add `constitution_path` to `config/planning-config.yaml` with default value `specs/constitution.md`. Reference it via config in both Phase 1 and Phase 9. This follows the existing pattern where all configurable values live in the config file (Critical Rule 6).

---

## Overall Assessment

The feature-planning skill is a well-architected, production-quality orchestration system. Its core strengths -- delegation architecture, state management, graceful degradation, and V-Model integration -- demonstrate sophisticated prompt engineering. The skill clearly states its purpose and delivers on it for the primary use case.

The most impactful improvements would be:
1. **F1 (HIGH):** Resolving coordinator prompt variable ambiguity to ensure consistent dispatch behavior.
2. **F2 (HIGH):** Fixing the lock leak in Phase 9 regeneration abort paths.
3. **F3 (MEDIUM):** Relocating post-planning menu handlers to where the orchestrator can actually read and execute them.
4. **F5 (MEDIUM):** Adding "when NOT to use" guidance to prevent inappropriate invocations.

The skill's complexity is its double-edged sword: the extensive feature flag system, multi-CLI dispatch, deep reasoning escalation, and context protocol create impressive capability but also create a large combinatorial space that Claude must navigate. Each additional conditional path increases the risk of instruction-following errors. The current design manages this well through modularity (separate reference files per phase), but the orchestrator-loop.md file in particular is approaching the limit of what a single reference file should contain.
