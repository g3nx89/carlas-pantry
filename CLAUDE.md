# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Carla's Pantry is a marketplace/collection of Claude Code plugins focused on product development workflows. Each plugin is a self-contained directory under `plugins/`.

## Repository Structure

```
carlas-pantry/
├── plugins/
│   └── {plugin-name}/
│       ├── .claude-plugin/plugin.json   # Required manifest
│       ├── commands/                     # Slash commands (*.md)
│       ├── agents/                       # Subagent definitions (*.md)
│       ├── templates/                    # Document templates
│       ├── config/                       # Plugin configuration
│       └── README.md                     # Plugin docs
└── README.md                             # Marketplace index
```

## Plugin Development

### Creating a New Plugin

1. Create directory: `plugins/{plugin-name}/`
2. Add manifest: `.claude-plugin/plugin.json`
3. Add at least one command in `commands/`
4. Document in `README.md`

### Plugin Manifest Format

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "What this plugin does",
  "author": { "name": "Author Name" },
  "keywords": ["relevant", "tags"],
  "license": "MIT"
}
```

### Testing Plugins Locally

```bash
claude plugins add ./plugins/plugin-name
claude plugins enable plugin-name
```

## Conventions

- Plugin names: lowercase with hyphens (`product-definition`)
- Commands: `commands/{command-name}.md` with YAML frontmatter
- Agents: `agents/{domain}-{role}.md` with model specification
- Use `$CLAUDE_PLUGIN_ROOT` for plugin-relative paths in prompts
