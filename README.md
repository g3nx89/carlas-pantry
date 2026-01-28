# Carla's Pantry

A curated marketplace of Claude Code plugins for product development workflows.

## Available Plugins

| Plugin | Description | Category |
|--------|-------------|----------|
| [product-definition](plugins/product-definition) | Transform rough product drafts into finalized PRDs through iterative Q&A | product-development |

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
