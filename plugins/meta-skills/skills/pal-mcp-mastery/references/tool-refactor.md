# refactor - Code Transformation

> **Note**: This tool is typically disabled via `DISABLED_TOOLS`. Enable only for systematic refactoring tasks.

## Purpose

Safe, systematic code transformations with validation. Executes refactoring patterns while preserving behavior.

## When to Use

- Extracting methods or classes
- Applying design patterns
- Modernizing legacy code
- Consistent style transformations across files

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Transformation step description |
| `step_number` | integer | Yes | Current step (1-indexed) |
| `total_steps` | integer | Yes | Expected total steps |
| `next_step_required` | boolean | Yes | Whether workflow continues |
| `findings` | string | Yes | Changes made in current step |
| `model` | string | No | Target model |
| `refactor_type` | string | No | extract_method, rename, move, inline |
| `relevant_files` | array | No | Files to refactor (ABSOLUTE paths) |
| `preserve_behavior` | boolean | No | Strict behavior preservation (default: true) |

## Example Usage

```
refactor(
  step="Extract payment validation into separate method",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Identified validation logic at lines 45-78",
  refactor_type="extract_method",
  relevant_files=["/src/payments/processor.py"],
  model="gpt5"
)
```

## Best Practices

1. Run tests before and after each refactor step
2. Use `planner` to plan multi-step refactors first
3. Keep transformations atomic and reversible
4. Always follow with `codereview` and `precommit`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Large refactors in one step | Break into atomic changes |
| Skipping validation | Run tests after each step |
| Refactoring without tests | Add tests first via `testgen` |

## Workflow Integration

For safe refactoring, use this sequence:

```
1. planner → Plan refactor steps
2. testgen → Ensure test coverage
3. refactor → Execute transformations (step by step)
4. codereview → Validate changes
5. precommit → Final safety check
```

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Multiple files | Parallel context for comparison | Refactor one file at a time |
| Step history | Cumulative context growth | Limit to 3-5 steps per session |

---

## See Also

- **planner** - Plan refactoring strategy before execution
- **testgen** - Generate tests before refactoring
- **codereview** - Validate refactored code
- **chat** - Alternative for simple one-off transformations
