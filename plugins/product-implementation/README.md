# product-implementation

Execute implementation plans produced by [product-planning](../product-planning). This plugin orchestrates TDD cycles, code generation, quality review, and documentation against the plan using per-phase delivery cycles.

## Installation

```bash
claude plugins add ./plugins/product-implementation
claude plugins enable product-implementation
```

## Plugin Structure

```
product-implementation/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── agents/
│   ├── test-writer.md                 # Spec-to-test translation (Red phase)
│   ├── developer.md                   # Implementation, testing, validation, review
│   ├── output-verifier.md             # Output quality verification (test bodies, spec alignment, DoD)
│   ├── code-simplifier.md             # Post-phase code simplification
│   ├── doc-judge.md                   # Documentation accuracy verification (LLM-as-a-judge)
│   └── tech-writer.md                 # Feature documentation, API guides, architecture updates
├── commands/
│   ├── 04-implement.md                # Legacy command (superseded by implement skill)
│   └── 05-document.md                 # Legacy command (merged into implement skill)
├── config/
│   ├── implementation-config.yaml     # Single source of truth for all configurable values
│   └── cli_clients/                   # CLI agent metadata and role prompts
│       ├── codex.json, gemini.json, opencode.json
│       └── *.txt                      # Role-specific prompt files
├── scripts/
│   ├── dispatch-cli-agent.sh          # Shared CLI dispatch via process-group
│   └── cleanup-orphans.sh             # Orphan sidecar cleanup
├── skills/
│   └── implement/
│       ├── SKILL.md                   # Lean orchestrator (6-stage workflow, per-phase delivery)
│       └── references/                # Stage-specific coordinator instructions (17 files)
│           ├── orchestrator-loop.md   # Dispatch loop, crash recovery, state migration
│           ├── stage-{1-6}-*.md       # Per-stage instructions
│           ├── agent-prompts.md       # 14 prompt templates
│           ├── summary-schemas.md     # YAML schemas for stage summaries
│           └── README.md             # Reference file index with cross-references
├── templates/
│   ├── implementation-state-template.local.md  # State file schema (v3)
│   └── stage-summary-template.md      # Inter-stage summary contract
├── docs/                              # Migration plans, workflow diagrams
├── CLAUDE.md                          # Plugin-specific guidance
└── README.md
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `implement` | 6-stage implementation workflow with per-phase delivery cycles: Setup, Execution, Validation, Quality Review, Documentation, Retrospective | `/product-implementation:implement` |

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `test-writer` | sonnet | Spec-to-test translation (Red phase TDD) |
| `developer` | sonnet | Implementation, testing, validation, code review |
| `output-verifier` | sonnet | Output quality verification (empty test bodies, spec alignment, DoD compliance) |
| `code-simplifier` | sonnet | Post-phase code simplification for clarity and maintainability |
| `doc-judge` | sonnet | Documentation accuracy verification (LLM-as-a-judge) |
| `tech-writer` | sonnet | Feature documentation, API guides, architecture updates, retrospective |

## Relationship to Other Plugins

| Phase | Plugin | Output |
|-------|--------|--------|
| Definition | product-definition | PRD, specifications, test-strategy.md |
| Planning | product-planning | design.md, plan.md, tasks.md, test-plan.md |
| **Implementation** | **product-implementation** | **Production code, tests, documentation** |

## License

MIT
