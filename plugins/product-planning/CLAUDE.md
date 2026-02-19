# CLAUDE.md

This file provides guidance to Claude Code when working with this plugin. Inherits repository-wide patterns from root `CLAUDE.md` (Lean Orchestrator, MPA, Configuration Management, State File Design, etc.).

> **Contributor rules** (phase file authoring, ST patterns, CLI roles, anti-pattern tables) are in `docs/contributor-guide.md` — read on-demand when modifying plugin internals.

## Plugin Overview

Plugin for feature planning, task decomposition, and **integrated test strategy generation** using SDD (Subagent-Driven Development) patterns with:
- **Multi-Perspective Analysis (MPA)** - Parallel agents with different focuses
- **PAL ThinkDeep** - External model insights (performance, maintainability, security)
- **PAL Consensus** - Multi-model validation with scoring rubric
- **CLI Dual-CLI Dispatch** - Gemini + Codex in parallel via Bash process-group dispatch
- **Sequential Thinking** - Structured reasoning templates
- **Research MCP Integration** - Context7/Ref/Tavily for authoritative documentation lookup
- **V-Model Test Planning** - Comprehensive test strategy aligned with development phases (integrated)
- **UAT Script Generation** - User story-based acceptance testing with Given-When-Then format
- **Asset Consolidation** - Identifies and catalogs all non-code assets needed for implementation
- **Dev-Skills Integration** - Subagent-delegated domain expertise injection from dev-skills plugin

## Plugin Testing

```bash
# Install locally for testing
claude plugins add ./plugins/product-planning
claude plugins enable product-planning

# Run the main workflow (includes test planning)
/product-planning:plan
```

## Architecture

### Workflow Phases (9 + Phases 6b, 8b)

The skill `skills/plan/SKILL.md` orchestrates a multi-phase workflow that includes both feature planning AND test strategy. The orchestrator delegates phases to coordinator subagents via `Task(general-purpose)`. Each coordinator reads a self-contained per-phase instruction file and communicates results through standardized summary files. See `skills/plan/references/orchestrator-loop.md` for dispatch logic.

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
│  Phase 6b: Expert Review (security gate)                         │
│       ↓                                                          │
│  Phase 7: Test Strategy (V-Model) ──────→ Unit Tests (TDD)      │
│       ↓                                                          │
│  Phase 8: Test Coverage Validation                               │
│       ↓                                                          │
│  Phase 8b: Asset Consolidation ─────────→ asset-manifest.md     │
│       ↓                                                          │
│  Phase 9: Task Generation & Completion ─→ tasks.md (TDD)        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Integrations:**
- Test planning (Phases 7-8) is embedded directly in the main workflow
- Task generation (Phase 9) uses test artifacts for TDD integration
- Phase 6b gates on security findings before proceeding to test strategy

### Phase Summary

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Setup | Initialize workspace, detect state, select analysis mode |
| 2 | Research | Codebase exploration, technology research |
| 3 | Clarification | User questions, gap resolution |
| 4 | Architecture | MPA design options (minimal/clean/pragmatic) |
| 5 | ThinkDeep | PAL multi-model insights (Complete/Advanced modes) |
| 6 | Validation | PAL Consensus plan validation |
| 6b | Expert Review | Security/quality gate, blocking on critical findings |
| 7 | Test Strategy | V-Model test planning, UAT generation |
| 8 | Test Coverage | Coverage validation, PAL Consensus |
| 8b | Asset Consolidation | Identify non-code assets, generate manifest, user validation |
| 9 | Task Generation | TDD-structured tasks with test refs, clarification loop |

### Analysis Mode Hierarchy

| Mode | Description | MCP Required |
|------|-------------|--------------|
| Complete | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes |
| Advanced | MPA + ThinkDeep (6) + Test Plan | Yes |
| Standard | MPA only + Basic Test Plan | No |
| Rapid | Single agent + Minimal Test Plan | No |

