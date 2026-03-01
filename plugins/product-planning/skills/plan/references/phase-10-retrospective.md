---
phase: "10"
phase_name: "Planning Retrospective"
checkpoint: "RETROSPECTIVE"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries: [phase-1, phase-2, phase-3, phase-4, phase-5, phase-6, phase-6b, phase-7, phase-8, phase-8b, phase-9]
artifacts_read: [".planning-state.local.md"]
artifacts_written:
  - ".planning-report-card.local.md"
  - ".phase-summaries/transcript-extract.json"  # conditional: transcript_analysis.enabled
  - "retrospective.md"
agents: ["product-planning:planning-retrospective-writer"]
---

# Phase 10: Planning Retrospective (Coordinator)

> This phase generates a retrospective narrative from workflow metrics and phase summaries.
> It runs AFTER lock release (Phase 9 Step 9.12) and is entirely read-only — it cannot
> modify any prior planning artifacts (design.md, plan.md, tasks.md, test-plan.md, etc.).

## Critical Rules

1. **Config gate**: Check `retrospective.enabled` in config. If `false`, write minimal summary with `flags.skipped: true` and return immediately.
2. **Read-only**: This phase MUST NOT modify any artifact written by Phases 1-9. It only reads state, summaries, and config.
3. **Failure is non-blocking**: If any step fails (transcript extraction, writer dispatch), log the error in the summary and continue. A failed retrospective never blocks workflow completion.
4. **No user interaction**: This phase never sets `status: needs-user-input`. It completes autonomously.

---

## Step 10.1: Config Gate

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

## Step 10.2: KPI Report Card

Compute 10 planning-specific KPIs from state file and phase summaries. Write to `{FEATURE_DIR}/.planning-report-card.local.md`.

### KPI Definitions

| ID | KPI | Source | Green | Yellow | Red |
|----|-----|--------|-------|--------|-----|
| P1 | Analysis Mode | `state.analysis_mode` | Complete | Advanced/Standard | Rapid |
| P2 | Architecture Options | Phase 4 summary `flags.options_count` | 3+ | 2 | 1 |
| P3 | CLI Deep Analysis | Phase 5 summary `flags.cli_count` | 3 CLIs | 2 | 1 or N/A |
| P4 | Plan Validation Score | Phase 6 summary `gate.score` | >= 16 | >= 12 | < 12 |
| P5 | Expert Review | Phase 6b summary `flags.critical_count` | 0 critical | advisory only | critical blocking |
| P6 | Test Coverage Score | Phase 8 summary `gate.score` | >= 80% | >= 60% | < 60% |
| P7 | Task Count | Phase 9 summary `flags.task_count` | Info | Info | Info |
| P8 | Clarification Rounds | Phase 3 summary `flags.round_count` or state `clarification_rounds` | 1 | 2 | 3+ |
| P9 | Coordinator Stability | Count of `flags.recovered: true` across all phase summaries | 0 | 1 | 2+ |
| P10 | Gate Retry Count | Sum of retries across Phases 6 and 8 | 0 | 1 | 2+ |

> **N/A handling:** P3 uses N/A when CLI analysis was not attempted (Standard/Rapid mode). P5 uses N/A when expert review was skipped. Set `traffic_light: "na"` in the report card YAML for these cases.

### Report Card Format

```yaml
---
skill_type: planning
generated_at: "{ISO_NOW}"
kpis:
  - id: P1
    name: "Analysis Mode"
    value: "{mode}"
    traffic_light: "{green|yellow|red}"
  - id: P2
    name: "Architecture Options"
    value: {N}
    traffic_light: "{green|yellow|red}"
  # ... P3-P10
---
```

### Data Collection

```
READ state file: {FEATURE_DIR}/.planning-state.local.md
    EXTRACT: analysis_mode, clarification_rounds, completed_phases

READ phase summaries: {FEATURE_DIR}/.phase-summaries/phase-{1-9}-summary.md
    (Also read phase-6b-summary.md, phase-8b-summary.md if they exist)
    Phase 1: mode, capabilities
    Phase 2: research findings count
    Phase 3: round_count, questions_count
    Phase 4: options_count, selected_option
    Phase 5: cli_count, perspectives_analyzed
    Phase 6: gate.score, gate.verdict, retries
    Phase 6b: critical_count, advisory_count
    Phase 7: test_levels_covered, uat_count
    Phase 8: gate.score, gate.verdict, retries
    Phase 8b: asset_count (if exists)
    Phase 9: task_count, tdd_structured

COUNT recovered summaries: grep for "recovered: true" across all summaries
SUM gate retries: from Phase 6 and Phase 8 summaries
```

Write the report card to: `{FEATURE_DIR}/.planning-report-card.local.md`

---

## Step 10.3: Transcript Extraction (Conditional)

