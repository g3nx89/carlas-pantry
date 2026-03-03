---
lens: overall-effectiveness
target_skill: feature-specify
target_path: plugins/product-definition/skills/specify
files_read:
  - SKILL.md
  - references/orchestrator-loop.md
  - references/error-handling.md
  - references/stage-4-clarification.md
  - references/stage-1-setup.md
  - references/README.md
fallback_used: true
finding_counts:
  critical: 1
  high: 3
  medium: 3
  low: 2
  info: 0
strength_count: 5
---

# Overall Effectiveness Analysis: feature-specify

## Summary

The feature-specify skill is a mature, well-architected orchestration system for producing feature specifications through a 7-stage coordinator-delegated workflow. It demonstrates strong architectural discipline with the lean orchestrator pattern, comprehensive error handling, and thoughtful state management. The skill clearly achieves its stated purpose of guiding feature specification creation with Figma integration, multi-CLI validation, and V-Model test strategy generation.

However, effectiveness is impacted by several issues: contradictory instructions around user interaction rules, a terminology migration that is incomplete (PAL vs CLI references), ambiguity in the iteration loop's convergence guarantees, and a dispatch template that may overwhelm coordinator context for later stages. These findings range from a critical internal contradiction to medium-level polish opportunities.

Overall effectiveness score: **7.5/10** -- the skill would produce correct output in most scenarios, but the contradictions and ambiguities identified below create real risk of incorrect Claude behavior in edge cases.

---

## Findings

### Finding 1: Contradictory User Interaction Rules in Stage 4

**Severity:** CRITICAL
**Category:** Internal Consistency / Instruction-Following Quality
**File:** `references/stage-4-clarification.md`

**Current state:** Stage 4's CRITICAL RULES state at line 28: "NEVER interact with users directly: Return `status: needs-user-input, pause_type: file_based` after writing question file." However, Step 4.0 (Figma Mock Gap Resolution) at lines 88-109 uses `pause_type: "interactive"` and explicitly instructs the coordinator to present an interactive question to the user. The CRITICAL RULES REMINDER at the end (line 524) repeats: "NEVER interact with users directly -- except Step 4.0 via `status: needs-user-input`." While the reminder adds the Step 4.0 exception, it arrives after 500+ lines. A coordinator encountering Step 4.0 may refuse to execute the interactive pause because Rule 6 says "NEVER" without qualification.

Additionally, Step 4.0a (RTM Disposition Resolution, line 127) writes disposition questions to the clarification file -- which is correct and consistent with the file-based rule. But the coordinator must distinguish between Step 4.0 (interactive) and Step 4.0a (file-based) under conflicting top-level guidance. This creates a real risk of Claude either (a) refusing to execute Step 4.0's interactive pause, or (b) making all pauses interactive because it sees the Step 4.0 exception as overriding the general rule.

**Recommendation:** Amend Stage 4 CRITICAL RULE 6 to explicitly carve out the exception: "NEVER interact with users directly for clarification questions. Step 4.0 (Figma Mock Gap) uses `pause_type: interactive` -- this is the ONLY interactive pause in Stage 4." Place the exception directly in the rule, not 500 lines later in the reminder section.

---

### Finding 2: Incomplete PAL-to-CLI Terminology Migration

**Severity:** HIGH
**Category:** Completeness / Accuracy
**File:** `SKILL.md` (line 301), `references/stage-1-setup.md` (line 135), `references/error-handling.md` (line 17), `references/README.md` (line 17)

**Current state:** SKILL.md line 301 explicitly says: "CLI dispatch replaces PAL MCP -- `CLI_AVAILABLE` replaces `PAL_AVAILABLE` everywhere." However, several references still use "PAL" terminology:

- `SKILL.md` line 70: `limits.pal_rejection_retries_max` (config key)
- `SKILL.md` line 73-74: `thresholds.pal.green`, `thresholds.pal.yellow`
- `references/stage-1-setup.md` line 135 (Case C): "Re-run PAL Gate" as a user-facing option label
- `references/README.md` line 17: "PAL failures" in the error-handling description
- `references/error-handling.md` line 17: "PAL failures" section header description in file listing

