# Figma MCP Configuration Reference

Setup, verification, and troubleshooting for Figma MCP server connection.

## MCP Server Options

| Server | Type | Use Case |
|--------|------|----------|
| `figma` | Remote (HTTP) | General use, requires OAuth |
| `figma-desktop` | Local | Uses Figma desktop app selection |

## Remote Server Setup (figma)

### Claude Code Setup

```bash
# Add the Figma MCP server
claude mcp add figma --url https://mcp.figma.com/mcp

# Login with OAuth
claude mcp login figma
```

### Manual Config (config.toml)

```toml
[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
bearer_token_env_var = "FIGMA_OAUTH_TOKEN"
http_headers = { "X-Figma-Region" = "us-east-1" }
```

**Notes:**
- Bearer token must be available as `FIGMA_OAUTH_TOKEN` in environment
- Align region header with your Figma organization region
- Optional timeouts: `startup_timeout_sec` (default 10), `tool_timeout_sec` (default 60)

### Environment Variable Setup

```bash
# One-time for current shell
export FIGMA_OAUTH_TOKEN="<token>"

# Persist for future sessions (add to ~/.zshrc or ~/.bashrc)
echo 'export FIGMA_OAUTH_TOKEN="<token>"' >> ~/.zshrc

# Verify before launching
echo $FIGMA_OAUTH_TOKEN
```

## Desktop Server Setup (figma-desktop)

The `figma-desktop` MCP server connects to the Figma desktop app directly:

- No OAuth required
- Uses currently selected node in Figma desktop app
- `fileKey` not needed in tool calls (uses open file)

## Verification Checklist

- [ ] MCP server added to config
- [ ] OAuth token set (remote) or Figma desktop app open (local)
- [ ] Test with `get_design_context` on a known node
- [ ] Verify screenshot retrieval works

## Troubleshooting

### Token Not Picked Up

**Cause:** Environment variable not available to Claude Code process.

**Solution:**
- Export `FIGMA_OAUTH_TOKEN` in the shell that launches Claude Code
- Add to shell profile (`~/.zshrc`, `~/.bashrc`) and restart shell
- Verify with `echo $FIGMA_OAUTH_TOKEN`

### OAuth Errors

**Cause:** Invalid token or MCP client not enabled.

**Solution:**
- Verify token is valid and not expired
- Ensure token doesn't include surrounding quotes
- Re-authenticate with `claude mcp login figma`

### Network/Region Errors

**Cause:** Region mismatch between config and Figma organization.

**Solution:**
- Update `X-Figma-Region` header to match your org's region
- Common regions: `us-east-1`, `eu-west-1`

### Tools Not Available

**Cause:** MCP server not connected or not started.

**Solution:**
- Restart Claude Code after config changes
- Check MCP server status
- Verify network connectivity to `mcp.figma.com`

### Selection-Based Prompting Not Working

**Cause:** Using remote server without URL, or desktop app not open.

**Solution:**
- Remote server requires Figma URL with `node-id` parameter
- Desktop server requires Figma desktop app open with node selected

## Link-Based vs Selection-Based

| Mode | Server | Requirement |
|------|--------|-------------|
| **Link-based** | `figma` (remote) | Figma URL with `node-id` |
| **Selection-based** | `figma-desktop` | Node selected in desktop app |

**Link-based:** Copy Figma frame/layer link, tools extract node ID from URL.

**Selection-based:** Select node in Figma desktop app, tools use current selection.
