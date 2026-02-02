---
name: Feature Planning
description: This skill should be used when the user asks to "plan a feature", "create an implementation plan", "design the architecture", "break down a feature into tasks", "decompose a specification", "plan development", "plan tests", or needs multi-perspective analysis for feature implementation. Provides 9-phase workflow with MPA agents, PAL ThinkDeep validation, V-Model test planning, and consensus scoring.
version: 2.0.0
allowed-tools:
  # File operations
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  # Shell commands
  - Bash(cp:*)
  - Bash(mkdir:*)
  - Bash(rm:*)
  - Bash(git:*)
  - Bash(ls:*)
  # Agent orchestration
  - Task
  - AskUserQuestion
  # Sequential Thinking MCP
  - mcp__sequential-thinking__sequentialthinking
  # PAL MCP (multi-model analysis)
  - mcp__pal__thinkdeep
  - mcp__pal__consensus
  - mcp__pal__listmodels
  - mcp__pal__challenge
  # Research MCP - Context7 (library documentation)
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
  # Research MCP - Ref (docs with prose, private repos)
  - mcp__Ref__ref_search_documentation
  - mcp__Ref__ref_read_url
  # Research MCP - Tavily (web search, news, current events)
  - mcp__tavily__tavily_search
  - mcp__tavily__tavily_extract
---

# Feature Planning Skill

> **Invoke:** `/product-planning:plan` or ask "plan this feature"

Transform feature specifications into actionable implementation plans with integrated test strategy:
- Explore the codebase to understand existing patterns
- Collect clarifying questions to resolve ambiguities
- Generate multiple architecture options via parallel agents
- Validate designs through multi-model analysis
- **Generate V-Model test strategy with UAT scripts**
- Produce final implementation plans with task breakdowns

## Critical Rules

1. **State Preservation** - Checkpoint after user decisions. User decisions are IMMUTABLE once saved.
2. **Resume Compliance** - When resuming, NEVER re-ask questions from `user_decisions`.
3. **Delegation** - Complex analysis uses MPA agents + PAL ThinkDeep. Do NOT attempt inline analysis.
4. **Mode Selection** - ALWAYS ask user to choose analysis mode before proceeding.
5. **Lock Protocol** - Acquire lock at start, release at completion. Check for stale locks (>60 min).
6. **Config Reference** - Use `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` for all settings.
7. **V-Model Alignment** - Every acceptance criterion MUST have a corresponding test.

## Analysis Modes

| Mode | Description | MCP Required | Est. Cost |
|------|-------------|--------------|-----------|
| **Complete** | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes | $0.80-1.50 |
| **Advanced** | MPA + ThinkDeep (6) + Test Plan | Yes | $0.45-0.75 |
| **Standard** | MPA only + Basic Test Plan | No | $0.15-0.30 |
| **Rapid** | Single agent + Minimal Test Plan | No | $0.05-0.12 |

Graceful degradation: If PAL unavailable, fall back to Standard/Rapid modes.

## Workflow Phases

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLANNING WORKFLOW (V-MODEL)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐                              ┌─────────────────┐   │
│  │ Phase 1 │ Setup & Initialization       │                 │   │
│  └────┬────┘                              │                 │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 2 │ Research & Exploration       │                 │   │
│  └────┬────┘                              │                 │   │
│       ↓                                   │  V-MODEL        │   │
│  ┌─────────┐                              │  TEST           │   │
│  │ Phase 3 │ Clarifying Questions ────────┼→ UAT Scripts    │   │
│  └────┬────┘ (Requirements)               │                 │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 4 │ Architecture Design ─────────┼→ E2E Tests      │   │
│  └────┬────┘                              │                 │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 5 │ PAL ThinkDeep ───────────────┼→ Integration    │   │
│  └────┬────┘                              │                 │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 6 │ Plan Validation              │                 │   │
│  └────┬────┘                              │                 │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 7 │ Test Strategy ───────────────┼→ Unit Tests     │   │
│  └────┬────┘ (V-Model Planning)           │  (TDD Specs)    │   │
│       ↓                                   │                 │   │
│  ┌─────────┐                              │                 │   │
│  │ Phase 8 │ Test Coverage Validation     │                 │   │
│  └────┬────┘                              └─────────────────┘   │
│       ↓                                                         │
│  ┌─────────┐                                                    │
│  │ Phase 9 │ Completion                                         │
│  └─────────┘                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Phase 1: Setup & Initialization
- Verify prerequisites (spec.md, constitution.md exist)
- Detect branch and feature directory
- Check for existing state (resume vs. new)
- Check MCP tool availability
- Present analysis mode selection
- Acquire planning lock

