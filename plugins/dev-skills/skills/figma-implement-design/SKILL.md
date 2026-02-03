---
name: figma-implement-design
description: This skill should be used when the user asks to "implement design", "build from Figma", "generate code from design", "implement component", "translate Figma to code", provides Figma URLs, or wants to create production-ready code matching Figma specs with 1:1 visual fidelity. Requires Figma MCP server.
allowed-tools: Read, Write, Edit, Glob, Grep
metadata:
  mcp-server: figma, figma-desktop
---

# Figma Implement Design

Translate Figma designs into production-ready code with pixel-perfect accuracy.

## Content Map

| File | When to Read |
|------|--------------|
| **[references/workflow-details.md](references/workflow-details.md)** | Detailed workflow, examples, troubleshooting |
| **[references/tools-and-prompts.md](references/tools-and-prompts.md)** | Tool catalog, prompt patterns to steer output |
| **[../../shared-references/figma-mcp-config.md](../../shared-references/figma-mcp-config.md)** | MCP setup, verification, troubleshooting |

## When to Use This Skill

Use this skill for **real-time, interactive** Figma-to-code workflows:
- Single component or page implementation
- Live design context fetching with screenshot validation
- Integration with existing project design systems

For **batch operations** (bulk export, auditing, token extraction), use `figma-design-toolkit` instead.

## Prerequisites

- Figma MCP server connected (`figma` or `figma-desktop`)
- Figma URL with `node-id` parameter OR node selected in desktop app
- Project should have established design system (preferred)

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

1. **Get Node ID** - Parse from URL (`node-id=1-2`) or use desktop selection
2. **Fetch Context** - `get_design_context(fileKey, nodeId)`
3. **Get Variables** - `get_variable_defs(fileKey, nodeId)` (optional, align tokens)
4. **Get Screenshot** - `get_screenshot(fileKey, nodeId)` for visual reference
5. **Download Assets** - Use localhost sources directly from Figma
6. **Translate** - Convert to project conventions, reuse existing components
7. **Validate** - Compare against screenshot for 1:1 visual parity

## URL Parsing

```
URL: https://figma.com/design/:fileKey/:fileName?node-id=1-2
                              ^^^^^^^^                 ^^^
                              fileKey                  nodeId
```

**Note:** `figma-desktop` MCP uses currently open file (no fileKey needed).

## Tool Reference

| Tool | Purpose |
|------|---------|
| `get_design_context` | Layout, typography, colors, structure |
| `get_screenshot` | Visual reference (source of truth) |
| `get_metadata` | Node map for large/truncated responses |
| `get_variable_defs` | Design tokens (colors, spacing, typography) |

## Prompt Patterns

Steer output toward your stack:

| Goal | Prompt |
|------|--------|
| Change framework | "generate in Vue" / "in plain HTML + CSS" |
| Use components | "using components from `src/components/ui`" |
| Combine | "use `src/ui` components and style with Tailwind" |

## Asset Rules

- **Use localhost sources** - If Figma returns localhost URL, use it directly
- **No new icon packages** - All assets come from Figma payload
- **No placeholders** - Don't create placeholders if source provided

## Validation Checklist

- [ ] Layout matches (spacing, alignment, sizing)
- [ ] Typography matches (font, size, weight, line height)
- [ ] Colors match exactly
- [ ] Interactive states work (hover, active, disabled)
- [ ] Assets render correctly

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Implement without context | Always fetch `get_design_context` first |
| Skip visual reference | Always get screenshot for validation |
| Hardcode values | Use design tokens |
| Create duplicate components | Reuse existing design system components |

## Related Figma Skills

| Need | Skill |
|------|-------|
| Connect Figma to code | `figma-code-connect-components` |
| Set up design rules | `figma-create-design-system-rules` |
| Bulk export & audit | `figma-design-toolkit` |

## Resources

- [Figma MCP Server Documentation](https://developers.figma.com/docs/figma-mcp-server/)
- [Figma MCP Server Tools](https://developers.figma.com/docs/figma-mcp-server/tools-and-prompts/)
