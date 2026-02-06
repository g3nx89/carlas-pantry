# consensus - Multi-Model Debate

## Purpose

Gather perspectives from multiple AI models on a decision, run structured debates, and synthesize recommendations through consensus-building.

## When to Use

- Architecture decisions with trade-offs
- Technology selection
- Risk assessment
- Any decision benefiting from multiple expert perspectives
- When you need to reduce single-model bias
- **Breaking AI sycophancy** - prevents models from simply agreeing with bad ideas

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Consensus prompt or notes |
| `step_number` | integer | Yes | Current step (1 = your analysis, 2+ = model responses) |
| `total_steps` | integer | Yes | Number of models + 1 (synthesis) |
| `next_step_required` | boolean | Yes | True until ready to synthesize |
| `findings` | string | Yes | Step 1: your analysis; Steps 2+: model response summary |
| `models` | array | No | Models to consult, e.g., `[{model: "gpt-5", stance: "for"}]` |
| `continuation_id` | string | No | Continue existing debate |
| `relevant_files` | array | No | Supporting files (ABSOLUTE paths) |
| `images` | array | No | Visual context |

## Model Entry Format

```yaml
models:
  - model: "gpt-5"
    stance: "for"        # for, against, or neutral
    stance_prompt: "..."  # Optional custom stance instruction
  - model: "pro"
    stance: "against"
  - model: "o3"
    stance: "neutral"
```

**Important:** Each `(model, stance)` combination must be unique. You CAN use the same model with different stances (e.g., gpt-5 for, gpt-5 against) but NOT duplicate pairs.

## Stance Steering

Rather than neutral responses, models argue from assigned positions:
- `for` - emphasizes benefits, opportunities
- `against` - emphasizes risks, challenges
- `neutral` - balanced evaluation
- Custom stances for domain-specific perspectives

## Example Usage

```
# Step 1: Your independent analysis
consensus(
  step="Evaluate: Should we use microservices or monolith for a 3-person team?",
  step_number=1,
  total_steps=4,  # 3 models + synthesis
  next_step_required=True,
  findings="My analysis: Monolith simpler for small team, but...",
  models=[
    {model: "gpt-5", stance: "for"},
    {model: "pro", stance: "against"},
    {model: "o3", stance: "neutral"}
  ]
)

# Steps 2-4: Process each model response
consensus(
  step="Notes on GPT-5 response (not shared with others)",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="GPT-5 argues for monolith citing team size...",
  current_model_index=1,
  continuation_id="<from_step_1>"
)

# Final step: Synthesis
consensus(
  step="Final synthesis of all perspectives",
  step_number=4,
  total_steps=4,
  next_step_required=False,
  findings="Consensus: Monolith recommended with 2-1 vote",
  continuation_id="<from_previous>"
)
```

## Consensus Outcomes

- **Unanimous (3-0)**: Strong signal for clear winner
- **Majority (2-1)**: Reasonable confidence with dissent noted
- **Tie**: Genuinely contested, requires human judgment

## Best Practices

1. **Use at least 2-3 models** with different training biases
2. **Gemini + OpenAI models** often surface complementary considerations
3. **Use stance steering** to ensure genuine debate, not echo chamber
4. **Follow with `challenge`** if all models agree too easily
5. **Sequential processing** - consensus gathers all perspectives before synthesis to avoid MCP reliability issues

## Multi-Agent Debate Hall Pattern

A powerful community pattern assigns three models with complementary roles:

| Role | Model | Focus |
|------|-------|-------|
| **The Architect** | o3 | Logical purity, structural integrity |
| **The Hacker** | Gemini Pro | Security exploits, edge cases |
| **The User Advocate** | Sonnet | Maintainability, developer experience |

This structured conflict consistently produces higher-quality decisions than any single model.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using 5+ models for simple decisions | 2-3 models usually sufficient |
| All models with same stance | Use diverse stances (for/against/neutral) |
| Consensus on obvious questions | Use `chat` for clear-cut decisions |
| Skipping synthesis step | Always include final synthesis |

---

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Number of models | Each model adds full context | Use 2-3 models, not 5+ |
| `relevant_files` | Duplicated for each model | Keep file list minimal |
| Synthesis step | Aggregates all model responses | Essential, don't skip |

**Cost formula**: `base_context × num_models + synthesis_overhead`

**Tip**: For simple questions, use `chat` instead. Reserve consensus for genuinely contested decisions.

---

## See Also

- **challenge** - Use after consensus to check for groupthink
- **chat** - For simple questions not needing multi-model debate
- **thinkdeep** - For single-model deep analysis (different from consensus)
