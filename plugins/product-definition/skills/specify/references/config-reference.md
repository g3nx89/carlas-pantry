# Configuration & Variables Reference

> Centralized reference for the Feature Specify workflow.

## Template Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{TIMESTAMP}` | ISO 8601 datetime | `2026-01-27T10:30:00Z` |
| `{ISO_DATE}` | Date portion | `2026-01-27` |
| `{ISO_TIMESTAMP}` | Full ISO timestamp | `2026-01-27T10:30:00Z` |
| `{NUMBER}` | Feature number | `1`, `2` |
| `{SHORT_NAME}` | Feature short name | `add-user-auth` |
| `{FEATURE_DIR}` | Feature directory name | `1-add-user-auth` |
| `{FEATURE_NAME}` | Human-readable feature name | `Add User Authentication` |
| `{USER_INPUT}` | Original user feature description | (text) |
| `{SPEC_FILE}` | Path to spec | `specs/1-add-user-auth/spec.md` |
| `{STATE_FILE}` | Path to state | `specs/1-add-user-auth/.specify-state.local.md` |
| `{LOCK_FILE}` | Path to lock | `specs/1-add-user-auth/.specify.lock` |
| `{FIGMA_CONTEXT_FILE}` | Path to Figma context | `specs/1-add-user-auth/figma_context.md` |
| `{RESUME_CONTEXT}` | Resume context from state | (generated text or empty) |
| `{STAGE_NUMBER}` | Current stage number | `3` |
| `{STAGE_NAME}` | Current stage name | `CHECKLIST_VALIDATION` |
| `{MODEL_NAME}` | CLI model identifier | `codex`, `gemini`, `opencode` |
| `{ERROR_MESSAGE}` | Error details | `Connection timeout` |
| `{REMAINING_COUNT}` | Remaining models after failure | `2` |
| `{TOTAL}` | Total models configured | `3` |

---

## File Naming Conventions

| File Pattern | Purpose | Example |
|--------------|---------|---------|
| `spec.md` | Feature specification | (fixed name) |
| `spec-checklist.md` | Annotated checklist | (fixed name) |
| `design-brief.md` | Screen/state inventory | (fixed name) |
| `design-supplement.md` | Design analysis | (fixed name) |
| `clarification-questions.md` | File-based clarification questions | (fixed name) |
| `clarification-report.md` | Auto-resolve audit trail | (fixed name) |
| `test-strategy.md` | V-Model test strategy | (fixed name) |
| `figma_context.md` | Figma design context | (fixed name) |
| `.specify-state.local.md` | Workflow state | (fixed name) |
| `.specify.lock` | Session lock | (fixed name) |
| `analysis/mpa-challenge*.md` | Challenge CLI dispatch report | (with -parallel suffix if parallel) |
| `analysis/mpa-edgecases*.md` | Edge Cases CLI dispatch report | (with -parallel suffix if parallel) |
| `analysis/mpa-triangulation.md` | Triangulation report | (fixed name) |
| `.stage-summaries/stage-{N}-summary.md` | Stage summaries | `stage-2-summary.md` |

---

## Key Configuration Values

