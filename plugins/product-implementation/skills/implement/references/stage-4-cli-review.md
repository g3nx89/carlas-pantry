---
purpose: "Stage 4 Tier C: Multi-model CLI quality review dispatches"
referenced_by:
  - "stage-4-quality-review.md (Section 4.1, Tier C)"
config_source: "$CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml (cli_dispatch.stage4)"
dispatch_procedure: "cli-dispatch-procedure.md"
---

# Stage 4 — Tier C: CLI Review

> **Extracted from**: `stage-4-quality-review.md` (now Section 4.2b) for modularity.
> Tier C dispatches external CLI agents (Codex, Gemini) for multi-model code review.
> Only runs when `cli_dispatch.stage4.multi_model_review.enabled` is `true`.

## Prerequisites

- `cli_dispatch.stage4.multi_model_review.enabled` must be `true` in config
- Read `cli_availability` from Stage 1 summary to check which CLIs are available
- Read `detected_domains` from Stage 1 summary for conditional reviewers

## Phase 1: Parallel Review Dispatch

Launch these reviewers in parallel. All dispatches follow the Shared CLI Dispatch Procedure (`cli-dispatch-procedure.md`).

### Reviewer Matrix

| Reviewer | CLI | Role | Focus | Fallback |
|----------|-----|------|-------|----------|
| Correctness | Codex | `correctness_reviewer` | Bugs, edge cases, race conditions, data flow | Native `developer` agent with same focus |
| Security | Codex | `security_reviewer` | OWASP Top 10, injection, auth bypass, exposed secrets | Skip (conditional — see below) |
| Android Domain | Gemini | `android_domain_reviewer` | Lifecycle, Compose recomposition, Material 3, coroutines | Skip (conditional — see below) |

### Correctness Reviewer (Always)

1. Check `cli_availability.codex` from Stage 1 summary
2. If available: Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/codex_correctness_reviewer.txt`. Inject variables:
   - `{FEATURE_DIR}`, `{TASKS_FILE}` — from Stage 1 summary
   - `{modified_files}` — file list from tasks.md `[X]` entries
   - `{skill_references}` — resolved in Section 4.1a (or fallback text)
3. Dispatch via `cli-dispatch-procedure.md` with:
   - `cli_name="codex"`, `role="correctness_reviewer"`
   - `fallback_behavior="native"`, `fallback_agent="product-implementation:developer"`, `fallback_prompt=` Quality Review Prompt from `agent-prompts.md` with focus "bugs, functional correctness, and edge case handling"
   - `expected_fields=["files", "findings", "top_risk", "data_flows_verified"]`
4. If CLI unavailable: immediately use native `developer` agent with same focus

### Security Reviewer (Conditional)

> Only triggers when `detected_domains` includes ANY of: `api`, `web_frontend`, `database` (configurable via `cli_dispatch.stage4.multi_model_review.conditional[].domains`).

1. Check `cli_availability.codex` and domain match
2. If both satisfied: Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/codex_security_reviewer.txt`. Inject variables:
   - `{FEATURE_DIR}`, `{TASKS_FILE}`, `{modified_files}`, `{detected_domains}`
3. Dispatch with:
   - `cli_name="codex"`, `role="security_reviewer"`
   - `fallback_behavior="skip"` (base reviewers still run)
   - `expected_fields=["files", "findings", "top_risk", "owasp_categories"]`

### Android Domain Reviewer (Conditional)

> Only triggers when `detected_domains` includes ANY of: `android`, `compose`, `kotlin` (configurable via `cli_dispatch.stage4.multi_model_review.conditional[].domains`).

1. Check `cli_availability.gemini` and domain match
2. If both satisfied: Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_android_domain_reviewer.txt`. Inject variables:
   - `{FEATURE_DIR}`, `{TASKS_FILE}`, `{modified_files}`, `{detected_domains}`
3. Dispatch with:
   - `cli_name="gemini"`, `role="android_domain_reviewer"`
   - `fallback_behavior="skip"`
   - `expected_fields=["findings", "top_risk", "lifecycle_issues", "compose_issues"]`

## Consolidation Checkpoint

After all Phase 1 dispatches complete:

1. Collect findings from all Phase 1 reviewers
2. Merge and deduplicate (same file:line = same finding)
3. Extract the Critical/High findings list for Phase 2

## Phase 2: Pattern Search (Sequential, Conditional)

> Only runs when Phase 1 produced at least one Critical or High finding.
> Gated by `cli_dispatch.stage4.pattern_search.min_severity_trigger` (default: "high").

The codebase pattern reviewer uses Gemini's 1M context window to search the entire codebase for the same vulnerability/bug patterns found in Phase 1.

### Procedure

1. Check: any Critical or High findings from Phase 1?
   - If none: skip Phase 2, proceed to consolidation
2. Check `cli_availability.gemini`
   - If unavailable: skip Phase 2, log warning
3. Build prompt from `$CLAUDE_PLUGIN_ROOT/config/cli_clients/gemini_codebase_pattern_reviewer.txt`. Inject variables:
   - `{FEATURE_DIR}`, `{PROJECT_ROOT}` — from Stage 1 summary
   - `{phase1_findings}` — Critical/High findings from Phase 1 (formatted as finding list)
   - `{modified_files}` — file list from tasks.md
4. Dispatch with:
   - `cli_name="gemini"`, `role="codebase_pattern_reviewer"`
   - `timeout_ms` from config (pattern search may need more time with large codebases)
   - `fallback_behavior="skip"` (Phase 1 findings are sufficient)
   - `expected_fields=["findings", "patterns_found", "files_scanned"]`
   - Context strategy: `max_context_tokens` from `cli_dispatch.stage4.codebase_pattern_reviewer.max_context_tokens` (default: 800000)

### Phase 2 Output

Any new findings from the pattern search are added to the consolidation pool with source tag "pattern_search". These findings inherit the severity of the original pattern they matched.

## Output Normalization

All CLI reviewers produce findings in `[{severity}] description -- file:line` format per the `<SUMMARY>` block convention in `config/cli_clients/shared/severity-output-conventions.md`. The coordinator normalizes all outputs into the Section 4.3 consolidation format before deduplication.

## Dev-Skills Conditional Reviewers

Conditional reviewers from `dev_skills.conditional_review` (Section 4.1a) still launch alongside Tier C. They are ALWAYS dispatched as native `developer` agents regardless of whether Tier C is enabled.
