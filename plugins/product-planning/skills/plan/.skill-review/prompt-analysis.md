---
lens: "Prompt Engineering Quality"
lens_id: "prompt"
skill_reference: "customaize-agent:prompt-engineering"
target: "feature-planning"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-planning/skills/plan"
fallback_used: true
findings_count: 14
critical_count: 1
high_count: 3
medium_count: 5
low_count: 3
info_count: 2
---

# Prompt Engineering Quality Analysis: feature-planning

## Summary

The feature-planning skill is an impressively engineered multi-phase orchestration system with strong architectural separation, a clear dispatch pattern, and excellent progressive disclosure via hub-spoke reference files. However, several prompt engineering issues undermine effectiveness: the coordinator dispatch prompt template relies on pseudocode variable interpolation that leaves Claude guessing at runtime behavior, critical decision logic is expressed in procedural code blocks rather than declarative rules that LLMs follow reliably, and some instructions conflate multiple concerns within single steps creating ambiguity about execution order and conditional boundaries. The skill would benefit from converting key pseudocode sections into explicit declarative instructions, tightening prompt variable contracts, and reducing the cognitive load of deeply nested conditional trees.

## Findings

### 1. Coordinator Dispatch Prompt Uses Unbounded Template Variables Without Fallback Defaults
- **Severity**: CRITICAL
- **Category**: LLM instruction effectiveness
- **File**: `references/orchestrator-loop.md`
- **Current**: The `DISPATCH_COORDINATOR` function builds a prompt template with interpolation variables like `{phase_name}`, `{analysis_mode}`, `{relevant_flags_and_values}`, `{FEATURE_DIR}`, and `{requirements_section}`. None of these variables specify fallback defaults. The template string (lines 254-278) is expressed in pseudocode, meaning Claude must infer what values to substitute at runtime. In particular, `{relevant_flags_and_values}` has no defined format, no enumeration of which flags are "relevant" per phase, and no fallback if the orchestrator cannot determine them.
- **Recommendation**: Convert the dispatch prompt template from pseudocode to a concrete template with explicit variable list. For each variable, define: (1) source (e.g., "from state.analysis_mode"), (2) type (string, list, etc.), (3) fallback value (e.g., `"unknown"` or `"[]"`). For `relevant_flags_and_values`, define which flags each phase needs by adding a `relevant_flags` field to the Phase Dispatch Table in SKILL.md. Replace the vague interpolation with something like: `Feature flags: cli_context_isolation={true|false}, s5_tot_architecture={true|false}, ...` listing only the flags the specific phase consumes.

### 2. Pseudocode Control Flow Blocks Are Ambiguous for LLM Execution
- **Severity**: HIGH
- **Category**: Instruction clarity and unambiguity
- **File**: `references/orchestrator-loop.md`
- **Current**: The orchestrator dispatch loop (lines 8-185) is written as imperative pseudocode with `FOR`, `IF/ELSE`, `FUNCTION`, and `RETURN` statements. LLMs do not execute code; they interpret instructions. The pseudocode creates ambiguity about whether Claude should (a) literally implement this logic in code, (b) follow it as a decision tree, or (c) treat it as a rough guideline. For example, the gate failure handler (lines 75-140) contains a 60-line nested conditional tree with 4 levels of nesting that would be extremely difficult for an LLM to follow faithfully at runtime.
- **Recommendation**: Restructure the most critical decision paths (gate failure handling, deep reasoning escalation eligibility) as explicit decision tables or numbered rule sets rather than pseudocode. For example, replace the nested `IF/ELSE IF/ELSE` gate failure tree with a flat decision table: "When gate verdict is RED: (1) If retries < 2, increment and loop back. (2) If retries >= 2 AND deep reasoning enabled AND escalation limits not exceeded, determine escalation type per Escalation Type Table below. (3) Otherwise, ask user: retry / skip / abort." This flattens the logic into sequential rules that Claude can follow top-to-bottom.

### 3. Phase 1 Setup Contains 8 Sub-Steps With Mixed Inline/Conditional/Delegated Patterns
- **Severity**: HIGH
- **Category**: Prompt structure and logical flow
- **File**: `references/phase-1-setup.md`
- **Current**: Phase 1 has Steps 1.1 through 1.8 (with sub-steps 1.5b, 1.5c, 1.5d, 1.6b, 1.6c), totaling 13 distinct operations spanning 460 lines. This phase runs inline in the orchestrator's context, meaning Claude must hold all 460 lines of instructions simultaneously while executing them. The sub-step numbering (1.5b, 1.5c, 1.5d) suggests organic growth rather than intentional design, and the step ordering is not always intuitive (1.6c "Requirements Digest Extraction" logically belongs near Step 1.1 "Prerequisites Check" since both deal with spec.md).
- **Recommendation**: Group Phase 1 steps into 3 logical blocks with clear headers: (A) Environment Detection (Steps 1.1-1.5d), (B) User Configuration (Steps 1.6-1.6b), (C) Workspace Setup (Steps 1.6c-1.8). Add a summary checklist at the top: "Phase 1 completes when: [ ] spec.md verified, [ ] mode selected, [ ] state initialized, [ ] summary written." This gives Claude a clear mental model before reading the details. Consider whether Steps 1.5b-1.5d (CLI detection, dev-skills detection, algorithm detection) could be delegated to a lightweight subagent to reduce inline context load.

