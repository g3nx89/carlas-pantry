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
| 4 | Quality Review | Coordinator | 3x+ developer (parallel, conditionally extended) |
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
- `design.md`, `test-plan.md` (expected — warns if missing, does not halt)
- `spec.md`, `data-model.md`, `contract.md`, `research.md` (optional)
- `test-cases/` (optional) — test specifications by level (e2e, integration, unit, uat)
- `analysis/task-test-traceability.md` (optional) — task-to-test-case mapping

### Legacy Commands

`commands/04-implement.md` and `commands/05-document.md` are superseded by the implement skill. They are retained for reference but should not be used directly.

## Development Notes

- All configurable values (lock timeout, severity definitions, review focus areas) live in `config/implementation-config.yaml` — never hardcode in SKILL.md or references
- Severity definitions (critical/high/medium/low) are canonical in the config file; SKILL.md references them but does not redefine
- State file is versioned (currently v2); any schema changes must include migration logic in `orchestrator-loop.md`
- The 3 quality reviewers in Stage 4 have distinct focus areas defined in config; do not merge or change their specializations without updating the config
- Cross-plugin naming: product-planning produces `contract.md` (singular), `test-cases/uat/` (not `visual/`), and test IDs like `E2E-*`, `INT-*`, `UT-*`, `UAT-*` (no `TC-` prefix) — always verify against the source plugin before adding new artifact references
- Handoff contract values (expected files, test-case subdirectories, test ID patterns) are externalized in `config/implementation-config.yaml` under `handoff` — update config, not prose, when planning outputs change
- Agent prompt templates in `agent-prompts.md` must list variables explicitly per prompt — do not use "Same as X Prompt" shorthand, as coordinators fill only what's listed and omissions cause silent failures
- Stage 1 summary is the context bus for all later stages: Planning Artifacts Summary table + Context File Summaries + Test Specifications block. When adding new planning artifacts, add them to Stage 1's discovery and summary, not to individual coordinator stages
- After bulk reference file edits, update `references/README.md` line counts — stale counts mislead developers about file complexity
- After inserting a new numbered section in any stage file, grep all reference files for the old section numbers and update — cross-file section references (e.g., "Section 1.7") break silently when sections are renumbered
- When adding a new reference file: register in `references/README.md` (3 tables: usage, file sizes, cross-references) AND `SKILL.md` Reference Map — this wiring step is the most common omission when sessions exhaust context

## Dev-Skills Integration

When the `dev-skills` plugin is installed alongside `product-implementation`, agents receive conditional domain-specific skill references that enhance implementation quality with patterns, anti-patterns, and decision trees.

### Architecture (Orchestrator-Transparent)

The orchestrator NEVER reads or references dev-skills. All skill resolution happens inside coordinator subagents:

1. **Stage 1** (inline) detects technology domains from task file paths and plan.md content → writes `detected_domains` to summary
2. **Stage 2** coordinator reads `detected_domains`, resolves applicable skills from `config/implementation-config.yaml` `dev_skills` section, and populates `{skill_references}` in developer agent prompts
3. **Stage 4** coordinator adds conditional review dimensions (e.g., accessibility for UI projects) and injects skill references into reviewer prompts
4. **Stage 5** coordinator injects diagram and documentation skills into tech-writer prompts

### Key Constraints

- **Max 3 skills per dispatch** (configurable via `dev_skills.max_skills_per_dispatch`) — prevents context bloat
- **On-demand reading** — agents read skill SKILL.md files only when encountering relevant decisions, not upfront
- **Codebase conventions take precedence** — CLAUDE.md and constitution.md override skill guidance
- **Graceful degradation** — if dev-skills not installed, all injection is silently skipped (fallback text used)
- **Config-driven** — domain-to-skill mapping lives in `config/implementation-config.yaml`, not in prose

### Domain Detection Indicators

Domain indicators (file extensions, framework keywords) are defined in `config/implementation-config.yaml` under `dev_skills.domain_mapping`. Currently supported: `kotlin`, `compose`, `android`, `kotlin_async`, `web_frontend`, `api`, `database`, `gradle`.

### Conditional Quality Reviewers

Stage 4 can launch additional reviewer agents beyond the base 3 when `detected_domains` match entries in `dev_skills.conditional_review`. Example: `web_frontend` triggers an accessibility reviewer using `accessibility-auditor` skill.
