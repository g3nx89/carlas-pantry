---
name: pal-mcp-mastery
description: Use when working with PAL MCP server tools (chat, thinkdeep, consensus, codereview, precommit, debug, planner, clink, challenge, apilookup) - provides tool selection guidance, parameter optimization, workflow patterns, and context-efficient reference loading for multi-model AI orchestration
---

# PAL MCP Mastery

## Overview

PAL MCP (Provider Abstraction Layer) enables Claude Code to orchestrate conversations with multiple AI models (Gemini, GPT-5, O3, Ollama) through a unified interface. This skill teaches effective PAL usage with **selective context loading** - load only the tool reference you need.

**Core capabilities:**
- **Context Revival**: When Claude's context resets, other models can "remind" Claude via continuation_id
- **CLI-to-CLI Bridge (clink)**: Launch isolated subagents that return only results, preserving context budget
- **Stance-Steered Consensus**: Multiple models debate with configurable perspectives

**Critical warning**: PAL tool definitions consume ~90KB of context (~60% in some configs). Always use `DISABLED_TOOLS` to disable unused tools.

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
```

**Available references:**
- `tool-chat.md` - Collaborative conversation
- `tool-thinkdeep.md` - Extended reasoning
- `tool-consensus.md` - Multi-model debate
- `tool-codereview.md` - Code analysis
- `tool-precommit.md` - Git validation
- `tool-debug.md` - Root cause analysis
- `tool-planner.md` - Project planning
- `tool-clink.md` - CLI subagent bridge
- `tool-challenge.md` - Anti-sycophancy
- `tool-apilookup.md` - Live API lookup
- `workflows.md` - Common workflow templates
- `anti-patterns.md` - Mistakes to avoid
- `troubleshooting.md` - Error handling

## Essential Rules

1. **Always use absolute paths** for `relevant_files` - relative paths fail silently
2. **Progress confidence naturally**: `exploring → low → medium → high → certain`
3. **Use continuation_id** for all related operations in a workflow
4. **Set `next_step_required=false`** only on final step
5. **Start with `thinking_mode=medium`** - escalate only when needed
6. **End workflows with `precommit`** for safety validation

## Common Parameter Values

```yaml
# Confidence levels (in order)
confidence: exploring | low | medium | high | certain

# Thinking modes (cost ascending)
thinking_mode: none | low | medium | high | max

# Model aliases
model: auto | pro | flash | o3 | o4-mini | gpt5 | gpt5-mini

# CLI names for clink
cli_name: gemini | claude | codex

# Clink roles
role: default | planner | codereviewer
```

## Model Selection

| Scenario | Model | Rationale |
|----------|-------|-----------|
| Maximum reasoning | `o3` | Extended thinking |
| Code generation | `gpt5` / `gpt5-codex` | Strong implementation |
| Fast iteration | `flash` | Lower latency/cost |
| Complex analysis | `pro` (Gemini) | Capability/cost balance |
| Large codebase | Gemini Pro | 1M token context |

## When NOT to Use PAL

- Simple tasks Claude handles natively
- File operations (use Claude's native tools)
- Code editing (use Claude's Edit tool)
- Tasks not benefiting from external perspectives
