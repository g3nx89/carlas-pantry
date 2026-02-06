---
phase: "7"
phase_name: "Test Strategy (V-Model)"
checkpoint: "TEST_STRATEGY"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-4-summary.md"
  - ".phase-summaries/phase-5-summary.md"
  - ".phase-summaries/phase-6-summary.md"
artifacts_read:
  - "spec.md"
  - "design.md"
  - "plan.md"
  - "analysis/thinkdeep-insights.md"
artifacts_written:
  - "test-plan.md"
  - "test-cases/unit/"
  - "test-cases/integration/"
  - "test-cases/e2e/"
  - "test-cases/uat/"
agents:
  - "product-planning:qa-strategist"
  - "product-planning:qa-security"
  - "product-planning:qa-performance"
  - "product-planning:phase-gate-judge"
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
  - "mcp__context7__query-docs"
  - "mcp__Ref__ref_search_documentation"
  - "mcp__tavily__tavily_search"
feature_flags:
  - "st_revision_reconciliation"
  - "st_redteam_analysis"
  - "st_tao_loops"
  - "s3_judge_gates"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/v-model-methodology.md"
---

# Phase 7: Test Strategy (V-Model)

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-7-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Step 7.1: Load Test Planning Context

```
READ:
  - {FEATURE_DIR}/spec.md (acceptance criteria, user stories)
  - {FEATURE_DIR}/design.md (architecture for test boundaries)
  - {FEATURE_DIR}/plan.md (implementation approach)
```

## Step 7.1b: Testing Best Practices Research (Research MCP)

**Purpose:** Fetch framework-specific testing patterns BEFORE launching QA agents.

```
IF analysis_mode in {advanced, complete}:

  1. IDENTIFY testing stack from design.md and codebase:
     test_framework = DETECT (Jest, Vitest, Playwright, Cypress, etc.)
     app_framework = EXTRACT from design.md (Next.js, Express, etc.)

  2. QUERY testing patterns:
     IF test_framework IN config.research_mcp.context7.common_library_ids:
       test_patterns = mcp__context7__query-docs(
         libraryId: config.research_mcp.context7.common_library_ids[test_framework],
         query: "{test_framework} {app_framework} testing patterns mocking async"
       )

  3. IF feature involves specific domains requiring specialized testing:

     # E2E testing patterns
     IF e2e_tests_needed:
       e2e_patterns = mcp__context7__query-docs(
         libraryId: "/microsoft/playwright",  # or cypress
         query: "Playwright {app_framework} authentication testing page objects"
       )

     # Security testing patterns
     IF security_sensitive_feature:
       security_tests = mcp__Ref__ref_search_documentation(
         query: "OWASP testing checklist web application security testing"
       )

  4. CHECK for recent testing tool updates:
     IF test_framework version is recent:
       updates = mcp__tavily__tavily_search(
         query: "{test_framework} breaking changes migration 2026",
         search_depth: "basic",
         time_range: "month"
       )

  5. INCLUDE patterns in QA agent prompts:
     testing_context = {
       test_patterns: test_patterns,
       e2e_patterns: e2e_patterns,
       security_tests: security_tests,
       source: "official documentation"
     }

ELSE:
  # Standard/Rapid mode - skip external research
  testing_context = null
```

## Step 7.2: Risk Analysis

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

## Step 7.3: Launch QA Agents (MPA Pattern)

Launch QA agents in parallel for multi-perspective test coverage:

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

## Step 7.3.1: Risk Reconciliation with ST Revision

**Purpose:** Ensure Phase 5 ThinkDeep security/performance insights are aligned with Phase 7 test risk analysis using ST Revision.

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

  3. CHECK for contradictions with T-RISK-2 output:
     has_contradictions = compare(thinkdeep_findings, t_risk_2_output)

  4. IF has_contradictions AND feature_flags.st_revision_reconciliation.enabled:

     # Invoke ST Revision to reconcile
     mcp__sequential-thinking__sequentialthinking({
       thought: "REVISION of Risk Prioritization: ThinkDeep identified...",
       thoughtNumber: 2,
       totalThoughts: 3,
       nextThoughtNeeded: true,
       isRevision: true,
       revisesThought: 2,  # References T-RISK-2
       hypothesis: "Phase 5 insights update risk; {N} conflicts resolved",
       confidence: "high"
     })

     # Update test-plan.md with reconciliation section
     WRITE reconciliation report to test-plan.md

  5. ELSE (no contradictions or flag disabled):
     # Manual reconciliation fallback
     FOR each gap (ThinkDeep finding without test coverage):
       - Add new risk to Phase 7 risk list
       - Generate corresponding test case
       - Update coverage matrix

     FOR each conflict (different severity assessment):
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
| {insight} | {sev} | SEC-XX | Covered |

