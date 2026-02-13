---
stage: "6"
stage_name: "Implementation Retrospective"
checkpoint: "RETROSPECTIVE"
delegation: "coordinator"
prior_summaries:
  - ".stage-summaries/stage-1-summary.md"
  - ".stage-summaries/stage-2-summary.md"
  - ".stage-summaries/stage-3-summary.md"
  - ".stage-summaries/stage-4-summary.md"
  - ".stage-summaries/stage-5-summary.md"
artifacts_read:
  - "tasks.md"
  - ".implementation-state.local.md"
artifacts_written:
  - "retrospective.md"
  - ".implementation-report-card.local.md"
  - ".stage-summaries/transcript-extract.json (conditional)"
agents:
  - "product-implementation:tech-writer"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/agent-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/implement/references/auto-commit-dispatch.md"
  - "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml"
---

# Stage 6: Implementation Retrospective

> **COORDINATOR STAGE:** This stage is dispatched by the orchestrator via `Task()`.
> Read all 5 prior stage summaries to understand the full implementation lifecycle.
> This stage runs **post-lock-release** — the lock was released in Stage 5. No lock operations needed.

## Architecture Overview

Stage 6 produces two artifacts through a three-layer pipeline:

| Layer | Source | Output | Purpose |
|-------|--------|--------|---------|
| **Data** | State file, stage summaries, tasks.md | `.implementation-report-card.local.md` | Quantitative KPIs, cross-run comparable |
| **Behavior** | Session transcript JSONL | `.stage-summaries/transcript-extract.json` | Tool usage, errors, timing, file patterns |
| **Presentation** | Report Card + transcript extract + summaries | `retrospective.md` | Human-readable narrative with recommendations |

The Data and Behavior layers run first (Sections 6.2-6.3), then feed into the Presentation layer (Section 6.4).

## 6.1 Config & Skip Gate

