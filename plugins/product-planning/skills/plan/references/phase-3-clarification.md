---
phase: "3"
phase_name: "Clarifying Questions"
checkpoint: "CLARIFICATION"
delegation: "conditional"
modes: [complete, advanced, standard, rapid]
prior_summaries:
  - ".phase-summaries/phase-2-summary.md"
artifacts_read:
  - "spec.md"
  - "research.md"
artifacts_written:
  - "requirements-anchor.md"  # consolidated requirements: spec + user clarifications
agents: []
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags:
  - "s12_specify_gate"
additional_references: []
---

<!-- Mode Applicability -->
| Step | Rapid | Standard | Advanced | Complete | Notes |
|------|-------|----------|----------|----------|-------|
| 3.1  | —     | —        | ✓        | ✓        | Requires ST MCP |
| 3.2  | ✓     | ✓        | ✓        | ✓        | `(s12_specify_gate)` |
| 3.3  | ✓     | ✓        | ✓        | ✓        | — |
| 3.4  | ✓     | ✓        | ✓        | ✓        | Inline for Rapid/Standard, coordinator for Advanced/Complete |
| 3.5  | ✓     | ✓        | ✓        | ✓        | `(s12_specify_gate)`, iterates if score < threshold |
| 3.6  | ✓     | ✓        | ✓        | ✓        | — |
| 3.7  | ✓     | ✓        | ✓        | ✓        | — |

# Phase 3: Clarifying Questions

> **COORDINATOR INSTRUCTIONS**
> You are a phase coordinator dispatched by the lean orchestrator.
> 1. Read this file completely for your phase instructions.
> 2. Read the prior phase summaries listed in `prior_summaries` frontmatter from `{FEATURE_DIR}/.phase-summaries/`.
> 3. Read the artifacts listed in `artifacts_read` frontmatter from `{FEATURE_DIR}/`.
> 4. Execute ALL steps below for the current `analysis_mode`.
> 5. Write your output artifacts to `{FEATURE_DIR}/`.
> 6. Write your phase summary to `{FEATURE_DIR}/.phase-summaries/phase-3-summary.md` using the template at `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`.
> 7. You MUST NOT interact with the user directly. If user input is needed, set `status: needs-user-input` in your summary with `block_reason` explaining what is needed and what options are available.
> 8. If a sub-agent (Task) fails, retry once. If it fails again, continue with partial results and set `flags.degraded: true` in your summary.

## Decision Protocol
When `a6_context_protocol` is enabled (check feature flags):
1. **RESPECT** all prior key decisions — do not contradict HIGH-confidence decisions without explicit justification.
2. **CHECK** open questions — if your analysis resolves any, include the resolution in your `key_decisions`.
3. **CONTRIBUTE** your findings as `key_decisions`, `open_questions`, and `risks_identified` in your phase summary YAML.

## Delegation Decision

- **Standard/Rapid modes:** Orchestrator executes this phase inline (small logic footprint, overhead of coordinator dispatch not justified)
- **Complete/Advanced modes:** Delegate to coordinator (ST T1-T3 adds significant context)

## Step 3.1: Sequential Thinking (Complete/Advanced Mode)

IF mode in {Complete, Advanced} AND ST available:

```
mcp__sequential-thinking__sequentialthinking(T1: Feature Understanding)
mcp__sequential-thinking__sequentialthinking(T2: Scope Boundaries)
mcp__sequential-thinking__sequentialthinking(T3: Decomposition Strategy)
```

## Step 3.2: Specify Gate — Initial Scoring [IF s12_specify_gate]

```
IF feature_flags.s12_specify_gate.enabled:

  1. SCORE the spec across 5 dimensions (0 = missing, 1 = partial, 2 = clear):

     | Dimension | 0 (Missing) | 1 (Partial) | 2 (Clear) |
     |-----------|-------------|-------------|-----------|
     | **Value** | No user/business value stated | Vague value | Explicit value + success metric |
     | **Scope** | No boundaries defined | Some boundaries | Clear in/out of scope |
     | **Acceptance** | No acceptance criteria | Generic criteria | Measurable, testable ACs |
     | **Constraints** | No constraints/deps | Some mentioned | Full list with priorities |
     | **Risk** | No risks identified | Surface risks only | Risks with mitigations |

  2. COMPUTE specify_score = sum of all 5 dimensions (0-10)

  3. IF specify_score >= config.specify_gate.pass_threshold (default 7):
       LOG: "Specify gate PASSED ({specify_score}/10)"
       SKIP targeted question generation (use standard Step 3.3)
     ELSE:
       LOG: "Specify gate score: {specify_score}/10 — generating targeted questions"
       PROCEED to targeted question generation in Step 3.3

  4. STORE specify_dimensions = { value, scope, acceptance, constraints, risk }
```

## Step 3.3: Generate Questions

