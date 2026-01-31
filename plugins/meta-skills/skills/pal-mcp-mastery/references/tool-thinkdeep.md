# thinkdeep - Extended Reasoning

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
| `confidence` | string | No | Current confidence level |
| `hypothesis` | string | No | Current theory based on work |
| `relevant_files` | array | No | Files for context (ABSOLUTE paths) |
| `relevant_context` | array | No | Methods/functions involved |
| `files_checked` | array | No | Files examined during step |
| `issues_found` | array | No | Issues with severity levels |

## Thinking Mode Selection

| Mode | Token Cost | Use Case |
|------|-----------|----------|
| `none` | Lowest | Quick sanity checks |
| `low` | Low | Simple queries with some reasoning |
| `medium` | Medium | Standard analysis (default) |
| `high` | High | Complex problems requiring depth |
| `max` | Highest | Most complex scenarios, edge cases |

**Natural language triggers**: "think" < "think hard" < "think harder" < "ultrathink"

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

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Starting with `thinking_mode=max` | Start medium, escalate if needed |
| Jumping to `confidence=high` immediately | Progress through levels with evidence |
| Setting `total_steps=1` for complex problems | Use 3-6 steps for thorough analysis |
| Forgetting `next_step_required=false` on final step | Always set false to complete |
