# Stage Summary YAML Schemas

> Defines the expected YAML structure for all 6 stage summaries.
> When adding or removing summary fields, update this file.
> Referenced by: `orchestrator-loop.md` (summary validation), `stage-1-setup.md` through
> `stage-6-retrospective.md` (each stage writes its summary per these schemas).

## Base Fields (Required — All Stages)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | string | Yes | Stage number as string (e.g., `"3"`) |
| `phase` | string | Conditional | Phase name (e.g., `"Phase 2: Core"`). Present when `phase_scope` is set. |
| `status` | enum | Yes | `completed` \| `needs-user-input` \| `failed` |
| `checkpoint` | string | Yes | Checkpoint name matching dispatch table |
| `artifacts_written` | array | Yes | List of files written (may be empty) |
| `summary` | string | Yes | Non-empty natural-language summary |

## Per-Phase Summary Naming

When `per_phase_review.enabled` is `true`, stages 2-5 produce per-phase summaries:

| Context | File Path Pattern | Example |
|---------|-------------------|---------|
| Per-phase | `phase-{N}-stage-{S}-summary.md` | `phase-2-stage-3-summary.md` |
| Final pass | `final-stage-{S}-summary.md` | `final-stage-4-summary.md` |
| Global (Stages 1, 6) | `stage-{N}-summary.md` | `stage-1-summary.md` |
| Linear mode | `stage-{N}-summary.md` | `stage-3-summary.md` |

Per-phase summaries include the `phase` field in YAML frontmatter. The schema for each stage is identical whether per-phase or full-project — only the scope of checks/review changes.

