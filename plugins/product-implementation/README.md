# product-implementation

Execute implementation plans produced by [product-planning](../product-planning). This plugin orchestrates TDD cycles, code generation, quality review, and documentation against the plan.

## Installation

```bash
claude plugins add ./plugins/product-implementation
claude plugins enable product-implementation
```

## Plugin Structure

```
product-implementation/
├── .claude-plugin/
│   └── plugin.json                  # Plugin manifest
├── agents/
│   ├── developer.md                 # Senior Software Engineer (TDD, implementation, review)
│   └── tech-writer.md               # Technical Documentation Specialist
├── commands/
│   ├── 04-implement.md              # Legacy command (superseded by implement skill)
│   └── 05-document.md               # Legacy command (merged into implement skill)
├── config/
│   └── implementation-config.yaml   # Configuration values (lock timeout, severity defs)
├── skills/
│   └── implement/
│       ├── SKILL.md                 # Orchestrator (5-stage workflow)
│       └── references/
│           ├── setup-and-context.md
│           ├── execution-and-validation.md
│           ├── quality-review.md
│           ├── documentation.md
│           └── agent-prompts.md
├── templates/
│   └── implementation-state-template.local.md
└── README.md
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `implement` | 5-stage implementation workflow: Setup, Execution, Validation, Quality Review, Documentation | `/product-implementation:implement` |

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `developer` | opus | Implementation, testing, validation, code review |
| `tech-writer` | sonnet | Feature documentation, API guides, architecture updates |

## Relationship to Other Plugins

| Phase | Plugin | Output |
|-------|--------|--------|
| Definition | product-definition | PRD, specifications, test-strategy.md |
| Planning | product-planning | design.md, plan.md, tasks.md, test-plan.md |
| **Implementation** | **product-implementation** | **Production code, tests, documentation** |

## License

MIT
