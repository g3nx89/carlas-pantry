---
name: pal-mcp-mastery
description: This skill should be used when the user asks to "use PAL", "call another model", "get a second opinion from GPT/Gemini/O3", "debug with PAL", "run codereview", "use consensus for decisions", "challenge my assumption", "lookup current API docs", "configure PAL", "set PAL environment variables", "disable PAL tools", "configure PAL timeout", "create a clink role", "customize clink", "use deepthinker", "use planreviewer", "migrate from ~/.pal/", or mentions PAL MCP tools (chat, thinkdeep, consensus, codereview, precommit, debug, planner, clink, challenge, apilookup). Provides tool selection guidance, parameter optimization, configuration management, custom clink roles, and workflow patterns for multi-model AI orchestration.
version: 0.4.0
---

# PAL MCP Mastery

> **Compatibility**: Verified against PAL MCP v1.x (January 2026)

## Overview

PAL MCP (Provider Abstraction Layer) enables Claude Code to orchestrate conversations with multiple AI models (Gemini, GPT-5, O3, Ollama) through a unified interface. This skill provides guidance for effective PAL usage with **selective context loading** - load only the tool reference needed.

**Core capabilities:**
- **Context Revival**: When Claude's context resets, other models can "remind" Claude via continuation_id
- **CLI-to-CLI Bridge (clink)**: Launch isolated subagents that return only results, preserving context budget
- **Stance-Steered Consensus**: Multiple models debate with configurable perspectives

**Critical warning**: PAL tool definitions consume ~90KB of context (~60% in some configs). Disable unused tools via `DISABLED_TOOLS` in `.env`.

## Quick Start

For simple tasks, invoke tools directly without loading additional references:

**Quick Question** → `chat(prompt="...", model="auto")`
**Current API docs** → `apilookup(prompt="React 19 streaming patterns")`
**Validate assumption** → `challenge(prompt="Statement to test")`

For complex tasks, follow this pattern:
1. Load the relevant tool reference: `Read: $SKILL_PATH/references/tool-{name}.md`
2. Pass `continuation_id` between related calls in multi-step workflows
3. End code changes with `codereview` → `precommit` sequence

**Context Budget Tip**: PAL tool definitions consume ~90KB. Disable unused tools via `DISABLED_TOOLS` in `.env`.

## Tool Selection Decision Tree

```
Quick question or brainstorm?
├── YES → chat
└── NO ↓

Deep reasoning or edge case analysis needed?
├── YES → thinkdeep
└── NO ↓

Choosing between options, need multiple perspectives?
├── YES → consensus
└── NO ↓

Something broken or behaving unexpectedly?
├── YES → debug
└── NO ↓

Reviewing code quality before merge/commit?
├── YES → codereview → precommit
└── NO ↓

Planning complex feature or migration?
├── YES → planner
└── NO ↓

Need current API documentation (not training data)?
├── YES → apilookup
└── NO ↓

Validating an assumption that might be wrong?
├── YES → challenge
└── NO ↓

Heavy task needing context isolation?
├── YES → clink
└── NO → chat with specific model
```

## Quick Reference

| Tool | Use When | Key Parameters |
|------|----------|----------------|
| `chat` | Quick questions, brainstorming, multi-turn | `prompt`, `model`, `continuation_id` |
| `thinkdeep` | Complex problems, architecture, edge cases | `thinking_mode`, `confidence`, `step_number` |
| `consensus` | Technology choices, need multi-model debate | `models[]`, `stance_steering` |
| `codereview` | Pre-merge quality, security audits | `relevant_files`, `step_number`, `confidence` |
| `precommit` | Final validation before git commit | `continuation_id` (from codereview) |
| `debug` | Runtime errors, race conditions, root cause | `hypothesis`, `confidence`, `thinking_mode` |
| `planner` | Project breakdown, migration planning | `step_number`, `total_steps` |
| `clink` | Context isolation, spawn CLI subagents | `cli_name`, `role`, `files` |
| `challenge` | Test assumptions, prevent sycophancy | `prompt` (statement to challenge) |
| `apilookup` | Current docs, avoid stale training data | `prompt` (API/SDK query) |

