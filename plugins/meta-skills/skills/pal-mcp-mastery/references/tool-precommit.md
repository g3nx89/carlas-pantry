# precommit - Git Change Validation

> **Shared parameters**: See `shared-parameters.md` for `step`, `step_number`, `total_steps`, `confidence`, and other common parameters.

## Purpose

Validate changes before committing to prevent regressions, catch incomplete implementations, and ensure code quality gates pass.

**Important:** Tool enforces minimum 3 steps before completion. For external validation, a changeset file may be required.

**Key capability:** Uses models to check for regressions or **deviations from the original plan** - especially powerful when continuing from a codereview session.

## When to Use

- Final validation before `git commit`
- After fixing issues found in codereview
- Integration with CI/CD pre-commit hooks
- Continuing validation from a codereview session

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Validation step description |
| `step_number` | integer | Yes | Current step |
| `total_steps` | integer | Yes | Expected steps (min 3 for external) |
| `next_step_required` | boolean | Yes | True until final step |
| `findings` | string | Yes | Git diff insights, risks, concerns |
| `model` | string | Yes | Validation model |
| `path` | string | No | Repository root (required in step 1) |
| `relevant_files` | array | No | Files to validate (ABSOLUTE paths) |
| `continuation_id` | string | No | Continue from codereview context |
| `confidence` | string | No | Confidence level |
| `compare_to` | string | No | Git ref to diff against |
| `include_staged` | boolean | No | Inspect staged changes (default: true) |
| `include_unstaged` | boolean | No | Inspect unstaged changes (default: true) |
| `precommit_type` | string | No | external (expert model) or internal |
| `focus_on` | string | No | Emphasis areas |
| `hypothesis` | string | No | Current theory |
| `issues_found` | array | No | Issues with severity |
| `files_checked` | array | No | Files examined |
| `relevant_context` | array | No | Methods/functions involved |
| `severity_filter` | string | No | Minimum severity to report |

## Powerful Pattern: codereview → precommit

```
# Session 1: Code review identifies issues
codereview(...) → Claude fixes them

# Session 2: Precommit validates fixes
precommit(
  step="Verify all HIGH severity issues addressed",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Checking fixes for session persistence issue",
  model="pro",
  path="/path/to/repo",
  continuation_id="<from_codereview>",  # KEY: Same thread!
  confidence="exploring"
)
```

The model already knows what was wrong and can verify corrections.

## Example Workflow

```
# Step 1: Initial validation
precommit(
  step="Outline validation strategy for staged changes",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Staged: 3 files in auth module",
  model="pro",
  path="/Users/dev/project",
  include_staged=True,
  include_unstaged=False,
  confidence="exploring"
)

# Step 2: Deep analysis
precommit(
  step="Analyze impact of auth changes",
  step_number=2,
  total_steps=3,
  next_step_required=True,
  findings="Changes correctly invalidate sessions on password change",
  model="pro",
  confidence="medium",
  continuation_id="<from_step_1>"
)

# Step 3: Final validation
precommit(
  step="Final regression check",
  step_number=3,
  total_steps=3,
  next_step_required=False,
  findings="All checks pass. Safe to commit.",
  model="pro",
  confidence="high",
  continuation_id="<from_step_2>"
)
```

## Best Practices

1. **Always use continuation_id from codereview** to leverage existing analysis
2. **Use at least 3 steps** for external validation
3. **Check both staged and unstaged** unless specifically validating staged only
4. **Run after fixing issues** to verify corrections

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Skipping continuation_id | Pass ID from preceding codereview |
| Single step for complex changes | Use 3+ steps for external validation |
| Not specifying path in step 1 | Always provide repository root |
| Using precommit without prior codereview | Review first, then validate |

---

## See Also

- **codereview** - Always run before precommit
- **debug** - If precommit finds bugs, use debug to investigate
