# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Start of orchestration — dispatch loop, variable defaults, iteration logic, quality gates |
| `recovery-migration.md` | On crash or v2/v3/v4 state detected — crash recovery procedures, v2→v3→v4→v5 state migration |
| `stage-1-setup.md` | Stage 1 inline execution — init, MCP check, workspace, Figma capture |
| `stage-2-spec-draft.md` | Dispatching Stage 2 — BA spec draft, MPA-Challenge CLI dispatch, incremental gates |
| `stage-3-checklist.md` | Dispatching Stage 3 — platform detect, checklist creation, BA validation |
| `stage-4-clarification.md` | Dispatching Stage 4 — MPA-EdgeCases, clarification protocol, MPA-Triangulation, spec update |
| `stage-5-validation-design.md` | Dispatching Stage 5 — CLI multi-stance evaluation, design-brief, design-supplement (MANDATORY) |
| `stage-6-test-strategy.md` | Dispatching Stage 6 — V-Model test strategy, AC traceability (optional, feature flag) |
| `stage-7-completion.md` | Dispatching Stage 7 — lock release, completion report, next steps |
| `checkpoint-protocol.md` | Any checkpoint — state update patterns and immutable decision rules |
| `error-handling.md` | Any error condition — CLI failures, Figma failures, graceful degradation, recovery |
| `config-reference.md` | CLI dispatch usage — template variables, CLI patterns, scoring thresholds |
| `cli-dispatch-patterns.md` | Stages 2, 4, 5 (CLI dispatch calls) — parameterized tri-CLI execution for Challenge, EdgeCases, Triangulation, Evaluation |
| `figma-capture-protocol.md` | Stage 1 (Figma enabled) — connection selection, capture process, screenshot naming, error recovery |
| `clarification-protocol.md` | Stage 4 (clarification dispatch) — file-based Q&A, BA recommendations, answer parsing |
| `auto-resolve-protocol.md` | Stage 4 (pre-question generation) — auto-resolve gate, classification, citation rules, exclusion rules |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | ~477 | Dispatch loop, variable defaults, template rendering, iteration logic (Stage 3↔4), quality gates, summary contract schema |
| `recovery-migration.md` | ~185 | Crash recovery procedures, v2→v3→v4→v5 state migration (loaded on-demand) |
| `stage-1-setup.md` | ~402 | Inline setup: MCP check, pre-flight, lock, workspace, Figma capture, RTM inventory, state init |
| `stage-2-spec-draft.md` | ~310 | Pre-conditions, BA spec draft, RTM generation, MPA-Challenge CLI dispatch, gate-judge dispatch |
| `stage-3-checklist.md` | ~228 | Pre-conditions, platform detect, checklist copy, BA validation, coverage scoring, RTM re-evaluation |
| `stage-4-clarification.md` | ~532 | Pre-conditions, RTM disposition gate, MPA-EdgeCases CLI dispatch, clarification protocol, MPA-Triangulation, spec update |
| `stage-5-validation-design.md` | ~317 | Pre-conditions, CLI multi-stance evaluation (retry loop), design-brief-generator, gap-analyzer |
| `stage-6-test-strategy.md` | ~183 | Feature flag check, pre-conditions, QA strategist, AC coverage validation |
| `stage-7-completion.md` | ~152 | Pre-conditions, lock release, completion report, next steps |
| `checkpoint-protocol.md` | ~69 | State update patterns, lock stale timeout, RTM disposition examples |
| `error-handling.md` | ~158 | CLI/Figma/gate/design/QA failures, internal reasoning fallback, graceful degradation |
| `config-reference.md` | ~158 | Template variables, limits, thresholds, feature flags, CLI dispatch params |
| `cli-dispatch-patterns.md` | ~408 | Parameterized execution for 4 CLI dispatch points, semantic dedup scheme, least-to-most synthesis |
| `figma-capture-protocol.md` | ~249 | Figma connection selection, capture process (ReAct), screenshot naming, error handling |
| `clarification-protocol.md` | ~248 | File-based Q&A format, BA recommendations, answer parsing rules, state tracking |
| `auto-resolve-protocol.md` | ~199 | Auto-resolve gate logic, classification levels, exclusion rules, worked examples |

