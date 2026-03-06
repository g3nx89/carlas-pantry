---
phase: "9"
phase_name: "Task Generation & Completion"
checkpoint: "COMPLETION"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-4-summary.md"
  - ".phase-summaries/phase-6-summary.md"
  - ".phase-summaries/phase-7-summary.md"
  - ".phase-summaries/phase-8-summary.md"
  - ".phase-summaries/phase-8b-summary.md"
artifacts_read:
  - "spec.md"
  - "plan.md"
  - "design.md"
  - "test-plan.md"
  - "test-cases/unit/"
  - "test-cases/integration/"
  - "test-cases/e2e/"
  - "test-cases/uat/"
  - "asset-manifest.md"
artifacts_written:
  - "tasks.md"
  - "analysis/task-test-traceability.md"
  - "analysis/cli-taskaudit-report.md"  # conditional: CLI dispatch enabled
  - ".phase-summaries/phase-9-skill-context.md"  # conditional: dev_skills_integration enabled
agents:
  - "product-planning:tech-lead"
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "st_task_decomposition"
  - "a5_post_planning_menu"
  - "cli_context_isolation"
  - "cli_custom_roles"
  - "dev_skills_integration"
  - "phase_9_parallel_generation"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/templates/tasks-template.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

<!-- Mode Applicability -->
| Step  | Rapid | Standard | Advanced | Complete | Notes |
|-------|-------|----------|----------|----------|-------|
| 9.1   | ✓     | ✓        | ✓        | ✓        | Optional entry point |
| 9.2   | ✓     | ✓        | ✓        | ✓        | — |
| 9.2b  | ✓     | ✓        | ✓        | ✓        | Pre-compute test spec map |
| 9.3   | —     | ✓        | ✓        | ✓        | `(dev_skills_integration)` |
| 9.4   | ✓     | ✓        | ✓        | ✓        | — |
| 9.5   | ✓     | ✓        | ✓        | ✓        | ST for Adv/Complete; inline for Rapid/Std |
| 9.5p  | —     | —        | ✓        | ✓        | `(phase_9_parallel_generation)` — parallel alternative to 9.5 |
| 9.6   | ✓     | ✓        | ✓        | ✓        | User interaction if high-risk tasks found |
| 9.7   | ✓     | ✓        | ✓        | ✓        | — |
| 9.8   | —     | —        | ✓        | ✓        | CLI task audit |
| 9.9   | ✓     | ✓        | ✓        | ✓        | — |
| 9.9b  | ✓     | ✓        | ✓        | ✓        | Traceability matrix (delegated) |
| 9.10  | ✓     | ✓        | ✓        | ✓        | — |
| 9.11  | ✓     | ✓        | ✓        | ✓        | — |
| 9.12  | ✓     | ✓        | ✓        | ✓        | — |
| 9.13  | ✓     | ✓        | ✓        | ✓        | `(a5_post_planning_menu)` |

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

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

**Integrated task generation with full context from Phases 1-8.**

This phase consolidates all planning artifacts and generates actionable, dependency-ordered tasks with TDD structure. The tech-lead agent receives complete context including test specifications.

## Step 9.1: Task Regeneration Check (Optional Entry Point)

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
           → Abort regeneration  # No lock held — safe to abort

       # All preconditions passed — now acquire lock
       CREATE {FEATURE_DIR}/.planning.lock

       # Proceed directly to Step 9.2
       → Continue to Step 9.2

     ELSE IF state.phase < "TEST_COVERAGE_VALIDATION":
       # Planning not complete — no lock acquired
       SET status: needs-user-input
       SET block_reason: "Planning not complete (current phase: {state.phase}). Options: (1) Run full /plan workflow, (2) Abort"

  2. IF no planning state exists:
     # No lock acquired — safe to abort
     SET status: needs-user-input
     SET block_reason: "No planning state found. Cannot regenerate without prior planning. Run /product-planning:plan first."

ELSE:
  # Normal workflow - coming from Phase 8 (lock already held by orchestrator)
  → Continue to Step 9.2
```

**Trigger Phrases for Regeneration:**
- "regenerate tasks for this feature"
- "update the task breakdown"
- "rerun Phase 9"
- "refresh tasks.md"

## Step 9.2: Load Task Generation Context

```
1. READ planning artifacts:
   - {FEATURE_DIR}/spec.md (user stories with priorities)
   - {FEATURE_DIR}/plan.md (tech stack, libraries, structure)
   - {FEATURE_DIR}/design.md (architecture decisions)
   - specs/constitution.md (project conventions)  # Path configurable via config.guards.constitution_path

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

