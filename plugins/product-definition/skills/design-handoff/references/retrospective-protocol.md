---
stage: retrospective-protocol
artifacts_written:
  - design-handoff/.handoff-report-card.local.md
  - design-handoff/.stage-summaries/transcript-extract.json
  - design-handoff/retrospective.md
---

# Retrospective Protocol — Design Handoff (Coordinator)

> This protocol generates a retrospective narrative from workflow metrics and stage summaries.
> It runs AFTER lock release and is entirely read-only — it cannot modify HANDOFF-SUPPLEMENT.md,
> handoff-manifest.md, gap-report.md, or any prior artifacts.

## Critical Rules

1. **Config gate**: Check `retrospective.enabled` in config. If `false`, write minimal summary with `flags.skipped: true` and return immediately.
2. **Read-only**: This protocol MUST NOT modify any artifact written by Stages 1-5J. It only reads state, summaries, judge verdicts, and config.
3. **Failure is non-blocking**: If any step fails (transcript extraction, writer dispatch), log the error in the summary and continue. A failed retrospective never blocks workflow completion.
4. **No user interaction**: This protocol never sets `status: needs-user-input`. It completes autonomously.

---

## Step R.1: Config Gate

```
READ config -> retrospective.enabled
IF NOT enabled:
    WRITE summary with:
        status: completed
        flags:
          skipped: true
          skip_reason: "retrospective.enabled = false"
    SET current_stage = "complete"
    RETURN
```

---

## Step R.2: KPI Report Card

Compute 10 handoff-specific KPIs from state file, stage summaries, and judge verdicts. Write to `design-handoff/.handoff-report-card.local.md`.

### KPI Definitions

| ID | KPI | Source | Green | Yellow | Red |
|----|-----|--------|-------|--------|-----|
| H1 | Screens Prepared | `state.screens` prepared count / total | 100% | >= 80% | < 80% |
| H2 | Per-Screen Fix Cycles | Average `fix_attempts` across all screens | <= 1 | <= 2 | 3 (circuit breaker) |
| H3 | TIER Distribution | `state.tier_decision.tier` | Info | Info | Info |
| H4 | Judge Verdicts | Per-checkpoint pass/needs_fix/block from `design-handoff/judge-verdicts/` | All pass | Any needs_fix | Any block |
| H5 | Gap Categories Found | Per-category count from `design-handoff/gap-report.md` | Info | Info | Info |
| H6 | Missing Screens | Count of MUST_CREATE items in `state.missing_screens` | 0 | <= 2 | 3+ |
| H7 | Smart Componentization | Candidates count vs created count from `state.tier_decision` | Info | Info | Info |
| H8 | Visual Diff Pass Rate | Count of screens passing qualitative visual diff on first attempt | Info | Info | Info |
| H9 | Design Extension | Count of screens created in Stage 3.5 | Info | Info | Info |
| H10 | Supplement Size | Line count of `design-handoff/HANDOFF-SUPPLEMENT.md` | Info | Info | Info |

### Report Card Format

```yaml
---
skill_type: design-handoff
generated_at: "{ISO_NOW}"
kpis:
  - id: H1
    name: "Screens Prepared"
    value: "{prepared}/{total} ({pct}%)"
    traffic_light: "{green|yellow|red}"
  - id: H2
    name: "Per-Screen Fix Cycles"
    value: "{avg}"
    traffic_light: "{green|yellow|red}"
  # ... H3-H10
---
```

### Data Collection

```
READ state file: design-handoff/.handoff-state.local.md
    EXTRACT: screens (array with status, fix_attempts per screen),
             tier_decision, missing_screens, effective_tier

READ judge verdicts: design-handoff/judge-verdicts/*.md
    EXTRACT: per-checkpoint verdict (pass/needs_fix/block)

READ gap report: design-handoff/gap-report.md
    EXTRACT: per-category gap counts (behavior, state, data, interaction, responsive, accessibility)

CHECK file existence and line count:
    design-handoff/HANDOFF-SUPPLEMENT.md

COUNT screens with status == "prepared" vs total
COMPUTE average fix_attempts across all screens
COUNT MUST_CREATE items in missing_screens
COUNT screens created in Stage 3.5 (designer_decision == "create" + status == "created" or "verified")
```

