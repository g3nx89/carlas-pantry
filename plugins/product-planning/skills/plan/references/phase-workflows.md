# Phase Workflows Index

> This file is an index only. Detailed instructions for each phase are in
> separate per-phase files. The orchestrator dispatches coordinators that
> read individual phase files — it never loads this entire index.

## Phase File Registry

| Phase | File | ~Lines | Delegation | Description |
|-------|------|--------|------------|-------------|
| 1 | phase-1-setup.md | ~486 | Inline | Setup, MCP check, mode selection |
| 2 | phase-2-research.md | ~455 | Coordinator | Research, code exploration, flow analysis |
| 3 | phase-3-clarification.md | ~215 | Conditional | User questions, gap resolution |
| 4 | phase-4-architecture.md | ~545 | Coordinator | MPA/ToT architecture design |
| 5 | phase-5-thinkdeep.md | ~170 | Coordinator | Multi-CLI deep analysis |
| 6 | phase-6-validation.md | ~277 | Coordinator | CLI Consensus Scoring / S6 debate |
| 6b | phase-6b-expert-review.md | ~315 | Coordinator | Security + simplicity review |
| 7 | phase-7-test-strategy.md | ~640 | Coordinator | V-Model test planning (MPA) |
| 8 | phase-8-coverage.md | ~162 | Coordinator | Coverage validation |
| 8b | phase-8b-asset-consolidation.md | ~256 | Coordinator | Asset discovery, manifest generation |
| 9 | phase-9-completion.md | ~695 | Coordinator | Task generation, completion |
| 10 | phase-10-retrospective.md | ~280 | Coordinator | Planning retrospective, KPI report card |

## Cross-Reference: Existing Reference Files Used by Phases

| Reference File | Used By Phases |
|----------------|---------------|
| orchestrator-loop.md | Orchestrator (SKILL.md) |
| cli-dispatch-pattern.md | 5, 6, 6b, 7, 9 |
| skill-loader-pattern.md | 2, 4, 6b, 7, 9 |
| deep-reasoning-dispatch-pattern.md | Gate failures, 6b |
| mpa-synthesis-pattern.md | 4, 7 |
| tot-workflow.md | 4 |
| adaptive-strategy-logic.md | 4 |
| debate-protocol.md | 6 |
| research-mcp-patterns.md | 2, 4, 7 |
| v-model-methodology.md | 7 |
| coverage-validation-rubric.md | 8 |
| validation-rubric.md | 6 |
| self-critique-template.md | All agents |
| cot-prefix-template.md | All agents |
| judge-gate-rubrics.md | 4, 7 (gates) |
| thinkdeep-prompts.md | 5 |

## Reading Guide

- **Orchestrator** reads SKILL.md + orchestrator-loop.md + summary files
- **Coordinators** read their single phase file + prior summaries + artifacts
- **This index** is for human navigation only