See `config/planning-config.yaml` for cost estimates, `analysis_modes`, and `blessed_profiles`.

The plugin gracefully degrades when MCP tools are unavailable.

### PAL ThinkDeep Integration

Phase 5 executes multi-model analysis across perspectives:
- **Performance** - Scalability, latency, resource efficiency
- **Maintainability** - Code quality, extensibility, technical debt
- **Security** - Threat modeling, compliance, vulnerabilities

Models are configurable in `config/planning-config.yaml` — update to match your PAL/MCP server.

### PAL Consensus Validation

**Phase 6 (Plan):** 20 points across 5 dimensions (Problem Understanding, Architecture Quality, Risk Mitigation, Implementation Clarity, Feasibility). See `config/planning-config.yaml` for thresholds and weights.

**Phase 8 (Test Coverage):** 100% across 5 dimensions (AC Coverage, Risk Coverage, UAT Completeness, Test Independence, Maintainability). See `config/planning-config.yaml` for thresholds and weights.

### State Management

State is persisted in `{FEATURE_DIR}/.planning-state.local.md` (YAML frontmatter + markdown). The workflow is resumable — user decisions are immutable and never re-asked.

Checkpoints: SETUP → RESEARCH → CLARIFICATION → ARCHITECTURE → THINKDEEP → VALIDATION → EXPERT_REVIEW → TEST_STRATEGY → TEST_COVERAGE_VALIDATION → ASSET_CONSOLIDATION → COMPLETION

State file version 2 adds `phase_summaries` tracking and `orchestrator` metadata. v1 files are auto-migrated on resume.

### Dev-Skills Loading by Phase

When dev-skills plugin is installed, coordinators load domain expertise via subagent delegation (Complete/Advanced/Standard modes only). See `config/planning-config.yaml` `dev_skills_integration:` for mappings and budgets.

| Phase | Skills Loaded | Token Budget |
|-------|---------------|-------------|
| 2 | accessibility, mobile, figma | 2500 |
| 4 | api-patterns, database, c4, mermaid, frontend | 3000 |
| 6b | clean-code, api-security | 2000 |
| 7 | qa-test-planner, accessibility | 2000 |
| 9 | clean-code | 800 |

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

25+ templates in `templates/sequential-thinking-templates.md`, organized into groups:
- **T1-T3:** Problem Decomposition
- **T4-T6:** Codebase Analysis
- **T7-T10 / T7a-T8:** Architecture Design (linear + fork-join)
- **T11-T13:** Risk Assessment
- **T14-T16:** Plan Validation
- **T-RISK series:** Test Risk Analysis (including revision and red-team branching)
- **T-AGENT series:** TAO Loop (structured synthesis pause)
- **T-EXTENSION:** Dynamic chain extension

For advanced ST patterns (fork-join, revision, red team, TAO loop), see `docs/contributor-guide.md`.

### MPA (Multi-Perspective Analysis)

Architecture design (Phase 4) uses 3 parallel specialist agents:
- Minimal Change approach
- Clean Architecture approach
- Pragmatic Balance approach

Phase 7 QA uses the same MPA pattern with security/performance specialists.

### Configuration

All limits, thresholds, and settings are in `config/planning-config.yaml`.

## Agents

### Planning Agents (Phases 2-4)

| Agent | File | Purpose |
|-------|------|---------|
| `code-explorer` | `agents/code-explorer.md` | Codebase patterns and integration points |
| `software-architect` | `agents/software-architect.md` | Architecture options and trade-offs |
| `tech-lead` | `agents/tech-lead.md` | Task breakdown and complexity analysis |
| `researcher` | `agents/researcher.md` | Technology research and unknowns |
| `flow-analyzer` | `agents/flow-analyzer.md` | User flow and interaction analysis |

### QA Agents (Phase 7 - MPA Pattern)

