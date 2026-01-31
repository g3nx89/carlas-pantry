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
1. Set `FORCE_ENV_FILE=true` in `.env`
2. Save `.env` file
3. Restart Claude Code completely
4. Verify with `listmodels`

### Cached Environment Variables

Claude Code may pass environment variables that override `.env` values. `FORCE_ENV_FILE=true` ensures `.env` values take precedence.

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
FORCE_ENV_FILE=true

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

## Verification Checklist

After any configuration change:

- [ ] `.env` file saved
- [ ] `FORCE_ENV_FILE=true` set
- [ ] Claude Code restarted (not just conversation)
- [ ] `/mcp` shows PAL connected
- [ ] `listmodels` shows expected models