## Stage 1: Setup & Context Loading

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 1 | Orchestrator |
| `flags.test_cases_available` | boolean | Yes | — | Stage 1 | Stages 2, 3 |
| `project_setup` | map | Yes | `{status: "disabled"}` | Stage 1 | Stages 2, 4, 5 |
| `project_setup.status` | enum | Yes | `"disabled"` | Stage 1 | All stages |
| `project_setup.categories_applied` | array | Yes | `[]` | Stage 1 | Stage 6 |
| `project_setup.categories_skipped` | array | Optional | `[]` | Stage 1 | Stage 6 |
| `project_setup.build_system` | string\|null | Yes | `null` | Stage 1 | Stage 2 |
| `project_setup.build_command` | string\|null | Yes | `null` | Stage 1 | Stage 2 |
| `project_setup.test_command` | string\|null | Yes | `null` | Stage 1 | Stage 2 |
| `project_setup.formatter` | string\|null | Optional | `null` | Stage 1 | Stage 2 |
| `project_setup.active_hooks` | array | Optional | `[]` | Stage 1 | Stage 2 |
| `project_setup.architecture_pattern` | string\|null | Optional | `null` | Stage 1 | Stages 2, 4 |
| `project_setup.detected_languages` | array | Optional | `[]` | Stage 1 | Stages 2, 4, 5 |
| `project_setup.detected_frameworks` | array | Optional | `[]` | Stage 1 | Stages 2, 4, 5 |
| `detected_domains` | array | Yes | `[]` | Stage 1 | Stages 2, 4, 5 |
| `cli_availability` | map | Yes | `{}` | Stage 1 | Stages 2, 3, 4, 5 |
| `mcp_availability` | map | Yes | all false | Stage 1 | Stages 2, 3, 4, 5 |
| `extracted_urls` | array | Optional | `[]` | Stage 1 | Stage 2 |
| `resolved_libraries` | array | Optional | `[]` | Stage 1 | Stages 2, 3, 4 |
| `private_doc_urls` | array | Optional | `[]` | Stage 1 | Stage 2 |
| `figma_available` | boolean | Yes | `false` | Stage 1 | Stages 2, 4 |
| `mobile_mcp_available` | boolean | Yes | `false` | Stage 1 | Stage 2 |
| `mobile_device_name` | string\|null | Yes | `null` | Stage 1 | Stage 2 |
| `engine_strategy` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3 |
| `engine_per_phase` | string\|null | Optional | `null` | Stage 1 | Stage 2 |
| `engine_full_sweep` | string\|null | Optional | `null` | Stage 1 | Stage 3 |
| `figma_refs_dir` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3 |
| `emulator_type` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3 |
| `plugin_availability` | map | Yes | — | Stage 1 | Stage 4 |
| `cli_circuit_state` | map\|null | Optional | `null` | Stage 1 | Stages 2, 3, 4 |
| `context_contributions` | map\|null | Optional | `null` | Stage 1 | Orchestrator |
| `profile` | string | Yes | — | Stage 1 | All stages |
| `autonomy` | string | Yes | — | Stage 1 | All stages |
| `vertical_agent_type` | string | Yes | `"developer"` | Stage 1 | Stages 2, 4 |
| `features` | map | Yes | `{}` | Stage 1 | All stages |
| `features.per_phase_review` | boolean | Yes | `true` | Stage 1 | Orchestrator |
| `features.output_verifier` | boolean | Yes | `true` | Stage 1 | Stage 2 |
| `features.code_simplification` | boolean | Yes | `false` | Stage 1 | Stage 2 |
| `features.uat_execution` | boolean | Yes | `false` | Stage 1 | Stages 2, 3 |
| `features.figma_parity` | boolean | Yes | `false` | Stage 1 | Stage 4 |
| `features.research_mcp` | boolean | Yes | `true` | Stage 1 | Stages 2, 4, 5 |
| `features.project_setup` | boolean | Yes | `false` | Stage 1 | Stage 1b |
| `features.stances` | boolean | Yes | `false` | Stage 1 | Stage 4 |
| `features.convergence` | boolean | Yes | `false` | Stage 1 | Stage 4 |
| `features.cove` | boolean | Yes | `false` | Stage 1 | Stage 4 |
| `features.context_protocol` | boolean | Yes | `false` | Stage 1 | Orchestrator |
| `features.circuit_breaker` | boolean | Yes | `false` | Stage 1 | Stage 1b |
| `features.external_models` | boolean | Yes | `false` | Stage 1 | Stage 1b |
| `features.doc_judge` | boolean | Yes | `false` | Stage 1 | Stage 5 |
| `features.stage5_docs` | boolean | Yes | `true` | Stage 1 | Orchestrator |
| `features.stage6_retro` | boolean | Yes | `true` | Stage 1 | Orchestrator |
| `features.app_launch_gate` | boolean | Yes | `true` | Stage 1 | Orchestrator |
| `cli_features_enabled` | array | Yes | `[]` | Stage 1 | Stages 2, 3, 4, 5 |
| `codex_model` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3, 4, 5 |
| `codex_effort` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3, 4, 5 |
| `uat_strategy` | string\|null | Optional | `null` | Stage 1 | Stages 2, 3 |
| `uat_engine_per_phase` | string\|null | Optional | `null` | Stage 1 | Stage 2 |
| `uat_engine_full_sweep` | string\|null | Optional | `null` | Stage 1 | Stage 3 |

