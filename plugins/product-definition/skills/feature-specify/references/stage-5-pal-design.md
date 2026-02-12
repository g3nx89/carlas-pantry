---
stage: stage-5-pal-design
artifacts_written:
  - specs/{FEATURE_DIR}/design-brief.md
  - specs/{FEATURE_DIR}/design-supplement.md
---

# Stage 5: PAL Validation & Design (Coordinator)

> This stage runs multi-model PAL Consensus validation of the spec, then generates
> MANDATORY design artifacts (design-brief.md + design-supplement.md).
> PAL retry is coordinator-internal (max 2 attempts).

## CRITICAL RULES (must follow — failure-prevention)

1. **PAL Consensus minimum 2 models**: If < 2 substantive responses, signal `needs-user-input` (NEVER self-assess)
2. **No model substitution**: Continue with remaining models, never swap
3. **design-brief.md is MANDATORY**: NEVER skip — even if PAL fails
4. **design-supplement.md is MANDATORY**: NEVER skip — even if PAL fails
5. **Verify BOTH files exist** before writing summary
6. **PAL retry max 2**: If REJECTED after 2 retries, signal `needs-user-input`
7. **NEVER interact with users directly**: signal `needs-user-input` in summary
8. **PAL content inline**: NEVER pass local file paths to external models — embed spec content in the prompt

## Step 5.0b: Prepare Inline Content for PAL

**Purpose:** External models cannot access local files. Spec content MUST be embedded inline.

```
READ specs/{FEATURE_DIR}/spec.md
COUNT words in spec content

IF word_count <= pal_consensus.content_delivery.inline_word_limit (default: 4000):
    SET pal_content = full spec content
ELSE:
    GENERATE structured summary:
        - Problem statement (full)
        - User stories with acceptance criteria (full)
        - NFRs (full)
        - Scope boundaries (full)
        - Technical constraints / Information architecture (summarized)
        - Appendices / detailed context (omitted, note: "Detailed appendices omitted for brevity")
    SET pal_content = structured summary
```

**CRITICAL:** NEVER pass file paths (e.g., `@specs/...`, `specs/{FEATURE_DIR}/spec.md`) to PAL consensus. External models cannot read local files.

## Step 5.1: PAL Consensus Evaluation (Optional)

**Check:** `feature_flags.enable_pal_validation` in config AND PAL_AVAILABLE

**If enabled:**

Call `mcp__pal__consensus` with 3 models:

```json
[
  {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "Provide objective assessment. Focus on factual gaps and measurable criteria."},
  {"model": "gpt-5.2", "stance": "for", "stance_prompt": "Advocate for the specification's strengths. Focus on what works."},
  {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "Find every weakness. Challenge completeness. Be skeptical of claimed coverage."}
]
```

**In the `step` parameter**, include:
1. The evaluation criteria from `@$CLAUDE_PLUGIN_ROOT/templates/prompts/pal-spec-eval.md`
2. The `{pal_content}` prepared in Step 5.0b (inline spec content, NOT file paths)

Evaluate 5 dimensions (4 points each, 20 total):
1. Business value clarity
2. Requirements completeness
3. Scope boundaries
4. Stakeholder coverage
5. Technology agnosticism

**If disabled OR PAL_AVAILABLE = false:** Skip to Step 5.5 (design artifacts).

## Step 5.1b: Validate PAL Responses

**Purpose:** Detect non-substantive responses from models that couldn't process the spec.

```
FOR each model_response IN pal_responses:
    CHECK for non-substantive patterns:
        - "cannot access"
        - "file not found"
        - "unable to read"
        - "no file provided"
        - "I don't have access"
        - response length < 50 words
        - all 5 dimension scores are identical (e.g., all 2/4)

    IF any pattern matches:
        MARK response as non_substantive
        LOG in model_failures: {model, stage: 5, operation: "pal_consensus", error: "non-substantive response", action_taken: "excluded"}

COUNT substantive_responses

IF substantive_responses < 2:
    DO NOT fall back to self-assessment
    PROCEED to Step 5.4 (Handle Insufficient Models)

IF substantive_responses >= 2:
    SCORE using only substantive responses
    PROCEED to Step 5.2
```

**CRITICAL:** Non-substantive responses MUST be excluded from scoring. NEVER self-assess when models fail to engage with the spec content.

## Step 5.2: Process PAL Result

| Score | Decision | Action |
|-------|----------|--------|
| >= 16/20 | APPROVED | Proceed to design artifacts |
| 12-15/20 | CONDITIONAL | Proceed with warnings noted |
| < 12/20 | REJECTED | Retry loop (coordinator-internal) |

## Step 5.3: Handle REJECTED (Coordinator-Internal Loop)

**Max 2 retries** (from `limits.pal_rejection_retries_max`):

```
FOR retry IN 1..2:
    INVOKE BA with prompts/ba-address-gaps.md:
        - Pass dissenting views from PAL
        - BA addresses identified weaknesses
        - BA updates spec.md

    RE-RUN PAL Consensus (Step 5.1)

    IF new_score >= 12/20:
        BREAK (proceed)

IF still REJECTED after max retries:
    Signal needs-user-input:
```

```yaml
flags:
  pause_type: "interactive"
  block_reason: "PAL validation REJECTED after 2 retries (score: {SCORE}/20)"
  question_context:
    question: "Specification scored {SCORE}/20 after 2 revision attempts. How would you like to proceed?"
    header: "PAL Gate"
    options:
      - label: "Re-run clarifications (Recommended)"
        description: "Gather more information to address weak areas"
      - label: "Force proceed"
        description: "Accept current spec quality and generate design artifacts"
      - label: "Abort"
        description: "Stop workflow and review spec manually"
  next_action_map:
    "Re-run clarifications (Recommended)": "loop_clarify"
    "Force proceed": "proceed"
    "Abort": "abort"
```

