# Agent Prompt Templates

All prompts in this file are used by the orchestrator to launch `developer` and `tech-writer` agents. Variables in `{braces}` MUST be prefilled by the orchestrator before dispatching.

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

**Agent behavior:** The developer agent reads its Tasks.md Execution Workflow section and executes all tasks in the specified phase, marking each `[X]` on completion. When test-case specs are available, the agent reads the relevant spec before writing each test to align with the planned strategy. When skill references are provided, the agent reads the referenced SKILL.md files on-demand for domain-specific patterns and anti-patterns — skills are consulted, not followed blindly (codebase conventions take precedence). The agent MUST run the full test suite as its final action and report `test_count_verified` and `test_failures` in the specified structured format.

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
   - Run the full test suite independently and report the verified count as `baseline_test_count: {N}` at the end of your validation report.
   - Report final status with summary of completed work

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}

Test cases directory: {test_cases_dir}
Task-test traceability: {traceability_file}

If test-case specs are available in test_cases_dir, verify that test IDs referenced in tasks.md have corresponding implemented test files. Report any gaps in the validation report.
```

**Variables:**
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{test_cases_dir}` — Path to test-cases/ directory, or `"Not available"` if the directory does not exist
- `{traceability_file}` — Path to `analysis/task-test-traceability.md`, or `"Not available"` if the file does not exist

**Agent behavior:** The developer agent reads tasks.md, verifies every task is `[X]`, runs the test suite, and cross-references implementation against plan.md and spec.md. When test-case specs are available, also validates test ID traceability. Verifies constitution.md/CLAUDE.md compliance if those files declare architectural constraints. Computes test coverage deltas against test-plan.md targets when available. Independently runs the full test suite and reports `baseline_test_count` in the validation report.

---

## Quality Review Prompt

Used in Stage 4. Launched 3 times in parallel with different `{focus_area}` values.

```markdown
**Goal**: Review the code implemented for {FEATURE_NAME}. Your assigned focus: {focus_area}.

## Review Instructions

1. Read TASKS_FILE to identify all files modified during implementation
2. Read each modified file and review through your assigned lens
3. Compare against existing codebase patterns (check CLAUDE.md, constitution.md if present)
4. If domain-specific skill references are provided below, consult them for domain-specific best practices relevant to your focus area
5. For each finding, provide structured output as described below

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

**Agent behavior:** The developer agent reads the changed files (extracted from tasks.md file paths), reviews code through its assigned lens, and produces a structured list of findings using the specified output format. When skill references are provided, the agent consults them for domain-specific anti-patterns and best practices relevant to its focus area.

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
```

**Variables:**
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md
- `{skill_references}` — Documentation-oriented skill references resolved by the coordinator (see `stage-5-documentation.md` Section 5.1a). Contains diagram generation and domain documentation skills. **Fallback:** `"No documentation skills available — produce prose documentation without diagrams."`

**Agent behavior:** The tech-writer agent reads all context files from FEATURE_DIR, reviews the implemented code, and creates/updates project documentation including API guides, usage examples, architecture updates, module READMEs, and lessons learned. When diagram skills are provided, the agent uses Mermaid.js syntax to create architecture, sequence, and ERD diagrams inline. Produces a documentation update summary.
