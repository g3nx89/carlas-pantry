---
phase: "9"
phase_name: "Task Generation & Completion"
checkpoint: "COMPLETION"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-7-summary.md"
  - ".phase-summaries/phase-8-summary.md"
artifacts_read:
  - "spec.md"
  - "plan.md"
  - "design.md"
  - "test-plan.md"
  - "test-cases/unit/"
  - "test-cases/integration/"
  - "test-cases/e2e/"
  - "test-cases/uat/"
artifacts_written:
  - "tasks.md"
  - "analysis/task-test-traceability.md"
agents:
  - "product-planning:tech-lead"
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "st_task_decomposition"
  - "a5_post_planning_menu"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/templates/tasks-template.md"
---

# Phase 9: Task Generation & Completion

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-9-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

**Integrated task generation with full context from Phases 1-8.**

This phase consolidates all planning artifacts and generates actionable, dependency-ordered tasks with TDD structure. The tech-lead agent receives complete context including test specifications.

## Step 9.0: Task Regeneration Check (Optional Entry Point)

**Purpose:** Allow users to regenerate tasks without re-running Phases 1-8 when planning is already complete.

```
IF user requests "regenerate tasks" OR "update tasks" OR triggers Phase 9 directly:

  1. CHECK planning state:
     READ {FEATURE_DIR}/.planning-state.local.md

     IF state.phase == "COMPLETION" OR state.phase == "TEST_COVERAGE_VALIDATION":
       # Planning already complete - can regenerate tasks directly
       LOG: "Planning complete. Regenerating tasks with existing artifacts."

       # Verify required artifacts exist
       REQUIRED_ARTIFACTS = [
         "{FEATURE_DIR}/spec.md",
         "{FEATURE_DIR}/plan.md",
         "{FEATURE_DIR}/design.md",
         "{FEATURE_DIR}/test-plan.md"
       ]

       FOR artifact IN REQUIRED_ARTIFACTS:
         IF NOT exists(artifact):
           ERROR: "Missing required artifact: {artifact}. Run /plan to generate."
           → Abort regeneration

       # Acquire lock for Phase 9 only
       CREATE {FEATURE_DIR}/.planning.lock

       # Proceed directly to Step 9.1
       → Continue to Step 9.1

     ELSE IF state.phase < "TEST_COVERAGE_VALIDATION":
       # Planning not complete
       SET status: needs-user-input
       SET block_reason: "Planning not complete (current phase: {state.phase}). Options: (1) Run full /plan workflow, (2) Abort"

  2. IF no planning state exists:
     SET status: needs-user-input
     SET block_reason: "No planning state found. Cannot regenerate without prior planning. Run /product-planning:plan first."

ELSE:
  # Normal workflow - coming from Phase 8
  → Continue to Step 9.1
```

**Trigger Phrases for Regeneration:**
- "regenerate tasks for this feature"
- "update the task breakdown"
- "rerun Phase 9"
- "refresh tasks.md"

## Step 9.1: Load Task Generation Context

