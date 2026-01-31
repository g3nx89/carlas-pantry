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
| `model` | string | Yes | Model to use (auto, pro, o3, flash, gpt5) |
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

| Mode | Token Budget | Cost Multiplier | Latency | Recommended Use |
|------|-------------|-----------------|---------|-----------------|
| `minimal` | 128 | 1x | Ultra-low | Formatting, style checks |
| `low` | 2,048 | 16x | Low | Basic explanations, routine logic |
| `medium` | 8,192 | 64x | Moderate | **Default** - standard development |
| `high` | 16,384 | 128x | High | Complex debugging, security audits |
| `max` | 32,768 | 256x | Very High | Strategic architecture, critical decisions |

**Rule**: Start with `medium`, escalate only when complexity requires deeper reasoning.

## File Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `relevant_files` | array | Files directly related to the task - **MUST be absolute paths** |
| `files_checked` | array | All files examined (including ruled-out) |
| `absolute_file_paths` | array | Used by `clink` - **MUST be absolute paths** |

**Critical**: Relative paths (`./file.py`) fail silently. Always use `/absolute/path/to/file.py`.

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

| Alias | Provider | Best For |
|-------|----------|----------|
| `auto` | Claude selection | General tasks (recommended default) |
| `pro` | Gemini 3.0 Pro | 1M token context, complex analysis |
| `flash` | Gemini Flash | Fast, low-cost validation |
| `o3` | OpenAI | Extended reasoning, logic-heavy tasks |
| `gpt5` | OpenAI GPT-5 | Code generation, implementation |
| `gpt5-mini` | OpenAI | Fast code tasks |

## Parameter Interaction Rules

1. **continuation_id chains context**: Always pass it between related steps
2. **confidence triggers expert phase**: Values below `certain` invoke assistant model
3. **thinking_mode affects cost**: Higher modes = exponentially more tokens/cost
4. **relevant_files defines scope**: Too many files = context overflow
5. **next_step_required controls flow**: Forgetting to set `false` = infinite loop
