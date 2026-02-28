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

1. **State Preservation** - Checkpoint after user decisions. User decisions are IMMUTABLE once saved.
2. **Resume Compliance** - When resuming, NEVER re-ask questions from `user_decisions`.
3. **Delegation** - Complex analysis uses MPA agents + CLI deep analysis. Do NOT attempt inline analysis.
4. **Mode Selection** - ALWAYS ask user to choose analysis mode before proceeding.
5. **Lock Protocol** - Acquire lock at start, release at completion. Check for stale locks (>60 min).
6. **Config Reference** - Use `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` for all settings.
7. **V-Model Alignment** - Every acceptance criterion MUST have a corresponding test.
8. **Delegation Protocol** - Delegated phases execute via `Task(subagent_type="general-purpose")` coordinators. Phase 1 is inline. Phase 3 is conditional (inline for Standard/Rapid).
9. **Summary-Only Context** - Between phases, read ONLY summary files from `{FEATURE_DIR}/.phase-summaries/`. Never read full phase instruction files or raw artifacts in orchestrator context.
10. **No User Interaction from Coordinators** - Coordinators set `status: needs-user-input` in their summary. The orchestrator mediates ALL user prompts via `AskUserQuestion`.
11. **Requirements Context Propagation** - The orchestrator injects a requirements digest (~300 tokens from spec.md) into every coordinator dispatch prompt. Phase 3 produces `requirements-anchor.md` (spec + clarifications). Phases 5, 6, 6b read spec.md directly. See `config/planning-config.yaml` `requirements_context:` for budgets.

## Analysis Modes

| Mode | Description | MCP Required | Base Cost | With CLI |
|------|-------------|--------------|-----------|----------|
| **Complete** | MPA + ThinkDeep (9) + ST + Consensus + Full Test Plan | Yes | $1.00-1.80 | $1.30-2.50 |
| **Advanced** | MPA + ThinkDeep (6) + Test Plan | Yes | $0.55-0.95 | $0.70-1.10 |
| **Standard** | MPA only + Basic Test Plan | No | $0.15-0.30 | N/A |
| **Rapid** | Single agent + Minimal Test Plan | No | $0.05-0.12 | N/A |

Costs are base estimates without ST or CLI enhancements. See `config/planning-config.yaml` blessed profiles for full costs with all enhancements enabled.

**CLI Multi-CLI Dispatch** (Complete/Advanced): When `cli_custom_roles` is enabled and CLI tools are installed, phases 5, 6, 6b, 7, and 9 run supplemental analysis via Gemini + Codex + OpenCode in parallel using Bash process-group dispatch (`scripts/dispatch-cli-agent.sh`), then synthesize and self-critique findings. Each CLI brings a different lens: Gemini (strategic/broad), Codex (code-level/challenger), OpenCode (UX/product). Tri-CLI synthesis uses unanimous (VERY HIGH), majority (HIGH), and divergent (FLAG) confidence levels. This adds ~6-9 min total latency but provides broader coverage.

Graceful degradation: If CLIs unavailable, fall back to Standard/Rapid modes (internal agents only). If ST unavailable, fall back to Advanced mode.

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
│  └─────────┘                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Latency Trade-off

Each coordinator dispatch adds ~5-15s overhead. This is the trade-off for ~78% orchestrator context reduction. For lightweight phases (Phase 3 in Standard/Rapid), inline execution avoids this overhead.

**Deep Reasoning Escalation** (Complete/Advanced, disabled by default): When gate retries exhaust (2 failures), the orchestrator can offer manual escalation to external deep reasoning models (GPT-5 Pro, Google Deep Think). User copies a CTCO prompt to the model's web interface, waits 3-15 min, and returns the result. Adds no API cost. See `references/deep-reasoning-dispatch-pattern.md` for the dispatch pattern and `config/planning-config.yaml` `deep_reasoning_escalation:` for feature flags.

## Phase Dispatch Table

| Phase | Delegation | File | Prior Summaries | User Interaction | CLI | Checkpoint |
|-------|-----------|------|-----------------|------------------|-----|------------|
| 1 | Inline | `phase-1-setup.md` | — | Mode selection | Detect | SETUP |
| 2 | Coordinator | `phase-2-research.md` | phase-1 | Gate failure only | — | RESEARCH |
| 3 | Conditional | `phase-3-clarification.md` | phase-2 | Questions (all) | — | CLARIFICATION |
| 4 | Coordinator | `phase-4-architecture.md` | phase-2, phase-3 | Select option | — | ARCHITECTURE |
| 5 | Coordinator | `phase-5-thinkdeep.md` | phase-4 | Review findings | deepthinker | THINKDEEP |
| 6 | Coordinator | `phase-6-validation.md` | phase-4, phase-5 | If YELLOW/RED | planreviewer | VALIDATION |
| 6b | Coordinator | `phase-6b-expert-review.md` | phase-6 | Blocking security | securityauditor | EXPERT_REVIEW |
| 7 | Coordinator | `phase-7-test-strategy.md` | phase-4, phase-5, phase-6 | — | teststrategist | TEST_STRATEGY |
| 8 | Coordinator | `phase-8-coverage.md` | phase-7 | If YELLOW/RED | — | TEST_COVERAGE_VALIDATION |
| 8b | Coordinator | `phase-8b-asset-consolidation.md` | phase-8 | Validate manifest | — | ASSET_CONSOLIDATION |
| 9 | Coordinator | `phase-9-completion.md` | phase-7, phase-8, phase-8b | Clarify tasks | taskauditor | COMPLETION |

