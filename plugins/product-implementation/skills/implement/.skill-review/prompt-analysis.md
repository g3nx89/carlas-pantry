---
lens: "Prompt Engineering Quality"
lens_id: "prompt"
skill_reference: "customaize-agent:prompt-engineering"
target: "feature-implementation"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-implementation/skills/implement"
fallback_used: true
findings_count: 14
critical_count: 0
high_count: 3
medium_count: 6
low_count: 3
info_count: 2
---

# Prompt Engineering Quality Analysis: feature-implementation

## Summary

The feature-implementation skill is a well-architected lean orchestrator with strong prompt engineering fundamentals: explicit variable contracts, structured output formats, and clear delegation boundaries. However, several prompt templates exhibit ambiguity in conditional behavior, the orchestrator loop uses pseudocode that leaves key branching decisions under-specified for an LLM executor, and the volume of optional/conditional features creates cognitive load that risks the LLM losing track of the critical path. Three high-severity findings relate to ambiguous decision logic in the orchestrator loop, missing structured output contracts in coordinator dispatch prompts, and inconsistent fallback specification patterns across agent prompts.

## Findings

### 1. Orchestrator Loop Pseudocode Relies on Implicit Programming Semantics
- **Severity**: HIGH
- **Category**: LLM instruction effectiveness
- **File**: `references/orchestrator-loop.md`
- **Current**: The dispatch loop (lines 8-69) is written in pseudocode with programming constructs (`FOR`, `IF/ELIF/ELSE`, `SET`, `FUNCTION`) that assume sequential imperative execution. For example: `IF infra_action == "retry_then_continue": RETRY stage once, then continue with degraded summary` packs two actions and a conditional outcome into a single line. The `DISPATCH_COORDINATOR` function builds a prompt via string interpolation with `{for each summary in prior_summaries: ...}` which is a loop-inside-a-template that an LLM must interpret as both a code generation instruction and an iteration directive simultaneously.
- **Recommendation**: Rewrite the dispatch loop as a numbered step list with explicit decision trees rather than nested pseudocode. Replace `IF/ELIF/ELSE` chains with decision tables or flowchart-style "If X, go to Step N" instructions. For the coordinator prompt template, show a concrete example of a fully-expanded prompt (with 2 prior summaries filled in) alongside the parameterized version, so the LLM has an unambiguous model of the expected output.

### 2. Coordinator Dispatch Prompt Lacks Structured Output Contract for the Coordinator Itself
- **Severity**: HIGH
- **Category**: Instruction clarity and unambiguity
- **File**: `references/orchestrator-loop.md`
- **Current**: The `DISPATCH_COORDINATOR` function (lines 74-136) builds a prompt that tells the coordinator to "Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/{stage_file}" and lists 5 output contract points. However, the output contract only specifies *what* to write (artifacts, summary, template), not *how* the coordinator should structure its own response back to the orchestrator. The orchestrator then reads the summary file, but there is no instruction to the coordinator about what to include in its direct Task() return value. The orchestrator's crash recovery checks "IF key artifacts exist on disk" but never inspects the Task() return value.
- **Recommendation**: Add an explicit instruction to the coordinator prompt: "Your direct response is not read by the orchestrator. All output MUST be persisted to files. Do not include critical information only in your response text." This eliminates ambiguity about whether the coordinator's stdout matters. Additionally, add a 6th output contract point: "6. If you encounter an error that prevents summary writing, your LAST line must be: `COORDINATOR_ERROR: {description}` so the orchestrator can detect failure without relying solely on file existence checks."

### 3. Inconsistent Fallback Specification Patterns Across Agent Prompts
- **Severity**: HIGH
- **Category**: Degrees of freedom / instruction specificity
- **File**: `references/agent-prompts.md`
- **Current**: Variable fallback text is specified differently across prompts. The Phase Implementation Prompt specifies fallbacks inline in the Variables section (e.g., `{context_summary}` fallback: `"No context summary available -- read planning artifacts from FEATURE_DIR as needed."`). The Quality Review Prompt specifies `{reviewer_stance}` fallback: `"No specific stance assigned -- review objectively using your best judgment."` But the Review Fix Prompt and Incomplete Task Fix Prompt have NO fallback specifications for any variables, and the Code Simplification Prompt specifies fallback only for `{skill_references}` but not for `{modified_files_list}` (what happens if the list is empty?). This inconsistency means coordinators filling these prompts must guess fallback behavior for under-specified variables.
- **Recommendation**: Establish a uniform fallback convention: every variable in every prompt template must have either (a) a "Fallback if unavailable" annotation, or (b) a "Required -- always available" annotation. For the Review Fix Prompt and Incomplete Task Fix Prompt, add explicit notes: "All variables are required -- the coordinator MUST NOT dispatch this prompt if any variable cannot be populated." For `{modified_files_list}` in the Code Simplification Prompt, add: "If the filtered file list is empty, the coordinator skips this dispatch entirely (see Step 3.5 eligibility check)."

