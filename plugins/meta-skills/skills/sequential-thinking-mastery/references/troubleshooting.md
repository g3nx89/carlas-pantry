# Troubleshooting Guide

## Troubleshooting Matrix

| Symptom | Probable Cause | Fix |
|---------|----------------|-----|
| Error -32000 Connection closed | Timeout exceeded | Increase `MCP_TIMEOUT` to 15000 or 30000 |
| CLI Freeze / Hang | Infinite retry loop | Use Ctrl+C. Ensure agent sets `nextThoughtNeeded: false` |
| High token usage | Verbose schema | Switch to `@mcpslim/sequential-thinking-slim` |
| "Rubber Stamping" | Weak prompting | Update system prompt to demand substantive thoughts |
| Circular thoughtNumber | Context compaction | Increase context limit or use checkpoints |
| Type validation errors | String instead of integer | Explicit prompting for numeric types |

## The Token Tax Problem

The official server has a heavy token footprint. The verbose JSON schema descriptions consume approximately **~1,500 tokens** of context overhead just to define the tool.

### The Slim Solution

A community-maintained fork optimizes the Zod schema descriptions:

```bash
npm install @mcpslim/sequential-thinking-slim
```

**Benefits:**
- ~55% reduction in context usage (down to ~688 tokens)
- No loss of functionality
- Recommended for production agents where context is expensive

### Configuration (Claude Desktop)

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@mcpslim/sequential-thinking-slim"],
      "env": {
        "MCP_TIMEOUT": "15000"
      }
    }
  }
}
```

## Connection Closed Error (-32000)

### Symptom
```
MCP error -32000: Connection closed
```

### Root Cause
The `npx` command takes time to resolve packages. The default MCP client timeout (often 60s) may expire before the server acts. Also common during LLM's "thinking" phase before tool call emission.

### Fix

Set `MCP_TIMEOUT` environment variable to a higher value:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "env": {
        "MCP_TIMEOUT": "15000"
      }
    }
  }
}
```

### Alternative: Docker

Using Docker avoids the npx startup penalty:

```bash
docker run --rm -i mcp/sequentialthinking
```

More stable for CI/CD pipelines.

## The Infinite Loop Freeze

### Symptom
- CLI or Desktop interface hangs
- Model repeats the same thought endlessly
- 50+ steps of circular reasoning

### Mechanism

Often caused by:
1. **Race condition** in stdio transport layer
2. **Context compaction failure**: When context window fills up and client "compacts" history, removing recent thought state, LLM loses its place (`thoughtNumber`) and attempts to regenerate missing step

### Mitigation Strategies

1. **Ctrl+C immediately** after task completes if interface freezes

2. **Ensure explicit termination**: Agent's final thought MUST set `nextThoughtNeeded: false`

3. **Circuit Breaker pattern** in prompt:
   ```
   If thoughtNumber > 20, you MUST explicitly ask the user for guidance or attempt a partial solution.
   ```

4. **Checkpoint pattern**: At 15+ steps, create a summary thought as a mental buffer clear

## Windows-Specific Issues

### "Not Connected" Errors (Windows 11)

**Symptom:** MCP clients fail to connect on Windows 11

**Fix:** Install globally instead of using npx:

```bash
npm install -g @modelcontextprotocol/server-sequential-thinking
```

Then reference the global installation in config.

## OpenAI Model Compatibility

### "String Too Long" Error

**Symptom:** OpenAI models fail with description length error

**Cause:** Tool description is 2,780 chars, OpenAI limit is 1,024

**Workaround:**
- Use Claude models (no limit)
- Implement a proxy that truncates description
- Use the Slim fork (shorter descriptions)

## Type Validation Errors

### Symptom
```
Invalid thoughtNumber: must be a number
```

**Cause:** LLMs sometimes generate string values (`"1"`) instead of integers (`1`)

**Fix:** Add explicit instructions in system prompt:

```
IMPORTANT: thoughtNumber and totalThoughts must be integers, not strings.
Correct: "thoughtNumber": 1
Incorrect: "thoughtNumber": "1"
```

## Quality Diagnostics

For detailed quality diagnostics including detecting autopilot mode and orphaned branches, see `references/prompting-patterns.md#quality-diagnostics`.

---

## Related References

- **Prompting patterns**: `prompting-patterns.md` - Strategic templates, quality diagnostics, chain evaluation
- **Technical details**: `technical-reference.md` - ThoughtData interface, state architecture, known issues
- **Branching/Revision**: `branching-revision.md` - Fork-Join pattern, revision loop, convergence rules
