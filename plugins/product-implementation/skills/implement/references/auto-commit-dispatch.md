---
description: "Shared auto-commit dispatch procedure for Stage 2, 4, and 5 coordinators"
referenced_by:
  - "stage-2-execution.md (Step 4.5)"
  - "stage-4-quality-review.md (Section 4.4 step 6)"
  - "stage-5-documentation.md (Section 5.3a)"
---

# Auto-Commit Dispatch Procedure

Shared procedure for committing milestone changes via a throwaway subagent. Each calling stage provides parameters specific to its context.

## Parameters

Each caller provides these values when invoking this procedure:

| Parameter | Type | Description |
|-----------|------|-------------|
| `template_key` | string | Key from `auto_commit.message_templates` in config (e.g., `phase_complete`, `review_fix`, `documentation`) |
| `substitution_vars` | map | Template variables to substitute: `{feature_name}` (always), `{phase_name}` (only for `phase_complete`) |
| `skip_target` | string | Section/step to continue to if auto-commit is disabled or after completion |
| `summary_field` | string | YAML field name for recording commit SHA(s) in stage summary (`commits_made` array or `commit_sha` scalar) |

## Procedure

1. Read `auto_commit` section from `$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml`
2. If `auto_commit.enabled` is `false`, skip to `{skip_target}`
3. Build commit message from `auto_commit.message_templates.{template_key}`:
   - Substitute each entry in `{substitution_vars}` into the template
   - Example: `phase_complete` with `{feature_name}=user-auth, {phase_name}=Phase 1: Setup` produces `feat(user-auth): implement Phase 1: Setup`
4. Format exclusion patterns from `auto_commit.exclude_patterns` as a bullet list
5. Dispatch a throwaway commit subagent:

```
Task(subagent_type="general-purpose")
```

Using the Auto-Commit Prompt from `agent-prompts.md`, prefilling:
- `{commit_message}` — built in step 3
- `{FEATURE_DIR}` — from Stage 1 summary
- `{exclude_patterns_formatted}` — built in step 4

6. Parse the subagent's structured output (`commit_status`, `commit_sha`, `files_committed`, `reason`)
7. Log the result:
   - On `success`: `"Auto-commit: {commit_sha} ({files_committed} files)"`
   - On `failed` or `skipped`: `"Auto-commit skipped/failed: {reason}"` — **do NOT halt**, continue to `{skip_target}`
8. Record `commit_sha` (or `null`) for `{summary_field}` in the stage summary

## Error Handling

Auto-commit failure is always **warn-and-continue**. A failed commit NEVER blocks execution. Changes remain on disk and will be included in subsequent commits or manual intervention.

## Exclude Pattern Matching

Patterns in `auto_commit.exclude_patterns` are matched as substrings against the git-status-relative file path. For example, the pattern `.stage-summaries/` matches any path containing that substring (e.g., `specs/001-user-auth/.stage-summaries/stage-1-summary.md`).

## Stage 2 Batch Strategy

When `auto_commit.stage2_strategy` is `batch` in config, the Stage 2 coordinator skips per-phase commits in the phase loop and instead dispatches a single commit after all phases complete, using the `phase_batch` template. This reduces latency for multi-phase features at the cost of per-phase git history granularity.

When `stage2_strategy` is `per_phase` (default), each phase triggers an individual commit via this procedure.
