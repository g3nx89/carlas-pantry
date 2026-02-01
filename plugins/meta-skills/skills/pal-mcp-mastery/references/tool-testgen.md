# testgen - Test Generation

> **Note**: This tool is typically disabled via `DISABLED_TOOLS`. Enable only when generating test suites.

## Purpose

Automated test generation for critical paths and edge cases. Creates unit tests, integration tests, and test fixtures based on code analysis.

## When to Use

- Adding test coverage to untested code
- After refactoring to ensure behavior preservation
- Creating regression tests for bug fixes
- Building test suites for new features

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | Description of what tests to generate |
| `model` | string | No | Target model |
| `relevant_files` | array | No | Source files to test (ABSOLUTE paths) |
| `test_framework` | string | No | Target framework (jest, pytest, etc.) |
| `coverage_focus` | string | No | critical_paths, edge_cases, all |

## Example Usage

```
testgen(
  prompt="Create unit tests for the payment processing module",
  model="gpt5",
  relevant_files=["/src/payments/processor.py"],
  test_framework="pytest",
  coverage_focus="critical_paths"
)
```

## Best Practices

1. Generate tests for one module at a time
2. Review generated tests before committing
3. Use `coverage_focus="edge_cases"` for bug fixes
4. Follow with manual review for test quality

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Generating tests for entire codebase | Focus on specific modules |
| Trusting generated tests blindly | Always review and run tests |
| Ignoring test framework conventions | Specify `test_framework` explicitly |

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Multiple source files | Linear context growth | Generate tests per-module |
| Complex test logic | Can produce verbose output | Use `coverage_focus` to limit scope |

---

## See Also

- **codereview** - Validate test quality after generation
- **chat** - For test strategy discussion before generation
- **planner** - For planning comprehensive test coverage
