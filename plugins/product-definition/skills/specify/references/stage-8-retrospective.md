---
stage: stage-8-retrospective
artifacts_written:
  - specs/{FEATURE_DIR}/.specify-report-card.local.md
  - specs/{FEATURE_DIR}/.stage-summaries/transcript-extract.json
  - specs/{FEATURE_DIR}/retrospective.md
---

# Stage 8: Retrospective (Coordinator)

> This stage generates a retrospective narrative from workflow metrics and stage summaries.
> It runs AFTER lock release (Stage 7) and is entirely read-only — it cannot modify spec.md,
> design-brief.md, or any prior artifacts.

## Critical Rules

1. **Config gate**: Check `retrospective.enabled` in config. If `false`, write minimal summary with `flags.skipped: true` and return immediately.
2. **Read-only**: This stage MUST NOT modify any artifact written by Stages 1-7. It only reads state, summaries, and config.
3. **Failure is non-blocking**: If any step fails (transcript extraction, writer dispatch), log the error in the summary and continue. A failed retrospective never blocks workflow completion.
4. **No user interaction**: This stage never sets `status: needs-user-input`. It completes autonomously.

---

## Step 8.1: Config Gate

```
READ config -> retrospective.enabled
IF NOT enabled:
    WRITE summary with:
        status: completed
        flags:
          skipped: true
          skip_reason: "retrospective.enabled = false"
    RETURN
```

---

## Step 8.2: KPI Report Card

Compute 10 specify-specific KPIs from state file and stage summaries. Write to `specs/{FEATURE_DIR}/.specify-report-card.local.md`.

### KPI Definitions

| ID | KPI | Source | Green | Yellow | Red |
|----|-----|--------|-------|--------|-----|
| S1 | Clarification Loops | Stage 4 iteration count from state | 0-1 | 2 | 3+ |
| S2 | Checklist Coverage | Stage 3 summary `flags.coverage_pct` | >= 85% | >= 60% | < 60% |
| S3 | CLI Validation Score | Stage 5 summary `flags.cli_score` | >= 16 | >= 12 | < 12 |
| S4 | RTM Coverage | `state.rtm_enabled` + Stage 3 disposition % | 100% mapped | >= 80% | < 80% |
| S5 | Figma Integration | `state.mcp_availability.figma_mcp_available` + screenshot count | > 0 captured | Info | Info |
| S6 | Design Artifacts | Stage 5 summary: design-brief.md + design-supplement.md existence | Both exist | Brief only | Neither |
| S7 | Test Strategy | Stage 6 summary presence + test case count | Generated | Info | Info |
| S8 | Gate Judge Results | Stage 2 summary `flags.gate_*` (first-pass vs retry scores) | All first-pass pass | Retries needed | Blocks encountered |
| S9 | Edge Cases Identified | Stage 4 summary `flags.edge_case_count` | Info | Info | Info |
| S10 | Coordinator Stability | Count of `model_failures` entries in state | 0 | 1 | 2+ |

> **N/A handling:** S3 uses N/A when CLI is disabled. S4 uses N/A when RTM is disabled. S5 uses N/A when Figma MCP is unavailable. S7 uses N/A when test strategy stage is disabled. Set `traffic_light: "na"` in the report card YAML for these cases.

### Report Card Format

```yaml
---
skill_type: specify
feature_dir: "{FEATURE_DIR}"
generated_at: "{ISO_NOW}"
kpis:
  - id: S1
    name: "Clarification Loops"
    value: {N}
    traffic_light: "{green|yellow|red}"
  - id: S2
    name: "Checklist Coverage"
    value: "{N}%"
    traffic_light: "{green|yellow|red}"
  # ... S3-S10
---
```

### Data Collection

```
READ state file: specs/{FEATURE_DIR}/.specify-state.local.md
    EXTRACT: current_stage, rtm_enabled, mcp_availability, model_failures

READ stage summaries: specs/{FEATURE_DIR}/.stage-summaries/stage-{1-7}-summary.md
    Stage 2: gate scores, gate retries
    Stage 3: coverage_pct, gaps_count
    Stage 4: iteration_count, edge_case_count, clarification_count
    Stage 5: cli_score, cli_decision, design artifacts written
    Stage 6: test_count (if exists)
    Stage 7: completion metrics

CHECK file existence:
    specs/{FEATURE_DIR}/design-brief.md
    specs/{FEATURE_DIR}/design-supplement.md
    specs/{FEATURE_DIR}/test-strategy.md
    specs/{FEATURE_DIR}/rtm.md

COUNT model_failures entries in state
```

Write the report card to: `specs/{FEATURE_DIR}/.specify-report-card.local.md`

