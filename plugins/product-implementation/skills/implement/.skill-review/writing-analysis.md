---
lens: "Writing Quality & Conciseness"
lens_id: "writing"
skill_reference: "docs:write-concisely"
target: "feature-implementation"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-implementation/skills/implement"
fallback_used: false
findings_count: 14
critical_count: 0
high_count: 2
medium_count: 7
low_count: 3
info_count: 2
---

# Writing Quality & Conciseness Analysis: feature-implementation

## Summary

The skill files are well-structured and achieve clarity through consistent formatting, tables, and numbered procedures. However, the writing suffers from pervasive passive voice, filler phrases that dilute instructions, and verbose conditional descriptions that could be halved without losing meaning. Several sections repeat information already stated elsewhere in the same file or across files, inflating coordinator context cost.

## Findings

### 1. Passive voice obscures the acting agent throughout stage references
- **Severity**: HIGH
- **Category**: Active voice
- **File**: `references/stage-2-execution.md`
- **Current**: Passive constructions appear throughout: "This step **is dispatched** by the orchestrator" (line 38), "tests **should be** FAIL" (line 171), "Phase relevance **is determined**" (line 333), "The coordinator **is** verifies post-dispatch" (line 181), "The CLI agent **is dispatched**" (line 388), "Results **are stored**" (line 129), "APK **is located**" (line 357). Similar patterns appear in `stage-1-setup.md`: "This step **runs** ONCE during Stage 1 and **stores** results" (mixed active/passive, but many section intros use "This step is executed" forms).
- **Recommendation**: Rewrite in active voice with clear subjects. Examples: "The orchestrator dispatches this stage via `Task()`." "All new tests should FAIL (Red phase confirmation)." "The coordinator verifies post-dispatch that no source files were created." "Store results in Stage 1 summary." Active voice clarifies who acts, which matters when coordinators, agents, and the orchestrator share responsibility.

### 2. Redundant variable documentation inflates agent-prompts.md
- **Severity**: HIGH
- **Category**: Conciseness (omit needless words)
- **File**: `references/agent-prompts.md`
- **Current**: Every prompt template repeats the same variable definitions verbatim. `{FEATURE_NAME}`, `{FEATURE_DIR}`, `{TASKS_FILE}`, and `{user_input}` each carry identical descriptions across 7+ prompt templates. For example, `{FEATURE_NAME} -- Feature identifier from git branch` appears in the Phase Implementation Prompt (line 81), Code Simplification Prompt (line 161), Completion Validation Prompt (line 207), Quality Review Prompt (line 276), Review Fix Prompt (line 315), Incomplete Task Fix Prompt (line 349), and Documentation Update Prompt (line 383). The "Agent behavior" paragraphs also repeat information already stated in the prompt template itself (e.g., lines 91, 166, 214, 283).
- **Recommendation**: Define shared variables once at the top of the file in a "Common Variables" section, then reference it: "All common variables (`{FEATURE_NAME}`, `{FEATURE_DIR}`, `{TASKS_FILE}`, `{user_input}`) are defined in the Common Variables section above." This could remove ~80 lines of repetition. For "Agent behavior" paragraphs, keep only information NOT already in the prompt template itself.

### 3. Filler phrases pad conditional gate descriptions
- **Severity**: MEDIUM
- **Category**: Needless words
- **File**: `references/stage-2-execution.md`
- **Current**: Conditional gates use wordy constructions: "Only runs when ALL of: `cli_dispatch.stage2.test_author.enabled` is `true`, `test_cases_available` is `true` (from Stage 1 summary), and `cli_availability.codex` is `true` (from Stage 1 summary). If any condition is false, skip to Step 2." (lines 150-151). The phrase "from Stage 1 summary" repeats within a single sentence. Similar pattern at lines 271-275 (UX Test Coverage Review) and lines 311-317 (UAT Mobile Testing).
- **Recommendation**: State the source once: "All availability flags below come from the Stage 1 summary unless noted." Then simplify each gate to: "Requires: `test_author.enabled`, `test_cases_available`, `cli_availability.codex`. If any is false, skip to Step 2."

### 4. "The fact that" and roundabout constructions
- **Severity**: MEDIUM
- **Category**: Needless words
- **File**: `references/stage-1-setup.md`
- **Current**: Several sentences use indirect constructions: "These files are not strictly required (implementation can proceed without them), but their absence usually indicates the planning phase was incomplete." (line 69). The parenthetical restates what "not strictly required" already means. Also: "This step uses artifacts ALREADY loaded in Sections 1.4-1.5 -- no additional file reads." (line 128) -- the em-dash clause restates the implication of "already loaded."
- **Recommendation**: "These files are not required but their absence usually indicates incomplete planning." Remove the parenthetical. For the domain detection line: "This step uses artifacts already loaded in Sections 1.4-1.5." The reader can infer no additional reads are needed.

