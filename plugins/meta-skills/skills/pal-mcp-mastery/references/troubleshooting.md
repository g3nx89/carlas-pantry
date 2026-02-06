# PAL MCP Troubleshooting

## Quick Diagnostic Commands

```bash
# View recent server logs
tail -n 100 logs/mcp_server.log

# Search for errors
grep "ERROR" logs/mcp_server.log

# Verify Python environment
which python
# Expected: .../pal-mcp-server/.pal_venv/bin/python

# Debug mode
claude --debug

# Reset virtual environment
rm -rf .pal_venv && ./run-server.sh

# Verify MCP connection in Claude Code
/mcp
```

---

## Error → Fix Lookup Table

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `MCP error -32001: Request timed out` | Client timeout too short | Add: `"MCP_TOOL_TIMEOUT": "300000"` (5 min) |
| `At least one API configuration required` | No API keys | Add `GEMINI_API_KEY` or `OPENAI_API_KEY` |
| `zen ✘ failed` (with auto + custom endpoint) | Auto mode needs provider metadata | Set explicit `DEFAULT_MODEL`, not `auto` |
| `'model' is not one of [...]` | Model name wrong or provider missing | Check model alias, verify API key |
| `Response blocked or incomplete` | Gemini safety filter | Try different model or simplify prompt |
| `uvx not found` | uvx not installed | Run: `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `Request too large` | Prompt exceeds limits | Reduce `relevant_files`, use clink |
| `Invalid model` | Model not configured | Check `listmodels`, verify API keys |
| `Rate limit exceeded` | Too many requests | Wait, or use different provider |
| `Context files too large` | Token limit hit | Use selective file paths, clink |
| `Input validation error: '...' is a required property` | Missing required parameter | Let Claude handle formatting; rephrase command |
| `Additional properties are not allowed` | Extra parameter in tool call | Remove invalid parameter, use natural language |
| `Refused to support that stance` | Unethical stance requested | Rephrase academically or choose neutral stance |
| `Model not available` | API key lacks permission | Use `listmodels` to check; verify key in provider console |
| `Invalid API key` | Spaces or quotes in .env | Sanitize .env file; test key with curl |
| `Slow response` | High thinking mode on complex task | Reduce `thinking_mode` to medium/low; switch to flash model |
| `Tool not found` | Tool is in DISABLED_TOOLS | Remove from DISABLED_TOOLS in .env and restart |
| `Zod Validation Error (store: false)` | OpenRouter schema mismatch with specific OpenAI models | Omit the `store` parameter in tool call; check for OpenRouter updates |

---

## Connection Failures

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| `zen ✘ failed` | uvx not found | Install uv: `pip install uv` |
| `Connection refused` | Server not running | Run `./run-server.sh` |
| `API key errors` | Missing or invalid key | Check `.env`, restart Claude |
| `auto mode failures` | Custom endpoint + auto | Use explicit model name |

---

## Model-Specific Issues

### Gemini "Response blocked" Errors

- Check if prompt triggers safety filters
- Try different model variant (flash instead of pro)
- Review Gemini API documentation for content policies

### OpenRouter Validation Errors

- Update to latest PAL version
- Use native API instead of OpenRouter for affected models

---

## Environment Variable Issues

### Changes Not Taking Effect

**Solution checklist:**
1. Set `PAL_MCP_FORCE_ENV_OVERRIDE=true` in `.env`
2. Save `.env` file
3. Restart Claude Code completely
4. Verify with `listmodels`

### Cached Environment Variables

Claude Code may pass environment variables that override `.env` values. `PAL_MCP_FORCE_ENV_OVERRIDE=true` ensures `.env` values take precedence.

---

## Timeout Configuration

For long-running operations (reasoning models):

```json
{
  "env": {
    "MCP_TIMEOUT": "300000",
    "MCP_TOOL_TIMEOUT": "300000"
  }
}
```

For Codex CLI (`~/.codex/config.toml`):
```toml
[mcp_servers.pal]
tool_timeout_sec = 1200  # 20 minutes
```

---

## Rate Limit Handling

- Gemini free tier: 1000 requests/day limit
- Space out bulk operations
- Consider paid tiers for production workflows
- Use different models to distribute load

---

## Context Overflow Prevention

1. **Disable unused tools** via `DISABLED_TOOLS`
2. **Use `clink`** for heavy context tasks (subagent isolation)
3. **Monitor context usage** with Claude's context indicator
4. **Use `relevant_files` selectively** - don't include entire directories unless necessary

---

## Essential Environment Variables

```bash
# Minimum viable configuration
GEMINI_API_KEY=your-key
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
DEFAULT_MODEL=auto
PAL_MCP_FORCE_ENV_OVERRIDE=true

