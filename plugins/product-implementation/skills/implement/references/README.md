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
| `skill-resolution.md` | Understanding domain-specific skill resolution algorithm used by Stages 2, 4, 5 |

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
2. Read `stage-1-setup.md` Section 1.8 for state initialization
3. Check `$CLAUDE_PLUGIN_ROOT/templates/implementation-state-template.local.md` for schema

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| `orchestrator-loop.md` | 195 | Dispatch loop, crash recovery, lock release, state migration |
| `stage-1-setup.md` | 289 | Inline setup instructions, domain detection, summary template |
| `stage-2-execution.md` | 217 | Skill resolution, phase loop, execution rules, test count extraction |
| `stage-3-validation.md` | 138 | Validation checks, constitution compliance, coverage delta, Stage 2 cross-validation, report format |
| `stage-4-quality-review.md` | 220 | Skill resolution, review dimensions (base + conditional), severity reclassification, consolidation |
| `stage-5-documentation.md` | 211 | Skill resolution for docs, tech-writer dispatch, lock release |
| `agent-prompts.md` | 257 | All 6 agent prompt templates with `{skill_references}` variable, verified test count, severity escalation |
| `skill-resolution.md` | 87 | Shared skill resolution algorithm for domain-specific skill injection |

## Cross-References

- `orchestrator-loop.md` → referenced by SKILL.md at workflow start
- `stage-1-setup.md` → inline execution, writes first summary
- `stage-2-execution.md` → uses `agent-prompts.md` Phase Implementation Prompt
- `stage-3-validation.md` → uses `agent-prompts.md` Completion Validation Prompt
- `stage-4-quality-review.md` → uses `agent-prompts.md` Quality Review + Review Fix Prompts
- `stage-5-documentation.md` → uses `agent-prompts.md` Incomplete Task Fix + Documentation Update Prompts
- `agent-prompts.md` → referenced by all coordinator stages
- All stages read `config/implementation-config.yaml` for severity levels and lock timeout
- Stages 1, 2, 4, 5 read `config/implementation-config.yaml` `dev_skills` section for domain-to-skill mapping
- `stage-1-setup.md` writes `detected_domains` to Stage 1 summary; consumed by Stages 2, 4, 5 coordinators
- `skill-resolution.md` → shared algorithm referenced by `stage-2-execution.md`, `stage-4-quality-review.md`, `stage-5-documentation.md`
- Dev-skills integration is orchestrator-transparent: only coordinators read/resolve skill references
- Stages 2, 3, 4 propagate verified test counts via summary flags: `test_count_verified` (Stage 2) → `baseline_test_count` (Stage 3) → `test_count_post_fix` (Stage 4)
- `config/implementation-config.yaml` `severity.escalation_triggers` → referenced by `agent-prompts.md` Quality Review Prompt and `stage-4-quality-review.md` Section 4.3 reclassification pass
- `config/implementation-config.yaml` `test_coverage.thresholds` → referenced by `agent-prompts.md` Completion Validation Prompt and `stage-3-validation.md` Section 3.2/3.3
