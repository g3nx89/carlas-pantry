---
phase: "5"
phase_name: "Multi-CLI Deep Analysis"
checkpoint: "THINKDEEP"
delegation: "coordinator"
modes: [complete, advanced]
prior_summaries:
  - ".phase-summaries/phase-4-summary.md"
artifacts_read:
  - "spec.md"          # requirements context: acceptance criteria, user stories, constraints
  - "design.md"
artifacts_written:
  - "analysis/thinkdeep-insights.md"
  - "analysis/cli-deepthinker-performance-report.md"  # conditional: per-perspective
  - "analysis/cli-deepthinker-maintainability-report.md"  # conditional: Complete only
  - "analysis/cli-deepthinker-security-report.md"  # conditional: per-perspective
agents: []
mcp_tools: []
feature_flags:
  - "cli_context_isolation"
  - "cli_custom_roles"
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/thinkdeep-prompts.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
---

<!-- Mode Applicability -->
| Step | Rapid | Standard | Advanced | Complete | Notes |
|------|-------|----------|----------|----------|-------|
| 5.1  | —     | —        | ✓        | ✓        | Skips phase for Rapid/Standard |
| 5.2  | —     | —        | ✓        | ✓        | CLI availability check |
| 5.3  | —     | —        | ✓        | ✓        | — |
| 5.4  | —     | —        | ✓        | ✓        | 6 dispatches (Adv) / 9 dispatches (Complete) |
| 5.5  | —     | —        | ✓        | ✓        | Maintainability report Complete only |
| 5.6  | —     | —        | ✓        | ✓        | User interaction |

# Phase 5: Multi-CLI Deep Analysis

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
IF state.cli.available == false OR state.cli.mode == "disabled": → Skip (graceful degradation, write summary with status: skipped)
```

## Step 5.2: Verify CLI Availability

```
# Read CLI capabilities already populated by Phase 1 Step 1.6
cli_capabilities = state.cli.capabilities
cli_mode = state.cli.mode  # "tri", "dual", "single_*", or "disabled"

LOG: "CLI mode: {cli_mode}"

IF cli_mode == "disabled" OR no CLIs available:
  LOG: "No CLIs available — skipping to Phase 6"
  → Write summary with status: skipped (graceful degradation)
```

## Step 5.3: Prepare Context

```
READ feature requirements: {FEATURE_DIR}/spec.md
READ selected architecture: {FEATURE_DIR}/design.md

# Prefer requirements-anchor.md (consolidates spec + user clarifications from Phase 3)
# Fall back to raw spec.md if anchor not available or empty
IF file_exists({FEATURE_DIR}/requirements-anchor.md) AND not_empty({FEATURE_DIR}/requirements-anchor.md):
  requirements_file = "{FEATURE_DIR}/requirements-anchor.md"
  LOG: "Requirements context: using requirements-anchor.md (enriched)"
ELSE:
  requirements_file = "{FEATURE_DIR}/spec.md"
  LOG: "Requirements context: using spec.md (raw)"

READ requirements_file

PREPARE problem_context with:
  - Feature summary (from requirements_file)
  - Acceptance criteria (from requirements_file)
  - Key constraints and non-functional requirements (from requirements_file)
  - Selected architecture approach (from design.md)
  - Codebase patterns (from Phase 4 summary context)
```

## Step 5.4: Execute CLI Deep Analysis Matrix

| Mode | Perspectives | CLIs | Total Dispatches |
|------|--------------|------|------------------|
| Complete | 3 (perf, maint, sec) | 3 | 9 |
| Advanced | 2 (perf, sec) | 3 | 6 |

All dispatches are independent and can be launched simultaneously.

For each perspective, follow the **CLI Multi-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md`:

```
# Determine perspectives based on analysis mode
IF analysis_mode == "complete":
  perspectives = [performance, maintainability, security]
ELSE IF analysis_mode == "advanced":
  perspectives = [performance, security]

FOR each perspective IN perspectives:

  # Load perspective prompt from config (pal.thinkdeep.perspectives.{perspective}.prompt_template)
  # and fill with architecture context from design.md

  Follow CLI Multi-CLI Dispatch Pattern from $CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md with:

  | Parameter | Value |
  |-----------|-------|
  | ROLE | `deepthinker` |
  | PHASE_STEP | `5.4.{perspective}` |
  | MODE_CHECK | `analysis_mode in {complete, advanced}` |
  | GEMINI_PROMPT | Perspective prompt from config with architecture AND requirements context. Focus: Broad architecture exploration, tech stack validation, pattern conflicts for {perspective}. Include design.md content AND acceptance criteria from spec.md/requirements-anchor.md. |
  | CODEX_PROMPT | Perspective prompt from config with architecture AND requirements context. Focus: Import chain analysis, coupling assessment, code-level complexity for {perspective}. Include design.md content AND key constraints from spec.md/requirements-anchor.md. |
  | OPENCODE_PROMPT | Perspective prompt from config with architecture AND requirements context. Focus: User flow impact, accessibility implications, UX pattern evaluation, design system alignment for {perspective}. Include design.md content AND user stories from spec.md/requirements-anchor.md. |
  | FILE_PATHS | `["{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/design.md"]` |
  | REPORT_FILE | `analysis/cli-deepthinker-{perspective}-report.md` |
  | PREFERRED_SINGLE_CLI | `gemini` |
  | POST_WRITE | none (synthesis happens in Step 5.5) |
```

**Note:** All 9 (Complete) or 6 (Advanced) dispatches can be launched simultaneously since each perspective's dispatch is fully independent. The CLI dispatch pattern handles per-perspective retry and circuit breaker logic internally.

## Step 5.5: Synthesize Insights

Read per-perspective CLI reports:
- `{FEATURE_DIR}/analysis/cli-deepthinker-performance-report.md`
- `{FEATURE_DIR}/analysis/cli-deepthinker-maintainability-report.md` (Complete mode only)
- `{FEATURE_DIR}/analysis/cli-deepthinker-security-report.md`

Write `{FEATURE_DIR}/analysis/thinkdeep-insights.md`:
- Per-perspective findings (from CLI reports)
- **Unanimous insights** (all CLIs and/or multiple perspectives agree) → CRITICAL priority
- **Majority insights** (2 of 3 CLIs agree) → HIGH priority
- **Divergent insights** (CLIs or perspectives all disagree) → FLAG for decision
- **Unique insights** (single CLI or single perspective only) → VERIFY against existing findings
- Recommended architecture updates

## Step 5.6: Present Findings [USER]

**USER INTERACTION:** The user should review deep analysis findings.

Set `status: needs-user-input` in your summary with:
- `block_reason`: Summary of findings, asking user to choose:
  A) Accept recommendations and update architecture
  B) Review divergent points one by one
  C) Proceed without changes

On re-dispatch, read `{FEATURE_DIR}/.phase-summaries/phase-5-user-input.md` for the selection.

**Checkpoint: THINKDEEP**
