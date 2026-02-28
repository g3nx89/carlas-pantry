# Agent Prompt Templates

All 9 prompts in this file are used by the orchestrator to launch `developer` and `tech-writer` agents. Variables in `{braces}` MUST be prefilled by the orchestrator before dispatching.

---

## Phase Implementation Prompt

Used in Stage 2 for each phase of tasks.md execution.

```markdown
**Goal**: Implement {phase_name} phase of tasks.md file by following Tasks.md Execution Workflow.

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}

## Planning Context

{context_summary}

## Test Specifications

{test_specs_summary}

Test cases directory: {test_cases_dir}
Task-test traceability: {traceability_file}

When test-case specs are available, read the relevant spec file BEFORE writing tests to align with the planned test strategy. If a test ID is referenced in a task, locate its spec in test-cases/ and implement accordingly.

## Domain-Specific Skill References

{skill_references}

When skill references include a compose, UI framework, or frontend skill, you MUST consult the referenced skill for platform-specific anti-patterns BEFORE writing UI code. Composition-time side effects, incorrect sealed class handling, and similar framework-specific pitfalls are common sources of runtime bugs that reviewers will flag.

## Research Context

{research_context}

When research context is provided: use it to verify API signatures, follow documented patterns, and diagnose build errors before guessing. Prefer Ref-sourced documentation over ad-hoc searches. When absent, proceed with codebase knowledge and planning artifacts only.

## Build Verification Rule

After writing or modifying ANY source file, you MUST compile/build the project before marking the corresponding task `[X]`. The sequence is: (1) write code, (2) compile/build, (3) fix any compilation errors, (4) mark `[X]`. NEVER mark a task complete if the project does not compile. If the project has no explicit build step (interpreted languages), run the linter or type checker instead.

## API Existence Verification

Before calling ANY API, method, or class, verify it exists in the current project dependencies at the EXACT version used. Use grep/glob to confirm. This is especially critical for:
- **Compose/UI frameworks**: Composable function signatures change across versions. Do not infer API signatures from naming patterns.
- **Third-party libraries**: Do not assume an API exists because it appears in documentation for a different version.
- **Platform APIs**: Android SDK levels, iOS deployment targets, and Node.js versions all gate API availability.

## Test Quality Requirements

NEVER write placeholder assertions (`assertTrue(true)`, `expect(true).toBe(true)`, `expect(1).toBe(1)`). Every test assertion must exercise real code and validate actual behavior. If a behavior cannot be tested in the current test framework, document it as a manual test case in your completion summary instead. Stage 3 validation scans for tautological patterns — placeholder tests will be caught and flagged.

## Animation and State Transition Testing

When implementing animations, transitions, or stateful UI components: tests must verify EACH discrete state AND the transitions between states (initial -> animating -> final, plus interrupted states). Do not test only the final state — an animation that starts at its target value is a no-op bug. Use test clocks or animation test utilities when available.

## Pattern Bug Fix Propagation

When fixing a bug that stems from a misapplied pattern (wrong API usage, incorrect state handling, framework anti-pattern): BEFORE marking the fix complete, grep the entire project for other occurrences of the same pattern. Fix ALL occurrences, not just the one referenced in the task. Report grep results and all files modified.

## Final Step — Verified Test Count

After completing all tasks in this phase, run the project's full test suite as your FINAL action. Report the result in this exact structured format at the end of your response:

    test_count_verified: {N}
    test_failures: {M}

Where {N} is the total number of passing tests and {M} is the number of failing tests (should be 0). This count will be cross-validated across stages — do not estimate, run the actual tests and report the real count.
```

