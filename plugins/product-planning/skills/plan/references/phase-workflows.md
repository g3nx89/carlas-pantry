# Phase Workflows Reference

Detailed step-by-step instructions for each planning phase.

## Phase 1: Setup & Initialization

### Step 1.1: Prerequisites Check

```
VERIFY:
  - Feature spec exists at {FEATURE_DIR}/spec.md
  - Constitution exists at specs/constitution.md

IF missing → ERROR with resolution guidance
```

### Step 1.2: Branch & Path Detection

```
GET current git branch

IF branch matches `feature/<NNN>-<kebab-case>`:
  FEATURE_NAME = part after "feature/"
  FEATURE_DIR = "specs/{FEATURE_NAME}"
ELSE:
  ASK user for feature directory
```

### Step 1.3: State Detection

```
IF {FEATURE_DIR}/.planning-state.local.md exists:
  DISPLAY state summary (phase, decisions count)
  ASK: Resume or Start Fresh?
ELSE:
  INITIALIZE new state from template
```

### Step 1.4: Lock Acquisition

```
LOCK_FILE = "{FEATURE_DIR}/.planning.lock"

IF LOCK_FILE exists AND age < 60 minutes:
  → ERROR: "Planning session in progress"

CREATE LOCK_FILE with pid, timestamp, user
```

### Step 1.5: MCP Availability Check

```
CHECK tools:
  - mcp__sequential-thinking__sequentialthinking
  - mcp__pal__thinkdeep
  - mcp__pal__consensus

DISPLAY availability status
```

### Step 1.6: Analysis Mode Selection

Present modes based on MCP availability. Only show modes where required tools are available.

### Step 1.7: Workspace Preparation

```
CREATE {FEATURE_DIR}/analysis/ if not exists
COPY plan-template.md to {FEATURE_DIR}/plan.md if not exists
```

**Checkpoint: SETUP**

---

## Phase 2: Research & Codebase Exploration

### Step 2.1: Load Context

```
READ:
  - {FEATURE_DIR}/spec.md
  - specs/constitution.md
```

### Step 2.2: Launch Research Agents

For each unknown in Technical Context:

```
Task(
  subagent_type: "product-planning:researcher",
  prompt: "Research {unknown} for {feature_context}"
)
```

### Step 2.3: Launch Code Explorer Agents (MPA)

Launch 2-3 agents in parallel:

```
Task(subagent_type: "product-planning:code-explorer", prompt: "Find similar features...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Map architecture...")
Task(subagent_type: "product-planning:code-explorer", prompt: "Identify integrations...")
```

### Step 2.4: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T4: Pattern Recognition)
mcp__sequential-thinking__sequentialthinking(T5: Integration Points)
mcp__sequential-thinking__sequentialthinking(T6: Technical Constraints)
```

### Step 2.5: Consolidate Research

Write `{FEATURE_DIR}/research.md` with:
- Technologies and decisions
- Patterns identified
- Key files to reference
- Constitution compliance notes

**Checkpoint: RESEARCH**

---

## Phase 3: Clarifying Questions

### Step 3.1: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T1: Feature Understanding)
mcp__sequential-thinking__sequentialthinking(T2: Scope Boundaries)
mcp__sequential-thinking__sequentialthinking(T3: Decomposition Strategy)
```

### Step 3.2: Generate Questions

Identify gaps across categories:
- Scope boundaries
- Edge cases
- Error handling
- Integration details
- Design preferences

### Step 3.3: Collect User Responses

**BLOCKING:** Wait for user to answer ALL questions.

For "whatever you think is best" responses, use BA recommendation and mark as ASSUMED.

### Step 3.4: Update State

Save all decisions to `user_decisions` (IMMUTABLE).

**Checkpoint: CLARIFICATION**

---

## Phase 4: Architecture Design

### Step 4.1: Launch Architecture Agents (MPA)

Launch 3 agents in parallel:

