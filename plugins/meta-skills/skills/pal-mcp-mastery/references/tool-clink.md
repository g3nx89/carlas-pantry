# clink - CLI-to-CLI Bridge

## Purpose

Launch isolated CLI instances (Gemini CLI, Codex CLI, Claude Code) as subagents with role-specific prompts, preserving main context budget.

## When to Use

- Heavy research tasks consuming too much context
- Parallel investigations
- Tasks needing specific CLI capabilities (web search, file inspection)
- Context isolation for focused work
- When main context is getting full

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | Task for the external CLI |
| `cli_name` | string | No | Target CLI: gemini (default), claude, codex |
| `role` | string | No | Preset role: default, planner, codereviewer |
| `absolute_file_paths` | array | No | File paths for context |
| `continuation_id` | string | No | Continue existing conversation |
| `images` | array | No | Image paths for visual context |

## CLI Options

| CLI | Auto-Approval Flag | Best For |
|-----|-------------------|----------|
| `gemini` | `--yolo` | Web search, large context (1M tokens) |
| `codex` | `--dangerously-bypass-approvals-and-sandbox` | Code-heavy tasks |
| `claude` | `--permission-mode acceptEdits` | General assistance |

## Role-Based Prompts

| Role | Behavior |
|------|----------|
| `default` | General-purpose assistance |
| `planner` | Project planning and decomposition |
| `codereviewer` | Code quality and security analysis |

## Example Usage

```
# Security audit with Codex
clink(
  prompt="Audit auth module for OWASP Top 10 vulnerabilities",
  cli_name="codex",
  role="codereviewer",
  absolute_file_paths=["/src/auth/"]
)

# Planning with Gemini
clink(
  prompt="Create detailed migration plan for microservices",
  cli_name="gemini",
  role="planner"
)

# Research with Gemini's web search
clink(
  prompt="Research latest React 19 Server Components best practices",
  cli_name="gemini"
)

# Large codebase analysis
clink(
  prompt="Analyze the entire src/ directory for dead code",
  cli_name="gemini",  # 1M token context
  absolute_file_paths=["/project/src/"]
)
```

## Context Isolation Pattern

```
# Main context is getting full
# Delegate heavy task to subagent

# Step 1: Spawn isolated subagent
clink(
  prompt="Perform comprehensive security audit of payment module",
  cli_name="codex",
  role="codereviewer",
  absolute_file_paths=["/src/payments/"]
)
# → Subagent works in isolation
# → Returns only final report
# → Main context preserved

# Step 2: Use report in main context
debug(
  step="Investigate findings from security audit",
  findings="<from_clink_report>",
  ...
)
```

## Best Practices

1. **Use for context-heavy tasks** - saves main context budget
2. **Gemini for web search** - has internet access
3. **Gemini for large files** - 1M token context
4. **Codex for code review** - specialized for code analysis
5. **Use after planner** - plan first, then dispatch phases

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using clink for simple questions | Use chat instead |
| Not specifying role for code review | Use `role="codereviewer"` |
| Relative file paths | Use absolute paths |
| Overusing clink | Reserve for genuinely heavy tasks |