This creates confusion for Claude about whether "PAL" and "CLI" are different systems or synonyms. A coordinator reading "pal_rejection_retries_max" in config may not map it to CLI dispatch behavior, especially since line 301 explicitly says the rename happened "everywhere."

**Recommendation:** Complete the terminology migration:
1. Rename config keys: `pal_rejection_retries_max` to `cli_rejection_retries_max`, `thresholds.pal.*` to `thresholds.cli_eval.*`
2. Update user-facing labels: "Re-run PAL Gate" to "Re-run CLI Validation"
3. Update README.md and error-handling.md descriptions to use "CLI" consistently
4. If config keys cannot change (backward compatibility), add a mapping note in `config-reference.md`

---

### Finding 3: No Convergence Guarantee for Iteration Loop

**Severity:** HIGH
**Category:** Edge Case Coverage
**File:** `references/orchestrator-loop.md` (lines 293-340)

**Current state:** The iteration loop between Stages 3 and 4 continues "until coverage >= 85% or user forces proceed." The stall detection triggers when improvement < 5% between iterations. However, there is no maximum iteration count or total-time circuit breaker. Combined with SKILL.md Rule 15 ("No Iteration Limits: Continue clarification loops until COMPLETE, not until a counter reaches max"), the system could theoretically loop indefinitely if:

- Coverage oscillates between 80% and 84% (each iteration adds some coverage but new checklist items are also discovered)
- The stall detection fires, but the user selects "Continue" each time
- A pathological spec with deeply interdependent requirements where resolving one gap creates another

While the stall detection partially addresses this, it only triggers when coverage improvement < 5%. A spec that improves by exactly 5% each iteration but never reaches 85% would never trigger stall detection and never terminate.

**Recommendation:** Add a soft circuit breaker in `orchestrator-loop.md`: after N iterations (e.g., 5, configurable), present the user with a summary of coverage trajectory and an explicit "force proceed" option, regardless of whether stall detection triggered. This preserves the "no artificial limits" principle (the user can always choose to continue) while preventing runaway loops. Add the threshold to `specify-config.yaml` as `limits.max_iterations_before_checkpoint` with a default of 5.

---

### Finding 4: Dispatch Template Context Bloat for Later Stages

**Severity:** HIGH
**Category:** Instruction-Following Quality
**File:** `references/orchestrator-loop.md` (lines 54-99)

**Current state:** The coordinator dispatch template (lines 82-86) includes "CONTENTS OF specs/{FEATURE_DIR}/.stage-summaries/stage-*-summary.md" -- meaning all prior stage summaries are injected verbatim into every coordinator's context. By Stage 6 or 7, this means 6 prior summaries are included. Even with the 500-char/1000-char size constraints (lines 136-141), this adds 6 * 1500 = ~9000 characters of prior context to every late-stage dispatch.

More importantly, the dispatch template also includes the full YAML frontmatter of the state file (line 88), which by Stage 6 contains accumulated `user_decisions`, `model_failures`, `iterations`, and RTM disposition arrays. For a spec with 20+ clarification questions and multiple iterations, this frontmatter could easily exceed 5000 characters.

This context bloat reduces the effective context window available for the coordinator's primary task and increases the risk of Claude losing focus on its stage-specific instructions.

**Recommendation:** Filter prior summaries to only include the immediately preceding stage summary and any stage summary explicitly needed by the current stage (defined in a "Required Prior Context" field per stage dispatch profile). For the state file, inject only the fields relevant to the current stage rather than the full frontmatter. Add a per-stage "required_state_fields" list to the dispatch profile table.

---

### Finding 5: Self-Verification Checklists Lack Failure Consequences

**Severity:** MEDIUM
**Category:** Instruction-Following Quality
**File:** `references/stage-4-clarification.md` (lines 504-514), `references/stage-1-setup.md` (lines 388-396)

