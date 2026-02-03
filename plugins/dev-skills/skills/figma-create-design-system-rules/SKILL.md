---
name: figma-create-design-system-rules
description: This skill should be used when the user asks to "create design system rules", "generate Figma rules", "set up design rules", "customize design guidelines", "configure Figma integration", or wants to establish project-specific conventions for Figma-to-code workflows. Requires Figma MCP server.
allowed-tools: Read, Write, Edit, Glob, Grep
metadata:
  mcp-server: figma, figma-desktop
---

# Figma Create Design System Rules

Generate custom design system rules tailored to your project for consistent Figma-to-code workflows.

## Content Map

| File | When to Read |
|------|--------------|
| **[references/workflow-details.md](references/workflow-details.md)** | Detailed workflow, rule templates, complete examples |
| **[../../shared-references/figma-mcp-config.md](../../shared-references/figma-mcp-config.md)** | MCP setup, verification, troubleshooting |

## When to Use This Skill

Use this skill to **establish project-wide Figma conventions**:
- Configure CLAUDE.md with design system rules
- Define component paths, styling tokens, and naming conventions
- Set up consistent Figma-to-code translation guidelines

For **implementing specific designs**, use `figma-implement-design` instead.

## Prerequisites

- Figma MCP server connected (`figma` or `figma-desktop`)
- Access to project codebase for analysis
- Understanding of team's component conventions

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

1. **Run Tool** - `create_design_system_rules(clientLanguages, clientFrameworks)`
2. **Get Variables** - `get_variable_defs(fileKey, nodeId)` to extract existing tokens
3. **Analyze Codebase** - Components, styling, tokens, patterns
4. **Generate Rules** - Create project-specific rules based on analysis
5. **Save to CLAUDE.md** - Add rules under "Figma MCP Server Rules"
6. **Test and Iterate** - Validate with simple implementation, refine

## Tool Reference

| Tool | Purpose |
|------|---------|
| `create_design_system_rules` | Generate tailored design system guidance |
| `get_variable_defs` | Extract design tokens (colors, spacing, typography) |
| `get_design_context` | Analyze existing component patterns |

## Prompt Patterns

Steer rule generation toward your stack:

| Goal | Prompt |
|------|--------|
| Framework-specific | "create rules for React + Tailwind project" |
| Token extraction | "generate rules based on our Figma variables" |
| Component focus | "create rules emphasizing component reuse from `src/ui`" |

## Codebase Analysis Checklist

| Area | Questions |
|------|-----------|
| **Components** | Where located? How organized? Naming conventions? |
| **Styling** | CSS framework? Token location? Design variables? |
| **Patterns** | Prop structures? Composition patterns? |
| **Architecture** | State management? Routing? Import aliases? |

## Essential Rules Template

```markdown
## Component Organization
- UI components are in `[PATH]`
- IMPORTANT: Always use existing components when possible

## Styling Rules
- Use `[FRAMEWORK]` for styling
- IMPORTANT: Never hardcode colors - use tokens from `[FILE]`

## Figma MCP Integration
1. Run get_design_context first
2. Run get_screenshot for visual reference
3. Download assets from Figma payload
4. Translate to project conventions
5. Validate against screenshot

## Asset Handling
- IMPORTANT: Use localhost sources from Figma directly
- DO NOT import new icon packages
```

## Rule Writing Best Practices

| Principle | Example |
|-----------|---------|
| **Be specific** | "Use Button from `src/ui/Button.tsx`" not "Use design system" |
| **Make actionable** | "Import colors from `src/theme/colors.ts`" not "Don't hardcode" |
| **Use IMPORTANT:** | Prefix critical rules that must never be violated |
| **Document why** | "Use absolute imports (makes refactoring easier)" |

## Decision Checklist

- [ ] Analyzed component organization?
- [ ] Extracted design tokens with `get_variable_defs`?
- [ ] Identified styling approach and tokens?
- [ ] Documented naming conventions?
- [ ] Defined Figma integration flow?
- [ ] Saved to CLAUDE.md?

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Write vague rules | Be specific with paths and conventions |
| Create too many rules | Focus on most impactful 20% |
| Skip codebase analysis | Analyze before writing rules |
| Leave rules stale | Update when architecture changes |

## Related Figma Skills

| Need | Skill |
|------|-------|
| Implement designs | `figma-implement-design` |
| Connect Figma to code | `figma-code-connect-components` |
| Bulk export & audit | `figma-design-toolkit` |

## Resources

- [Figma MCP Server Documentation](https://developers.figma.com/docs/figma-mcp-server/)
- [Figma Variables and Design Tokens](https://help.figma.com/hc/en-us/articles/15339657135383-Guide-to-variables-in-Figma)
