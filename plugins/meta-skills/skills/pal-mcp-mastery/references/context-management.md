# Context Management & Threading

## Overview

PAL MCP maintains conversation continuity across tools and models through a **Thread Context Store**. Understanding these mechanics helps avoid common pitfalls.

## continuation_id Threading

The `continuation_id` is a UUID that identifies a persistent context thread.

### How It Works

1. **First tool call**: Server generates a new `continuation_id` in the response
2. **Subsequent calls**: Include the same `continuation_id` to continue the thread
3. **Server reconstructs**: Full conversation context including files, findings, and history

### Thread Context Includes

- All previous prompts and tool outputs
- Files and code snippets shared
- State of multi-step workflows
- Cross-tool memory (what Gemini said, what O3 suggested, etc.)

## Thread Limits

| Setting | Default | Description |
|---------|---------|-------------|
| `CONVERSATION_TIMEOUT_HOURS` | ~3 hours | Thread expiry time |
| `MAX_CONVERSATION_TURNS` | 50 turns | Maximum turns per thread |

**When a thread expires or exceeds limits:**
- Server returns error: "Thread not found or expired"
- Start a new conversation without the old `continuation_id`

## Context Window Management

PAL MCP uses **token budgeting** to prevent context overflow:

- Intermediate steps: Files referenced by name, not full content
- Final steps: Full content embedded when needed
- Older turns: Auto-summarized when threshold hit
- Large contexts: Delegated to models with huge windows (Gemini 1M)

### Large Prompt Bridge

A significant challenge in MCP is the 25k token limit on tool inputs. PAL addresses this via the **Large Prompt Bridge**:

1. When prompt exceeds ~50k characters, server returns a special status
2. Primary agent persists full content to temporary `prompt.txt` file
3. Server reads file directly into target model's memory space
4. Bypasses protocol limitations, enabling entire codebase analysis in one turn

### Shadow History

PAL maintains a **persistent memory store** outside any single model's context:
- Persists across tool switches and context resets
- If Claude's memory clears, PAL invokes secondary model (like o3) to retrieve history
- Synthesizes critical points and "re-contextualizes" the primary agent
- Enables "True Conversation Continuity" - Gemini remembers what o3 said 10 steps ago

## Best Practices

### Always Reuse continuation_id

```
# WRONG - loses context
thinkdeep(step="Step 1", ...)  # Gets ID: abc-123
thinkdeep(step="Step 2", ...)  # New ID! Context lost

# RIGHT - maintains context
response1 = thinkdeep(step="Step 1", ...)
thinkdeep(step="Step 2", continuation_id=response1.continuation_id, ...)
```

### Cross-Tool Threading

Different tools can be chained with the same thread:

```
codereview(...) → continuation_id="abc"
↓
precommit(..., continuation_id="abc")  # Knows what codereview found
↓
debug(..., continuation_id="abc")      # Full history available
```

### For Long Sessions

1. **Monitor conversation length** - after ~40 turns, consider starting fresh
2. **Use clink for isolation** - heavy subtasks in subagent preserve main context
3. **Summarize periodically** - ask for summary before hitting limits

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Thread not found" | Expired or invalid ID | Start new thread |
| "Context too large" | Too much in history | Use clink for subtasks |
| Findings lost between steps | Missing continuation_id | Always pass the ID |

## Environment Configuration

```bash
# In .env file
CONVERSATION_TIMEOUT_HOURS=6    # Extend thread lifetime
MAX_CONVERSATION_TURNS=100      # Allow more turns
LOG_LEVEL=INFO                  # Reduce logging verbosity
```
