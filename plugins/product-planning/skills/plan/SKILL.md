---
name: feature-planning
description: This skill should be used when the user asks to "plan a feature", "create an implementation plan", "design the architecture", "break down a feature into tasks", "decompose a specification", "plan development", "plan tests", or needs multi-perspective analysis for feature implementation. Provides 9-phase workflow with MPA agents, CLI deep analysis, V-Model test planning, and consensus scoring.
version: 3.0.0
allowed-tools:
  # File operations
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  # Shell commands
  - Bash(cp:*)
  - Bash(mkdir:*)
  - Bash(rm:*)
  - Bash(git:*)
  - Bash(ls:*)
  # Agent orchestration
  - Task
  - AskUserQuestion
  # Sequential Thinking MCP
  - mcp__sequential-thinking__sequentialthinking
  # CLI dispatch (Bash-based, replaces PAL MCP)
  - Bash(dispatch:*)
  # Research MCP - Context7 (library documentation)
  - mcp__context7__resolve-library-id
  - mcp__context7__query-docs
  # Research MCP - Ref (docs with prose, private repos)
  - mcp__Ref__ref_search_documentation
  - mcp__Ref__ref_read_url
  # Research MCP - Tavily (web search, news, current events)
  - mcp__tavily__tavily_search
  - mcp__tavily__tavily_extract
---

# Feature Planning Skill — Lean Orchestrator

> **Invoke:** `/product-planning:plan` or ask "plan this feature"

Transform feature specifications into actionable implementation plans with integrated test strategy. This orchestrator delegates phases to coordinator subagents, reading only standardized summary files between phases.

## Critical Rules

### Tier 1 — Architectural Invariants

1. **No User Interaction from Coordinators** — Coordinators NEVER call `AskUserQuestion` or prompt users directly. Set `status: needs-user-input` with `flags.block_reason` in the summary; the orchestrator mediates ALL user prompts.
2. **Orchestrator Summary-Only Context** — Read ONLY summary files from `{FEATURE_DIR}/.phase-summaries/` between phases. Never load raw phase artifacts (design.md, research.md) into orchestrator context.
3. **Delegation Protocol** — Dispatch all phases >=2 via `Task(subagent_type="general-purpose")` with a prompt pointing to the phase reference file. Run Phase 1 inline. Run Phase 3 inline for Standard/Rapid.
4. **Delegation over Inline Analysis** — Always delegate analysis to coordinator subagents. Never perform multi-step analysis inline in the orchestrator.

### Tier 2 — Operational Protocol

5. **Checkpoint after User Decisions** — Save user decisions to state immediately after receiving them. Never overwrite a saved user decision. When resuming, never re-ask questions already in `user_decisions`.
6. **Mode Selection** — Ask the user to choose an analysis mode before proceeding. Never default silently.
7. **Lock Protocol** — Acquire lock at start, release at completion. Treat locks older than `config.guards.lock_stale_timeout_minutes` (default 60) as stale.
8. **Config Reference** — Source all settings from `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml`. Never hardcode thresholds or limits.
9. **V-Model Alignment** — Map every acceptance criterion to a corresponding test. Flag untested criteria.
10. **Requirements Context Propagation** — Inject a requirements digest (~300 tokens from spec.md) into every coordinator dispatch prompt. Phase 3 produces `requirements-anchor.md` (spec + clarifications). Phases 5, 6, 6b read spec.md directly. See `config/planning-config.yaml` `requirements_context:` for budgets.

## Terminology

| Term | Definition |
|------|-----------|
| Phase | Numbered workflow step (1-10, plus 6b, 8b) |
| Coordinator | Dispatched subagent that executes a phase |
| Dispatch | Sending a coordinator via `Task(general-purpose)` with a phase prompt |
| Summary | 30-80 line result file written by coordinator to `.phase-summaries/` |
| Gate | Quality checkpoint scored by CLI Consensus (Phases 6, 8) |
| Orchestrator | This SKILL.md context — reads summaries, dispatches coordinators, mediates user interaction |
| Escalation | Deep reasoning dispatch triggered by repeated gate failure |