```
1. READ planning artifacts:
   - {FEATURE_DIR}/spec.md (user stories with priorities)
   - {FEATURE_DIR}/plan.md (tech stack, libraries, structure)
   - {FEATURE_DIR}/design.md (architecture decisions)
   - specs/constitution.md (project conventions)

2. READ test artifacts (from Phases 7-8):
   - {FEATURE_DIR}/test-plan.md (V-Model strategy, coverage matrix)
   - {FEATURE_DIR}/test-cases/unit/*.md (TDD specifications)
   - {FEATURE_DIR}/test-cases/integration/*.md
   - {FEATURE_DIR}/test-cases/e2e/*.md
   - {FEATURE_DIR}/test-cases/uat/*.md

3. READ optional artifacts:
   - {FEATURE_DIR}/data-model.md (entities) if exists
   - {FEATURE_DIR}/contract.md (API endpoints) if exists
   - {FEATURE_DIR}/research.md (decisions, patterns) if exists

4. EXTRACT test IDs for TDD integration:
   # Parse test files for ID patterns in markdown headers
   # Pattern: ^## (UT|INT|E2E|UAT)-\d{3}: or ^### (UT|INT|E2E|UAT)-\d{3}:
   # Example: "## UT-001: User registration validation" → extracts "UT-001"

   test_ids = {
     unit: [UT-001, UT-002, ...],      # From test-cases/unit/*.md headers
     integration: [INT-001, ...],       # From test-cases/integration/*.md headers
     e2e: [E2E-001, ...],              # From test-cases/e2e/*.md headers
     uat: [UAT-001, ...]               # From test-cases/uat/*.md headers
   }

   # Fallback: If no IDs found, generate placeholder IDs based on file count
   IF test_ids.unit is empty AND test-cases/unit/ has files:
     LOG: "Warning: No test IDs found in unit test files, using file-based placeholders"

5. EXTRACT user stories with priorities:
   user_stories = PARSE spec.md for stories (P1, P2, P3...)

6. LOG context summary:
   "Task generation context: {story_count} stories, {test_count} tests, {entity_count} entities"
```

## Step 9.2: Initialize Tasks File

```
COPY $CLAUDE_PLUGIN_ROOT/templates/tasks-template.md to {FEATURE_DIR}/tasks.md

UPDATE tasks.md header with:
  - Feature name from FEATURE_NAME
  - Generation date
  - Analysis mode used
  - Test artifact references
```

## Step 9.3: Launch Tech-Lead Agent with Sequential Thinking

**Complete/Advanced modes:** Use ST T-TASK templates for structured decomposition.
**Standard/Rapid modes:** Use inline structured reasoning.

```
Task(
  subagent_type: "product-planning:tech-lead",
  prompt: """
    **Goal**: Create dependency-ordered tasks for implementation with TDD structure.

    ## Feature Context
    FEATURE_NAME: {FEATURE_NAME}
    FEATURE_DIR: {FEATURE_DIR}
    TASKS_FILE: {FEATURE_DIR}/tasks.md
    ANALYSIS_MODE: {analysis_mode}

    ## Input Artifacts
    - spec.md: {spec_summary - user stories with priorities}
    - plan.md: {plan_summary - tech stack, approach}
    - design.md: {design_summary - architecture decisions}
    - constitution.md: {constitution_summary - project conventions}

    ## Test Artifacts (CRITICAL for TDD integration)
    - test-plan.md: {test_plan_summary}
    - Unit Test IDs: {test_ids.unit}
    - Integration Test IDs: {test_ids.integration}
    - E2E Test IDs: {test_ids.e2e}
    - UAT Test IDs: {test_ids.uat}

    ## Optional Artifacts
    - data-model.md: {data_model_summary or "NOT AVAILABLE"}
    - contract.md: {contracts_summary or "NOT AVAILABLE"}
    - research.md: {research_summary or "NOT AVAILABLE"}

    ## Instructions
    1. Apply Least-to-Most Decomposition methodology
    2. Generate tasks organized by user story (Phase 3+)
    3. Include test references in every task's Definition of Done
    4. Use strict checklist format: `- [ ] [TaskID] [P?] [Story?] Description with file path`
    5. Map each task to relevant test IDs: UT-*, INT-*, E2E-*, UAT-*
    6. Identify high-risk tasks for clarification

    ## TDD Structure per Task
    Each implementation task follows: TEST (RED) → IMPLEMENT (GREEN) → VERIFY

    ## Output
    Fill {TASKS_FILE} following the task generation workflow in your instructions.
    Include self-critique summary at the end.
  """,
  description: "Generate TDD-structured task breakdown"
)
```

**Sequential Thinking Integration (Complete/Advanced):**

