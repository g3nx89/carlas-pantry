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
| `auto-commit-dispatch.md` | Understanding shared auto-commit procedure, exclude pattern matching, or batch strategy |
| `skill-resolution.md` | Understanding domain-specific skill resolution algorithm used by Stages 2, 4, 5 |
| `clink-dispatch-procedure.md` | Understanding shared clink dispatch, timeout, parsing, fallback algorithm |

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
| `orchestrator-loop.md` | 210 | Dispatch loop, crash recovery, lock release, state migration, late notification handling |
| `stage-1-setup.md` | 450 | Inline setup instructions, domain detection, MCP availability probing (1.6a-1.6d), CLI availability detection (1.7a), summary template |
| `stage-2-execution.md` | 378 | Skill resolution, research context resolution (2.0a), phase loop, clink test author (Step 1.8), clink test augmenter (2.1a), auto-commit per phase, batch strategy, execution rules, build verification, build error smart resolution, test count extraction |
| `stage-3-validation.md` | 181 | Validation checks, clink spec validator (3.1a), constitution compliance, coverage delta, API doc alignment (check 12), Stage 2 cross-validation, test quality gate, report format |
| `stage-4-quality-review.md` | 340 | Skill resolution, research context for review (4.1b), review dimensions (base + conditional), clink multi-model review (4.2a), clink security reviewer (Option E), clink fix engineer (Option F), severity reclassification, consolidation, auto-decision matrix, auto-commit on fix |
| `stage-5-documentation.md` | 249 | Skill resolution for docs, research context for documentation (5.1b), tech-writer dispatch, auto-commit documentation, lock release |
| `agent-prompts.md` | 358 | All 7 agent prompt templates (6 agent + 1 auto-commit) with `{skill_references}` and `{research_context}` variables, verified test count, severity escalation, build verification, API verification, test quality, animation testing, pattern propagation |
| `auto-commit-dispatch.md` | 61 | Shared parameterized auto-commit procedure, exclude pattern semantics, batch strategy |
| `skill-resolution.md` | 87 | Shared skill resolution algorithm for domain-specific skill injection |
| `clink-dispatch-procedure.md` | 133 | Shared parameterized clink dispatch, timeout, parsing, variable injection convention, fallback procedure |

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
- Research MCP integration is orchestrator-transparent: Stage 1 (inline) probes availability, coordinators build `{research_context}`, agents make on-demand MCP calls
- `config/implementation-config.yaml` `research_mcp` → referenced by `stage-1-setup.md` Sections 1.6a-1.6d, `stage-2-execution.md` Section 2.0a, `stage-3-validation.md` Section 3.1, `stage-4-quality-review.md` Section 4.1b, `stage-5-documentation.md` Section 5.1b
- `stage-1-setup.md` writes `mcp_availability`, `extracted_urls`, `resolved_libraries`, `private_doc_urls` to Stage 1 summary; consumed by all downstream coordinators
- `stage-2-execution.md` writes `research_urls_discovered` to Stage 2 summary flags (session accumulation); consumed by Stages 4, 5
- `agent-prompts.md` `{research_context}` variable in 4 prompts (Phase Implementation, Completion Validation, Quality Review, Documentation Update) with explicit fallback defaults
- `agents/developer.md` and `agents/tech-writer.md` have Research MCP Awareness sections for optional `## Research Context` injection
- Stages 2, 3, 4 propagate verified test counts via summary flags: `test_count_verified` (Stage 2) → `baseline_test_count` (Stage 3) → `test_count_post_fix` (Stage 4)
- `config/implementation-config.yaml` `severity.escalation_triggers` → referenced by `agent-prompts.md` Quality Review Prompt and `stage-4-quality-review.md` Section 4.3 reclassification pass
- `config/implementation-config.yaml` `test_coverage.thresholds` → referenced by `agent-prompts.md` Completion Validation Prompt and `stage-3-validation.md` Section 3.2/3.3
- `auto-commit-dispatch.md` → shared procedure referenced by `stage-2-execution.md` Step 4.5, `stage-4-quality-review.md` Section 4.4 step 6, `stage-5-documentation.md` Section 5.3a
- `config/implementation-config.yaml` `auto_commit` → referenced by `auto-commit-dispatch.md` procedure, `agent-prompts.md` Auto-Commit Prompt, and all 3 calling stage files via the shared procedure
- `config/implementation-config.yaml` `test_coverage.tautological_patterns` → referenced by `stage-3-validation.md` Section 3.2 check 11 and `agent-prompts.md` Quality Review Prompt step 5
- `config/implementation-config.yaml` `severity.auto_decision` (`auto_accept_low_only`) → referenced by `stage-4-quality-review.md` Section 4.4 auto-decision logic
- `config/implementation-config.yaml` `timestamps` → referenced by `stage-2-execution.md` Section 2.3 and all stage log templates
- `clink-dispatch-procedure.md` → shared procedure referenced by `stage-2-execution.md` (Steps 1.8, 2.1a), `stage-3-validation.md` (Section 3.1a), `stage-4-quality-review.md` (Section 4.2a, 4.4)
- `config/cli_clients/shared/severity-output-conventions.md` → injected into all clink role prompts at dispatch time by coordinators
- `config/implementation-config.yaml` `clink_dispatch` → referenced by `clink-dispatch-procedure.md`, `stage-1-setup.md` Section 1.7a (CLI detection), and all stage files with clink integration points
- `stage-1-setup.md` writes `cli_availability` to Stage 1 summary; consumed by Stages 2, 3, 4 coordinators for clink dispatch gating
- Clink integration is orchestrator-transparent: only coordinators and Stage 1 (inline) read clink config; orchestrator never sees clink
- `stage-2-execution.md` writes `augmentation_bugs_found` to Stage 2 summary flags (from clink test augmenter, Section 2.1a)
