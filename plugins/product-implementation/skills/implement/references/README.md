# Reference Files Index

Quick guide to when to read each reference file during skill development or debugging.

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Understanding dispatch loop, crash recovery, state migration, or context pack protocol |
| `stage-1-setup.md` | Debugging setup, branch parsing, lock acquisition, or state initialization |
| `stage-2-execution.md` | Debugging phase-by-phase execution, task parsing, or TDD enforcement |
| `stage-2-uat-mobile.md` | Understanding UAT mobile testing procedure (extracted from Stage 2 Step 3.7) |
| `stage-3-validation.md` | Debugging completion validation, spec alignment, or test coverage checks |
| `stage-4-quality-review.md` | Debugging quality review, three-tier architecture, finding consolidation, confidence scoring, stances, convergence detection, or CoVe |
| `stage-4-plugin-review.md` | Understanding Tier B plugin-based review (code-review skill integration) |
| `stage-4-cli-review.md` | Understanding Tier C CLI multi-model review (Phase 1/2 dispatch, pattern search) |
| `stage-5-documentation.md` | Debugging documentation generation, tech-writer dispatch, or lock release |
| `stage-6-retrospective.md` | Debugging retrospective generation, KPI compilation, transcript extraction, or tech-writer dispatch |
| `agent-prompts.md` | Modifying agent prompt templates or adding new prompt types |
| `integrations-overview.md` | Understanding dev-skills, research MCP, CLI dispatch, or autonomy policy integration summaries |
| `autonomy-policy-procedure.md` | Understanding shared parameterized autonomy policy check (used by Stages 2, 3, 4, 5) |
| `auto-commit-dispatch.md` | Understanding shared auto-commit procedure, exclude pattern matching, or batch strategy |
| `skill-resolution.md` | Understanding domain-specific skill resolution algorithm used by Stages 2, 4, 5 |
| `cli-dispatch-procedure.md` | Understanding shared CLI dispatch, timeout, parsing, fallback algorithm, or circuit breaker gate |
| `summary-schemas.md` | Checking required/optional fields for any stage summary YAML |

## By Task

### Understanding the Delegation Architecture
1. Read `orchestrator-loop.md` for dispatch loop and recovery
2. Read any per-stage file for that stage's complete instructions
3. See Architecture Decision Records below for rationale

### Debugging a Specific Stage
1. Read the corresponding `stage-{N}-*.md` file
2. Read `agent-prompts.md` for the prompt template used by that stage
3. Check `orchestrator-loop.md` if the issue is in dispatch or summary handling

### Adding a New Stage
1. Read `orchestrator-loop.md` for the dispatch pattern
2. Copy an existing `stage-{N}-*.md` as a template (use YAML frontmatter)
3. Add entry to SKILL.md Stage Dispatch Table
4. Add prompt template to `agent-prompts.md`
5. Add summary schema to `summary-schemas.md`

### Working on State Management
1. Read `orchestrator-loop.md` for v1-to-v2 migration
2. Read `stage-1-setup.md` Section 1.8 for state initialization
3. Check `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md` for schema

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | 272 | Dispatch loop, crash recovery, lock release, state migration, late notification handling, autonomy policy infrastructure checks, context pack protocol |
| `stage-1-setup.md` | 584 | Inline setup instructions, domain detection with confidence scoring, MCP availability probing (1.6a-1.6d), mobile device availability (1.6e), plugin availability check (1.6f), CLI circuit breaker initialization (1.7b), CLI availability detection with dispatch script smoke test (1.7a), autonomy policy selection (1.9a), context contributions initialization, summary template |
| `stage-2-execution.md` | 501 | Skill resolution, research context resolution (2.0a), phase loop, CLI test author (Step 1.8), code simplification (Step 3.5), OpenCode UX test review (Step 3.6), auto-commit per phase, batch strategy, execution rules, build verification, build error smart resolution, test count extraction, cli_dispatch_metrics, circuit state propagation, context contributions, autonomy policy checks |
| `stage-2-uat-mobile.md` | 121 | UAT mobile testing procedure (non-skippable gate check, phase relevance, APK build/install, evidence directory, CLI dispatch, result processing via autonomy-policy-procedure, write boundaries) |
| `stage-3-validation.md` | 243 | Validation checks, CLI spec validator (3.1a), OpenCode UX validator (3.1b), constitution compliance, coverage delta, API doc alignment (check 12), Stage 2 cross-validation, test quality gate, report format, circuit state propagation, context contributions, autonomy policy check via shared procedure (3.4) |
| `stage-4-quality-review.md` | 490 | Interaction matrix (4.0), three-tier review architecture (Tier A native, Tier B plugin, Tier C CLI), stance assignment (4.2), convergence detection with semantic cross-check (4.3a), confidence scoring with outcome logging, severity reclassification (with intentional bypass note), stance divergence analysis (4.3), CoVe post-synthesis (4.3b), finding consolidation, auto-decision matrix with autonomy policy extension (4.4), CLI fix engineer (Option F), native agent failure tracking, auto-commit on fix |
| `stage-4-plugin-review.md` | 69 | Tier B: Plugin-based review via code-review skill, config-driven CEK confidence normalization, max findings cap, graceful degradation |
| `stage-4-cli-review.md` | 126 | Tier C: CLI multi-model review, Phase 1 parallel dispatch (correctness, security, android domain, UX/accessibility), Phase 2 sequential pattern search (Gemini 1M context), consolidation checkpoint |
| `stage-5-documentation.md` | 292 | Skill resolution for docs, research context for documentation (5.1b), tech-writer dispatch, OpenCode doc review (5.2a), auto-commit documentation, lock release, context contributions, autonomy policy check for incomplete tasks (5.1) |
| `stage-6-retrospective.md` | 350 | KPI Report Card compilation (10 Phase 1 KPIs), Phase 2 KPI placeholders (CoVe effectiveness, reviewer convergence, circuit breaker trips), cli_dispatch_metrics aggregation, sidecar cleanup, session transcript extraction (conditional), retrospective composition via tech-writer, auto-commit, context contributions, state update |
| `agent-prompts.md` | 562 | Common Variables section, 9 agent prompt templates (8 agent + 1 auto-commit) with section markers, `{skill_references}`, `{research_context}`, and `{reviewer_stance}` variables with explicit fallback annotations, Implementation Verification Rules reference, severity escalation, retrospective composition |
| `integrations-overview.md` | 84 | Dev-Skills, Research MCP, CLI Dispatch, and Autonomy Policy integration summaries (extracted from SKILL.md for context efficiency) |
| `autonomy-policy-procedure.md` | 56 | Shared parameterized autonomy policy check — severity iteration, fix/defer/accept actions, infrastructure failure auto-revert, manual escalation fallback |
| `auto-commit-dispatch.md` | 62 | Shared parameterized auto-commit procedure, exclude pattern semantics, batch strategy |
| `skill-resolution.md` | 87 | Shared skill resolution algorithm for domain-specific skill injection |
| `cli-dispatch-procedure.md` | 208 | Shared parameterized CLI dispatch via Bash process-group dispatch, 4-tier output parsing, expected-fields validation, metrics sidecar, exit codes 0-4, UUID output filenames, variable injection convention, circuit breaker pre/post-step, fallback procedure |
| `summary-schemas.md` | 94 | YAML schemas for all 6 stage summaries — base fields table + per-stage field tables with type, required/optional, default, producer, consumer |

