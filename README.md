# Carla's Pantry

A curated marketplace of Claude Code plugins for product development workflows.

## Available Plugins

| Plugin | Description | Category |
|--------|-------------|----------|
| [product-definition](plugins/product-definition) | Transform drafts into PRDs, generate specifications, and create UX narratives from Figma mockups — with MPA, PAL consensus, and V-Model test strategies | product-development |
| [product-planning](plugins/product-planning) | Transform specifications into implementation plans, tasks, and test strategies using SDD patterns | product-development |
| [product-implementation](plugins/product-implementation) | Execute implementation plans from product-planning, orchestrating TDD cycles, code generation, and verification | product-development |
| [meta-skills](plugins/meta-skills) | Meta-skills for mastering Claude Code, MCP servers, and agentic workflows | productivity |
| [dev-skills](plugins/dev-skills) | Skills to support software design and development activities | development |

## Installation

### Add the Marketplace

**From GitHub:**
```bash
/plugin marketplace add g3nx89/carlas-pantry
```

**From local clone:**
```bash
git clone https://github.com/g3nx89/carlas-pantry.git
/plugin marketplace add ./carlas-pantry
```

### Install a Plugin

Once the marketplace is added, install plugins by name:
```bash
/plugin install product-definition@carlas-pantry
```

### Update the Marketplace

To get the latest plugins and updates:
```bash
/plugin marketplace update carlas-pantry
```

## Plugin Structure

Each plugin in `plugins/` follows the Claude Code plugin specification:

```
plugins/
└── plugin-name/
    ├── .claude-plugin/
    │   └── plugin.json      # Plugin manifest
    ├── commands/            # Slash commands
    ├── agents/              # Subagent definitions
    ├── templates/           # Document templates
    ├── config/              # Configuration files
    └── README.md            # Plugin documentation
```

## Contributing

To add a plugin to Carla's Pantry:

1. Create a new directory under `plugins/`
2. Include a `.claude-plugin/plugin.json` manifest
3. Add a README.md with usage instructions
4. Submit a PR

## License

MIT