```
Task(subagent_type: "product-planning:software-architect", prompt: "MINIMAL CHANGE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "CLEAN ARCHITECTURE focus...")
Task(subagent_type: "product-planning:software-architect", prompt: "PRAGMATIC BALANCE focus...")
```

Output to:
- `{FEATURE_DIR}/design.minimal.md`
- `{FEATURE_DIR}/design.clean.md`
- `{FEATURE_DIR}/design.pragmatic.md`

### Step 4.2: Sequential Thinking (Complete Mode)

IF mode == Complete AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T7: Option Generation)
mcp__sequential-thinking__sequentialthinking(T8: Trade-off Analysis)
mcp__sequential-thinking__sequentialthinking(T9: Component Design)
mcp__sequential-thinking__sequentialthinking(T10: Acceptance Criteria Mapping)
```

### Step 4.3: Present Options

Display comparison table with:
- Complexity scores
- Maintainability scores
- Performance scores
- Time-to-implement estimates

Include **Recommendation** with reasoning.

### Step 4.4: Record Decision

Save `architecture_choice` to state (IMMUTABLE).

**Checkpoint: ARCHITECTURE**

IF mode in {Complete, Advanced}: → Phase 5
ELSE: → Phase 6

---

## Phase 5: PAL ThinkDeep Analysis

### Step 5.1: Check Prerequisites

```
IF analysis_mode in {standard, rapid}: → Skip to Phase 6
IF PAL unavailable: → Skip (graceful degradation)
```

### Step 5.2: Prepare Context

```
READ selected architecture: {FEATURE_DIR}/design.{selected}.md

PREPARE problem_context with:
  - Feature summary
  - Selected architecture approach
  - Codebase patterns
```

### Step 5.3: Execute ThinkDeep Matrix

| Mode | Perspectives | Models | Total Calls |
|------|--------------|--------|-------------|
| Complete | 3 (perf, maint, sec) | 3 | 9 |
| Advanced | 2 (perf, sec) | 3 | 6 |

For each perspective × model:

```
mcp__pal__thinkdeep(
  step: "{perspective_prompt}",
  model: "{model}",
  thinking_mode: "high",
  focus_areas: "{perspective.focus}",
  problem_context: "{architecture_context}",
  relevant_files: ["{design_file}"]
)
```

### Step 5.4: Synthesize Insights

Write `{FEATURE_DIR}/analysis/thinkdeep-insights.md`:
- Per-model findings
- **Convergent insights** (all agree) → CRITICAL priority
- **Divergent insights** (disagree) → FLAG for decision
- Recommended architecture updates

### Step 5.5: Present Findings

ASK user to:
A) Accept recommendations and update architecture
B) Review divergent points one by one
C) Proceed without changes

**Checkpoint: THINKDEEP**

---

## Phase 6: Plan Validation

### Step 6.1: PAL Consensus (Complete Mode)

IF mode == Complete AND Consensus available:

```
mcp__pal__consensus(model: "gemini-3-pro-preview", stance: "neutral")
mcp__pal__consensus(model: "gpt-5.2", stance: "for")
mcp__pal__consensus(model: "openrouter/x-ai/grok-4", stance: "against")
```

### Step 6.2: Score Calculation

| Dimension | Weight | Score |
|-----------|--------|-------|
| Problem Understanding | 20% | 1-4 |
| Architecture Quality | 25% | 1-4 |
| Risk Mitigation | 20% | 1-4 |
| Implementation Clarity | 20% | 1-4 |
| Feasibility | 15% | 1-4 |

### Step 6.3: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| ≥16 | GREEN | Proceed |
| 12-15 | YELLOW | Proceed with documented risks |
| <12 | RED | Revise (→ Phase 4) |

### Step 6.4: Internal Validation (Fallback)

IF Consensus not available:

```
mcp__sequential-thinking__sequentialthinking(T14: Completeness Check)
mcp__sequential-thinking__sequentialthinking(T15: Consistency Validation)
mcp__sequential-thinking__sequentialthinking(T16: Feasibility Assessment)
```

**Checkpoint: VALIDATION**

---

## Phase 7: Test Strategy (V-Model)

### Step 7.1: Load Test Planning Context

```
READ:
  - {FEATURE_DIR}/spec.md (acceptance criteria, user stories)
  - {FEATURE_DIR}/design.md (architecture for test boundaries)
  - {FEATURE_DIR}/plan.md (implementation approach)
