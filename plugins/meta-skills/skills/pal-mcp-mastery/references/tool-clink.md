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

⚠️ **Security Warning**: These flags bypass safety prompts to allow autonomous code edits and tool use via MCP. **Run only in trusted sandboxes** - never in production environments.

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

## Subagent Chaining

Clink supports multi-level spawning where agents spawn other agents:

```
Claude Code
  └→ spawns Codex subagent
       └→ spawns Gemini CLI subagent
```

Each subagent returns **only the final results** to its parent, keeping token usage efficient. The parent never sees the intermediate reasoning.

## Custom Roles: The Researcher Pattern

Create a custom role restricted to `apilookup` and web searches for objective documentation retrieval:

```
clink(
  prompt="Research current best practices for React Server Components streaming patterns",
  cli_name="gemini",
  role="researcher"  # Custom role (if configured)
)
```

This ensures documentation retrieval remains **objective** and does not become entangled with implementation logic.

## Nested Capability: Web Browsing via CLI

PAL doesn't offer a direct "browse" tool, but you can enable web search in the underlying CLI and invoke it via clink:

```toml
# In ~/.codex/config.toml
[agent]
web_search = true
```

Then invoke:
```
clink(
  prompt="Search for and summarize the latest security advisories for Log4j 2.x",
  cli_name="codex"  # Has web_search enabled
)
```

This "Nested Capability" approach extends PAL beyond its native tools.

## Success Stories

| Use Case | Configuration | Outcome |
|----------|--------------|---------|
| **Monorepo Dependency Mapping** | `clink` + Gemini Pro (1M context) | Mapped dependencies across 500+ files while main context stayed efficient |
| **Security Audit at Scale** | `clink` + Codex `codereviewer` role | Isolated audit in fresh context, returned only final report |
| **Cross-Codebase Research** | `clink` + Gemini web search | Retrieved current docs without polluting main reasoning |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using clink for simple questions | Use chat instead |
| Not specifying role for code review | Use `role="codereviewer"` |
| Relative file paths | Use absolute paths |
| Overusing clink | Reserve for genuinely heavy tasks |
| Running in production | Use only in trusted sandboxes |
| Not leveraging nested capabilities | Enable web_search in CLI config, then invoke via clink |

---

## Context Budget Impact

| Factor | Impact | Benefit |
|--------|--------|---------|
| Context isolation | Subagent has own context | **Preserves main context** |
| Return value only | Only final report returns | Minimal context pollution |
| Gemini 1M context | Can handle entire codebases | Offload heavy analysis |

**Key insight**: `clink` is **context-positive** - it REDUCES main context usage by delegating to isolated subagents.

**Use clink when**: Main context is filling up, or task would consume >50% of available context.

---

## See Also

- **planner** - Plan first, then use clink to dispatch phases
- **chat** - For lightweight questions that don't need context isolation
