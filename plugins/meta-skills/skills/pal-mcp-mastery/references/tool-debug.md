# debug - Root Cause Analysis

> **Shared parameters**: See `shared-parameters.md` for `step`, `step_number`, `total_steps`, `confidence`, `thinking_mode`, and other common parameters.

## Purpose

Systematic debugging with hypothesis tracking, confidence levels, and evidence-based investigation for finding root causes.

## When to Use

- Runtime errors
- Race conditions
- Performance regressions
- Memory leaks
- Integration problems
- Any bug requiring systematic investigation

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Investigation step description |
| `step_number` | integer | Yes | Current step (starts at 1) |
| `total_steps` | integer | Yes | Estimated steps needed |
| `next_step_required` | boolean | Yes | True to continue, False when done |
| `findings` | string | Yes | Clues, evidence, disproven theories |
| `model` | string | Yes | Debugging model |
| `hypothesis` | string | No | Current root cause theory |
| `confidence` | string | No | Confidence in hypothesis |
| `relevant_files` | array | No | Related code files (ABSOLUTE paths) |
| `files_checked` | array | No | All files examined |
| `issues_found` | array | No | Issues with severity |
| `relevant_context` | array | No | Methods/functions involved |
| `images` | array | No | Screenshots/visuals |
| `thinking_mode` | string | No | Reasoning depth |

## Confidence Levels

| Level | When to Use | Next Action |
|-------|-------------|-------------|
| `exploring` | Initial investigation | Gather more data |
| `low` | Some findings, many unknowns | Narrow focus |
| `medium` | Reasonable understanding | Validate assumptions |
| `high` | Strong hypothesis | Seek confirmation |
| `very_high` | Very strong evidence | Prepare fix |
| `almost_certain` | Nearly confirmed | Implement fix |
| `certain` | 100% confirmed | No external validation needed |

**Warning**: Only use `certain` when absolutely sure. It prevents external model validation.

## Hypothesis Tracking Workflow

```
# Step 1: Initial investigation
debug(
  step="Investigate intermittent 500 errors on /api/checkout",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Error occurs under high load, 5% of requests",
  model="o3",
  confidence="exploring",
  relevant_files=["/src/checkout.py", "/src/inventory.py"],
  thinking_mode="medium"
)

# Step 2: Test hypothesis 1
debug(
  step="Test hypothesis: Database connection timeout",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="DB connection pool healthy, ruled out",
  hypothesis="Database timeout",
  confidence="low",  # Ruled out this theory
  continuation_id="<from_step_1>"
)

# Step 3: Test hypothesis 2
debug(
  step="Test hypothesis: Race condition in inventory lock",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  findings="Lock acquired but not released on exception path",
  hypothesis="Lock not released on exception",
  confidence="high",
  thinking_mode="high",
  continuation_id="<from_step_2>"
)

# Step 4: Confirm and fix
debug(
  step="Confirm root cause and propose fix",
  step_number=4,
  total_steps=4,
  next_step_required=False,
  findings="Confirmed: missing finally block for lock release",
  hypothesis="Lock not released on exception - add finally block",
  confidence="certain",
  continuation_id="<from_step_3>"
)
```

## Parameter Recipes

| Parameter | Standard Value | Deep Investigation Value |
|-----------|---------------|-------------------------|
| `model` | auto | pro or o3 |
| `thinking_mode` | medium | high or max |
| `step_number` | 1 | (Auto-increments per turn) |
| `total_steps` | 3 | 5-8 (for complex bugs) |
| `confidence` | exploring | certain (at completion) |
| `use_assistant_model` | false | **true** (for maximum reliability) |

**Key insight**: Set `use_assistant_model=true` for deep investigations - this triggers the expert analysis phase that validates your findings with a secondary model.

## Vision-Guided Debugging

For UI/UX issues, pass screenshots directly to vision-capable models:

```
debug(
  step="Identify CSS layout discrepancy between design and render",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Screenshot shows header overlapping content",
  model="pro",  # Vision-capable
  images=["/screenshots/broken-layout.png", "/designs/intended-layout.png"],
  thinking_mode="high"
)
```

Models like Gemini can identify the delta between intended design and rendered output, suggesting specific CSS overrides.

## Best Practices

1. **Use `thinking_mode=max`** for complex debugging - worth the cost
2. **Track hypotheses explicitly** - document what you've tested and ruled out
3. **Progress confidence naturally** based on evidence
4. **"No bug found" is valid** if evidence supports it
5. **Use 5-8 steps** for deep debugging sessions
6. **Set `use_assistant_model=true`** for expert validation on complex bugs

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Starting with `confidence=high` | Start at `exploring`, earn confidence |
| Not tracking ruled-out hypotheses | Document what you tested and why it's not the cause |
| Using `certain` prematurely | Only use when 100% confirmed with evidence |
| Single-step complex bugs | Use multiple steps for systematic investigation |
| Low thinking_mode for subtle bugs | Use `high` or `max` for complex issues |

---

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| `thinking_mode` | High modes consume 128-256x more tokens | Use `medium` for initial investigation |
| `total_steps` | 5-8 steps for complex bugs | Summarize findings if exceeding 8 steps |
| `files_checked` accumulation | Grows with each step | Focus on relevant files only |
| `use_assistant_model=true` | Adds expert validation pass | Worth the cost for critical bugs |

**Tip**: For complex bugs, use `clink` with Gemini to investigate large codebases without context overflow.

---

## See Also

- **thinkdeep** - For architectural analysis without bug focus
- **codereview** - For code quality review (use after debug fixes)
- **precommit** - For validating fixes before commit