**Variables:**
- `{phase_name}` — Name of the current phase (e.g., "Phase 1: Setup", "Phase 3: US1 - User Registration")
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{context_summary}` — Context File Summaries section from Stage 1 summary. Provides 1-line descriptions of each loaded planning artifact so the agent has immediate context without re-reading full files. **Fallback if unavailable:** `"No context summary available — read planning artifacts from FEATURE_DIR as needed."`
- `{test_specs_summary}` — Test Specifications section from Stage 1 summary. Lists available test-case specs by level with counts. **Fallback if unavailable:** `"No test specifications available — proceed with standard TDD approach."`
- `{test_cases_dir}` — Path to test-cases/ directory, or `"Not available"` if the directory does not exist
- `{traceability_file}` — Path to `analysis/task-test-traceability.md`, or `"Not available"` if the file does not exist
- `{skill_references}` — Domain-specific skill references resolved by the coordinator from `detected_domains` (see `stage-2-execution.md` Section 2.0). Contains skill paths and usage guidance. **Fallback if no skills apply or dev-skills not installed:** `"No domain-specific skills available — proceed with standard implementation patterns from the codebase."`
- `{research_context}` — Documentation excerpts, library references, and API details assembled by the coordinator from MCP tools (see `stage-2-execution.md` Section 2.0a). Includes pre-read URLs, Context7 library docs, and private documentation. **Fallback if research MCP is disabled or unavailable:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:** The developer agent reads its Tasks.md Execution Workflow section and executes all tasks in the specified phase, marking each `[X]` on completion. When test-case specs are available, the agent reads the relevant spec before writing each test to align with the planned strategy. When skill references are provided, the agent reads the referenced SKILL.md files on-demand for domain-specific patterns and anti-patterns — skills are consulted, not followed blindly (codebase conventions take precedence). When research context is provided, the agent uses it to verify API signatures, follow documented patterns, and diagnose build errors. The agent MUST run the full test suite as its final action and report `test_count_verified` and `test_failures` in the specified structured format. The agent must compile/build after each file write before marking tasks [X], verify APIs exist before using them, never write placeholder assertions, and grep for all occurrences when fixing pattern-level bugs.

---

## Code Simplification Prompt

Used in Stage 2 after each phase's developer agent completes and tests pass. The code-simplifier agent refines modified files for clarity and maintainability before auto-commit.

```markdown
**Goal**: Simplify and refine the following recently-modified files for clarity, consistency, and maintainability. Preserve ALL existing functionality — every test must continue to pass.

## Scope

ONLY modify these files:
{modified_files_list}

Do NOT modify:
- Test files (they are the safety net that validates your changes)
- Configuration files (.json, .yaml, .yml)
- Documentation files (.md)
- Files not in the list above

## Project Context

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
Phase just completed: {phase_name}

## Simplification Guidelines

Focus on these areas (in priority order):
1. **Dead code removal** — unreachable branches, unused imports, commented-out blocks
2. **Naming clarity** — rename internal variables/functions for self-documentation (never rename exports)
3. **Flatten conditionals** — replace nested if/else with early returns, guard clauses
4. **Extract method** — break long functions into well-named smaller functions
5. **Reduce duplication** — extract shared logic within the modified files
6. **Consistent patterns** — align with codebase conventions (check CLAUDE.md, constitution.md)

Do NOT:
- Change public API signatures (function parameters, return types, class interfaces)
- Add new dependencies or imports from external packages
- Reorganize file structure or move code between files
- Optimize for performance (this is a clarity pass, not a performance pass)
- Use nested ternary operators — prefer if/else or switch for multiple conditions
- Over-compact code — prefer clarity over brevity (a clear 3-line block > a dense one-liner)
- Modify test files under any circumstances
- Make changes that alter observable behavior

## Domain-Specific Skill References

{skill_references}

## Build Verification Rule

After modifying ANY source file, you MUST compile/build the project before proceeding to the next file. If the build fails, REVERT your last change and move on to the next file. If the project has no explicit build step (interpreted languages), run the linter or type checker instead.

## Final Step — Test Verification

After completing all simplifications, run the project's full test suite as your FINAL action. Report the result in this exact structured format at the end of your response:

    test_count_verified: {N}
    test_failures: {M}
    files_simplified: {count}
    changes_made: {total}

Where {N} is the total number of passing tests and {M} is the number of failing tests (should be 0). If ANY test fails, report which tests failed and which simplification likely caused the failure.
```

**Variables:**
- `{modified_files_list}` — Bullet list of source files modified by the developer agent in the current phase. Extracted from tasks.md `[X]` entries for this phase, filtered to exclude test files, config files, and documentation per `code_simplification.exclude_patterns` in config.
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{phase_name}` — Name of the phase that was just completed (e.g., "Phase 1: Setup")
- `{skill_references}` — Domain-specific skill references resolved by the coordinator in Section 2.0. Same value used for the developer agent. **Fallback if no skills apply or dev-skills not installed:** `"No domain-specific skills available — simplify using standard clean code principles."`

