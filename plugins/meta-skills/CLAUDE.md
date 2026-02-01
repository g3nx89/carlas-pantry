# CLAUDE.md

This file provides guidance to Claude Code when working with this plugin.

## Plugin Overview

Meta-skills plugin for mastering Claude Code, MCP servers, and agentic workflows. Contains utility skills and best practices documentation.

## Plugin Testing

```bash
# Install locally for testing
claude plugins add /path/to/meta-skills
claude plugins enable meta-skills
```

## Directory Structure

```
meta-skills/
├── .claude-plugin/plugin.json   # Plugin manifest
├── commands/                     # Slash commands (*.md)
├── skills/                       # Skill definitions
├── agents/                       # Subagent definitions
├── templates/                    # Reusable templates
├── config/                       # Plugin configuration
├── CLAUDE.md                     # This file
└── README.md                     # User documentation
```

## Development Guidelines

### Skill Categories

When adding skills, organize them into these categories:

1. **Diagnostics** - Health checks, troubleshooting, configuration validation
2. **Optimization** - Performance tuning, workflow improvements
3. **Education** - Best practices, patterns, tutorials
4. **Utilities** - Common tasks, shortcuts, automation

### Naming Conventions

- Commands: `commands/{action}-{target}.md` (e.g., `diagnose-mcp.md`)
- Skills: `skills/{category}/{skill-name}/SKILL.md`
- Agents: `agents/{purpose}.md`

### MCP Tool References

When documenting MCP tools, always include:
- Tool name and server
- Required parameters
- Example usage
- Common error handling

### Skill Documentation Standards

**Frontmatter voice**: Use third-person in skill descriptions:
- ✅ `description: This skill should be used when working with...`
- ❌ `description: Use when working with...`

**Second-person avoidance**: Instructional text in skills/agents should avoid "you":
- ✅ "Enable only the tools needed"
- ❌ "Enable only tools you'll use"
- Exception: "you" is acceptable in example dialogues showing patterns

**Documentation deduplication**: When information (tables, lists) appears in multiple files:
1. Keep one canonical source (e.g., `shared-parameters.md`)
2. Reference it from other locations: `> See shared-parameters.md for the complete table`
3. Include a brief summary where referenced for quick access

**Disabled/optional features**: Document even typically-disabled tools/features:
- Add note at top: `> **Note**: This tool is typically disabled via DISABLED_TOOLS`
- Explain when to enable
- Keep documentation minimal but complete

**Version markers**: Add compatibility notes to workflow templates:
- `> **Compatibility**: Verified against [tool] v1.x (Month Year)`
- Helps users identify potentially stale examples

**Parameter naming inconsistencies**: When similar parameters have different names across tools, document explicitly:
- Example: "`clink` uses `absolute_file_paths` while other tools use `relevant_files`"

## Plugin Path Variable

Use `$CLAUDE_PLUGIN_ROOT` to reference plugin-relative paths in commands and agents.

## Future Additions

Planned components:
- MCP diagnostic commands
- Configuration validators
- Workflow templates
- Best practices reference

## Quality Verification Checklist

Before committing skill/documentation changes:

- [ ] Frontmatter uses third-person voice ("This skill should be used when...")
- [ ] No second-person ("you") in instructional text (examples excepted)
- [ ] No duplicate tables/lists across files (use references instead)
- [ ] All tool references in SKILL.md have corresponding `tool-*.md` files
- [ ] Disabled features documented with enable conditions
- [ ] Workflow templates include version/compatibility markers
- [ ] Parameter naming inconsistencies documented in shared references

---

*Last updated: 2026-02-01*
