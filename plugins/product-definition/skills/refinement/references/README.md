# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Start of orchestration — dispatch loop, variable defaults, quality gates, reflexion, iteration logic |
| `recovery-migration.md` | On crash or v1 state detected — crash recovery procedures, v1→v2 state migration |
| `stage-1-setup.md` | Stage 1 inline execution — init, MCP check, workspace, mode selection |
| `stage-2-research.md` | Dispatching Stage 2 — research agenda generation and synthesis |
| `stage-3-analysis-questions.md` | Dispatching Stage 3 — ThinkDeep, section decomposition, MPA agents, question generation |
| `stage-4-response-analysis.md` | Dispatching Stage 4 — response parsing, gap analysis, iteration decision |
| `stage-5-validation-generation.md` | Dispatching Stage 5 — PRD readiness validation and generation |
| `stage-6-completion.md` | Dispatching Stage 6 — completion report, lock release, next steps |
| `checkpoint-protocol.md` | Any checkpoint — state update patterns and immutable decision rules |
| `error-handling.md` | Any error condition — PAL failures, graceful degradation, recovery |
| `config-reference.md` | PAL tool usage — template variables, PAL patterns, scoring thresholds |
| `option-generation-reference.md` | Stage 3 question gen — option format, scoring algorithm, merging logic |
| `consensus-call-pattern.md` | Stages 4 and 5 consensus — shared model resolution, multi-step execution, unanimity check |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | ~460 | Dispatch loop, variable defaults with precedence, quality gates, reflexion with persistence, compaction + digest template |
| `recovery-migration.md` | ~65 | Crash recovery procedures, v1→v2 state migration (loaded on-demand) |
| `stage-1-setup.md` | ~300 | Inline setup: init, workspace, mode selection |
| `stage-2-research.md` | ~185 | Research coordinator: agenda + synthesis |
| `stage-3-analysis-questions.md` | ~470 | Analysis + decomposition (8 sections) + question generation (largest) |
| `stage-4-response-analysis.md` | ~243 | Response parsing + gap analysis (consensus via shared pattern) |
| `stage-5-validation-generation.md` | ~243 | Validation + PRD generation + chain-of-thought scoring (consensus via shared pattern) |
| `stage-6-completion.md` | ~125 | Completion: report, lock release |
| `checkpoint-protocol.md` | ~50 | State update patterns |
| `error-handling.md` | ~110 | Error recovery procedures |
| `config-reference.md` | ~220 | PAL parameter reference, scoring thresholds |
| `option-generation-reference.md` | ~300 | Question/option format specification |
| `consensus-call-pattern.md` | ~90 | Shared PAL Consensus call workflow (model resolution, execution, unanimity) |

## Cross-References

### Stage Files -> Shared References

- All stage files reference `checkpoint-protocol.md` for state updates
- All stage files reference `error-handling.md` for failure recovery
- `stage-3-analysis-questions.md` references `option-generation-reference.md` for scoring algorithms
- `stage-3-analysis-questions.md` references `config-reference.md` for ThinkDeep PAL patterns
- `stage-4-response-analysis.md` references `config-reference.md` for Consensus PAL patterns
- `stage-5-validation-generation.md` references `config-reference.md` for scoring thresholds
- `stage-4-response-analysis.md` references `consensus-call-pattern.md` for PAL Consensus execution
- `stage-5-validation-generation.md` references `consensus-call-pattern.md` for PAL Consensus execution

### Stage Summary Data Flow (REFLECTION_CONTEXT)

- `stage-4-response-analysis.md` summary `flags.gap_descriptions` -> consumed by `orchestrator-loop.md` REFLECTION_CONTEXT template
- `stage-5-validation-generation.md` summary `flags.dimension_scores`, `flags.weak_dimensions`, `flags.strong_dimensions` -> consumed by `orchestrator-loop.md` REFLECTION_CONTEXT template
- `orchestrator-loop.md` persists REFLECTION_CONTEXT to `requirements/.stage-summaries/reflection-round-{N}.md` for crash recovery
- `orchestrator-loop.md` passes REFLECTION_CONTEXT to `stage-3-analysis-questions.md` coordinator, which passes it to MPA agents

### Orchestrator -> Stage Files

- `orchestrator-loop.md` references all 6 stage files in dispatch order
- `orchestrator-loop.md` references `recovery-migration.md` for crash recovery and state migration
- `orchestrator-loop.md` references `checkpoint-protocol.md` for state update patterns

### External References

- All files reference `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` for configuration
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/requirements-*.md`
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/research-discovery-*.md`
- Stage files reference templates at `$CLAUDE_PLUGIN_ROOT/templates/`

## Step Numbering Convention

- **Stages 1, 2, 4, 5, 6**: Use flat numbering `Step N.M` (e.g., `Step 4.1`, `Step 4.2`)
- **Stage 3**: Uses sub-part numbering `Step 3A.M` / `Step 3B.M` because the stage has two distinct phases:
  - Part A: ThinkDeep analysis (steps `3A.1`, `3A.2`, `3A.3`)
  - Part B: MPA question generation (steps `3B.1` through `3B.6`)

## Structural Patterns

All stage files (stages 1-6) follow this structure:
1. YAML frontmatter with `stage` name and `artifacts_written` list
2. **CRITICAL RULES** section at top (attention-favored position)
3. Numbered steps for execution
4. Summary Contract (YAML template)
5. **Self-Verification** checklist (mandatory before writing summary)
6. **CRITICAL RULES REMINDER** at bottom (attention-favored position)

**Max-rules guidance:** Keep CRITICAL RULES sections to **5-7 rules maximum** per stage file. More than 7 rules dilutes the attention benefit of the bookend pattern.
