---
name: figma-code-connect-components
description: This skill should be used when the user asks to "connect Figma to code", "code connect", "map component to code", "link design to code", "create code connect mapping", "add code connect", or wants to establish mappings between Figma design components and code implementations. Requires Figma MCP server.
allowed-tools: Read, Glob, Grep
metadata:
  mcp-server: figma, figma-desktop
---

# Figma Code Connect Components

Connect Figma design components to code implementations using Code Connect.

## Content Map

| File | When to Read |
|------|--------------|
| **[references/workflow-details.md](references/workflow-details.md)** | Detailed step-by-step workflow, examples, troubleshooting |
| **[../../shared-references/figma-mcp-config.md](../../shared-references/figma-mcp-config.md)** | MCP setup, verification, troubleshooting |

## When to Use This Skill

Use this skill to **establish persistent mappings** between Figma components and code:
- Link Figma design components to their code implementations
- Enable developers to navigate from Figma to code
- Maintain design-code consistency across team

For **implementing designs** as new code, use `figma-implement-design` instead.

## Prerequisites

- Figma MCP server connected (`figma` or `figma-desktop`)
- Figma URL with `node-id` parameter OR node selected in desktop app
- **IMPORTANT:** Component must be published to team library

## Step 0: MCP Setup (if not configured)

If MCP calls fail because Figma MCP is not connected:

```bash
# Add Figma MCP server
claude mcp add figma --url https://mcp.figma.com/mcp

# Login with OAuth
claude mcp login figma
```

After login, restart Claude Code. See shared `figma-mcp-config.md` for troubleshooting.

## Quick Workflow

1. **Get Node ID** - Parse from URL (`node-id=1-2` → `1:2`) or use desktop selection
2. **Get Metadata** - `get_metadata(fileKey, nodeId)` to identify `<symbol>` nodes
3. **Check Existing** - `get_code_connect_map(fileKey, nodeId)` for each component
4. **Get Context** - `get_design_context(fileKey, nodeId)` for unconnected components
5. **Find Code Match** - Scan codebase for matching component (name, props, structure)
6. **Create Mapping** - `add_code_connect_map(nodeId, source, componentName, ...)`
7. **Repeat** - Process all unconnected components, provide summary

## URL Parsing

```
URL: https://figma.com/design/:fileKey/:fileName?node-id=1-2
                              ^^^^^^^^                 ^^^
                              fileKey                  nodeId (convert - to :)
```

**Note:** `figma-desktop` MCP uses currently open file (no fileKey needed).

## Tool Reference

| Tool | Purpose |
|------|---------|
| `get_metadata` | Get node structure, identify `<symbol>` nodes (components) |
| `get_code_connect_map` | Check if component already connected |
| `get_design_context` | Get detailed component structure and props |
| `add_code_connect_map` | Create the Code Connect mapping |

## add_code_connect_map Parameters

| Parameter | Example |
|-----------|---------|
| `nodeId` | `"42:15"` (colon format) |
| `source` | `"src/components/Button.tsx"` |
| `componentName` | `"Button"` |
| `clientLanguages` | `"typescript,javascript"` |
| `clientFrameworks` | `"react"`, `"vue"`, `"svelte"` |
| `label` | `"React"`, `"Vue"`, `"Compose"`, `"SwiftUI"` |

## Prompt Patterns

| Goal | Prompt |
|------|--------|
| Check mapping | "show the code connect map for this selection" |
| Create mapping | "map this node to `src/components/Button.tsx`" |
| List connected | "what code component is connected to this?" |

## Decision Checklist

- [ ] Figma URL has `node-id` parameter?
- [ ] Component published to team library?
- [ ] Checked for existing Code Connect mapping?
- [ ] Found matching code component with similar props?
- [ ] Detected correct language and framework?

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Skip checking existing mappings | Always run `get_code_connect_map` first |
| Guess the file path | Scan codebase and confirm with user |
| Use URL format node ID | Convert `1-2` to `1:2` for tools |
| Map unpublished components | Ensure component is published to library |

## Best Practices

- **Proactive search** - Scan codebase to find matches, don't just ask for path
- **Structure matching** - Compare props, not just names
- **Clear communication** - Explain what was found and why it's a good match
- **Handle ambiguity** - When multiple candidates exist, present options

## Related Figma Skills

| Need | Skill |
|------|-------|
| Implement designs | `figma-implement-design` |
| Set up design rules | `figma-create-design-system-rules` |
| Bulk export & audit | `figma-design-toolkit` |

## Resources

- [Code Connect Documentation](https://help.figma.com/hc/en-us/articles/23920389749655-Code-Connect)
- [Figma MCP Server Tools](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/)