**Current state:** Every stage file includes a "Self-Verification (MANDATORY before writing summary)" section with 5-7 verification checks. However, the instructions only say "BEFORE writing the summary file, verify:" followed by a checklist. They do not specify what the coordinator should do if a verification check fails. Should it:
- Retry the failed step?
- Write the summary with `status: failed`?
- Write the summary with `status: completed` but flag the issue?
- Attempt to fix the issue in-place?

Without explicit failure handling, Claude will likely write the summary as `completed` even when verification checks fail, since the instructions say to verify "before writing" but don't say "stop if verification fails."

**Recommendation:** Add explicit failure handling after each self-verification section: "If ANY verification check fails: (1) attempt to fix the issue by re-running the relevant step, (2) if fix fails, write summary with `status: failed` and `flags.block_reason` describing which verification failed, (3) NEVER write `status: completed` with failing verifications."

---

### Finding 6: RTM Disposition Gate Contradiction with Orchestrator Loop

**Severity:** MEDIUM
**Category:** Internal Consistency
**File:** `SKILL.md` (line 55, Rule 28), `references/orchestrator-loop.md` (lines 260-273)

**Current state:** SKILL.md Rule 28 states: "RTM Disposition Gate: Zero UNMAPPED requirements before proceeding past Stage 4. Every source requirement must have a conscious disposition." This reads as a hard blocking gate.

However, `orchestrator-loop.md` lines 260-273 implement this as a NON-BLOCKING notification: "This check is intentionally NON-BLOCKING (notification only, does not halt)." The rationale given is valid (avoiding infinite loops when the user chose not to answer), but it directly contradicts the SKILL.md rule which says "Zero UNMAPPED requirements before proceeding."

A coordinator reading Rule 28 would expect blocking behavior. The orchestrator reading `orchestrator-loop.md` would implement non-blocking behavior. Since coordinators and orchestrator may interpret differently, this creates a split-brain risk.

**Recommendation:** Align SKILL.md Rule 28 with the actual implementation. Change to: "RTM Disposition Gate: Zero UNMAPPED requirements before proceeding past Stage 4, enforced via the disposition question flow in Step 4.0a. If the user declines to resolve remaining UNMAPPED entries during clarification, the orchestrator proceeds with a non-blocking warning (reported in Stage 7)." This accurately describes the two-tier behavior: Stage 4 enforces the gate via questions, orchestrator post-Stage-4 check is a safety net.

---

### Finding 7: Missing "When NOT to Use" Guidance

**Severity:** MEDIUM
**Category:** Completeness / Decision Context
**File:** `SKILL.md`

**Current state:** The skill describes what it does (guided feature specification) but never describes when it should NOT be used. Claude (or a user) has no guidance on:
- Features too small for this workflow (e.g., a one-line config change)
- Features that already have complete specifications from another source
- Situations where the upstream PRD/requirements are still in flux (should /specify wait for /requirements to finish?)
- Partial runs: can /specify be used to add test strategy to an already-complete spec without re-running Stages 1-5?

Without "when NOT to use" guidance, Claude may launch the full 7-stage workflow for trivial changes or re-run completed stages unnecessarily.

**Recommendation:** Add a "When to Use / When NOT to Use" section after the description. Include: minimum feature complexity threshold, prerequisites (completed PRD or user input), relationship to the /requirements workflow, and guidance on partial re-runs (which the resume mechanism already supports but is not surfaced as a feature).

---

### Finding 8: Pre-flight Validation Checks Are Incomplete

**Severity:** LOW
**Category:** Edge Case Coverage
**File:** `references/stage-1-setup.md` (lines 53-72)

**Current state:** Pre-flight validation (Step 1.2) checks for the existence of 3 agents (`business-analyst`, `design-brief-generator`, `gap-analyzer`) and the prompt templates. However, it does not check for:
- `qa-strategist` agent (used in Stage 6)
- `gate-judge` agent (used in Stage 2)
- CLI dispatch script existence when CLI features are expected
- The `specify-config.yaml` config file itself
- Template files specifically referenced by name (e.g., `spec-template.md`, `requirements-inventory-template.md`)