4. READ asset manifest (from Phase 8b):
   IF file_exists("{FEATURE_DIR}/asset-manifest.md"):
     READ asset_manifest
     EXTRACT asset_count, categories, individual assets
     IF asset_manifest.status == "validated":
       LOG: "Asset manifest loaded: {asset_count} assets across {categories}"
     ELSE IF asset_manifest.status == "skipped":
       LOG: "Asset manifest skipped by user — no Phase 0 tasks"
       asset_manifest = null
   ELSE:
     LOG: "No asset manifest found — Phase 8b may have been skipped"
     asset_manifest = null

5. BUILD test_spec_map and test_ids via Step 9.2b (see below).
   # Step 9.2b extracts test IDs from all test-case files and writes
   # a pre-computed map to .phase-summaries/phase-9-test-map.md.
   # The flat test_ids list is also derived there for backward-compatible validation.

   # Fallback: If no IDs found, generate placeholder IDs based on file count
   IF test_ids.unit is empty AND test-cases/unit/ has files:
     LOG: "Warning: No test IDs found in unit test files, using file-based placeholders"

5b. EXTRACT design/screen references for UI tasks:
   # Scan spec.md and design.md for screen/component references.
   # Extraction patterns (check in order):
   #   1. Markdown headers containing "Screen", "View", "Page", "Component", "Widget":
   #      Pattern: ^#{1,3} .*(Screen|View|Page|Component|Widget)
   #      Example: "## Timer Component" → name: "Timer Component"
   #   2. Bullet items with explicit labels:
   #      Pattern: ^[-*] \**(Screen|Component|View|Page)\**: (.+)
   #      Example: "- **Screen**: Workout Timer" → name: "Workout Timer"
   #   3. Figma/design references:
   #      Pattern: figma\.com|design\.md §|mockup|wireframe
   # Map each screen/component to user stories by checking for story refs (US1, "As a user") in same section.

   design_refs = {
     screens: [
       { name: "Login Screen", source: "spec.md", stories: ["US1"] },
       ...
     ],
     components: [
       { name: "Timer Widget", source: "design.md § Timer Component", stories: ["US2"] },
       ...
     ]
   }

   IF design_refs.screens is empty AND design_refs.components is empty:
     LOG: "Warning: No screen/component references found in spec.md or design.md"
     design_refs = null

6. EXTRACT user stories with priorities:
   user_stories = PARSE spec.md for stories (P1, P2, P3...)

7. LOG context summary:
   "Task generation context: {story_count} stories, {test_count} tests, {entity_count} entities"
```

## Step 9.2b: Pre-compute Test Spec Map

**Purpose:** Extract test IDs with file/section references BEFORE dispatching the tech-lead agent. This reduces the tech-lead's parsing burden from ~50KB of raw test-case files to a ~5KB pre-computed map. Runs inline (parsing, not reasoning).

```
test_spec_map = { unit: [], integration: [], e2e: [], uat: [] }