**Agent behavior:** The code-simplifier agent reads each listed file, identifies simplification opportunities (dead code, naming, nesting, duplication), applies changes while preserving all functionality, builds after each file change, and runs the full test suite as final verification. It reports structured output with per-file detail and test results. The agent MUST NOT modify test files, change public APIs, add dependencies, or alter observable behavior.

---

## Completion Validation Prompt

Used in Stage 3 after all phases complete.

```markdown
**Goal**: Verify that all tasks in tasks.md file are completed in order and without errors.
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - If test-case specs are available, cross-validate test IDs against implemented tests
   - Verify constitution/architecture compliance: if the project has constitution.md or CLAUDE.md at the project root declaring architectural constraints (e.g., layering rules, dependency directions), verify that the implementation adheres to each declared constraint. Flag violations as High severity.
   - Test coverage delta: count implemented automated tests by level (unit, integration, e2e). If test-plan.md is available, compare against planned targets and report delta as `{implemented}/{planned} {level} ({pct}%)`. Flag thresholds (from config): if unit tests < 80% of plan target, flag High; if any other level < 50% of plan target, flag Medium.
   - Strategy risk cross-reference: if test-strategy.md is available, verify that critical/high risks from the strategy are addressed by implemented tests. Report uncovered risks as Medium severity.
   - Run the full test suite independently and report the verified count as `baseline_test_count: {N}` at the end of your validation report.
   - Report final status with summary of completed work

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}

Test cases directory: {test_cases_dir}
Task-test traceability: {traceability_file}

If test-case specs are available in test_cases_dir, verify that test IDs referenced in tasks.md have corresponding implemented test files. Report any gaps in the validation report.

## Research Context

{research_context}

When research context is provided: use it to verify that implemented APIs match their official documentation (advisory check — flag discrepancies as Low severity). When absent, skip API documentation alignment checks.
```

**Variables:**
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{test_cases_dir}` — Path to test-cases/ directory, or `"Not available"` if the directory does not exist
- `{traceability_file}` — Path to `analysis/task-test-traceability.md`, or `"Not available"` if the file does not exist
- `{research_context}` — Documentation excerpts for API verification, assembled by the coordinator (see `stage-3-validation.md` Section 3.1). **Fallback if research MCP is disabled or unavailable:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:** The developer agent reads tasks.md, verifies every task is `[X]`, runs the test suite, and cross-references implementation against plan.md and spec.md. When test-case specs are available, also validates test ID traceability. Verifies constitution.md/CLAUDE.md compliance if those files declare architectural constraints. Computes test coverage deltas against test-plan.md targets when available. Independently runs the full test suite and reports `baseline_test_count` in the validation report. Scans test files for tautological/placeholder assertions (assertTrue(true), etc.) and flags files with no substantive assertions per config patterns. If `tautological_patterns` is not defined in config, skip the tautological scan. When research context is provided, performs advisory API documentation alignment checks.

---

## Quality Review Prompt

Used in Stage 4. Launched 3 times in parallel with different `{focus_area}` values.

```markdown
**Goal**: Review the code implemented for {FEATURE_NAME}. Your assigned focus: {focus_area}.

{reviewer_stance}

## Review Instructions

1. Read TASKS_FILE to identify all files modified during implementation
2. Read each modified file and review through your assigned lens
3. Compare against existing codebase patterns (check CLAUDE.md, constitution.md if present)
4. If domain-specific skill references are provided below, consult them for domain-specific best practices relevant to your focus area
5. Scan test files for tautological assertions (see `config/implementation-config.yaml` under `test_coverage.tautological_patterns` for the authoritative pattern list). Flag any test that passes without exercising real code as Medium severity (or High if it covers a critical feature path with no other test).
6. **Pattern propagation (R-REV-01)**: After finding any Critical or High severity structural bug (wrong API usage, incorrect state handling, framework anti-pattern), search the ENTIRE codebase for other occurrences of the same pattern before concluding your review. Report all matching locations — a single instance of a bug pattern often indicates systemic misuse.
7. For each finding, provide structured output as described below

## Output Format

Return findings as a markdown list, one per issue:

- [{severity}] {description} — {file}:{line} — Recommendation: {fix}

