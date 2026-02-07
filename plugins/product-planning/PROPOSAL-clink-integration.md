# Proposal: Clink Integration for Plan Skill

> **Status:** Implemented
> **Author:** Claude Code Analysis
> **Date:** 2026-02-04 (Draft) / 2026-02-07 (Implemented)
> **Plugin:** product-planning
> **Skill:** /product-planning:plan

## Executive Summary

This proposal documents the PAL `clink` (CLI-to-CLI bridge) integration into the plan skill workflow. The implementation delivers:

1. **Dual-CLI MPA pattern** -- every role runs BOTH Gemini AND Codex in parallel, then synthesizes convergent/divergent/unique findings
2. **5 custom roles x 2 CLIs = 10 prompt files** covering deep analysis, plan review, test strategy, security audit, and task audit
3. **Self-critique via Task subagent** with ST Chain-of-Verification, preventing coordinator context pollution
4. **Coordinator-level context savings** of ~30KB per planning session through isolated clink execution
5. **Template-to-runtime deployment** -- templates ship in the plugin, auto-deploy to projects at Phase 1

The integration supplements (does not replace) existing PAL ThinkDeep, Consensus, Challenge, and listmodels usage. Clink steps are additive at 6 integration points across Phases 1, 5, 6, 6b, 7, and 9.