### Phase 2: Research & Codebase Exploration
- Load feature spec and constitution
- Launch researcher agents for unknowns
- Launch code-explorer agents (MPA) in parallel:
  - Find similar features
  - Map architecture patterns
  - Identify integration points
- Execute Sequential Thinking T4-T6 (Complete mode)
- Launch learnings-researcher in parallel (A2, if knowledge base exists)
- Consolidate findings to `research.md`
- **Quality Gate:** Research Completeness (Advanced/Complete modes)

### Phase 2b: User Flow Analysis (A1)
**Complete mode only. Feature flag: `a1_user_flow_analysis`**

- Launch flow-analyzer agent to map user journeys:
  - Identify all entry points and exit points
  - Map decision points and branching logic
  - Calculate permutation matrix
  - Generate gap questions for Phase 3
- Output: Flow diagrams, decision tree, test scenario recommendations
- Reference: `templates/user-flow-analysis-template.md`

### Phase 3: Clarifying Questions
- Execute Sequential Thinking T1-T3 (Complete mode)
- Generate questions across categories:
  - Scope boundaries
  - Edge cases
  - Error handling
  - Integration details
  - Design preferences
- **BLOCKING:** Wait for ALL user responses
- Save decisions to state (IMMUTABLE)

### Phase 4: Architecture Design
**Standard/Advanced modes:** Launch 3 architecture agents (MPA) in parallel:
- Minimal Change approach
- Clean Architecture approach
- Pragmatic Balance approach

**TAO Loop (st_tao_loops enabled):** After MPA agents complete:
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ T-AGENT-ANALYSIS│ →  │ T-AGENT-SYNTHESIS│ →  │T-AGENT-VALIDATION│
│ Categorize      │    │ Define strategy │    │ Quality check   │
│ findings        │    │ per category    │    │ before proceed  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Complete mode with S5 ToT enabled:** Execute Hybrid ToT-MPA workflow:
1. **Phase 4a: Seeded Exploration** - Generate 8 approaches:
   - Minimal perspective: 2 approaches (seeded)
   - Clean perspective: 2 approaches (seeded)
   - Pragmatic perspective: 2 approaches (seeded)
   - Wildcard: 2 approaches (unconstrained, via wildcard-architect)
2. **Phase 4b: Multi-Criteria Pruning** - 3 judges evaluate all 8, select top 4
3. **Phase 4c: Competitive Expansion** - 4 agents develop full designs
4. **Phase 4d: Evaluation + Adaptive Selection** - Apply S4 strategy:
   - SELECT_AND_POLISH: Clear winner (gap ≥0.5, score ≥3.0)
   - FULL_SYNTHESIS: Tie (all ≥3.0, gap <0.5)
   - REDESIGN: All weak (any <3.0) → Return to 4a