### 4. SKILL.md Critical Rules Mix Operational Constraints With Architectural Decisions
- **Severity**: HIGH
- **Category**: Degrees of freedom
- **File**: `SKILL.md`
- **Current**: The 11 Critical Rules (lines 43-54) blend fundamentally different types of instructions: behavioral rules ("NEVER re-ask questions from user_decisions"), architectural constraints ("Delegated phases execute via Task(subagent_type='general-purpose')"), and process rules ("ALWAYS ask user to choose analysis mode"). This flat list lacks priority ordering and does not distinguish between rules that must never be violated (immutability of user decisions) versus implementation preferences (delegation via Task subagent type).
- **Recommendation**: Split Critical Rules into two tiers: "Invariants" (rules 1, 2, 9, 10 -- behavioral guarantees that must hold across all modes) and "Implementation Protocol" (rules 3, 4, 5, 6, 7, 8, 11 -- how the workflow executes). This helps Claude prioritize when rules conflict. For example, Rule 9 ("Summary-Only Context") could conflict with Rule 3 ("Complex analysis uses MPA agents") if an MPA agent's output is needed but the summary is degraded. A tiered structure makes the resolution clear.

### 5. Phase 4 Step Numbering Is Non-Sequential and Contains Step 4.0a Before Step 4.0
- **Severity**: MEDIUM
- **Category**: Prompt structure and logical flow
- **File**: `references/phase-4-architecture.md`
- **Current**: The steps in Phase 4 are ordered: 4.0a, 4.0b, 4.0, 4.1, 4.1-alt, 4.1b, 4.1c, 4.2, 4.3, 4.3c, 4.4, 4.5, 4.6, 4.7. Step 4.0a runs "IN PARALLEL" with Step 4.0, but sequential ordering in the file implies serial execution. The gap from 4.3 to 4.3c (no 4.3a or 4.3b) suggests deleted steps. The "4.1-alt" naming breaks the numbering convention entirely. A coordinator reading top-to-bottom may execute 4.0a, then 4.0b, then 4.0 sequentially rather than parallelizing 4.0a and 4.0.
- **Recommendation**: Renumber steps sequentially (4.1 through 4.N) and use explicit parallelism markers: "Steps 4.1 and 4.2 execute IN PARALLEL. Wait for both to complete before proceeding to Step 4.3." Replace "4.1-alt" with a conditional block within Step 4.4: "IF s5_tot_architecture enabled: follow Hybrid ToT-MPA workflow, ELSE: follow Standard MPA." This eliminates the ambiguity of alternative steps.

### 6. Mode Guards Are Inconsistent Between SKILL.md and Phase Reference Files
- **Severity**: MEDIUM
- **Category**: Instruction clarity and unambiguity
- **File**: `SKILL.md` and `references/phase-4-architecture.md`
- **Current**: SKILL.md Phase Dispatch Table shows Phase 5 has `modes: [complete, advanced]` (it is skipped for standard/rapid). But within phase-4-architecture.md, Step 4.1 says "Standard/Advanced modes (when S5 ToT disabled)" and Step 4.3 says "IF mode == Complete AND ST available." The mode check in Step 4.3c uses "IF analysis_mode in {advanced, complete}" while Step 4.6 uses "IF feature_flags.s4_adaptive_strategy.enabled AND analysis_mode in {advanced, complete}." There is no single authoritative source that says which steps within a phase apply to which modes.
- **Recommendation**: Add a "Mode Applicability" table at the top of each phase reference file that lists every step and its mode guard in one place. For example: "| Step | Modes | Feature Flag | ... |". This provides a scannable index the coordinator can reference before executing, rather than requiring it to parse each step's inline conditions.

