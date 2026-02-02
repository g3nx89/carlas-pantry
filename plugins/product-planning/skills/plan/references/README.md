# Reference Files Index

Quick guide to when to read each reference file during skill development or debugging.

## Reference File Usage

| File | Read When... |
|------|--------------|
| `research-mcp-patterns.md` | Using Context7/Ref/Tavily MCP servers; optimizing research queries |
| `self-critique-template.md` | Creating or modifying agents; need to add self-verification |
| `cot-prefix-template.md` | Adding reasoning approach to agent prompts |
| `judge-gate-rubrics.md` | Understanding quality gate scoring; debugging PASS/FAIL decisions |
| `adaptive-strategy-logic.md` | Debugging S4 adaptive strategy selection issues |
| `tot-workflow.md` | Working on Complete mode architecture (S5 Tree-of-Thoughts) |
| `debate-protocol.md` | Working on S6 multi-judge debate validation |
| `phase-workflows.md` | Understanding full workflow steps; debugging phase transitions |
| `thinkdeep-prompts.md` | Customizing PAL ThinkDeep perspective prompts |
| `validation-rubric.md` | Understanding Phase 6 plan validation scoring |
| `coverage-validation-rubric.md` | Understanding Phase 8 test coverage validation |
| `v-model-methodology.md` | Understanding test level mapping and V-Model alignment |

## By Task

### Using Research MCP Servers
1. Read `research-mcp-patterns.md` for server selection and query patterns
2. Check `phase-workflows.md` for Step 2.1c, 4.0, 7.1b integration points

### Adding a New Agent
1. Read `self-critique-template.md` for verification section
2. Read `cot-prefix-template.md` for reasoning approach
3. Read `research-mcp-patterns.md` if agent uses research MCP servers

### Debugging Quality Gates
1. Read `judge-gate-rubrics.md` for scoring criteria
2. Read `adaptive-strategy-logic.md` if strategy selection fails

### Modifying the Workflow
1. Read `phase-workflows.md` for complete step-by-step
2. Check specific phase references as needed

### Working on Test Planning
1. Read `v-model-methodology.md` for test level definitions
2. Read `coverage-validation-rubric.md` for validation scoring

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `phase-workflows.md` | ~1200 | Complete workflow reference (largest) |
| `research-mcp-patterns.md` | ~350 | Research MCP server usage guide |
| `judge-gate-rubrics.md` | ~200 | Gate evaluation criteria |
| `self-critique-template.md` | ~130 | Agent verification template |
| `tot-workflow.md` | ~150 | Tree-of-Thoughts process |
| `debate-protocol.md` | ~120 | Multi-round debate structure |
| Others | <100 | Focused reference content |

## Cross-References

- `phase-workflows.md` references most other files
- `research-mcp-patterns.md` used by `researcher` agent and Phase 2/4/7 workflows
- `judge-gate-rubrics.md` used by `phase-gate-judge` agent
- `self-critique-template.md` used by all agents
- `debate-protocol.md` used by `debate-judge` agent
