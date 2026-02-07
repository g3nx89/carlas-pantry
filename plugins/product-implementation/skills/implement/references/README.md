# Reference Files Index

Quick guide to when to read each reference file during skill development or debugging.

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Understanding dispatch loop, crash recovery, state migration, or delegation ADR |
| `stage-1-setup.md` | Debugging setup, branch parsing, lock acquisition, or state initialization |
| `stage-2-execution.md` | Debugging phase-by-phase execution, task parsing, or TDD enforcement |
| `stage-3-validation.md` | Debugging completion validation, spec alignment, or test coverage checks |
| `stage-4-quality-review.md` | Debugging quality review, finding consolidation, or review strategy selection |
| `stage-5-documentation.md` | Debugging documentation generation, tech-writer dispatch, or lock release |
| `agent-prompts.md` | Modifying agent prompt templates or adding new prompt types |

## By Task

### Understanding the Delegation Architecture
1. Read `orchestrator-loop.md` for dispatch loop and recovery
2. Read any per-stage file for that stage's complete instructions

### Debugging a Specific Stage
1. Read the corresponding `stage-{N}-*.md` file
2. Read `agent-prompts.md` for the prompt template used by that stage
3. Check `orchestrator-loop.md` if the issue is in dispatch or summary handling

### Adding a New Stage
1. Read `orchestrator-loop.md` for the dispatch pattern
2. Copy an existing `stage-{N}-*.md` as a template (use YAML frontmatter)
3. Add entry to SKILL.md Stage Dispatch Table
4. Add prompt template to `agent-prompts.md`

### Working on State Management
1. Read `orchestrator-loop.md` for v1-to-v2 migration
2. Read `stage-1-setup.md` Section 1.7 for state initialization
3. Check `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md` for schema

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | 195 | Dispatch loop, crash recovery, lock release, state migration |
| `stage-1-setup.md` | 257 | Inline setup instructions with summary template |
| `stage-2-execution.md` | 166 | Phase loop and execution rules |
| `stage-3-validation.md` | 123 | Validation checks and report format |
| `stage-4-quality-review.md` | 159 | Review dimensions, consolidation, user decision |
| `stage-5-documentation.md` | 182 | Tech-writer dispatch, lock release |
| `agent-prompts.md` | 221 | All 6 agent prompt templates |

## Cross-References

- `orchestrator-loop.md` → referenced by SKILL.md at workflow start
- `stage-1-setup.md` → inline execution, writes first summary
- `stage-2-execution.md` → uses `agent-prompts.md` Phase Implementation Prompt
- `stage-3-validation.md` → uses `agent-prompts.md` Completion Validation Prompt
- `stage-4-quality-review.md` → uses `agent-prompts.md` Quality Review + Review Fix Prompts
- `stage-5-documentation.md` → uses `agent-prompts.md` Incomplete Task Fix + Documentation Update Prompts
- `agent-prompts.md` → referenced by all coordinator stages
- All stages read `config/implementation-config.yaml` for severity levels and lock timeout
