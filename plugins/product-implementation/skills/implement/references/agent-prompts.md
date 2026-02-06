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
```

**Variables:**
- `{phase_name}` — Name of the current phase (e.g., "Phase 1: Setup", "Phase 3: US1 - User Registration")
- `{user_input}` — Original user arguments, or empty string if none
- `{FEATURE_NAME}` — Feature identifier from git branch
- `{FEATURE_DIR}` — Path to feature spec directory
- `{TASKS_FILE}` — Path to tasks.md

**Agent behavior:** The developer agent reads its Tasks.md Execution Workflow section and executes all tasks in the specified phase, marking each `[X]` on completion.

---

## Completion Validation Prompt

Used in Stage 3 after all phases complete.

```markdown
**Goal**: Verify that all tasks in tasks.md file are completed in order and without errors.
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}
```

**Variables:** Same as Phase Implementation Prompt.

**Agent behavior:** The developer agent reads tasks.md, verifies every task is `[X]`, runs the test suite, and cross-references implementation against plan.md and spec.md. Produces a validation report.

---

## Quality Review Prompt

Used in Stage 4. Launched 3 times in parallel with different `{focus_area}` values.

```markdown
**Goal**: Review the code implemented for {FEATURE_NAME}. Your assigned focus: {focus_area}.

## Review Instructions

1. Read TASKS_FILE to identify all files modified during implementation
2. Read each modified file and review through your assigned lens
3. Compare against existing codebase patterns (check CLAUDE.md, constitution.md if present)
4. For each finding, provide structured output as described below

## Output Format

Return findings as a markdown list, one per issue:

- [{severity}] {description} — {file}:{line} — Recommendation: {fix}

Severity levels: Critical (breaks functionality, security risk), High (likely bugs, significant quality issue), Medium (code smell, maintainability concern), Low (style preference, minor optimization)

If no issues found for your focus area, state "No issues found" with a brief explanation of what you reviewed.

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}
```

**Variables:**
- `{focus_area}` — One of (see `config/implementation-config.yaml` for canonical list):
  - `"simplicity, DRY principles, and code elegance"`
  - `"bugs, functional correctness, and edge case handling"`
  - `"project conventions, abstractions, and pattern adherence"`
- Other variables: Same as Phase Implementation Prompt.

**Agent behavior:** The developer agent reads the changed files (extracted from tasks.md file paths), reviews code through its assigned lens, and produces a structured list of findings using the specified output format.

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
- Other variables: Same as Phase Implementation Prompt.

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
- Other variables: Same as Phase Implementation Prompt.

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
```

**Variables:** Same as Phase Implementation Prompt.

**Agent behavior:** The tech-writer agent reads all context files from FEATURE_DIR, reviews the implemented code, and creates/updates project documentation including API guides, usage examples, architecture updates, module READMEs, and lessons learned. Produces a documentation update summary.
