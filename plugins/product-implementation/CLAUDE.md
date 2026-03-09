# product-implementation CLAUDE.md

Plugin-specific guidance for Claude Code when working in this plugin.

## Plugin Purpose

Executes feature implementation plans produced by product-planning. Orchestrates TDD cycles, code generation, quality review, and documentation against an approved plan.

## Workflow Chain Position

Product Definition (PRD, spec) → Product Planning (design, plan, tasks, test-plan) → **Product Implementation** (code, tests, docs)

## Architecture

### Per-Phase Delivery Cycles (v3 Architecture)

When `per_phase_review.enabled` is `true` (default), stages 2-5 run per-phase inside a loop:
`S1a(inline) → S1b(coord) → FOR_EACH_PHASE[S2→S3→S4→S5→commit] → optional final S3+S4 → final S5 → S6`

When `per_phase_review.enabled` is `false`, the workflow falls back to linear: `S1a→S1b→S2→S3→S4→S5→S6`.

| Stage | Name | Dispatch | Agent(s) |
|-------|------|----------|----------|
| 1a | Setup & Context Loading | Inline | None (orchestrator) |
| 1b | Probes & Configuration | Coordinator | None (probes, config) |
| 2 | Phase-by-Phase Execution | Coordinator (per-phase) | test-writer + integration-test-writer + {vertical_agent_type} + output-verifier + code-simplifier + uat-tester (per phase, CLI/gemini) |
| 3 | Completion Validation | Coordinator (per-phase + final) | developer |
| 4 | Quality Review | Coordinator (per-phase + final) | 3x+ developer (parallel, conditionally extended) |
| 5 | Feature Documentation | Coordinator (per-phase + final) | developer + tech-writer + doc-judge |
| 6 | Implementation Retrospective | Coordinator | tech-writer |

### Agent Assignments

- **test-writer** (`agents/test-writer.md`): model=sonnet — unit test spec-to-test translation, Red phase TDD (Stage 2, Step 1.9)
- **integration-test-writer** (`agents/integration-test-writer.md`): model=sonnet — E2E/integration test specialist, wiring verification, flow testing (Stage 2, Step 1.9)
- **developer** (`agents/developer.md`): model=sonnet — generic implementation, testing, validation, code review (fallback vertical)
- **android-developer** (`agents/android-developer.md`): model=sonnet — Android/Kotlin/Compose specialist with baked-in domain skills (Stage 2 vertical)
- **frontend-developer** (`agents/frontend-developer.md`): model=sonnet — Frontend/web specialist with baked-in domain skills (Stage 2 vertical)
- **backend-developer** (`agents/backend-developer.md`): model=sonnet — Backend/API/database specialist with baked-in domain skills (Stage 2 vertical)
- **debugger** (`agents/debugger.md`): model=sonnet — systematic bug diagnosis via UNDERSTAND→REPRODUCE→ISOLATE→FIX (Stage 2 task override)
- **output-verifier** (`agents/output-verifier.md`): model=sonnet — output quality verification: empty test bodies, spec alignment, DoD compliance (Stage 2, Step 2.5)
- **code-simplifier** (`agents/code-simplifier.md`): model=sonnet — post-phase code simplification for clarity and maintainability (Stage 2, optional via config)
- **uat-tester** (`agents/uat-tester.md`): model=sonnet — UAT mobile testing via SAV loop, Figma visual parity (Stage 2, Step 3.7)
- **doc-judge** (`agents/doc-judge.md`): model=sonnet — documentation accuracy verification, LLM-as-a-judge (Stage 5, per-phase mode)
- **tech-writer** (`agents/tech-writer.md`): model=sonnet — feature documentation with static doc skills (mermaid, c4-architecture), API guides, architecture updates
- **test_augmenter (secondary)**: dual-model test gap analysis via dedicated script (`scripts/dispatch-test-augmenter.sh`) — Gemini discovers edge-case gaps, Codex verifies them; produces `.test-augmentation-{phase}.md` and `.test-augmentation-{phase}.draft.md` artifacts (Stage 2, optional via config)