## Tool Selection Matrix (with Reasoning Depth)

| Developer Objective | Primary Tool | Reasoning Depth |
|---------------------|--------------|-----------------|
| Solve a specific runtime error | `debug` | High: Requires hypothesis testing |
| Analyze a large legacy directory | `analyze` | Medium: Pattern recognition focus |
| Decide between two frameworks | `consensus` | High: Multi-model debate |
| Check code for security flaws | `codereview` | High: Focused on anti-patterns |
| Draft a multi-phase feature roadmap | `planner` | Medium: Decomposition focus |
| Verify documentation for a current-year API | `apilookup` | Low: Information retrieval |
| Challenge a reflexive "Yes" from AI | `challenge` | High: Critical reasoning |
| Delegate task to a fresh context | `clink` | Variable: Role-based isolation |

## Selective Reference Loading

**Load tool-specific reference only when using that tool:**

```
# Before using a specific tool, load its reference:
Read: $SKILL_PATH/references/tool-{toolname}.md

# For workflow patterns:
Read: $SKILL_PATH/references/workflows.md

# For troubleshooting:
Read: $SKILL_PATH/references/troubleshooting.md

# For common mistakes:
Read: $SKILL_PATH/references/anti-patterns.md

# For PAL configuration and overrides:
Read: $SKILL_PATH/references/configuration.md

# For custom clink roles:
Read: $SKILL_PATH/references/clink-roles.md
```

**Available references:**

Core documentation:
- `shared-parameters.md` - **Core parameters shared across tools** (confidence, thinking_mode, step workflow)
- `workflows.md` - Common workflow templates
- `context-management.md` - Thread limits, continuation_id patterns
- `anti-patterns.md` - Mistakes to avoid
- `troubleshooting.md` - Error handling
- `architecture.md` - Provider matrix, Large Prompt Bridge, BaseTool model
- `configuration.md` - **PAL configuration hierarchy, env vars, ~/.pal overrides**
- `clink-roles.md` - **Custom clink roles (deepthinker, planreviewer, etc.)**

Tool-specific references:
- `tool-chat.md` - Collaborative conversation
- `tool-thinkdeep.md` - Extended reasoning
- `tool-consensus.md` - Multi-model debate
- `tool-codereview.md` - Code analysis
- `tool-precommit.md` - Git validation
- `tool-debug.md` - Root cause analysis
- `tool-planner.md` - Project planning
- `tool-clink.md` - CLI subagent bridge (includes custom roles)
- `tool-challenge.md` - Anti-sycophancy
- `tool-apilookup.md` - Live API lookup
- `tool-listmodels.md` - Model discovery

Typically disabled tools (enable in `DISABLED_TOOLS` when needed):
- `tool-analyze.md` - Codebase analysis
- `tool-testgen.md` - Test generation
- `tool-refactor.md` - Code transformation

Example clink role templates:
- `examples/clink-roles/deepthinker.txt` - Deep analysis with ST
- `examples/clink-roles/planreviewer.txt` - Red/Blue team review
- `examples/clink-roles/uat_mobile.txt` - Mobile UAT testing
- `examples/clink-roles/researcher.txt` - Documentation research
- `examples/clink-roles/securityauditor.txt` - Security assessment

## Essential Rules

1. **Absolute paths required** - File parameters must use absolute paths; relative paths fail silently
2. **Parameter naming varies** - `clink` uses `absolute_file_paths`, other tools use `relevant_files` (same purpose, different names)
3. **Progress confidence naturally** - `exploring → low → medium → high → certain`
4. **Chain with continuation_id** - pass between all related operations in a workflow
5. **Terminate correctly** - set `next_step_required=false` only on final step
6. **Start at medium thinking** - escalate `thinking_mode` only when complexity requires
7. **End with precommit** - complete workflows with safety validation before commit