FOR each level IN [unit, integration, e2e, uat]:
  FOR each file IN {FEATURE_DIR}/test-cases/{level}/*.md:
    content = READ(file)

    # Format A — Markdown headers (used by UAT scripts):
    #   Pattern: ^#{2,3} (UT|INT|E2E|UAT)-\d{2,3}: (.+)
    FOR each match OF /^#{2,3}\s+((?:UT|INT|E2E|UAT)-\d{2,3}):\s+(.+)/gm IN content:
      APPEND { id: match[1], file: relative_path(file), section: match[2] } to test_spec_map[level]

    # Format B — Table rows (used by unit/integration/E2E specs):
    #   Pattern: ^\| (UT|INT|E2E|UAT)-\d{2,3} \|
    FOR each match OF /^\|\s+((?:UT|INT|E2E|UAT)-\d{2,3})\s+\|\s+([^|]+)\|\s+([^|]+)\|/gm IN content:
      section = TRIM(match[2]) + " — " + TRIM(match[3])
      APPEND { id: match[1], file: relative_path(file), section: section } to test_spec_map[level]

total_count = SUM(LEN(test_spec_map[level]) for level in [unit, integration, e2e, uat])

# Write pre-computed map for tech-lead consumption
WRITE to {FEATURE_DIR}/.phase-summaries/phase-9-test-map.md:
  """
  ---
  total_tests: {total_count}
  unit_count: {LEN(test_spec_map.unit)}
  integration_count: {LEN(test_spec_map.integration)}
  e2e_count: {LEN(test_spec_map.e2e)}
  uat_count: {LEN(test_spec_map.uat)}
  ---

  # Pre-computed Test Spec Map

  ## Unit Tests
  {FOR t IN test_spec_map.unit: "- {t.id}: {t.file} § {t.section}"}

  ## Integration Tests
  {FOR t IN test_spec_map.integration: "- {t.id}: {t.file} § {t.section}"}

  ## E2E Tests
  {FOR t IN test_spec_map.e2e: "- {t.id}: {t.file} § {t.section}"}

  ## UAT Tests
  {FOR t IN test_spec_map.uat: "- {t.id}: {t.file} § {t.section}"}
  """

LOG: "Pre-computed test map: {total_count} tests across {file_count} files"

# Keep flat list for backward-compatible validation
test_ids = {
  unit: test_spec_map.unit.map(t => t.id),
  integration: test_spec_map.integration.map(t => t.id),
  e2e: test_spec_map.e2e.map(t => t.id),
  uat: test_spec_map.uat.map(t => t.id)
}
```

> **Note:** Step 9.5 tech-lead prompt now reads `phase-9-test-map.md` instead of parsing raw test-case files inline. The raw files are still listed in `artifacts_read` for validation (Step 9.7).

## Step 9.3: Dev-Skills Context Loading [IF dev_skills_integration]

**Purpose:** Load clean-code quality standards to enrich the tech-lead's task generation.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md`

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase 9 (Task Generation).

    Load the following skill and extract ONLY the specified sections:

    1. Skill("dev-skills:clean-code") → extract:
       - Function rules (max 20 lines, few args, single responsibility)
       - Naming rules (variables, functions, booleans)
       - AI coding style guidance
       LIMIT: 800 tokens

    WRITE condensed output to: {FEATURE_DIR}/.phase-summaries/phase-9-skill-context.md
    FORMAT: YAML frontmatter + markdown sections per skill
    TOTAL BUDGET: 800 tokens max
    IF Skill() call fails → write empty context file with skills_failed
  """)

  READ {FEATURE_DIR}/.phase-summaries/phase-9-skill-context.md
  IF file exists AND not empty:
    INJECT into tech-lead prompt (Step 9.5) as:
    "## Task Quality Standards (from dev-skills)\n{section content}"
```

## Step 9.4: Initialize Tasks File

```
COPY $CLAUDE_PLUGIN_ROOT/templates/tasks-template.md to {FEATURE_DIR}/tasks.md

UPDATE tasks.md header with:
  - Feature name from FEATURE_NAME
  - Generation date
  - Analysis mode used
  - Test artifact references
```

## Step 9.5: Launch Tech-Lead Agent with Sequential Thinking

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
    - Pre-computed test map: {FEATURE_DIR}/.phase-summaries/phase-9-test-map.md
      READ this file for all test IDs with source file and section references.
      Use `(spec: {file} § {section})` format when mapping tasks to tests.

    ## Design References
    {IF design_refs:}
    Screens and components extracted from spec.md/design.md. Reference these in UI tasks.
    **Screens:**
    {FOR s IN design_refs.screens: "- {s.name} (source: {s.source}, stories: {s.stories})"}
    **Components:**
    {FOR c IN design_refs.components: "- {c.name} (source: {c.source}, stories: {c.stories})"}
    {ELSE:}
    No design references found. For UI tasks, use `(design: TBD)` and flag Uncertainty: High.
    {END}

    ## Optional Artifacts
    - data-model.md: {data_model_summary or "NOT AVAILABLE"}
    - contract.md: {contracts_summary or "NOT AVAILABLE"}
    - research.md: {research_summary or "NOT AVAILABLE"}

    ## Asset Manifest (from Phase 8b)
    asset_manifest: {asset_manifest_summary or "No asset manifest — skip Phase 0"}

    ## Instructions
    1. Apply Least-to-Most Decomposition methodology
    2. IF asset_manifest exists AND status == "validated":
       Generate "Phase 0: Asset Preparation" BEFORE Phase 1 (Setup).
       For each asset where status == "needs-preparation":
         Generate task: [T0XX] [P] Prepare {asset_name} ({asset_id}) — {format/specs}
       All asset tasks are marked [P] (parallelizable, no code dependencies).
       No TDD structure (assets are not code) but include validation criteria.
    3. Generate tasks organized by user story (Phase 3+)
    4. Include test references in every task's Definition of Done
    5. Use strict checklist format: `- [ ] [TaskID] [P?] [Story?] Description with file path`
    6. Map each task to relevant test IDs using `(spec: {file} § {section})` format.
       The Test Spec Map above provides the file and section for each ID.
       Example: `- [ ] T010 [US1] Write unit tests UT-01..02 (spec: test-cases/unit/auth.md § UserService.create)`
    7. Identify high-risk tasks for clarification

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
    thought: "DECOMPOSITION of {FEATURE_NAME}. LEVEL 0 (zero dependencies): [config, types, schemas, interfaces]. LEVEL 1 (depends on L0): [utilities, base models, test fixtures]. LEVEL 2+: [per user story subproblems]. DEPENDENCY CHAIN: L0 → L1 → L2 → Feature complete. HYPOTHESIS: Feature decomposes into {N} levels with {M} tasks. CONFIDENCE: medium.",
    thoughtNumber: 1,
    totalThoughts: 4,
    nextThoughtNeeded: true
  })

  # T-TASK-2: SEQUENCE - Order within levels
  mcp__sequential-thinking__sequentialthinking({
    thought: "SEQUENCING tasks. STRATEGY: {top-down|bottom-up|mixed} because {rationale}. LEVEL 0 ORDER: [...]. LEVEL 1 ORDER: [...]. PER-STORY ORDER: [...]. CRITICAL PATH: [...]. RISK-FIRST items: [...]. HYPOTHESIS: Optimal sequence minimizes blocking, critical path is {N} tasks. CONFIDENCE: high.",
    thoughtNumber: 2,
    totalThoughts: 4,
    nextThoughtNeeded: true
  })

  # T-TASK-3: VALIDATE - Verify correctness
  mcp__sequential-thinking__sequentialthinking({
    thought: "VALIDATION of task breakdown. CHECKLIST: [ ] All user stories covered? [ ] No circular dependencies? [ ] Each task depends only on earlier levels? [ ] Every task 1-2 days? [ ] TDD pattern respected (tests in DoD)? [ ] Test IDs mapped? ISSUES: [...]. FIXES: [...]. HYPOTHESIS: Task breakdown valid after {N} fixes. CONFIDENCE: high.",
    thoughtNumber: 3,
    totalThoughts: 4,
    nextThoughtNeeded: true,
    isRevision: true,
    revisesThought: 1
  })

  # T-TASK-4: FINALIZE - Produce deliverable
  mcp__sequential-thinking__sequentialthinking({
    thought: "FINALIZATION. SUMMARY: {total} tasks across {levels} levels. HIGH-RISK requiring attention: [{task}: {context}]. PARALLEL PLAN: [{concurrent groups}]. MVP SCOPE: [{first deliverable}]. TDD READINESS: {count} tasks have test references. HYPOTHESIS: Task breakdown complete, ready for clarification review. CONFIDENCE: high.",
    thoughtNumber: 4,
    totalThoughts: 4,
    nextThoughtNeeded: false
  })
```

## Step 9.5p: Parallel Task Generation [IF phase_9_parallel_generation]

**Purpose:** Split task generation into per-implementation-phase sub-agents for ~2.7× speedup on large specs. Only activates when the flag is enabled AND estimated task count exceeds the configured threshold.

**Replaces Step 9.5** when active. Falls back to Step 9.5 (single tech-lead) otherwise.

```
IF feature_flags.phase_9_parallel_generation.enabled
   AND analysis_mode IN {complete, advanced}:

  # Estimate task count from plan.md phase sections
  phases = EXTRACT implementation phase sections from {FEATURE_DIR}/plan.md
  # Typical: Phase 0 (assets), Phase A (foundation), Phase B-E (features)
  estimated_tasks = SUM(estimated_task_count per phase)

  IF estimated_tasks < config.feature_flags.phase_9_parallel_generation.min_task_threshold:
    LOG: "Estimated {estimated_tasks} tasks < threshold — using sequential Step 9.5"
    → FALL THROUGH to Step 9.5

  LOG: "Estimated {estimated_tasks} tasks — activating parallel generation across {LEN(phases)} phases"

  # --- Phase 0 (assets) — conditional ---
  IF asset_manifest exists AND asset_manifest.status == "validated":
    agent_0 = Task(subagent_type="general-purpose", prompt="""
      Generate Phase 0: Asset Preparation tasks.
      READ: {FEATURE_DIR}/asset-manifest.md
      WRITE to: {FEATURE_DIR}/.phase-summaries/phase-9-tasks-phase0.md
      Format: Standard task checklist. Task IDs: T001-T0XX.
      No TDD structure (assets are not code) but include validation criteria.
      All tasks marked [P] (parallelizable).
    """)

  # --- Per-implementation-phase agents (parallel) ---
  agents = []
  FOR each impl_phase IN phases:
    agent = Task(subagent_type="product-planning:tech-lead", prompt="""
      **Goal**: Generate tasks for Implementation Phase {impl_phase.letter}: {impl_phase.name}

      ## Scoped Context (read ONLY these sections)
      - {FEATURE_DIR}/spec.md — focus on user stories: {impl_phase.stories}
      - {FEATURE_DIR}/design.md — focus on components: {impl_phase.components}
      - {FEATURE_DIR}/plan.md — focus on Phase {impl_phase.letter} section
      - {FEATURE_DIR}/.phase-summaries/phase-9-test-map.md — test ID references
      - {FEATURE_DIR}/constitution.md — project conventions

      ## Constraints
      - TDD structure: TEST (RED) → IMPLEMENT (GREEN) → VERIFY
      - Map tasks to test IDs using `(spec: {file} § {section})` format
      - Task IDs: T{impl_phase.id_prefix}01, T{impl_phase.id_prefix}02, ...
      - Reference dependencies on earlier phases by task ID range
      - Each task completable in 1-2 days

      ## Output
      WRITE to: {FEATURE_DIR}/.phase-summaries/phase-9-tasks-{impl_phase.letter}.md
      Format: Standard task checklist with TDD structure per task
    """)
    agents.APPEND(agent)

  # Wait for all parallel agents to complete
  WAIT_ALL(agents + [agent_0] if asset_manifest)

  # --- Merge step (sequential — validates cross-phase dependencies) ---
  Task(subagent_type="general-purpose", prompt="""
    **Goal**: Merge per-phase task files into final tasks.md

    ## Input Files
    READ all {FEATURE_DIR}/.phase-summaries/phase-9-tasks-*.md files

    ## Instructions
    1. Combine all tasks into {FEATURE_DIR}/tasks.md
    2. Renumber task IDs sequentially: T001, T002, ... (preserve phase ordering)
    3. Update ALL cross-phase dependency references to use the new sequential IDs
       (e.g., if Phase B task "TB03" depended on Phase A task "TA02", and TA02 is now T005,
       update TB03's dependency to reference T005)
    4. Validate cross-phase dependencies — no circular references
    5. Deduplicate infrastructure/setup tasks that appear in multiple phases
    6. Verify all test IDs from phase-9-test-map.md are referenced by at least one task
    7. Add header with generation metadata (date, mode, task count, parallel phases)

    ## Output
    WRITE merged result to: {FEATURE_DIR}/tasks.md
    Using template: $CLAUDE_PLUGIN_ROOT/templates/tasks-template.md
  """)

  # Cleanup temporary per-phase files
  DELETE {FEATURE_DIR}/.phase-summaries/phase-9-tasks-*.md

  → SKIP Step 9.5 (already generated tasks via parallel path)
```

## Step 9.6: Task Clarification Loop [USER]

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

## Step 9.7: Task Validation

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

4b. VERIFY test spec references:
    FOR each task IN tasks.md referencing test IDs (UT-*, INT-*, E2E-*, UAT-*):
      ASSERT task contains structured spec reference (pattern: "\(spec: .+§.+\)" or "\(screen: .+\)")
      IF NOT → FLAG as missing spec reference
    spec_ref_compliant = COUNT(tasks with valid spec references)
    spec_ref_total = COUNT(tasks referencing test IDs)

5. GENERATE validation summary:
   ```yaml
   task_validation:
     self_critique_passed: {passed}/5
     tdd_integration: {compliant_count}/{total_tasks}
     test_mapping: {mapped_tests}/{total_tests}
     format_compliance: {valid_format}/{total_tasks}
     spec_references: {spec_ref_compliant}/{spec_ref_total}
     high_risk_addressed: {addressed}/{flagged}
   ```

6. IF validation fails critical checks (passed < 4 OR tdd_integration < 80%):
   LOG: "Task validation failed - requesting revision"
   → Return to Step 9.5 with validation feedback (max 1 retry)
```

## Step 9.8: CLI Task Audit [IF cli_context_isolation]

**Purpose:** Audit task breakdown for completeness (Gemini), code-level accuracy (Codex), and user story coverage (OpenCode) via CLI multi-CLI dispatch.

Follow the **CLI Multi-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `taskauditor` |
| PHASE_STEP | `9.8` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Audit task completeness for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Tasks: {FEATURE_DIR}/tasks.md. Focus: Requirements mapping, missing infrastructure tasks, scope coverage.` |
| CODEX_PROMPT | `Verify task breakdown against codebase for feature: {FEATURE_NAME}. Tasks: {FEATURE_DIR}/tasks.md. Design: {FEATURE_DIR}/design.md. Focus: File path verification, dependency ordering, code structure alignment.` |
| OPENCODE_PROMPT | `Audit user story coverage and UX task completeness for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Tasks: {FEATURE_DIR}/tasks.md. Focus: User story to task mapping, missing UX tasks (empty states, loading, errors), definition of done UX criteria, accessibility task coverage.` |
| FILE_PATHS | `["{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/tasks.md", "{FEATURE_DIR}/design.md"]` |
| REPORT_FILE | `analysis/cli-taskaudit-report.md` |
| PREFERRED_SINGLE_CLI | `codex` |
| POST_WRITE | See blocking findings handling below |

**Blocking findings handling** (after pattern Step D):

```
IF audit has blocking findings (missing tasks, invalid paths):
  SET status: needs-user-input
  SET block_reason: """
    CLI TASK AUDIT FINDINGS:
    {blocking_findings_summary}

    Options:
    1. Fix issues and regenerate tasks (return to Step 9.5)
    2. Acknowledge findings and proceed as-is
    3. Add missing tasks manually
  """
```

## Step 9.9: Generate Final Artifacts

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

4. GENERATE traceability matrix — delegate to Step 9.9b below.
```

## Step 9.9b: Generate Traceability Matrix (Delegated)

**Purpose:** Generate the task-to-test traceability matrix as a separate subagent. This is mechanical mapping (task ID → test IDs → test level) that doesn't require opus-level reasoning, freeing the coordinator to continue with the summary report.

```
Task(subagent_type="general-purpose", prompt="""
  **Goal**: Generate a traceability matrix from tasks.md and test spec map.

  ## Input
  - {FEATURE_DIR}/tasks.md — task list with test references
  - {FEATURE_DIR}/.phase-summaries/phase-9-test-map.md — pre-computed test IDs

  ## Instructions
  1. For each task in tasks.md, extract:
     - Task ID (T###)
     - User Story reference (US#)
     - Test IDs referenced in the task (UT-*, INT-*, E2E-*, UAT-*)
     - Test level for each referenced test ID
  2. Generate a Markdown table with columns:
     | Task ID | User Story | Tests Referenced | Test Level |
  3. Add a coverage summary at the bottom:
     - Total tasks with test references: X/Y (Z%)
     - Unmapped test IDs (tests not referenced by any task): [list]
     - Unmapped tasks (tasks with no test references): [list]

  ## Output
  WRITE to: {FEATURE_DIR}/analysis/task-test-traceability.md
""")
```

## Step 9.10: Output Artifacts Summary

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

## Step 9.11: Generate Summary Report

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

Asset Preparation:
├── Assets Identified: {asset_count or "N/A"}
├── Categories: {asset_categories or "N/A"}
├── Phase 0 Tasks: {phase_0_task_count or "Skipped"}

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

## Step 9.12: Cleanup

```
DELETE {FEATURE_DIR}/.planning.lock
UPDATE state.phase = COMPLETION
UPDATE state.tasks_generated = true
UPDATE state.task_count = {task_count}
SAVE state to {FEATURE_DIR}/.planning-state.local.md
```

## Step 9.13: Post-Planning Menu [IF a5_post_planning_menu] [USER]

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

> **Important:** The following option handlers are executed by the **ORCHESTRATOR** (SKILL.md context), NOT by the Phase 9 coordinator. The coordinator's job ends after writing `tasks.md` and the phase summary.

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
