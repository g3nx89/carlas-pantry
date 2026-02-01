# analyze - Codebase Analysis

> **Note**: This tool is typically disabled via `DISABLED_TOOLS`. Enable only when needed for large codebase analysis.

## Purpose

Architectural analysis and pattern detection for understanding large codebases. Unlike codereview (which finds issues), analyze explains how code works.

## When to Use

- Mapping dependencies across 100+ files
- Understanding legacy architecture
- Identifying design patterns in unfamiliar code
- Onboarding to a new project
- Creating architecture documentation

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Analysis step description |
| `step_number` | integer | Yes | Current step (1-indexed) |
| `total_steps` | integer | Yes | Expected total steps |
| `next_step_required` | boolean | Yes | Whether workflow continues |
| `findings` | string | Yes | Discoveries from current step |
| `model` | string | No | Target model (prefer `pro` for large context) |
| `analysis_type` | string | No | architecture, patterns, dependencies |
| `output_format` | string | No | summary, detailed |
| `relevant_files` | array | No | Directories to analyze (ABSOLUTE paths) |

## Example Usage

```
analyze(
  step="Map architecture and data flows in legacy module",
  step_number=1,
  total_steps=3,
  next_step_required=True,
  findings="Initial discovery of module structure",
  analysis_type="architecture",
  output_format="detailed",
  relevant_files=["/src/legacy/"],
  model="pro"
)
```

## Best Practices

1. Use for discovery on unfamiliar codebases
2. Prefer `pro` model (Gemini) for large context windows (1M tokens)
3. Follow with `codereview` for specific quality checks
4. Scope to specific directories, not entire repos

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using analyze + codereview on same files | Choose one based on goal (understand vs critique) |
| Analyzing without scoping | Specify directories, not entire repos |
| Using for bug finding | Use `debug` or `codereview` instead |

## Context Budget Impact

| Factor | Impact | Mitigation |
|--------|--------|------------|
| Large directories | Can consume significant context | Scope to specific subdirectories |
| Detailed output | ~2x context vs summary | Use summary for initial exploration |

**Tip**: For very large codebases, use `clink` to delegate analysis to Gemini (1M tokens).

---

## See Also

- **codereview** - For finding issues (different from understanding)
- **clink** - For context-isolated large analysis
- **thinkdeep** - For deep reasoning about specific problems
