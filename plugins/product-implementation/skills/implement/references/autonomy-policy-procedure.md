# Autonomy Policy Check — Shared Procedure

> Parameterized procedure for autonomy-policy-driven resolution of findings and failures.
> Referenced by: `stage-2-execution.md` (Steps 3.5, 3.7), `stage-3-validation.md` (Section 3.4),
> `stage-5-documentation.md` (Section 5.1). Note: Stage 4 implements its own auto-decision matrix
> inline (Section 4.4) — it does not use this shared procedure.

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `finding_severity_map` | map | `{severity → list_of_findings}` for findings to process |
| `context_label` | string | Human-readable label for log messages (e.g., "UAT", "validation", "quality review") |
| `fix_agent_config` | object | `{agent_type, prompt_template, prompt_vars}` — how to dispatch the fix agent |
| `defer_artifact_path` | string | Path to write deferred findings (e.g., `{FEATURE_DIR}/review-findings.md`) |
| `stage_log_prefix` | string | Prefix for stage log entries (e.g., `"Stage 2"`, `"Stage 4"`) |

## Procedure

1. **Read policy**: Read `autonomy_policy` from Stage 1 summary. Read the policy level definition from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml` under `autonomy_policy.levels.{policy}`.

2. **Per-severity iteration**: For each severity level present in `finding_severity_map` (iterate in order: critical, high, medium, low), look up `policy.findings.{severity}` action:
   - `"fix"` → add findings to `fix_list`
   - `"defer"` → add findings to `defer_list`
   - `"accept"` → add findings to `accept_list`

3. **Apply fix_list** (if non-empty):
   - Dispatch fix agent using `fix_agent_config`
   - Log: `"[AUTO-{policy}] {context_label} — auto-fixing {count} findings ({severity_breakdown})"`
   - After fix, re-validate once. If retry still fails for these findings, move them to `defer_list`

4. **Apply defer_list** (if non-empty):
   - Write findings to `defer_artifact_path` (append under a section headed `## {context_label} Findings`)
   - Log: `"[AUTO-{policy}] {context_label} — deferred {count} findings"`

5. **Apply accept_list** (if non-empty):
   - Log: `"[AUTO-{policy}] {context_label} — accepted {count} findings"`

6. **Determine outcome**:
   - If fix_list was processed → outcome = `"fixed"`
   - Else if defer_list was processed → outcome = `"deferred"`
   - Else → outcome = `"accepted"`

7. **No policy set** (edge case): If `autonomy_policy` is null or missing from Stage 1 summary, fall through to manual escalation — set `status: needs-user-input` with `block_reason` describing the findings. The orchestrator mediates user interaction.

## Special Case: Infrastructure Failures

Infrastructure failures (e.g., code simplification breaking tests, coordinator crash, build failure) are NOT severity-based findings. They use the `policy.infrastructure` action instead:

- `"retry_then_continue"` → retry once, then continue with degraded state
- `"retry_then_ask"` → retry once, then ask user via manual escalation

Simplification test failures are a special sub-case: revert is always safe (restores known-good code), so all policy levels auto-revert regardless of the infrastructure action.

## Logging Convention

All auto-resolved decisions use the prefix `[AUTO-{policy}]` where `{policy}` is the level key (e.g., `full_auto`, `balanced`, `critical_only`). This enables Stage 6 retrospective to count auto-resolutions via log scanning.

## Gate Policy Dimensions

Two additional policy fields control behavior for gates and probes — independent of finding severity.

| Field | Controls | Options |
|-------|----------|---------|
| `gate_prerequisites` | Behavior when a required probe field is ABSENT (probe was not executed) | `halt`, `warn_and_continue`, `ask` |
| `gate_skip` | Behavior when a gate is intentionally skipped (prerequisite reports available=false) | `halt`, `warn_and_continue`, `ask` |

**Defaults per level:**
- `full_auto`: prerequisites=`warn_and_continue`, skip=`warn_and_continue` (never block)
- `balanced`: prerequisites=`halt`, skip=`ask` (missing probes are serious; skipped gates need confirmation)
- `critical_only`: prerequisites=`halt`, skip=`ask` (same as balanced — missing probes always halt)

**Backward compatibility:** If `gate_prerequisites` or `gate_skip` fields are absent from a policy level definition, the system falls back to the current default behavior for that level (halt for balanced/critical_only, warn for full_auto).

**Consumers:**
- `VALIDATE_STAGE1_SUMMARY` (orchestrator-loop.md) reads `gate_prerequisites` to decide halt vs warn when required summary fields are missing
- `VERIFY_NON_SKIPPABLE_GATES` (orchestrator-loop.md) reads `gate_skip` to decide halt vs ask when a gate was skipped despite prerequisites being available
