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
  - "spec.md"          # requirements context: acceptance criteria, user stories — needed for "Problem Understanding" scoring
  - "plan.md"
  - "design.md"
artifacts_written:
  - "analysis/validation-report.md"
  - "analysis/cli-planreview-report.md"  # conditional: CLI dispatch enabled
  - "analysis/cli-consensus-report.md"  # conditional: CLI dispatch enabled
agents:
  - "product-planning:debate-judge"
mcp_tools:
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

<!-- Mode Applicability -->
| Step | Rapid | Standard | Advanced | Complete | Notes |
|------|-------|----------|----------|----------|-------|
| 6.1  | ✓     | ✓        | ✓        | ✓        | — |
| 6.2  | —     | —        | ✓        | ✓        | CLI dispatch |
| 6.3  | —     | —        | —        | ✓        | `(s6_multi_judge_debate)`, Complete only |
| 6.4  | —     | —        | ✓        | ✓        | CLI Consensus; skipped if 6.3 runs |
| 6.5  | —     | —        | ✓        | ✓        | Score divergence check |
| 6.6  | ✓     | ✓        | ✓        | ✓        | — |
| 6.7  | ✓     | ✓        | ✓        | ✓        | User interaction for YELLOW/RED |
| 6.8  | ✓     | ✓        | —        | —        | Fallback when CLI unavailable |

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
> 9. **CLI dispatch: ONLY use `dispatch-via-ntm.sh`**: For ALL multi-CLI consensus and validation dispatches, use `$CLAUDE_PLUGIN_ROOT/scripts/dispatch-via-ntm.sh` via Bash(). NEVER use the `ask` command or CCB async dispatch — the async queue returns stale cross-phase results.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Step 6.1: Load Requirements Context

```
# Prefer requirements-anchor.md (consolidates spec + user clarifications from Phase 3)
# Fall back to raw spec.md if anchor not available or empty

IF file_exists({FEATURE_DIR}/requirements-anchor.md) AND not_empty({FEATURE_DIR}/requirements-anchor.md):
  requirements_file = "{FEATURE_DIR}/requirements-anchor.md"
  LOG: "Requirements context: using requirements-anchor.md (enriched)"
ELSE:
  requirements_file = "{FEATURE_DIR}/spec.md"
  LOG: "Requirements context: using spec.md (raw)"

# Read requirements content for use in CLI scoring prompts (Step 6.6)
requirements_content = READ(requirements_file)
```

## Step 6.2: CLI Plan Review [IF cli_context_isolation]

**Purpose:** Pre-validation adversarial review via CLI multi-CLI dispatch before CLI Consensus Scoring or Multi-Judge Debate.

Follow the **CLI Multi-CLI Dispatch Pattern** from `$CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md` with these parameters:

| Parameter | Value |
|-----------|-------|
| ROLE | `planreviewer` |
| PHASE_STEP | `6.2` |
| MODE_CHECK | `analysis_mode in {complete, advanced}` |
| GEMINI_PROMPT | `Strategic plan review for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Plan: {FEATURE_DIR}/plan.md. Design: {FEATURE_DIR}/design.md. Focus: Strategic risks, scope assessment, Red Team/Blue Team analysis. Cross-check plan against acceptance criteria in spec.md.` |
| CODEX_PROMPT | `Technical feasibility review for feature: {FEATURE_NAME}. Spec: {FEATURE_DIR}/spec.md. Plan: {FEATURE_DIR}/plan.md. Design: {FEATURE_DIR}/design.md. Focus: Code structure support, dependency compatibility, import path resolution. Verify plan covers all technical constraints from spec.md.` |
| FILE_PATHS | `["{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"]` |
| REPORT_FILE | `analysis/cli-planreview-report.md` |
| PREFERRED_SINGLE_CLI | `gemini` |
| POST_WRITE | `APPEND CLI review summary to consensus_context for Step 6.4` |

## Step 6.3: Multi-Judge Debate Validation [IF s6_multi_judge_debate]