IF specify gate is enabled AND score < threshold:
  Generate TARGETED questions per low-scoring dimension:
  - **Value (score 0-1):** "What specific user/business problem does this solve?" "How will success be measured?"
  - **Scope (score 0-1):** "What is explicitly out of scope?" "What adjacent features should NOT be affected?"
  - **Acceptance (score 0-1):** "What are the testable acceptance criteria?" "How will the Product Owner verify completion?"
  - **Constraints (score 0-1):** "What technical/timeline constraints exist?" "What dependencies must be resolved first?"
  - **Risk (score 0-1):** "What could go wrong?" "What are the biggest unknowns?"

ELSE (gate disabled or score >= threshold):
  Identify gaps across standard categories:
  - Scope boundaries
  - Edge cases
  - Error handling
  - Integration details
  - Design preferences

## Step 3.4: Collect User Responses [USER]

**USER INTERACTION:** This phase requires user input for ALL generated questions.

- In **coordinator mode**: Set `status: needs-user-input` in your summary with the complete questions list in `block_reason`. The orchestrator will collect responses and write them to `{FEATURE_DIR}/.phase-summaries/phase-3-user-input.md`. On re-dispatch, read that file to get the answers.
- In **inline mode** (Standard/Rapid): The orchestrator uses `AskUserQuestion` directly.

For "whatever you think is best" responses, use BA recommendation and mark as ASSUMED.

## Step 3.5: Specify Gate — Iteration Loop [IF s12_specify_gate]

```
IF feature_flags.s12_specify_gate.enabled AND specify_score < config.specify_gate.pass_threshold:

  iteration = 1
  max_iterations = config.circuit_breaker.specify_gate.max_iterations  # 3

  WHILE specify_score < config.specify_gate.pass_threshold AND iteration <= max_iterations:

    1. RE-SCORE spec + user responses across same 5 dimensions
    2. DISPLAY progress:

       ┌──────────────────────────────────────────┐
       │ SPECIFY GATE — Iteration {iteration}/{max_iterations}  │
       │ Score: {specify_score}/10 (threshold: {threshold})     │
       │ Value: {v}/2  Scope: {s}/2  Acceptance: {a}/2          │
       │ Constraints: {c}/2  Risk: {r}/2                        │
       └──────────────────────────────────────────┘

    3. IF specify_score >= threshold:
         LOG: "Specify gate PASSED after {iteration} iteration(s)"
         BREAK

    4. IDENTIFY remaining low dimensions (score 0-1)
    5. GENERATE follow-up questions for low dimensions ONLY
    6. SET status: needs-user-input with targeted follow-up questions
    7. ON re-dispatch: READ user-input, increment iteration

  IF iteration > max_iterations AND specify_score < config.specify_gate.min_acceptable (default 6):
    SET flags.low_specify_score = true
    LOG: "Specify gate exhausted iterations — score {specify_score}/10, proceeding with advisory flag"
```

## Step 3.6: Update State

Save all decisions to `user_decisions` (IMMUTABLE).

Include in phase summary YAML:
- `specify_score: {score}` (0-10, null if gate disabled)
- `specify_dimensions: { value, scope, acceptance, constraints, risk }` (null if gate disabled)
- `flags.low_specify_score: true` (if applicable)

## Step 3.7: Generate Requirements Anchor

**Purpose:** Produce a consolidated, structured requirements document that merges the original spec with user clarifications. This document becomes the single source of truth for requirements context in all downstream phases (5, 6, 6b, 7, 8, 9).

```
READ {FEATURE_DIR}/spec.md

# Collect user clarifications (from Step 3.4 responses)
# In coordinator mode: already parsed from phase-3-user-input.md
# In inline mode: already collected via AskUserQuestion

WRITE {FEATURE_DIR}/requirements-anchor.md with:

  ---
  generated_by: "phase-3"
  source_spec: "spec.md"
  includes_clarifications: true
  specify_score: {specify_score or null}
  ---

  # Requirements Anchor — {FEATURE_NAME}

  > Auto-generated from spec.md + Phase 3 user clarifications.
  > This document is the consolidated requirements reference for all downstream phases.

  ## Feature Summary
  {2-3 sentence summary of what the feature does and why, from spec.md}

  ## Acceptance Criteria
  {Numbered list of ALL acceptance criteria from spec.md — preserve original wording}
  {Add any criteria clarified or added through user Q&A, marked with "(clarified)"}

  ## User Stories
  {List user stories from spec.md, if present}
  {If none in spec, synthesize from acceptance criteria: "As a [role], I want [action], so that [benefit]"}

  ## Key Constraints
  {Technical constraints, dependencies, non-functional requirements from spec.md}
  {Include user-clarified constraints, marked with "(clarified)"}

  ## User Decisions
  {Key decisions from Phase 3 Q&A that affect requirements interpretation}
  {Format: "Q: {question} → A: {answer}"}

  ## Scope Boundaries
  {What is in scope vs out of scope, from spec.md + clarifications}

BUDGET: Keep under config.requirements_context.anchor_max_tokens (default: 800 tokens)
If spec is very large, prioritize: acceptance criteria > constraints > user stories > scope
```

**Checkpoint: CLARIFICATION**
