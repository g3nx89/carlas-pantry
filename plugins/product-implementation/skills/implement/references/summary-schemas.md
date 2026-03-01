# Stage Summary YAML Schemas

> Defines the expected YAML structure for all 6 stage summaries.
> When adding or removing summary fields, update this file.
> Referenced by: `orchestrator-loop.md` (summary validation), `stage-1-setup.md` through
> `stage-6-retrospective.md` (each stage writes its summary per these schemas).

## Base Fields (Required — All Stages)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | string | Yes | Stage number as string (e.g., `"1"`) |
| `status` | enum | Yes | `completed` \| `needs-user-input` \| `failed` |
| `checkpoint` | string | Yes | Checkpoint name matching dispatch table |
| `artifacts_written` | array | Yes | List of files written (may be empty) |
| `summary` | string | Yes | Non-empty natural-language summary |

## Stage 1: Setup & Context Loading

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 1 | Orchestrator |
| `flags.test_cases_available` | boolean | Yes | — | Stage 1 | Stages 2, 3 |
| `detected_domains` | array | Yes | `[]` | Stage 1 | Stages 2, 4, 5 |
| `cli_availability` | map | Yes | `{}` | Stage 1 | Stages 2, 3, 4, 5 |
| `mcp_availability` | map | Yes | all false | Stage 1 | Stages 2, 3, 4, 5 |
| `extracted_urls` | array | Optional | `[]` | Stage 1 | Stage 2 |
| `resolved_libraries` | array | Optional | `[]` | Stage 1 | Stages 2, 3, 4 |
| `private_doc_urls` | array | Optional | `[]` | Stage 1 | Stage 2 |
| `mobile_mcp_available` | boolean | Yes | `false` | Stage 1 | Stage 2 |
| `mobile_device_name` | string\|null | Yes | `null` | Stage 1 | Stage 2 |
| `plugin_availability` | map | Yes | — | Stage 1 | Stage 4 |
| `autonomy_policy` | string | Yes | — | Stage 1 | All stages |
| `cli_circuit_state` | map\|null | Optional | `null` | Stage 1 | Stages 2, 3, 4 |
| `context_contributions` | map\|null | Optional | `null` | Stage 1 | Orchestrator |

## Stage 2: Phase-by-Phase Execution

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 2 | Orchestrator |
| `flags.test_count_verified` | integer\|null | Yes | `null` | Stage 2 | Stage 3 |
| `flags.commits_made` | array | Yes | `[]` | Stage 2 | Stage 6 |
| `flags.research_urls_discovered` | array | Optional | `[]` | Stage 2 | Stages 4, 5 |
| `flags.augmentation_bugs_found` | integer | Optional | `0` | Stage 2 | Stage 6 |
| `flags.simplification_stats` | map\|null | Optional | `null` | Stage 2 | Stage 6 |
| `flags.cli_dispatch_metrics` | map\|null | Optional | `null` | Stage 2 | Stage 6 |
| `flags.cli_circuit_state` | map\|null | Optional | `null` | Stage 2 | Stages 3, 4 |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 2 | Orchestrator |
| `flags.uat_results` | map\|null | Optional | `null` | Stage 2 | Stage 6 |

## Stage 3: Completion Validation

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 3 | Orchestrator |
| `flags.validation_outcome` | enum | Yes | — | Stage 3 | Stage 4 |
| `flags.baseline_test_count` | integer | Yes | — | Stage 3 | Stage 4 |
| `flags.test_coverage_delta` | map\|null | Optional | `null` | Stage 3 | Stage 6 |
| `flags.cli_circuit_state` | map\|null | Optional | `null` | Stage 3 | Stage 4 |
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 3 | Orchestrator |

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
| `flags.context_contributions` | map\|null | Optional | `null` | Stage 5 | Orchestrator |

## Stage 6: Implementation Retrospective

| Field | Type | Required | Default | Producer | Consumer |
|-------|------|----------|---------|----------|----------|
| `flags.block_reason` | string\|null | Yes | `null` | Stage 6 | Orchestrator |
| `flags.retrospective_outcome` | enum | Yes | — | Stage 6 | — |
| `flags.commit_sha` | string\|null | Optional | `null` | Stage 6 | — |
| `flags.kpi_count` | integer | Optional | `0` | Stage 6 | — |
| `flags.transcript_analyzed` | boolean | Optional | `false` | Stage 6 | — |