## Analysis Modes

| Mode | Description | MCP Required | Base Cost | With CLI |
|------|-------------|--------------|-----------|----------|
| **Complete** | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes | $1.00-1.80 | $1.30-2.50 |
| **Advanced** | MPA + ThinkDeep (6) + Test Plan | Yes | $0.55-0.95 | $0.70-1.10 |
| **Standard** | MPA only + Basic Test Plan | No | $0.15-0.30 | N/A |
| **Rapid** | Single agent + Minimal Test Plan | No | $0.05-0.12 | N/A |

Costs are base estimates without ST or CLI enhancements. See `config/planning-config.yaml` blessed profiles for full costs with all enhancements enabled.

### CLI Dispatch

| CLI | Analytical Lens | Phases |
|-----|----------------|--------|
| Gemini | Strategic / broad | 5, 6, 8 |
| Codex | Code-level / challenger | 5, 6, 8 |
| OpenCode | UX / product | 5, 6, 8 |

Script: `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-cli-agent.sh`

Complete/Advanced modes dispatch all three CLIs in parallel, then synthesize findings. Tri-CLI synthesis uses unanimous (VERY HIGH), majority (HIGH), and divergent (FLAG) confidence levels. Adds ~6-9 min total latency.

Graceful degradation: If CLIs are unavailable, fall back to Standard/Rapid modes (internal agents only). If ST is unavailable, fall back to Advanced mode.

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
│  │ Phase 5 │ Multi-CLI Deep Analysis ─────┼→ Integration    │   │
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
│  ┌──────────┐                                                   │
│  │ Phase 8b │ Asset Consolidation ──────→ asset-manifest.md     │
│  └────┬─────┘                                                   │
│       ↓                                                         │
│  ┌─────────┐                                                    │
│  │ Phase 9 │ Completion                                         │
│  └────┬────┘                                                    │
│       ↓                                                         │
│  ┌──────────┐                                                   │
│  │ Phase 10 │ Retrospective ──────────→ retrospective.md        │
│  └──────────┘                                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Latency Trade-off

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for ~78% orchestrator context reduction. For lightweight phases (Phase 3 in Standard/Rapid), inline execution avoids this overhead.

**Deep Reasoning Escalation** (Complete/Advanced, disabled by default): When gate retries exhaust (2 failures), the orchestrator can offer manual escalation to external deep reasoning models (GPT-5 Pro, Google Deep Think). User copies a CTCO prompt to the model's web interface, waits 3-15 min, and returns the result. Adds no API cost. See `references/deep-reasoning-dispatch-pattern.md` for the dispatch pattern and `config/planning-config.yaml` `deep_reasoning_escalation:` for feature flags.

## Phase Dispatch Table

