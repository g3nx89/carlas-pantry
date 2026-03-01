# Agent Prompt Templates

All 9 prompts in this file are used by coordinators to launch `developer` and `tech-writer` agents. Variables in `{braces}` MUST be prefilled by the coordinator before dispatching.

## Common Variables

These variables appear across most prompts. Per-prompt variable lists reference this table rather than repeating definitions.

| Variable | Description | Fallback |
|----------|-------------|----------|
| `{FEATURE_NAME}` | Feature identifier from git branch (e.g., `001-user-auth`) | **Required — always available** |
| `{FEATURE_DIR}` | Path to feature spec directory (e.g., `specs/001-user-auth`) | **Required — always available** |
| `{TASKS_FILE}` | Path to tasks.md (e.g., `specs/001-user-auth/tasks.md`) | **Required — always available** |
| `{user_input}` | Original user arguments passed at invocation | `"No additional user instructions provided — follow standard workflow."` |

## Coordinator Dispatch Protocol

After reading a stage reference file, the coordinator lists the section headers it found in its first stage log line. This confirms the file was fully ingested before proceeding.

Example: `"[2026-02-15T10:30:45Z] Read stage-2-execution.md: Sections 2.0, 2.0a, 2.1, 2.1a, 2.2, 2.3"`

---

<!-- SECTION: Phase Implementation Prompt -->
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

## Implementation Verification Rules

Follow the Implementation Verification Rules defined in `agents/developer.md` § Implementation Verification Rules.

## Final Step — Verified Test Count

After completing all tasks in this phase, run the project's full test suite as your FINAL action. Report the result in this exact structured format at the end of your response:

    test_count_verified: {N}
    test_failures: {M}