## Stage 2: Phase-by-Phase Execution

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 2 | Orchestrator |
| `flags.vertical_agent_type` | string | Yes | `"developer"` | Stage 2 | Stages 4, 6 |
| `flags.test_count_verified` | integer\|null | Yes | `null` | Stage 2 | Stage 3 |
| `flags.commits_made` | array | Yes | `[]` | Stage 2 | Stage 6 |
| `flags.research_urls_discovered` | array | Optional | `[]` | Stage 2 | Stages 4, 5 |
| `flags.augmentation_bugs_found` | integer | Optional | `0` | Stage 2 | Stage 6 |
| `flags.simplification_stats` | map\|null | Optional | `null` | Stage 2 | Stage 6 |
| `flags.cli_dispatch_metrics` | map\|null | Optional | `null` | Stage 2 | Stage 6 |
| `flags.cli_circuit_state` | map\|null | Optional | `null` | Stage 2 | Stages 3, 4 |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 2 | Orchestrator |
| `flags.output_verification_stats` | map\|null | Optional | `null` | Stage 2 | Stages 3, 6 |
| `flags.uat_results` | map\|null | Optional | `null` | Stage 2 | Stage 6 |
| `protocol_evidence` | map | Yes (Stages 2-5) | `{}` | Stage 2 | Orchestrator, Stage 6 |
| `protocol_evidence.agents_dispatched` | array | Yes | `[]` | Stage 2 | Orchestrator |
| `protocol_evidence.prompt_templates_used` | array | Yes | `[]` | Stage 2 | Orchestrator |
| `protocol_evidence.phases_executed_sequentially` | boolean | Yes | `true` | Stage 2 | Orchestrator |
| `protocol_evidence.per_phase_steps_completed` | map | Yes | `{}` | Stage 2 | Stage 6 |

> **Note:** `protocol_evidence` uses the same schema in Stages 2-5. Each stage populates it with its own dispatch records. The orchestrator validates this field via `VERIFY_STAGE_PROTOCOL` (see `orchestrator-loop.md`). Stage 1 and Stage 6 do not require `protocol_evidence`.

## Stage 3: Completion Validation

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 3 | Orchestrator |
| `flags.validation_outcome` | enum | Yes | — | Stage 3 | Stage 4 |
| `flags.baseline_test_count` | integer | Yes | — | Stage 3 | Stage 4 |
| `flags.test_coverage_delta` | map\|null | Optional | `null` | Stage 3 | Stage 6 |
| `flags.cli_circuit_state` | map\|null | Optional | `null` | Stage 3 | Stage 4 |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 3 | Orchestrator |
| `flags.uat_sweep_results` | map\|null | Optional | `null` | Stage 3 | Stage 6 |

## Stage 4: Quality Review

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 4 | Orchestrator |
| `flags.review_outcome` | enum | Yes | — | Stage 4 | Stage 5 |
| `flags.test_count_post_fix` | integer\|null | Optional | `null` | Stage 4 | Stage 6 |
| `flags.commit_sha` | string\|null | Optional | `null` | Stage 4 | Stage 6 |
| `flags.convergence_stats` | map\|null | Optional | `null` | Stage 4 | Stage 6 |
| `flags.stance_stats` | map\|null | Optional | `null` | Stage 4 | Stage 6 |
| `flags.cove_stats` | map\|null | Optional | `null` | Stage 4 | Stage 6 |
| `flags.cli_circuit_state` | map\|null | Optional | `null` | Stage 4 | — |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 4 | Orchestrator |
| `flags.confidence_scoring_stats` | map\|null | Optional | `null` | Stage 4 | Stage 6 |

## Stage 5: Feature Documentation

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 5 | Orchestrator |
| `flags.documentation_outcome` | enum | Yes | — | Stage 5 | Stage 6 |
| `flags.commit_sha` | string\|null | Optional | `null` | Stage 5 | Stage 6 |
| `flags.doc_judge_result` | map\|null | Optional | `null` | Stage 5 | Stage 6 |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 5 | Orchestrator |

`doc_judge_result` (when doc_judge enabled and per-phase mode): `{quality: "PASS"|"FAIL", accuracy_score: N, hallucinations: N, revision_cycles: N}`

## Stage 6: Implementation Retrospective

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 6 | Orchestrator |
| `flags.retrospective_outcome` | enum | Yes | — | Stage 6 | — |
| `flags.commit_sha` | string\|null | Optional | `null` | Stage 6 | — |
| `flags.kpi_count` | integer | Optional | `0` | Stage 6 | — |
| `flags.transcript_analyzed` | boolean | Optional | `false` | Stage 6 | — |
