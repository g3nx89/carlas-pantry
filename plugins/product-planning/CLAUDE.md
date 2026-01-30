# CLAUDE.md

This file provides guidance to Claude Code when working with this plugin.

## Plugin Overview

Plugin for feature planning, task decomposition, and **integrated test strategy generation** using SDD (Subagent-Driven Development) patterns with:
- **Multi-Perspective Analysis (MPA)** - Parallel agents with different focuses
- **PAL ThinkDeep** - External model insights (performance, maintainability, security)
- **PAL Consensus** - Multi-model validation with scoring rubric
- **Sequential Thinking** - Structured reasoning templates
- **V-Model Test Planning** - Comprehensive test strategy aligned with development phases (integrated)
- **UAT Script Generation** - User story-based acceptance testing with Given-When-Then format

## Plugin Testing

```bash
# Install locally for testing
claude plugins add /path/to/product-planning
claude plugins enable product-planning

# Run the main workflow (includes test planning)
/product-planning:plan
```

## Architecture

### 9-Phase Integrated Workflow

The skill `skills/plan/SKILL.md` orchestrates a **9-phase workflow** that includes both feature planning AND test strategy:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLANNING WORKFLOW (V-MODEL)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 1: Setup & Initialization                                 │
│       ↓                                                          │
│  Phase 2: Research & Exploration                                 │
│       ↓                                                          │
│  Phase 3: Clarifying Questions ─────────→ UAT Scripts           │
│       ↓                                                          │
│  Phase 4: Architecture Design ──────────→ E2E Tests             │
│       ↓                                                          │
│  Phase 5: PAL ThinkDeep ────────────────→ Integration Tests     │
│       ↓                                                          │
│  Phase 6: Plan Validation                                        │
│       ↓                                                          │
│  Phase 7: Test Strategy (V-Model) ──────→ Unit Tests (TDD)      │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 9: Completion                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Integration:** Test planning (Phases 7-8) is now embedded directly in the main workflow, not a separate skill.

### Phase Summary

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Setup | Initialize workspace, detect state, select analysis mode |
| 2 | Research | Codebase exploration, technology research |
| 3 | Clarification | User questions, gap resolution |
| 4 | Architecture | MPA design options (minimal/clean/pragmatic) |
| 5 | ThinkDeep | PAL multi-model insights (Complete/Advanced modes) |
| 6 | Validation | PAL Consensus plan validation |
| **7** | **Test Strategy** | **V-Model test planning, UAT generation** |
| **8** | **Test Coverage** | **Coverage validation, PAL Consensus** |
| 9 | Completion | Final artifacts, TDD-structured task breakdown |

### Analysis Mode Hierarchy

| Mode | Description | MCP Required | Cost |
|------|-------------|--------------|------|
| Complete | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes | $0.80-1.50 |
| Advanced | MPA + ThinkDeep (6) + Test Plan | Yes | $0.45-0.75 |
| Standard | MPA only + Basic Test Plan | No | $0.15-0.30 |
| Rapid | Single agent + Minimal Test Plan | No | $0.05-0.12 |

The plugin gracefully degrades when MCP tools are unavailable.

### PAL ThinkDeep Integration

Phase 5 executes multi-model analysis across perspectives:
- **Performance** - Scalability, latency, resource efficiency
- **Maintainability** - Code quality, extensibility, technical debt
- **Security** - Threat modeling, compliance, vulnerabilities

Models used: gpt-5.2, gemini-3-pro-preview, grok-4

### PAL Consensus Validation

**Phase 6 (Plan):** 20 points across 5 dimensions:
- Problem Understanding (20%)
- Architecture Quality (25%)
- Risk Mitigation (20%)
- Implementation Clarity (20%)
- Feasibility (15%)

Thresholds: GREEN ≥16, YELLOW ≥12, RED <12

**Phase 8 (Test Coverage):** 100% across 5 dimensions:
- AC Coverage (25%)
- Risk Coverage (25%)
- UAT Completeness (20%)
- Test Independence (15%)
- Maintainability (15%)

Thresholds: GREEN ≥80%, YELLOW ≥65%, RED <65%

### State Management

State is persisted in `{FEATURE_DIR}/.planning-state.local.md` (YAML frontmatter + markdown). The workflow is resumable—user decisions are immutable and never re-asked.

