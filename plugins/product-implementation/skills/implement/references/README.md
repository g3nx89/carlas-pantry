# Reference Files Index

Quick guide to when to read each reference file during skill development or debugging.

## Reference File Usage

| File | Read When... |
|------|--------------|
| `orchestrator-loop.md` | Understanding dispatch loop, crash recovery, state migration, delegation ADR, or context pack protocol |
| `stage-1-setup.md` | Debugging setup, branch parsing, lock acquisition, or state initialization |
| `stage-2-execution.md` | Debugging phase-by-phase execution, task parsing, or TDD enforcement |
| `stage-3-validation.md` | Debugging completion validation, spec alignment, or test coverage checks |
| `stage-4-quality-review.md` | Debugging quality review, three-tier architecture, finding consolidation, confidence scoring, stances, convergence detection, or CoVe |
| `stage-4-plugin-review.md` | Understanding Tier B plugin-based review (code-review skill integration) |
| `stage-4-cli-review.md` | Understanding Tier C CLI multi-model review (Phase 1/2 dispatch, pattern search) |
| `stage-5-documentation.md` | Debugging documentation generation, tech-writer dispatch, or lock release |
| `agent-prompts.md` | Modifying agent prompt templates or adding new prompt types |
| `auto-commit-dispatch.md` | Understanding shared auto-commit procedure, exclude pattern matching, or batch strategy |
| `skill-resolution.md` | Understanding domain-specific skill resolution algorithm used by Stages 2, 4, 5 |
| `cli-dispatch-procedure.md` | Understanding shared CLI dispatch, timeout, parsing, fallback algorithm, or circuit breaker gate |
| `stage-6-retrospective.md` | Debugging retrospective generation, KPI compilation, transcript extraction, or tech-writer dispatch |

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
| `orchestrator-loop.md` | 258 | Dispatch loop, crash recovery, lock release, state migration, late notification handling, autonomy policy infrastructure checks, context pack protocol |
| `stage-1-setup.md` | 594 | Inline setup instructions, domain detection, MCP availability probing (1.6a-1.6d), mobile device availability (1.6e), plugin availability check (1.6f), CLI circuit breaker initialization (1.7b), CLI availability detection with dispatch script smoke test (1.7a), autonomy policy selection (1.9a), context contributions initialization, summary template |
| `stage-2-execution.md` | ~660 | Skill resolution, research context resolution (2.0a), phase loop, CLI test author (Step 1.8), code simplification (Step 3.5), OpenCode UX test review (Step 3.6), UAT mobile testing (Step 3.7) with non-skippable gate check, CLI test augmenter (2.1a), auto-commit per phase, batch strategy, execution rules, build verification, build error smart resolution, test count extraction, cli_dispatch_metrics, circuit state propagation, context contributions, autonomy policy checks |
| `stage-3-validation.md` | ~240 | Validation checks, CLI spec validator (3.1a), OpenCode UX validator (3.1b), constitution compliance, coverage delta, API doc alignment (check 12), Stage 2 cross-validation, test quality gate, report format, circuit state propagation, context contributions, autonomy policy check (3.4) |
| `stage-4-quality-review.md` | 467 | Three-tier review architecture (Tier A native, Tier B plugin, Tier C CLI), Tier A native multi-agent review, stance assignment (4.2), convergence detection (4.3a), confidence scoring with outcome logging, severity reclassification (with intentional bypass note), stance divergence analysis (4.3), CoVe post-synthesis (4.3b), finding consolidation, auto-decision matrix with autonomy policy extension (4.4), CLI fix engineer (Option F), auto-commit on fix |
| `stage-4-plugin-review.md` | 69 | Tier B: Plugin-based review via code-review skill, config-driven CEK confidence normalization, max findings cap, graceful degradation |
| `stage-4-cli-review.md` | ~130 | Tier C: CLI multi-model review, Phase 1 parallel dispatch (correctness, security, android domain, UX/accessibility), Phase 2 sequential pattern search (Gemini 1M context), consolidation checkpoint |
| `stage-5-documentation.md` | ~300 | Skill resolution for docs, research context for documentation (5.1b), tech-writer dispatch, OpenCode doc review (5.2a), auto-commit documentation, lock release, context contributions, autonomy policy check for incomplete tasks (5.1) |
| `agent-prompts.md` | 541 | All 9 agent prompt templates (8 agent + 1 auto-commit) with `{skill_references}`, `{research_context}`, and `{reviewer_stance}` variables, verified test count, severity escalation, R-REV-01 pattern propagation, build verification, API verification, test quality, animation testing, code simplification, retrospective composition |
| `auto-commit-dispatch.md` | 62 | Shared parameterized auto-commit procedure, exclude pattern semantics, batch strategy |
| `skill-resolution.md` | 87 | Shared skill resolution algorithm for domain-specific skill injection |
| `cli-dispatch-procedure.md` | 207 | Shared parameterized CLI dispatch via Bash process-group dispatch, 4-tier output parsing, expected-fields validation, metrics sidecar, exit codes 0-4, UUID output filenames, variable injection convention, circuit breaker pre/post-step, fallback procedure |
| `stage-6-retrospective.md` | 350 | KPI Report Card compilation (10 Phase 1 KPIs), Phase 2 KPI placeholders (CoVe effectiveness, reviewer convergence, circuit breaker trips), cli_dispatch_metrics aggregation, sidecar cleanup, session transcript extraction (conditional), retrospective composition via tech-writer, auto-commit, context contributions, state update |