Severity levels:
- **Critical**: Breaks functionality, security vulnerability, data loss risk
- **High**: Likely bugs, significant code quality issue. ESCALATE a finding to High (not Medium) if ANY of these apply: user-visible data corruption, implicit ordering producing wrong results, UI state contradiction, singleton/shared-state leak across scopes, race condition with user-visible effect
- **Medium**: Code smell, maintainability concern, minor pattern violation
- **Low**: Style preference, minor optimization opportunity

Apply escalation triggers BEFORE classifying — a finding that matches any High escalation trigger must never be classified as Medium.

If no issues found for your focus area, state "No issues found" with a brief explanation of what you reviewed.

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}

## Domain-Specific Skill References

{skill_references}

## Research Context

{research_context}

When research context is provided: use it for documentation-backed review — verify API usage against official docs, flag deprecated API calls, and check pattern compliance against documented best practices. When absent, review against codebase conventions only.
```

**Variables:**
- `{focus_area}` — One of (see `config/implementation-config.yaml` for canonical list):
  - `"simplicity, DRY principles, and code elegance"`
  - `"bugs, functional correctness, and edge case handling"`
  - `"project conventions, abstractions, and pattern adherence"`
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{skill_references}` — Domain-specific skill references resolved by the coordinator (see `stage-4-quality-review.md` Section 4.1a). **Fallback:** `"No domain-specific skills available — review against codebase conventions only."`
- `{research_context}` — Documentation excerpts for documentation-backed review, assembled by the coordinator from accumulated research URLs (see `stage-4-quality-review.md` Section 4.1b). **Fallback:** `"No research context available — review against codebase conventions only."`
- `{reviewer_stance}` — Reviewer stance instruction, assigned by the Stage 4 coordinator (see `stage-4-quality-review.md` Section 4.2). Contains stance-specific guidance (advocate, challenger, or neutral). **Fallback if stances disabled:** `"No specific stance assigned — review objectively using your best judgment."`

**Agent behavior:** The developer agent reads the changed files (extracted from tasks.md file paths), reviews code through its assigned lens, and produces a structured list of findings using the specified output format. When skill references are provided, the agent consults them for domain-specific anti-patterns and best practices relevant to its focus area. When research context is provided, the agent uses it for documentation-backed review: verifying API correctness, flagging deprecated calls, and checking pattern compliance. When a reviewer stance is provided, the agent adopts it: an advocate emphasizes strengths, a challenger stress-tests and scores conservatively, a neutral reviewer applies balanced judgment. Stances calibrate severity assessment — they do not change review scope or output format.

---

## Review Fix Prompt

Used in Stage 4 when user chooses "Fix now".

```markdown
**Goal**: Address the following quality review findings in the implemented code. Fix Critical and High severity issues only. Do not refactor or change anything beyond the listed issues.

## Findings to Fix

{findings_list}

## Context

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}
```

**Variables:**
- `{findings_list}` — Markdown list of Critical and High findings from the consolidated review, each with:
  - Finding ID (C1, H1, etc.)
  - Description
  - File path and line number
  - Recommended fix
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md

**Agent behavior:** The developer agent reads each referenced file, applies targeted fixes for each listed finding, runs tests to verify no regressions, and reports what was fixed with file:line references.

---

## Incomplete Task Fix Prompt

Used in Stage 5 when user chooses to fix incomplete tasks before documentation.

```markdown
**Goal**: Complete the following incomplete tasks from tasks.md before documentation proceeds.

## Incomplete Tasks

{incomplete_tasks_list}

## Context

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}
```

**Variables:**
- `{incomplete_tasks_list}` — Markdown list of incomplete tasks from tasks.md, each with:
  - Task ID (T001, T002, etc.)
  - Description
  - File path
  - Current status (not started / partially done)
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md

**Agent behavior:** The developer agent reads tasks.md, identifies the listed incomplete tasks, implements them following the Tasks.md Execution Workflow, marks each `[X]` on completion, and runs tests to verify correctness.

---

## Documentation Update Prompt

Used in Stage 5 to launch the tech-writer agent for feature documentation.

```markdown
**Goal**: Document feature implementation with API guides, architecture updates, and lessons learned, by following Feature Implementation Documentation Workflow.

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}

## Documentation Skill References

{skill_references}

## Research Context

{research_context}

When research context is provided: use it to enrich documentation with links to official docs, verify code examples against current API signatures, and include migration notes or deprecation warnings where relevant. Maximum Dropout benefit applies — by Stage 5, Ref returns only the most documentation-relevant content. When absent, produce documentation from codebase knowledge and planning artifacts only.
```