Where {N} is the total number of passing tests and {M} is the number of failing tests (should be 0). This count will be cross-validated across stages — do not estimate, run the actual tests and report the real count.
```

**Variables:** See Common Variables above, plus:
- `{phase_name}` — Name of the current phase (e.g., "Phase 1: Setup"). **Required — always available**
- `{context_summary}` — Context File Summaries section from Stage 1 summary. **Fallback:** `"No context summary available — read planning artifacts from FEATURE_DIR as needed."`
- `{test_specs_summary}` — Test Specifications section from Stage 1 summary. **Fallback:** `"No test specifications available — proceed with standard TDD approach."`
- `{test_cases_dir}` — Path to test-cases/ directory. **Fallback:** `"Not available"`
- `{traceability_file}` — Path to `analysis/task-test-traceability.md`. **Fallback:** `"Not available"`
- `{skill_references}` — Domain-specific skill references (see `stage-2-execution.md` Section 2.0). **Fallback:** `"No domain-specific skills available — proceed with standard implementation patterns from the codebase."`
- `{research_context}` — Documentation excerpts from MCP tools (see `stage-2-execution.md` Section 2.0a). **Fallback:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:**
1. The developer agent reads its Tasks.md Execution Workflow section and executes all tasks in the specified phase, marking each `[X]` on completion.
2. When test-case specs are available, the agent reads the relevant spec before writing each test to align with the planned strategy.
3. When skill references are provided, the agent reads the referenced SKILL.md files on-demand — skills are consulted, not followed blindly (codebase conventions take precedence).
4. When research context is provided, the agent uses it to verify API signatures, follow documented patterns, and diagnose build errors.
5. The agent follows Implementation Verification Rules from `agents/developer.md`.
6. The agent MUST run the full test suite as its final action and report `test_count_verified` and `test_failures`.

---

<!-- SECTION: Code Simplification Prompt -->
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

**Variables:** See Common Variables above (except `{TASKS_FILE}` — not used), plus:
- `{modified_files_list}` — Bullet list of source files modified in the current phase, filtered per `code_simplification.exclude_patterns`. **Required — always available**
- `{phase_name}` — Name of the phase just completed. **Required — always available**
- `{skill_references}` — Domain-specific skill references (same value as developer agent). **Fallback:** `"No domain-specific skills available — simplify using standard clean code principles."`

**Agent behavior:**
1. The code-simplifier reads each listed file and identifies simplification opportunities (dead code, naming, nesting, duplication).
2. Applies changes while preserving all functionality, builds after each file change.
3. Runs the full test suite as final verification and reports structured output.
4. MUST NOT modify test files, change public APIs, add dependencies, or alter observable behavior.

---

<!-- SECTION: Completion Validation Prompt -->
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

**Variables:** See Common Variables above, plus:
- `{test_cases_dir}` — Path to test-cases/ directory. **Fallback:** `"Not available"`
- `{traceability_file}` — Path to `analysis/task-test-traceability.md`. **Fallback:** `"Not available"`
- `{research_context}` — Documentation excerpts for API verification (see `stage-3-validation.md` Section 3.1). **Fallback:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:**
1. The developer agent reads tasks.md, verifies every task is `[X]`, runs the test suite, and cross-references implementation against plan.md and spec.md.
2. When test-case specs are available, validates test ID traceability.
3. Verifies constitution.md/CLAUDE.md compliance if those files declare architectural constraints.
4. Computes test coverage deltas against test-plan.md targets when available.
5. Independently runs the full test suite and reports `baseline_test_count`.
6. Scans test files for tautological/placeholder assertions per config patterns.
7. When research context is provided, performs advisory API documentation alignment checks.

---

<!-- SECTION: Quality Review Prompt -->
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

**Example:** A `LiveData` observer updating UI from a background thread matches both "UI state contradiction" and "race condition with user-visible effect" → classify as High, not Medium.

**Tiebreaker:** When uncertain whether a finding matches an escalation trigger, classify as Medium with note: `"Potential High — {trigger} may apply"`.

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

**Variables:** See Common Variables above, plus:
- `{focus_area}` — One of (see `config/implementation-config.yaml` for canonical list):
  - `"simplicity, DRY principles, and code elegance"`
  - `"bugs, functional correctness, and edge case handling"`
  - `"project conventions, abstractions, and pattern adherence"`
  **Required — always available**
- `{skill_references}` — Domain-specific skill references (see `stage-4-quality-review.md` Section 4.1a). **Fallback:** `"No domain-specific skills available — review against codebase conventions only."`
- `{research_context}` — Documentation excerpts from accumulated research URLs (see `stage-4-quality-review.md` Section 4.1b). **Fallback:** `"No research context available — review against codebase conventions only."`
- `{reviewer_stance}` — Stance instruction (advocate, challenger, neutral) from Stage 4 coordinator (Section 4.2). **Fallback:** `"No specific stance assigned — review objectively using your best judgment."`

**Agent behavior:**
1. The developer agent reads the changed files (from tasks.md file paths) and reviews code through its assigned lens.
2. Produces a structured list of findings using the specified output format.
3. When skill references are provided, consults them for domain-specific anti-patterns relevant to its focus area.
4. When research context is provided, uses it for documentation-backed review (API correctness, deprecated calls, pattern compliance).
5. When a reviewer stance is provided, adopts it: advocate emphasizes strengths, challenger stress-tests, neutral applies balanced judgment. Stances calibrate severity — they do not change review scope or output format.

---

<!-- SECTION: Review Fix Prompt -->
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

**Variables:** See Common Variables above, plus:
- `{findings_list}` — Markdown list of Critical and High findings, each with finding ID, description, file:line, and recommended fix. **Required — always available**

**Agent behavior:**
1. The developer agent reads each referenced file and applies targeted fixes for each listed finding.
2. Runs tests to verify no regressions.
3. Reports what was fixed with file:line references.

---

<!-- SECTION: Incomplete Task Fix Prompt -->
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

**Variables:** See Common Variables above, plus:
- `{incomplete_tasks_list}` — Markdown list of incomplete tasks, each with task ID, description, file path, and current status. **Required — always available**

**Agent behavior:**
1. The developer agent reads tasks.md and identifies the listed incomplete tasks.
2. Implements them following the Tasks.md Execution Workflow, marks each `[X]` on completion.
3. Runs tests to verify correctness.

---

<!-- SECTION: Documentation Update Prompt -->
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

**Variables:** See Common Variables above, plus:
- `{skill_references}` — Documentation-oriented skill references (see `stage-5-documentation.md` Section 5.1a). **Fallback:** `"No documentation skills available — produce prose documentation without diagrams."`
- `{research_context}` — Documentation excerpts from accumulated research URLs (see `stage-5-documentation.md` Section 5.1b). **Fallback:** `"No research context available — proceed with codebase knowledge and planning artifacts only."`

**Agent behavior:**
1. The tech-writer agent reads all context files from FEATURE_DIR and reviews the implemented code.
2. Creates/updates project documentation: API guides, usage examples, architecture updates, module READMEs, and lessons learned.
3. When diagram skills are provided, uses Mermaid.js syntax for architecture, sequence, and ERD diagrams.
4. When research context is provided, enriches documentation with official doc links and migration notes.
5. Produces a documentation update summary.

---

<!-- SECTION: Auto-Commit Prompt -->
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

**Example successful run:**

```
commit_status: success
commit_sha: a1b2c3d
files_committed: 5
reason: Phase 1 implementation committed
```

**Agent behavior:** The general-purpose subagent runs git commands to stage and commit changed files, excluding internal state files. It reports structured output that the coordinator logs. On any failure, the subagent reports the error without retrying — the coordinator treats all failures as non-blocking warnings.

---

<!-- SECTION: Retrospective Composition Prompt -->
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
- Use traffic light text markers for visual scanning: `[GREEN]`, `[YELLOW]`, `[RED]`
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
