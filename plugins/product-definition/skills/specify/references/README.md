# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Start of orchestration — dispatch loop, variable defaults, iteration logic, quality gates |
| `recovery-migration.md` | On crash or v2 state detected — crash recovery procedures, v2→v3 state migration |
| `stage-1-setup.md` | Stage 1 inline execution — init, MCP check, workspace, Figma capture |
| `stage-2-spec-draft.md` | Dispatching Stage 2 — BA spec draft, MPA-Challenge CLI dispatch, incremental gates |
| `stage-3-checklist.md` | Dispatching Stage 3 — platform detect, checklist creation, BA validation |
| `stage-4-clarification.md` | Dispatching Stage 4 — MPA-EdgeCases, clarification protocol, MPA-Triangulation, spec update |
| `stage-5-validation-design.md` | Dispatching Stage 5 — CLI multi-stance evaluation, design-brief, design-supplement (MANDATORY) |
| `stage-6-test-strategy.md` | Dispatching Stage 6 — V-Model test plan, AC traceability (optional, feature flag) |
| `stage-7-completion.md` | Dispatching Stage 7 — lock release, completion report, next steps |
| `checkpoint-protocol.md` | Any checkpoint — state update patterns and immutable decision rules |
| `error-handling.md` | Any error condition — PAL failures, Figma failures, graceful degradation, recovery |
| `config-reference.md` | CLI dispatch usage — template variables, CLI patterns, scoring thresholds |
| `cli-dispatch-patterns.md` | Stages 2, 4, 5 (CLI dispatch calls) — parameterized tri-CLI execution for Challenge, EdgeCases, Triangulation, Evaluation |
| `figma-capture-protocol.md` | Stage 1 (Figma enabled) — connection selection, capture process, screenshot naming, error recovery |
| `clarification-protocol.md` | Stage 4 (clarification dispatch) — file-based Q&A, BA recommendations, answer parsing |
| `auto-resolve-protocol.md` | Stage 4 (pre-question generation) — auto-resolve gate, classification, citation rules, exclusion rules |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | ~380 | Dispatch loop, variable defaults, iteration logic (Stage 3↔4), quality gates, stall detection |
| `recovery-migration.md` | ~80 | Crash recovery procedures, v2→v3 state migration (loaded on-demand) |
| `stage-1-setup.md` | ~350 | Inline setup: MCP check, pre-flight, lock, workspace, Figma capture, state init |
| `stage-2-spec-draft.md` | ~450 | BA spec draft, MPA-Challenge CLI dispatch, Gate 1 (Problem), Gate 2 (True Need) |
| `stage-3-checklist.md` | ~200 | Platform detect, checklist copy, BA validation, coverage scoring |
| `stage-4-clarification.md` | ~400 | MPA-EdgeCases CLI dispatch, clarification protocol, MPA-Triangulation CLI dispatch, spec update |
| `stage-5-validation-design.md` | ~310 | CLI multi-stance evaluation (retry loop), design-brief-generator, gap-analyzer |
| `stage-6-test-strategy.md` | ~250 | Feature flag check, QA strategist, AC coverage validation |
| `stage-7-completion.md` | ~130 | Lock release, completion report, next steps |
| `checkpoint-protocol.md` | ~55 | State update patterns |
| `error-handling.md` | ~165 | CLI/Figma/gate/design/QA failures, graceful degradation |
| `config-reference.md` | ~235 | Template variables, limits, thresholds, feature flags, CLI dispatch params |
| `cli-dispatch-patterns.md` | ~295 | Parameterized execution for 4 CLI dispatch integration points |
| `figma-capture-protocol.md` | ~240 | Figma connection selection, capture process (ReAct), screenshot naming, error handling |
| `clarification-protocol.md` | ~250 | File-based Q&A format, BA recommendations, answer parsing rules, state tracking |
| `auto-resolve-protocol.md` | ~190 | Auto-resolve gate logic, classification levels, exclusion rules, report format |

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

### External References

- All files reference `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` for configuration
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/{agent-name}.md`
- Stage files reference templates at `$CLAUDE_PLUGIN_ROOT/templates/prompts/`
- Stage files reference analysis templates at `$CLAUDE_PLUGIN_ROOT/templates/analysis/`
- Stage 6 references `$CLAUDE_PLUGIN_ROOT/agents/qa-references/sequential-thinking-templates.md`

## Step Numbering Convention

All stage files use flat numbering `Step N.M` (e.g., `Step 2.1`, `Step 3.3`, `Step 5.5`).
No sub-part numbering is needed (unlike refinement's Stage 3 which had A/B parts).

## Structural Patterns

All stage files (stages 1-7) follow this structure:
1. YAML frontmatter with `stage` name and `artifacts_written` list
2. **CRITICAL RULES** section at top (attention-favored position)
3. Numbered steps for execution
4. Summary Contract (YAML template)
5. **Self-Verification** checklist (mandatory before writing summary)
6. **CRITICAL RULES REMINDER** at bottom (attention-favored position)

**Max-rules guidance:** Keep CRITICAL RULES sections to **5-7 rules maximum** per stage file.
