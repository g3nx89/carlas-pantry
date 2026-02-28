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
  - "test-strategy.md"  # Optional — from specify's Stage 6 (strategic test analysis)
artifacts_written:
  - "test-plan.md"
  - "test-cases/unit/"
  - "test-cases/integration/"
  - "test-cases/e2e/"
  - "test-cases/uat/"
  - "analysis/cli-testreview-report.md"  # conditional: CLI dispatch enabled
  - ".phase-summaries/phase-7-skill-context.md"  # conditional: dev_skills_integration enabled
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
  - "cli_context_isolation"
  - "cli_custom_roles"
  - "dev_skills_integration"
  - "deep_reasoning_escalation"  # algorithm awareness: flag test difficulty for orchestrator
  - "s7_mpa_deliberation"
  - "s8_convergence_detection"
  - "s10_team_presets"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/research-mcp-patterns.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/v-model-methodology.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md"
---

# Phase 7: Test Strategy (V-Model)

> **Algorithm Awareness:** If `state.deep_reasoning.algorithm_detected == true`, the
> test strategy should include test cases for algorithmic correctness — edge cases,
> boundary conditions, and formal property verification where applicable. If the QA
> agents cannot adequately cover the algorithm test space, set
> `flags.algorithm_difficulty: true` in the phase summary so the orchestrator can
> consider deep reasoning escalation if the test coverage gate fails.

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

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 7.1: Load Test Planning Context

```
READ:
  - {FEATURE_DIR}/spec.md (acceptance criteria, user stories)
  - {FEATURE_DIR}/design.md (architecture for test boundaries)
  - {FEATURE_DIR}/plan.md (implementation approach)
  - {FEATURE_DIR}/test-strategy.md (OPTIONAL — specify's strategic test analysis)

IF test-strategy.md exists:
  EXTRACT: risk_areas, testable_acs, critical_journeys, edge_cases
  STORE as strategy_inputs for Step 7.6b

  # Migration check: old specify versions produced test-plan.md instead (remove after v2.0)
  IF test-plan.md exists AND test-strategy.md does NOT exist:
    CHECK header of test-plan.md — if it starts with "# Test Strategy:"
    THEN treat as strategy input, LOG: "Legacy test-plan.md detected from specify — treating as test-strategy.md. Consider renaming."
    strategy_inputs = EXTRACT from test-plan.md
ELSE:
  LOG: "test-strategy.md not found — proceeding without strategy traceability"
  strategy_inputs = null
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

## Step 7.1c: Dev-Skills Context Loading (Subagent)

**Purpose:** Load QA domain expertise and accessibility patterns before launching QA agents. Runs IN PARALLEL with Step 7.1b Research MCP queries.

**Reference:** `$CLAUDE_PLUGIN_ROOT/skills/plan/references/skill-loader-pattern.md`

```
IF state.dev_skills.available AND analysis_mode != "rapid":

  DISPATCH Task(subagent_type="general-purpose", prompt="""
    You are a skill context loader for Phase 7 (Test Strategy).

    Detected domains: {state.dev_skills.detected_domains}
    Technology markers: {state.dev_skills.technology_markers}

    Load the following skills and extract ONLY the specified sections:

    1. Skill("dev-skills:qa-test-planner") → extract:
       - Regression suite types (smoke, targeted, full, sanity)
       - Priority definitions (P0-P3)
       - Severity definitions
       - Figma design validation checklist (if "figma" in domains)
       LIMIT: 1200 tokens

    2. IF "frontend" in domains OR "mobile" in domains:
       Skill("dev-skills:accessibility-auditor") → extract:
         - WCAG quick audit checklist (critical items only)
         - Semantic HTML vs ARIA summary
       LIMIT: 600 tokens

    WRITE condensed output to: {FEATURE_DIR}/.phase-summaries/phase-7-skill-context.md
    FORMAT: YAML frontmatter + markdown sections per skill
    TOTAL BUDGET: 2000 tokens max
    IF any Skill() call fails → log in skills_failed, continue with remaining
  """)

  # READ result AFTER both 7.1b and 7.1c complete
  READ {FEATURE_DIR}/.phase-summaries/phase-7-skill-context.md
  IF file exists AND not empty:
    INJECT qa-test-planner section into qa-strategist prompt (Step 7.3)
    INJECT accessibility section into qa-security prompt (Step 7.3) if UI feature
```

## Step 7.2: Risk Analysis

Execute Sequential Thinking for failure point analysis:

```
IF analysis_mode in {advanced, complete} AND mcp__sequential-thinking__sequentialthinking available:

mcp__sequential-thinking__sequentialthinking(T-RISK-1: Failure Mode Identification)
- Data failures: missing, malformed, stale, too large
- Integration failures: dependencies unavailable, timeouts
- State failures: race conditions, stale reads, lost updates
- User failures: invalid input, misuse, unexpected navigation
- Infrastructure failures: network, disk, memory, CPU exhaustion
- Operational resilience failures: rate limits, circuit breakers, backpressure, failover, deployment rollback, compliance/privacy (N/A for MVP/internal — see config risk_keywords)