### 5. Verbose "Cost" sections repeat obvious information
- **Severity**: MEDIUM
- **Category**: Conciseness (every sentence earns its place)
- **File**: `references/stage-1-setup.md`
- **Current**: Each subsection (1.6, 1.6a, 1.6b, 1.6c, 1.6d, 1.6e, 1.6f, 1.7a, 1.7b) ends with a "Cost" section that often restates what the Procedure section already says. For example, Section 1.6 Cost: "Zero additional file reads. Zero additional agent dispatches. Pure text matching against already-loaded content." (lines 150-151). Section 1.6b Cost: "Zero MCP calls. Pure regex matching against already-loaded content." (line 203). Section 1.6f Cost: "Zero MCP calls. Single skill listing check (~0s)." (line 303).
- **Recommendation**: Consolidate cost annotations inline within each procedure's opening line (e.g., "Scan task file paths (zero additional reads -- uses loaded artifacts):"). Eliminate standalone "Cost" subsections for trivial operations. Keep them only where cost is non-obvious (1.6a, 1.6c, 1.7a).

### 6. Inconsistent terminology for "skip" actions
- **Severity**: MEDIUM
- **Category**: Consistent terminology
- **File**: `references/stage-2-execution.md`
- **Current**: The word used for bypassing a step varies: "skip to Step 2" (line 151), "skip to Section 2.1" (line 49), "skip to Step 4" (lines 219, 227, 231, 346, 356, 358, 368), "skip this step silently" (line 275), "skip silently" (line 323), "skip to Section 2.2" (line 501). Some use "skip" as imperative ("skip to"), others as description ("is skipped"). The verb changes meaning subtly -- sometimes it means "proceed to the next step," other times "omit entirely."
- **Recommendation**: Standardize on one pattern. Use "Skip to {target}" for jumping forward and "Omit this step" for when the step simply does not run. Apply consistently across all stage reference files.

### 7. Latency Impact sections are formulaic repetitions
- **Severity**: MEDIUM
- **Category**: Conciseness (every sentence earns its place)
- **File**: `references/stage-2-execution.md`
- **Current**: Three "Latency Impact" subsections (lines 265-267, 305-307, 459-460) follow the same template: "Adds ~Xs dispatch overhead + ~Ys agent execution per phase. Skipped automatically when disabled, when {condition1}, or when {condition2}." The "Skipped automatically when disabled" clause restates the conditional gate that already opens the section.
- **Recommendation**: Reduce to a single line with timing only: "Adds ~5-15s dispatch + 30-120s execution per phase." The skip conditions are already documented in the conditional gate at the top of each step.

### 8. Loose sentence chains in SKILL.md integration sections
- **Severity**: MEDIUM
- **Category**: Clarity and readability (avoid succession of loose sentences)
- **File**: `SKILL.md`
- **Current**: The "Research MCP Integration" section (lines 206-223) chains eight sentences in succession, most following a subject-dash-explanation pattern: "This integration is: ... Orchestrator-transparent -- ... Ref-primary -- ... Budget-controlled -- ..." followed by "MCP availability detection runs in Stage 1 ... Injection points: ... Session accumulation: ..." The same pattern repeats in "CLI Dispatch" (lines 225-246) and "Dev-Skills Integration" (lines 188-203). Each section follows an identical rhetorical structure that becomes monotonous.
- **Recommendation**: Vary sentence structure across these sections. Convert the property lists ("Zero-cost when disabled," "Orchestrator-transparent," etc.) into a compact table rather than repeating the same bullet format three times. The injection point lists could use a shared "Stage injection matrix" table for all three integrations.

### 9. Negative conditions stated negatively
- **Severity**: MEDIUM
- **Category**: Positive form
- **File**: `references/stage-2-execution.md`
- **Current**: Multiple conditions use double negatives or negative framing: "If any condition is false, skip" (lines 151, 275, 317), "If no relevant specs found" (line 157), "Do NOT modify" (lines 107-108, 131-137), "MUST NOT write" (line 456), "never rename exports" (line 125). While some "DO NOT" instructions are warranted safety rules, others could be stated positively.
- **Recommendation**: Rewrite where possible in positive form. "If no relevant specs found" becomes "When all specs are irrelevant to this phase." "never rename exports" becomes "preserve export names." Keep explicit "DO NOT" only for safety-critical rules (git push, test file modification).

### 10. Verbose write-boundary repetition across steps
- **Severity**: LOW
- **Category**: Conciseness
- **File**: `references/stage-2-execution.md`
- **Current**: "Write Boundaries" sections appear identically at Step 1.8 (lines 179-181) and Step 3.7 (lines 454-456). Both say the CLI agent must not write outside its designated directory and the coordinator verifies compliance.
- **Recommendation**: Define write boundaries once in a shared convention (perhaps in `cli-dispatch-procedure.md`) and reference it: "Write boundaries per CLI dispatch procedure." This removes ~6 lines of duplication.