## Cross-References

### Stage Files → Shared References

- Stages 2-7 reference `checkpoint-protocol.md` for state updates (Stage 1 implements checkpoints inline)
- Stages 2-6 reference `error-handling.md` for failure recovery
- `stage-2-spec-draft.md` references `cli-dispatch-patterns.md` (Integration 1: Challenge)
- `stage-4-clarification.md` references `cli-dispatch-patterns.md` (Integrations 2 & 3: EdgeCases, Triangulation)
- `stage-5-validation-design.md` references `cli-dispatch-patterns.md` (Integration 4: Evaluation) and `config-reference.md` for CLI dispatch params
- Gate thresholds (Stages 2, 3) and test thresholds (Stage 6) are loaded via config YAML in the dispatch template

### Orchestrator → Stage Files

- `orchestrator-loop.md` references all 7 stage files in dispatch order
- `orchestrator-loop.md` references `recovery-migration.md` for crash recovery and state migration
- `orchestrator-loop.md` performs quality checks after Stages 2, 4, and 5

### Internal Protocol References

- `stage-1-setup.md` loads `figma-capture-protocol.md` for Figma capture (Step 1.9)
- `stage-4-clarification.md` loads `auto-resolve-protocol.md` (Step 4.1b) and `clarification-protocol.md` (Steps 4.2, 4.3)

### RTM Cross-References

- `stage-1-setup.md` Step 1.9c loads `$CLAUDE_PLUGIN_ROOT/templates/requirements-inventory-template.md`
- `stage-2-spec-draft.md` Step 2.3 loads `$CLAUDE_PLUGIN_ROOT/templates/rtm-template.md` and reads `REQUIREMENTS-INVENTORY.md`
- `stage-3-checklist.md` Step 3.3c re-evaluates `rtm.md` dispositions
- `stage-4-clarification.md` Step 4.0a writes RTM disposition questions to `clarification-questions.md`; Step 4.3 parses RTM disposition answers; Step 4.5 creates new US for PENDING_STORY dispositions
- `stage-7-completion.md` includes RTM metrics in completion report
- `recovery-migration.md` defines v4→v5 state migration adding RTM fields
- `checkpoint-protocol.md` Section 5 includes `rtm_dispositions` example
- `orchestrator-loop.md` adds `RTM_ENABLED` to variable defaults and RTM quality check after Stage 4

### External References

- All files reference `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` for configuration
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/{agent-name}.md`
- Stage files reference templates at `$CLAUDE_PLUGIN_ROOT/templates/prompts/`
- Stage files reference analysis templates at `$CLAUDE_PLUGIN_ROOT/templates/analysis/`
- Stage 6 references `$CLAUDE_PLUGIN_ROOT/agents/qa-references/sequential-thinking-templates.md`

## Step Numbering Convention

All stage files use flat numbering `Step N.M` (e.g., `Step 2.1`, `Step 3.3`, `Step 5.5`).
Pre-condition validation uses `Step N.0`. Stage 4 uses suffix letters for conditional sub-steps: `Step 4.0a` (RTM disposition), `Step 4.0b` (Figma mock gaps).

## Structural Patterns

All stage files (stages 1-7) follow this structure:
1. YAML frontmatter with `stage` name and `artifacts_written` list
2. **CRITICAL RULES** section at top (attention-favored position)
3. **Pre-condition validation** (Step X.0 — verify required inputs exist)
4. Numbered steps for execution
5. Summary Contract (YAML template)
6. **Self-Verification** checklist (mandatory before writing summary) with failure consequences

**Max-rules guidance:** Keep CRITICAL RULES sections to **5-7 rules maximum** per stage file.
