# Skill Analyzer — Reference Files

## File Usage Table

| File | Purpose | Loaded By | When |
|------|---------|-----------|------|
| `lens-config.md` | Default + optional lens definitions, fallback criteria, override mechanism | Orchestrator (SKILL.md Step 4) | Always |
| `sub-agent-prompt-template.md` | Parameterized prompt template for each lens sub-agent | Orchestrator (SKILL.md Step 5) | Always |
| `synthesis-rules.md` | Deduplication, priority assignment, scoring, plan construction | Orchestrator (SKILL.md Step 7) | Always |
| `report-template.md` | Output report markdown structure | Orchestrator (SKILL.md Step 8) | Always |
| `config/skill-analyzer-config.yaml` | Centralized thresholds, weights, and token budgets | Orchestrator (Steps 4, 7) | Always |
| `examples/sample-review-report.md` | Completed example of a 7-lens review report | Reference | On request |
| `README.md` | This file — reference index and cross-reference map | Maintainers | On request |

## File Sizes

| File | Lines | Approximate Words |
|------|-------|-------------------|
| `lens-config.md` | ~270 | ~1400 |
| `sub-agent-prompt-template.md` | ~150 | ~600 |
| `synthesis-rules.md` | ~130 | ~600 |
| `report-template.md` | ~130 | ~500 |
| `config/skill-analyzer-config.yaml` | ~50 | ~200 |
| `examples/sample-review-report.md` | ~140 | ~700 |
| `README.md` | ~55 | ~300 |

## Cross-References

| Source File | References To | Relationship |
|-------------|---------------|--------------|
| SKILL.md | lens-config.md | Loads lens definitions in Step 4 |
| SKILL.md | sub-agent-prompt-template.md | Loads prompt template in Step 5 |
| SKILL.md | synthesis-rules.md | Applies synthesis rules in Step 7 |
| SKILL.md | report-template.md | Uses report template in Step 8 |
| SKILL.md | config/skill-analyzer-config.yaml | References thresholds and constraints |
| SKILL.md | examples/sample-review-report.md | Example output (on request) |
| sub-agent-prompt-template.md | lens-config.md | Variables sourced from lens definitions |
| synthesis-rules.md | config/skill-analyzer-config.yaml | Weights and thresholds sourced from config |
| synthesis-rules.md | report-template.md | Passes synthesized data to report template |
| report-template.md | (none) | Terminal output — no outgoing references |
| lens-config.md | (none) | Source data — no outgoing references |
| config/skill-analyzer-config.yaml | (none) | Source config — no outgoing references |
| examples/sample-review-report.md | (none) | Example output — no outgoing references |

## Data Pipeline

```
config/skill-analyzer-config.yaml
        ↓
lens-config.md → sub-agent-prompt-template.md → [7+ analysis files] → synthesis-rules.md → report-template.md
```

Configurable thresholds are centralized in `config/skill-analyzer-config.yaml`.