### 11. Overly long compound sentences in agent behavior summaries
- **Severity**: LOW
- **Category**: Clarity and readability
- **File**: `references/agent-prompts.md`
- **Current**: The "Agent behavior" paragraph for the Phase Implementation Prompt (line 91) is a single 96-word sentence that covers reading, executing, marking, aligning, consulting, using, running, reporting, compiling, verifying, and grepping. The Quality Review Prompt's agent behavior paragraph (line 283) similarly chains 7 clauses with commas.
- **Recommendation**: Break into shorter sentences, each covering one behavior. "The developer agent reads tasks.md and executes all tasks in the specified phase, marking each `[X]` on completion. When test-case specs are available, it reads each spec before writing the corresponding test. When skill references are provided, it consults SKILL.md files on-demand for domain patterns." Three clear sentences replace one unwieldy one.

### 12. Parenthetical asides interrupt instruction flow
- **Severity**: LOW
- **Category**: Keep related words together
- **File**: `references/stage-1-setup.md`
- **Current**: Instructions embed parenthetical explanations that interrupt the procedural flow: "Extract test IDs from spec files (default patterns: `E2E-*`, `INT-*`, `UT-*`, `UAT-*`)" (line 88), "expected subdirectories and test ID patterns are defined in `config/implementation-config.yaml` under `handoff.test_cases`; defaults: `e2e/`, `integration/`, `unit/`, `uat/`" (line 86). These config references break the reader's procedural reading.
- **Recommendation**: Move config references to a footnote-style annotation or a separate "Configuration Keys" table at the section end. Keep the procedure steps focused on actions.

### 13. SKILL.md Latency Trade-off section is self-justifying
- **Severity**: INFO
- **Category**: Every sentence earns its place
- **File**: `SKILL.md`
- **Current**: "Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for significant orchestrator context reduction and fault isolation. Stage 1 is inline to avoid overhead for lightweight setup. When `code_simplification.enabled` is `true`, each phase adds an additional code-simplifier dispatch (~5-15s overhead + 30-120s execution). This is the trade-off for cleaner downstream code, reduced review noise in Stage 4, lower token cost for future maintenance, and improved LLM comprehension." (lines 95). The phrase "This is the trade-off for" appears twice, each time justifying a design decision that the reader (a coordinator agent) cannot change.
- **Recommendation**: This is a design note for human maintainers, not an instruction for agents. It could move to CLAUDE.md or a development notes section. If kept, condense: "Coordinator dispatch overhead: ~5-15s per stage. Code-simplifier adds ~35-135s per phase when enabled."

### 14. Consistent use of ISO timestamp reminder
- **Severity**: INFO
- **Category**: Consistent terminology
- **File**: `references/stage-2-execution.md`, `references/stage-1-setup.md`
- **Current**: Both files include identical Stage Log instructions: "Use ISO 8601 timestamps with seconds precision per `config/implementation-config.yaml` `timestamps` section (e.g., `2026-02-10T14:30:45Z`). Never round to hours or minutes." (stage-2 line 653, stage-1 line 578). This is a positive consistency pattern worth noting.
- **Recommendation**: No action needed. This repetition is justified since each coordinator reads only its own stage file.

## Strengths

1. **Tables as information architecture** -- The skill consistently uses markdown tables for structured data (Stage Dispatch Table, Severity Levels, Output Artifacts, Error Handling, Planning Artifacts Summary). Tables compress information density and enable quick scanning, avoiding the verbose paragraph-based descriptions common in other skills. The Stage Dispatch Table in SKILL.md (lines 99-106) is a particularly effective example: six columns convey delegation model, references, agents, dependencies, interaction model, and checkpoints in a format that would require paragraphs of prose otherwise.

2. **Procedure-first section structure** -- Each section in the stage reference files leads with a numbered procedure (actionable steps) before any explanatory context. This follows Strunk's principle of placing the emphatic content (the instruction) first and supporting material (cost, output, rationale) after. The pattern is especially clean in `stage-1-setup.md` Sections 1.6a through 1.6f, where every subsection follows Procedure -> Output -> Cost ordering.

3. **Definite, concrete language in error handling** -- The Error Handling table in SKILL.md (lines 288-295) and the error handling table in `stage-2-execution.md` (lines 555-562) use specific, concrete language: "Halt with guidance: 'Run `/product-planning:tasks` first'" rather than vague directives like "handle appropriately." Each error type maps to exactly one action. This follows Rule 12 (definite, specific, concrete language) rigorously.

4. **Frontmatter as structured metadata** -- Every stage reference file opens with YAML frontmatter declaring its inputs, outputs, agents, and dependencies. This separates metadata from instruction, keeps the prose body focused on procedure, and enables machine parsing. It is a strong application of Rule 8 (one paragraph per topic) at the document level.
