# Product Planning Plugin

Transform specifications into actionable implementation plans, tasks, and test strategies using SDD patterns with V-Model testing methodology.

## Overview

- **Transforms** specifications into implementation plans and dependency-ordered tasks
- **Uses V-Model methodology** for integrated test planning (Unit, Integration, E2E, UAT)
- **Provides 4 analysis modes** from rapid single-agent to full multi-model consensus
- **Supports 9-phase workflow** with parallel Multi-Perspective Analysis (MPA)
- **Integrates Research MCP** for authoritative documentation lookup
- **Degrades gracefully** when MCP tools are unavailable

## Quick Start

1. Create feature branch: `git checkout -b feature/001-my-feature`
2. Ensure specs exist in `specs/001-my-feature/` (spec.md, plan.md)
3. Run: `/product-planning:plan`
4. Review generated artifacts (tasks.md, test-plan.md, design.md)

## Installation

### From Local Directory
```bash
claude plugins add /path/to/product-planning
```

### Enable the Plugin
```bash
claude plugins enable product-planning
```

## Skills

### /product-planning:plan
Main skill orchestrating 9-phase workflow including test strategy and task generation.

**Phases:**
1. Setup - Initialize workspace, detect state
2. Research - Codebase exploration, technology research
3. Clarification - User questions, gap resolution
4. Architecture - MPA design options (minimal/clean/pragmatic)
5. ThinkDeep - PAL multi-model insights
6. Validation - PAL Consensus plan validation
7. Test Strategy - V-Model test planning, UAT generation
8. Test Coverage - Coverage validation
9. **Task Generation & Completion** - TDD-structured task breakdown with full test integration

### /product-planning:tasks (Deprecated)
**Deprecated in v2.0.0.** Task generation is now integrated into Phase 9 of `/plan`.
Running this command will redirect you to use `/plan` instead.

## Analysis Modes

| Mode | Description | MCP Required | Cost |
|------|-------------|--------------|------|
| Complete | MPA + ThinkDeep (9) + ST + Consensus | Yes | $0.80-1.50 |
| Advanced | MPA + ThinkDeep (6) + Test Plan | Yes | $0.45-0.75 |
| Standard | MPA only + Basic Test Plan | No | $0.15-0.30 |
| Rapid | Single agent + Minimal Test Plan | No | $0.05-0.12 |

## Directory Structure

```
specs/
├── constitution.md
└── {FEATURE_NAME}/
    ├── spec.md, plan.md (input)
    ├── design.md, tasks.md, test-plan.md (output)
    ├── test-cases/ (unit/, integration/, e2e/, uat/)
    └── .planning-state.local.md (state)
```

## V-Model Test Planning

| Development Phase | Test Level | Loop | Executor |
|------------------|------------|------|----------|
| Requirements | UAT | Outer | Product Owner |
| Architecture | E2E | Outer | QA / Automation |
| Design | Integration | Inner | CI Pipeline |
| Implementation | Unit | Inner | CI Pipeline (TDD) |

## MCP Dependencies

| MCP Server | Purpose | Fallback |
|------------|---------|----------|
| sequential-thinking | Structured reasoning | Standard reasoning |
| pal (thinkdeep) | Multi-model insights | Single-model analysis |
| pal (consensus) | Multi-model validation | Skip validation |
| context7/Ref/tavily | Documentation lookup | Manual research |

## Plugin Components

### Agents (10)

| Agent | Purpose | Model |
|-------|---------|-------|
| software-architect | Architecture blueprints | opus |
| tech-lead | Task breakdown | opus |
| code-explorer | Codebase analysis | opus |
| researcher | Technology research | sonnet |
| tech-writer | Documentation | sonnet |
| qa-strategist | V-Model test strategy | sonnet |
| qa-security | Security testing | sonnet |
| qa-performance | Performance testing | sonnet |
| flow-analyzer | User flow analysis | sonnet |
| learnings-researcher | Pattern extraction | haiku |

*Note: Agent files in `agents/` are the authoritative source for model assignments.*

### Templates (10)
- **tasks-template** - TDD-structured task breakdown
- planning-state, test-plan, uat-script, github-issue
- user-flow-analysis, judge-report, debate-round
- learnings-schema, sequential-thinking-templates

## Configuration

See `config/planning-config.yaml` for:
- Analysis mode parameters
- Validation thresholds (Plan: GREEN >= 16, Test: GREEN >= 80%)
- Sequential Thinking template groups
- Research MCP selection rules

## Troubleshooting

**Lock file exists:** `rm specs/{FEATURE}/.planning-lock`
**State corruption:** `rm specs/{FEATURE}/.planning-state.local.md`
**MCP unavailable:** Plugin auto-degrades to Standard/Rapid

## Version
2.0.0

### Changelog (v2.0.0)
- **Integrated task generation** - Phase 9 now includes full task breakdown with TDD structure
- **Deprecated /tasks command** - Use /plan for complete workflow
- **Added tasks-template.md** - Standard template for task breakdown output
- **Enhanced tech-lead context** - Agent receives all test artifacts for TDD integration

## License
MIT
