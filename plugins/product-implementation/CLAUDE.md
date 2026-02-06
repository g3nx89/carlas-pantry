# product-implementation CLAUDE.md

Plugin-specific guidance for Claude Code when working in this plugin.

## Plugin Purpose

Executes feature implementation plans produced by product-planning. Orchestrates TDD cycles, code generation, quality review, and documentation against an approved plan.

## Workflow Chain Position

Product Definition (PRD, spec) → Product Planning (design, plan, tasks, test-plan) → **Product Implementation** (code, tests, docs)

## Architecture

### 5-Stage Workflow

| Stage | Name | Dispatch | Agent(s) |
|-------|------|----------|----------|
| 1 | Setup & Context Loading | Inline | None (orchestrator) |
| 2 | Phase-by-Phase Execution | Coordinator | developer (per phase) |
| 3 | Completion Validation | Coordinator | developer |
| 4 | Quality Review | Coordinator | 3x developer (parallel) |
| 5 | Feature Documentation | Coordinator | developer + tech-writer |

### Agent Assignments

- **developer** (`agents/developer.md`): model=opus — implementation, testing, validation, code review
- **tech-writer** (`agents/tech-writer.md`): model=sonnet — feature documentation, API guides, architecture updates

### Key Files

- `skills/implement/SKILL.md` — Lean orchestrator dispatch table (entry point)
- `skills/implement/references/orchestrator-loop.md` — Dispatch loop, crash recovery, state migration
- `skills/implement/references/stage-{1-5}-*.md` — Stage-specific coordinator instructions
- `skills/implement/references/agent-prompts.md` — All agent prompt templates
- `config/implementation-config.yaml` — Single source of truth for configurable values
- `templates/implementation-state-template.local.md` — State file schema (v2)
- `templates/stage-summary-template.md` — Inter-stage summary contract

### Required Input Artifacts

The implement skill expects these files in the feature directory (produced by product-planning):
- `tasks.md` (required) — phased task list with acceptance criteria
- `plan.md` (required) — implementation plan
- `spec.md`, `design.md`, `data-model.md`, `contracts.md`, `research.md`, `test-plan.md` (optional)

### Legacy Commands

`commands/04-implement.md` and `commands/05-document.md` are superseded by the implement skill. They are retained for reference but should not be used directly.

## Development Notes

- All configurable values (lock timeout, severity definitions, review focus areas) live in `config/implementation-config.yaml` — never hardcode in SKILL.md or references
- Severity definitions (critical/high/medium/low) are canonical in the config file; SKILL.md references them but does not redefine
- State file is versioned (currently v2); any schema changes must include migration logic in `orchestrator-loop.md`
- The 3 quality reviewers in Stage 4 have distinct focus areas defined in config; do not merge or change their specializations without updating the config