**Fork-Join ST Pattern (st_fork_join_architecture enabled, Complete mode):**
```
┌─────────────────────────────────────────────────────────────────┐
│                     FORK-JOIN ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                 │
│  │  T7a_FRAME  │  ← Frame decision, spawn branches              │
│  └──────┬──────┘                                                 │
│         │                                                        │
│    ┌────┴────┬────────────┐                                     │
│    ↓         ↓            ↓                                     │
│ ┌──────┐ ┌──────┐ ┌──────────┐                                  │
│ │T7b   │ │T7c   │ │T7d       │  ← Parallel exploration         │
│ │MINIMAL│ │CLEAN │ │PRAGMATIC │    (branchId per path)         │
│ └──┬───┘ └──┬───┘ └────┬─────┘                                  │
│    │        │          │                                        │
│    └────────┴──────────┘                                        │
│              ↓                                                   │
│      ┌────────────┐                                              │
│      │T8_SYNTHESIS│  ← Join and synthesize                      │
│      └──────┬─────┘                                              │
│             ↓                                                    │
│    Continue with T9, T10 using selected approach                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

- Execute Sequential Thinking T7-T10 (Complete mode)
- Present comparison with recommendation
- Record architecture decision
- **Quality Gate:** Architecture Quality (Advanced/Complete modes)

Reference: `references/tot-workflow.md`, `references/adaptive-strategy-logic.md`

### Phase 5: PAL ThinkDeep Analysis
**Complete/Advanced modes only.**

Execute multi-model analysis across perspectives:
- **Performance** - scalability, latency, resource efficiency
- **Maintainability** - code quality, extensibility, tech debt (Complete only)
- **Security** - threat modeling, compliance, vulnerabilities

Models: gpt-5.2, gemini-3-pro-preview, grok-4

Synthesize convergent (all agree) vs. divergent (flag for decision) insights.

### Phase 6: Plan Validation
**Complete mode with S6 Multi-Judge Debate enabled:**

Execute multi-round debate validation:
1. **Round 1: Independent Analysis** - 3 judges evaluate independently
   - Neutral (gemini-3-pro-preview)
   - Advocate (gpt-5.2)
   - Challenger (grok-4)
2. **Consensus Check** - If all scores within 0.5, synthesize and proceed
3. **Round 2: Rebuttal** - Each judge reads others, writes rebuttals, may revise
4. **Consensus Check** - If converged, synthesize and proceed
5. **Round 3: Final Positions** - Force verdict via majority rule

Reference: `references/debate-protocol.md`

**Standard Complete mode (S6 disabled):** Execute PAL Consensus with:
- Neutral evaluator (gemini)
- Advocate (gpt-5.2)
- Challenger (grok-4)

Scoring (20 points):
| Dimension | Weight |
|-----------|--------|
| Problem Understanding | 20% |
| Architecture Quality | 25% |
| Risk Mitigation | 20% |
| Implementation Clarity | 20% |
| Feasibility | 15% |

Thresholds: GREEN ≥16, YELLOW ≥12, RED <12 (return to Phase 4)

**Fallback:** Internal validation using Sequential Thinking T14-T16.

### Phase 6b: Expert Review (A4)
**Advanced/Complete modes. Feature flag: `a4_expert_review`**

After plan validation, optionally trigger expert review:
- **Security Review** - Launch security-analyst agent for STRIDE analysis
- **Simplicity Review** - Launch simplicity-reviewer for over-engineering check

Results integrated into final plan. Security findings may be blocking; simplicity findings are advisory.

Reference: `agents/reviewers/security-analyst.md`, `agents/reviewers/simplicity-reviewer.md`

### Phase 7: Test Strategy (V-Model)
**Integrated test planning with MPA pattern and ST enhancements**

Generate comprehensive test strategy aligned with V-Model:

1. **Risk Analysis** - Identify failure modes and prioritize by severity
2. **Test Level Planning** - Map each development artifact to test level:
   - Requirements → UAT Scripts (Given-When-Then)
   - Architecture → E2E Scenarios
   - Design → Integration Tests
   - Implementation → Unit Tests (TDD specs)
3. **UAT Script Generation** - Create user story-based acceptance tests
4. **Phase 5 Reconciliation** - Align ThinkDeep security/performance insights with test risks

**ST Enhancement: Revision for Reconciliation (st_revision_reconciliation enabled):**
When Phase 5 ThinkDeep findings contradict Phase 7 risk analysis:
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    T-RISK-2     │ →  │ T-RISK-REVISION  │ →  │ Updated risks   │
│ Original output │    │ isRevision: true │    │ with ThinkDeep  │
│                 │    │ revisesThought: 2│    │ reconciliation  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**ST Enhancement: Red Team Branch (st_redteam_analysis enabled, Complete/Advanced):**
```
┌─────────────────┐         ┌─────────────────────┐
│    T-RISK-1     │ ──fork→ │  T-RISK-REDTEAM     │
│ Failure modes   │         │  branchId: "redteam"│
└────────┬────────┘         │  Attacker perspective│
         │                  └──────────┬──────────┘
         │                             │
         └────────────────┬────────────┘
                          ↓
              ┌───────────────────────┐
              │T-RISK-REDTEAM-SYNTHESIS│
              │ Merge adversarial     │
              │ findings to test plan │
              └───────────────────────┘
