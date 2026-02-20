---
phase: "6"
phase_name: "Plan Validation"
checkpoint: "VALIDATION"
delegation: "coordinator"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-4-summary.md"
  - ".phase-summaries/phase-5-summary.md"
artifacts_read:
  - "plan.md"
  - "design.md"
artifacts_written:
  - "analysis/validation-report.md"
  - "analysis/cli-planreview-report.md"  # conditional: CLI dispatch enabled
agents:
  - "product-planning:debate-judge"
mcp_tools:
  - "mcp__pal__consensus"
  - "mcp__pal__challenge"
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "s6_multi_judge_debate"
  - "cli_context_isolation"
  - "cli_custom_roles"
  - "deep_reasoning_escalation"  # orchestrator may offer escalation on RED after 2 retries
additional_references:
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/debate-protocol.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/validation-rubric.md"
  - "$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md"
---

# Phase 6: Plan Validation

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-6-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 6.0a: CLI Plan Review

**Purpose:** Pre-validation adversarial review via CLI dual-CLI dispatch before PAL Consensus or Multi-Judge Debate.

Follow the **CLI Dual-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `planreviewer` |
| PHASE_STEP | `6.0a` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Strategic plan review for feature: {FEATURE_NAME}. Plan: {FEATURE_DIR}/plan.md. Design: {FEATURE_DIR}/design.md. Focus: Strategic risks, scope assessment, Red Team/Blue Team analysis.` |
| CODEX_PROMPT | `Technical feasibility review for feature: {FEATURE_NAME}. Plan: {FEATURE_DIR}/plan.md. Design: {FEATURE_DIR}/design.md. Focus: Code structure support, dependency compatibility, import path resolution.` |
| FILE_PATHS | `["{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"]` |
| REPORT_FILE | `analysis/cli-planreview-report.md` |
| PREFERRED_SINGLE_CLI | `gemini` |
| POST_WRITE | `APPEND CLI review summary to consensus_context for Step 6.1` |

## Step 6.0: Multi-Judge Debate Validation (S6)

**Complete mode only. Feature flag: `s6_multi_judge_debate`**

Execute multi-round debate validation:

1. **Round 1: Independent Analysis** — 3 judges evaluate independently
   - Neutral (gemini-3-pro-preview)
   - Advocate (gpt-5.2)
   - Challenger (grok-4)
2. **Consensus Check** — If all scores within 0.5, synthesize and proceed
3. **Round 2: Rebuttal** — Each judge reads others' positions, writes rebuttals, may revise
4. **Consensus Check** — If converged, synthesize and proceed
5. **Round 3: Final Positions** — Force verdict via majority rule

Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/debate-protocol.md`

If S6 debate produces a verdict, skip Step 6.1 (standard PAL Consensus).

## Step 6.1: PAL Consensus (Standard Flow)

**When S6 is disabled or unavailable:** Execute PAL Consensus with models array.

IF mode == Complete AND Consensus available:

```
# Step 1: Initialize consensus workflow with models array
response = mcp__pal__consensus({
  step: """
    PLAN VALIDATION:

    Evaluate implementation plan for feature: {FEATURE_NAME}

    PLAN SUMMARY:
    {plan_summary}

    ARCHITECTURE:
    {selected_architecture}

    Score dimensions (max 20 total):
    1. Problem Understanding (20%) — score 1-4
    2. Architecture Quality (25%) — score 1-5
    3. Risk Mitigation (20%) — score 1-4
    4. Implementation Clarity (20%) — score 1-4
    5. Feasibility (15%) — score 1-3
  """,
  step_number: 1,
  total_steps: 4,
  next_step_required: true,
  findings: "Initial plan analysis complete.",
  models: [
    {model: "gemini-3-pro-preview", stance: "neutral", stance_prompt: "Evaluate objectively"},
    {model: "gpt-5.2", stance: "for", stance_prompt: "Advocate for strengths"},
    {model: "openrouter/x-ai/grok-4", stance: "against", stance_prompt: "Challenge weaknesses"}
  ],
  relevant_files: ["{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"]
})

# Continue workflow with continuation_id until complete
WHILE response.next_step_required:
  current_step = response.step_number + 1
  is_final = (current_step >= 4)  # Final step = synthesis

  response = mcp__pal__consensus({
    step: IF is_final THEN "Final synthesis of all perspectives" ELSE "Processing model response",
    step_number: current_step,
    total_steps: 4,
    next_step_required: NOT is_final,
    findings: "Model evaluation: {summary}",
    continuation_id: response.continuation_id
  })
```