### 7. Feature Flag References Use Inconsistent Naming Conventions
- **Severity**: MEDIUM
- **Category**: Instruction clarity and unambiguity
- **File**: `SKILL.md`, `references/phase-4-architecture.md`
- **Current**: Feature flags are referenced with different naming patterns throughout: `s5_tot_architecture`, `s4_adaptive_strategy`, `s3_judge_gates`, `st_fork_join_architecture`, `st_tao_loops`, `a6_context_protocol`, `cli_context_isolation`, `cli_custom_roles`, `dev_skills_integration`, `s7_mpa_deliberation`, `s8_convergence_detection`, `s10_team_presets`, `s12_specify_gate`, `s13_confidence_gated_review`. The naming uses at least 4 different prefix conventions: `s{N}_`, `st_`, `a{N}_`, and unprefixed. The `s` and `a` prefixes presumably mean "strategy" and "addon" but this is never stated.
- **Recommendation**: Document the flag naming convention in a comment or note at the top of the SKILL.md "Multi-Agent Collaboration Flags" section. For example: "Naming: `s{N}_` = strategy enhancement, `a{N}_` = architectural addon, `st_` = Sequential Thinking variant, unprefixed = core integration." This prevents confusion when coordinators need to check whether a flag is enabled.

### 8. The Orchestrator's "Summary-Only Context" Rule Contradicts Coordinator Instructions
- **Severity**: MEDIUM
- **Category**: Degrees of freedom
- **File**: `SKILL.md`
- **Current**: Critical Rule 9 states: "Between phases, read ONLY summary files from `.phase-summaries/`. Never read full phase instruction files or raw artifacts in orchestrator context." However, the coordinator dispatch prompt (orchestrator-loop.md line 258) tells coordinators to "Read and execute: $CLAUDE_PLUGIN_ROOT/skills/plan/references/{phase_file}". The Phase Dispatch Table in SKILL.md also lists `artifacts_read` per phase (e.g., spec.md, research.md). This creates confusion: is Rule 9 about what the orchestrator reads, or what coordinators read? The answer is the former, but the rule's wording ("Between phases") does not make this boundary clear.
- **Recommendation**: Reword Rule 9 to: "The ORCHESTRATOR reads ONLY summary files from `.phase-summaries/` between phases. Coordinators read their full instruction files, prior summaries, and listed artifacts. The orchestrator must never load phase instruction files or raw feature artifacts into its own context."

### 9. Coordinator Instructions Block Is a Generic Boilerplate Without Phase-Specific Adaptation
- **Severity**: MEDIUM
- **Category**: Use of examples vs. rules
- **File**: `references/phase-4-architecture.md`
- **Current**: The "COORDINATOR INSTRUCTIONS" block (lines 57-65) is identical across all phase reference files (a copy-pasted template with 8 generic rules). While consistency is good, this block occupies 9 lines of context in every phase file without providing phase-specific guidance. The generic instruction "Execute ALL steps below for the current analysis_mode" could mislead a coordinator in Phase 4 where some steps are alternatives (4.1 vs 4.1-alt) rather than sequential.
- **Recommendation**: Keep the generic template but add 1-2 phase-specific sentences. For Phase 4: "This phase has PARALLEL steps (4.0a + 4.0) and ALTERNATIVE steps (4.1 vs 4.1-alt based on s5_tot_architecture flag). Execute the applicable path, not both." This costs minimal tokens but prevents misinterpretation.

### 10. Deep Reasoning Escalation Logic in Orchestrator Loop Is Overly Complex for LLM Parsing
- **Severity**: LOW
- **Category**: Instruction clarity and unambiguity
- **File**: `references/orchestrator-loop.md`
- **Current**: The deep reasoning escalation eligibility check (lines 82-136) involves 6 conditions, 3 escalation types, and 2 levels of nested conditionals. It also references 3 config keys (`circular_failure_recovery`, `architecture_wall_breaker`, `abstract_algorithm_detection`), each with their own `.enabled` and `.modes` subfields. While technically correct, this density of conditional logic in a single block makes it likely that an LLM will simplify or skip edge cases.
- **Recommendation**: Extract the escalation type determination into a standalone "Escalation Type Decision Table" in `deep-reasoning-dispatch-pattern.md` (where it is conceptually located anyway) and reference it from the orchestrator loop: "Determine escalation type per the Escalation Type Decision Table in deep-reasoning-dispatch-pattern.md." This reduces the orchestrator loop's complexity and leverages the reference file system the skill already uses.

### 11. Sequential Thinking Template IDs Are Cryptic Without Inline Documentation
- **Severity**: LOW
- **Category**: Instruction clarity and unambiguity
- **File**: `references/phase-4-architecture.md`
- **Current**: Steps 4.3 references template IDs like `T7a_FRAME`, `T7b_BRANCH_GROUNDING`, `T8a_RECONCILE`, `T8b_COMPOSE`, and the fallback `T7`, `T8`, `T9`, `T10`. These IDs are defined in `templates/sequential-thinking-templates.md` but there is no inline comment explaining what each template does. A coordinator must cross-reference the template file to understand the purpose of each ST call, which adds cognitive load and risk of misuse.
- **Recommendation**: Add a one-line inline comment after each ST call: `mcp__sequential-thinking__sequentialthinking(T7a_FRAME)  # Define Perspective x Concern matrix`. This costs ~50 tokens total but saves the coordinator from loading the template file just to understand the flow.