**Complete mode only. Feature flag: `s6_multi_judge_debate`**

Execute multi-round debate validation:

1. **Round 1: Independent Analysis** — 3 judges evaluate independently
   - Neutral (internal agent)
   - Advocate (Gemini CLI)
   - Challenger (Codex CLI)
2. **Consensus Check** — If all scores within 0.5, synthesize and proceed
3. **Round 2: Rebuttal** — Each judge reads others' positions, writes rebuttals, may revise
4. **Consensus Check** — If converged, synthesize and proceed
5. **Round 3: Final Positions** — Force verdict via majority rule

Reference: `$CLAUDE_PLUGIN_ROOT/skills/plan/references/debate-protocol.md`

If S6 debate produces a verdict, skip Step 6.4 (standard CLI Consensus).

## Step 6.4: CLI Consensus Scoring (Standard Flow)

**When S6 debate is disabled or unavailable:** Execute consensus scoring via CLI dispatch.

```
IF mode in {Complete, Advanced} AND state.cli.available:

  # Dispatch ALL CLIs with stance-differentiated scoring prompts
  Follow CLI Multi-CLI Dispatch Pattern from $CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md with:

  | Parameter | Value |
  |-----------|-------|
  | ROLE | `consensus` |
  | PHASE_STEP | `6.4` |
  | MODE_CHECK | `analysis_mode in {complete, advanced}` |
  | GEMINI_PROMPT | see below (advocate stance + scoring rubric) |
  | CODEX_PROMPT | see below (challenger stance + scoring rubric) |
  | FILE_PATHS | `["{FEATURE_DIR}/spec.md", "{FEATURE_DIR}/plan.md", "{FEATURE_DIR}/design.md"]` |
  | REPORT_FILE | `analysis/cli-consensus-report.md` |
  | PREFERRED_SINGLE_CLI | `gemini` |
  | POST_WRITE | none |

  # Requirements content loaded from Step 6.1 (requirements_file → requirements_content)

  GEMINI_PROMPT:
    "STANCE: ADVOCATE — Highlight strengths, give benefit of doubt on ambiguous items.

    Score this implementation plan for feature: {FEATURE_NAME}

    ORIGINAL REQUIREMENTS:
    {requirements_content}

    PLAN: {plan_summary}
    ARCHITECTURE: {selected_architecture}

    Score dimensions (max 20 total):
    1. Problem Understanding (20%) — score 1-4. Cross-check against the ORIGINAL REQUIREMENTS above.
    2. Architecture Quality (25%) — score 1-5
    3. Risk Mitigation (20%) — score 1-4
    4. Implementation Clarity (20%) — score 1-4
    5. Feasibility (15%) — score 1-3

    Return per-dimension scores with evidence."

  CODEX_PROMPT:
    "STANCE: CHALLENGER — Actively find gaps, risks, and overlooked failure modes. Score conservatively.

    Score this implementation plan for feature: {FEATURE_NAME}

    ORIGINAL REQUIREMENTS:
    {requirements_content}

    PLAN: {plan_summary}
    ARCHITECTURE: {selected_architecture}

    Score dimensions (max 20 total):
    1. Problem Understanding (20%) — score 1-4. Verify plan addresses ALL acceptance criteria from requirements.
    2. Architecture Quality (25%) — score 1-5
    3. Risk Mitigation (20%) — score 1-4
    4. Implementation Clarity (20%) — score 1-4
    5. Feasibility (15%) — score 1-3

    Return per-dimension scores with evidence."

  # Extract and average scores from all CLI outputs
  gemini_scores = PARSE dimensional scores from gemini output
  codex_scores = PARSE dimensional scores from codex output
  final_scores = AVERAGE(all available CLI scores) per dimension
  total_score = SUM(final_scores)
```

### Team-Based Follow-Up (when Agent Teams enabled)