**Source:** `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

### Limits

| Setting | Path | Value |
|---------|------|-------|
| CLI rejection retries | `limits.cli_rejection_retries_max` | 2 |
| Questions per batch (deprecated) | `limits.questions_per_batch` | 4 (deprecated — file-based mode) |
| Lock stale timeout (minutes) | `limits.lock_stale_timeout_minutes` | 60 |
| Max user stories | `limits.max_user_stories` | **null** (no limit) |
| Max acceptance criteria | `limits.max_acceptance_criteria` | **null** (no limit) |
| Max NFRs | `limits.max_nfrs` | **null** (no limit) |
| Max clarification questions | `limits.max_clarification_questions` | **null** (no limit) |

### Thresholds

| Setting | Path | Value |
|---------|------|-------|
| Checklist GREEN | `thresholds.checklist.green` | 85% |
| Checklist YELLOW | `thresholds.checklist.yellow` | 60% |
| CLI eval GREEN | `thresholds.cli_eval.green` | 16/20 |
| CLI eval YELLOW | `thresholds.cli_eval.yellow` | 12/20 |
| Self-critique pass | `thresholds.self_critique.pass` | 16/20 |
| Incremental gate problem min | `incremental_gates.gate_1_problem_quality.thresholds.green` | 4 |
| Incremental gate true need min | `incremental_gates.gate_2_true_need.thresholds.green` | 4 |

### Feature Flags

| Flag | Path | Default |
|------|------|---------|
| Incremental gates | `feature_flags.enable_incremental_gates` | true |
| CLI validation | `feature_flags.enable_cli_validation` | true |
| Self-critique | `feature_flags.enable_self_critique` | true |
| Figma integration | `feature_flags.enable_figma_integration` | true |
| Test strategy | `feature_flags.enable_test_strategy` | true |

---

## CLI Dispatch Quick Reference

> **IMPORTANT:** Authoritative dispatch syntax lives in each stage file and `cli-dispatch-patterns.md`. This section is a parameter reference only.

### Script Invocation Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `--cli` | string | Yes | CLI name: `codex`, `gemini`, or `opencode` |
| `--role` | string | Yes | Role name from CLI's JSON config (e.g., `spec_root_cause`) |
| `--prompt-file` | path | Yes | Path to prompt file with embedded spec content |
| `--output-file` | path | Yes | Path where extracted output will be written |
| `--timeout` | integer | No | Timeout in seconds (default: 300) |
| `--expected-fields` | string | No | Comma-separated fields to validate in SUMMARY block |

### Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Use output file |
| 1 | CLI failure | Retry up to `cli_dispatch.retry.max_attempts` |
| 2 | Timeout | Retry up to `cli_dispatch.retry.max_attempts` |
| 3 | CLI not found in PATH | Skip — do NOT retry |
| 4 | Parse failure (no structured output) | Include raw output in synthesis (best-effort) |

### Common Mistakes (CRITICAL)

| Mistake | Impact | Fix |
|---------|--------|-----|
| Passing file paths in prompt file | CLI cannot read local files | Embed spec content inline in prompt file |
| Not checking exit code 3 | Hangs on missing CLI | Check exit code before retry |
| Ignoring exit code 4 output | Loses partial results | Include in synthesis even if unstructured |
| Running evaluation with < 2 responses | Invalid scoring | Check `clis_substantive` before computing score |

### CLI → Model Mapping

| CLI | Model | Provider | Characteristic |
|-----|-------|----------|----------------|
| `codex` | GPT-4o | OpenAI | Precision, logical rigor, structured analysis |
| `gemini` | Gemini Pro | Google | Breadth, cross-domain synthesis, coverage |
| `opencode` | Grok (via OpenRouter) | xAI | Contrarian, assumption-challenging, unconventional |

### Stage 5 Evaluation Dimensions

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| Business value clarity | 4/20 | Clear problem, measurable impact |
| Requirements completeness | 4/20 | All user stories with ACs |
| Scope boundaries | 4/20 | Clear in/out of scope |
| Stakeholder coverage | 4/20 | All personas addressed |
| Technology agnosticism | 4/20 | No implementation details |

**Minimum Substantive Responses Required:** 2 (for evaluation scoring)

---

## Graceful Degradation Matrix

| CLI/MCP Status | Challenge / Edge Cases / Triangulation | Gates | Evaluation (Stage 5) | Design Artifacts |
|----------------|---------------------------------------|-------|----------------------|-----------------|
| CLI + ST + Figma available | Full tri-CLI dispatch | Judge-evaluated | Multi-stance (3 CLIs) | Full |
| CLI available, ST unavailable | Full tri-CLI dispatch | Internal evaluation | Multi-stance (3 CLIs) | Full |
| CLI unavailable, ST available | Skipped (internal reasoning) | Internal evaluation | Skipped (internal gates) | Full |
| Figma unavailable | Full (unaffected) | Full | Full | Spec-only mode |
| All unavailable | Skipped | Internal evaluation | Skipped | Spec-only mode |

*Design artifacts (design-brief.md, design-supplement.md) are ALWAYS generated regardless of CLI/MCP availability.
