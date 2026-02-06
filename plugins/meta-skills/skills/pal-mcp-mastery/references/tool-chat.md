# chat - Collaborative Conversation

## Purpose

Multi-turn conversation with external AI models for second opinions, approach validation, and collaborative problem-solving.

## When to Use

- Brainstorming approaches
- Validating assumptions
- Getting fresh perspectives
- Generating implementation ideas
- Quick questions needing external model strengths

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | The message or question to discuss |
| `model` | string | No | Target model (auto, pro, flash, o3, gpt5, gpt5.2, codex) |
| `continuation_id` | string | No | UUID to continue existing conversation |
| `absolute_file_paths` | array | No | File paths for context (**MUST be absolute paths**) |
| `images` | array | No | Image paths for vision-capable models |
| `temperature` | number | No | 0 = deterministic, 1 = creative |
| `thinking_mode` | string | No | Reasoning depth: minimal, low, medium, high, max |
| `working_directory_absolute_path` | string | Yes | Directory for generated code artifacts |

> **Note**: The `chat` tool uses `absolute_file_paths` (not `relevant_files` like workflow tools). This matches CLI conventions.

## Example Usage

```
# Simple question
chat(
  prompt="What's the best approach for Redis vs Memcached for session caching?",
  model="pro"
)

# With file context
chat(
  prompt="Review this authentication approach",
  absolute_file_paths=["/absolute/path/to/auth.py"],
  working_directory_absolute_path="/absolute/path/to/project",
  model="auto"
)

# Continue conversation
chat(
  prompt="What about the edge case where session expires?",
  continuation_id="abc123-def456"
)
```

## Output Structure

- Conversational response with reasoning
- `continuation_id` for threading follow-ups
- Can reference provided files
- **Code Generation**: When generating code, saves to `pal_generated.code` file in the working directory

## Optimal Use Cases

| Use Case | Why chat Excels |
|----------|-----------------|
| Algorithm explanations | File context + multi-turn discussion |
| Technology comparisons | Quick brainstorming (PostgreSQL vs MongoDB) |
| Architectural discussions | Multiple perspectives via continuation |
| Quick questions | Faster than thinkdeep for simple queries |

## Best Practices

1. **Start with `model=auto`** - let Claude select optimal model
2. **Specify explicit models** only when specific capabilities needed (e.g., `o3` for reasoning, `codex` for code)
3. **Use continuation_id** for follow-up questions to maintain context
4. **Provide absolute paths** for `absolute_file_paths` - relative paths fail silently
5. **Always provide `working_directory_absolute_path`** - required for code generation artifacts

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using relative paths | Always use absolute paths |
| Not using continuation_id for follow-ups | Pass the ID from previous response |
| Using chat for complex analysis | Use `thinkdeep` instead |

---

## See Also

- **thinkdeep** - For deep analysis requiring multiple reasoning steps
- **challenge** - For validating assumptions before acting on chat advice
- **apilookup** - For current API documentation (chat may have stale knowledge)
