# Reference Files Index

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Start of orchestration — dispatch loop, iteration logic, crash recovery |
| `stage-1-setup.md` | Stage 1 inline execution — init, MCP check, workspace, mode selection |
| `stage-2-research.md` | Dispatching Stage 2 — research agenda generation and synthesis |
| `stage-3-analysis-questions.md` | Dispatching Stage 3 — ThinkDeep, MPA agents, question generation |
| `stage-4-response-analysis.md` | Dispatching Stage 4 — response parsing, gap analysis, iteration decision |
| `stage-5-validation-generation.md` | Dispatching Stage 5 — PRD readiness validation and generation |
| `stage-6-completion.md` | Dispatching Stage 6 — completion report, lock release, next steps |
| `checkpoint-protocol.md` | Any checkpoint — state update patterns and immutable decision rules |
| `error-handling.md` | Any error condition — PAL failures, graceful degradation, recovery |
| `config-reference.md` | PAL tool usage — template variables, PAL patterns, scoring thresholds |
| `option-generation-reference.md` | Stage 3 question gen — option format, scoring algorithm, merging logic |

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | ~270 | Dispatch loop, iteration, crash recovery, state migration |
| `stage-1-setup.md` | ~270 | Inline setup: init, workspace, mode selection |
| `stage-2-research.md` | ~155 | Research coordinator: agenda + synthesis |
| `stage-3-analysis-questions.md` | ~340 | Analysis + question generation (largest) |
| `stage-4-response-analysis.md` | ~215 | Response parsing + gap analysis |
| `stage-5-validation-generation.md` | ~200 | Validation + PRD generation |
| `stage-6-completion.md` | ~105 | Completion: report, lock release |
| `checkpoint-protocol.md` | ~50 | State update patterns |
| `error-handling.md` | ~110 | Error recovery procedures |
| `config-reference.md` | ~265 | Template vars, PAL patterns, scoring |
| `option-generation-reference.md` | ~300 | Question/option format specification |

## Cross-References

### Stage Files -> Shared References

- All stage files reference `checkpoint-protocol.md` for state updates
- All stage files reference `error-handling.md` for failure recovery
- `stage-3-analysis-questions.md` references `option-generation-reference.md` for scoring algorithms
- `stage-3-analysis-questions.md` references `config-reference.md` for ThinkDeep PAL patterns
- `stage-4-response-analysis.md` references `config-reference.md` for Consensus PAL patterns
- `stage-5-validation-generation.md` references `config-reference.md` for scoring thresholds

### Orchestrator -> Stage Files

- `orchestrator-loop.md` references all 6 stage files in dispatch order
- `orchestrator-loop.md` references `checkpoint-protocol.md` for crash recovery

### External References

- All files reference `$CLAUDE_PLUGIN_ROOT/config/requirements-config.yaml` for configuration
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/requirements-*.md`
- Stage files reference agents at `$CLAUDE_PLUGIN_ROOT/agents/research-discovery-*.md`
- Stage files reference templates at `$CLAUDE_PLUGIN_ROOT/templates/`