## Common Parameter Values

### Thinking Mode Token Budgets

See `shared-parameters.md` for detailed token budgets. Quick guide:
- **minimal/low**: Simple tasks, formatting
- **medium**: Default for most development (recommended starting point)
- **high/max**: Complex debugging, security audits (256x cost increase)

**Cost warning**: `max` mode costs 256x more than `minimal`. Start with `medium`, escalate only when complexity requires.

### Confidence & Thinking Mode Values

```yaml
# Confidence levels (in order)
confidence: exploring | low | medium | high | very_high | almost_certain | certain

# Thinking modes (cost ascending)
thinking_mode: minimal | low | medium | high | max

# Model aliases
model: auto | pro | flash | o3 | o4-mini | gpt5 | gpt5-mini

# CLI names for clink
cli_name: gemini | claude | codex

# Clink roles (built-in)
role: default | planner | codereviewer

# Clink roles (custom)
role: deepthinker | planreviewer | uat_mobile | researcher | securityauditor
# See clink-roles.md for detailed specifications and examples/clink-roles/ for templates
```

## Model Selection

| Scenario | Model | Rationale |
|----------|-------|-----------|
| Maximum reasoning | `o3` | Extended thinking |
| Code generation | `gpt5` / `gpt5-codex` | Strong implementation |
| Fast iteration | `flash` | Lower latency/cost |
| Complex analysis | `pro` (Gemini) | Capability/cost balance |
| Large codebase | Gemini Pro | 1M token context |

## Troubleshooting Quick Index

| Symptom | Quick Fix | See |
|---------|-----------|-----|
| `MCP error -32001: Request timed out` | Set `MCP_TOOL_TIMEOUT=300000` | `troubleshooting.md` |
| `zen ✘ failed` | Install uvx or use explicit model | Connection Failures |
| AI looping without progress | Request summary, start fresh | Being Stuck section |
| Model not available | Check `listmodels`, verify API key | Error Lookup Table |
| Response blocked | Try different model or simplify prompt | Model-Specific Issues |
| Changes not taking effect | Set `PAL_MCP_FORCE_ENV_OVERRIDE=true`, restart | Environment Variables |

**Full reference**: `$SKILL_PATH/references/troubleshooting.md`

## Configuration Quick Reference

**Philosophy**: Prefer project-level overrides (`PROJECT_ROOT/conf/`, `.env`) over user-level (`~/.pal/`).

**Priority**: Env Vars > `~/.pal/` (clink only) > `*_CONFIG_PATH` > `PROJECT_ROOT/conf/` > Defaults

### Minimal Project Setup

```bash
# PROJECT_ROOT/.env
PAL_MCP_FORCE_ENV_OVERRIDE=true        # Always set this
DEFAULT_MODEL=flash
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer  # Save ~90KB
LOG_LEVEL=INFO
```

### Full Project Setup with Custom Clink Roles

```
my-project/
├── .env                              # Environment overrides (gitignored)
├── conf/
│   └── cli_clients/
│       ├── gemini.json               # Clink config
│       ├── gemini_deepthinker.txt    # Role prompt
│       └── gemini_planreviewer.txt
```

```bash
# .env
PAL_MCP_FORCE_ENV_OVERRIDE=true
CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
```

```json
// conf/cli_clients/gemini.json
{
  "name": "gemini",
  "command": "gemini",
  "additional_args": ["--yolo"],
  "roles": {
    "deepthinker": { "prompt_path": "gemini_deepthinker.txt" },
    "planreviewer": { "prompt_path": "gemini_planreviewer.txt" }
  }
}
```

**Full reference**: `$SKILL_PATH/references/configuration.md`

## When NOT to Use PAL

- Simple tasks Claude handles natively
- File operations (use Claude's native tools)
- Code editing (use Claude's Edit tool)
- Tasks not benefiting from external perspectives