## Step 6.1b: Groupthink Detection with Challenge

**Purpose:** Detect potential groupthink when all models agree too closely.

```
# Extract scores from each model's response
scores = [gemini_score, gpt_score, grok_score]
score_range = max(scores) - min(scores)

IF score_range < 0.5:  # All models agree within 0.5 points
  LOG: "GROUPTHINK WARNING: Score variance < 0.5 ({min_score}-{max_score})"

  # Use PAL Challenge to force critical examination
  challenge_response = mcp__pal__challenge({
    prompt: """
      All models scored this plan similarly ({min_score}-{max_score}/20).

      Is this genuinely well-designed, or are we missing something?

      EXAMINE CRITICALLY:
      1. Are there hidden risks not surfaced by any model?
      2. Are there alternative approaches none of the models considered?
      3. Are the scoring criteria too lenient for this problem domain?

      PLAN SUMMARY:
      {plan_summary}

      CONSENSUS RESPONSE:
      {consensus_synthesis}
    """
  })

  IF challenge_response.identifies_issues:
    # Append challenge findings to validation report
    APPEND to validation_report:
      "### Groupthink Challenge Results
       {challenge_response.analysis}"

    # Note for orchestrator: user should review challenge findings
    FLAG challenge_findings for user review

ELSE:
  LOG: "Score variance acceptable ({score_range}) - no groupthink detected"
```

## Step 6.2: Score Calculation

| Dimension | Weight | Score | Max |
|-----------|--------|-------|-----|
| Problem Understanding | 20% | 1-4 | 4 |
| Architecture Quality | 25% | 1-5 | 5 |
| Risk Mitigation | 20% | 1-4 | 4 |
| Implementation Clarity | 20% | 1-4 | 4 |
| Feasibility | 15% | 1-3 | 3 |
| **Total** | **100%** | | **20** |

## Step 6.3: Determine Status

| Score | Status | Action |
|-------|--------|--------|
| >=16 | GREEN | Proceed |
| >=12 AND <16 | YELLOW | Proceed with documented risks |
| <12 | RED | Revise (→ Phase 4) |

**USER INTERACTION for YELLOW/RED:**

If YELLOW: Set `status: needs-user-input` with `block_reason` explaining the risks and asking user to confirm proceeding or return to Phase 4.

If RED: Set `status: needs-user-input` with `block_reason` explaining what failed and that the orchestrator should loop back to Phase 4 with specific improvements.

> **Deep Reasoning Escalation Note:** If RED verdict is set and this is the 2nd retry,
> the orchestrator (not this coordinator) may offer deep reasoning escalation to the user
> before looping back to Phase 4. When `architecture_wall_breaker` is enabled, the
> orchestrator generates a specialized CTCO prompt for an external deep reasoning model.
> The coordinator does not need to handle this. See `deep-reasoning-dispatch-pattern.md`.

## Step 6.4: Internal Validation (Fallback)

IF Consensus not available:

```
mcp__sequential-thinking__sequentialthinking(T14: Completeness Check)
mcp__sequential-thinking__sequentialthinking(T15: Consistency Validation)
mcp__sequential-thinking__sequentialthinking(T16: Feasibility Assessment)
```

**Checkpoint: VALIDATION**