Checkpoints: SETUP → RESEARCH → CLARIFICATION → ARCHITECTURE → THINKDEEP → VALIDATION → **TEST_STRATEGY** → **TEST_COVERAGE_VALIDATION** → COMPLETION

## V-Model Test Planning (Integrated)

### Test Levels (V-Model Alignment)

| Development Phase | Test Level | Loop | Executor |
|------------------|------------|------|----------|
| Requirements | UAT (Acceptance) | Outer | Product Owner |
| Architecture | E2E (System) | Outer | QA / Automation |
| Design | Integration | Inner | CI Pipeline |
| Implementation | Unit | Inner | CI Pipeline (TDD) |

### Inner vs Outer Loop

**Inner Loop (Automated, CI):**
- Unit Tests - TDD pattern, write before implementation
- Integration Tests - Component boundaries

**Outer Loop (Manual/Agentic, Pre-release):**
- E2E Tests - Complete user flows with evidence
- UAT Scripts - Given-When-Then format for stakeholders
- Exploratory Testing - Charter-based edge case discovery

### UAT Script Format

UAT scripts follow Gherkin-style Given-When-Then:

```gherkin
Given: {preconditions}
When: {user actions}
Then: {expected outcomes}
```

With evidence collection (screenshots) and sign-off checkboxes for Product Owner approval.

### TDD-Structured Tasks

Phase 9 generates tasks structured as TEST → IMPLEMENT → VERIFY cycles:

```markdown
## Task: {component_name}

### 1. TEST (RED)
- Write failing unit tests: UT-{ids}

### 2. IMPLEMENT (GREEN)
- Write minimal code to pass tests

### 3. VERIFY
- Run integration tests: INT-{ids}
```

## Key Design Patterns

### Sequential Thinking Templates

16+ templates organized into groups:
- **T1-T3:** Problem Decomposition
- **T4-T6:** Codebase Analysis
- **T7-T10:** Architecture Design
- **T11-T13:** Risk Assessment
- **T14-T16:** Plan Validation
- **T-RISK-1 to T-RISK-3:** Test Risk Analysis (NEW)

Templates are in `templates/sequential-thinking-templates.md`.

### MPA (Multi-Perspective Analysis)

Architecture design uses 3 parallel specialist agents:
- Minimal Change approach
- Clean Architecture approach
- Pragmatic Balance approach

### Configuration

All limits, thresholds, and settings are in `config/planning-config.yaml`.

## Agents

### Planning Agents (Phases 2-4)

| Agent | Purpose |
|-------|---------|
| `product-planning:code-explorer` | Codebase patterns and integration points |
| `product-planning:software-architect` | Architecture options and trade-offs |
| `product-planning:tech-lead` | Task breakdown and complexity analysis |
| `product-planning:researcher` | Technology research and unknowns |

### QA Agents (Phase 7 - MPA Pattern)

| Agent | Purpose | Modes |
|-------|---------|-------|
| `product-planning:qa-strategist` | V-Model test strategy, UAT scripts | All |
| `product-planning:qa-security` | Security testing, STRIDE analysis, auth tests | Complete, Advanced |
| `product-planning:qa-performance` | Performance/load testing, latency requirements | Complete, Advanced |

Phase 7 uses MPA (Multi-Perspective Analysis) pattern similar to Phase 4 architecture design.

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture design |
| `plan.md` | Implementation plan |
| `tasks.md` | Task breakdown (TDD-structured) |
| `research.md` | Codebase analysis findings |
| `test-plan.md` | V-Model test strategy |
| `test-cases/unit/` | Unit test specifications |
| `test-cases/integration/` | Integration test specs |
| `test-cases/e2e/` | E2E scenario scripts |
| `test-cases/uat/` | UAT scripts (Given-When-Then) |

## File Naming Conventions

- Agents: `agents/{role}.md`
- Skills: `skills/{skill-name}/SKILL.md`
- Reference files: `skills/{skill-name}/references/*.md`
- Templates: `templates/{purpose}.md`
- State: `{FEATURE_DIR}/.planning-state.local.md`

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in commands and agents.

## MCP Dependencies

