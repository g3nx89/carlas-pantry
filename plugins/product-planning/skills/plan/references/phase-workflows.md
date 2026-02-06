# Phase Workflows Index

> This file is an index only. Detailed instructions for each phase are in
> separate per-phase files. The orchestrator dispatches coordinators that
> read individual phase files — it never loads this entire index.

## Phase File Registry

| Phase | File | ~Lines | Delegation | Description |
|-------|------|--------|------------|-------------|
| 1 | phase-1-setup.md | 175 | Inline | Setup, MCP check, mode selection |
| 2 | phase-2-research.md | 371 | Coordinator | Research, code exploration, flow analysis |
| 3 | phase-3-clarification.md | 70 | Conditional | User questions, gap resolution |
| 4 | phase-4-architecture.md | 386 | Coordinator | MPA/ToT architecture design |
| 5 | phase-5-thinkdeep.md | 161 | Coordinator | Multi-model analysis |
| 6 | phase-6-validation.md | 194 | Coordinator | PAL Consensus / S6 debate |
| 6b | phase-6b-expert-review.md | 122 | Coordinator | Security + simplicity review |
| 7 | phase-7-test-strategy.md | 439 | Coordinator | V-Model test planning (MPA) |
| 8 | phase-8-coverage.md | 144 | Coordinator | Coverage validation |
| 9 | phase-9-completion.md | 572 | Coordinator | Task generation, completion |

## Cross-Reference: Existing Reference Files Used by Phases

| Reference File | Used By Phases |
|----------------|---------------|
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
| orchestrator-loop.md | Orchestrator (SKILL.md) |

## Reading Guide

- **Orchestrator** reads SKILL.md + orchestrator-loop.md + summary files
- **Coordinators** read their single phase file + prior summaries + artifacts
- **This index** is for human navigation only