```

### Step 7.2: Risk Analysis

Execute Sequential Thinking for failure point analysis:

```
mcp__sequential-thinking__sequentialthinking(T-RISK-1: Failure Mode Identification)
- Data failures: missing, malformed, stale, too large
- Integration failures: dependencies unavailable, timeouts
- State failures: race conditions, stale reads, lost updates
- User failures: invalid input, misuse, unexpected navigation

mcp__sequential-thinking__sequentialthinking(T-RISK-2: Risk Prioritization)
- Critical: Data loss, security breach, system crash
- High: Feature broken, user blocked
- Medium: Degraded experience, workaround available
- Low: Cosmetic issues, minor inconvenience

mcp__sequential-thinking__sequentialthinking(T-RISK-3: Risk to Test Mapping)
- Each Critical/High risk MUST have dedicated test coverage
```

### Step 7.3: Launch QA Agents (MPA Pattern)

Launch 3 QA agents in parallel for multi-perspective test coverage:

**Complete/Advanced modes:** All 3 agents
**Standard mode:** qa-strategist only
**Rapid mode:** qa-strategist only (minimal output)

```
# Agent 1: General Test Strategy (all modes)
Task(
  subagent_type: "product-planning:qa-strategist",
  prompt: """
    Generate V-Model test strategy for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - Plan: {FEATURE_DIR}/plan.md

    Required Output:
    1. Risk Assessment with test mapping
    2. Unit Test Specifications (TDD-ready)
    3. Integration Test Specifications
    4. E2E Test Scenarios
    5. UAT Scripts (Given-When-Then)
    6. Coverage Matrix
  """,
  description: "Generate V-Model test plan"
)

# Agent 2: Security Test Focus (Complete/Advanced modes)
Task(
  subagent_type: "product-planning:qa-security",
  prompt: """
    Generate security-focused test specifications for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - ThinkDeep Security Insights: {FEATURE_DIR}/analysis/thinkdeep-insights.md (if exists)

    Required Output:
    1. STRIDE Threat Assessment
    2. Authentication Test Cases
    3. Authorization Test Cases
    4. Input Validation Test Cases
    5. Security Edge Cases
    6. Reconciliation with Phase 5 ThinkDeep findings
  """,
  description: "Generate security tests"
)

