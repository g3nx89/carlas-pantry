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
| `{MODEL_NAME}` | PAL model identifier | `gpt-5.2` |
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
| `test-plan.md` | V-Model test strategy | (fixed name) |
| `figma_context.md` | Figma design context | (fixed name) |
| `.specify-state.local.md` | Workflow state | (fixed name) |
| `.specify.lock` | Session lock | (fixed name) |
| `analysis/mpa-challenge*.md` | Challenge ThinkDeep report | (with -parallel suffix if parallel) |
| `analysis/mpa-edgecases*.md` | Edge Cases ThinkDeep report | (with -parallel suffix if parallel) |
| `analysis/mpa-triangulation.md` | Triangulation report | (fixed name) |
| `.stage-summaries/stage-{N}-summary.md` | Stage summaries | `stage-2-summary.md` |

---

## Key Configuration Values

**Source:** `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

### Limits

| Setting | Path | Value |
|---------|------|-------|
| PAL rejection retries | `limits.pal_rejection_retries_max` | 2 |
| Questions per batch (deprecated) | `limits.questions_per_batch` | 4 (deprecated — file-based mode) |
| Lock staleness hours | `limits.lock_staleness_hours` | 2 |
| Max user stories | `limits.max_user_stories` | **null** (no limit) |
| Max acceptance criteria | `limits.max_acceptance_criteria` | **null** (no limit) |
| Max NFRs | `limits.max_nfrs` | **null** (no limit) |
| Max clarification questions | `limits.max_clarification_questions` | **null** (no limit) |

### Thresholds

| Setting | Path | Value |
|---------|------|-------|
| Checklist GREEN | `thresholds.checklist.green` | 85% |
| Checklist YELLOW | `thresholds.checklist.yellow` | 60% |
| PAL GREEN | `thresholds.pal.green` | 16/20 |
| PAL YELLOW | `thresholds.pal.yellow` | 12/20 |
| Self-critique pass | `thresholds.self_critique.pass` | 16/20 |
| Incremental gate problem min | `incremental_gates.gate_1_problem_quality.thresholds.green` | 4 |
| Incremental gate true need min | `incremental_gates.gate_2_true_need.thresholds.green` | 4 |

### Feature Flags

| Flag | Path | Default |
|------|------|---------|
| Incremental gates | `feature_flags.enable_incremental_gates` | true |
| PAL validation | `feature_flags.enable_pal_validation` | true |
| Self-critique | `feature_flags.enable_self_critique` | true |
| Figma integration | `feature_flags.enable_figma_integration` | true |
| Test strategy | `feature_flags.enable_test_strategy` | true |

---

## PAL Tool Quick Reference

> **IMPORTANT:** Authoritative PAL call syntax lives in each stage file and `thinkdeep-patterns.md`. This section is a parameter reference only.

### Shared Parameters (ThinkDeep & Consensus)

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Your current analysis — NOT just a title |
| `step_number` | integer | Yes | Current step in multi-step chain |
| `total_steps` | integer | Yes | ThinkDeep: 3 per chain. Consensus: models + 1 |
| `next_step_required` | boolean | Yes | True until final step |
| `findings` | string | Yes | Summary of discoveries — MUST NOT be empty |
| `relevant_files` | array | No | Context files — MUST use ABSOLUTE paths |
| `continuation_id` | string | No | Thread ID from previous step — required on steps 2+ |

### ThinkDeep-Only Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `model` | string | Single model ID (e.g., `gpt-5.2`) |
| `thinking_mode` | string | `"high"` for deep analysis |
| `confidence` | string | `"exploring"` → `"low"` → `"high"` across steps |
| `focus_areas` | array | e.g., `["competitive_analysis", "market_positioning"]` |
| `problem_context` | string | MUST include "This is BUSINESS/SPECIFICATION ANALYSIS, not code analysis" |

### Consensus-Only Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `models` | array | List of `{model, stance, stance_prompt}` objects |
| `models[].stance` | string | `"neutral"`, `"for"`, or `"against"` |

### Common Mistakes (CRITICAL)

| Mistake | Impact | Fix |
|---------|--------|-----|
| Using `prompt` instead of `step` | Wrong parameter name | Both tools use `step` |
| Using `files` instead of `relevant_files` | Wrong parameter name | Both tools use `relevant_files` |
| Treating Consensus as single-call | Skips model processing | Multi-step: step 1 = analysis, steps 2-N = models, final = synthesis |
| Missing `continuation_id` on steps 2+ | Loses context | Pass from each previous step |
| Empty `findings` | Model has no context | NEVER empty |
| No spec disclaimer in `problem_context` | Model requests source files | Add "This is BUSINESS/SPECIFICATION ANALYSIS" |
| Relative file paths | Tool error | MUST use absolute paths |

---

## PAL Consensus Configuration

### Default Models

| Model | Stance | Purpose |
|-------|--------|---------|
| `gemini-3-pro-preview` | neutral | Objective assessment |
| `gpt-5.2` | for | Advocate for strengths |
| `x-ai/grok-4` | against | Challenge completeness |

**Minimum Models Required:** 2

### Content Delivery (CRITICAL)

| Setting | Path | Default | Description |
|---------|------|---------|-------------|
| Mode | `pal_consensus.content_delivery.mode` | `inline` | Always inline — never file paths |
| Word limit | `pal_consensus.content_delivery.inline_word_limit` | 4000 | Specs larger than this are auto-summarized |

### Response Validation

| Setting | Path | Default | Description |
|---------|------|---------|-------------|
| Enabled | `pal_consensus.response_validation.enabled` | `true` | Detect non-substantive responses |
| Min words | `pal_consensus.response_validation.min_response_words` | 50 | Responses shorter than this are flagged |
| Patterns | `pal_consensus.response_validation.non_substantive_patterns` | (list) | Strings that indicate model couldn't read content |
| Identical scores | `pal_consensus.response_validation.flag_identical_scores` | `true` | Flag responses with identical dimension scores |

### Stage 5 Evaluation Dimensions

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| Business value clarity | 4/20 | Clear problem, measurable impact |
| Requirements completeness | 4/20 | All user stories with ACs |
| Scope boundaries | 4/20 | Clear in/out of scope |
| Stakeholder coverage | 4/20 | All personas addressed |
| Technology agnosticism | 4/20 | No implementation details |

---

## Graceful Degradation Matrix

| MCP Status | ThinkDeep | Gates | PAL Consensus | Design Artifacts |
|------------|-----------|-------|---------------|-----------------|
| All available | Full | Judge-evaluated | Multi-model | Full |
| PAL unavailable | Skipped | Internal evaluation | Skipped | Full |
| ST unavailable | Internal reasoning | Internal evaluation | Full | Full |
| Figma unavailable | Full | Full | Full | Spec-only mode |
| All unavailable | Skipped | Internal evaluation | Skipped | Spec-only mode |

*Design artifacts (design-brief.md, design-supplement.md) are ALWAYS generated regardless of MCP availability.