**Additional cost:** ~$0.15-0.30 per session. **Additional latency:** ~5-10 minutes cumulative across all roles.

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Gap Identification](#2-gap-identification)
3. [Proposed Improvements](#3-proposed-improvements)
4. [Custom Clink Roles](#4-custom-clink-roles)
5. [Phase Workflow Changes](#5-phase-workflow-changes)
6. [Configuration Changes](#6-configuration-changes)
7. [Implementation Plan](#7-implementation-plan)
8. [Cost-Benefit Analysis](#8-cost-benefit-analysis)
9. [Risks and Mitigations](#9-risks-and-mitigations)
10. [Acceptance Criteria](#10-acceptance-criteria)
11. [Appendix A: File Structure](#appendix-a-file-structure)
12. [Appendix B: CLI Client Configuration](#appendix-b-cli-client-configuration)
13. [Appendix C: Glossary](#appendix-c-glossary)

---

## 1. Current State Analysis

### 1.1 PAL Tools Currently Used

| Tool | Phase | Usage | Assessment |
|------|-------|-------|------------|
| `mcp__pal__thinkdeep` | 5 | 9 calls (3 perspectives x 3 models) | Well-implemented |
| `mcp__pal__consensus` | 6, 8 | Plan validation, test coverage validation | Well-implemented |
| `mcp__pal__challenge` | 6 | Groupthink detection (variance < 0.5) | Well-implemented |
| `mcp__pal__listmodels` | 5 | Model availability verification | Well-implemented |

### 1.2 PAL Tools NOT Used (Pre-Implementation)

| Tool | Potential Use | Impact if Added |
|------|---------------|-----------------|
| **`clink`** | Context isolation, parallel CLI investigations | **Critical** -- coordinator context savings |
| Custom roles | Specialized filesystem-exploring analysis | **High** -- quality improvement |
| `apilookup` | Phase 2 research supplement | Medium |
| `codereview`/`precommit` | Phase 9 commit workflow | Low |

### 1.3 Context Budget Analysis (Pre-Implementation)

Coordinator-level context consumption per phase:

| Phase | Operation | Estimated Coordinator Context |
|-------|-----------|-------------------------------|
| 2 | MPA research agents (3x) | ~8KB |
| 5 | ThinkDeep matrix (9 calls) | ~12KB |
| 6 | Consensus validation | ~5KB |
| 6b | Expert review agents (2x) | ~8KB |
| 7 | QA MPA agents (3x) | ~10KB |
| **Total** | | **~43KB** |

Note: These are coordinator-level estimates (not main conversation). Coordinators run via `Task(general-purpose)` and already isolate from the orchestrator. Clink further isolates within coordinators.

---

## 2. Gap Identification

### G1: No Filesystem Exploration in Heavy Analysis

**Problem:** PAL ThinkDeep calls and Task subagents reason primarily from provided context. They do not actively explore the project filesystem for conflicting patterns, dependency chains, or infrastructure configurations.

**Evidence:** Phase 5 ThinkDeep receives curated context but cannot independently `ls`, `cat`, or search the codebase.

**Impact:** Analysis misses codebase-specific evidence that CLI agents (Gemini, Codex) with filesystem access would catch.

### G2: Missing Adversarial Pre-Validation

**Problem:** Phase 6 uses Consensus with stance steering ("for"/"against"/"neutral"), but lacks structured adversarial review with codebase evidence before validation begins.

**Evidence:** Challenge tool only invoked when score variance < 0.5 (reactive, not proactive).

**Impact:** Plans may pass validation without thorough adversarial stress-testing grounded in actual code.

### G3: Single-Perspective Security Review

**Problem:** Phase 6b security review uses a single agent type. No architectural/supply-chain security perspective complements the code-level OWASP analysis.

**Evidence:** `Task(subagent_type: "product-planning:security-analyst")` provides one viewpoint only.

**Impact:** Supply chain risks, configuration security, and compliance gaps may go undetected.

---

## 3. Proposed Improvements

### 3.1 Dual-CLI MPA Pattern

The core innovation: every clink role runs **both Gemini and Codex in parallel**, then the coordinator synthesizes findings:

```
Coordinator (Phase N)
  Step N.X: Clink Dual-CLI Dispatch (PARALLEL)
  +-----------+      +-----------+
  | clink     |      | clink     |
  | gemini    |      | codex     |
  | role=X    |      | role=X    |
  +-----+-----+      +-----+-----+
        +--------+----------+
                 v
  Step N.X+1: Synthesis (inline)
  - Convergent (both agree) -> HIGH confidence
  - Divergent (disagree) -> FLAG for user decision
  - Unique (one only) -> VERIFY

  Step N.X+2: Self-Critique via Task subagent
  Task(general-purpose):
    ST CoVe: 3-5 verification Qs -> revise -> output
  -> Returns validated findings only

  Step N.X+3: Write to analysis/clink-{role}-report.md
```

**Why dual-CLI?**
- **Gemini** has 1M token context: excels at broad codebase exploration, pattern discovery, tech stack analysis
- **Codex** specializes in code: excels at import chain tracing, dependency verification, file-level analysis
- **Convergent findings** (both agree) are high-confidence -- no further verification needed
- **Divergent findings** surface blind spots that single-CLI analysis would miss

### 3.2 Self-Critique via Task Subagent

Self-critique runs in a **separate Task subagent** (not inline in the coordinator) to prevent context pollution:

```
Task(subagent_type: "general-purpose", prompt: """
  Apply Chain-of-Verification to these findings:
  {clink_synthesis}

  1. Generate 3-5 verification questions
  2. Answer each question against the evidence
  3. Revise findings where verification fails
  4. Return only validated findings
""")
```

This adds ~5-10s latency but keeps coordinator context clean.

### 3.3 Deepthinker Supplements (Does Not Replace) ThinkDeep

The deepthinker role **supplements** the PAL ThinkDeep matrix. It does not replace it because:
- Gemini CLI lacks PAL MCP access (cannot call `mcp__pal__thinkdeep` itself)
- ThinkDeep provides multi-model strategic insights (gpt-5.2, gemini-3-pro-preview, grok-4)
- Deepthinker adds filesystem exploration breadth that model-to-model calls cannot achieve

### 3.4 EXPLORE Directives

All 10 prompt files include **EXPLORE directives** -- mandatory filesystem exploration instructions that leverage clink's unique power: the ability to read files, walk directories, trace imports, and verify claims against the actual codebase. This is clink's primary differentiator versus inline Task agents.

### 3.5 Role Set (Final)

| Role | Gemini Focus | Codex Focus | Phase | Modes |
|------|-------------|-------------|-------|-------|
| deepthinker | Broad architecture exploration, tech stack | Code-level coupling, dependency chains | 5 | Complete, Advanced |
| planreviewer | Strategic risks, scope assessment | Technical risks, code conflicts | 6 | Complete, Advanced |
| teststrategist | Test infra discovery, framework patterns | Test code patterns, assertion quality | 7 | Complete |
| securityauditor | Supply chain, architectural security | OWASP code-level vulnerabilities | 6b | Complete, Advanced |
| taskauditor | Completeness, missing infrastructure | File path verification, code structure | 9 | Complete, Advanced |

**Design decisions:**
- **Researcher removed** -- duplicates Research MCP (Context7, Ref, Tavily) already integrated in Phase 2
- **Reconciliator removed** -- reconciliation duties absorbed into teststrategist (Gemini variant performs ThinkDeep-to-test reconciliation in Phase 3 of its protocol)
- **Taskauditor added** -- Phase 9 task generation lacked code-level verification of file paths and dependency ordering

### 3.6 Feature Flags

```yaml
feature_flags:
  clink_context_isolation:
    enabled: true
    description: "Use clink for context-isolated CLI agent analysis"
    rollback: "Set false to use inline agents only"
    modes: [complete, advanced]
    requires_mcp: true
    cost_impact: "Marginal increase; ~30KB coordinator context savings"

  clink_custom_roles:
    enabled: true
    description: "Use specialized clink roles with filesystem exploration directives"
    rollback: "Set false to skip clink roles"
    modes: [complete, advanced]
    requires: [clink_context_isolation]
    requires_mcp: true
    cost_impact: "~$0.15-0.30 additional; ~5-10 min latency for all roles"
```

---

## 4. Custom Clink Roles

### 4.1 Role: `deepthinker` (Phase 5)

**Purpose:** Supplement PAL ThinkDeep matrix with broad codebase exploration (Gemini) and code-level coupling analysis (Codex).

#### Gemini Variant (`gemini_deepthinker.txt`)

**CLI:** gemini | **Phase:** 5 | **Modes:** Complete, Advanced

**Focus Areas:**
- Broad architecture exploration across the entire codebase using 1M token context
- Technology stack analysis and compatibility verification via package.json, tsconfig.json, build configs
- Pattern discovery across large codebases (finding existing patterns that conflict or align with the proposal)
- Cross-cutting concern identification that narrow model calls miss

**ST Integration:** Mandatory -- uses `branchFromThought` for performance, maintainability, and security perspective branches with convergent/divergent synthesis.

**EXPLORE Directives:** Search for conflicting patterns, open config files, walk directory trees, check test patterns, read module implementations, examine CI/CD configs.

**Output:** Architecture Analysis Summary with filesystem exploration results, convergent/divergent findings, recommended updates, confidence assessment.

#### Codex Variant (`codex_deepthinker.txt`)

**CLI:** codex | **Phase:** 5 | **Modes:** Complete, Advanced

**Focus Areas:**
- Import chain tracing and circular dependency detection
- Dependency graph analysis (which modules depend on what)
- Code-level complexity measurement (cyclomatic complexity, nesting depth)
- Proposed abstraction verification against actual usage patterns
- Hot path analysis for performance-critical code sections

**EXPLORE Directives:** Trace import chains from entry points, check for circular dependencies, analyze hot path complexity, verify proposed abstractions, check dependency versions, examine error handling patterns.

**Output:** Code-Level Deep Analysis with import chain analysis, coupling assessment, complexity hotspots, dependency verification.

### 4.2 Role: `planreviewer` (Phase 6)

**Purpose:** Adversarial pre-validation plan review before PAL Consensus or Multi-Judge Debate.

#### Gemini Variant (`gemini_planreviewer.txt`)

**CLI:** gemini | **Phase:** 6 | **Modes:** Complete, Advanced

**Focus Areas:**
- Strategic risk identification (scope creep, dependency risks, team capacity)
- Broad pattern analysis across the codebase for plan feasibility
- Timeline and scope assessment against similar features in the codebase
- Cross-cutting concern identification the plan may have missed

**ST Integration:** Mandatory -- Red Team/Blue Team branching with `branchId: "red-team"`.

**EXPLORE Directives:** Verify file paths in plan exist, check referenced API interfaces, search for similar implementations, examine test infrastructure, walk directory structure.

**Output:** Plan Review Summary with strengths, Red Team findings, missing elements, recommendations, verdict.

#### Codex Variant (`codex_planreviewer.txt`)

**CLI:** codex | **Phase:** 6 | **Modes:** Complete, Advanced

**Focus Areas:**
- Code structure support verification (do referenced files/APIs exist?)
- Dependency compatibility checks (version conflicts, peer deps)
- Import path resolution (can proposed imports actually resolve?)
- Build configuration compatibility

**EXPLORE Directives:** Resolve every import path, check API signatures, verify dependency versions, check build configs, trace data flow paths, verify test infrastructure.

**Output:** Technical Feasibility Review with path resolution, API compatibility, build configuration, technical feasibility findings, verdict.

### 4.3 Role: `teststrategist` (Phase 7)

**Purpose:** Review and validate QA agent outputs. Absorbs ThinkDeep reconciliation duties (formerly handled by the removed reconciliator role).

#### Gemini Variant (`gemini_teststrategist.txt`)

**CLI:** gemini | **Phase:** 7 | **Modes:** Complete

**Focus Areas:**
- Test infrastructure discovery (find all test configs, runners, CI pipelines)
- Framework compatibility verification (does test framework match app framework?)
- Broad coverage gap detection across the entire test surface
- CI/CD pipeline analysis for test execution feasibility
- ThinkDeep finding reconciliation (Phase 5 insights mapped to test coverage)

**EXPLORE Directives:** Search for jest/vitest/playwright configs, read devDependencies, check CI/CD configs, walk test directories, examine fixtures/mocks, check coverage configuration.

**Output:** Test Strategy Review with test infrastructure discovery, CI/CD test execution, coverage gaps, ThinkDeep reconciliation report, coverage delta, recommendations.

#### Codex Variant (`codex_teststrategist.txt`)

**CLI:** codex | **Phase:** 7 | **Modes:** Complete

**Focus Areas:**
- Existing test pattern analysis (how tests are currently written)
- Assertion quality evaluation (meaningful assertions vs trivial checks)
- Mock pattern review (appropriate mocking levels, no over-mocking)
- Fixture and test data setup patterns
- Test isolation verification (no shared mutable state between tests)

**EXPLORE Directives:** Read 3-5 existing test files, check mock patterns, examine fixtures, look for shared test utilities, check for isolation issues, review naming conventions.

**Output:** Test Code Analysis with existing test patterns, assertion quality, mock pattern assessment, test isolation issues, pattern alignment, recommendations.

### 4.4 Role: `securityauditor` (Phase 6b)

**Purpose:** Supplement standard Phase 6b security review with dual-perspective security analysis.

#### Gemini Variant (`gemini_securityauditor.txt`)

**CLI:** gemini | **Phase:** 6b | **Modes:** Complete, Advanced

**Focus Areas:**
- Supply chain security assessment (dependency audit, transitive deps)
- Architectural attack surface analysis (exposed endpoints, trust boundaries)
- Compliance pattern identification (GDPR, SOC2, HIPAA indicators)
- Configuration security (secrets management, environment variables)

**EXPLORE Directives:** Read package.json/lock files, search for secrets/credentials, check auth configs, examine API routes for missing auth, walk infrastructure configs, check CORS/CSP headers.

**Output:** Architectural Security Audit with supply chain assessment, trust boundaries, attack surface, configuration security, compliance indicators, verdict.

#### Codex Variant (`codex_securityauditor.txt`)

**CLI:** codex | **Phase:** 6b | **Modes:** Complete, Advanced

**Focus Areas:**
- Code-level injection point identification (SQL, XSS, command injection)
- Hardcoded secret detection (API keys, passwords, tokens in source)
- Authentication implementation flaw detection
- Input validation gap analysis
- OWASP Top 10 systematic checklist

**EXPLORE Directives:** Search for string concatenation in queries, search for raw HTML rendering, search for hardcoded API keys, examine auth middleware, check input validation, review file upload handling.

**Output:** Code-Level Security Audit with attack surface, findings by severity (CRITICAL/HIGH/MEDIUM/LOW), remediation priority, OWASP coverage table, verdict.

### 4.5 Role: `taskauditor` (Phase 9)

**Purpose:** Audit task breakdown for completeness and code-level accuracy after task generation.

#### Gemini Variant (`gemini_taskauditor.txt`)

**CLI:** gemini | **Phase:** 9 | **Modes:** Complete, Advanced

**Focus Areas:**
- Completeness check against original specification
- Missing user story detection (stories in spec without corresponding tasks)
- Missing infrastructure tasks (CI/CD, deployment, monitoring, documentation)
- Scope coverage assessment and cross-cutting concern coverage

**EXPLORE Directives:** Read spec.md and extract all user stories/ACs, read tasks.md and map each story to tasks, check CI/CD configs for missing infrastructure tasks, search for cross-cutting concerns, verify deployment/migration needs, check for documentation tasks.

**Output:** Task Completeness Audit with requirements mapping, missing tasks, scope coverage assessment, recommendations, verdict.

#### Codex Variant (`codex_taskauditor.txt`)

**CLI:** codex | **Phase:** 9 | **Modes:** Complete, Advanced

**Focus Areas:**
- File path verification (do paths referenced in tasks actually exist or follow conventions?)
- Dependency ordering verification via import chain analysis
- Code structure alignment (do proposed components fit the existing module structure?)
- Build dependency validation and test file path verification

**EXPLORE Directives:** Check every file path in tasks.md, trace import chains for dependency ordering, verify new file locations follow conventions, check test file locations, verify build ordering, check tasks reference correct existing files.

**Output:** Task Breakdown Verification with file path verification, dependency ordering, structure alignment, audit summary table, invalid paths, dependency ordering issues, verdict.

---

## 5. Phase Workflow Changes

All clink integration points follow the **4-sub-step pattern** described in Section 3.1: (1) parallel dual-CLI dispatch, (2) synthesis, (3) self-critique via Task subagent, (4) write validated report.

### 5.1 Phase 1 -- Step 1.5b: Clink Capability Detection

**Integration Point:** After MCP availability check (Step 1.5a), before mode selection (Step 1.6).

**Delegation:** Inline (Phase 1 always runs inline in orchestrator).

```
IF feature_flags.clink_context_isolation.enabled:

  1. CHECK clink MCP tool accessible:
     clink_available = CHECK mcp__pal__clink is callable

  2. IF clink_available:
     # Check which CLIs are installed
     gemini_available = CHECK "gemini" CLI responds
     codex_available = CHECK "codex" CLI responds

     # Determine clink mode
     IF gemini_available AND codex_available:
       clink_mode = "dual"
     ELSE IF gemini_available:
       clink_mode = "single_gemini"
     ELSE IF codex_available:
       clink_mode = "single_codex"
     ELSE:
       clink_mode = "disabled"

  3. IF clink_mode != "disabled" AND feature_flags.clink_custom_roles.enabled:
     # Auto-deploy role templates to project
     SOURCE = "$CLAUDE_PLUGIN_ROOT/templates/clink-roles/"
     TARGET = "PROJECT_ROOT/conf/cli_clients/"

     IF TARGET missing OR version marker mismatch:
       COPY all .txt and .json files from SOURCE to TARGET
       LOG: "Deployed clink role templates (version 1.0.0)"

  4. UPDATE state:
     clink:
       available: {clink_available}
       capabilities:
         gemini: {gemini_available}
         codex: {codex_available}
       roles_deployed: {roles_deployed}
       mode: {clink_mode}

ELSE:
  SET state.clink.available = false
  SET state.clink.mode = "disabled"
```

### 5.2 Phase 5 -- Step 5.6: Deepthinker Supplement

**Integration Point:** After ThinkDeep matrix completes (Step 5.3-5.4), before presenting findings (Step 5.5).

**Preconditions:** `state.clink.available AND state.clink.mode != "disabled" AND feature_flags.clink_custom_roles.enabled AND analysis_mode in {complete, advanced}`

```
# Step 5.6a: Parallel Dual-CLI Dispatch
IF state.clink.mode == "dual":
  gemini_result = clink(
    cli_name: "gemini",
    role: "deepthinker",
    prompt: "Supplement ThinkDeep for {FEATURE_NAME}. Focus: Broad architecture exploration.",
    absolute_file_paths: ["{FEATURE_DIR}/design.md", "{FEATURE_DIR}/analysis/thinkdeep-insights.md"]
  )
  codex_result = clink(
    cli_name: "codex",
    role: "deepthinker",
    prompt: "Supplement ThinkDeep for {FEATURE_NAME}. Focus: Import chain analysis, coupling.",
    absolute_file_paths: ["{FEATURE_DIR}/design.md", "{FEATURE_DIR}/analysis/thinkdeep-insights.md"]
  )
ELSE:
  # Single-CLI fallback
  cli = IF state.clink.capabilities.gemini THEN "gemini" ELSE "codex"
  single_result = clink(cli_name: cli, role: "deepthinker", ...)

# Step 5.6b: Synthesis
SYNTHESIZE: Convergent -> merge into insights; Divergent -> FLAG; Unique -> VERIFY

# Step 5.6c: Self-Critique via Task Subagent (ST CoVe)
Task(general-purpose): CoVe 3-5 verification questions -> revise -> validated findings

# Step 5.6d: Write report
WRITE validated findings to {FEATURE_DIR}/analysis/clink-deepthinker-report.md
APPEND clink supplement section to {FEATURE_DIR}/analysis/thinkdeep-insights.md
```

**Fallback:** If clink unavailable, skip step entirely. ThinkDeep matrix results stand on their own.

### 5.3 Phase 6 -- Step 6.0a: Plan Review Pre-Validation

**Integration Point:** Before PAL Consensus or Multi-Judge Debate (Step 6.0/6.1).

**Preconditions:** `state.clink.available AND state.clink.mode != "disabled" AND feature_flags.clink_custom_roles.enabled AND analysis_mode in {complete, advanced}`

```
# Step 6.0a.1: Parallel Dual-CLI Dispatch
gemini: planreviewer -> Strategic risks, scope assessment, Red Team/Blue Team
codex: planreviewer -> Technical feasibility, code structure, dependency compatibility

# Step 6.0a.2: Synthesis
Convergent -> HIGH confidence; Divergent -> FLAG for Consensus input; Unique -> VERIFY

# Step 6.0a.3: Self-Critique via Task Subagent (ST CoVe)

# Step 6.0a.4: Write report + feed into Consensus context
WRITE to {FEATURE_DIR}/analysis/clink-planreview-report.md
APPEND clink review summary to consensus_context
```

**Key design:** Clink plan review findings are included in the Consensus prompt context, enriching the multi-model validation with codebase-grounded evidence.

### 5.4 Phase 6b -- Step 6b.1b: Security Audit Supplement

**Integration Point:** After standard security agent launch (Step 6b.1a), runs in parallel with standard agents.

**Preconditions:** `state.clink.available AND state.clink.mode != "disabled" AND feature_flags.clink_custom_roles.enabled`

Note: No mode restriction -- security is important in both Complete and Advanced modes.

```
# Step 6b.1b.1: Parallel Dual-CLI Dispatch
gemini: securityauditor -> Supply chain, trust boundaries, compliance
codex: securityauditor -> OWASP code-level vulnerabilities, injection points

# Step 6b.1b.2: Synthesis

# Step 6b.1b.3: Self-Critique via Task Subagent (ST CoVe)

# Step 6b.1b.4: Write report
WRITE to {FEATURE_DIR}/analysis/clink-security-report.md

# Step 6b.2 merges clink findings with standard agent findings (deduplicate)
```

**Key design:** Standard security agents (security-analyst, simplicity-reviewer) still run. Clink **supplements** -- findings are merged and deduplicated in Step 6b.2.

### 5.5 Phase 7 -- Step 7.3.5: Test Strategy Review

**Integration Point:** After QA MPA agent synthesis (Step 7.3), before UAT generation (Step 7.4).

**Preconditions:** `state.clink.available AND state.clink.mode != "disabled" AND feature_flags.clink_custom_roles.enabled AND analysis_mode == "complete"`

Note: Complete mode only -- Advanced mode skips to reduce cost.

```
# Step 7.3.5a: Parallel Dual-CLI Dispatch
gemini: teststrategist -> Test infra discovery, coverage gaps, ThinkDeep reconciliation
codex: teststrategist -> Test code patterns, assertion quality, mock patterns

# Step 7.3.5b: Synthesis

# Step 7.3.5c: Self-Critique via Task Subagent (ST CoVe)

# Step 7.3.5d: Write report
WRITE to {FEATURE_DIR}/analysis/clink-testreview-report.md
UPDATE test-plan.md with coverage gaps, pattern recommendations, reconciliation
```

**Key design:** The teststrategist absorbs ThinkDeep reconciliation duties (formerly a separate reconciliator role). The Gemini variant performs Phase 5-to-Phase 7 reconciliation in its protocol Phase 3.

### 5.6 Phase 9 -- Step 9.5b: Task Audit

**Integration Point:** After task validation (Step 9.5), before task formatting (Step 9.6).

**Preconditions:** `state.clink.available AND state.clink.mode != "disabled" AND feature_flags.clink_custom_roles.enabled AND analysis_mode in {complete, advanced}`

```
# Step 9.5b.1: Parallel Dual-CLI Dispatch
gemini: taskauditor -> Requirements mapping, missing infrastructure, scope coverage
codex: taskauditor -> File path verification, dependency ordering, code structure

# Step 9.5b.2: Synthesis

# Step 9.5b.3: Self-Critique via Task Subagent (ST CoVe)

# Step 9.5b.4: Write report
WRITE to {FEATURE_DIR}/analysis/clink-taskaudit-report.md

IF blocking issues (missing tasks, invalid paths):
  SET status: needs-user-input
  SET block_reason with options:
    1. Fix and regenerate (return to Step 9.3)
    2. Acknowledge and proceed
    3. Add missing tasks manually
```

**Key design:** Task audit can block Phase 9 completion if critical issues are found (missing requirements, invalid file paths). The coordinator mediates user interaction through `status: needs-user-input`.

---

## 6. Configuration Changes

### 6.1 New Feature Flags in `config/planning-config.yaml`

```yaml
feature_flags:
  # Clink Integration
  clink_context_isolation:
    enabled: true
    description: "Use clink for context-isolated CLI agent analysis"
    rollback: "Set false to use inline agents only"
    modes: [complete, advanced]
    requires_mcp: true
    cost_impact: "Marginal increase; ~30KB coordinator context savings"

  clink_custom_roles:
    enabled: true
    description: "Use specialized clink roles with filesystem exploration directives"
    rollback: "Set false to skip clink roles"
    modes: [complete, advanced]
    requires: [clink_context_isolation]
    requires_mcp: true
    cost_impact: "~$0.15-0.30 additional; ~5-10 min latency for all roles"
```

### 6.2 New `clink_integration` Section

```yaml
clink_integration:
  # Auto-setup configuration
  auto_setup:
    source_dir: "$CLAUDE_PLUGIN_ROOT/templates/clink-roles/"
    target_dir: "PROJECT_ROOT/conf/cli_clients/"
    version_marker: "clink_role_version: 1.0.0"

  # Available CLIs and their capabilities
  clis:
    gemini:
      context_size: "1M tokens"
      capabilities: [web_search, sequential_thinking, broad_exploration]
      auto_approval_flag: "--yolo"
      best_for: "Broad codebase analysis, tech stack validation, pattern discovery"

    codex:
      context_size: "128K tokens"
      capabilities: [code_analysis, import_tracing, vulnerability_detection]
      auto_approval_flag: "--dangerously-bypass-approvals-and-sandbox"
      best_for: "Import chains, coupling analysis, code-level security, file path verification"

  # Dual-CLI MPA pattern
  dual_cli:
    enabled: true
    synthesis_strategy: "convergent_divergent_unique"

  # Self-critique configuration
  self_critique:
    method: "st_cove_subagent"
    description: "Chain-of-Verification via Task(general-purpose) subagent"
    verification_questions: 3-5
    rationale: "Runs in separate context to avoid coordinator pollution"

  # Custom roles (5 roles x 2 CLIs = 10 prompt files)
  roles:
    deepthinker:
      gemini_focus: "Broad architecture exploration, tech stack, pattern conflicts"
      codex_focus: "Import chain analysis, coupling assessment, complexity hotspots"
      phases: [5]
      modes: [complete, advanced]

    planreviewer:
      gemini_focus: "Strategic risks, scope assessment, Red Team/Blue Team"
      codex_focus: "Technical feasibility, code structure support, dependency compatibility"
      phases: [6]
      modes: [complete, advanced]

    teststrategist:
      gemini_focus: "Test infra discovery, framework patterns, coverage gaps, ThinkDeep reconciliation"
      codex_focus: "Test code patterns, assertion quality, mock patterns, test isolation"
      phases: [7]
      modes: [complete]

    securityauditor:
      gemini_focus: "Supply chain security, architectural attack surface, compliance"
      codex_focus: "OWASP code-level vulnerabilities, injection points, hardcoded secrets"
      phases: [6b]
      modes: [complete, advanced]

    taskauditor:
      gemini_focus: "Requirements mapping, missing infrastructure, scope coverage"
      codex_focus: "File path verification, dependency ordering, code structure alignment"
      phases: [9]
      modes: [complete, advanced]

  # Retry and circuit breaker
  retry:
    max_retries: 1
    circuit_breaker_threshold: 2  # After 2 consecutive failures, skip clink for session

  # Timeout configuration
  timeout:
    default_seconds: 120
    per_role:
      deepthinker: 180
      planreviewer: 120
      teststrategist: 150
      securityauditor: 150
      taskauditor: 120

  # Latency estimates (per-role, includes both CLIs + synthesis + self-critique)
  latency:
    deepthinker: "60-90s"
    planreviewer: "45-75s"
    teststrategist: "60-90s"
    securityauditor: "60-90s"
    taskauditor: "45-60s"
    total_cumulative: "~5-7 min for all roles"

  # Fallback behavior
  fallback:
    if_clink_unavailable: "skip_clink_steps"
    if_one_cli_missing: "single_cli_mode"
    if_both_missing: "skip_clink_steps"
    log_fallback: true
```

### 6.3 Updated Blessed Profiles

Clink flags added to `complete_default` and `advanced_with_st` blessed profiles:

```yaml
blessed_profiles:
  complete_default:
    flags:
      # ... existing flags ...
      clink_context_isolation: true
      clink_custom_roles: true
    expected_cost: "$1.10-2.00"  # Updated to reflect ST + clink enhancements

  advanced_default:
    flags:
      # ... existing flags ...
      clink_context_isolation: true
      clink_custom_roles: true
    expected_cost: "$0.55-0.90"

  advanced_with_st:
    flags:
      # ... existing flags ...
      clink_context_isolation: true
      clink_custom_roles: true
    expected_cost: "$0.70-1.10"  # Updated to reflect ST + clink enhancements
```

### 6.4 SKILL.md Updates

Added to `allowed-tools:`:

```yaml
allowed-tools:
  # ... existing tools ...
  # PAL MCP - Clink
  - mcp__pal__clink
```

---

## 7. Implementation Plan

### Wave 1: Templates (Foundation)

Create 13 files in `$CLAUDE_PLUGIN_ROOT/templates/clink-roles/`:

1. `README.md` -- Role index, dual-CLI MPA pattern docs, deployment instructions
2. `gemini.json` -- Gemini CLI client configuration (5 roles)
3. `codex.json` -- Codex CLI client configuration (5 roles)
4. `gemini_deepthinker.txt` -- Gemini deepthinker prompt
5. `codex_deepthinker.txt` -- Codex deepthinker prompt
6. `gemini_planreviewer.txt` -- Gemini planreviewer prompt
7. `codex_planreviewer.txt` -- Codex planreviewer prompt
8. `gemini_teststrategist.txt` -- Gemini teststrategist prompt
9. `codex_teststrategist.txt` -- Codex teststrategist prompt
10. `gemini_securityauditor.txt` -- Gemini securityauditor prompt
11. `codex_securityauditor.txt` -- Codex securityauditor prompt
12. `gemini_taskauditor.txt` -- Gemini taskauditor prompt
13. `codex_taskauditor.txt` -- Codex taskauditor prompt

### Wave 2: Phase Workflow Integration

Edit 6 phase reference files to add clink integration steps:

1. `skills/plan/references/phase-1-setup.md` -- Add Step 1.5b (clink detection + deployment)
2. `skills/plan/references/phase-5-thinkdeep.md` -- Add Step 5.6 (deepthinker supplement)
3. `skills/plan/references/phase-6-validation.md` -- Add Step 6.0a (plan review pre-validation)
4. `skills/plan/references/phase-6b-expert-review.md` -- Add Step 6b.1b (security supplement)
5. `skills/plan/references/phase-7-test-strategy.md` -- Add Step 7.3.5 (test strategy review)
6. `skills/plan/references/phase-9-completion.md` -- Add Step 9.5b (task audit)

### Wave 3: Configuration

1. Add `clink_context_isolation` and `clink_custom_roles` feature flags
2. Add `clink_integration:` section with roles, retry, timeout, fallback config
3. Update blessed profiles with clink flags

### Wave 4: SKILL.md and References

1. Add `mcp__pal__clink` to `allowed-tools` in `SKILL.md`
2. Update `skills/plan/references/README.md` with clink role index and file size estimates

### Wave 5: Documentation

1. Update `PROPOSAL-clink-integration.md` to reflect implemented design (this document)
2. Update `CLAUDE.md` with clink integration patterns and references

---

## 8. Cost-Benefit Analysis

### 8.1 Benefits

| Benefit | Quantification |
|---------|----------------|
| Coordinator context savings | ~30KB across all clink-enabled phases |
| Filesystem exploration | All roles actively explore codebase (EXPLORE directives) |
| Dual-perspective analysis | Convergent findings are high-confidence; divergent findings surface blind spots |
| Better isolation | Clink failures do not pollute coordinator context |
| CLI specialization | Gemini for broad exploration; Codex for code-level precision |
| ThinkDeep reconciliation | Absorbed into teststrategist (no separate role needed) |
| Task validation | New taskauditor catches invalid paths, missing requirements |

### 8.2 Costs

| Cost | Assessment |
|------|------------|
| Additional API cost | ~$0.15-0.30 per session (all roles combined) |
| Additional latency | ~5-10 minutes cumulative across all roles |
| Implementation effort | 5 waves (templates, workflows, config, SKILL.md, docs) |
| Prompt file maintenance | Low (10 files, stable once defined) |
| Configuration complexity | Moderate (mitigated by centralized `clink_integration:` section) |

### 8.3 ROI Assessment

**Primary value is analysis quality, not context savings.** The dual-CLI MPA pattern with EXPLORE directives produces codebase-grounded findings that inline agents cannot match. Context savings (~30KB coordinator-level) are a secondary benefit.

**Cost-effectiveness:** At $0.15-0.30 additional cost, clink adds 5 supplemental analysis passes with filesystem exploration, dual-perspective synthesis, and self-critique -- comparable value to adding 5 specialized human reviewers to the planning process.

**Recommendation:** HIGH ROI for Complete and Advanced modes where quality analysis justifies the latency investment.

---

## 9. Risks and Mitigations

### R1: Clink MCP Unavailable

**Risk:** PAL MCP server may not have clink enabled.

**Mitigation:**
- Runtime availability check at Step 1.5b
- `fallback.if_clink_unavailable: "skip_clink_steps"` -- all clink steps are additive, workflow completes without them
- State records `clink.available: false` for downstream phases to check

### R2: One CLI Missing

**Risk:** Gemini or Codex CLI may not be installed on the user's system.

**Mitigation:**
- Step 1.5b detects both CLIs independently
- Single-CLI fallback mode: uses whichever CLI is available
- Output marked with `mode: single_{cli_name}` for traceability
- Dual-CLI synthesis skipped -- direct findings used

### R3: CLI Timeout

**Risk:** External CLI processes may hang or take excessively long.

**Mitigation:**
- Per-role timeout configuration (120-180 seconds)
- Default timeout: 120 seconds
- Configurable in `clink_integration.timeout.per_role`

### R4: Consecutive Failures

**Risk:** Repeated clink failures waste time and latency budget.

**Mitigation:**
- **Circuit breaker:** After 2 consecutive failures, skip clink for the remainder of the session
- `retry.max_retries: 1` -- single retry before moving on
- `retry.circuit_breaker_threshold: 2` -- configurable in `planning-config.yaml`

### R5: Role Prompt Quality

**Risk:** Custom role prompts may produce inconsistent or low-quality results.

**Mitigation:**
- All roles include quality requirements with FORBIDDEN patterns (rubber-stamping, generic advice, reasoning without filesystem evidence)
- Self-critique via ST Chain-of-Verification validates every finding
- EXPLORE directives ensure grounded analysis (not prompt-only reasoning)
- Iterative refinement based on usage feedback

### R6: Increased Complexity

**Risk:** 10 prompt files + config section + 6 workflow integrations increase maintenance burden.

**Mitigation:**
- Centralized configuration in single `clink_integration:` section
- Template files ship with plugin (no user configuration required)
- Auto-deployment in Phase 1 (no manual setup)
- README.md index in templates directory for quick navigation

---

## 10. Acceptance Criteria

### AC1: Feature Flag Configuration

- [x] `clink_context_isolation` flag exists in `config/planning-config.yaml`
- [x] `clink_custom_roles` flag exists with `requires: [clink_context_isolation]`
- [x] Both flags specify `modes: [complete, advanced]`
- [x] Both flags specify `requires_mcp: true`
- [x] Both flags include `cost_impact` documentation

### AC2: Custom Role Files (10 Prompt Files)

- [x] `gemini_deepthinker.txt` -- broad architecture exploration with ST branching
- [x] `codex_deepthinker.txt` -- code-level coupling and dependency analysis
- [x] `gemini_planreviewer.txt` -- strategic plan review with Red Team/Blue Team ST
- [x] `codex_planreviewer.txt` -- technical feasibility with path/API verification
- [x] `gemini_teststrategist.txt` -- test infra discovery + ThinkDeep reconciliation
- [x] `codex_teststrategist.txt` -- test code patterns and assertion quality
- [x] `gemini_securityauditor.txt` -- supply chain and architectural security
- [x] `codex_securityauditor.txt` -- OWASP code-level vulnerabilities
- [x] `gemini_taskauditor.txt` -- completeness and scope coverage
- [x] `codex_taskauditor.txt` -- file path verification and dependency ordering
- [x] All roles include EXPLORE directives (mandatory filesystem exploration)
- [x] All roles include quality requirements with FORBIDDEN patterns
- [x] All roles include structured output format

### AC3: CLI Client Configuration

- [x] `gemini.json` defines 5 roles (deepthinker, planreviewer, teststrategist, securityauditor, taskauditor)
- [x] `codex.json` defines 5 roles (same 5)
- [x] Both include `additional_args` for auto-approval flags

### AC4: Dual-CLI MPA Behavior

- [x] Each clink step dispatches BOTH Gemini and Codex in parallel (when dual mode available)
- [x] Synthesis categorizes findings as convergent/divergent/unique
- [x] Single-CLI fallback when only one CLI is available
- [x] `skip_clink_steps` fallback when neither CLI is available

### AC5: Self-Critique Pattern

- [x] Self-critique runs in Task(general-purpose) subagent (not inline in coordinator)
- [x] Uses ST Chain-of-Verification (3-5 verification questions)
- [x] Returns only validated findings
- [x] Prevents coordinator context pollution

### AC6: Phase Workflow Integration (6 Points)

- [x] Phase 1 Step 1.5b: Clink detection + template deployment
- [x] Phase 5 Step 5.6: Deepthinker supplement (after ThinkDeep matrix)
- [x] Phase 6 Step 6.0a: Plan review pre-validation (before Consensus)
- [x] Phase 6b Step 6b.1b: Security audit supplement (parallel with standard agents)
- [x] Phase 7 Step 7.3.5: Test strategy review (Complete mode only)
- [x] Phase 9 Step 9.5b: Task audit (after task validation)
- [x] All integration points have runtime clink availability checks
- [x] All integration points have graceful skip on unavailability

### AC7: Graceful Degradation

- [x] Workflow completes when clink unavailable (all steps skip cleanly)
- [x] Workflow completes with single CLI (single-CLI mode)
- [x] Circuit breaker disables clink after 2 consecutive failures
- [x] Fallback behavior logged appropriately

### AC8: Template Deployment

- [x] Templates stored in `$CLAUDE_PLUGIN_ROOT/templates/clink-roles/`
- [x] Phase 1 auto-copies to `PROJECT_ROOT/conf/cli_clients/`
- [x] Version marker (`clink_role_version: 1.0.0`) used for update detection
- [x] README.md index with role table and pattern documentation

### AC9: Configuration Completeness

- [x] `clink_integration:` section in `planning-config.yaml`
- [x] Timeout config per role
- [x] Retry and circuit breaker config
- [x] Fallback behavior config
- [x] Latency estimates per role
- [x] Blessed profiles updated with clink flags
- [x] SKILL.md includes `mcp__pal__clink` in allowed-tools

---

## Appendix A: File Structure

```
templates/clink-roles/
├── README.md                        # Role index, dual-CLI MPA pattern docs, deployment
├── gemini.json                      # Gemini CLI config (5 roles)
├── codex.json                       # Codex CLI config (5 roles)
├── gemini_deepthinker.txt           # Broad architecture exploration (Phase 5)
├── codex_deepthinker.txt            # Code-level coupling analysis (Phase 5)
├── gemini_planreviewer.txt          # Strategic plan review (Phase 6)
├── codex_planreviewer.txt           # Technical feasibility review (Phase 6)
├── gemini_teststrategist.txt        # Test infra + ThinkDeep reconciliation (Phase 7)
├── codex_teststrategist.txt         # Test code patterns + assertion quality (Phase 7)
├── gemini_securityauditor.txt       # Supply chain + architectural security (Phase 6b)
├── codex_securityauditor.txt        # OWASP code-level vulnerabilities (Phase 6b)
├── gemini_taskauditor.txt           # Completeness + scope coverage (Phase 9)
└── codex_taskauditor.txt            # File path verification + deps (Phase 9)
```

Phase workflow files with clink integration:

```
skills/plan/references/
├── phase-1-setup.md                 # Step 1.5b: Clink detection + deployment
├── phase-5-thinkdeep.md             # Step 5.6: Deepthinker supplement
├── phase-6-validation.md            # Step 6.0a: Plan review pre-validation
├── phase-6b-expert-review.md        # Step 6b.1b: Security audit supplement
├── phase-7-test-strategy.md         # Step 7.3.5: Test strategy review
└── phase-9-completion.md            # Step 9.5b: Task audit
```

Configuration and metadata:

```
config/planning-config.yaml          # clink_integration section + feature flags
skills/plan/SKILL.md                 # mcp__pal__clink in allowed-tools
skills/plan/references/README.md     # Clink role index and file sizes
```

Runtime deployment target (auto-created by Phase 1):

```
PROJECT_ROOT/conf/cli_clients/       # Copied from templates/clink-roles/
├── gemini.json
├── codex.json
├── gemini_deepthinker.txt
├── codex_deepthinker.txt
├── gemini_planreviewer.txt
├── codex_planreviewer.txt
├── gemini_teststrategist.txt
├── codex_teststrategist.txt
├── gemini_securityauditor.txt
├── codex_securityauditor.txt
├── gemini_taskauditor.txt
└── codex_taskauditor.txt
```

Output artifacts (per-feature, written by coordinators):

```
{FEATURE_DIR}/analysis/
├── clink-deepthinker-report.md      # Phase 5 supplement findings
├── clink-planreview-report.md       # Phase 6 pre-validation findings
├── clink-security-report.md         # Phase 6b security supplement
├── clink-testreview-report.md       # Phase 7 test review findings
└── clink-taskaudit-report.md        # Phase 9 task audit findings
```

---

## Appendix B: CLI Client Configuration

### `templates/clink-roles/gemini.json`

```json
{
  "name": "gemini",
  "command": "gemini",
  "additional_args": ["--yolo"],
  "roles": {
    "deepthinker": { "prompt_path": "gemini_deepthinker.txt" },
    "planreviewer": { "prompt_path": "gemini_planreviewer.txt" },
    "teststrategist": { "prompt_path": "gemini_teststrategist.txt" },
    "securityauditor": { "prompt_path": "gemini_securityauditor.txt" },
    "taskauditor": { "prompt_path": "gemini_taskauditor.txt" }
  }
}
```

### `templates/clink-roles/codex.json`

```json
{
  "name": "codex",
  "command": "codex",
  "additional_args": ["--dangerously-bypass-approvals-and-sandbox"],
  "roles": {
    "deepthinker": { "prompt_path": "codex_deepthinker.txt" },
    "planreviewer": { "prompt_path": "codex_planreviewer.txt" },
    "teststrategist": { "prompt_path": "codex_teststrategist.txt" },
    "securityauditor": { "prompt_path": "codex_securityauditor.txt" },
    "taskauditor": { "prompt_path": "codex_taskauditor.txt" }
  }
}
```

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **clink** | CLI-to-CLI bridge in PAL MCP; spawns an isolated CLI agent (Gemini, Codex) with a custom role prompt and filesystem access |
| **Dual-CLI MPA** | Pattern where every clink role runs both Gemini and Codex in parallel, then synthesizes findings as convergent/divergent/unique |
| **Convergent finding** | A finding where both Gemini and Codex agree; classified as HIGH confidence |
| **Divergent finding** | A finding where Gemini and Codex disagree; flagged for user decision or further verification |
| **Unique finding** | A finding surfaced by only one CLI; verified against existing analysis before inclusion |
| **EXPLORE directives** | Mandatory filesystem exploration instructions in every role prompt; the key differentiator of clink vs inline agents |
| **Self-critique (CoVe)** | Chain-of-Verification applied via a Task(general-purpose) subagent; generates 3-5 verification questions, answers them, and revises findings |
| **Context isolation** | Running analysis in a separate CLI process so results do not consume coordinator context budget |
| **Custom role** | A specialized behavior prompt file (`.txt`) loaded by clink for a specific analysis domain |
| **Circuit breaker** | After N consecutive clink failures (default: 2), all clink steps are skipped for the remainder of the session |
| **Single-CLI mode** | Fallback when only one CLI is available; runs that CLI alone, skips dual-CLI synthesis |
| **Template deployment** | Phase 1 auto-copies role templates from `$CLAUDE_PLUGIN_ROOT/templates/clink-roles/` to `PROJECT_ROOT/conf/cli_clients/` |
| **ST** | Sequential Thinking MCP tool for structured reasoning chains with branching, revision, and extension |
| **Red Team / Blue Team** | Adversarial analysis pattern used by planreviewer: Red Team attacks the plan, Blue Team proposes mitigations |
| **ThinkDeep reconciliation** | Mapping Phase 5 ThinkDeep findings to Phase 7 test coverage; performed by teststrategist (Gemini variant) |
| **V-Model** | Test planning framework mapping development phases (requirements, architecture, design, implementation) to test levels (UAT, E2E, integration, unit) |
| **OWASP Top 10** | Standard security vulnerability checklist used by securityauditor (Codex variant) for code-level assessment |

---

*Last updated: 2026-02-07*