**Variables:**
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{skill_references}` — Documentation-oriented skill references resolved by the coordinator (see `stage-5-documentation.md` Section 5.1a). Contains diagram generation and domain documentation skills. **Fallback:** `"No documentation skills available — produce prose documentation without diagrams."`
- `{research_context}` — Documentation excerpts for enrichment and link generation, assembled by the coordinator from accumulated research URLs (see `stage-5-documentation.md` Section 5.1b). **Fallback:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:** The tech-writer agent reads all context files from FEATURE_DIR, reviews the implemented code, and creates/updates project documentation including API guides, usage examples, architecture updates, module READMEs, and lessons learned. When diagram skills are provided, the agent uses Mermaid.js syntax to create architecture, sequence, and ERD diagrams inline. When research context is provided, the agent enriches documentation with links to official docs, verifies code examples, and includes migration or deprecation notes. Produces a documentation update summary.

---

## Auto-Commit Prompt

Used by Stages 2, 4, and 5 coordinators to commit milestone changes via a throwaway `Task(subagent_type="general-purpose")` subagent. This keeps git output out of coordinator context. Failure is always warn-and-continue.

```markdown
**Goal**: Create a git commit for implementation milestone changes.

Commit message: {commit_message}

## Instructions

1. Run `git status` in the project root to see changed files
2. Stage files individually using `git add <file>` for each changed file
   - **EXCLUDE** files matching these patterns (do NOT stage them):
     {exclude_patterns_formatted}
   - Stage all modified, new, or deleted files that are part of the current feature implementation (feature spec directory: {FEATURE_DIR})
   - Do NOT stage files clearly unrelated to the current feature (e.g., files in other feature spec directories)
   - Never use `git add .` or `git add -A`
3. If no files are staged after exclusions, report `commit_status: skipped` and stop
4. Run `git commit` with the provided commit message
5. Report the result

## Safety Rules

- NEVER run `git push`
- NEVER use `--amend`
- NEVER use `--force` or `--no-verify`
- NEVER modify the git config
- If the commit fails (e.g., pre-commit hook), report the error — do NOT retry

## Output Format

Report exactly these fields at the end of your response:

    commit_status: {success|failed|skipped}
    commit_sha: {sha or null}
    files_committed: {count}
    reason: {brief explanation}
```

**Variables:**
- `{commit_message}` — Pre-built commit message from `auto_commit.message_templates` in config, with template variables (e.g., `{feature_name}`, `{phase_name}`) already substituted by the coordinator
- `{FEATURE_DIR}` — Path to feature spec directory (used to scope staged files)
- `{exclude_patterns_formatted}` — Bullet list of exclude patterns from `auto_commit.exclude_patterns` in config, formatted as: `- .implementation-state.local.md\n- .stage-summaries/`

**Agent behavior:** The general-purpose subagent runs git commands to stage and commit changed files, excluding internal state files. It reports structured output that the coordinator logs. On any failure, the subagent reports the error without retrying — the coordinator treats all failures as non-blocking warnings.

---

## Retrospective Composition Prompt

Used in Stage 6 to launch the tech-writer agent for composing the implementation retrospective narrative from structured KPI data and transcript analysis.

```markdown
**Goal**: Compose a comprehensive implementation retrospective for feature {FEATURE_NAME}. Synthesize quantitative KPIs, session behavior analysis, and stage-by-stage outcomes into a narrative that identifies what worked, what didn't, and what to improve.

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}

## KPI Report Card Data

{report_card_data}

## Session Transcript Analysis

{transcript_extract}

## Stage Summaries

{stage_summaries_compiled}

## Sections Configuration

{sections_config}

## Output Instructions

Write `{FEATURE_DIR}/retrospective.md` with these sections. Skip any section where `sections_config` has it set to `false`. The Executive Summary and KPI Report Card are ALWAYS included regardless of config.

### 1. Executive Summary
- 2-3 sentence verdict backed by KPI traffic lights
- Highlight the most significant green and red KPIs
- State autonomy policy used and its impact (auto-resolutions count)