### 12. Error Handling Section in SKILL.md Lacks Specificity for Common Failure Modes
- **Severity**: LOW
- **Category**: Edge cases and decision points
- **File**: `SKILL.md`
- **Current**: The Error Handling section (lines 276-282) lists 6 error types with brief one-line responses: "Missing prerequisites -- Provide guidance to create spec.md", "Agent failure -- Retry once, then continue with partial results." These are too terse to guide Claude's actual behavior. For example, "Retry once" does not specify: retry the entire coordinator dispatch or just the failed sub-agent? What does "partial results" look like in practice?
- **Recommendation**: Expand each error handler to 2-3 lines specifying: (1) detection condition, (2) recovery action with scope, (3) user communication. For example: "Agent failure: If a Task() sub-agent returns no output or errors, retry that specific Task() once. If the retry also fails, write a degraded summary with `flags.degraded: true` and note which agent failed. Do NOT retry the entire phase coordinator."

### 13. Phase Dispatch Table Column "User Interaction" Has Ambiguous Values
- **Severity**: INFO
- **Category**: Instruction clarity and unambiguity
- **File**: `SKILL.md`
- **Current**: The "User Interaction" column in the Phase Dispatch Table contains values like "Gate failure only", "Questions (all)", "Select option", "If YELLOW/RED", "Blocking security", "Review findings", "Validate manifest", "Clarify tasks". These are contextual shorthand that require reading the phase reference files to understand. For instance, "Blocking security" for Phase 6b does not indicate whether the user is asked a question, shown a report, or required to make a binary decision.
- **Recommendation**: This is acceptable as a quick-reference table since each phase file contains full details. No action required, but consider expanding to two words where the interaction type is unclear (e.g., "Security gate decision" instead of "Blocking security").

### 14. Excellent Use of ASCII Diagrams for Complex Workflows
- **Severity**: INFO
- **Category**: Use of examples vs. rules
- **File**: `SKILL.md`, `references/phase-4-architecture.md`
- **Current**: The skill uses ASCII box diagrams in both SKILL.md (workflow overview, lines 73-119) and phase-4-architecture.md (Diagonal Matrix Fork-Join, lines 321-352). These diagrams complement the textual rules by providing spatial understanding of phase relationships and data flow.
- **Recommendation**: No change needed. This is a strong practice that aids LLM comprehension of parallel and branching flows.

## Strengths

1. **Hub-Spoke Architecture With Progressive Disclosure** -- SKILL.md is kept lean at ~293 lines as a dispatch table and rule index, with all procedural detail pushed to per-phase reference files. This prevents context overload: the orchestrator loads only the ~155-line orchestrator-loop.md and relevant summaries, while coordinators load only their specific ~100-500 line phase file. The Phase Dispatch Table provides a scannable index of all phases with their delegation type, dependencies, and checkpoints. This design directly addresses LLM context window limitations and is the single strongest prompt engineering decision in the skill.

2. **Layered Degradation With Explicit Mode Guards** -- The skill defines 4 analysis modes (Complete, Advanced, Standard, Rapid) with explicit cost estimates and MCP/CLI requirements per mode. The degradation path is clearly specified: if CLIs unavailable, fall to Standard; if ST unavailable, fall to Advanced. Each phase file includes mode guards on individual steps (e.g., "IF analysis_mode in {advanced, complete}"), ensuring that simpler modes skip expensive operations without breaking the workflow. This prevents the common prompt engineering anti-pattern of all-or-nothing execution.

3. **Summary Contract as Inter-Phase Communication** -- The summary convention (30-80 lines, YAML frontmatter with required fields, "Context for Next Phase" section) creates a well-defined interface between the orchestrator and coordinators. The required fields (`phase`, `status`, `checkpoint`, `artifacts_written`, `summary`) enforce structured output that the orchestrator can validate programmatically. The crash recovery function demonstrates thoughtful handling of the case where this contract is violated (reconstruct from artifacts, mark degraded, ask user).

4. **Immutable User Decisions Pattern** -- Critical Rule 1-2 and the state management design enforce that user decisions (mode selection, architecture choice, test strategy approval) are write-once. The orchestrator-loop.md explicitly states "User decisions are IMMUTABLE once saved" and "When resuming, NEVER re-ask questions from user_decisions." This prevents a common multi-session failure mode where LLMs re-prompt users for decisions already made, and demonstrates strong understanding of stateful LLM workflow design.
