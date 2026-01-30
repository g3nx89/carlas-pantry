---
name: Feature Planning
description: This skill should be used when the user asks to "plan a feature", "create an implementation plan", "design the architecture", "break down a feature into tasks", "decompose a specification", "plan development", "plan tests", or needs multi-perspective analysis for feature implementation. Provides 9-phase workflow with MPA agents, PAL ThinkDeep validation, V-Model test planning, and consensus scoring.
version: 2.0.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(cp:*)
  - Bash(mkdir:*)
  - Bash(rm:*)
  - Bash(git:*)
  - Bash(ls:*)
  - Task
  - AskUserQuestion
  - mcp__sequential-thinking__sequentialthinking
  - mcp__pal__thinkdeep
  - mcp__pal__consensus
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
- Consolidate findings to `research.md`

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
- Launch 3 architecture agents (MPA) in parallel:
  - Minimal Change approach
  - Clean Architecture approach
  - Pragmatic Balance approach
- Execute Sequential Thinking T7-T10 (Complete mode)
- Present comparison with recommendation
- Record architecture decision

### Phase 5: PAL ThinkDeep Analysis
**Complete/Advanced modes only.**

Execute multi-model analysis across perspectives:
- **Performance** - scalability, latency, resource efficiency
- **Maintainability** - code quality, extensibility, tech debt (Complete only)
- **Security** - threat modeling, compliance, vulnerabilities

Models: gpt-5.2, gemini-3-pro-preview, grok-4

Synthesize convergent (all agree) vs. divergent (flag for decision) insights.

### Phase 6: Plan Validation
**Complete mode:** Execute PAL Consensus with:
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

### Phase 7: Test Strategy (V-Model)
**Integrated test planning with MPA pattern**

Generate comprehensive test strategy aligned with V-Model:

1. **Risk Analysis** - Identify failure modes and prioritize by severity
2. **Test Level Planning** - Map each development artifact to test level:
   - Requirements → UAT Scripts (Given-When-Then)
   - Architecture → E2E Scenarios
   - Design → Integration Tests
   - Implementation → Unit Tests (TDD specs)
3. **UAT Script Generation** - Create user story-based acceptance tests
4. **Phase 5 Reconciliation** - Align ThinkDeep security/performance insights with test risks

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

Output:
- Risk assessment with mitigation mapping
- Phase 5 ↔ Phase 7 reconciliation report
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
- **`references/phase-workflows.md`** - Detailed phase-by-phase instructions
- **`references/thinkdeep-prompts.md`** - PAL ThinkDeep perspective prompts
- **`references/validation-rubric.md`** - Consensus scoring criteria
- **`references/v-model-methodology.md`** - V-Model testing reference
- **`references/coverage-validation-rubric.md`** - Test coverage scoring

### Configuration
- **`$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml`** - All limits, thresholds, models

### Examples
- **`examples/state-file.md`** - Sample planning state file
- **`examples/thinkdeep-output.md`** - Sample ThinkDeep synthesis

### Templates
- **`$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md`** - Test plan structure
- **`$CLAUDE_PLUGIN_ROOT/templates/uat-script-template.md`** - UAT script format

## Quick Start

1. Ensure `{FEATURE_DIR}/spec.md` exists
2. Run `/product-planning:plan` or ask "plan this feature"
3. Select analysis mode (Complete recommended for critical features)
4. Answer clarifying questions
5. Review architecture options and select one
6. Review ThinkDeep insights (Complete/Advanced)
7. Verify plan validation passes (GREEN/YELLOW)
8. **Review test strategy and coverage**
9. Verify test coverage validation passes (≥80%)
10. Review final artifacts and commit

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
