# codereview - Systematic Code Analysis

> **Shared parameters**: See `shared-parameters.md` for `step`, `step_number`, `total_steps`, `confidence`, and other common parameters.

## Purpose

Professional code review with multi-pass analysis, severity classification, confidence tracking, and actionable recommendations.

## When to Use

- Before merging PRs
- After major refactors
- Security audits
- Onboarding to unfamiliar codebases
- Quality gates in CI/CD

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Review narrative and findings |
| `step_number` | integer | Yes | Current review pass |
| `total_steps` | integer | Yes | Expected passes |
| `next_step_required` | boolean | Yes | Whether review continues |
| `findings` | string | Yes | Quality, security, performance, architecture notes |
| `model` | string | Yes | Review model |
| `relevant_files` | array | No | Code files/directories (ABSOLUTE paths) |
| `confidence` | string | No | Confidence in findings |
| `files_checked` | array | No | All files examined |
| `issues_found` | array | No | Issues with severity |
| `review_type` | string | No | full, security, performance, quick |
| `review_validation_type` | string | No | external (default, 2 steps) or internal (1 step only) |
| `use_assistant_model` | boolean | No | Default True. Enables external model validation |
| `severity_filter` | string | No | Minimum severity to report |
| `focus_on` | string | No | Areas to emphasize |
| `standards` | string | No | Coding standards to enforce |
| `hypothesis` | string | No | Current theory |
| `relevant_context` | array | No | Methods/functions involved |

## Severity Levels

| Level | Icon | Description | Action Required |
|-------|------|-------------|-----------------|
| **CRITICAL** | 🔴 | Security flaws, data corruption, crashes | Block merge |
| **HIGH** | 🟠 | Logic errors, major performance bottlenecks | Must fix before merge |
| **MEDIUM** | 🟡 | Code smells, maintainability issues | Should fix |
| **LOW** | 🟢 | Documentation, style, formatting | Consider fixing |

## Multi-Pass Workflow

```
# Pass 1: Initial scan
codereview(
  step="Initial security and quality scan of auth module",
  step_number=1,
  total_steps=4,
  next_step_required=True,
  findings="Found 2 potential issues in session handling",
  model="auto",
  relevant_files=["/src/auth/"],
  confidence="exploring",
  review_type="full"
)

# Pass 2: Deep analysis
codereview(
  step="Deep analysis of identified concerns",
  step_number=2,
  total_steps=4,
  next_step_required=True,
  findings="Session token not invalidated on password change",
  model="pro",
  confidence="medium",
  issues_found=[{severity: "HIGH", description: "Session persistence after password change"}],
  continuation_id="<from_pass_1>"
)

# Pass 3: Secondary opinion
codereview(
  step="Architectural and logical consistency review",
  step_number=3,
  total_steps=4,
  next_step_required=True,
  findings="O3 confirms session issue, found additional edge case",
  model="o3",
  confidence="high",
  continuation_id="<from_pass_2>"
)

# Pass 4: Synthesis
codereview(
  step="Final synthesis and prioritized recommendations",
  step_number=4,
  total_steps=4,
  next_step_required=False,
  findings="1 HIGH, 2 MEDIUM issues. Recommend fixing HIGH before merge.",
  confidence="high",
  continuation_id="<from_pass_3>"
)
```

## Review Types

| Type | Focus | Use When |
|------|-------|----------|
| `full` | All aspects | Comprehensive pre-merge review |
| `security` | Vulnerabilities, auth, injection | Security-sensitive changes |
| `performance` | Speed, memory, efficiency | Performance-critical code |
| `quick` | Major issues only | Fast sanity check |

## Best Practices

1. **Use multi-model review** for security-sensitive code
2. **Progress through passes** - don't rush to conclusions
3. **Always end with `precommit`** for final validation
4. **Use continuation_id** to maintain context between passes
5. **Different models catch different issues** - use variety

## Two-Phase Methodology

Like the debug tool, codereview uses a two-phase approach:

1. **Investigation Phase**: Primary agent examines code, traces dependencies, gathers findings across multiple steps
2. **Expert Analysis Phase**: If confidence < "certain", automatically triggers assistant model for deep-dive analysis

**Tip:** Set `use_assistant_model=false` for quick style checks where external validation isn't needed.

## codereview vs analyze

| Tool | Purpose | Output |
|------|---------|--------|
| `codereview` | Find bugs, security flaws, quality issues | **Prescriptive** - specific fixes |
| `analyze` | Understand architecture, patterns | **Explanatory** - how it works |

Don't run both on the same file in the same turn - they have overlapping logic.

## Parameter Recipes

| Parameter | Quick Review | Security Audit |
|-----------|-------------|----------------|
| `model` | flash | pro or o3 |
| `review_type` | quick | security |
| `total_steps` | 2 | 4-6 |
| `severity_filter` | critical | all |
| `use_assistant_model` | false | **true** |

**Key insight**: For security-sensitive code, use multiple models across passes (auto → pro → o3) and always enable `use_assistant_model=true`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Single-pass for complex code | Use 3-4 passes minimum |
| Skipping precommit after | Always follow with precommit |
| Same model for all passes | Use different models for perspectives |
| Relative file paths | Use absolute paths only |
| Running analyze + codereview together | Choose one based on goal |

---

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Multi-pass analysis | Each pass adds findings | Limit to 3-4 passes for most reviews |
| `relevant_files` | ~200 tokens/file | Use specific paths, not entire directories |
| Multi-model passes | Each model gets full context | Use 2-3 models max for security audits |
| `use_assistant_model=true` | Adds expert validation | Worth it for security-sensitive code |

**Tip**: For large codebases, use `clink` with `codereviewer` role to isolate the review.

---

## See Also

- **precommit** - Always use after codereview for final validation
- **debug** - For investigating runtime bugs (different from code quality)
- **consensus** - For architectural decisions found during review
