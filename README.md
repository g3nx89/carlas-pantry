# Carla's Pantry

A curated marketplace of Claude Code plugins for product development workflows.

## Available Plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| [product-definition](plugins/product-definition) | Transform rough product drafts into finalized PRDs through iterative Q&A | `claude plugins add https://github.com/g3nx89/carlas-pantry/plugins/product-definition` |

## Installation

### From GitHub

```bash
claude plugins add https://github.com/g3nx89/carlas-pantry/plugins/PLUGIN_NAME
```

### From Local Clone

```bash
git clone https://github.com/g3nx89/carlas-pantry.git
claude plugins add ./carlas-pantry/plugins/PLUGIN_NAME
claude plugins enable PLUGIN_NAME
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