# Agent 3: Performance Test Focus (Complete/Advanced modes)
Task(
  subagent_type: "product-planning:qa-performance",
  prompt: """
    Generate performance-focused test specifications for feature: {FEATURE_NAME}

    Context:
    - Spec: {FEATURE_DIR}/spec.md
    - Design: {FEATURE_DIR}/design.md
    - ThinkDeep Performance Insights: {FEATURE_DIR}/analysis/thinkdeep-insights.md (if exists)

    Required Output:
    1. Performance Requirements (latency, load targets)
    2. Response Time Test Cases
    3. Load Test Scenarios
    4. Stress Test Scenarios
    5. Resource Monitoring Points
    6. Reconciliation with Phase 5 ThinkDeep findings
  """,
  description: "Generate performance tests"
)
```

Output to:
- `{FEATURE_DIR}/analysis/test-strategy-general.md`
- `{FEATURE_DIR}/analysis/test-strategy-security.md`
- `{FEATURE_DIR}/analysis/test-strategy-performance.md`

### Step 7.3.1: Risk Reconciliation with Phase 5

**Purpose:** Ensure Phase 5 ThinkDeep security/performance insights are aligned with Phase 7 test risk analysis.

```
IF {FEATURE_DIR}/analysis/thinkdeep-insights.md exists:

  1. EXTRACT security findings from ThinkDeep:
     - Identified threats (STRIDE categories)
     - Compliance requirements
     - Vulnerability concerns

  2. EXTRACT performance findings from ThinkDeep:
     - Scalability bottlenecks
     - Latency concerns
     - Resource efficiency issues

  3. RECONCILE with Phase 7 risk analysis:

     | ThinkDeep Finding | Phase 7 Risk ID | Test Coverage | Status |
     |-------------------|-----------------|---------------|--------|
     | {finding} | R-XX or NEW | {test_ids} | Covered/Gap |

  4. FOR each gap (ThinkDeep finding without test coverage):
     - Add new risk to Phase 7 risk list
     - Generate corresponding test case
     - Update coverage matrix

  5. FOR each conflict (different severity assessment):
     - Document both assessments
     - Use higher severity as default
     - FLAG for human decision if significantly different

ELSE:
  SKIP reconciliation (Phase 5 not executed in Standard/Rapid modes)
```

**Reconciliation Output:** Add section to test-plan.md:

```markdown
## Phase 5 ↔ Phase 7 Reconciliation

### ThinkDeep Security Insights → Test Coverage
| Insight | Severity | Test ID | Status |
|---------|----------|---------|--------|
| {insight} | {sev} | SEC-XX | ✅ Covered |

### ThinkDeep Performance Insights → Test Coverage
| Insight | Severity | Test ID | Status |
|---------|----------|---------|--------|
| {insight} | {sev} | PERF-XX | ✅ Covered |

### Gaps Addressed
- {gap description} → Added {test_id}

### Conflicts Flagged
- {conflict description} → Using {resolution}
```

### Step 7.3.2: Synthesize QA Agent Outputs

After all QA agents complete AND reconciliation is done:

1. **Merge test cases** - Combine into unified test-plan.md
2. **Deduplicate** - Remove duplicate test coverage
3. **Prioritize** - Use convergent findings (all agents agree) as highest priority
4. **Flag conflicts** - Note where agents disagree for human decision
5. **Verify reconciliation** - All ThinkDeep insights have test coverage

### Step 7.4: Generate UAT Scripts

For each user story in spec.md, generate:

```markdown
## UAT-{id}: {Story Title}

**User Story:** As a {persona}, I want {action} so that {benefit}

**Given:** {preconditions}
**When:** {user actions}
**Then:** {expected outcomes}

**Test Data:** {specific data needed}

**Evidence Checklist:**
- [ ] Screenshot of initial state
- [ ] Screenshot of action
- [ ] Screenshot of result
- [ ] User confirmation
```

### Step 7.5: Structure Test Directories

```
CREATE {FEATURE_DIR}/test-cases/unit/ if not exists
CREATE {FEATURE_DIR}/test-cases/integration/ if not exists
CREATE {FEATURE_DIR}/test-cases/e2e/ if not exists
CREATE {FEATURE_DIR}/test-cases/uat/ if not exists

WRITE unit test specs to test-cases/unit/
WRITE integration test specs to test-cases/integration/
WRITE e2e scenarios to test-cases/e2e/
WRITE uat scripts to test-cases/uat/
```

### Step 7.6: Generate Test Plan Document

Write `{FEATURE_DIR}/test-plan.md` using template from `$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md`

**Checkpoint: TEST_STRATEGY**

---

## Phase 8: Test Coverage Validation

### Step 8.1: Prepare Coverage Matrix

```
COLLECT all acceptance criteria from spec.md
COLLECT all identified risks from Phase 7
COLLECT all user stories from spec.md