IF AGENT_TEAMS_ENABLED AND feature_flags.agent_teams_debate.enabled:
    Run perspective-critic team debate per $CLAUDE_PLUGIN_ROOT/skills/plan/references/cli-dispatch-pattern.md Team-Based Follow-Up Protocol
    Variables: ROLE=consensus, FEATURE_DIR, CLI_OUTPUT_A (codex), CLI_OUTPUT_B (gemini)
    Merge debate findings into synthesis output

## Step 6.5: Score Divergence Check

**Purpose:** Detect scoring divergence between CLIs and reconcile if needed.

```
# Check score divergence between CLIs
score_delta = abs(gemini_total - codex_total)

IF score_delta < 1.0:  # CLIs agree very closely
  LOG: "Low divergence ({score_delta}) — scores are consistent"
  # Accept averaged scores

ELIF score_delta > 4.0:  # CLIs strongly disagree
  LOG: "HIGH divergence ({score_delta}) — re-dispatching with challenge prompt"
  # Re-dispatch the lower-scoring CLI with explicit challenge:
  # "The other evaluator scored this plan {other_score}/20.
  #  Your score was {this_score}/20. Review the {score_delta}-point gap.
  #  Are you being too lenient or too harsh? Revise if justified."
  # Use updated score for final average

ELSE:
  LOG: "Moderate divergence ({score_delta}) — using averaged scores"
```

## Step 6.6: Score Calculation

| Dimension | Weight | Score | Max |
|-----------|--------|-------|-----|
| Problem Understanding | 20% | 1-4 | 4 |
| Architecture Quality | 25% | 1-5 | 5 |
| Risk Mitigation | 20% | 1-4 | 4 |
| Implementation Clarity | 20% | 1-4 | 4 |
| Feasibility | 15% | 1-3 | 3 |
| **Total** | **100%** | | **20** |

## Step 6.6b: Review Board (when enabled + YELLOW/RED) [CONDITIONAL]

> Dispatched only when `state.review_board_enabled == true` AND preliminary verdict is YELLOW or RED.
> Protocol: `@$CLAUDE_PLUGIN_ROOT/skills/plan/references/review-board-protocol.md`

```
# Calculate preliminary verdict from Step 6.6 scores
preliminary_total = SUM(final_scores)

IF preliminary_total >= 16:
  preliminary_verdict = "GREEN"
ELIF preliminary_total >= 12:
  preliminary_verdict = "YELLOW"
ELSE:
  preliminary_verdict = "RED"

IF state.review_board_enabled AND preliminary_verdict IN ["YELLOW", "RED"] AND AGENT_TEAMS_AVAILABLE:
  LOG: "Preliminary verdict is {preliminary_verdict} — dispatching review board"

  # Execute review board protocol (3-critic adversarial debate)
  # See review-board-protocol.md for full Steps RB.1-RB.7
  Execute Review Board per @$CLAUDE_PLUGIN_ROOT/skills/plan/references/review-board-protocol.md
  Variables: FEATURE_DIR, FEATURE_NAME, FEATURE_ID

  # Review board may downgrade verdict (never upgrade):
  # - 1+ CRITICAL findings → RED (regardless of original)
  # - 1+ HIGH findings (no CRITICAL) → keep YELLOW
  # - 0 CRITICAL + 0 HIGH → keep original verdict

  IF review_board_synthesis has CRITICAL findings:
    final_verdict = "RED"
    LOG: "Review board found CRITICAL issues — verdict downgraded to RED"
  ELSE:
    final_verdict = preliminary_verdict

ELSE:
  final_verdict = preliminary_verdict
  IF state.review_board_enabled AND preliminary_verdict == "GREEN":
    LOG: "Preliminary verdict GREEN — review board skipped (no value in reviewing passing plan)"
```

## Step 6.7: Determine Status [USER]

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

## Step 6.8: Internal Validation (Fallback)

IF CLI dispatch not available:

```
mcp__sequential-thinking__sequentialthinking(T14: Completeness Check)
mcp__sequential-thinking__sequentialthinking(T15: Consistency Validation)
mcp__sequential-thinking__sequentialthinking(T16: Feasibility Assessment)
```

**Checkpoint: VALIDATION**