| Agent | File | Purpose | Modes |
|-------|------|---------|-------|
| `qa-strategist` | `agents/qa-strategist.md` | V-Model test strategy, UAT scripts | All |
| `qa-security` | `agents/qa-security.md` | Security testing, STRIDE analysis | Complete, Advanced |
| `qa-performance` | `agents/qa-performance.md` | Performance/load testing | Complete, Advanced |

### Reviewer Agents (Phase 6b)

| Agent | File | Purpose |
|-------|------|---------|
| `simplicity-reviewer` | `agents/reviewers/simplicity-reviewer.md` | Code simplicity and over-engineering |
| `security-analyst` | `agents/reviewers/security-analyst.md` | Security threat analysis |

### Judge Agents (Gates)

| Agent | File | Purpose |
|-------|------|---------|
| `phase-gate-judge` | `agents/judges/phase-gate-judge.md` | Phase gate scoring and pass/fail |
| `debate-judge` | `agents/judges/debate-judge.md` | Multi-agent debate evaluation |
| `architecture-pruning-judge` | `agents/judges/architecture-pruning-judge.md` | Architecture option pruning |

### Specialist Agents

| Agent | File | Purpose |
|-------|------|---------|
| `tech-writer` | `agents/tech-writer.md` | Documentation generation |
| `learnings-researcher` | `agents/learnings-researcher.md` | Cross-session learning extraction |
| `wildcard-architect` | `agents/explorers/wildcard-architect.md` | Unconventional architecture exploration |

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture design |
| `plan.md` | Implementation plan |
| `tasks.md` | Dependency-ordered tasks with TDD structure and test refs |
| `research.md` | Codebase analysis findings |
| `test-plan.md` | V-Model test strategy |
| `test-cases/unit/` | Unit test specifications |
| `test-cases/integration/` | Integration test specs |
| `test-cases/e2e/` | E2E scenario scripts |
| `test-cases/uat/` | UAT scripts (Given-When-Then) |
| `asset-manifest.md` | Non-code asset manifest (Phase 8b, optional) |
| `.phase-summaries/*.md` | Inter-phase coordinator summary files |

## File Naming Conventions

- Agents: `agents/{role}.md` or `agents/{category}/{role}.md` (categories: `reviewers/`, `judges/`, `explorers/`)
- Skills: `skills/{skill-name}/SKILL.md`
- Reference files: `skills/{skill-name}/references/*.md`
- Templates: `templates/{purpose}.md`
- CLI roles: `templates/cli-roles/{cli}_{role}.txt`
- State: `{FEATURE_DIR}/.planning-state.local.md`

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in agents and skills.

## MCP Dependencies

### Core MCP (Optional but recommended)
- `mcp__sequential-thinking__sequentialthinking` - Structured reasoning
- `mcp__pal__thinkdeep` - External model insights
- `mcp__pal__consensus` - Multi-model validation
- `mcp__pal__listmodels` - Model availability check
- `mcp__pal__challenge` - Groupthink detection

### Research MCP (Optional but recommended)
Used in Phases 2, 4, and 7 for authoritative documentation lookup.

| Server | Purpose | Best For |
|--------|---------|----------|
| `mcp__context7__query-docs` | Library documentation | React, Next.js, mainstream libs |
| `mcp__Ref__ref_search_documentation` | Docs with prose | Explanations, niche/private repos |
| `mcp__Ref__ref_read_url` | Read specific URLs | Changelogs, blog posts |
| `mcp__tavily__tavily_search` | Web search | News, CVEs, recent updates |
| `mcp__tavily__tavily_extract` | Extract URL content | Full page extraction |

**Server Selection Decision Tree:**
- Library API (mainstream) → Context7
- Library API (niche/prose needed) → Ref
- Current events/news → Tavily
- Security CVE check → Tavily
- Deep dive specific URL → Ref

**Reference:** `skills/plan/references/research-mcp-patterns.md`

---

*Last updated: 2026-02-19 — CLAUDE.md audit: fixed Phase 6b omission, expanded agent inventory to 16, removed hardcoded thresholds, extracted contributor guidelines to `docs/contributor-guide.md`*