mcp__sequential-thinking__sequentialthinking(T-RISK-2: Risk Prioritization)
- Critical: Data loss, security breach, system crash
- High: Feature broken, user blocked
- Medium: Degraded experience, workaround available
- Low: Cosmetic issues, minor inconvenience

mcp__sequential-thinking__sequentialthinking(T-RISK-3: Risk to Test Mapping)
- Each Critical/High risk MUST have dedicated test coverage
```

## Step 7.3: Launch QA Agents (MPA Pattern)

```
# S5: Team Preset filtering (s10_team_presets)
IF feature_flags.s10_team_presets.enabled AND state.team_preset == "rapid_prototype":
  # Only dispatch qa-strategist (skip qa-security, qa-performance)
  QA_AGENT_LIST = ["product-planning:qa-strategist"]
  LOG: "Team preset rapid_prototype: dispatching qa-strategist only"
ELSE:
  QA_AGENT_LIST = default agents per mode
```

Launch QA agents in parallel for multi-perspective test coverage:

**Complete/Advanced modes:** All 3 agents (unless rapid_prototype preset)
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
    {IF strategy_inputs != null: - Test Strategy (from specify): {FEATURE_DIR}/test-strategy.md — USE as baseline for risks, ACs, journeys, edge cases. Ensure 100% coverage of strategy items.}

    Required Output:
    1. Risk Assessment with test mapping
    2. Unit Test Specifications (TDD-ready)
    3. Integration Test Specifications
    4. E2E Test Scenarios
    5. UAT Scripts (Given-When-Then)
    6. Coverage Matrix
  """,
  description: "Generate V-Model test plan with strategy traceability"
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

Output to (MPA intermediate outputs — distinct from specify's root-level `test-strategy.md`):
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
       thought: "REVISION of Risk Prioritization: ThinkDeep identified NEW/DIFFERENT insights. THINKDEEP: {findings}. ORIGINAL: {T-RISK-2_output}. CONFLICTS: [list]. RESOLUTION: Using higher severity. NEW RISKS: {additions}. HYPOTHESIS: Phase 5 insights update risk; {N} conflicts resolved. CONFIDENCE: high.",
       thoughtNumber: 2,
       totalThoughts: 3,
       nextThoughtNeeded: true,
       isRevision: true,
       revisesThought: 2
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
IF analysis_mode in {complete, advanced} AND feature_flags.st_redteam_analysis.enabled:

  1. INVOKE Red Team branch:
     mcp__sequential-thinking__sequentialthinking({
       thought: "BRANCH: Red Team. ATTACKER PERSPECTIVE: Entry points: {inputs}. Attack vectors: {injections, auth bypass, data exfiltration}. Impact: {breach, disruption, data loss}. OVERLOOKED: {what standard analysis missed}. HYPOTHESIS: Adversarial analysis reveals {N} additional vectors. CONFIDENCE: medium.",
       thoughtNumber: 2,
       totalThoughts: 4,
       nextThoughtNeeded: true,
       branchFromThought: 1,
       branchId: "redteam"
     })

  2. SYNTHESIZE red team findings:
     mcp__sequential-thinking__sequentialthinking({
       thought: "SYNTHESIS: Merging red team findings back to main trunk. NEW ATTACKS: [list]. ADDITIONS TO TEST PLAN: {new security cases}. COVERAGE GAPS CLOSED: [what red team revealed]. HYPOTHESIS: Red team adds {N} new test cases. CONFIDENCE: high.",
       thoughtNumber: 3,
       totalThoughts: 4,
       nextThoughtNeeded: true
     })

  3. FINALIZE red team analysis:
     mcp__sequential-thinking__sequentialthinking({
       thought: "RED TEAM COMPLETE. TOTAL NEW VECTORS: {N}. TEST CASES ADDED: SEC-RT-{IDs}. RESIDUAL RISK: {assessment}. All red team findings integrated into main test plan. HYPOTHESIS: Red team analysis is complete with {N} vectors addressed. CONFIDENCE: high.",
       thoughtNumber: 4,
       totalThoughts: 4,
       nextThoughtNeeded: false
     })

  4. ADD red team findings to test plan:
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

## Step 7.3.2b: MPA Deliberation — Structured Synthesis for QA (S1)

Follow the **MPA Deliberation** algorithm from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/mpa-synthesis-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| `AGENT_OUTPUTS` | `[general, security, performance]` |
| `AGENT_LIST` | QA agents from Step 7.3 |
| `PHASE_ID` | `"7"` |
| `INSIGHT_FOCUS` | Key test cases, unique risk findings, novel coverage approaches |
| `RESOLUTION_STRATEGY` | Higher severity for risk conflicts, broader coverage for scope conflicts |

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

## Step 7.3.3b: Convergence Detection for QA (S2)

Follow the **Convergence Detection** algorithm from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/mpa-synthesis-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| `AGENT_OUTPUTS` | `[general, security, performance]` |
| `PHASE_ID` | `"7"` |
| `LOW_CONVERGENCE_STRATEGY` | `"include_all_flag_conflicts"` |

## Step 7.3.4: Synthesize QA Agent Outputs

After all QA agents complete AND reconciliation is done:

1. **Merge test cases** - Combine into unified test-plan.md
2. **Deduplicate** - Remove duplicate test coverage
3. **Prioritize** - Use convergent findings (all agents agree) as highest priority
4. **Flag conflicts** - Note where agents disagree for human decision
5. **Verify reconciliation** - All ThinkDeep insights have test coverage

## Step 7.3.5: CLI Test Strategy Review

**Purpose:** Review and validate QA agent outputs using CLI multi-CLI dispatch. Gemini discovers test infrastructure and framework patterns; Codex verifies test code quality and patterns; OpenCode assesses UAT quality and accessibility testing. Also absorbs ThinkDeep reconciliation duties.

Follow the **CLI Multi-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `teststrategist` |
| PHASE_STEP | `7.3.5` |
| MODE_CHECK | `analysis_mode == "complete"` |
| GEMINI_PROMPT | `Review test strategy for feature: {FEATURE_NAME}. Test plan: {FEATURE_DIR}/test-plan.md. ThinkDeep insights: {FEATURE_DIR}/analysis/thinkdeep-insights.md (if exists). Focus: Test infrastructure discovery, framework compatibility, coverage gaps, ThinkDeep-to-test reconciliation.` |
| CODEX_PROMPT | `Review test code quality for feature: {FEATURE_NAME}. Test plan: {FEATURE_DIR}/test-plan.md. Focus: Existing test patterns, assertion quality, mock patterns, test isolation.` |
| OPENCODE_PROMPT | `Review UAT quality and accessibility test coverage for feature: {FEATURE_NAME}. Test plan: {FEATURE_DIR}/test-plan.md. Focus: UAT script clarity (Given-When-Then readability), accessibility testing (keyboard nav, screen reader), exploratory testing charters from user perspective.` |
| FILE_PATHS | `["{FEATURE_DIR}/test-plan.md", "{FEATURE_DIR}/test-strategy.md", "{FEATURE_DIR}/analysis/thinkdeep-insights.md", "{FEATURE_DIR}/analysis/test-strategy-general.md"]` |
| REPORT_FILE | `analysis/cli-testreview-report.md` |
| PREFERRED_SINGLE_CLI | `gemini` |
| POST_WRITE | `Update test-plan.md with coverage gap additions (Gemini), pattern alignment recommendations (Codex), UAT/accessibility improvements (OpenCode), and ThinkDeep reconciliation report` |

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

## Step 7.6b: Strategy Traceability Verification

```
IF strategy_inputs != null:

  1. BUILD traceability matrix:
     FOR EACH risk IN strategy_inputs.risk_areas:
       FIND matching test IDs in test-plan.md → record in risk_trace[]
     FOR EACH ac IN strategy_inputs.testable_acs:
       FIND matching test IDs in test-plan.md → record in ac_trace[]
     FOR EACH journey IN strategy_inputs.critical_journeys:
       FIND matching E2E/UAT IDs in test-plan.md → record in journey_trace[]
     FOR EACH edge_case IN strategy_inputs.edge_cases:
       FIND matching test IDs in test-plan.md → record in edge_trace[]

  2. CALCULATE coverage:
     total_items = len(risk_trace) + len(ac_trace) + len(journey_trace) + len(edge_trace)
     covered_items = count items with at least 1 matching test ID
     coverage_pct = covered_items / total_items * 100

  3. IF coverage_pct < 100:
     FOR EACH uncovered item:
       GENERATE additional test case(s) to close the gap
       APPEND to appropriate section of test-plan.md
     RECALCULATE coverage_pct

  4. APPEND Section 10 (Strategy Traceability) to test-plan.md:
     Use traceability tables from template (Section 10)
     Include: risk_trace, ac_trace, journey_trace, edge_trace, summary

  5. IF coverage_pct < 100 after gap-closing attempt:
     SET flags.strategy_traceability_gap = true in phase summary
     DOCUMENT remaining gaps in Section 10.5

ELSE:
  SKIP — no Section 10 added to test-plan.md (strategy_inputs is null)
```

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
         {IF strategy_inputs != null: - {FEATURE_DIR}/test-strategy.md (verify Section 10 traceability covers all strategy items)}

         Use Gate 3 criteria from judge-gate-rubrics.md.
         {IF strategy_inputs != null: Additional criterion: Section 10 Strategy Traceability must cover 100% of test-strategy.md items.}
         Mode: {analysis_mode}
       """
     )

  2. PARSE verdict (same retry logic as Gates 1 and 2)

  3. UPDATE state.gate_results
```

**Checkpoint: TEST_STRATEGY**