### 2. KPI Report Card
- Render all Phase 1 KPIs as a markdown table: `| ID | KPI | Value | Traffic Light |`
- Include a "Phase 2 (Future)" row with `—` values for forward-compatibility awareness
- Add brief interpretation notes for non-obvious KPIs

### 3. Implementation Timeline (if sections.timeline)
- Stage-by-stage chronology with key events
- Note any re-runs, user interventions, or auto-resolutions
- Include timestamps if available from stage summaries

### 4. What Worked Well (if sections.what_worked)
- Synthesize evidence from: green KPIs, successful auto-resolutions, clean validation passes
- If transcript available: highlight efficient tool usage patterns, low error rates
- Cite specific stage summary data as evidence

### 5. What Did Not Work Well (if sections.what_didnt_work)
- Synthesize evidence from: red/yellow KPIs, rework loops, coordinator failures
- If transcript available: highlight files read repeatedly (inefficiency), high error counts, context compressions
- Cite specific stage summary data as evidence

### 6. Stage-by-Stage Breakdown (if sections.stage_breakdown)
- For each stage (1-5): outcome, key metrics, policy actions taken
- Include validation findings summary, review findings summary, documentation gaps

### 7. Session Behavior Analysis (if sections.tool_analysis AND transcript available)
- Tool usage distribution (top 5 tools by count)
- File access heatmap (most accessed files)
- Repeatedly-read files (inefficiency signals — read 5+ times)
- Subagent dispatch pattern
- Context compression events (if any — indicates approaching context limits)
- Longest turns (potential bottlenecks)

### 8. Quality Metrics (if sections.code_quality_metrics)
- Test count progression: Stage 2 verified → Stage 3 baseline → Stage 4 post-fix
- Code simplification results (if available): phases simplified, lines reduced, rollbacks
- UAT results (if available): phases tested, pass/fail, visual mismatches
- Review findings by severity

### 9. Recommendations (if sections.recommendations)
- 3-5 actionable recommendations based on evidence
- Categorize: Process improvements, Input quality, Config tuning
- Reference specific KPIs or transcript evidence for each

### 10. Appendix: Raw Data (if sections.raw_metrics)
- Full KPI values table (machine-readable format)
- Transcript extract summary (if available)
- Stage summary flags compilation

## Style Guidelines

- Use concrete numbers and evidence — avoid vague assessments
- Reference KPI IDs (e.g., "KPI 1.2") when discussing metrics
- Use traffic light emoji for visual scanning: green circle, yellow circle, red circle
- Keep the document scannable with headers, tables, and bullet points
- Total document length: aim for 200-400 lines depending on sections enabled
```

**Variables:**
- `{FEATURE_NAME}` — Feature identifier from Stage 1 summary. (required — always available)
- `{FEATURE_DIR}` — Path to feature spec directory from Stage 1 summary. (required — always available)
- `{report_card_data}` — Full content of `.implementation-report-card.local.md` YAML frontmatter (produced in Stage 6 Section 6.2). Contains all Phase 1 KPI values and traffic lights. (required — always produced before this prompt runs)
- `{transcript_extract}` — Content of `.stage-summaries/transcript-extract.json` (produced in Stage 6 Section 6.3). Contains tool usage, errors, timing, and file access patterns. **Fallback if transcript analysis disabled or unavailable:** `"Transcript analysis not available — session behavior sections will be omitted."`
- `{stage_summaries_compiled}` — Key excerpts from all 5 stage summaries: the `summary` and `flags` YAML sections from each, plus any `## Context for Next Stage` prose. Compiled by the Stage 6 coordinator (~200 tokens per stage, ~1000 tokens total). (required — always available)
- `{sections_config}` — The `retrospective.sections` block from `config/implementation-config.yaml`, rendered as YAML. Controls which sections the tech-writer includes. **Fallback if config unavailable:** All sections enabled (default `true`).

**Agent behavior:** The tech-writer agent reads the provided structured data (KPI Report Card, transcript extract, stage summaries), synthesizes findings across all three data sources, and produces a narrative retrospective document. The agent respects section toggles from `{sections_config}` — disabled sections are omitted entirely. When transcript data is unavailable, the agent omits session behavior sections and produces a KPI-and-summary-focused retrospective. The agent uses traffic light indicators, tables, and evidence-based language throughout.
