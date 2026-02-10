# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Start of orchestration — dispatch loop, variable defaults, iteration logic, quality gates |
| `recovery-migration.md` | On crash or v2 state detected — crash recovery procedures, v2→v3 state migration |
| `stage-1-setup.md` | Stage 1 inline execution — init, MCP check, workspace, Figma capture |
| `stage-2-spec-draft.md` | Dispatching Stage 2 — BA spec draft, MPA-Challenge ThinkDeep, incremental gates |
| `stage-3-checklist.md` | Dispatching Stage 3 — platform detect, checklist creation, BA validation |
| `stage-4-clarification.md` | Dispatching Stage 4 — MPA-EdgeCases, clarification sub-skill, MPA-Triangulation, spec update |
| `stage-5-pal-design.md` | Dispatching Stage 5 — PAL Consensus, design-brief, design-feedback (MANDATORY) |
| `stage-6-test-strategy.md` | Dispatching Stage 6 — V-Model test plan, AC traceability (optional, feature flag) |
| `stage-7-completion.md` | Dispatching Stage 7 — lock release, completion report, next steps |
| `checkpoint-protocol.md` | Any checkpoint — state update patterns and immutable decision rules |
| `error-handling.md` | Any error condition — PAL failures, Figma failures, graceful degradation, recovery |
| `config-reference.md` | PAL tool usage — template variables, PAL patterns, scoring thresholds |
| `thinkdeep-patterns.md` | Stages 2, 4 (ThinkDeep calls) — parameterized multi-model execution for Challenge, EdgeCases, Triangulation |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | ~380 | Dispatch loop, variable defaults, iteration logic (Stage 3↔4), quality gates, stall detection |
| `recovery-migration.md` | ~80 | Crash recovery procedures, v2→v3 state migration (loaded on-demand) |
| `stage-1-setup.md` | ~350 | Inline setup: MCP check, pre-flight, lock, workspace, Figma capture, state init |
| `stage-2-spec-draft.md` | ~450 | BA spec draft, MPA-Challenge ThinkDeep, Gate 1 (Problem), Gate 2 (True Need) |
| `stage-3-checklist.md` | ~200 | Platform detect, checklist copy, BA validation, coverage scoring |
| `stage-4-clarification.md` | ~400 | MPA-EdgeCases ThinkDeep, clarification sub-skill, MPA-Triangulation, spec update |
| `stage-5-pal-design.md` | ~350 | PAL Consensus (retry loop), design-brief-generator, gap-analyzer |
| `stage-6-test-strategy.md` | ~250 | Feature flag check, QA strategist, AC coverage validation |
| `stage-7-completion.md` | ~130 | Lock release, completion report, next steps |
| `checkpoint-protocol.md` | ~55 | State update patterns |
| `error-handling.md` | ~160 | PAL/Figma/gate/design/QA failures, graceful degradation |
| `config-reference.md` | ~250 | Template variables, limits, thresholds, feature flags, PAL params |
| `thinkdeep-patterns.md` | ~200 | Parameterized execution for 3 ThinkDeep integration points |

## Cross-References

### Stage Files → Shared References

- Stages 2-7 reference `checkpoint-protocol.md` for state updates (Stage 1 implements checkpoints inline)
- Stages 2-6 reference `error-handling.md` for failure recovery
- `stage-2-spec-draft.md` references `thinkdeep-patterns.md` (Integration 1: Challenge)
- `stage-4-clarification.md` references `thinkdeep-patterns.md` (Integrations 2 & 3: EdgeCases, Triangulation)
- `stage-5-pal-design.md` references `config-reference.md` for PAL Consensus parameters
- Gate thresholds (Stages 2, 3) and test thresholds (Stage 6) are loaded via config YAML in the dispatch template

### Orchestrator → Stage Files

- `orchestrator-loop.md` references all 7 stage files in dispatch order
- `orchestrator-loop.md` references `recovery-migration.md` for crash recovery and state migration
- `orchestrator-loop.md` performs quality checks after Stages 2, 4, and 5

### Sub-Skill References

- `stage-1-setup.md` invokes `specify-figma-capture` sub-skill
- `stage-4-clarification.md` invokes `specify-clarification` sub-skill (potentially twice: initial + triangulation)

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
