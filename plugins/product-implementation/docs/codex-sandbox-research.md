# Codex CLI Sandbox & Approval Configuration Research

> Research date: 2026-03-09 | Codex CLI v0.111.0

## Summary

Codex CLI does **not** have an equivalent to Gemini CLI's `--policies` flag for granular per-tool approval. It uses a different but complementary approach: project-level trust + global sandbox modes.

## Sandbox Modes (`-s/--sandbox`)

| Mode | Behavior |
|------|----------|
| `read-only` | Model cannot execute write commands |
| `workspace-write` | (Default) Model can write within workspace |
| `danger-full-access` | No sandbox restrictions |

## Approval Policies (`-a/--ask-for-approval`)

| Mode | Behavior |
|------|----------|
| `untrusted` | Only run "trusted" commands (ls, cat, sed, etc.) without asking; escalate others |
| `on-request` | Model decides when to ask user for approval |
| `never` | Run all commands without approval (deprecated) |
| `on-failure` | Same as `never` (deprecated) |

**Convenience alias**: `--full-auto` = `-a on-request --sandbox workspace-write`

## Configuration File (`~/.codex/config.toml`)

```toml
model = "gpt-5.4"
personality = "pragmatic"
model_reasoning_effort = "medium"

[mcp_servers.mobile-mcp]
command = "npx"
args = ["@mobilenext/mobile-mcp@latest"]

[projects."/path/to/project"]
trust_level = "trusted"
```

Key: Codex supports `[projects]` sections with `trust_level` (trusted/untrusted), but **not** granular per-tool policy rules like Gemini's TOML format.

## Runtime Config Overrides (`-c` flag)

```bash
codex exec -c model="gpt-5.2-codex" -c 'sandbox_permissions=["disk-full-read-access"]' "prompt"
```

The only way to pass structured config (arrays, nested objects) at runtime.

## Context File Injection (`-C` flag)

Codex CLI's `-C` flag is an alias for `--cd` (change directory), NOT a context file injection mechanism. There is no way to pass multiple structured context files to `codex exec`. System prompts and context must be concatenated into the main prompt via stdin.

## Comparison: Codex vs Gemini

| Feature | Codex | Gemini |
|---------|-------|--------|
| Policy file (TOML) | No | Yes (`--policies`) |
| Granular tool approval | No | Yes (per MCP, per tool) |
| Project trust levels | Yes | No |
| Sandbox modes | Yes (3 modes) | No |
| Approval policies | Yes (4 modes) | No |
| MCP server config | Yes (`config.toml`) | No |
| Runtime config overrides | Yes (`-c` flag) | No |

## Impact on UAT Dispatch

For UAT testing, the current approach (`--dangerously-bypass-approvals-and-sandbox`) remains the best option for non-interactive `exec` mode. There is no way to create a Codex policy file equivalent to `scripts/uat/policies/uat-testing.toml`.

If Codex adds per-tool policies in the future, create `scripts/uat/policies/uat-testing.codex.toml` with equivalent rules.

## Recommendation

No action needed. The current UAT script uses `--dangerously-bypass-approvals-and-sandbox` for Codex, which is the correct approach for headless execution. Gemini uses `--yolo` + `--policies` for granular control, which is already implemented.
