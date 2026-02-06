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
artifacts_written: []
agents: []
mcp_tools:
  - "mcp__sequential-thinking__sequentialthinking"
feature_flags: []
additional_references: []
---

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

## Step 3.2: Generate Questions

Identify gaps across categories:
- Scope boundaries
- Edge cases
- Error handling
- Integration details
- Design preferences

## Step 3.3: Collect User Responses

**USER INTERACTION:** This phase requires user input for ALL generated questions.

- In **coordinator mode**: Set `status: needs-user-input` in your summary with the complete questions list in `block_reason`. The orchestrator will collect responses and write them to `{FEATURE_DIR}/.phase-summaries/phase-3-user-input.md`. On re-dispatch, read that file to get the answers.
- In **inline mode** (Standard/Rapid): The orchestrator uses `AskUserQuestion` directly.

For "whatever you think is best" responses, use BA recommendation and mark as ASSUMED.

## Step 3.4: Update State

Save all decisions to `user_decisions` (IMMUTABLE).

**Checkpoint: CLARIFICATION**
