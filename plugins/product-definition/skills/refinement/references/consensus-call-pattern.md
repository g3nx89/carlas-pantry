# PAL Consensus Call Pattern (Shared)

> Parameterized consensus workflow used by Stage 4 (response validation) and Stage 5 (PRD readiness).
> Each stage supplies its own `{STEP_CONTENT}`, `{FINDINGS}`, `{RELEVANT_FILES}`, and `{STANCE_PROMPTS}`.

## Model Resolution (BEFORE calling Consensus)

```
IF grok-4 is available (check config -> pal.thinkdeep.models where optional=true):
  SET total_steps = 4  (3 models + 1 synthesis)
  SET models = [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "{NEUTRAL_STANCE_PROMPT}"},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "{FOR_STANCE_PROMPT}"},
    {"model": "x-ai/grok-4", "stance": "against", "stance_prompt": "{AGAINST_STANCE_PROMPT}"}
  ]

ELSE (grok-4 unavailable):
  SET total_steps = 3  (2 models + 1 synthesis)
  SET models = [
    {"model": "gemini-3-pro-preview", "stance": "neutral", "stance_prompt": "{NEUTRAL_STANCE_PROMPT}"},
    {"model": "gpt-5.2", "stance": "for", "stance_prompt": "{FOR_STANCE_PROMPT}"}
  ]
```

## Multi-Step Consensus Execution

```
# Step 1: YOUR independent analysis (sets up the debate)
mcp__pal__consensus(
  step: "{STEP_CONTENT}",
  step_number: 1,
  total_steps: {total_steps},    # resolved above
  next_step_required: true,
  findings: "{FINDINGS}",
  models: {models},              # resolved above
  relevant_files: [{RELEVANT_FILES}]
)
# -> Save continuation_id from response

# Step 2: Process first model's response
mcp__pal__consensus(
  step: "Notes on gemini-3-pro-preview (neutral) response",
  step_number: 2,
  total_steps: {total_steps},
  next_step_required: true,
  findings: "Gemini (neutral) finds: [summary of model response]",
  continuation_id: "<from_step_1>"
)

# Step 3 (if 3 models): Process second model's response
# (if 2 models: this step becomes the synthesis — set next_step_required: false)
mcp__pal__consensus(
  step: "Notes on gpt-5.2 (for) response",
  step_number: 3,
  total_steps: {total_steps},
  next_step_required: {total_steps > 3},
  findings: "GPT-5.2 (for) argues: [summary of model response]",
  continuation_id: "<from_step_2>"
)

# Step 4 (only if 3 models): Final synthesis
IF total_steps == 4:
  mcp__pal__consensus(
    step: "Synthesize all model perspectives into final assessment",
    step_number: 4,
    total_steps: 4,
    next_step_required: false,
    findings: "Consensus assessment: [summary of convergence/divergence across all models]",
    continuation_id: "<from_step_3>"
  )
```

## Unanimity Check (after synthesis)

```
IF all models agree on assessment (unanimous recommendation)
  AND no model flagged concerns or weak areas:
    LOG unanimity_warning in output artifact
    ADD note: "Unanimity warning: all models converged without dissent.
     Consider whether issues may have been overlooked due to sycophantic agreement."
    (Non-blocking — proceed normally)
```

## Error Handling

If any model fails during the consensus chain:
- Display PAL Model Failure notification (see `error-handling.md`)
- If < 2 models remaining: ABORT (consensus requires minimum 2)
- If >= 2 models remaining: ask user to Continue or Abort
- Log failure to state file `model_failures` array