```
IF feature_flags.st_task_decomposition.enabled AND analysis_mode in {complete, advanced}:

  # T-TASK-1: DECOMPOSE - Establish level structure
  mcp__sequential-thinking__sequentialthinking({
    thought: "DECOMPOSITION of {FEATURE_NAME}. LEVEL 0 (zero dependencies): [config, types, schemas, interfaces]. LEVEL 1 (depends on L0): [utilities, base models, test fixtures]. LEVEL 2+: [per user story subproblems]. DEPENDENCY CHAIN: L0 → L1 → L2 → Feature complete.",
    thoughtNumber: 1,
    totalThoughts: 4,
    nextThoughtNeeded: true,
    hypothesis: "Feature decomposes into {N} levels with {M} tasks",
    confidence: "medium"
  })

  # T-TASK-2: SEQUENCE - Order within levels
  mcp__sequential-thinking__sequentialthinking({
    thought: "SEQUENCING tasks. STRATEGY: {top-down|bottom-up|mixed} because {rationale}. LEVEL 0 ORDER: [...]. LEVEL 1 ORDER: [...]. PER-STORY ORDER: [...]. CRITICAL PATH: [...]. RISK-FIRST items: [...].",
    thoughtNumber: 2,
    totalThoughts: 4,
    nextThoughtNeeded: true,
    hypothesis: "Optimal sequence minimizes blocking, critical path is {N} tasks",
    confidence: "high"
  })

  # T-TASK-3: VALIDATE - Verify correctness
  mcp__sequential-thinking__sequentialthinking({
    thought: "VALIDATION of task breakdown. CHECKLIST: [ ] All user stories covered? [ ] No circular dependencies? [ ] Each task depends only on earlier levels? [ ] Every task 1-2 days? [ ] TDD pattern respected (tests in DoD)? [ ] Test IDs mapped? ISSUES: [...]. FIXES: [...].",
    thoughtNumber: 3,
    totalThoughts: 4,
    nextThoughtNeeded: true,
    isRevision: true,
    revisesThought: 1,
    hypothesis: "Task breakdown valid after {N} fixes",
    confidence: "high"
  })

  # T-TASK-4: FINALIZE - Produce deliverable
  mcp__sequential-thinking__sequentialthinking({
    thought: "FINALIZATION. SUMMARY: {total} tasks across {levels} levels. HIGH-RISK requiring attention: [{task}: {context}]. PARALLEL PLAN: [{concurrent groups}]. MVP SCOPE: [{first deliverable}]. TDD READINESS: {count} tasks have test references.",
    thoughtNumber: 4,
    totalThoughts: 4,
    nextThoughtNeeded: false,
    hypothesis: "Task breakdown complete, ready for clarification review",
    confidence: "high"
  })
```

## Step 9.4: Task Clarification Loop

**Purpose:** Present high-risk/uncertain tasks to user for clarification before finalizing.

**USER INTERACTION:** This step requires user input if high-risk tasks are identified.

```
iteration = 0
max_iterations = 2

WHILE iteration < max_iterations:

  1. PARSE tech-lead output for high-risk items:
     high_risk_tasks = EXTRACT tasks with:
       - Complexity: High
       - Uncertainty: High
       - Missing information flagged

  2. IF high_risk_tasks is empty:
     LOG: "No high-risk tasks identified"
     BREAK

  3. SET status: needs-user-input
     SET block_reason: """
       HIGH-RISK TASKS REQUIRING CLARIFICATION:

       {FOR each task IN high_risk_tasks:}
         **{task.id}: {task.subject}**
         - Complexity: {task.complexity}
         - Uncertainty: {task.uncertainty}
         - Context: {task.risk_context}

       Options:
       1. Decompose these tasks into smaller pieces
       2. Clarify uncertain areas with more detail
       3. Proceed as-is with risks documented
       4. Add spike/research tasks to reduce uncertainty
     """

  4. ON re-dispatch after user input:
     READ {FEATURE_DIR}/.phase-summaries/phase-9-user-input.md

     IF user provides clarifications:
       # Re-run tech-lead with additional context
       Task(
         subagent_type: "product-planning:tech-lead",
         prompt: """
           **Goal**: Refine task breakdown based on user clarifications.

           Previous output: {previous_tasks_md}

           User clarifications:
           {user_clarifications}

           Update tasks.md to address the clarifications.
         """
       )
       iteration += 1

     ELSE IF user chooses "Proceed as-is":
       LOG: "User accepted risks - proceeding with current breakdown"
       BREAK
```