All phase files are in `$CLAUDE_PLUGIN_ROOT/skills/plan/references/`.

## Orchestrator Loop

Read and follow: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/orchestrator-loop.md`

The loop reads state → dispatches phases in order → reads summaries → handles user interaction → updates state. It includes crash recovery, summary validation, v1-to-v2 state migration, and the Context Pack builder (S6).

**Multi-Agent Collaboration Flags** (all disabled by default — enable in `config/planning-config.yaml`):
- `a6_context_protocol` — Accumulated decision/question/risk propagation via Context Pack
- `s7_mpa_deliberation` — Structured Round 2 cross-review for MPA agents
- `s8_convergence_detection` — Jaccard similarity convergence measurement
- `s10_team_presets` — User-selectable agent team configurations (balanced/rapid_prototype)
- `s12_specify_gate` — 5-dimension specification quality scoring in Phase 3
- `s13_confidence_gated_review` — Confidence-scored expert review with tri-state outcome

## Phase 1 (Inline)

Execute Phase 1 inline. Read `$CLAUDE_PLUGIN_ROOT/skills/plan/references/phase-1-setup.md` for full instructions. After completion, write Phase 1 summary to `{FEATURE_DIR}/.phase-summaries/phase-1-summary.md`.

## Summary Convention

- **Path:** `{FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md`
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`
- **Size:** 30-80 lines (YAML frontmatter + markdown)
- **Critical section:** "Context for Next Phase" — this is what the next coordinator reads to understand priorities

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

## Additional Resources

### Per-Phase Instruction Files
- `references/phase-1-setup.md` through `references/phase-9-completion.md`
- `references/phase-6b-expert-review.md`
- `references/phase-8b-asset-consolidation.md`
- `references/phase-workflows.md` — Navigational index only

### Orchestrator Support
- `references/orchestrator-loop.md` — Dispatch loop, crash recovery, state migration

### Existing References
- `references/thinkdeep-prompts.md` — Deep analysis perspective prompts (used by CLI deepthinker dispatch)
- `references/validation-rubric.md` — Consensus scoring criteria
- `references/v-model-methodology.md` — V-Model testing reference
- `references/coverage-validation-rubric.md` — Test coverage scoring
- `$CLAUDE_PLUGIN_ROOT/templates/asset-manifest-template.md` — Asset manifest structure (Phase 8b)
- `references/self-critique-template.md` — Standard self-critique for all agents (S1)
- `references/cot-prefix-template.md` — Chain-of-Thought reasoning template (S2)
- `references/judge-gate-rubrics.md` — Quality gate scoring criteria (S3)
- `references/adaptive-strategy-logic.md` — Architecture selection strategy (S4)
- `references/tot-workflow.md` — Hybrid ToT-MPA workflow (S5)
- `references/debate-protocol.md` — Multi-round debate validation (S6)
- `references/research-mcp-patterns.md` — Research MCP server usage guide
- `references/cli-dispatch-pattern.md` — Canonical CLI multi-CLI dispatch pattern (retry, synthesis, self-critique)
- `references/skill-loader-pattern.md` — Canonical dev-skills context loading via subagent delegation (Phases 2, 4, 6b, 7, 9)
- `references/deep-reasoning-dispatch-pattern.md` — Deep reasoning escalation workflow (gate failures, security deep dive, algorithm escalation)
- `references/mpa-synthesis-pattern.md` — Shared MPA Deliberation (S1) + Convergence Detection (S2) algorithms (used by Phase 4 and Phase 7)

### Sequential Thinking Reference
- `$CLAUDE_PLUGIN_ROOT/templates/sequential-thinking-templates.md`
  - **Load selectively**: coordinators should load only the relevant template group per the `phase_mapping` in `config/planning-config.yaml`, NOT the entire file (~4K tokens). E.g., Phase 4 loads `architecture_design` + `architecture_fork_join` + `risk_assessment` + `agent_analysis` groups only.

### Configuration
- `$CLAUDE_PLUGIN_ROOT/config/planning-config.yaml` — All limits, thresholds, models

### Templates
- `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md` — Phase summary format
- `$CLAUDE_PLUGIN_ROOT/templates/tasks-template.md` — Task breakdown structure
- `$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md` — Test plan structure
- `$CLAUDE_PLUGIN_ROOT/templates/uat-script-template.md` — UAT script format
- `$CLAUDE_PLUGIN_ROOT/templates/deep-reasoning-templates.md` — CTCO prompt templates for deep reasoning escalation

## Quick Start

1. Ensure `{FEATURE_DIR}/spec.md` exists (optional: `test-strategy.md` from specify for traceability)
2. Run `/product-planning:plan`
3. Select analysis mode
4. Answer clarifying questions
5. Review architecture → ThinkDeep → validation → tests → tasks

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