### Key Files

- `skills/implement/SKILL.md` — Lean orchestrator dispatch table (entry point)
- `skills/implement/references/orchestrator-loop.md` — Dispatch loop, crash recovery, state migration
- `skills/implement/references/stage-1-setup.md` — Stage 1a inline setup instructions
- `skills/implement/references/stage-1b-probes.md` — Stage 1b coordinator: all probes, detection, configuration
- `skills/implement/references/stage-{2-6}-*.md` — Stage-specific coordinator instructions
- `skills/implement/references/agent-prompts.md` — All agent prompt templates
- `config/implementation-config.yaml` — Single source of truth for configurable values
- `templates/implementation-state-template.local.md` — State file schema (v3)
- `templates/stage-summary-template.md` — Inter-stage summary contract

### Required Input Artifacts

The implement skill expects these files in the feature directory (produced by product-planning):
- `tasks.md` (required) — phased task list with acceptance criteria
- `plan.md` (required) — implementation plan
- `design.md`, `test-plan.md` (expected — warns if missing, does not halt)
- `test-strategy.md` (optional — from specify's strategic test analysis: risks, testable ACs, journeys)
- `spec.md`, `data-model.md`, `contract.md`, `research.md` (optional)
- `test-cases/` (optional) — test specifications by level (e2e, integration, unit, uat)
- `analysis/task-test-traceability.md` (optional) — task-to-test-case mapping

### Legacy Commands

`commands/04-implement.md` and `commands/05-document.md` are superseded by the implement skill. They are retained for reference but should not be used directly.

## Stage 1 Split Architecture (v3.4.0)

Stage 1 is split into two parts to prevent LLM compliance degradation:
- **Stage 1a** (inline, ~280 lines): Branch parsing, file loading, tasks validation, lock, state init. Writes partial summary.
- **Stage 1b** (coordinator, ~600 lines): ALL probes (MCP, mobile, Figma, CLI), domain detection, project setup, autonomy policy, quality config. Reads partial summary, writes FULL Stage 1 summary.

The orchestrator validates the full summary via `VALIDATE_STAGE1_SUMMARY` (fail-closed gate) before proceeding. Missing probe fields cause HALT, not silent skip.

## Project Setup Analysis (Stage 1b Section 1.5b)

Stage 1 includes an optional project setup analysis phase that scans the target project and proposes Claude configuration improvements.

### Architecture (Subagent-Delegated)

Two throwaway subagents handle the heavy lifting; the orchestrator stays lean:

1. **Analysis subagent** (read-only): Scans `PROJECT_ROOT` for build system, languages, frameworks, test infrastructure, code quality tools, and existing Claude configuration. Cross-references with `plan.md` to produce targeted recommendations. Writes `.project-setup-analysis.local.md`.
2. **Generator subagent** (creates files): Based on user-selected categories, generates hook scripts, CLAUDE.md additions, and settings.json updates. Writes `.project-setup-proposal.local.md`.

### Key Constraints

- **Append-only**: NEVER overwrite existing hooks, CLAUDE.md content, MCP servers, or settings. Only add.
- **Backup before modify**: `.claude/settings.json.bak` created before settings changes (configurable).
- **Bash-compatible hooks**: Generated scripts use `#!/usr/bin/env bash`, work on macOS and Linux. All hooks that parse JSON input include jq availability check with graceful degradation.
- **User decides**: Orchestrator presents categorized recommendations via `AskUserQuestion` (multiSelect). Nothing auto-applied.
- **Skip on resume**: If `user_decisions.project_setup_applied` is `true` in state file, the entire section is skipped.
- **9 hook categories**: spec protection, language enforcement, TDD reminder, safety guards, commit format, code formatting, architecture boundaries, build output analysis, session context. Each independently toggleable in config.
- **Domain enrichment**: Analysis results (detected languages, frameworks) merge into Section 1.6 domain detection, upgrading `tentative` domains to `confident` when confirmed by actual project files.

### Configuration

- Master switch: `project_setup.enabled` (default: `true`)
- Skip re-analysis: `project_setup.skip_if_analyzed` (default: `true`)
- Analysis budget: `project_setup.analysis_budget.max_files_to_scan` (default: 50)
- Category toggles: `project_setup.categories.*` (claude_md, hooks, mcp_servers, code_quality)
- Hook category toggles: `project_setup.hooks.*` (9 categories)
- Backup: `project_setup.backup_settings_json` (default: `true`)
- Exclude from auto-commit: `.project-setup-analysis` and `.project-setup-proposal` patterns

## Development Notes

- All configurable values (lock timeout, severity definitions, review focus areas) live in `config/implementation-config.yaml` — never hardcode in SKILL.md or references
- Severity definitions (critical/high/medium/low) are canonical in the config file; SKILL.md references them but does not redefine
- State file is versioned (currently v3); any schema changes must include migration logic in `orchestrator-loop.md` (chain: v1→v2→v3)
- The 3 quality reviewers in Stage 4 have distinct focus areas defined in config; do not merge or change their specializations without updating the config
- Cross-plugin naming: product-planning produces `contract.md` (singular), `test-cases/uat/` (not `visual/`), and test IDs like `E2E-*`, `INT-*`, `UT-*`, `UAT-*` (no `TC-` prefix) — always verify against the source plugin before adding new artifact references
- Handoff contract values (expected files, test-case subdirectories, test ID patterns) are externalized in `config/implementation-config.yaml` under `handoff` — update config, not prose, when planning outputs change
- Agent prompt templates in `agent-prompts.md` must list variables explicitly per prompt — do not use "Same as X Prompt" shorthand, as coordinators fill only what's listed and omissions cause silent failures
- Stage 1 summary is the context bus for all later stages: Planning Artifacts Summary table + Context File Summaries + Test Specifications block. When adding new planning artifacts, add them to Stage 1's discovery and summary, not to individual coordinator stages
- After bulk reference file edits, update `references/README.md` line counts — stale counts mislead developers about file complexity
- After inserting a new numbered section in any stage file, grep all reference files for the old section numbers and update — cross-file section references (e.g., "Section 1.7") break silently when sections are renumbered
- When adding a new reference file: register in `references/README.md` (3 tables: usage, file sizes, cross-references) AND `SKILL.md` Reference Map — this wiring step is the most common omission when sessions exhaust context
- Code simplification runs after each phase in Stage 2 (Step 3.5) when `code_simplification.enabled` is `true` in config. The simplifier never modifies test files and automatically rolls back if tests fail. Configuration lives in `config/implementation-config.yaml` under `code_simplification`
- UAT mobile testing runs after each relevant phase in Stage 2 (Step 3.7) when `uat_execution.enabled` is `true` and `mobile_mcp_available` is `true`. Supports 3 engines: Claude subagent (native), Codex CLI, Gemini CLI — selected via `uat_execution.engine_strategy`. Full-sweep UAT runs in final Stage 3 (Section 3.2a). Configuration lives in `config/implementation-config.yaml` under `uat_execution`. System prompt in `scripts/uat/uat-system-prompt.md`
- Autonomy policy (`autonomy_policy` in config) controls how findings/failures are auto-resolved. Three levels: `full_auto` (fix everything), `balanced` (fix critical/high, defer medium), `critical_only` (fix only critical). Selected at Stage 1 startup via AskUserQuestion (or skipped if `default_level` is set). Policy flows through Stage 1 summary to all stages. Auto-resolved decisions are logged with `[AUTO-{policy}]` prefix. If auto-resolution fails, the system falls through to standard user escalation.
- Stage 6 (Retrospective) runs post-lock-release as read-only analysis. It produces two artifacts: `.implementation-report-card.local.md` (machine-readable KPI Report Card) and `retrospective.md` (narrative document). Both are excluded from auto-commit except the retrospective itself. Configuration lives in `config/implementation-config.yaml` under `retrospective`.
- CoVe (Chain-of-Verification) post-synthesis dispatches a throwaway subagent to verify Critical/High review findings against actual code (Stage 4, Section 4.3b). Opt-in via `quality_review.cove.enabled` in config. Only triggers when multi-tier review produces >= `min_findings_trigger` Critical+High findings.
- Reviewer stance assignment assigns advocate/challenger/neutral roles to base reviewers for calibrated scoring (Stage 4, Section 4.2). Opt-in via `quality_review.stances.enabled` in config. Stance divergence analysis flags findings where severity spread >= 2 levels across stances.
- Convergence detection measures inter-reviewer agreement via Jaccard similarity on technical keywords (Stage 4, Section 4.3a). Opt-in via `quality_review.convergence.enabled` in config. Adapts consolidation strategy (standard merge / weighted merge with divergence flags / present all for manual review).
- CLI circuit breaker tracks consecutive CLI dispatch failures across stages (Section 1.7b init, cli-dispatch-procedure.md gate). Opt-in via `cli_dispatch.circuit_breaker.enabled` in config. When threshold reached, circuit opens and dispatches skip directly to fallback.
- CLI dispatch script (`scripts/dispatch-cli-agent.sh`) supports `--model` and `--effort` flags for per-role model/effort overrides (e.g., `--model claude-sonnet-4-5 --effort high`). These are passed through from coordinator dispatch calls; defaults live in each `config/cli_clients/*.json` file.
- Stage 4 fix path uses the detected `vertical_agent_type` (from Stage 2 summary) when launching the native fix agent — ensures the same specialized vertical agent (android-developer, frontend-developer, backend-developer, or developer) applies fixes, not a generic fallback.
- Test augmenter artifacts (`.test-augmentation-*`) are excluded from auto-commit to keep feature commits clean. Add `.test-augmentation-` to `auto_commit.exclude_patterns` in config.
- Context pack protocol accumulates key decisions, open issues, and risk signals across stages (orchestrator-loop.md context pack builder). Opt-in via `context_protocol.enabled` in config. Each stage contributes `context_contributions` to its summary; the orchestrator compiles and injects a budget-controlled context pack into coordinator prompts.
- Per-phase delivery cycles (`per_phase_review.enabled` in config, default `true`) restructure the workflow from linear `S1→S2→S3→S4→S5→S6` to `S1 → FOR_EACH_PHASE[S2→S3→S4→S5→commit] → final passes → S6`. Each phase gets validated, reviewed, and documented before the next begins. Auto-commit moves from Stage 2 coordinator (Step 4.5) to orchestrator phase loop. Set `per_phase_review.enabled: false` to restore linear behavior.
- Doc-judge (LLM-as-a-judge, `doc_judge.enabled` in config) verifies documentation accuracy against actual code after each per-phase tech-writer dispatch (Stage 5 Section 5.2b). Catches hallucinated APIs, wrong signatures, and invented behaviors. One revision cycle on failure.

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

When the `dev-skills` plugin is installed alongside `product-implementation`, vertical developer agents use domain-specific skills via progressive disclosure — skills are baked into agent `.md` files, not injected at runtime.

### Architecture (Vertical Agents + Static Skills)

The orchestrator NEVER reads or references dev-skills. Skill knowledge is distributed:

1. **Stage 1** (inline) detects technology domains from task file paths and plan.md content → writes `detected_domains` to summary
2. **Stage 2** coordinator reads `detected_domains`, selects a vertical agent type (`android-developer`, `frontend-developer`, `backend-developer`, or generic `developer`) via priority-ordered matching in Section 2.0
3. **Vertical agents** have domain skills baked into their `.md` files with progressive disclosure protocol (read first 50 lines for decision framework, grep+targeted read on-demand)
4. **Stage 4** coordinator resolves conditional reviewers (e.g., accessibility for UI projects) from `dev_skills.conditional_review` config — triggers extra reviewer agent dispatches
5. **Tech-writer** and **test-writer** agents have static documentation/testing skills baked in — no coordinator skill injection needed

### Key Constraints

- **Progressive disclosure** — agents read skill SKILL.md files in 2 phases: first 50 lines for decision framework, then grep for specific sections on-demand. Never read entire skill files upfront
- **Shared core** — all developer-family agents (developer, android-developer, frontend-developer, backend-developer, debugger) read `references/developer-core-instructions.md` for shared engineering process, quality standards, and verification rules
- **Codebase conventions take precedence** — CLAUDE.md and constitution.md override skill guidance
- **Graceful degradation** — if dev-skills not installed, agents proceed without domain skills (no runtime failure)
- **Config-driven selection** — vertical agent mapping and domain indicators live in `config/implementation-config.yaml` under `dev_skills`
- **Task-level debugger override** — within a phase, tasks with debugging indicators dispatch `debugger` agent instead of the vertical developer
- **Test level split** — unit tests (UT-*) dispatch `test-writer`, e2e/integration tests (E2E-*/INT-*) dispatch `integration-test-writer`

### Vertical Agent Selection (Stage 2, Section 2.0)

| Domain(s) | Agent | Key Skills |
|-----------|-------|------------|
| android, compose, kotlin, kotlin_async, gradle | `android-developer` | kotlin-expert, compose-expert, android-expert |
| web_frontend | `frontend-developer` | frontend-design, accessibility-auditor |
| api, database | `backend-developer` | api-patterns, database-schema-designer |
| (fallback) | `developer` | clean-code |

### Domain Detection Indicators

Domain indicators (file extensions, framework keywords) are defined in `config/implementation-config.yaml` under `dev_skills.domain_mapping`. Currently supported: `kotlin`, `compose`, `android`, `kotlin_async`, `web_frontend`, `api`, `database`, `gradle`.

### Conditional Quality Reviewers

Stage 4 can launch additional reviewer agents beyond the base 3 when `detected_domains` match entries in `dev_skills.conditional_review`. Example: `web_frontend` triggers an accessibility reviewer using `accessibility-auditor` skill.

## Ralph Loop Integration (Autonomous Execution)

When invoked via `/product-implementation:ralph-implement`, the implement skill runs autonomously inside a ralph loop. The ralph-loop plugin's Stop Hook feeds the same prompt back on each session exit; the implement skill resumes from its checkpoint.

### Architecture (Outer Loop)

Ralph wraps the implement skill invocation (outer loop). The skill's checkpoint-based resume handles cross-iteration state persistence. Each ralph iteration gets a fresh context window.

1. **Stage 1** (inline) Section 1.0b detects `.claude/ralph-loop.local.md` → sets `ralph_mode: true`
2. **Orchestrator** AskUserQuestion guard auto-resolves all user prompts via autonomy policy
3. **Stall detection** compares state fingerprints across iterations; writes `.implementation-blockers.local.md` if stuck
4. **Completion signal**: `<promise>IMPLEMENTATION COMPLETE</promise>` after Stage 6

### Key Constraints

- **No user interaction**: ALL `AskUserQuestion` calls intercepted — auto-resolved with `[AUTO-ralph]` prefix
- **Pre-seeded config required**: `quality_preset`, `autonomy_policy.default_level`, `external_models` must be non-null (setup script applies `pre_seed_defaults` if needed)
- **Project setup skipped**: Section 1.5b requires interactive category selection — skipped in ralph mode
- **Crash recovery**: Retry once then continue (never abort, never ask user)
- **Graduated stall response**: 4-level progressive response (warn → write blockers → scope reduce/skip → halt). Configurable: `graduated` (default), `write_blockers` (legacy), `halt` (legacy)
- **Rate limit exemption**: API throttling/timeouts are exempt from stall counting — backoff + retry instead. Patterns configured in `circuit_breaker.rate_limit_patterns` and `timeout_patterns`
- **Output decline detection**: Summary length drops >70% compared to previous trigger stall count increment. Threshold: `circuit_breaker.output_decline_threshold`
- **Test result stall**: Identical Stage 3 test failures across iterations count toward `same_error_threshold`
- **Plan mutability**: At graduated Level 3, stuck tasks are annotated in tasks.md with HTML comments and phase is optionally skipped. Config: `ralph_loop.plan_mutability.*`
- **Status file**: Writes `.implementation-ralph-status.local.md` after each stage/phase transition for external monitoring. Config: `ralph_loop.status_file.*`

### Configuration

- Master switch: `ralph_loop.enabled`
- Iteration budget: `ralph_loop.iteration_budget.*` (per_phase_multiplier, stage budgets, safety margin)
- Circuit breaker: `ralph_loop.circuit_breaker.*` (no_progress_threshold, stall_action, graduated_levels, output_decline_threshold, rate_limit_backoff_seconds, rate_limit_patterns, timeout_patterns)
- Plan mutability: `ralph_loop.plan_mutability.*` (enabled, annotation_format, skip_blocked_phases)
- Status file: `ralph_loop.status_file.*` (enabled, filename)
- Completion promise: `ralph_loop.completion_promise`
- Pre-seed defaults: `ralph_loop.pre_seed_defaults.*` (quality_preset, autonomy_policy, external_models)
- Blockers excluded from auto-commit: `.implementation-blockers` pattern in `auto_commit.exclude_patterns`
- Status file excluded from auto-commit: `.implementation-ralph-status` pattern in `auto_commit.exclude_patterns`
- Cross-iteration learnings (`ralph_loop.learnings.enabled` in config, default `true`) capture fail→succeed deltas as operational learnings in `{FEATURE_DIR}/.implementation-learnings.local.md`. Stage 1 Section 1.0c reads the file and injects up to 10 recent entries into the summary. FIFO-capped at `max_entries` (default 20). Excluded from auto-commit (`.implementation-learnings` pattern).
- SAFE_ASK_USER (`orchestrator-loop.md` Helper) wraps all interactive AskUserQuestion calls with empty response validation (race condition with SessionStart hooks), option matching, and text-based fallback. Used by orchestrator needs-user-input relay, crash recovery, and Stage 1 inline calls (Sections 1.1, 1.5b, 1.9a, 1.9b). Bypassed entirely in ralph mode — the auto-resolve guard intercepts before SAFE_ASK_USER is reached. Ported from product-planning v1.3.0 post-mortem fix.
- Coordinator summary minimum content check (`orchestrator.min_summary_bytes` in config, default `50`) treats coordinator summaries smaller than the threshold as degraded output, triggering crash recovery. Prevents 0-byte or trivially short outputs from being accepted as valid summaries.
- Per-phase dispatch deduplication guard (`orchestrator-loop.md` Late Agent Notifications) prevents crash-recovery retries from racing with slow original dispatches in per-phase mode. Checks if the expected summary file was already written after the dispatch attempt started.

## UAT Mobile Testing Integration

Multi-engine acceptance testing with Figma visual verification. Supports 3 engines: Claude subagent (native), Codex CLI, Gemini CLI. Per-phase testing in Stage 2 (Step 3.7) and full-sweep validation in Stage 3 (Section 3.2a).

### Architecture (Orchestrator-Transparent)

The orchestrator NEVER touches UAT, mobile-mcp, or Figma. All logic lives in:

1. **Stage 1** (inline) probes `mobile_list_available_devices` to detect emulator availability → writes `mobile_mcp_available`, `mobile_device_name`, `engine_strategy` to summary. Pre-exports Figma reference PNGs via REST API (`scripts/uat/capture-figma-refs.sh`) when configured.
2. **Stage 2** coordinator checks 3 gates (uat_execution enabled + mobile_mcp available + phase relevance), selects engine per strategy, builds APK, installs on emulator, dispatches UAT agent (subagent or CLI script)
3. **Stage 3** (final pass only) runs full-sweep UAT across ALL user stories to catch cross-phase interaction bugs
4. Summaries write `uat_results` / `uat_sweep_results` for implementation record

### Engine Strategy

User selects at Stage 1 (or pre-configures in `uat_execution.engine_strategy`):

| Strategy | Per-Phase | Full-Sweep | Use Case |
|----------|-----------|------------|----------|
| `cli_only` | CLI | CLI | Consistent tooling, CLI available |
| `hybrid` | Claude subagent | CLI | **Recommended** — fast per-phase, high-confidence final |
| `subagent_only` | Claude subagent | Claude subagent | No external CLI, minimal dependency |

All strategies include automatic fallback: if CLI fails, fall back to Claude subagent (when `fallback_to_subagent` is `true`).

### Key Constraints

- **3 conditional gates**: `uat_execution.enabled` + `mobile_mcp_available` + phase has UAT specs or UI files — ANY false → skip. Claude subagent is always available, so CLI availability is not a gate.
- **Figma pre-export**: Reference PNGs exported via Figma REST API in Stage 1b (not runtime figma-console-mcp). Deterministic across phases.
- **Severity gating (policy-aware)**: Critical/high handled per autonomy policy. Medium/low logged as warnings without blocking.
- **Evidence stored**: Screenshots saved to `{FEATURE_DIR}/.uat-evidence/{phase_name}/` for traceability
- **Write boundaries**: UAT agent writes ONLY screenshots to evidence directory; never touches source/test/spec files
- **Phase relevance detection**: UAT runs only for phases with mapped UAT-* test IDs or task file paths matching UI domain indicators (compose, android, web_frontend)
- **Scripts are standalone**: `scripts/uat/run-uat.sh` and `scripts/uat/capture-figma-refs.sh` can be used independently outside the implement skill

### Configuration

- Master switch: `uat_execution.enabled`
- Engine strategy: `uat_execution.engine_strategy` (`cli_only` | `hybrid` | `subagent_only` | null=ask)
- CLI engine: `uat_execution.cli_engine` (`codex` | `gemini`)
- Figma references: `uat_execution.figma_references.*` (file_key, page_name, scale)
- Severity gating: `uat_execution.severity_gating` (block_on / warn_on)
- Gradle build: `uat_execution.gradle_build` (command, apk_search_pattern, timeout)
- MCP tool budgets: `cli_dispatch.mcp_tool_budgets.per_cli_dispatch.mobile_mcp` and `.figma`
- Emulator/install: `uat_execution.emulator` and `uat_execution.apk_install`

## CLI Instruction File Management

Stage 1b manages AGENTS.md (for Codex CLI) and GEMINI.md (for Gemini CLI) at PROJECT_ROOT via marker-based idempotent lifecycle. These files carry shared behavioral standards that each CLI natively loads on every invocation.

### Architecture

Source files (single source of truth) live in `config/cli_clients/shared/`:
- `cli-instruction-shared.md` — Universal content (output standards, severity classification)
- `codex-instruction-extra.md` — Codex-specific (parallelism, plan tool suppression)
- `gemini-instruction-extra.md` — Gemini-specific (context window usage)

Managed sections in AGENTS.md/GEMINI.md are delimited by `<!-- pi-codex-begin/end -->` and `<!-- pi-gemini-begin/end -->` markers. User content outside markers is preserved.

### Lifecycle (Section 1.7c)

| Target File | Marker | Condition |
|-------------|--------|-----------|
| AGENTS.md | `pi-codex` | File missing → create; marker missing → append; marker found → compare & update if changed |
| GEMINI.md | `pi-gemini` | Same logic |

### Configuration

- Master switch: `cli_dispatch.cli_instruction_files.enabled` (default: `true`)
- Per-file toggles: `agents_md.enabled`, `gemini_md.enabled`
- Shared content source and CLI-specific content source paths in config

### Key Constraints

- **Append-only**: Never overwrites user content outside managed markers
- **Idempotent**: Running twice produces "unchanged" status on second run
- **Defense-in-depth**: Role prompt `.txt` files retain Operating Mode and Exploration Strategy as primary source; AGENTS.md/GEMINI.md reinforce output standards and severity classification
- **Cleanup on uninstall**: To remove managed sections, delete content between `<!-- pi-codex-begin -->` and `<!-- pi-codex-end -->` markers in AGENTS.md (and similarly for GEMINI.md). If the file contains only the managed section, delete the entire file.
- **Skipped in ralph mode when instruction files already exist**: Section 1.7c checks for existing markers before modifying

## Protocol Compliance Enforcement (v3.5.0)

Defense-in-depth mechanisms to prevent LLM compliance degradation where the orchestrator silently bypasses the lean orchestrator pattern (direct agent dispatch, parallel phases, skipped specialized agents, ad-hoc prompts).

### Non-Overridable Gates

Five gates in `config/implementation-config.yaml` under `non_overridable_gates` that cannot be disabled by autonomy policy or full_auto mode:
- `sequential_phase_execution` — phases must run one-at-a-time, never in parallel
- `coordinator_mediated_dispatch` — all agents dispatch through coordinators, never directly from orchestrator
- `protocol_evidence_required` — Stages 2, 3, 4 must include `protocol_evidence` in summaries
- `app_launch_gate` — build+install+launch when emulator available (build failure blocks Stage 3)
- `prompt_template_usage` — agents must use templates from `agent-prompts.md`

### Protocol Evidence in Summaries

Stages 2-5 summaries include a `protocol_evidence` map documenting actual dispatch records:
- `agents_dispatched` — list of `{type, template_used, phase}` for each agent dispatch
- `prompt_templates_used` — template names from `agent-prompts.md`
- `phases_executed_sequentially` — boolean confirmation
- `per_phase_steps_completed` — map of phase → step IDs completed

Schema defined in `references/summary-schemas.md`. Template in `templates/stage-summary-template.md`.

### Pre-Summary Checklists

Shared checklist in `references/protocol-compliance-checklist.md` with universal + per-stage sections. Each stage file (2-5) cross-references it from their checklist section (2.2a, 3.4a, 4.4a, 5.3a). Stage 3 retains Check 15 (vertical slice wiring) inline since it has stage-specific detail.

### VERIFY_STAGE_PROTOCOL Function

Orchestrator-level verification in `orchestrator-loop.md` called from VALIDATE_AND_HANDLE after summary parsing:
- Checks `protocol_evidence` exists and is non-empty
- Validates required agents were dispatched (Stage 2: developer, test-writer, output-verifier; Stage 3: developer; Stage 4: 3+ reviewers; Stage 5: tech-writer)
- Detects parallel phase execution
- Detects missing prompt template usage
- **Remediation**: On first failure, re-dispatches the coordinator with explicit compliance instructions. On second failure, runs `scripts/verify_protocol.sh` for mechanical verification and proceeds with degraded output.
- Records violations in `state.orchestrator.protocol_violations` for Stage 6 retrospective

### Mechanical Verification Script

`scripts/verify_protocol.sh` — Bash script that parses stage summary YAML files to mechanically check for `protocol_evidence` fields. Breaks the LLM-checking-LLM trust boundary. Called by VERIFY_STAGE_PROTOCOL on second failure as a secondary check. Can also be run standalone: `verify_protocol.sh <feature_dir> [stage_number]`.

### Retrospective KPIs 1.6-1.10 (Outcome KPIs)

Stage 6 computes 5 additional outcome-based KPIs from `protocol_evidence`:
- **1.6 Protocol Compliance Score** — % of stages with valid protocol_evidence
- **1.7 Agent Diversity Score** — unique agent types dispatched vs. expected
- **1.8 Wiring Verification** — did vertical slice checks pass?
- **1.9 Build Success Rate** — builds attempted vs. succeeded
- **1.10 N/A Audit** — count of N/A values that had available tooling (should be 0)

Rule: "N/A ≠ GREEN" — any KPI marked N/A when tooling was available is a RED flag.

### Configuration

- Non-overridable gates: `config/implementation-config.yaml` under `non_overridable_gates`
- Prompt registry: `references/prompt-registry.yaml` (machine-readable template lookup)
- Critical Rules 13-15 in `SKILL.md` (no direct dispatch, sequential phases, prompt templates)