Missing agents would cause a coordinator crash mid-workflow rather than failing fast at Stage 1.

**Recommendation:** Expand pre-flight validation to cover all 5 agents listed in the Agent References table and the config file. For optional components (qa-strategist when test strategy is disabled), validate conditionally.

---

### Finding 9: AskUserQuestion Format Inconsistency

**Severity:** LOW
**Category:** Accuracy / Instruction-Following Quality
**File:** `references/stage-1-setup.md` (lines 89-103, 126-139)

**Current state:** Stage 1 uses two different JSON formats for `AskUserQuestion` calls. Step 1.3 (Lock Detection, line 89) uses a `questions` array wrapping format: `{"questions": [{"question": "...", "header": "...", "options": [...]}]}`. Step 1.4 (State Detection, line 126) uses the same format. However, the orchestrator-loop.md summary handling (lines 195-209) shows AskUserQuestion with a flat format: `question: "...", header: "...", options: [...]` (no wrapping `questions` array).

The SKILL.md Summary Contract (lines 196-203) uses the flat `question_context` format. Since Stage 1 runs inline and other stages use the summary contract, this inconsistency may not cause runtime errors. But if a future refactor consolidates the patterns, Claude may produce malformed calls.

**Recommendation:** Standardize on a single AskUserQuestion format. Since the summary contract's `question_context` format (flat, no wrapping array) is used by all coordinator-delegated stages, update Stage 1's inline calls to match, or document that Stage 1 uses the raw API format while coordinators use the summary contract format.

---

## Strengths

### Strength 1: Exemplary Graceful Degradation Architecture

The skill systematically handles tool unavailability at every level: CLI dispatch, Sequential Thinking, Figma MCP, and individual CLI binaries. Each degradation path is explicitly documented with specific fallback behavior, user notifications, and state tracking. The `mcp_availability` state object and the `CLI_AVAILABLE` variable default system ensure that the workflow never crashes due to missing optional tools. This is one of the most thorough degradation architectures in the plugin ecosystem.

### Strength 2: Immutable User Decisions with Resume Compliance

The `user_decisions` system in the state file is exceptionally well-designed. Decisions are write-once (immutable), checked before any question is asked (Rule 2: "NEVER re-ask questions from `user_decisions`"), and persisted across crashes and re-invocations. The RTM disposition decisions follow the same pattern. This ensures users never experience the frustration of re-answering questions after a session interruption.

### Strength 3: Hub-Spoke Reference Architecture with Progressive Loading

The skill follows the lean orchestrator pattern precisely: SKILL.md is 302 lines (dispatch table + rules), with 17 reference files providing stage-specific detail. The Reference Map table and README.md cross-reference index make it straightforward to locate any piece of logic. The "Load When" column prevents unnecessary context loading, and the structural consistency across stage files (CRITICAL RULES at top and bottom, numbered steps, self-verification, summary contract) creates predictable behavior.

### Strength 4: File-Based Clarification with Auto-Resolve Intelligence

The decision to use file-based clarification (writing questions to markdown files for offline editing) rather than interactive Q&A is a significant UX improvement. Users can answer questions at their own pace, review BA recommendations, and override auto-resolved answers. The auto-resolve gate with citation requirements ensures that automatically answered questions are traceable and auditable. The three-tier classification (AUTO_RESOLVED, INFERRED, REQUIRES_USER) provides appropriate confidence signaling.

### Strength 5: Multi-Layer Quality Gates with Non-Blocking Design

The quality gate system operates at three levels: incremental gates within Stage 2 (Problem gate, True Need gate), coverage-based iteration gates between Stages 3-4, and CLI multi-stance evaluation in Stage 5. All gates are non-blocking by design -- they notify the user of issues but do not halt the workflow unilaterally. This respects user autonomy while ensuring quality signals are never silently swallowed. The stall detection mechanism for the iteration loop adds practical convergence awareness.
