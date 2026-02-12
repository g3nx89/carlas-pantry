---
stage: stage-2-spec-draft
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md (conditional)
  - specs/{FEATURE_DIR}/analysis/mpa-challenge.md (conditional)
---

# Stage 2: Spec Draft & Gates (Coordinator)

> This stage creates the specification draft, challenges problem framing with ThinkDeep, and validates through incremental quality gates.

## CRITICAL RULES (must follow — failure-prevention)

1. **BA recommendation**: first option MUST be "(Recommended)" with rationale
2. **No limits**: on user stories, acceptance criteria, or NFRs — capture ALL requirements
3. **ThinkDeep MUST complete before gates**: challenge insights inform evaluation
4. **Gate evaluation**: GREEN = proceed silently, YELLOW/RED = signal `needs-user-input`
5. **If gates require BA revision**: re-invoke BA then re-run gates (coordinator-internal loop)
6. **NEVER interact with users directly**: signal `needs-user-input` in summary for orchestrator

## Step 2.1: Launch BA Agent

Dispatch BA agent via `Task(subagent_type="general-purpose")`:

```
## Task: Create Feature Specification

{RESUME_CONTEXT}

Perform business analysis and requirements gathering for:
{USER_INPUT}

## Figma Context
{IF FIGMA_CONTEXT_FILE exists: Include content}
{ELSE: "No Figma designs available - proceed without design context"}

## Variables
- FEATURE_NAME: {value}
- FEATURE_DIR: specs/{FEATURE_DIR}
- SPEC_FILE: specs/{FEATURE_DIR}/spec.md

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-spec-draft.md

Write specification to {SPEC_FILE} following template structure.
IF figma context provided: Correlate designs with requirements, add @FigmaRef annotations.
```

Agent uses Sequential Thinking (if available) for 8 phases: problem framing → JTBD → requirements → context → stakeholders → specification → story splitting → self-critique.

## Step 2.2: Parse BA Response

Extract from agent output:
- `status`: success/partial/error
- `self_critique_score`: N/20
- `user_stories_count`: N
- `problem_statement_quality`: assessment
- `true_need_confidence`: low/medium/high

## Step 2.3: MPA-Challenge ThinkDeep

**Check:** `thinkdeep.integrations.challenge.enabled` in config

**If enabled AND PAL_AVAILABLE:**

Load execution pattern from: `@$CLAUDE_PLUGIN_ROOT/skills/feature-specify/references/thinkdeep-patterns.md` → Integration 1: Challenge

Execute parallel ThinkDeep with 3 models:
- gpt5.2: root cause analysis focus
- pro: alternative interpretations focus
- x-ai/grok-4: assumption validation focus

**Synthesize** findings using haiku agent (union_with_dedup strategy).

**Determine risk level:**
- GREEN: No critical findings, assumptions hold
- YELLOW: Some assumptions challenged, minor risks
- RED: Critical assumptions invalidated, major risks

**If RED:**
Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "MPA-Challenge found critical issues with problem framing"
  question_context:
    question: "ThinkDeep analysis identified critical issues with the problem framing. How would you like to proceed?"
    header: "Challenge"
    options:
      - label: "Revise problem framing (Recommended)"
        description: "Re-invoke BA with challenge findings to strengthen the spec"
      - label: "Acknowledge and proceed"
        description: "Proceed with noted risks documented"
      - label: "Reject findings"
        description: "Proceed without changes"
  next_action_map:
    "Revise problem framing (Recommended)": "revise_ba"
    "Acknowledge and proceed": "proceed"
    "Reject findings": "proceed"
```

**If user chose "Revise":** Re-invoke BA with challenge findings, then re-run MPA-Challenge.

Write report: `specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md`

**If disabled OR PAL_AVAILABLE = false:** Skip, proceed to Step 2.4.

## Step 2.4: Gate 1 — Problem Quality

**Check:** `feature_flags.enable_incremental_gates` in config

**If enabled:**

Auto-evaluate 4 criteria:
1. Problem statement is specific (not generic)
2. Target persona is clearly identified
3. Impact/pain point is measurable or observable
4. Root cause is articulated (not just symptoms)

Score: Each criterion = 1 point (max 4)

**Thresholds:**
- 4 = GREEN → proceed silently
- 3 = YELLOW → signal `needs-user-input` with gate feedback
- <= 2 = RED → signal `needs-user-input` with gate feedback

**If YELLOW/RED:**
Signal `needs-user-input` with question:
```
"Problem statement scored {SCORE}/4. {DETAILS}. How would you like to proceed?"
Options: "Needs refinement" | "Proceed anyway"
```

**If user wants refinement:** Re-invoke BA with gate feedback (coordinator-internal loop).

## Step 2.5: Gate 2 — True Need

**If incremental gates enabled:**

Auto-evaluate 4 criteria:
1. True need differs from stated request (root cause found)
2. Stakeholder motivations are documented
3. Success criteria are defined
4. Business value is articulated

Same GREEN/YELLOW/RED logic as Gate 1.

## Step 2.6: Checkpoint

Update state file:
```yaml
current_stage: 2
stage_status: "completed"
input_document_paths:
  - "{path to original user input file, if file-based}"
  - "{path to research reports, if any}"
  - "{path to any other input documents}"
stages:
  spec_draft:
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    self_critique_score: {N}
    user_stories_count: {N}
  mpa_challenge:
    status: {completed|skipped}
    risk_level: {GREEN|YELLOW|RED|null}
    findings_count: {N}
  gate_1_problem:
    status: {completed|skipped}
    score: {N}/4
  gate_2_true_need:
    status: {completed|skipped}
    score: {N}/4
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "spec-draft-gates"
stage_number: 2
status: completed | needs-user-input
checkpoint: SPEC_DRAFT
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md
  - specs/{FEATURE_DIR}/analysis/mpa-challenge-parallel.md  # if ThinkDeep ran
summary: "Spec draft created with {N} user stories. Self-critique: {S}/20. Challenge risk: {LEVEL}. Gate 1: {S}/4. Gate 2: {S}/4."
flags:
  self_critique_score: {N}
  user_stories_count: {N}
  challenge_risk_level: "{GREEN|YELLOW|RED|skipped}"
  gate_1_score: {N}
  gate_2_score: {N}
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
---

## Context for Next Stage
Spec draft at specs/{FEATURE_DIR}/spec.md with {N} user stories.
{Challenge findings summary if available.}
{Gate results summary.}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/spec.md` exists and has content (not just template)
2. If ThinkDeep ran: analysis report exists
3. Gate scores are populated (not placeholder values)
4. State file updated with stage 2 checkpoint data
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- BA recommendation: first option = "(Recommended)"
- No limits on user stories, ACs, or NFRs
- ThinkDeep completes before gates
- Gates: GREEN proceed, YELLOW/RED signal needs-user-input
- NEVER interact with users directly