# Timeout configuration
MCP_TIMEOUT=300000
MCP_TOOL_TIMEOUT=300000

# Logging for debugging
LOG_LEVEL=DEBUG
```

---

## Windows-Specific Issues

**PowerShell 5.1 compatibility problems** with `run-server.ps1`.

**Workaround:** Use WSL2 instead:
```bash
# In WSL2
git clone https://github.com/BeehiveInnovations/pal-mcp-server.git
cd pal-mcp-server
./run-server.sh
```

---

## Recovery Patterns for Broken Workflows

If a multi-step workflow (e.g., an 8-step debug session) is interrupted:

| Pattern | When to Use | How |
|---------|-------------|-----|
| **Context Revival** | Session crashed mid-workflow | Use `continuation_id` from failed session; secondary model retrieves previous reasoning |
| **Graceful Degradation** | Primary model rate limited | Fall back to Flash model or local Ollama instance |
| **Pristine Reset** | Context pollution (circular reasoning) | Start fresh tool call **without** continuation_id to clear server-side thread |

### Example: Graceful Degradation

```
# Primary model timing out
"Using GPT-5 with high thinking is timing out."
"Let's try with Gemini Flash or medium thinking mode."

# Fall back to lighter configuration
thinkdeep(
  model="flash",
  thinking_mode="medium",  # Down from high
  ...
)
```

**Principle**: Better to get some result with a smaller model than none with a larger one.

---

## Being Stuck / Not Making Progress

**Symptoms:**
- AI looping without new conclusions
- Token usage spiking without useful output
- Same findings repeated across steps
- Debug/thinkdeep running forever until stopped

**Causes:**
- Tool not realizing it should stop
- Context overflow causing confusion
- Insufficient information to make progress

**Recovery Steps:**
1. **Intervene immediately** - Don't let it run forever
2. **Request summary**: "Stop debugging now and summarize findings so far"
3. **Simplify prompt**: Provide more focused logs or break problem down
4. **Fresh start**: Start new debug with the summary as seed input
5. **Different strategy**: If debug loops, try thinkdeep; if thinkdeep loops, try chat

**Prevention:**
- Set clear termination criteria
- Monitor for circular reasoning
- After 3+ iterations without progress, intervene
- Consider using `clink` to isolate heavy tasks

---

## Claude Refuses to Use Tool

**Symptoms:**
- Claude says "I'm not able to do that"
- Normal answer given without tool use
- Tool invocation seems ignored

**Causes:**
- Complex mixed instructions confusing parsing
- Prompt triggered safety guidelines inadvertently
- Tool name not recognized

**Fixes:**
1. **Simplify**: Use "Use [toolname]" early in sentence
2. **Be direct**: "Use debug to diagnose the error on line 10" (not "can you see if debug would help?")
3. **Rephrase**: If safety filters triggered, use neutral technical language
4. **Verify tool enabled**: Check it's not in `DISABLED_TOOLS`

---

## Verification Checklist

After any configuration change:

- [ ] `.env` file saved
- [ ] `PAL_MCP_FORCE_ENV_OVERRIDE=true` set
- [ ] Claude Code restarted (not just conversation)
- [ ] `/mcp` shows PAL connected
- [ ] `listmodels` shows expected models