```

**Launch QA agents (MPA):**

| Mode | Agents Launched |
|------|-----------------|
| Complete | qa-strategist + qa-security + qa-performance |
| Advanced | qa-strategist + qa-security + qa-performance |
| Standard | qa-strategist only |
| Rapid | qa-strategist (minimal) |

```
Task(subagent_type: "product-planning:qa-strategist", prompt: "V-Model test strategy...")
Task(subagent_type: "product-planning:qa-security", prompt: "Security test cases...")
Task(subagent_type: "product-planning:qa-performance", prompt: "Performance test cases...")
```

**TAO Loop (st_tao_loops enabled):** After QA agents complete:
- T-AGENT-ANALYSIS: Categorize convergent/divergent/gap findings
- T-AGENT-SYNTHESIS: Define handling strategy per category
- T-AGENT-VALIDATION: Quality check before proceeding

Output:
- Risk assessment with mitigation mapping
- Phase 5 ↔ Phase 7 reconciliation report (with ST Revision if enabled)
- Red team findings (if st_redteam_analysis enabled)
- Unit test specifications (TDD-ready)
- Integration test specifications
- E2E test scenarios with evidence requirements
- Security test cases (STRIDE-based)
- Performance test cases (load/stress)
- UAT scripts in Given-When-Then format

### Phase 8: Test Coverage Validation
Validate test plan completeness using PAL Consensus:

Scoring (100%):
| Dimension | Weight |
|-----------|--------|
| AC Coverage | 25% |
| Risk Coverage | 25% |
| UAT Completeness | 20% |
| Test Independence | 15% |
| Maintainability | 15% |

Thresholds: GREEN ≥80%, YELLOW ≥65%, RED <65%

**RED status:** Return to Phase 7 to add missing tests.

### Phase 9: Completion
- Generate final `design.md` and `plan.md`
- Generate final `test-plan.md` with coverage matrix
- Create task breakdown with test dependencies
- Structure tasks as: TEST → IMPLEMENT → VERIFY cycles
- Release planning lock
- Display summary report
- Suggest git commit

## State Management

State persisted in `{FEATURE_DIR}/.planning-state.local.md`:
- YAML frontmatter tracks phase, mode, decisions
- Markdown body contains human-readable log
- Immutable fields: `user_decisions`, `approved_architecture`, `approved_test_strategy`

## MPA Agents

Available agents for multi-perspective analysis:

### Planning Agents (Phases 2-4)
- `product-planning:code-explorer` - Codebase patterns and integration points
- `product-planning:software-architect` - Architecture options and trade-offs
- `product-planning:tech-lead` - Task breakdown and complexity analysis
- `product-planning:researcher` - Technology research and unknowns
- `product-planning:flow-analyzer` - User flow mapping (Complete mode, A1)
- `product-planning:learnings-researcher` - Institutional knowledge lookup (A2)

### Explorer Agents (Phase 4 ToT)
- `product-planning:wildcard-architect` - Unconstrained architecture exploration (Complete mode, S5)

### Judge Agents (Phases 4, 6, 7)
- `product-planning:phase-gate-judge` - Quality gate evaluation (S3)
- `product-planning:architecture-pruning-judge` - ToT option pruning (Complete mode, S5)
- `product-planning:debate-judge` - Multi-round debate moderation (Complete mode, S6)

### Reviewer Agents (Phase 6b)
- `product-planning:security-analyst` - STRIDE threat analysis (Advanced/Complete, A4)
- `product-planning:simplicity-reviewer` - Over-engineering detection (Advanced/Complete, A4)

### QA Agents (Phase 7) - MPA for Test Planning
- `product-planning:qa-strategist` - V-Model test strategy and UAT generation (all modes)
- `product-planning:qa-security` - Security testing, STRIDE analysis (Complete/Advanced)
- `product-planning:qa-performance` - Performance/load testing (Complete/Advanced)

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture design |
| `plan.md` | Implementation plan |
| `tasks.md` | Task breakdown with dependencies |
| `research.md` | Codebase analysis findings |
| `test-plan.md` | V-Model test strategy |
| `test-cases/unit/` | Unit test specifications |
| `test-cases/integration/` | Integration test specs |
| `test-cases/e2e/` | E2E scenario scripts |
| `test-cases/uat/` | UAT scripts (Given-When-Then) |
| `data-model.md` | Entity definitions (optional) |
| `contract.md` | API contracts (optional) |

## Additional Resources

### Reference Files
- **`references/phase-workflows.md`** - Detailed phase-by-phase instructions (with ST enhancements)
- **`references/thinkdeep-prompts.md`** - PAL ThinkDeep perspective prompts
- **`references/validation-rubric.md`** - Consensus scoring criteria
- **`references/v-model-methodology.md`** - V-Model testing reference
- **`references/coverage-validation-rubric.md`** - Test coverage scoring
- **`references/self-critique-template.md`** - Standard self-critique for all agents (S1)
- **`references/cot-prefix-template.md`** - Chain-of-Thought reasoning template (S2)
- **`references/judge-gate-rubrics.md`** - Quality gate scoring criteria (S3)
- **`references/adaptive-strategy-logic.md`** - Architecture selection strategy (S4)
- **`references/tot-workflow.md`** - Hybrid ToT-MPA workflow (S5)
- **`references/debate-protocol.md`** - Multi-round debate validation (S6)

### Sequential Thinking Reference
- **`$CLAUDE_PLUGIN_ROOT/templates/sequential-thinking-templates.md`** - All ST templates including:
  - Groups 1-6: Standard templates (T1-T16, T-RISK-1 to T-RISK-3)
  - Group 7: Fork-Join Architecture (T7a-T8) - branching exploration
  - Group 8: Revision Templates (T-RISK-REVISION) - reconciliation
  - Group 9: Red Team Analysis (T-RISK-REDTEAM series) - adversarial perspective
  - Group 10: TAO Loop (T-AGENT series) - structured synthesis pause
  - Group 11: Dynamic Extension (T-EXTENSION) - chain extension

### Configuration
- **`$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml`** - All limits, thresholds, models

### Examples
- **`examples/state-file.md`** - Sample planning state file
- **`examples/thinkdeep-output.md`** - Sample ThinkDeep synthesis

### Templates
- **`$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md`** - Test plan structure
- **`$CLAUDE_PLUGIN_ROOT/templates/uat-script-template.md`** - UAT script format
- **`$CLAUDE_PLUGIN_ROOT/templates/user-flow-analysis-template.md`** - Flow analysis output (A1)
- **`$CLAUDE_PLUGIN_ROOT/templates/judge-report-template.md`** - Quality gate reports (S3)
- **`$CLAUDE_PLUGIN_ROOT/templates/debate-round-template.md`** - Debate round format (S6)
- **`$CLAUDE_PLUGIN_ROOT/templates/github-issue-template.md`** - GitHub issue export (A5)

## Quick Start

1. Ensure `{FEATURE_DIR}/spec.md` exists
2. Run `/product-planning:plan` or ask "plan this feature"
3. Select analysis mode (Complete recommended for critical features)
4. Answer clarifying questions (informed by flow analysis in Complete mode)
5. Review architecture options (8 approaches via ToT in Complete mode)
6. Review ThinkDeep insights (Complete/Advanced)
7. Verify plan validation passes (via debate in Complete mode)
8. Review expert analysis if triggered (security/simplicity)
9. **Review test strategy and coverage**
10. Verify test coverage validation passes (≥80%)
11. Review final artifacts
12. Use post-planning menu: Review, Expert, Simplify, GitHub, Commit, or Quit

## Error Handling

- **Missing prerequisites** - Provide guidance to create spec.md
- **MCP unavailable** - Graceful degradation to simpler modes
- **Agent failure** - Retry once, then skip with warning
- **Lock conflict** - Wait or manual intervention guidance
- **RED plan validation** - Return to Phase 4 with specific improvements
- **RED test coverage** - Return to Phase 7 to add missing tests

## Test Execution Order (V-Model)

After planning completes, implementation follows V-Model test order:

1. **Pre-Implementation:** Write failing unit tests (TDD RED)
2. **During Implementation:** Pass unit tests (TDD GREEN), refactor
3. **Post-Implementation:** Run integration tests
4. **Pre-Merge:** Run E2E tests with evidence collection
5. **Pre-Release:** Execute UAT with Product Owner sign-off