MAP each AC to test IDs
MAP each risk to mitigation tests
MAP each story to UAT script
```

### Step 8.2: PAL Consensus Validation (Complete/Advanced)

IF mode in {Complete, Advanced} AND Consensus available:

```
mcp__pal__consensus(
  model: "gemini-3-pro-preview",
  stance: "neutral",
  prompt: "Evaluate test coverage completeness..."
)
mcp__pal__consensus(
  model: "gpt-5.2",
  stance: "for",
  prompt: "Highlight test coverage strengths..."
)
mcp__pal__consensus(
  model: "grok-4",
  stance: "against",
  prompt: "Find coverage gaps and missing edge cases..."
)
```

### Step 8.3: Score Calculation

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| AC Coverage | 25% | All acceptance criteria mapped to tests |
| Risk Coverage | 25% | All Critical/High risks have tests |
| UAT Completeness | 20% | Scripts are clear for non-technical users |
| Test Independence | 15% | Tests can run in isolation |
| Maintainability | 15% | Tests verify behavior, not implementation |

### Step 8.4: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| ≥80% | GREEN | Proceed to completion |
| 65-79% | YELLOW | Proceed with documented gaps |
| <65% | RED | Return to Phase 7 |

### Step 8.5: Internal Validation (Fallback)

IF Consensus not available:

```
Self-Assessment Checklist:
- [ ] Every AC has at least one test
- [ ] Every Critical risk has mitigation test
- [ ] Every High risk has mitigation test
- [ ] UAT scripts use Given-When-Then
- [ ] UAT scripts have evidence checklists
- [ ] Tests don't depend on each other
```

### Step 8.6: Generate Coverage Report

Write `{FEATURE_DIR}/analysis/test-coverage-validation.md`

**Checkpoint: TEST_COVERAGE_VALIDATION**

IF status == RED: → Return to Phase 7

---

## Phase 9: Completion

### Step 9.1: Generate Final Artifacts

Launch agents for final documents:

```
Task(subagent_type: "product-planning:software-architect", prompt: "Create final design.md...")
Task(subagent_type: "product-planning:tech-lead", prompt: "Break down into tasks with TDD structure...")
```

### Step 9.2: Structure Tasks with TDD

For each implementation task, structure as:

```markdown
## Task: {component_name}

### 1. TEST (RED)
- Write failing unit tests: UT-{ids}
- Verify tests fail for right reason

### 2. IMPLEMENT (GREEN)
- Write minimal code to pass tests
- Run tests, verify GREEN

### 3. VERIFY
- Run integration tests: INT-{ids}
- Code review

### Dependencies
- Blocked by: {task_ids}
- Blocks: {task_ids}
- Test refs: UT-{ids}, INT-{ids}
```

### Step 9.3: Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture |
| `plan.md` | Implementation plan |
| `tasks.md` | Task breakdown with TDD structure |
| `test-plan.md` | V-Model test strategy |
| `test-cases/` | Test specifications by level |
| `data-model.md` | Entity definitions (optional) |
| `contract.md` | API contracts (optional) |

### Step 9.4: Generate Summary Report

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
├── Unit Tests: {count} (TDD-ready)
├── Integration Tests: {count}
├── E2E Tests: {count}
├── UAT Scripts: {count}
├── Coverage: {GREEN/YELLOW} ({score}%)

Tasks: {task_count} structured as TEST → IMPLEMENT → VERIFY

Artifacts Generated:
├── design.md
├── plan.md
├── tasks.md
├── test-plan.md
└── test-cases/{unit,integration,e2e,uat}/

Next Steps:
1. Review artifacts
2. Commit: git add . && git commit -m "feat: plan {FEATURE_NAME}"
3. Begin TDD: Start with unit tests (RED phase)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 9.5: Cleanup

```
DELETE lock file
UPDATE state to COMPLETED
DISPLAY summary report
SUGGEST git commit
```

**Checkpoint: COMPLETION**
