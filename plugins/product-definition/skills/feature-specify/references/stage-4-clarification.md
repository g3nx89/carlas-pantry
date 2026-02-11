---
stage: stage-4-clarification
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md (updated)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md (conditional)
---

# Stage 4: Edge Cases & Clarification (Coordinator)

> This stage discovers edge cases via multi-model ThinkDeep, collects user clarifications
> via the clarification protocol, triangulates questions from multiple perspectives,
> then updates the spec. Resolves all `[NEEDS CLARIFICATION]` markers.

## CRITICAL RULES (must follow — failure-prevention)

1. **No question limits**: Ask EVERYTHING needed — no artificial caps
2. **Never re-ask**: Questions from `user_decisions.clarifications` are IMMUTABLE — check before asking
3. **Clarification protocol handles batching**: Max 4 questions per AskUserQuestion call
4. **Edge case severity boost**: 2+ models agree = MEDIUM→HIGH, 3/3 = HIGH→CRITICAL
5. **CRITICAL/HIGH edge cases**: Auto-inject as clarification questions
6. **NEVER interact with users directly**: Dispatch subagent with clarification protocol for all user Q&A
7. **Spec updates additive only**: ONLY add/refine requirements, NEVER remove existing ones

## Step 4.1: MPA-EdgeCases ThinkDeep (Optional)

**Check:** `thinkdeep.integrations.edge_cases.enabled` in config AND PAL_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/thinkdeep-patterns.md` → Integration 2: Edge Cases

Execute parallel ThinkDeep with 3 models:
- pro: security & performance focus (thinking_mode: max)
- gpt5.2: user experience focus (thinking_mode: high)
- x-ai/grok-4: accessibility, i18n, contrarian focus (thinking_mode: high)

**Synthesize** with severity boost:
- 2+ models identify same edge case → boost severity (MEDIUM→HIGH)
- 3/3 models identify → boost severity (HIGH→CRITICAL)

**Auto-inject** CRITICAL and HIGH edge cases as pending clarification questions:
```
FOR EACH edge_case WHERE severity IN [CRITICAL, HIGH]:
    ADD to pending_clarifications:
        question: "How should the system handle: {edge_case.description}?"
        source: "MPA-EdgeCases"
        severity: {edge_case.severity}
```

Write report: `specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md`

**If disabled OR PAL_AVAILABLE = false:** Skip, proceed to Step 4.2.

## Step 4.2: Invoke Clarification Protocol

Dispatch subagent with clarification protocol:

```
## Task: Collect Clarifications

Feature directory: specs/{FEATURE_DIR}
Spec file: specs/{FEATURE_DIR}/spec.md
State file: specs/{FEATURE_DIR}/.specify-state.local.md

## Context
- [NEEDS CLARIFICATION] markers in spec: {MARKERS_COUNT}
- Edge case questions to inject: {INJECTED_COUNT}
- Previously answered clarifications: {PRIOR_CLARIFICATIONS from user_decisions}

## Instructions
Read and execute: @$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/clarification-protocol.md

The protocol will:
1. Identify all [NEEDS CLARIFICATION] markers in spec
2. Add injected edge case questions
3. Generate questions with BA recommendations (first option = Recommended)
4. Batch questions in groups of max 4 via AskUserQuestion
5. Save responses to state immediately after each batch
6. Return status and metrics
```

**Returns:**
- `status`: completed/partial
- `questions_answered`: N
- `markers_resolved`: N
- `remaining_markers`: N

## Step 4.3: MPA-Triangulation ThinkDeep (Optional)

**Check:** `thinkdeep.integrations.triangulation.enabled` in config AND PAL_AVAILABLE

**If enabled:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/thinkdeep-patterns.md` → Integration 3: Triangulation

Execute dual+ model dispatch:
- pro: technical perspective
- gpt5.2: business perspective
- x-ai/grok-4: contrarian perspective

Each generates 2-4 additional questions not covered by BA.

**Semantic deduplication** against existing questions (similarity threshold: 0.85):
- Discard duplicates
- Priority boost on cross-source agreement

**Present unique questions** to user via clarification protocol subagent (re-invoke if new questions found).

Write report: `specs/{FEATURE_DIR}/analysis/mpa-triangulation.md`

**If disabled OR PAL_AVAILABLE = false:** Skip, proceed to Step 4.4.

## Step 4.4: Update Specification

Dispatch BA agent to incorporate all clarification answers:

```
## Task: Update Specification with Clarifications

Spec: @specs/{FEATURE_DIR}/spec.md
Clarification answers: {ALL_ANSWERS_FROM_SUB_SKILL}
Edge case findings: {EDGE_CASE_SUMMARY}
Triangulation findings: {TRIANGULATION_SUMMARY}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-update-spec.md

RULES:
- ONLY add or refine requirements — NEVER remove existing ones
- Remove [NEEDS CLARIFICATION] markers that have been resolved
- Add @ResearchRef annotations where clarifications cite evidence
- Maintain consistent formatting with existing spec sections
```

## Step 4.5: Checkpoint

Update state file:
```yaml
current_stage: 4
stages:
  clarification:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    questions_answered: {N}
    markers_found: {N}
    markers_resolved: {N}
    iteration: {N}
  mpa_edgecases:
    status: {completed|skipped}
    findings_count: {N}
    injected_clarifications: {N}
  mpa_triangulation:
    status: {completed|skipped}
    additional_questions: {N}
    deduplicated: {N}
```

## Summary Contract

```yaml
---
stage: "clarification"
stage_number: 4
status: completed
checkpoint: CLARIFICATION
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/analysis/mpa-edgecases-parallel.md  # if ThinkDeep ran
  - specs/{FEATURE_DIR}/analysis/mpa-triangulation.md  # if triangulation ran
summary: "Clarification complete: {N} questions answered, {M} markers resolved. Edge cases: {E} found. Triangulation: {T} additional questions."
flags:
  questions_answered: {N}
  markers_resolved: {N}
  remaining_markers: {N}
  edgecases_found: {N}
  triangulation_questions: {N}
  iteration: {N}
  next_action: "proceed"
---

## Context for Next Stage
Clarification resolved {N} of {M} markers.
{IF remaining_markers > 0: "Remaining markers: {LIST}"}
Edge case severity distribution: {CRITICAL: N, HIGH: N, MEDIUM: N}
Spec updated with all clarification answers.
```

**Note on iteration:** After this stage, the orchestrator re-dispatches Stage 3 for re-validation. The loop continues until coverage >= 85% or user requests proceed. The `next_action` from this stage is always `"proceed"` — the orchestrator checks Stage 3's `coverage_pct` to decide whether to loop back.

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/spec.md` has been updated (not unchanged from input)
2. Resolved `[NEEDS CLARIFICATION]` markers have been removed from spec
3. Edge case report exists (if ThinkDeep ran)
4. All clarification answers are recorded in state file
5. Summary YAML frontmatter has no placeholder values
6. No previously answered questions were re-asked

## CRITICAL RULES REMINDER

- No question limits — ask EVERYTHING needed
- Never re-ask questions from user_decisions.clarifications
- Clarification protocol handles batching (max 4 per call)
- Edge case severity boost on cross-model agreement
- CRITICAL/HIGH edge cases auto-inject as questions
- Spec updates are additive only — NEVER remove requirements
- NEVER interact with users directly