Read `retrospective` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`.

1. If `retrospective.enabled` is `false`:
   - Write a minimal Stage 6 summary with `status: "completed"` and `flags.skipped: true`
   - Log: `"Retrospective disabled — skipping Stage 6"`
   - Return immediately (no artifacts produced)

2. If `retrospective.enabled` is `true`: proceed to Section 6.2.

## 6.2 KPI Report Card Compilation

The coordinator compiles the Report Card inline (no subagent needed — data is already structured YAML).

### 6.2.1 Data Collection

Read and collect data from these sources:

| Source | Fields Extracted |
|--------|-----------------|
| `.implementation-state.local.md` | `user_decisions`, `orchestrator.coordinator_failures`, `orchestrator.summaries_reconstructed` |
| Stage 1 summary | `artifacts_loaded` table, `test_cases_available`, `autonomy_policy`, expected file warnings |
| Stage 2 summary | `simplification_stats`, `uat_results`, `augmentation_bugs_found` |
| Stage 3 summary | `validation_outcome`, `baseline_test_count` |
| Stage 4 summary | `review_outcome`, finding counts by severity |
| Stage 5 summary | `documentation_outcome` |
| `tasks.md` | Count of `[X]` vs total tasks |
| All stage summaries | Count of `[AUTO-{policy}]` log entries (grep Implementation Log sections) |

### 6.2.2 KPI Computation — Phase 1

Compute 10 Phase 1 KPIs from the collected data:

| ID | KPI Name | Computation | Traffic Light |
|----|----------|-------------|---------------|
| 1.2 | Rework Loop Count | Count `user_decisions` values that are `"fixed"` (across validation_outcome, review_outcome, documentation_verification) | Green: 0, Yellow: 1, Red: 2+ |
| 1.3 | Coordinator Stability | `coordinator_failures` + `summaries_reconstructed` | Green: 0, Yellow: 1, Red: 2+ |
| 3.1 | Input Completeness Score | Count artifacts with status `"loaded"` / total artifacts in Stage 1 summary table × 100 | Green: >=80%, Yellow: >=60%, Red: <60% |
| 3.2 | Expected File Gap Rate | Count Stage 1 warnings about expected-but-missing files / total expected files × 100 | Green: 0%, Yellow: <=20%, Red: >20% |
| 3.3 | Test Case Availability | `test_cases_available` from Stage 1 flags (`true`/`false`) | Green: true, Red: false |
| 5.1 | Autonomy Policy Level | `autonomy_policy` from Stage 1 summary (literal value) | Info only — no traffic light |
| 5.2 | Auto-Resolution Count | Total `[AUTO-{policy}]` entries across all stage logs | Info only — contextualizes policy impact |
| 5.3 | Simplification Stats | `simplification_stats` from Stage 2 summary (phases_simplified, lines_reduced, rollbacks) | Green: 0 rollbacks, Yellow: 1 rollback, Red: 2+ rollbacks |
| 5.4 | UAT Results | `uat_results` from Stage 2 summary (phases_tested, pass_count, fail_count, visual_mismatches) | Green: all pass, Yellow: visual-only issues, Red: behavioral failures |
| 5.5 | Clink Augmentation | `augmentation_bugs_found` from Stage 2 summary (count of bugs found by clink test augmenter) | Green: 0, Yellow: 1-2, Red: 3+ |

**Null handling**: If a source field is absent (feature disabled, stage skipped), set the KPI value to `null` and traffic light to `"N/A"`.

### 6.2.3 Write Report Card

Write `{FEATURE_DIR}/.implementation-report-card.local.md`:

```yaml
---
schema_version: 1
feature_name: "{FEATURE_NAME}"
generated_at: "{ISO_TIMESTAMP}"
kpi_phase: 1
# --- Phase 1 KPIs (extracted from existing structured data) ---
kpis:
  rework_loop_count:
    id: "1.2"
    value: {N}
    traffic_light: "{green|yellow|red}"
  coordinator_stability:
    id: "1.3"
    value: {N}
    traffic_light: "{green|yellow|red}"
  input_completeness_score:
    id: "3.1"
    value: {N}    # percentage
    traffic_light: "{green|yellow|red}"
  expected_file_gap_rate:
    id: "3.2"
    value: {N}    # percentage
    traffic_light: "{green|yellow|red}"
  test_case_availability:
    id: "3.3"
    value: {true|false}
    traffic_light: "{green|red}"
  autonomy_policy_level:
    id: "5.1"
    value: "{full_auto|balanced|critical_only|null}"
    traffic_light: "info"
  auto_resolution_count:
    id: "5.2"
    value: {N}
    traffic_light: "info"
  simplification_stats:
    id: "5.3"
    value:
      phases_simplified: {N}
      lines_reduced: {N}
      rollbacks: {N}
    traffic_light: "{green|yellow|red|N/A}"
  uat_results:
    id: "5.4"
    value:
      phases_tested: {N}
      pass_count: {N}
      fail_count: {N}
      visual_mismatches: {N}
    traffic_light: "{green|yellow|red|N/A}"
  clink_augmentation_bugs:
    id: "5.5"
    value: {N}
    traffic_light: "{green|yellow|red|N/A}"
# --- Phase 2 KPIs (future — null placeholders for forward-compatibility) ---
phase2:
  stage_duration_seconds: null
  finding_counts_by_severity: null
  spec_coverage_ratio: null
  test_id_traceability_score: null
  review_fix_rate: null
  test_coverage_delta: null
  documentation_completeness: null
  constitution_violations: null
  build_error_resolution_count: null
  pattern_propagation_count: null
---
## Notes

