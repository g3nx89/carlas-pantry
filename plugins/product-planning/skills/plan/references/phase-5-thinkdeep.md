---
phase: "5"
phase_name: "PAL ThinkDeep Analysis"
checkpoint: "THINKDEEP"
delegation: "coordinator"
modes: [complete, advanced]
prior_summaries:
  - ".phase-summaries/phase-4-summary.md"
artifacts_read:
  - "design.md"
artifacts_written:
  - "analysis/thinkdeep-insights.md"
  - "analysis/cli-deepthinker-report.md"  # conditional: CLI dispatch enabled
agents: []
mcp_tools:
  - "mcp__pal__thinkdeep"
  - "mcp__pal__listmodels"
feature_flags:
  - "cli_context_isolation"
  - "cli_custom_roles"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/thinkdeep-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
---

# Phase 5: PAL ThinkDeep Analysis

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-5-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 5.1: Check Prerequisites

```
IF analysis_mode in {standard, rapid}: → Skip phase (write summary with status: skipped)
IF PAL unavailable: → Skip (graceful degradation, write summary with status: skipped)
```

## Step 5.1b: Verify Model Availability

```
# Query available models from PAL MCP server
available_models = mcp__pal__listmodels()

# Define required models for ThinkDeep (configurable in planning-config.yaml)
required_models = ["gpt-5.2", "gemini-3-pro-preview", "openrouter/x-ai/grok-4"]

# Check availability and find alternatives if needed
model_substitutions = {}
unavailable_count = 0

FOR model IN required_models:
  IF model NOT IN available_models.models:
    LOG: "Warning: {model} unavailable"
    unavailable_count += 1

    # Try to find alternative from same provider family
    alternative = find_alternative(model, available_models.models)
    IF alternative:
      LOG: "Substituting {model} → {alternative}"
      model_substitutions[model] = alternative
    ELSE:
      LOG: "No alternative found for {model}"

# Determine if we can proceed
IF unavailable_count >= len(required_models):
  LOG: "No ThinkDeep models available - skipping to Phase 6"
  → Write summary with status: skipped (graceful degradation)

ELSE IF unavailable_count >= 2:
  LOG: "Insufficient models for full analysis - degrading to reduced ThinkDeep"
  # Continue with available models only

# Apply substitutions to models list used in Step 5.3
FOR original, substitute IN model_substitutions:
  REPLACE original with substitute in thinkdeep_models
```

## Step 5.2: Prepare Context

```
READ selected architecture: {FEATURE_DIR}/design.md

PREPARE problem_context with:
  - Feature summary
  - Selected architecture approach
  - Codebase patterns (from Phase 4 summary context)
```

## Step 5.3: Execute ThinkDeep Matrix

| Mode | Perspectives | Models | Total Calls |
|------|--------------|--------|-------------|
| Complete | 3 (perf, maint, sec) | 3 | 9 |
| Advanced | 2 (perf, sec) | 3 | 6 |

For each perspective x model:

```
# Initialize continuation tracking per perspective
continuation_ids = {}

FOR each perspective IN [performance, maintainability, security]:
  FOR i, model IN enumerate(models):

    response = mcp__pal__thinkdeep({
      step: """
        Analyze this architecture from a {PERSPECTIVE} perspective.

        FEATURE: {FEATURE_NAME}
        ARCHITECTURE: {selected_approach}

        MY CURRENT ANALYSIS:
        {architecture_summary}

        EXTEND MY ANALYSIS - Focus on:
        {perspective_focus_areas}
      """,
      step_number: 1,
      total_steps: 1,
      next_step_required: false,
      model: "{model}",
      thinking_mode: "high",
      confidence: "medium",
      hypothesis: "Architecture is sound from {PERSPECTIVE} perspective - validating assumptions",
      focus_areas: ["{perspective_focus}"],
      findings: "{initial_findings_from_architecture}",
      problem_context: "{problem_context_template}",
      relevant_files: ["{ABSOLUTE_PATH}/design.md"],
      continuation_id: continuation_ids.get(perspective) or null
    })

    # Store continuation_id for next model in same perspective
    IF i == 0:
      continuation_ids[perspective] = response.continuation_id
```

## Step 5.4: Synthesize Insights

Write `{FEATURE_DIR}/analysis/thinkdeep-insights.md`:
- Per-model findings
- **Convergent insights** (all agree) → CRITICAL priority
- **Divergent insights** (disagree) → FLAG for decision
- Recommended architecture updates

## Step 5.5: Present Findings

**USER INTERACTION:** The user should review ThinkDeep findings.

Set `status: needs-user-input` in your summary with:
- `block_reason`: Summary of findings, asking user to choose:
  A) Accept recommendations and update architecture
  B) Review divergent points one by one
  C) Proceed without changes

On re-dispatch, read `{FEATURE_DIR}/.phase-summaries/phase-5-user-input.md` for the selection.

**Checkpoint: THINKDEEP**

## Step 5.6: CLI Deepthinker Supplement

**Purpose:** Supplement ThinkDeep matrix with broad codebase exploration (Gemini) and code-level coupling analysis (Codex) via CLI dispatch. Runs AFTER user reviews ThinkDeep findings.

Follow the **CLI Dual-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `deepthinker` |
| PHASE_STEP | `5.6` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Supplement ThinkDeep analysis for feature: {FEATURE_NAME}. Architecture: {FEATURE_DIR}/design.md. ThinkDeep findings so far: {FEATURE_DIR}/analysis/thinkdeep-insights.md. Focus: Broad architecture exploration, tech stack validation, pattern conflicts.` |
| CODEX_PROMPT | `Supplement ThinkDeep analysis for feature: {FEATURE_NAME}. Architecture: {FEATURE_DIR}/design.md. ThinkDeep findings so far: {FEATURE_DIR}/analysis/thinkdeep-insights.md. Focus: Import chain analysis, coupling assessment, code-level complexity.` |
| FILE_PATHS | `["{FEATURE_DIR}/design.md", "{FEATURE_DIR}/analysis/thinkdeep-insights.md"]` |
| REPORT_FILE | `analysis/cli-deepthinker-report.md` |
| PREFERRED_SINGLE_CLI | `gemini` |
| POST_WRITE | `APPEND CLI supplement section to {FEATURE_DIR}/analysis/thinkdeep-insights.md` |
