# Agent Prompt Templates

All prompts in this file are used by the orchestrator to launch `developer` agents. Variables in `{braces}` MUST be prefilled by the orchestrator before dispatching.

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
**Goal**: Tasks.md file is implemented, review newly implemented code. Focus on {focus_area}.

User Input: {user_input}

FEATURE_NAME: {FEATURE_NAME}
FEATURE_DIR: {FEATURE_DIR}
TASKS_FILE: {TASKS_FILE}
```

**Variables:**
- `{focus_area}` — One of:
  - `"simplicity, DRY principles, and code elegance"`
  - `"bugs, functional correctness, and edge case handling"`
  - `"project conventions, abstractions, and pattern adherence"`
- Other variables: Same as Phase Implementation Prompt.

**Agent behavior:** The developer agent reads the changed files (extracted from tasks.md file paths), reviews code through its assigned lens, and produces a structured list of findings with severity, file:line references, and recommendations.

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