| Phase | File | Prior Summaries | User Interaction | CLI | Checkpoint | Relevant Flags | Direct Artifact Reads | `∥` |
|-------|------|-----------------|------------------|-----|------------|----------------|-----------------------|-----|
| 1 | `phase-1-setup.md` | — | Mode selection | Detect | SETUP | `cli_*`, `dev_skills`, `deep_reasoning`, `s10_team` | — | — |
| 2 | `phase-2-research.md` | phase-1 | Gate failure only | — | RESEARCH | `a1_flow`, `a2_learnings`, `a3_adaptive`, `s3_judge`, `st_tao`, `dev_skills` | spec.md, constitution.md | — |
| 3 | `phase-3-clarification.md` | phase-2 | Questions (all) | — | CLARIFICATION | `s12_specify_gate` | spec.md, research.md | — |
| 4 | `phase-4-architecture.md` | phase-2, phase-3 | Select option | — | ARCHITECTURE | `s5_tot`, `s4_adaptive`, `s3_judge`, `st_fork_join`, `st_tao`, `dev_skills`, `deep_reasoning`, `s7_mpa`, `s8_convergence`, `s10_team` | spec.md, research.md | — |
| 5 | `phase-5-thinkdeep.md` | phase-4 | Review findings | deepthinker | THINKDEEP | `cli_*` | spec.md, design.md | — |
| 6 | `phase-6-validation.md` | phase-4, phase-5 | If YELLOW/RED | planreviewer | VALIDATION | `s6_debate`, `cli_*`, `deep_reasoning` | spec.md, plan.md, design.md | — |
| 6b | `phase-6b-expert-review.md` | phase-6 | Blocking security | securityauditor | EXPERT_REVIEW | `a4_expert`, `cli_*`, `dev_skills`, `deep_reasoning`, `s13_confidence` | spec.md, design.md, plan.md | — |
| 7 | `phase-7-test-strategy.md` | phase-4, phase-5, phase-6 | — | teststrategist | TEST_STRATEGY | `st_revision`, `st_redteam`, `st_tao`, `s3_judge`, `cli_*`, `dev_skills`, `deep_reasoning`, `s7_mpa`, `s8_convergence`, `s10_team` | spec.md, design.md, plan.md, thinkdeep-insights.md, test-strategy.md | — |
| 8 | `phase-8-coverage.md` | phase-7 | If YELLOW/RED | — | TEST_COVERAGE_VALIDATION | `cli_*` | test-plan.md, spec.md, test-strategy.md | `∥` |
| 8b | `phase-8b-asset-consolidation.md` | phase-8 | Validate manifest | — | ASSET_CONSOLIDATION | — | spec.md, design.md, plan.md, test-plan.md, research.md, expert-review.md | `∥` |
| 9 | `phase-9-completion.md` | phase-4, phase-6, phase-7, phase-8, phase-8b | Clarify tasks | taskauditor | COMPLETION | `st_task_decomp`, `a5_post_menu`, `cli_*`, `dev_skills` | spec.md, plan.md, design.md, test-plan.md, test-cases/*, asset-manifest.md | — |
| 10 | `phase-10-retrospective.md` | phase-1 through phase-9 | None | — | RETROSPECTIVE | — | `.planning-state.local.md` | — |

All phase files are in `$CLAUDE_PLUGIN_ROOT/skills/plan/references/`. Delegation: Phase 1 inline, Phase 3 conditional (inline for Standard/Rapid), all others coordinator.

> **Flag abbreviations:** `cli_*` = `cli_context_isolation` + `cli_custom_roles`, `s5_tot` = `s5_tot_architecture`, `s4_adaptive` = `s4_adaptive_strategy`, `s3_judge` = `s3_judge_gates`, `st_fork_join` = `st_fork_join_architecture`, `st_tao` = `st_tao_loops`, `dev_skills` = `dev_skills_integration`, `deep_reasoning` = `deep_reasoning_escalation`, `s7_mpa` = `s7_mpa_deliberation`, `s8_convergence` = `s8_convergence_detection`, `s10_team` = `s10_team_presets`, `a1_flow` = `a1_flow_analysis`, `a4_expert` = `a4_expert_review`, `s13_confidence` = `s13_confidence_gated_review`, `s6_debate` = `s6_multi_judge_debate`, `st_task_decomp` = `st_task_decomposition`, `a5_post_menu` = `a5_post_planning_menu`.

## Orchestrator Dispatch Loop

```pseudocode
FOR EACH phase IN dispatch_table (ordered by phase number):

  # 1. Check entry conditions
  IF phase.min_mode > state.analysis_mode: SKIP
  IF phase.checkpoint already in state.checkpoints: SKIP (already done)
  IF phase == "8b" AND state.analysis_mode in [rapid, standard]: SKIP

  # 2. Resolve prompt variables (see orchestrator-loop.md § Variable Resolution Table)
  prompt = FILL_TEMPLATE(phase.prompt_template, {
    phase, phase_name, phase_file, FEATURE_DIR, analysis_mode,
    relevant_flags_and_values, requirements_section, context_section, prior_summaries
  })

  # 3. Dispatch coordinator
  IF phase == "8" AND phase "8b" eligible:
    PARALLEL_DISPATCH(phase_8_prompt, phase_8b_prompt)  # Both run concurrently
  ELSE:
    summary = Task(subagent_type="general-purpose", prompt=prompt)

  # 4. Validate summary
  VALIDATE summary has required YAML frontmatter (stage, status, artifacts_written)
  IF validation fails: RECONSTRUCT minimal summary from artifact state

  # 5. Handle result
  IF summary.status == "needs-user-input":
    RELAY summary.flags.block_reason to user via AskUserQuestion
    UPDATE state with user response
    RE-DISPATCH same phase
  ELIF summary.gate AND summary.gate.verdict == "RED":
    FOLLOW Gate Failure Decision Table (orchestrator-loop.md)
  ELSE:
    SAVE checkpoint
    CONTINUE to next phase
```

> **On-demand references in `orchestrator-loop.md`:** crash recovery, circuit breaker, state migration, variable resolution table, gate failure decision table, Context Pack builder (S6), ADR.

**Multi-Agent Collaboration Flags** (all disabled by default — enable in `config/planning-config.yaml`):
- `a6_context_protocol` — Accumulated decision/question/risk propagation via Context Pack
- `s7_mpa_deliberation` — Structured Round 2 cross-review for MPA agents
- `s8_convergence_detection` — Jaccard similarity convergence measurement
- `s10_team_presets` — User-selectable agent team configurations (balanced/rapid_prototype)
- `s12_specify_gate` — 5-dimension specification quality scoring in Phase 3
- `s13_confidence_gated_review` — Confidence-scored expert review with tri-state outcome

### Feature Flag Naming Convention

| Prefix | Scope | Example |
|--------|-------|---------|
| `s{N}_` | Shared — available in all modes | `s7_mpa_deliberation` |
| `a{N}_` | Advanced-only — Complete/Advanced modes | `a6_context_protocol` |
| `st_` | Sequential Thinking integration | `st_enabled` |
| _(none)_ | Infrastructure — always active | `circuit_breaker_enabled` |

## Phase 1 (Inline)

Execute Phase 1 inline. Read `$CLAUDE_PLUGIN_ROOT/skills/plan/references/phase-1-setup.md` for full instructions. After completion, write Phase 1 summary to `{FEATURE_DIR}/.phase-summaries/phase-1-summary.md`.

## Summary Convention

- **Path:** `{FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md`
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`
- **Size:** 30-80 lines (YAML frontmatter + markdown)
- **Critical section:** "Context for Next Phase" — this is what the next coordinator reads to understand priorities
- `reasoning_lineage` (optional, ~100 tokens) — Brief chain of key decisions: `"Chose X because Y → led to Z → confirmed by W"`

## State Management

State persisted in `{FEATURE_DIR}/.planning-state.local.md` (version 2):
- YAML frontmatter tracks phase, mode, decisions, phase_summaries, orchestrator metadata
- Markdown body contains human-readable log
- Immutable fields: `user_decisions`, `approved_architecture`, `approved_test_strategy`
- Migration: If `version: 1`, see `orchestrator-loop.md` for auto-migration to v2

## MPA Agents

### Planning Agents (Phases 2-4, 9)
- `product-planning:code-explorer` - Codebase patterns and integration points
- `product-planning:software-architect` - Architecture options and trade-offs
- `product-planning:tech-lead` - Task breakdown with TDD structure (Phase 9 primary)
- `product-planning:researcher` - Technology research and unknowns
- `product-planning:flow-analyzer` - User flow mapping (Complete mode, A1)
- `product-planning:learnings-researcher` - Institutional knowledge lookup (A2)

### Explorer Agents (Phase 4 ToT)
- `product-planning:wildcard-architect` - Unconstrained architecture exploration (Complete mode, S5)

### Judge Agents (Phases 4, 6, 7)
- `product-planning:phase-gate-judge` - Quality gate evaluation (S3)
- `product-planning:architecture-pruning-judge` - ToT option pruning (Complete mode, S5)
- `product-planning:debate-judge` - Multi-round debate moderation (Complete mode, S6)

### Reviewer Agents (Phase 6b)
- `product-planning:security-analyst` - STRIDE threat analysis (Advanced/Complete, A4)
- `product-planning:simplicity-reviewer` - Over-engineering detection (Advanced/Complete, A4)

### QA Agents (Phase 7) - MPA for Test Planning
- `product-planning:qa-strategist` - V-Model test strategy and UAT generation (all modes)
- `product-planning:qa-security` - Security testing, STRIDE analysis (Complete/Advanced)
- `product-planning:qa-performance` - Performance/load testing (Complete/Advanced)

## Output Artifacts

| Artifact | Content |
|----------|---------|
| `design.md` | Final architecture design |
| `plan.md` | Implementation plan |
| `tasks.md` | Dependency-ordered tasks with TDD structure (TEST->IMPLEMENT->VERIFY) |
| `requirements-anchor.md` | Consolidated requirements: spec + user clarifications (Phase 3) |
| `research.md` | Codebase analysis findings |
| `test-plan.md` | V-Model test strategy with coverage matrix |
| `test-cases/unit/` | Unit test specifications (TDD-ready) |
| `test-cases/integration/` | Integration test specs |
| `test-cases/e2e/` | E2E scenario scripts with evidence requirements |
| `test-cases/uat/` | UAT scripts (Given-When-Then format) |
| `asset-manifest.md` | Asset preparation manifest (Phase 8b, optional) |
| `.phase-summaries/` | Inter-phase coordinator summary files |
| `data-model.md` | Entity definitions (optional) |
| `contract.md` | API contracts (optional) |
| `retrospective.md` | Planning retrospective with KPIs, timeline, and recommendations |
| `.planning-report-card.local.md` | Machine-readable KPI Report Card (local, not committed) |

### Additional Resources

See `references/README.md` for the complete reference file catalog with usage patterns and cross-references.

**Examples:** `$CLAUDE_PLUGIN_ROOT/skills/plan/examples/` contains sample artifacts for reference:
- `state-file.md` — Sample `.planning-state.local.md` for resume testing
- `thinkdeep-output.md` — Sample CLI deep analysis output (Phase 5)

## Quick Start

1. Ensure `{FEATURE_DIR}/spec.md` exists (optional: `test-strategy.md` from specify for traceability)
2. Run `/product-planning:plan`
3. Select analysis mode
4. Answer clarifying questions
5. Review architecture → ThinkDeep → validation → tests → tasks

### When NOT to Use This Skill

- **Bug fixes** — Use direct implementation, not feature planning
- **Documentation-only changes** — No architecture design needed
- **Multi-feature specs** — Split into separate planning sessions per feature
- **Already-planned features** — Go directly to `/product-implementation:implement`
- **Trivial changes** — Single-file edits under 50 lines don't need planning

## Error Handling

- **Missing prerequisites** - Provide guidance to create spec.md
- **MCP unavailable** - Graceful degradation to simpler modes
- **Agent failure** - Retry once, then continue with partial results
- **Lock conflict** - Wait or manual intervention guidance
- **RED gates** - Loop back (Phase 6 RED → Phase 4, Phase 8 RED → Phase 7)
- **Coordinator crash** - See `orchestrator-loop.md` for crash recovery and summary reconstruction

## Test Execution Order (V-Model)

After planning completes, implementation follows V-Model test order:

1. **Pre-Implementation:** Write failing unit tests (TDD RED)
2. **During Implementation:** Pass unit tests (TDD GREEN), refactor
3. **Post-Implementation:** Run integration tests
4. **Pre-Merge:** Run E2E tests with evidence collection
5. **Pre-Release:** Execute UAT with Product Owner sign-off