### ThinkDeep Performance Insights → Test Coverage
| Insight | Severity | Test ID | Status |
|---------|----------|---------|--------|
| {insight} | {sev} | PERF-XX | Covered |

### Gaps Addressed
- {gap description} → Added {test_id}

### Conflicts Flagged
- {conflict description} → Using {resolution}

### ST Revision Applied
- isRevision: {true/false}
- revisesThought: {thought_number or N/A}
- Conflicts resolved: {count}
```

## Step 7.3.2: Red Team Branch (Complete/Advanced)

**Purpose:** Add adversarial perspective to risk analysis by thinking like an attacker.

```
IF analysis_mode in {Complete, Advanced} AND feature_flags.st_redteam_analysis.enabled:

  1. INVOKE Red Team branch:
     mcp__sequential-thinking__sequentialthinking({
       thought: "BRANCH: Red Team. ATTACKER PERSPECTIVE: Entry points...",
       thoughtNumber: 2,
       totalThoughts: 4,
       nextThoughtNeeded: true,
       branchFromThought: 1,  # Branches from T-RISK-1
       branchId: "redteam",
       hypothesis: "Adversarial analysis reveals {N} additional vectors",
       confidence: "medium"
     })

  2. SYNTHESIZE red team findings:
     mcp__sequential-thinking__sequentialthinking({
       thought: "SYNTHESIS: Merging red team findings. NEW ATTACKS...",
       thoughtNumber: 3,
       totalThoughts: 4,
       nextThoughtNeeded: true,
       hypothesis: "Red team adds {N} new test cases",
       confidence: "high"
     })

  3. ADD red team findings to test plan:
     - New attack vectors → Security test cases
     - Overlooked entry points → Additional E2E scenarios
     - Update coverage matrix with SEC-RT-XX IDs

ELSE:
  SKIP red team (not enabled or Standard/Rapid mode)
```

**Red Team Focus Areas:**
- Input validation bypasses
- Authentication/authorization weaknesses
- Data exfiltration paths
- Service disruption vectors
- Injection vulnerabilities (SQL, XSS, command)

## Step 7.3.3: TAO Loop for QA Synthesis

```
IF feature_flags.st_tao_loops.enabled:

  AFTER all QA agents (qa-strategist, qa-security, qa-performance) complete:
    mcp__sequential-thinking__sequentialthinking(T-AGENT-ANALYSIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-SYNTHESIS)
    mcp__sequential-thinking__sequentialthinking(T-AGENT-VALIDATION)

  MERGE findings:
    - Convergent → Incorporate directly into test-plan.md
    - Divergent → Present to user for decision OR use higher severity
    - Gaps → Document as known testing gaps
```

## Step 7.3.4: Synthesize QA Agent Outputs

After all QA agents complete AND reconciliation is done:

1. **Merge test cases** - Combine into unified test-plan.md
2. **Deduplicate** - Remove duplicate test coverage
3. **Prioritize** - Use convergent findings (all agents agree) as highest priority
4. **Flag conflicts** - Note where agents disagree for human decision
5. **Verify reconciliation** - All ThinkDeep insights have test coverage

## Step 7.4: Generate UAT Scripts

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

## Step 7.5: Structure Test Directories

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

## Step 7.6: Generate Test Plan Document

Write `{FEATURE_DIR}/test-plan.md` using template from `$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md`

## Step 7.7: Quality Gate - Test Coverage (S3)

**Purpose:** Verify test coverage quality before coverage validation.

```
IF feature_flags.s3_judge_gates.enabled AND analysis_mode in {advanced, complete}:

  1. LAUNCH judge agent:
     Task(
       subagent_type: "product-planning:phase-gate-judge",
       prompt: """
         Evaluate Test Coverage for feature: {FEATURE_NAME}

         Artifacts to evaluate:
         - {FEATURE_DIR}/test-plan.md
         - {FEATURE_DIR}/spec.md (for AC coverage check)
         - {FEATURE_DIR}/analysis/test-strategy-*.md

         Use Gate 3 criteria from judge-gate-rubrics.md.
         Mode: {analysis_mode}
       """
     )

  2. PARSE verdict (same retry logic as Gates 1 and 2)

  3. UPDATE state.gate_results
```

**Checkpoint: TEST_STRATEGY**
