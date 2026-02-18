# product-implementation CLAUDE.md

Plugin-specific guidance for Claude Code when working in this plugin.

## Plugin Purpose

Executes feature implementation plans produced by product-planning. Orchestrates TDD cycles, code generation, quality review, and documentation against an approved plan.

## Workflow Chain Position

Product Definition (PRD, spec) → Product Planning (design, plan, tasks, test-plan) → **Product Implementation** (code, tests, docs)

## Architecture

### 6-Stage Workflow

| Stage | Name | Dispatch | Agent(s) |
|-------|------|----------|----------|
| 1 | Setup & Context Loading | Inline | None (orchestrator) |
| 2 | Phase-by-Phase Execution | Coordinator | developer + code-simplifier + uat-tester (per phase, CLI/gemini) |
| 3 | Completion Validation | Coordinator | developer |
| 4 | Quality Review | Coordinator | 3x+ developer (parallel, conditionally extended) |
| 5 | Feature Documentation | Coordinator | developer + tech-writer |
| 6 | Implementation Retrospective | Coordinator | tech-writer |

### Agent Assignments

- **developer** (`agents/developer.md`): model=opus — implementation, testing, validation, code review
- **code-simplifier** (`agents/code-simplifier.md`): model=opus — post-phase code simplification for clarity and maintainability (Stage 2, optional via config)
- **tech-writer** (`agents/tech-writer.md`): model=sonnet — feature documentation, API guides, architecture updates

### Key Files

- `skills/implement/SKILL.md` — Lean orchestrator dispatch table (entry point)
- `skills/implement/references/orchestrator-loop.md` — Dispatch loop, crash recovery, state migration
- `skills/implement/references/stage-{1-6}-*.md` — Stage-specific coordinator instructions
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
- Code simplification runs after each phase in Stage 2 (Step 3.5) when `code_simplification.enabled` is `true` in config. The simplifier never modifies test files and automatically rolls back if tests fail. Configuration lives in `config/implementation-config.yaml` under `code_simplification`
- UAT mobile testing runs after each relevant phase in Stage 2 (Step 3.7) when both `uat_execution.enabled` and `cli_dispatch.stage2.uat_mobile_tester.enabled` are `true`. Requires Genymotion emulator running + mobile-mcp MCP server + Gemini CLI. Configuration lives in `config/implementation-config.yaml` under `uat_execution` and `cli_dispatch.stage2.uat_mobile_tester`. Role prompt in `config/cli_clients/gemini_uat_mobile_tester.txt`
- Autonomy policy (`autonomy_policy` in config) controls how findings/failures are auto-resolved. Three levels: `full_auto` (fix everything), `balanced` (fix critical/high, defer medium), `critical_only` (fix only critical). Selected at Stage 1 startup via AskUserQuestion (or skipped if `default_level` is set). Policy flows through Stage 1 summary to all stages. Auto-resolved decisions are logged with `[AUTO-{policy}]` prefix. If auto-resolution fails, the system falls through to standard user escalation.
- Stage 6 (Retrospective) runs post-lock-release as read-only analysis. It produces two artifacts: `.implementation-report-card.local.md` (machine-readable KPI Report Card) and `retrospective.md` (narrative document). Both are excluded from auto-commit except the retrospective itself. Configuration lives in `config/implementation-config.yaml` under `retrospective`.

## Retrospective & KPI (Stage 6)

Stage 6 generates a comprehensive implementation retrospective using a three-layer architecture:

- **Data Layer**: KPI Report Card compiled inline from state file + stage summaries (10 Phase 1 KPIs)
- **Behavior Layer**: Session transcript extraction via throwaway subagent (streaming Python script on JSONL, conditional)
- **Presentation Layer**: Narrative retrospective composed by tech-writer agent from Report Card + transcript + summaries

### Key Constraints

- **Post-lock-release**: Stage 6 runs after Stage 5 releases the lock — no lock operations needed
- **Conditional transcript analysis**: Gated by `retrospective.transcript_analysis.enabled`; if disabled or transcript not found, retrospective is KPI-and-summary-only
- **Forward-compatible schema**: Report Card includes Phase 2 KPI fields as `null` placeholders
- **Section toggles**: Each retrospective section can be individually disabled via `retrospective.sections` in config
- **Local artifacts excluded**: `.implementation-report-card.local.md` and `transcript-extract.json` are excluded from auto-commit

### Configuration

- Master switch: `retrospective.enabled` (if `false`, Stage 6 writes minimal "skipped" summary)
- Transcript analysis: `retrospective.transcript_analysis.*` (enabled, transcript_dir, extraction caps)
- Section toggles: `retrospective.sections.*` (timeline, what_worked, what_didnt_work, etc.)
- Auto-commit: `auto_commit.message_templates.retrospective` + exclude patterns for report card and transcript extract

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

## UAT Mobile Testing Integration

When UAT is enabled and a Genymotion emulator is running with mobile-mcp available, Stage 2 runs per-phase behavioral acceptance testing and Figma visual verification against the running app after each relevant phase completes.

### Architecture (Orchestrator-Transparent)

The orchestrator NEVER touches UAT, mobile-mcp, or Figma. All logic lives in:

1. **Stage 1** (inline) probes `mobile_list_available_devices` to detect emulator availability → writes `mobile_mcp_available` and `mobile_device_name` to summary
2. **Stage 2** coordinator checks 5 gates (uat_execution enabled + uat_mobile_tester enabled + Gemini CLI available + mobile-mcp available + phase relevance), builds APK via Gradle, installs on emulator via mobile-mcp, dispatches Gemini CLI agent with UAT role prompt
3. **Stage 2 summary** writes `uat_results` (phases tested, pass/fail counts, visual mismatches, evidence directory) for implementation record

### Key Constraints

- **5 conditional gates**: `uat_execution.enabled` + `uat_mobile_tester.enabled` + `cli_availability.gemini` + `mobile_mcp_available` + phase has UAT specs or UI files — ANY false → silent skip
- **Fallback is "skip"**: If Gemini unavailable, mobile-mcp unreachable, no emulator, or build fails → UAT silently skipped, native behavior (no UAT) is default
- **Severity gating (policy-aware)**: UAT findings at critical/high severity are handled per autonomy policy — `full_auto`/`balanced` auto-fix or defer, `critical_only` auto-fixes only critical. When no policy applies, falls back to manual escalation (status: needs-user-input). Medium/low findings are always logged as warnings without blocking.
- **MEDIUM/LOW warn only**: Logged as warnings but do not block phase progression
- **Evidence stored**: Screenshots saved to `{FEATURE_DIR}/.uat-evidence/{phase_name}/` for traceability
- **Write boundaries**: CLI agent writes ONLY screenshots to evidence directory; never touches source/test/spec files
- **Phase relevance detection**: UAT runs only for phases with mapped UAT-* test IDs or task file paths matching UI domain indicators (compose, android, web_frontend)

### Configuration

- Master switches: `uat_execution.enabled` AND `cli_dispatch.stage2.uat_mobile_tester.enabled`
- Figma visual comparison: `cli_dispatch.stage2.uat_mobile_tester.figma.enabled` + `figma.default_node_url`
- Severity gating: `cli_dispatch.stage2.uat_mobile_tester.severity_gating` (block_on / warn_on)
- Gradle build: `cli_dispatch.stage2.uat_mobile_tester.gradle_build` (command, apk_search_pattern, timeout)
- MCP tool budgets: `cli_dispatch.mcp_tool_budgets.per_cli_dispatch.mobile_mcp` and `.figma`
- Emulator/install: `uat_execution.emulator` and `uat_execution.apk_install`
