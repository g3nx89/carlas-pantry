# thinkdeep - Extended Reasoning

> **Shared parameters**: See `shared-parameters.md` for `step`, `step_number`, `total_steps`, `confidence`, `thinking_mode`, and other common parameters.

## Purpose

Multi-stage investigation for deep analysis of complex problems, edge cases, and alternative perspectives. Uses systematic workflow with expert validation at completion.

## When to Use

- Complex architectural decisions
- Security analysis
- Performance investigations
- Edge case exploration
- Any problem requiring systematic hypothesis testing

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Current investigation step description |
| `step_number` | integer | Yes | Current step (1-indexed) |
| `total_steps` | integer | Yes | Expected total steps |
| `next_step_required` | boolean | Yes | Whether workflow continues |
| `findings` | string | Yes | Discoveries and evidence |
| `model` | string | No | Target reasoning model |
| `thinking_mode` | string | No | Reasoning depth (see below) |
| `continuation_id` | string | No | Continue from previous analysis |
| `confidence` | string | No | Current confidence level (CRITICAL: "certain" prevents external validation) |
| `use_assistant_model` | boolean | No | Default True. If True and confidence < certain, external model validates |
| `hypothesis` | string | No | Current theory based on work |
| `relevant_files` | array | No | Files for context (ABSOLUTE paths) |
| `relevant_context` | array | No | Methods/functions involved |
| `files_checked` | array | No | Files examined during step |
| `issues_found` | array | No | Issues with severity levels |
| `problem_context` | string | No | Extended description of the problem |
| `focus_areas` | array | No | Specific aspects to investigate (e.g., "security", "performance") |

## Thinking Mode Selection

| Mode | Token Budget | Economic Impact | Use Case |
|------|-------------|-----------------|----------|
| `minimal` | 128 tokens | 1x cost | Formatting, style checks, basic syntax |
| `low` | 2,048 tokens | 16x cost | Explaining basic concepts, light reasoning |
| `medium` | 8,192 tokens | 64x cost | Default development tasks, multi-file analysis |
| `high` | 16,384 tokens | 128x cost | Complex logic, security audits, architecture |
| `max` | 32,768 tokens | 256x cost | Exhaustive strategic analysis, critical debugging |

**Natural language triggers**: "think" < "think hard" < "think harder" < "ultrathink"

**Note:** For Gemini models, thinkdeep automatically overrides to `high` or `max` mode, significantly impacting latency and cost.

## Example Workflow

```
# Step 1: Initial exploration
thinkdeep(
  step="Analyze potential race conditions in payment processing",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Initial scan of checkout.py reveals async patterns",
  thinking_mode="medium",
  confidence="exploring",
  relevant_files=["/src/checkout.py"]
)

# Step 2: Focus investigation
thinkdeep(
  step="Investigate mutex implementation",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="Lock acquisition happens after DB call starts",
  hypothesis="Lock timing issue causing race condition",
  confidence="low",
  continuation_id="<from_step_1>"
)

# Step 3: Validate hypothesis
thinkdeep(
  step="Evaluate alternative locking strategies",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  findings="Two viable approaches: early lock or optimistic locking",
  thinking_mode="high",
  confidence="medium",
  continuation_id="<from_step_2>"
)

# Step 4: Final synthesis
thinkdeep(
  step="Assess edge cases under high concurrency",
  step_number=4,
  total_steps=4,
  next_step_required=False,
  findings="Early lock approach handles all edge cases",
  confidence="high",
  continuation_id="<from_step_3>"
)
```

## Response Statuses

- `pause_for_thinkdeep`: Intermediate step, more analysis needed
- `complete_pending_validation`: Final step, expert validation included

## Best Practices

1. **Start with `thinking_mode=medium`** - escalate only when needed
2. **Progress confidence naturally** through levels based on findings
3. **Use continuation_id** to maintain context across steps
4. **Adjust total_steps** if complexity changes during investigation
5. **Use `max` sparingly** - high token and time cost

## Parameter Recipes

| Parameter | Standard Analysis | Deep Strategic Analysis |
|-----------|------------------|------------------------|
| `model` | auto | pro or o3 |
| `thinking_mode` | medium | high or max |
| `total_steps` | 3-4 | 5-8 |
| `confidence` | exploring → high | exploring → certain |
| `use_assistant_model` | true | **true** (critical for validation) |

**Key insight**: For architecture decisions or security analysis, use `thinking_mode=high` and `use_assistant_model=true` to get expert validation.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Starting with `thinking_mode=max` | Start medium, escalate if needed |
| Jumping to `confidence=high` immediately | Progress through levels with evidence |
| Setting `total_steps=1` for complex problems | Use 3-6 steps for thorough analysis |
| Forgetting `next_step_required=false` on final step | Always set false to complete |

---

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| `thinking_mode` | **256x cost** from minimal→max | Start at `medium`, escalate only if needed |
| `total_steps` | Linear scaling | Use 3-4 steps default, not 8+ |
| `relevant_files` | ~200 tokens/file | Pass only essential files, use paths not contents |
| Multi-step continuation | Cumulative | Break into separate sessions if hitting limits |

**Tip**: If hitting context limits, use `clink` to delegate heavy analysis to Gemini (1M tokens).

---

## See Also

- **chat** - For simpler questions not requiring deep reasoning
- **debug** - For bug investigation with hypothesis testing
- **codereview** - For code quality analysis (different focus than thinkdeep)