```
READ config -> retrospective.transcript_analysis.enabled
IF NOT enabled:
    SET transcript_data = null
    SKIP to Step 10.4

READ config -> retrospective.transcript_analysis.transcript_dir
IF transcript_dir is null:
    AUTO-DETECT: search ~/.claude/projects/ for the JSONL matching this session
    IF not found: SET transcript_data = null, SKIP to Step 10.4

DISPATCH throwaway subagent:
    Task(subagent_type="general-purpose", prompt="""
    Extract session behavior data from the transcript JSONL.

    Transcript path: {TRANSCRIPT_PATH}
    Token budget: {config.retrospective.transcript_analysis.extract_token_budget}

    Extract:
    1. Tool usage counts (tool name -> call count)
    2. Errors (up to {max_errors_extracted}): timestamp, tool, error message, resolution
    3. File heatmap (up to {max_file_paths_extracted}): file path -> read count, write count

    Filter to only entries between workflow start ({state.started_at}) and completion ({phase_9_summary.timestamp}).

    Write JSON output to: {FEATURE_DIR}/.phase-summaries/transcript-extract.json

    Schema:
    {
      "tool_usage": {"tool_name": count},
      "errors": [{"timestamp": "", "tool": "", "message": "", "resolution": ""}],
      "file_heatmap": [{"path": "", "reads": 0, "writes": 0}]
    }
    """)

READ result: {FEATURE_DIR}/.phase-summaries/transcript-extract.json
IF file exists and valid JSON:
    SET transcript_data = file contents
ELSE:
    SET transcript_data = null
```

---

## Step 10.4: Writer Dispatch

Compile variables and dispatch the planning retrospective writer agent.

```
COLLECT phase summaries:
    READ all files matching: {FEATURE_DIR}/.phase-summaries/phase-*-summary.md
    CONCATENATE YAML frontmatters into PHASE_SUMMARIES string

READ report card: {FEATURE_DIR}/.planning-report-card.local.md
SET REPORT_CARD_DATA = file contents

READ config -> retrospective.sections
SET SECTIONS_CONFIG = sections block as YAML

READ state -> feature_name (or derive from FEATURE_DIR basename)
SET FEATURE_NAME = feature name

DISPATCH planning-retrospective-writer:
    Task(subagent_type="general-purpose", prompt="""
    You are the planning-retrospective-writer agent.
    Read your instructions at: $CLAUDE_PLUGIN_ROOT/agents/planning-retrospective-writer.md

    Variables:
    - FEATURE_DIR: {FEATURE_DIR}
    - FEATURE_NAME: {FEATURE_NAME}
    - REPORT_CARD_DATA:
      ```yaml
      {REPORT_CARD_DATA}
      ```
    - TRANSCRIPT_EXTRACT: {transcript_data or "null"}
    - PHASE_SUMMARIES:
      ```yaml
      {PHASE_SUMMARIES}
      ```
    - SECTIONS_CONFIG:
      ```yaml
      {SECTIONS_CONFIG}
      ```

    Write output to: {FEATURE_DIR}/retrospective.md
    """)
```

Verify output file exists: `{FEATURE_DIR}/retrospective.md`

---

## Step 10.5: Auto-Commit (Conditional)

```
READ config -> retrospective.auto_commit.enabled
IF NOT enabled:
    SKIP to Step 10.6

DISPATCH throwaway subagent:
    Task(subagent_type="general-purpose", prompt="""
    Auto-commit the retrospective artifact.

    1. cd to {FEATURE_DIR}
    2. git add retrospective.md
    3. Verify no excluded files are staged:
       Exclude patterns: {config.retrospective.auto_commit.exclude_patterns}
    4. git commit -m "{config.retrospective.auto_commit.message_template}"
       Replace {feature_name} with: {FEATURE_NAME}

    If git add or commit fails (e.g., not a git repo, nothing to commit),
    log the error and return — do NOT retry or escalate.
    """)
```

---

## Step 10.6: State Update + Summary

```yaml
current_phase: 10
phase_status: "completed"
retrospective_completed_at: "{ISO_DATE}"
```

## Summary Contract

```yaml
---
phase: "retrospective"
phase_number: 10
status: completed
checkpoint: RETROSPECTIVE
artifacts_written:
  - "{FEATURE_DIR}/.planning-report-card.local.md"
  - "{FEATURE_DIR}/.phase-summaries/transcript-extract.json"
  - "{FEATURE_DIR}/retrospective.md"
summary: "Retrospective generated. {N_GREEN} green, {N_YELLOW} yellow, {N_RED} red KPIs. Transcript analysis: {included|skipped}. Auto-commit: {committed|skipped|failed}."
flags:
  skipped: false
  kpi_green_count: {N}
  kpi_yellow_count: {N}
  kpi_red_count: {N}
  transcript_included: {true|false}
  auto_committed: {true|false}
---
```

---

## Self-Verification (Mandatory before writing summary)

Before writing the summary file, verify:
1. `{FEATURE_DIR}/.planning-report-card.local.md` exists and contains all 10 KPIs
2. `{FEATURE_DIR}/retrospective.md` exists and has the Executive Summary section
3. State file has `current_phase: 10`
4. Summary YAML has no placeholder values (`{N}` must be replaced with actual numbers)
5. No Phase 1-9 artifacts were modified (read-only constraint)

## Critical Rules Reminder

Rules 1-4 above apply. Key: config gate first, read-only analysis, failures are non-blocking, no user interaction.