### 4. Stage 2 Phase Loop Overloads a Single Coordinator with Excessive Conditional Branching
- **Severity**: MEDIUM
- **Category**: Prompt structure and logical flow
- **File**: `references/stage-2-execution.md`
- **Current**: The Stage 2 coordinator must execute Steps 1 through 5 in a loop, but Steps 1.8, 3.5, 3.6, and 3.7 are all conditional with multi-gate checks (3-5 boolean conditions each). Step 3.7 alone spans ~150 lines with sub-procedures for APK build, install, evidence directory setup, CLI dispatch, result processing with policy-aware severity gating, and non-skippable gate checks. The coordinator must hold all of this conditional logic in context while also managing the core phase loop, developer agent dispatch, and progress tracking.
- **Recommendation**: Add a "Critical Path Summary" section at the top of stage-2-execution.md (after the frontmatter) that lists ONLY the mandatory steps: "Steps 1, 2, 3, 4, 5 are the critical path. Steps 1.8, 3.5, 3.6, 3.7 are conditional extensions -- check their gate conditions and skip if not met. When in doubt about a conditional step, skip it." This gives the LLM a mental model of the essential flow before it encounters the conditional complexity.

### 5. Autonomy Policy Decision Tree Scattered Across Multiple Files
- **Severity**: MEDIUM
- **Category**: Prompt structure and logical flow
- **File**: `SKILL.md` (references: `orchestrator-loop.md`, `stage-2-execution.md`)
- **Current**: The autonomy policy is defined in SKILL.md (lines 250-266) as a table with three levels. The orchestrator-loop.md references it via `LOOKUP policy infrastructure action from config`. Stage-2-execution.md implements it inline for code simplification rollback (Step 3.5, lines 251-254) and UAT severity gating (Step 3.7, lines 426-441). Each implementation location re-describes the policy lookup and action mapping slightly differently. The Stage 2 simplification handling even includes a parenthetical justification for why all policy levels auto-revert (line 253), mixing rationale with instructions.
- **Recommendation**: Extract a single "Autonomy Policy Decision Procedure" into a shared reference (similar to `cli-dispatch-procedure.md` and `auto-commit-dispatch.md`). Each stage file would then reference: "Apply the Autonomy Policy Decision Procedure (see `references/autonomy-policy-procedure.md`) with `finding_severity={severity}`, `finding_type={type}`." This prevents drift between implementations and removes the need for inline policy logic in every stage file.

### 6. Phase Implementation Prompt Contains Dual-Purpose Instructions Mixed with Context
- **Severity**: MEDIUM
- **Category**: Instruction clarity and unambiguity
- **File**: `references/agent-prompts.md`
- **Current**: The Phase Implementation Prompt (lines 12-76) mixes contextual setup (Goal, Planning Context, Test Specifications, Research Context) with behavioral rules (Build Verification Rule, API Existence Verification, Test Quality Requirements, Animation Testing, Pattern Bug Fix Propagation, Final Step). The behavioral rules are embedded inline within the prompt template itself rather than being part of the agent's base instructions (in `agents/developer.md`). This means every developer dispatch repeats ~40 lines of behavioral rules, consuming tokens and creating a risk of divergence if the agent file also states similar rules.
- **Recommendation**: Verify whether `agents/developer.md` already contains these behavioral rules. If so, remove the duplicates from the prompt template and add a single line: "Follow all behavioral rules from your agent definition (Build Verification, API Verification, Test Quality, etc.)." If not, move the 6 behavioral rule sections to `agents/developer.md` and reference them from the prompt. Either way, the prompt template should focus on phase-specific context injection, not repeated behavioral instructions.

