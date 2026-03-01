---
stage: stage-7-retrospective
artifacts_written:
  - requirements/.refinement-report-card.local.md
  - requirements/.stage-summaries/transcript-extract.json
  - requirements/retrospective.md
---

# Stage 7: Retrospective (Coordinator)

> This stage generates a retrospective narrative from workflow metrics and stage summaries.
> It runs AFTER lock release (Stage 6) and is entirely read-only — it cannot modify PRD.md,
> decision-log.md, or any prior artifacts.

## Critical Rules

1. **Config gate**: Check `retrospective.enabled` in config. If `false`, write minimal summary with `flags.skipped: true` and return immediately.
2. **Read-only**: This stage MUST NOT modify any artifact written by Stages 1-6. It only reads state, summaries, and config.
3. **Failure is non-blocking**: If any step fails (transcript extraction, writer dispatch), log the error in the summary and continue. A failed retrospective never blocks workflow completion.
4. **No user interaction**: This stage never sets `status: needs-user-input`. It completes autonomously.

---

## Step 7.1: Config Gate

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

## Step 7.2: KPI Report Card

Compute 10 refinement-specific KPIs from state file and stage summaries. Write to `requirements/.refinement-report-card.local.md`.

### KPI Definitions

| ID | KPI | Source | Green | Yellow | Red |
|----|-----|--------|-------|--------|-----|
| R1 | Total Q&A Rounds | `state.current_round` | 1-2 | 3 | 4+ |
| R2 | Questions Generated | Count of `requirements/working/QUESTIONS-*.md` files | Info | Info | Info |
| R3 | Answer Coverage | Stage 4 summary `completion_rate` or count answered/total | 100% first pass | Needed gap round | Incomplete |
| R4 | Panel Composition | Stage 1 summary (`panel_count`, `preset`) | Info | Info | Info |
| R5 | Analysis Mode Achieved | `state.analysis_mode` | Complete | Advanced or Standard | Rapid |
| R6 | PRD Mode | `state.prd_mode` (NEW or EXTEND) | Info | Info | Info |
| R7 | Validation Score | Stage 5 summary `flags.validation_score` | >= 16 | >= 12 | < 12 |
| R8 | Research Reports | Stage 2 summary `flags.report_count` or count of files in `requirements/research/reports/` | >= 1 | 0 (research enabled) | N/A (research disabled) |
| R9 | MCP Integration | Stage 3 summary ThinkDeep results | All succeeded | Partial (some failed) | All failed |
| R10 | Coordinator Stability | Count of `flags.recovered: true` across all stage summaries | 0 | 1 | 2+ |

> **N/A handling:** R8 uses N/A when research is disabled. R9 uses N/A when ThinkDeep was not attempted (Standard/Rapid mode). Set `traffic_light: "na"` in the report card YAML for these cases.

### Report Card Format

```yaml
---
skill_type: refinement
generated_at: "{ISO_NOW}"
kpis:
  - id: R1
    name: "Total Q&A Rounds"
    value: {N}
    traffic_light: "{green|yellow|red}"
  - id: R2
    name: "Questions Generated"
    value: {N}
    traffic_light: "info"
  # ... R3-R10
---
```

### Data Collection

```
READ state file: requirements/.requirements-state.local.md
    EXTRACT: current_round, analysis_mode, prd_mode, mcp_availability

READ stage summaries: requirements/.stage-summaries/stage-{1-6}-summary.md
    Stage 1: panel_count, preset
    Stage 2: report_count (if exists)
    Stage 3: thinkdeep_success_rate, questions_count
    Stage 4: completion_rate, gap_round_needed
    Stage 5: validation_score
    Stage 6: total_rounds, total_questions

COUNT files matching: requirements/working/QUESTIONS-*.md

COUNT recovered summaries: grep for "recovered: true" across all summaries
```

Write the report card to: `requirements/.refinement-report-card.local.md`

---

## Step 7.3: Transcript Extraction (Conditional)

```
READ config -> retrospective.transcript_analysis.enabled
IF NOT enabled:
    SET transcript_data = null
    SKIP to Step 7.4

READ config -> retrospective.transcript_analysis.transcript_dir
IF transcript_dir is null:
    AUTO-DETECT: search ~/.claude/projects/ for the JSONL matching this session
    IF not found: SET transcript_data = null, SKIP to Step 7.4

DISPATCH throwaway subagent:
    Task(subagent_type="general-purpose", prompt="""
    Extract session behavior data from the transcript JSONL.

    Transcript path: {TRANSCRIPT_PATH}
    Token budget: {config.retrospective.transcript_analysis.extract_token_budget}

    Extract:
    1. Tool usage counts (tool name → call count)
    2. Errors (up to {max_errors_extracted}): timestamp, tool, error message, resolution
    3. File heatmap (up to {max_file_paths_extracted}): file path → read count, write count

    Filter to only entries between workflow start ({state.started_at}) and completion ({stage_6_summary.timestamp}).

    Write JSON output to: requirements/.stage-summaries/transcript-extract.json

    Schema:
    {
      "tool_usage": {"tool_name": count},
      "errors": [{"timestamp": "", "tool": "", "message": "", "resolution": ""}],
      "file_heatmap": [{"path": "", "reads": 0, "writes": 0}]
    }
    """)

READ result: requirements/.stage-summaries/transcript-extract.json
IF file exists and valid JSON:
    SET transcript_data = file contents
ELSE:
    SET transcript_data = null
```

---

## Step 7.4: Writer Dispatch

Compile variables and dispatch the shared retrospective writer agent.

```
COLLECT stage summaries:
    READ all files matching: requirements/.stage-summaries/stage-*-summary.md
    CONCATENATE YAML frontmatters into STAGE_SUMMARIES string

READ report card: requirements/.refinement-report-card.local.md
SET REPORT_CARD_DATA = file contents

READ config -> retrospective.sections
SET SECTIONS_CONFIG = sections block as YAML

DISPATCH definition-retrospective-writer:
    Task(subagent_type="general-purpose", prompt="""
    You are the definition-retrospective-writer agent.
    Read your instructions at: @$CLAUDE_PLUGIN_ROOT/agents/definition-retrospective-writer.md

    Variables:
    - SKILL_TYPE: refinement
    - FEATURE_DIR: requirements
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

    Write output to: requirements/retrospective.md
    """)
```

Verify output file exists: `requirements/retrospective.md`

---

## Step 7.5: State Update + Summary

```yaml
current_stage: 7
stage_status: "completed"
retrospective_completed_at: "{ISO_DATE}"
```

## Summary Contract

```yaml
---
stage: "retrospective"
stage_number: 7
status: completed
checkpoint: RETROSPECTIVE
artifacts_written:
  - requirements/.refinement-report-card.local.md
  - requirements/.stage-summaries/transcript-extract.json
  - requirements/retrospective.md
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
1. `requirements/.refinement-report-card.local.md` exists and contains all 10 KPIs
2. `requirements/retrospective.md` exists and has the Executive Summary section
3. State file has `current_stage: 7`
4. Summary YAML has no placeholder values (`{N}` must be replaced with actual numbers)
5. No Stage 1-6 artifacts were modified (read-only constraint)

## Critical Rules Reminder

Rules 1-4 above apply. Key: config gate first, read-only analysis, failures are non-blocking, no user interaction.