Write the report card to: `design-handoff/.handoff-report-card.local.md`

---

## Step R.3: Transcript Extraction (Conditional)

```
READ config -> retrospective.transcript_analysis.enabled
IF NOT enabled:
    SET transcript_data = null
    SKIP to Step R.4

READ config -> retrospective.transcript_analysis.transcript_dir
IF transcript_dir is null:
    AUTO-DETECT: search ~/.claude/projects/ for the JSONL matching this session
    IF not found: SET transcript_data = null, SKIP to Step R.4

DISPATCH throwaway subagent:
    Task(subagent_type="general-purpose", prompt="""
    Extract session behavior data from the transcript JSONL.

    Transcript path: {TRANSCRIPT_PATH}
    Token budget: {config.retrospective.transcript_analysis.extract_token_budget}

    Extract:
    1. Tool usage counts (tool name → call count)
    2. Errors (up to {max_errors_extracted}): timestamp, tool, error message, resolution
    3. File heatmap (up to {max_file_paths_extracted}): file path → read count, write count

    Filter to only entries between workflow start ({state.started_at}) and completion.

    Write JSON output to: design-handoff/.stage-summaries/transcript-extract.json

    Schema:
    {
      "tool_usage": {"tool_name": count},
      "errors": [{"timestamp": "", "tool": "", "message": "", "resolution": ""}],
      "file_heatmap": [{"path": "", "reads": 0, "writes": 0}]
    }
    """)

READ result: design-handoff/.stage-summaries/transcript-extract.json
IF file exists and valid JSON:
    SET transcript_data = file contents
ELSE:
    SET transcript_data = null
```

---

## Step R.4: Writer Dispatch

Compile variables and dispatch the shared retrospective writer agent.

```
COLLECT stage summaries:
    READ all stage summary files from design-handoff/.stage-summaries/
    CONCATENATE YAML frontmatters into STAGE_SUMMARIES string
    INCLUDE judge verdict summaries

READ report card: design-handoff/.handoff-report-card.local.md
SET REPORT_CARD_DATA = file contents

READ config -> retrospective.sections
SET SECTIONS_CONFIG = sections block as YAML

DISPATCH definition-retrospective-writer:
    Task(subagent_type="general-purpose", prompt="""
    You are the definition-retrospective-writer agent.
    Read your instructions at: @$CLAUDE_PLUGIN_ROOT/agents/definition-retrospective-writer.md

    Variables:
    - SKILL_TYPE: design-handoff
    - FEATURE_DIR: design-handoff
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

    Write output to: design-handoff/retrospective.md
    """)
```

Verify output file exists: `design-handoff/retrospective.md`

---

## Step R.5: State Update + Summary

After writer completes:

```
SET current_stage = "complete"
SET last_updated = NOW()
Recompute checksum and WRITE state file (atomic)
```

Note: The orchestrator sets `current_stage = "retrospective"` before dispatching this protocol, and this protocol sets `current_stage = "complete"` upon completion. The `"complete"` state remains the sole terminal state.

## Summary Contract

```yaml
---
stage: "retrospective"
stage_number: null
status: completed
checkpoint: RETROSPECTIVE
artifacts_written:
  - design-handoff/.handoff-report-card.local.md
  - design-handoff/.stage-summaries/transcript-extract.json
  - design-handoff/retrospective.md
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
1. `design-handoff/.handoff-report-card.local.md` exists and contains all 10 KPIs
2. `design-handoff/retrospective.md` exists and has the Executive Summary section
3. State file has `current_stage: "complete"` (this protocol finalizes to terminal)
4. Summary YAML has no placeholder values (`{N}` must be replaced with actual numbers)
5. No Stage 1-5J artifacts were modified (read-only constraint)

## Critical Rules Reminder

Rules 1-4 above apply. Key: config gate first, read-only analysis, failures are non-blocking, no user interaction.
