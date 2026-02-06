# Shared Parameters Reference

This file documents parameters shared across multiple PAL MCP tools. Tool-specific parameters are documented in their respective `tool-*.md` files.

## Multi-Step Workflow Parameters

These parameters appear in `debug`, `thinkdeep`, `codereview`, `precommit`, and `consensus`:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `step` | string | Yes | Current step description - what you're investigating/analyzing |
| `step_number` | integer | Yes | Current step in sequence (starts at 1) |
| `total_steps` | integer | Yes | Estimated total steps needed (adjust as you go) |
| `next_step_required` | boolean | Yes | `true` to continue workflow, `false` on final step |
| `findings` | string | Yes | Evidence, clues, observations from current step |
| `model` | string | Yes | Model to use (auto, pro, flash, o3, gpt5, gpt5.2, codex) |
| `continuation_id` | string | No | Thread ID from previous step (preserves context) |

## Confidence Levels

Progress through these levels based on evidence gathered:

| Level | When to Use | Triggers Expert Analysis |
|-------|-------------|-------------------------|
| `exploring` | Initial investigation, gathering data | Yes |
| `low` | Some findings, many unknowns remain | Yes |
| `medium` | Reasonable understanding, validating | Yes |
| `high` | Strong hypothesis with evidence | Yes |
| `very_high` | Very strong evidence, preparing fix | Yes |
| `almost_certain` | Nearly confirmed, implementing | Yes |
| `certain` | 100% confirmed with proof | **No** (skips validation) |

**Warning**: Only use `certain` when absolutely sure. It **prevents external model validation** which is PAL's primary benefit.

## Thinking Mode Token Budgets

> **Note**: The token budgets below are **illustrative guidance** showing relative cost/capability trade-offs. Actual token allocations depend on model-specific `max_thinking_tokens` configured in the model catalog (e.g., Gemini Pro: 32,768, Gemini Flash: 24,576).

| Mode | Relative Budget | Cost Impact | Latency | Recommended Use |
|------|-----------------|-------------|---------|-----------------|
| `minimal` | Very Low | 1x baseline | Ultra-low | Formatting, style checks |
| `low` | Low | ~16x | Low | Basic explanations, routine logic |
| `medium` | Medium | ~64x | Moderate | **Default** - standard development |
| `high` | High | ~128x | High | Complex debugging, security audits |
| `max` | Maximum | ~256x | Very High | Strategic architecture, critical decisions |

**Rule**: Start with `medium`, escalate only when complexity requires deeper reasoning. Use `listmodels` to check specific model capabilities.

## File Path Parameters

| Parameter | Type | Used By | Description |
|-----------|------|---------|-------------|
| `relevant_files` | array | Workflow tools (debug, codereview, thinkdeep, etc.) | Files directly related to the task |
| `files_checked` | array | Workflow tools | All files examined (including ruled-out) |
| `absolute_file_paths` | array | `chat`, `clink` | Files for context (CLI-style naming) |

**Critical**: ALL file path parameters require **absolute paths**. Relative paths (`./file.py`) fail silently. Always use `/absolute/path/to/file.py`.

**Naming Convention**:
- Workflow tools (`debug`, `codereview`, `thinkdeep`, `precommit`, `analyze`) use `relevant_files`
- Simple tools (`chat`, `clink`) use `absolute_file_paths` (matching CLI conventions)

## Analysis Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `hypothesis` | string | Current theory about root cause or solution |
| `issues_found` | array | Issues with severity levels (critical/high/medium/low) |
| `relevant_context` | array | Methods, functions, classes involved |
| `focus_on` | string | Specific area to emphasize (e.g., "security", "performance") |

## Visual Context Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `images` | array | Screenshot/diagram paths for vision-capable models |

**Note**: Only use with vision-capable models (check `listmodels`).

## Model Aliases

> **Note**: Use `listmodels` tool to see all available models for your configured providers. Common aliases below.

### Gemini Models
| Alias | Model | Best For |
|-------|-------|----------|
| `pro` / `gemini3` | Gemini Pro 3.0 Preview | 1M context, complex analysis, thinking modes |
| `flash` | Gemini Flash 2.5 | Fast, low-cost validation |
| `flash2` | Gemini Flash 2.0 | Previous-gen fast model, audio/video input |
| `flashlite` | Gemini Flash Lite 2.0 | Lowest cost, text-only |

### OpenAI Models
| Alias | Model | Best For |
|-------|-------|----------|
| `gpt5` | GPT-5 | General code generation |
| `gpt5-mini` / `mini` | GPT-5-mini | Fast code tasks, budget-friendly |
| `gpt5.2` | GPT-5.2 | Flagship reasoning, configurable effort |
| `gpt5.2-pro` / `gpt5-pro` | GPT-5.2 Pro | Very advanced reasoning (272K output) |
| `gpt5-codex` / `codex` | GPT-5 Codex | Specialized coding, refactoring |
| `gpt5.1-codex` / `codex-5.1` | GPT-5.1 Codex | Agentic coding (Responses API) |
| `codex-mini` | GPT-5.1 Codex mini | Cost-efficient Codex variant |
| `o3` | O3 | Extended reasoning, logic-heavy tasks |
| `o3-mini` | O3-mini | Balanced performance/speed |
| `o3-pro` | O3-Pro | Professional-grade reasoning |
| `o4-mini` | O4-mini | Rapid reasoning, short contexts |
| `gpt4.1` | GPT-4.1 | 1M context, large codebase analysis |
| `nano` | GPT-5 nano | Fastest, cheapest for simple tasks |

### Special
| Alias | Provider | Best For |
|-------|----------|----------|
| `auto` | Claude selection | General tasks (recommended default) |

## Parameter Interaction Rules

1. **continuation_id chains context**: Always pass it between related steps
2. **confidence triggers expert phase**: Values below `certain` invoke assistant model
3. **thinking_mode affects cost**: Higher modes = exponentially more tokens/cost
4. **relevant_files defines scope**: Too many files = context overflow
5. **next_step_required controls flow**: Forgetting to set `false` = infinite loop