- Phase 1 KPIs are computed from existing structured YAML data (no template changes needed)
- Phase 2 fields are null placeholders — they require template changes to populate
- Traffic lights: green = healthy, yellow = attention, red = concern, info = contextual, N/A = feature disabled
- This file is excluded from auto-commit (local analysis artifact)
```

## 6.3 Transcript Extraction (Conditional)

> **Gate**: `retrospective.transcript_analysis.enabled` must be `true`. If `false`, set `transcript_available: false` and skip to Section 6.4.

### 6.3.1 Identify Transcript File

Claude Code stores session transcripts as JSONL at `~/.claude/projects/{project_hash}/{session_id}.jsonl`.

1. Read `retrospective.transcript_analysis.transcript_dir` from config
   - If `null` (default): auto-detect by globbing `~/.claude/projects/*/*.jsonl`
   - If set: use the specified directory
2. Identify the correct transcript by matching recency: find the JSONL file whose last-modified timestamp falls within the implementation window (between Stage 1 summary `generated_at` and Stage 5 summary `generated_at`)
   - **Known limitation**: Timestamp-based matching is a heuristic — if multiple Claude Code sessions overlap the implementation window (e.g., parallel sessions in different terminals), the wrong transcript may be selected. The `transcript_dir` config override can be used to disambiguate manually.
3. If no matching transcript found: set `transcript_available: false`, log warning, skip to Section 6.4

### 6.3.2 Dispatch Extraction Subagent

Dispatch a throwaway `Task(subagent_type="general-purpose")` subagent to extract behavioral signals from the transcript. The subagent runs a streaming Python script that processes the JSONL line-by-line (never loads the full file into memory).

**Subagent prompt:**

> Read the session transcript at `{transcript_path}`. Write and execute a Python script that streams the JSONL file line-by-line, extracting these metrics into a JSON object. Write the result to `{FEATURE_DIR}/.stage-summaries/transcript-extract.json`.
>
> The script must:
> - Stream line-by-line (never load full file — transcripts can be 2-14MB)
> - Parse each JSON line looking for tool calls, errors, system messages, and timing data
> - Cap extracted arrays at configured maximums
>
> **Extract these fields:**
>
> ```json
> {
>   "session_duration_minutes": null,
>   "total_turns": 0,
>   "tool_call_counts": {},
>   "tool_error_count": 0,
>   "tool_errors": [],
>   "files_most_accessed": [],
>   "files_repeatedly_read": [],
>   "subagent_dispatches": [],
>   "context_compressions": 0,
>   "longest_turns_ms": []
> }
> ```
>
> **Field definitions:**
> - `session_duration_minutes`: Time from first to last message timestamp
> - `total_turns`: Count of assistant message entries
> - `tool_call_counts`: Map of tool name → invocation count (e.g., `{"Read": 45, "Edit": 23, "Bash": 12, "Task": 8}`)
> - `tool_error_count`: Total tool calls that returned errors
> - `tool_errors`: Array of `{"tool": "...", "preview": "first 100 chars of error", "timestamp": "..."}`, capped at `{max_errors_extracted}` entries
> - `files_most_accessed`: Top `{max_file_paths_extracted}` files by total operations (read + edit + write), as `{"path": "...", "operations": N}`
> - `files_repeatedly_read`: Files read 5+ times (inefficiency signal), as `{"path": "...", "read_count": N}`
> - `subagent_dispatches`: Array of `{"type": "...", "timestamp": "..."}` for each Task tool call
> - `context_compressions`: Count of system messages indicating context compression/compaction
> - `longest_turns_ms`: Top 5 turns by duration (time between user message and assistant response), as `{"turn_index": N, "duration_ms": N}`
>
> Config caps: max_errors_extracted = `{max_errors_extracted}`, max_file_paths_extracted = `{max_file_paths_extracted}`, extract_token_budget = `{extract_token_budget}` (approximate target size for the output JSON — keep arrays trimmed to stay within this budget)

### 6.3.3 Parse Extraction Result

1. Read `{FEATURE_DIR}/.stage-summaries/transcript-extract.json`
2. If file exists and is valid JSON: set `transcript_available: true`
3. If subagent failed or file is missing/invalid: set `transcript_available: false`, log warning, proceed with reduced-detail retrospective

## 6.4 Retrospective Composition

Dispatch a `tech-writer` agent to compose the narrative retrospective document from the structured data collected in Sections 6.2-6.3.

### 6.4.1 Compile Input Data

Prepare the prompt variables for the tech-writer:

| Variable | Source | Fallback |
|----------|--------|----------|
| `{FEATURE_NAME}` | Stage 1 summary | (required — always available) |
| `{FEATURE_DIR}` | Stage 1 summary | (required — always available) |
| `{report_card_data}` | Content of `.implementation-report-card.local.md` YAML frontmatter | (required — always produced in 6.2) |
| `{transcript_extract}` | Content of `.stage-summaries/transcript-extract.json` | `"Transcript analysis not available — session behavior sections will be omitted."` |
| `{stage_summaries_compiled}` | Key excerpts from all 5 stage summaries (summary + flags sections, ~200 tokens each) | (required — always available) |
| `{sections_config}` | `retrospective.sections` from config (which sections to include) | All sections enabled (default) |

### 6.4.2 Dispatch Tech-Writer

```
Task(subagent_type="product-implementation:tech-writer")
```

Use the Retrospective Composition Prompt from `agent-prompts.md` (Section: Retrospective Composition Prompt).

### 6.4.3 Expected Output

The tech-writer produces `{FEATURE_DIR}/retrospective.md` with these sections (each gated by `{sections_config}`):

1. **Executive Summary** — KPI-backed headline metrics, overall verdict (always included)
2. **KPI Report Card** — Table with all Phase 1 KPIs, traffic lights, Phase 2 placeholders (always included)
3. **Implementation Timeline** — Stage-by-stage events with timestamps (gated: `sections.timeline`)
4. **What Worked Well** — KPI + transcript + summary synthesis (gated: `sections.what_worked`)
5. **What Did Not Work Well** — Errors, rework, bottlenecks with evidence (gated: `sections.what_didnt_work`)
6. **Stage-by-Stage Breakdown** — Per-stage analysis with policy actions taken (gated: `sections.stage_breakdown`)
7. **Session Behavior Analysis** — Tool usage, file heatmap, subagent dispatch, context pressure (gated: `sections.tool_analysis`, requires transcript)
8. **Quality Metrics** — Test progression, simplification, UAT, review findings (gated: `sections.code_quality_metrics`)
9. **Recommendations** — Process, input, config improvements (gated: `sections.recommendations`)
10. **Appendix: Raw Data** — Raw KPI values, transcript extract dump (gated: `sections.raw_metrics`)

## 6.5 Auto-Commit Retrospective

After the tech-writer completes, optionally commit the retrospective document. Follow the Auto-Commit Dispatch Procedure in `$CLAUDE_PLUGIN_ROOT/skills/implement/references/auto-commit-dispatch.md` with:

| Parameter | Value |
|-----------|-------|
| `template_key` | `retrospective` |
| `substitution_vars` | `{feature_name}` = FEATURE_NAME |
| `skip_target` | Section 6.6 |
| `summary_field` | `commit_sha` |

**Note:** The auto-commit exclude patterns in config include `.implementation-report-card` and `transcript-extract.json` — these are local analysis artifacts not committed to version control.

## 6.6 State Update

After retrospective generation:

1. Update state file:
   - Set `current_stage: 6`
   - Update `last_checkpoint`
   - Append to Implementation Log: `"[{ISO_TIMESTAMP}] Stage 6: Retrospective — completed"`
2. **No lock operations** — lock was already released in Stage 5

## 6.7 Write Stage 6 Summary

Write summary to `{FEATURE_DIR}/.stage-summaries/stage-6-summary.md`:

```yaml
---
stage: "6"
stage_name: "Implementation Retrospective"
checkpoint: "RETROSPECTIVE"
status: "completed"
artifacts_written:
  - "retrospective.md"
  - ".implementation-report-card.local.md"
  - ".stage-summaries/transcript-extract.json (conditional)"
summary: |
  Retrospective generated. KPIs: {N} computed ({M} green, {O} yellow, {P} red).
  Transcript analysis: {available|unavailable}.
  Document sections: {N}/{total} enabled.
flags:
  skipped: false
  transcript_analyzed: true  # false if transcript unavailable or extraction disabled
  kpis_computed: 10          # Number of Phase 1 KPIs successfully computed
  kpis_null: {N}             # Number of KPIs set to null (feature disabled)
  commit_sha: null            # Auto-commit SHA (null if disabled, skipped, or failed)
---
## Context for Next Stage

Implementation workflow complete. No further stages.

## Retrospective Highlights

- Feature: {FEATURE_NAME}
- Overall KPI health: {N} green / {M} yellow / {O} red / {P} N/A
- Rework loops: {N}
- Coordinator stability: {failures} failures, {reconstructed} reconstructed
- Autonomy policy: {policy} ({auto_resolutions} auto-resolutions)
- Transcript: {analyzed with N turns, M tool calls | not available}

## Artifacts Produced

- `retrospective.md` — Full narrative retrospective ({N} sections)
- `.implementation-report-card.local.md` — Machine-readable KPI Report Card (Phase 1)
- `.stage-summaries/transcript-extract.json` — Behavioral extraction from session transcript (if available)
```