Optional but recommended:
- `mcp__sequential-thinking__sequentialthinking` - Structured reasoning
- `mcp__pal__thinkdeep` - External model insights
- `mcp__pal__consensus` - Multi-model validation

---

## Development Guidelines

### Architecture Decisions

#### Integration over Separation
- **Pattern**: Embed tightly-coupled functionality as phases within a single workflow rather than separate skills
- **Rationale**: Separate skills for coupled workflows create state synchronization issues and user friction
- **Example**: Test planning (Phases 7-8) is embedded in main `/plan` skill, not a separate `/plan-tests`
- **Anti-pattern**: Creating separate skills that share state files and must be run in sequence

#### MPA Pattern Extensibility
- **Pattern**: Apply Multi-Perspective Analysis (MPA) to any phase requiring diverse viewpoints
- **Implementation**: Launch 2-3 specialized agents in parallel, synthesize their outputs
- **Applied to**: Phase 4 (architecture: minimal/clean/pragmatic) and Phase 7 (QA: general/security/performance)
- **Checklist**: When adding MPA, define: agent variants, mode availability, output synthesis rules

#### Phase Reconciliation
- **Pattern**: Multi-phase workflows with related analysis need explicit reconciliation steps
- **Example**: Phase 7 reconciles Phase 5 ThinkDeep security insights with test risk analysis
- **Implementation**: Create reconciliation step that maps prior findings to current phase, identifies gaps/conflicts
- **Output**: Reconciliation report showing alignment and flagging unresolved conflicts

### Configuration Management

#### Single Source of Truth
- **Rule**: Configurable values (thresholds, costs, model names) must exist in exactly one place
- **Location**: `config/planning-config.yaml` for this plugin
- **Anti-pattern**: Duplicating values in SKILL.md, CLAUDE.md, and config - causes drift
- **If displaying values**: Reference config file or note "See config for current values"

#### Threshold Semantics
- **Rule**: Always clarify boundary conditions using comparison operators
- **Format**: `GREEN: score >= 16`, `YELLOW: score >= 12 AND score < 16`, `RED: score < 12`
- **Anti-pattern**: Ambiguous statements like "RED <12" with separate `not_ready: 11` field

#### External Model Names
- **Note**: Model identifiers (gpt-5.2, gemini-3-pro-preview) are configurable placeholders
- **Rule**: Document that users should update these to match their PAL/MCP server configurations
- **Location**: Add configuration notes near model definitions

### Template Design

#### Glossary Sections
- **Rule**: Templates used by non-technical stakeholders (UAT scripts) must include glossary
- **Content**: Define domain terms (AC, TDD, Given-When-Then, Inner/Outer Loop)
- **Placement**: Appendix section at end of template

#### Template Completeness
- **Checklist for new templates**:
  - [ ] All placeholder sections have example content
  - [ ] Glossary for non-technical users
  - [ ] Evidence/sign-off sections where approval needed
  - [ ] Cross-references to related templates

### Quality Verification

#### Critique-Driven Improvements
When running `/reflexion:critique`, address findings by priority:
1. **Critical**: Duplicate files, missing reconciliation - fix immediately
2. **High**: Inconsistent constants, missing MPA - fix before release
3. **Medium**: Missing glossaries, unclear thresholds - fix in next iteration
4. **Low**: Style inconsistencies - batch fix periodically

#### Common Issues to Check
- [ ] No duplicate reference files across skills
- [ ] All config values sourced from single location
- [ ] MPA agents have mode availability documented
- [ ] Related phases have reconciliation steps
- [ ] Templates have glossaries for non-technical users

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Separate skills for coupled workflows | State sync issues, user must remember sequence | Embed as phases in single workflow |
| Duplicate reference files | Maintenance burden, drift risk | Single copy, reference via `$CLAUDE_PLUGIN_ROOT` |
| Hardcoded values in multiple files | Inconsistency, hard to update | Single source in config file |
| Missing phase reconciliation | Conflicting analysis, coverage gaps | Explicit reconciliation step between related phases |
| Templates without glossary | Non-technical users confused | Add glossary appendix |
| Ambiguous thresholds | Off-by-one errors, unclear logic | Use explicit comparison operators |

---

*Last updated: 2026-01-30 - Added development guidelines from V-Model integration critique*