### 7. "Read and Execute" Delegation Pattern Assumes Faithful Multi-Step Following
- **Severity**: MEDIUM
- **Category**: LLM instruction effectiveness
- **File**: `references/orchestrator-loop.md`
- **Current**: The coordinator prompt (line 109) says `Read and execute: $CLAUDE_PLUGIN_ROOT/skills/implement/references/{stage_file}`. This is a two-step meta-instruction: first read a file, then follow its contents as instructions. For long stage files (stage-2-execution.md is 41KB), the LLM must read the entire file into context and then execute it faithfully. There is no verification mechanism to confirm the coordinator actually read the file, and no prioritization guidance for what to do if the file exceeds the coordinator's effective context window.
- **Recommendation**: Add explicit guardrails to the coordinator prompt: "After reading the stage reference file, confirm you have read it by listing the section headers you found. If the file is too large to process fully, prioritize sections in numerical order and note which sections you could not process." This provides a verification hook and graceful degradation path.

### 8. Quality Review Prompt Escalation Triggers Could Cause Classification Paralysis
- **Severity**: MEDIUM
- **Category**: Degrees of freedom / instruction specificity
- **File**: `references/agent-prompts.md`
- **Current**: The Quality Review Prompt (lines 245-249) defines High-severity escalation triggers: "ESCALATE a finding to High (not Medium) if ANY of these apply: user-visible data corruption, implicit ordering producing wrong results, UI state contradiction, singleton/shared-state leak across scopes, race condition with user-visible effect." Then line 249 says: "Apply escalation triggers BEFORE classifying." This creates a two-pass classification requirement: first check triggers, then classify. But the triggers themselves are subjective ("implicit ordering producing wrong results" -- how implicit is implicit?), and there is no guidance for when a trigger *almost* applies.
- **Recommendation**: Reframe the escalation triggers as concrete examples rather than abstract categories. For instance, replace "implicit ordering producing wrong results" with "Example: iterating over a HashMap/Set where order matters for output correctness." Add a tiebreaker: "When uncertain whether an escalation trigger applies, classify as Medium and add a note: 'Potential High -- {trigger_name} may apply.'" This gives the reviewer a safe default instead of forcing a binary decision.

### 9. Retrospective Composition Prompt Style Guidelines Use Emoji References
- **Severity**: MEDIUM
- **Category**: Instruction clarity and unambiguity
- **File**: `references/agent-prompts.md`
- **Current**: Line 529 states: "Use traffic light emoji for visual scanning: green circle, yellow circle, red circle." This describes emoji by name rather than providing the actual characters, which means the LLM must infer which Unicode characters to use. Different models may interpret "green circle" differently (solid circle vs. checkmark vs. colored dot).
- **Recommendation**: Provide the exact emoji characters in the instruction: "Use traffic light emoji for visual scanning: \U0001F7E2 (green), \U0001F7E1 (yellow), \U0001F534 (red)." Alternatively, define a non-emoji convention: "Use `[GREEN]`, `[YELLOW]`, `[RED]` text markers for traffic lights" to avoid rendering inconsistencies across environments.

### 10. Auto-Commit Prompt Safety Rules Are Negative-Only
- **Severity**: LOW
- **Category**: Use of examples vs. rules
- **File**: `references/agent-prompts.md`
- **Current**: The Auto-Commit Prompt (lines 417-421) lists 5 "NEVER" rules (never push, never amend, never force, never no-verify, never modify git config). While these are important guardrails, the prompt contains no positive examples of what a successful commit looks like. The structured output format (lines 425-431) helps, but there is no example of a complete successful run.
- **Recommendation**: Add a brief example block after the Safety Rules: "Example successful run: `git status` shows 3 modified files, `git add src/auth.kt src/auth_test.kt specs/001/tasks.md`, `git commit -m 'feat(001): Phase 1 setup'`, output: `commit_status: success, commit_sha: abc1234, files_committed: 3, reason: Phase 1 changes committed`." This gives the subagent a concrete success model.

### 11. Stage Dispatch Table "User Interaction" Column Uses Ambiguous "Policy-gated" Label
- **Severity**: LOW
- **Category**: Instruction clarity and unambiguity
- **File**: `SKILL.md`
- **Current**: The Stage Dispatch Table (lines 99-106) uses "Policy-gated" in the User Interaction column for Stages 2-5, but "Policy question (1.9a)" for Stage 1 and "None" for Stage 6. "Policy-gated" is not defined in the table itself -- the reader must understand the Autonomy Policy section (50+ lines later) to interpret what "Policy-gated" means for each stage. The meaning differs: Stage 2 policy-gating means auto-resolving build/test failures, Stage 4 means auto-accepting low findings, Stage 5 means auto-deciding on incomplete tasks.
- **Recommendation**: Replace "Policy-gated" with stage-specific descriptions in the table: Stage 2: "Auto-resolve per policy (build/test failures)", Stage 3: "Auto-resolve per policy (validation gaps)", Stage 4: "Auto-resolve per policy (review findings)", Stage 5: "Auto-resolve per policy (incomplete tasks, doc approval)". This makes the table self-contained without requiring cross-referencing.

