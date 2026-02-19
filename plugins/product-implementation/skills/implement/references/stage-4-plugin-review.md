---
purpose: "Stage 4 Tier B: Plugin-based quality review via code-review skill"
referenced_by:
  - "stage-4-quality-review.md (Section 4.1, Tier B)"
config_source: "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml (quality_review, cli_dispatch.stage4)"
---

# Stage 4 — Tier B: Plugin Review

> **Extracted from**: `stage-4-quality-review.md` Section 4.1 for modularity.
> Tier B runs when the `code-review` plugin is installed alongside `product-implementation`.
> The coordinator dispatches Tier B via a context-isolated subagent.

## Detection

Read `plugin_availability.code_review` from the Stage 1 summary (cached in Section 1.6f).

- **If `true`**: Tier B is available. Proceed with dispatch below.
- **If `false`**: Tier B is unavailable. Skip this section entirely — Tier A (native reviewers) and Tier C (CLI reviewers) provide full coverage.

## Dispatch

Invoke via a context-isolated `Task(subagent_type="general-purpose")` subagent to prevent plugin output from bloating the coordinator's context:

```
Task(subagent_type="general-purpose", prompt="
  Invoke the skill `code-review:review-local-changes`.
  Write the output to {FEATURE_DIR}/.stage-summaries/plugin-review-output.md.
  Do not summarize or filter — write the raw skill output.
")
```

After the subagent completes, the coordinator reads the output file (not the subagent's return value).

## Finding Normalization

The `code-review` plugin produces findings in its own format (CEK confidence + impact scoring). The coordinator normalizes these to match the Stage 4 severity scale using thresholds from `config/implementation-config.yaml` under `cli_dispatch.stage4.review_plugins.confidence_mapping` (canonical source — see config for current values).

| Plugin Output | Stage 4 Severity | Config Key |
|---------------|-----------------|------------|
| confidence >= `critical.min_confidence` AND impact = `critical.impact` | Critical | `confidence_mapping.critical` |
| confidence >= `high.min_confidence` AND impact = `high.impact` | High | `confidence_mapping.high` |
| confidence >= `medium.min_confidence` OR impact = "medium" | Medium | `confidence_mapping.medium` |
| All others | Low | `confidence_mapping.low` |

### Normalization Procedure

1. Parse plugin output for finding entries (typically `[severity] description — file:line` format)
2. For each finding, extract or infer:
   - `confidence` (if present in plugin output; default 0.7 if not reported)
   - `impact` (if present; default "medium" if not reported)
   - `file:line` location
   - `description` and `recommendation`
3. Map to Stage 4 severity using the table above
4. Convert to the standard consolidation format: `[{severity}] {description} — {file}:{line} — Source: plugin`

## Max Findings Cap

Cap at 50 findings from Tier B. If the plugin reports more, keep the highest-severity findings and log: "Plugin review capped at 50 findings ({N} total reported)."

## Graceful Degradation

- If plugin invocation returns an error: log warning, continue with Tiers A and C only
- If plugin produces no parseable findings: treat as "no issues found" from this tier
- If the subagent crashes or times out: log warning, continue without Tier B results

## Integration with Consolidation

Tier B findings are added to the same finding pool as Tier A (native) and Tier C (CLI) findings before the Section 4.3 consolidation step. The consolidation deduplicates across all tiers, with consensus scoring applied when multiple tiers flag the same issue.