## Step 5.4: Handle Insufficient Models

If < 2 models respond to PAL Consensus:

Signal `needs-user-input`:
```yaml
flags:
  pause_type: "interactive"
  block_reason: "PAL Consensus failed: only {N} model(s) available (minimum 2 required)"
  question_context:
    question: "PAL Consensus requires minimum 2 models but only {N} responded. How to proceed?"
    header: "PAL Models"
    options:
      - label: "Retry (Recommended)"
        description: "Attempt PAL Consensus again"
      - label: "Skip PAL validation"
        description: "Proceed without multi-model validation"
      - label: "Abort"
        description: "Stop workflow"
```

## Step 5.5: Launch design-brief-generator

**MANDATORY — always runs regardless of PAL outcome.**

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate Design Brief

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md

Spec: @specs/{FEATURE_DIR}/spec.md
{IF figma_context.md exists: Figma: @specs/{FEATURE_DIR}/figma_context.md}

Output: specs/{FEATURE_DIR}/design-brief.md

Use Sequential Thinking (if available, 6 thoughts):
1. Extract all screens from user stories
2. Identify states per screen (default, loading, error, empty, success)
3. Map user journeys across screens
4. Define navigation flows
5. Document interaction patterns
6. Self-critique completeness
```

## Step 5.6: Launch gap-analyzer (Design Supplement)

**MANDATORY — always runs regardless of PAL outcome.**

Dispatch via `Task(subagent_type="general-purpose")`:

```
## Task: Generate Design Supplement

Read the agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md

Spec: @specs/{FEATURE_DIR}/spec.md
Design Brief: @specs/{FEATURE_DIR}/design-brief.md
{IF figma_context.md exists: Figma: @specs/{FEATURE_DIR}/figma_context.md}

Output: specs/{FEATURE_DIR}/design-supplement.md

Use Sequential Thinking (if available, 6 thoughts):
1. Extract all requirements needing visual/interaction coverage
2. Map requirements to Figma screens (or mark all NOT_COVERED if no Figma)
3. Specify missing screens with full layout, content, and interactions
4. Specify missing states as deltas from base screens
5. Specify missing reusable components with variants
6. Generate alignment summary — every requirement mapped to source
```

## Step 5.7: Verify Outputs

```bash
test -f "specs/{FEATURE_DIR}/design-brief.md" || echo "MISSING: design-brief.md"
test -f "specs/{FEATURE_DIR}/design-supplement.md" || echo "MISSING: design-supplement.md"
```

**If either file missing:** Re-run the missing agent step (5.5 or 5.6).
**If still missing after retry:** Set `status: failed` — mandatory outputs MUST exist.

## Step 5.8: Checkpoint

Update state file:
```yaml
current_stage: 5
stages:
  pal_gate:
    status: {completed|skipped}
    pal_score: {N|null}
    pal_decision: "{APPROVED|CONDITIONAL|REJECTED|skipped}"
    iterations: {N}
    models_responded: {N}        # Total models that returned a response
    models_substantive: {N}      # Models with substantive responses (used for scoring)
  design_supplement:
    status: completed
    figma_available: {true|false}
    outputs:
      - design-brief.md
      - design-supplement.md
```

## Summary Contract

> **Size limits:** `summary` max 500 chars, Context body max 1000 chars. Details in artifacts, not summaries.

```yaml
---
stage: "pal-design"
stage_number: 5
status: completed | needs-user-input | failed
checkpoint: PAL_GATE
artifacts_written:
  - specs/{FEATURE_DIR}/design-brief.md
  - specs/{FEATURE_DIR}/design-supplement.md
summary: "PAL: {DECISION} ({SCORE}/20). Design artifacts generated. Brief: {SCREENS} screens. Feedback: {GAPS} gaps identified."
flags:
  pal_score: {N|null}
  pal_decision: "{APPROVED|CONDITIONAL|REJECTED|skipped}"
  pal_iterations: {N}
  design_brief_exists: true
  design_supplement_exists: true
  block_reason: null | "{reason}"
  pause_type: null | "interactive"
  question_context: {see above if needs-user-input}
  next_action_map: {see above if needs-user-input}
---

## Context for Next Stage
PAL validation: {DECISION} ({SCORE}/20).
Design brief: {SCREENS} screens documented.
Design feedback: {GAPS} requirement-screen gaps found.
{IF PAL dissenting views: "Key dissent: {SUMMARY}"}
```

## Self-Verification (MANDATORY before writing summary)

BEFORE writing the summary file, verify:
1. `specs/{FEATURE_DIR}/design-brief.md` exists and has content
2. `specs/{FEATURE_DIR}/design-supplement.md` exists and has content
3. PAL score is populated (or marked as skipped)
4. State file updated with stage 5 checkpoint data
5. Summary YAML frontmatter has no placeholder values

## CRITICAL RULES REMINDER

- PAL Consensus minimum 2 substantive responses — signal needs-user-input if < 2 (NEVER self-assess)
- PAL content inline — NEVER pass file paths to external models
- No model substitution
- design-brief.md is MANDATORY — NEVER skip
- design-supplement.md is MANDATORY — NEVER skip
- Verify BOTH files exist before writing summary
- PAL retry max 2, then signal needs-user-input
- NEVER interact with users directly