## Cross-References (Key Non-Obvious Data Flows)

Obvious flows (stage file → agent-prompts.md, all stages → config) are omitted. See individual stage files for their specific references.

- **Stage 1 summary as context bus**: `stage-1-setup.md` writes `detected_domains`, `mcp_availability`, `cli_availability`, `mobile_mcp_available`, `plugin_availability`, `autonomy_policy`, `cli_circuit_state`, and `context_contributions` — consumed by all downstream coordinators
- **Test count propagation**: `test_count_verified` (Stage 2) → `baseline_test_count` (Stage 3, independently verified) → `test_count_post_fix` (Stage 4)
- **Research URL accumulation**: Stage 2 writes `research_urls_discovered` to summary flags; Stages 4 and 5 re-read these URLs for maximum Ref Dropout benefit
- **CLI circuit state propagation**: Initialized in Stage 1 (Section 1.7b), propagated through Stages 2, 3, 4 summary flags, updated by CLI dispatches via `cli-dispatch-procedure.md`
- **Context contributions accumulation**: Each stage writes `context_contributions` to its summary; `orchestrator-loop.md` compiles and injects budget-controlled context packs into coordinator prompts
- **Shared procedures referenced by multiple stages**: `autonomy-policy-procedure.md` (Stages 2, 3, 4, 5), `auto-commit-dispatch.md` (Stages 2, 4, 5, 6), `skill-resolution.md` (Stages 2, 4, 5), `cli-dispatch-procedure.md` (Stages 2, 3, 4, 5)
- **Orchestrator transparency**: Dev-skills, Research MCP, CLI dispatch, UAT mobile, and OpenCode are coordinator-only — the orchestrator never reads their config or dispatches them directly
- **Stage 6 post-lock-release**: Lock released in Stage 5; Stage 6 runs as read-only analysis, reads all 5 prior summaries

## Architecture Decision Records

### ADR-1: Coordinator Delegation vs Direct Inline Execution

**Status**: Accepted

**Context**: The implement skill has 6 stages, each reading 3-8 reference files plus config. Executing all stages inline in the orchestrator's context would load ~4,000 lines of reference material, degrading reasoning quality on the primary dispatch task.

**Decision**: Stages 2-6 are delegated to coordinator subagents via `Task(subagent_type="general-purpose")`. Stage 1 runs inline (lightweight setup, ~60 lines of logic). Each coordinator reads only its stage's reference files, writes a YAML-frontmatter summary, and terminates. The orchestrator reads only summaries between stages.

**Consequences**:
- Each coordinator dispatch adds ~5-15s latency overhead (11 total dispatches across a full run: 5 coordinator stages + conditional sub-dispatches)
- Orchestrator context stays lean (~300 lines of SKILL.md + summaries)
- Fault isolation: a coordinator crash does not lose orchestrator state; crash recovery reconstructs from artifacts
- Independent restart: any stage can be re-dispatched without replaying prior stages
- Trade-off accepted: latency cost is small relative to agent execution time (30-120s per stage)
