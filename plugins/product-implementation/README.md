# product-implementation

Configure projects for autonomous implementation of development plans produced by [product-planning](../product-planning). Two complementary skills: **harness** sets up the environment, **implement** provides the session protocol.

## Installation

```bash
claude plugins add ./plugins/product-implementation
claude plugins enable product-implementation
```

## Plugin Structure

```
product-implementation/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest (v6.0.0)
├── agents/
│   ├── shared/
│   │   └── developer-core-instructions.md  # Core engineering process (read by developer-family agents)
│   ├── android-developer.md           # Android/Kotlin/Compose specialist
│   ├── backend-developer.md           # Backend/API/database specialist
│   ├── code-simplifier.md             # Post-implementation code cleanup
│   ├── debugger.md                    # Systematic bug diagnosis
│   ├── developer.md                   # Generic implementation (fallback)
│   ├── frontend-developer.md          # Frontend/web specialist
│   ├── integration-test-writer.md     # E2E and integration tests
│   ├── tech-writer.md                 # Feature documentation
│   ├── test-writer.md                 # Unit test Red phase
│   └── uat-tester.md                  # UAT mobile testing via MCP
├── commands/
│   └── ralph-implement.md             # Autonomous implementation via Ralph loop
├── skills/
│   ├── harness/
│   │   ├── SKILL.md                   # Harness configurator (environment setup)
│   │   └── references/                # Templates, schemas, catalogs (7 files)
│   ├── implement/
│   │   └── SKILL.md                   # Session protocol (task loop)
│   ├── code-review/
│   │   └── SKILL.md                   # Two-stage code review
│   ├── tdd/
│   │   └── SKILL.md                   # TDD enforcement
│   └── verification/
│       └── SKILL.md                   # Verification gate
├── CLAUDE.md                          # Plugin-specific guidance
└── README.md
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `harness` | Configure project environment: CLAUDE.md, hooks, feature-list.json, evaluation criteria, CLI review | `/product-implementation:harness` |
| `implement` | Session protocol: startup, task selection, TDD, review, verify, handoff | `/product-implementation:implement` |
| `tdd` | RED-GREEN-REFACTOR cycle with anti-rationalizations | `/product-implementation:tdd` |
| `code-review` | Spec compliance + code quality (two-stage) | `/product-implementation:code-review` |
| `verification` | Evidence-before-claims gate function | `/product-implementation:verification` |

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `developer` | sonnet | Generic implementation (fallback vertical) |
| `android-developer` | sonnet | Android/Kotlin/Compose specialist |
| `frontend-developer` | sonnet | Frontend/web specialist |
| `backend-developer` | sonnet | Backend/API/database specialist |
| `debugger` | sonnet | Systematic bug diagnosis |
| `test-writer` | sonnet | Unit test spec-to-test translation (Red phase) |
| `integration-test-writer` | sonnet | E2E and integration tests |
| `code-simplifier` | sonnet | Post-implementation code cleanup |
| `uat-tester` | sonnet | Interactive UAT via mobile-mcp/Playwright |
| `tech-writer` | sonnet | Feature documentation, API guides |

## Workflow

```
product-planning output (tasks.md + plan.md)
        │
        ▼
  /product-implementation:harness    ← configure once
        │
        ▼
  /product-implementation:implement  ← each coding session
        │
        ▼
  /product-implementation:ralph-implement  ← autonomous loop (optional)
```

## Relationship to Other Plugins

| Phase | Plugin | Output |
|-------|--------|--------|
| Definition | product-definition | PRD, specifications |
| Planning | product-planning | design.md, plan.md, tasks.md, test-plan.md |
| **Implementation** | **product-implementation** | **Production code, tests, documentation** |

## License

MIT