## Cross-References

- `orchestrator-loop.md` → referenced by SKILL.md at workflow start
- `stage-1-setup.md` → inline execution, writes first summary
- `stage-2-execution.md` → uses `agent-prompts.md` Phase Implementation Prompt + Code Simplification Prompt
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
- `auto-commit-dispatch.md` → shared procedure referenced by `stage-2-execution.md` Step 4.5, `stage-4-quality-review.md` Section 4.4 step 6, `stage-5-documentation.md` Section 5.3a, `stage-6-retrospective.md` Section 6.5
- `config/implementation-config.yaml` `auto_commit` → referenced by `auto-commit-dispatch.md` procedure, `agent-prompts.md` Auto-Commit Prompt, and all 3 calling stage files via the shared procedure
- `config/implementation-config.yaml` `test_coverage.tautological_patterns` → referenced by `stage-3-validation.md` Section 3.2 check 11 and `agent-prompts.md` Quality Review Prompt step 5
- `config/implementation-config.yaml` `severity.auto_decision` (`auto_accept_low_only`) → referenced by `stage-4-quality-review.md` Section 4.4 auto-decision logic
- `config/implementation-config.yaml` `timestamps` → referenced by `stage-2-execution.md` Section 2.3 and all stage log templates
- `stage-4-plugin-review.md` → Tier B procedure; is Section 4.2a in `stage-4-quality-review.md`
- `stage-4-cli-review.md` → Tier C procedure; is Section 4.2b in `stage-4-quality-review.md`; uses `cli-dispatch-procedure.md` for all dispatches
- `cli-dispatch-procedure.md` → shared procedure referenced by `stage-2-execution.md` (Steps 1.8, 2.1a, 3.7), `stage-3-validation.md` (Section 3.1a), `stage-4-cli-review.md` (all Tier C dispatches), `stage-4-quality-review.md` (Section 4.4)
- `config/cli_clients/shared/severity-output-conventions.md` → injected into all CLI role prompts at dispatch time by coordinators
- `config/implementation-config.yaml` `cli_dispatch` → referenced by `cli-dispatch-procedure.md`, `stage-1-setup.md` Section 1.7a (CLI detection), and all stage files with CLI integration points
- `stage-1-setup.md` writes `cli_availability` to Stage 1 summary; consumed by Stages 2, 3, 4 coordinators for CLI dispatch gating
- `stage-1-setup.md` writes `plugin_availability` to Stage 1 summary (Section 1.6f); consumed by `stage-4-plugin-review.md` for Tier B detection
- `config/implementation-config.yaml` `cli_dispatch.non_skippable_gates` → referenced by `stage-2-execution.md` Step 3.7 (non-skippable gate check)
- `config/implementation-config.yaml` `cli_dispatch.stage4.review_plugins.confidence_mapping` → canonical source for `stage-4-plugin-review.md` normalization thresholds
- CLI integration is orchestrator-transparent: only coordinators and Stage 1 (inline) read CLI config; orchestrator never sees CLI
- `stage-2-execution.md` writes `augmentation_bugs_found` to Stage 2 summary flags (from CLI test augmenter, Section 2.1a)
- `stage-2-execution.md` writes `cli_dispatch_metrics` to Stage 2 summary flags (aggregated from `.metrics.json` sidecars); consumed by `stage-6-retrospective.md` KPI data layer
- `config/implementation-config.yaml` `cli_dispatch.instrumentation` → referenced by `stage-6-retrospective.md` Section 6.6 (sidecar cleanup)
- `config/implementation-config.yaml` `cli_dispatch.stage4.confidence_scoring` → referenced by `stage-4-quality-review.md` Section 4.3
- `config/implementation-config.yaml` `cli_dispatch.stage4.pattern_search` → referenced by `stage-4-cli-review.md` Phase 2 gate
- `config/implementation-config.yaml` `cli_dispatch.stage4.review_plugins` → referenced by `stage-4-plugin-review.md` max findings cap
- `stage-2-execution.md` Step 3.5 uses `agent-prompts.md` Code Simplification Prompt; dispatches `agents/code-simplifier.md`
- `config/implementation-config.yaml` `code_simplification` → referenced by `stage-2-execution.md` Step 3.5
- `stage-2-execution.md` writes `simplification_stats` to Stage 2 summary flags (from code-simplifier, Step 3.5)
- `stage-2-execution.md` Step 3.7 uses `cli-dispatch-procedure.md` for UAT CLI dispatch to Gemini
- `config/implementation-config.yaml` `cli_dispatch.stage2.uat_mobile_tester` → referenced by `stage-2-execution.md` Step 3.7
- `config/implementation-config.yaml` `uat_execution` → referenced by `stage-1-setup.md` Section 1.6e, `stage-2-execution.md` Step 3.7
- `stage-1-setup.md` writes `mobile_mcp_available` and `mobile_device_name` to Stage 1 summary; consumed by Stage 2 coordinator for UAT gating
- `stage-2-execution.md` writes `uat_results` to Stage 2 summary flags (from UAT mobile tester, Step 3.7)
- `config/cli_clients/gemini_uat_mobile_tester.txt` → role prompt for Option J UAT mobile tester CLI dispatch
- UAT mobile testing is orchestrator-transparent: Stage 1 (inline) probes mobile-mcp, Stage 2 coordinator handles build/install/dispatch; orchestrator never touches UAT
- `config/implementation-config.yaml` `autonomy_policy` → referenced by `stage-1-setup.md` Section 1.9a, `orchestrator-loop.md` (infrastructure failures), `stage-2-execution.md` (Steps 3.5, 3.7), `stage-3-validation.md` (Section 3.4), `stage-4-quality-review.md` (Section 4.4), `stage-5-documentation.md` (Section 5.1)
- `stage-1-setup.md` writes `autonomy_policy` to Stage 1 summary; consumed by orchestrator and all downstream coordinators
- Autonomy policy auto-resolution is logged with `[AUTO-{policy}]` prefix in all stage logs for traceability
- `stage-6-retrospective.md` → uses `agent-prompts.md` Retrospective Composition Prompt, `auto-commit-dispatch.md` Section 6.5
- `stage-6-retrospective.md` reads all 5 prior stage summaries for KPI compilation and narrative context
- `stage-6-retrospective.md` reads `[AUTO-{policy}]` entries from all stage logs for KPI 5.2 (Auto-Resolution Count)
- `config/implementation-config.yaml` `retrospective` → referenced by `stage-6-retrospective.md` Sections 6.1, 6.3, 6.4
- `config/implementation-config.yaml` `auto_commit.message_templates.retrospective` → referenced by `stage-6-retrospective.md` Section 6.5 via shared auto-commit procedure
- `config/implementation-config.yaml` `auto_commit.exclude_patterns` includes `.implementation-report-card` and `transcript-extract.json` for Stage 6 local artifacts
- Stage 6 runs post-lock-release: lock was released in Stage 5, Stage 6 is read-only analysis
- Stage 6 produces `.implementation-report-card.local.md` (KPI Report Card) and `retrospective.md` (narrative); transcript-extract.json is intermediate
- `config/implementation-config.yaml` `quality_review.cove` → referenced by `stage-4-quality-review.md` Section 4.3b (CoVe post-synthesis)
- `config/implementation-config.yaml` `quality_review.stances` → referenced by `stage-4-quality-review.md` Section 4.2 (stance assignment), `agent-prompts.md` Quality Review Prompt (`{reviewer_stance}` variable)
- `config/implementation-config.yaml` `quality_review.convergence` → referenced by `stage-4-quality-review.md` Section 4.3a (convergence detection)
- `config/implementation-config.yaml` `cli_dispatch.circuit_breaker` → referenced by `stage-1-setup.md` Section 1.7b (initialization), `cli-dispatch-procedure.md` Pre-Step/Post-Step (gate + update)
- `config/implementation-config.yaml` `context_protocol` → referenced by `orchestrator-loop.md` DISPATCH_COORDINATOR (context pack builder)
- `stage-1-setup.md` writes `cli_circuit_state` to Stage 1 summary (Section 1.7b); propagated through Stages 2, 3, 4 via summary flags, updated by CLI dispatches
- `stage-1-setup.md` writes initial `context_contributions` to Stage 1 summary; accumulated across all stages via `orchestrator-loop.md` context pack builder
- `agent-prompts.md` `{reviewer_stance}` variable in Quality Review Prompt with explicit fallback default
- OpenCode CLI integration is orchestrator-transparent: only coordinators and Stage 1 (inline) detect availability; orchestrator never sees OpenCode
- `config/cli_clients/opencode.json` → OpenCode CLI metadata with 4 roles: `ux_test_reviewer`, `ux_validator`, `ux_reviewer`, `doc_reviewer`
- `config/cli_clients/opencode_ux_test_reviewer.txt` → role prompt for Option K UX test coverage review (Stage 2 Step 3.6)
- `config/cli_clients/opencode_ux_validator.txt` → role prompt for Option D UX completeness validation (Stage 3 Section 3.1b)
- `config/cli_clients/opencode_ux_reviewer.txt` → role prompt for Tier C UX/accessibility code review (Stage 4 Phase 1)
- `config/cli_clients/opencode_doc_reviewer.txt` → role prompt for Option L documentation quality review (Stage 5 Section 5.2a)
- `config/implementation-config.yaml` `cli_dispatch.stage2.ux_test_reviewer` → referenced by `stage-2-execution.md` Step 3.6
- `config/implementation-config.yaml` `cli_dispatch.stage3.ux_validator` → referenced by `stage-3-validation.md` Section 3.1b
- `config/implementation-config.yaml` `cli_dispatch.stage4.multi_model_review.conditional` includes OpenCode `ux_reviewer` for UI domains
- `config/implementation-config.yaml` `cli_dispatch.stage5.doc_reviewer` → referenced by `stage-5-documentation.md` Section 5.2a
- `stage-1-setup.md` writes `cli_availability.opencode` to Stage 1 summary (auto-detected when any OpenCode option is enabled); consumed by Stages 2, 3, 4, 5 coordinators
- `stage-2-execution.md` Step 3.6 uses `cli-dispatch-procedure.md` for OpenCode UX test review dispatch
- `stage-3-validation.md` Section 3.1b uses `cli-dispatch-procedure.md` for OpenCode UX validation dispatch
- `stage-4-cli-review.md` includes OpenCode `ux_reviewer` as conditional Phase 1 reviewer alongside security and android domain reviewers
- `stage-5-documentation.md` Section 5.2a uses `cli-dispatch-procedure.md` for OpenCode doc review dispatch; can trigger one tech-writer revision cycle