---

## Step 8.3: Transcript Extraction (Conditional)

```
READ config -> retrospective.transcript_analysis.enabled
IF NOT enabled:
    SET transcript_data = null
    SKIP to Step 8.4

READ config -> retrospective.transcript_analysis.transcript_dir
IF transcript_dir is null:
    AUTO-DETECT: search ~/.claude/projects/ for the JSONL matching this session
    IF not found: SET transcript_data = null, SKIP to Step 8.4

DISPATCH throwaway subagent:
    Task(subagent_type="general-purpose", prompt="""
    Extract session behavior data from the transcript JSONL.

    Transcript path: {TRANSCRIPT_PATH}
    Token budget: {config.retrospective.transcript_analysis.extract_token_budget}

    Extract:
    1. Tool usage counts (tool name → call count)
    2. Errors (up to {max_errors_extracted}): timestamp, tool, error message, resolution
    3. File heatmap (up to {max_file_paths_extracted}): file path → read count, write count

    Filter to only entries between workflow start ({state.started_at}) and completion ({stage_7_summary.timestamp}).

    Write JSON output to: specs/{FEATURE_DIR}/.stage-summaries/transcript-extract.json

    Schema:
    {
      "tool_usage": {"tool_name": count},
      "errors": [{"timestamp": "", "tool": "", "message": "", "resolution": ""}],
      "file_heatmap": [{"path": "", "reads": 0, "writes": 0}]
    }
    """)

READ result: specs/{FEATURE_DIR}/.stage-summaries/transcript-extract.json
IF file exists and valid JSON:
    SET transcript_data = file contents
ELSE:
    SET transcript_data = null
```

---

## Step 8.4: Writer Dispatch

Compile variables and dispatch the shared retrospective writer agent.

```
COLLECT stage summaries:
    READ all files matching: specs/{FEATURE_DIR}/.stage-summaries/stage-*-summary.md
    CONCATENATE YAML frontmatters into STAGE_SUMMARIES string

READ report card: specs/{FEATURE_DIR}/.specify-report-card.local.md
SET REPORT_CARD_DATA = file contents

READ config -> retrospective.sections
SET SECTIONS_CONFIG = sections block as YAML

DISPATCH definition-retrospective-writer:
    Task(subagent_type="general-purpose", prompt="""
    You are the definition-retrospective-writer agent.
    Read your instructions at: @$CLAUDE_PLUGIN_ROOT/agents/definition-retrospective-writer.md

    Variables:
    - SKILL_TYPE: specify
    - FEATURE_DIR: specs/{FEATURE_DIR}
    - REPORT_CARD_DATA:
      ```yaml
      {REPORT_CARD_DATA}
      ```
    - TRANSCRIPT_EXTRACT: {transcript_data or "null"}
    - STAGE_SUMMARIES:
      ```yaml
      {STAGE_SUMMARIES}
      ```
    - SECTIONS_CONFIG:
      ```yaml
      {SECTIONS_CONFIG}
      ```

    Write output to: specs/{FEATURE_DIR}/retrospective.md
    """)
```

Verify output file exists: `specs/{FEATURE_DIR}/retrospective.md`

---

## Step 8.5: State Update + Summary

```yaml
current_stage: 8
stage_status: "completed"
retrospective_completed_at: "{ISO_DATE}"
```

## Summary Contract

```yaml
---
stage: "retrospective"
stage_number: 8
status: completed
checkpoint: RETROSPECTIVE
artifacts_written:
  - specs/{FEATURE_DIR}/.specify-report-card.local.md
  - specs/{FEATURE_DIR}/.stage-summaries/transcript-extract.json
  - specs/{FEATURE_DIR}/retrospective.md
summary: "Retrospective generated. {N_GREEN} green, {N_YELLOW} yellow, {N_RED} red KPIs. Transcript analysis: {included|skipped}."
flags:
  skipped: false
  kpi_green_count: {N}
  kpi_yellow_count: {N}
  kpi_red_count: {N}
  transcript_included: {true|false}
---
```

---

## Self-Verification (Mandatory before writing summary)

Before writing the summary file, verify:
1. `specs/{FEATURE_DIR}/.specify-report-card.local.md` exists and contains all 10 KPIs
2. `specs/{FEATURE_DIR}/retrospective.md` exists and has the Executive Summary section
3. State file has `current_stage: 8`
4. Summary YAML has no placeholder values (`{N}` must be replaced with actual numbers)
5. No Stage 1-7 artifacts were modified (read-only constraint)

## Critical Rules Reminder

Rules 1-4 above apply. Key: config gate first, read-only analysis, failures are non-blocking, no user interaction.