### 12. SKILL.md Reference Map "When to Read" Column Has Overlapping Guidance
- **Severity**: LOW
- **Category**: Prompt structure and logical flow
- **File**: `SKILL.md`
- **Current**: The Reference Map (lines 270-284) states `orchestrator-loop.md` should be read at "Workflow start (always)" and `stage-1-setup.md` at "Stage 1 (inline)". But the orchestrator loop contains the dispatch logic for ALL stages including Stage 1 inline execution. The "always" qualifier for orchestrator-loop.md is correct but could lead the LLM to read both files upfront at workflow start, front-loading ~40KB of reference content before any work begins.
- **Recommendation**: Add a sequencing note: "Read `orchestrator-loop.md` first to understand the dispatch loop. Read stage reference files only when that stage is reached -- do not preload all stage files." This explicit sequencing instruction prevents eager context loading.

### 13. Comprehensive Variable Documentation in Agent Prompts
- **Severity**: INFO
- **Category**: Instruction clarity and unambiguity
- **File**: `references/agent-prompts.md`
- **Current**: Every prompt template includes a detailed Variables section listing each variable with its source, type, and fallback behavior. The Phase Implementation Prompt (lines 78-89) is exemplary: each variable specifies where it comes from (e.g., "From Stage 1 summary 'Context File Summaries' section"), what it contains, and what to use as a fallback. The "Agent behavior" paragraph after each prompt provides a natural-language summary of expected execution.
- **Recommendation**: None -- this is a strength. The pattern of "template + variable list + agent behavior summary" provides three complementary views of the same instruction, reducing misinterpretation risk.

### 14. Effective Use of Structured Output Formats Throughout
- **Severity**: INFO
- **Category**: Use of examples vs. rules
- **File**: `references/agent-prompts.md`, `references/stage-2-execution.md`
- **Current**: Multiple prompts require structured output in specific formats: `test_count_verified: {N}` / `test_failures: {M}` in the Phase Implementation Prompt, `commit_status: {success|failed|skipped}` / `commit_sha: {sha or null}` in the Auto-Commit Prompt, and the Quality Review Prompt's `- [{severity}] {description} -- {file}:{line} -- Recommendation: {fix}` format. The Stage 2 summary template (lines 589-658) provides a complete YAML example with comments explaining each field.
- **Recommendation**: None -- this is a strength. Structured output formats with explicit field names, types, and allowed values (e.g., `{success|failed|skipped}`) are among the most effective prompt engineering patterns for reliable LLM output parsing.

## Strengths

1. **Explicit variable contracts with fallback discipline** -- The agent-prompts.md file establishes a rigorous pattern where each prompt template lists every variable with its source location, data type, and fallback value. This is particularly well-executed for the Phase Implementation Prompt, which has 10 variables each with clear sourcing instructions. The fallback pattern ("Fallback if unavailable: {text}") ensures prompts are always well-formed even when optional artifacts are missing, and the requirement to list variables explicitly (not "Same as X Prompt") prevents silent omissions during coordinator prompt assembly.

2. **Summary-as-context-bus architecture** -- The design where Stage 1 writes a structured summary that becomes the single context source for all downstream coordinators is an excellent prompt engineering pattern. It means each coordinator receives a curated, token-budgeted context block rather than raw artifacts. The Stage 2 summary template (with its extensive YAML structure and "Context for Next Stage" prose section) demonstrates sophisticated inter-agent communication design that balances machine-readability (YAML flags) with LLM-readability (prose summaries).

3. **Layered instruction architecture (hub-spoke)** -- SKILL.md stays lean at ~300 lines as a dispatch table and critical rules reference, delegating procedural detail to stage-specific reference files. This prevents the primary skill file from overwhelming the LLM with detail it does not yet need. The Reference Map table provides a clear "when to read" guide that supports just-in-time context loading rather than upfront bulk loading.

4. **Behavioral rules embedded directly in prompts** -- While Finding 6 notes the token cost of repeating behavioral rules in prompts, the pattern itself is sound for reliability: rules like "Build Verification Rule" and "Test Quality Requirements" appear at the point of use rather than relying on the agent remembering separate instructions. For critical behavioral constraints (never write placeholder tests, always compile before marking done), proximity to the task instruction is more reliable than distant reference.