## Step 9.5: Task Validation

**Purpose:** Verify task breakdown meets quality standards before finalizing.

```
1. RUN self-critique validation:

   QUESTIONS = [
     "Does every user story from spec.md have all required tasks?",
     "Can each task start when its predecessors complete (no forward dependencies)?",
     "Does every implementation task include test writing in Definition of Done?",
     "Is every task completable in 1-2 days?",
     "Are all high-risk tasks either decomposed or have spike tasks?"
   ]

   FOR each question IN QUESTIONS:
     answer = EVALUATE against tasks.md
     evidence = EXTRACT supporting evidence

   passed = COUNT(answers == "Yes")

2. VERIFY TDD integration:
   FOR each task IN tasks.md:
     IF task is implementation task:
       ASSERT task.definition_of_done contains test reference (UT-*, INT-*)
       IF NOT → FLAG as incomplete

3. VERIFY test coverage mapping:
   FOR each test_id IN test_ids:
     ASSERT exists task referencing test_id
     IF NOT → FLAG as unmapped test

4. VALIDATE checklist format:
   FOR each task IN tasks.md:
     ASSERT format matches: `- [ ] [T###] [P?] [US#?] Description with file path`
     IF NOT → FLAG for correction

5. GENERATE validation summary:
   ```yaml
   task_validation:
     self_critique_passed: {passed}/5
     tdd_integration: {compliant_count}/{total_tasks}
     test_mapping: {mapped_tests}/{total_tests}
     format_compliance: {valid_format}/{total_tasks}
     high_risk_addressed: {addressed}/{flagged}
   ```

6. IF validation fails critical checks (passed < 4 OR tdd_integration < 80%):
   LOG: "Task validation failed - requesting revision"
   → Return to Step 9.3 with validation feedback (max 1 retry)
```

## Step 9.6: Generate Final Artifacts

```
1. FINALIZE tasks.md:
   - Ensure header is complete
   - Add task-to-test traceability matrix
   - Include validation summary
   - Add implementation strategy section

2. UPDATE design.md:
   - Add task references to components
   - Include final refinements from tech-lead

3. UPDATE plan.md:
   - Add task count summary
   - Include critical path information
   - Add MVP scope recommendation

4. GENERATE traceability matrix:
   Write to {FEATURE_DIR}/analysis/task-test-traceability.md:

   | Task ID | User Story | Tests Referenced | Test Level |
   |---------|------------|------------------|------------|
   | T001    | Setup      | -                | -          |
   | T010    | US1        | UT-001, UT-002   | Unit       |
   | T011    | US1        | INT-001          | Integration|
   ...
```

## Step 9.7: Output Artifacts Summary

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture with task references |
| `plan.md` | Implementation plan with task summary |
| `tasks.md` | Dependency-ordered tasks with TDD structure |
| `test-plan.md` | V-Model test strategy (from Phase 7) |
| `test-cases/` | Test specifications by level (from Phase 7) |
| `analysis/task-test-traceability.md` | Task-to-test mapping matrix |
| `data-model.md` | Entity definitions (optional) |
| `contract.md` | API contracts (optional) |

## Step 9.8: Generate Summary Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    PLANNING COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: {FEATURE_NAME}
Mode: {analysis_mode}

Architecture:
├── Design: {selected_approach}
├── Validation: {GREEN/YELLOW} ({score}/20)

Test Strategy (V-Model):
├── Unit Tests: {unit_count} specifications
├── Integration Tests: {int_count} specifications
├── E2E Tests: {e2e_count} scenarios
├── UAT Scripts: {uat_count} scripts
├── Coverage: {GREEN/YELLOW} ({coverage_score}%)

Task Breakdown:
├── Total Tasks: {task_count}
├── Setup/Foundational: {setup_count}
├── Per User Story: {story_task_breakdown}
├── Parallel Opportunities: {parallel_count}
├── TDD Integration: {tdd_percent}% tasks have test refs
├── High-Risk Tasks: {high_risk_count} (addressed: {addressed})

Critical Path: {critical_path_tasks}
MVP Scope: {mvp_scope}

Artifacts Generated:
├── design.md
├── plan.md
├── tasks.md (TDD-structured)
├── test-plan.md
├── test-cases/{unit,integration,e2e,uat}/
└── analysis/task-test-traceability.md

Next Steps:
1. Review tasks.md - verify task ordering and dependencies
2. Begin implementation following TDD cycle:
   - RED: Write failing tests from test-cases/unit/
   - GREEN: Implement to pass tests
   - VERIFY: Run integration tests
3. Commit: git add . && git commit -m "feat: plan {FEATURE_NAME}"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Include this summary report in the phase summary's `summary` field.

## Step 9.9: Cleanup

```
DELETE {FEATURE_DIR}/.planning.lock
UPDATE state.phase = COMPLETION
UPDATE state.tasks_generated = true
UPDATE state.task_count = {task_count}
SAVE state to {FEATURE_DIR}/.planning-state.local.md
```

## Step 9.10: Post-Planning Menu (A5)

**Purpose:** Provide structured options for next steps after planning completion.

```
IF feature_flags.a5_post_planning_menu.enabled:

  SET status: needs-user-input
  SET block_reason: """
    PLANNING COMPLETE. What would you like to do next?

    1. [Review]   Open artifacts in editor for review
    2. [Expert]   Get expert review (security + simplicity)
    3. [Simplify] Reduce plan complexity
    4. [GitHub]   Create GitHub issue from plan
    5. [Commit]   Commit all planning artifacts
    6. [Quit]     Exit planning session
  """
```

**Option Handlers (executed by orchestrator after receiving user choice):**

**1. Review:**
```
OPEN {FEATURE_DIR}/design.md in editor
OPEN {FEATURE_DIR}/plan.md in editor
OPEN {FEATURE_DIR}/tasks.md in editor
SUGGEST: "Review artifacts and let me know if you'd like changes"
```

**2. Expert Review:**
```
IF analysis_mode in {complete, advanced}:
  LAUNCH security-analyst agent → review design.md + plan.md
  LAUNCH simplicity-reviewer agent → review tasks.md
  CONSOLIDATE feedback
  PRESENT findings to user
ELSE:
  DISPLAY: "Expert review available in Advanced/Complete modes"
```

**3. Simplify:**
```
ANALYZE tasks.md for:
  - Tasks that can be combined
  - Phases that can be merged
  - Complexity that can be deferred
PRESENT simplification options
IF user approves → UPDATE tasks.md
```

**4. GitHub Issue:**
```
READ template from $CLAUDE_PLUGIN_ROOT/templates/github-issue-template.md
EXTRACT values from:
  - {FEATURE_DIR}/spec.md (ACs)
  - {FEATURE_DIR}/design.md (architecture decisions)
  - {FEATURE_DIR}/tasks.md (task summary)
  - {FEATURE_DIR}/test-plan.md (test counts)
GENERATE issue body
RUN: gh issue create --title "{title}" --body "{body}"
DISPLAY: Issue URL
```

**5. Commit:**
```
STAGE files:
  - {FEATURE_DIR}/design.md
  - {FEATURE_DIR}/plan.md
  - {FEATURE_DIR}/tasks.md
  - {FEATURE_DIR}/test-plan.md
  - {FEATURE_DIR}/research.md (if exists)
  - {FEATURE_DIR}/analysis/*.md
  - {FEATURE_DIR}/test-cases/**/*.md

COMMIT with message:
  "feat(planning): complete plan for {FEATURE_NAME}

  Architecture: {selected_approach}
  Tasks: {task_count}
  Test Coverage: {coverage_status}

  Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

**6. Quit:**
```
DISPLAY: "Planning session complete. Artifacts saved to {FEATURE_DIR}/"
EXIT
```

**Checkpoint: COMPLETION**
