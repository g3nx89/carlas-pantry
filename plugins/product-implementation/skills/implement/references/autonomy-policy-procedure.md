# Autonomy Policy Check — Shared Procedure

> Parameterized procedure for autonomy-policy-driven resolution of findings and failures.
> Referenced by: `stage-2-execution.md` (Steps 3.5, 3.7), `stage-3-validation.md` (Section 3.4),
> `stage-5-documentation.md` (Section 5.1). Note: Stage 4 implements its own auto-decision matrix
> inline (Section 4.4) — it does not use this shared procedure.

## Two Autonomy Levels

Read `autonomy` from Stage 1 summary. Two valid values:

| Level | Fix Critical | Fix High | Fix Medium | Accept Low | Fix Incomplete Tasks | Retry Infra |
|-------|-------------|----------|------------|------------|---------------------|-------------|
| `auto` | yes | yes | yes | yes | yes | yes |
| `interactive` | yes | yes | DEFER | yes | yes | yes |

All other behaviors (gate failures, coordinator crashes) are handled at the orchestrator level and are not part of this procedure.

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `finding_severity_map` | map | `{severity → list_of_findings}` for findings to process |
| `context_label` | string | Human-readable label for log messages (e.g., "UAT", "validation", "quality review") |
| `fix_agent_config` | object | `{agent_type, prompt_template, prompt_vars}` — how to dispatch the fix agent |
| `defer_artifact_path` | string | Path to write deferred findings (e.g., `{FEATURE_DIR}/review-findings.md`) |
| `stage_log_prefix` | string | Prefix for stage log entries (e.g., `"Stage 2"`, `"Stage 4"`) |

## Procedure

1. **Read policy**: Read `autonomy` from Stage 1 summary.

2. **Per-severity iteration**: For each severity level present in `finding_severity_map` (iterate in order: critical, high, medium, low):

   - `auto`: critical → fix, high → fix, medium → fix, low → accept
   - `interactive`: critical → fix, high → fix, medium → defer, low → accept

3. **Apply fix_list** (if non-empty):
   - Dispatch fix agent using `fix_agent_config`
   - Log: `"[AUTO-{autonomy}] {context_label} — auto-fixing {count} findings ({severity_breakdown})"`
   - After fix, re-validate once. If retry still fails for these findings, move them to `defer_list`

4. **Apply defer_list** (if non-empty):
   - Write findings to `defer_artifact_path` (append under a section headed `## {context_label} Findings`)
   - Log: `"[AUTO-{autonomy}] {context_label} — deferred {count} findings"`

5. **Apply accept_list** (if non-empty):
   - Log: `"[AUTO-{autonomy}] {context_label} — accepted {count} findings"`

6. **Determine outcome**:
   - If fix_list was processed → outcome = `"fixed"`
   - Else if defer_list was processed → outcome = `"deferred"`
   - Else → outcome = `"accepted"`

7. **No policy set** (edge case): If `autonomy` is null or missing from Stage 1 summary, fall through to manual escalation — set `status: needs-user-input` with `block_reason` describing the findings. The orchestrator mediates user interaction.

## Special Case: Infrastructure Failures

Infrastructure failures (e.g., code simplification breaking tests, coordinator crash, build failure) are NOT severity-based findings. Both policy levels use the same infrastructure behavior: `retry_then_continue` — retry once, then continue with degraded state.

Simplification test failures are a special sub-case: revert is always safe (restores known-good code), so both policy levels auto-revert regardless of the infrastructure action.

## Logging Convention

All auto-resolved decisions use the prefix `[AUTO-{autonomy}]` where `{autonomy}` is the level key (`auto` or `interactive`). This enables Stage 6 retrospective to count auto-resolutions via log scanning.
