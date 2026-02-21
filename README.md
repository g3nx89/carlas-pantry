# Carla's Pantry

A curated marketplace of Claude Code plugins for product development workflows.

## Available Plugins

| Plugin | Version | Description | Category |
|--------|---------|-------------|----------|
| [product-definition](plugins/product-definition) | 2.2.0 | Transform drafts into PRDs, generate specifications, and create UX narratives from Figma mockups — with MPA, PAL consensus, V-Model test strategies, and batch multi-screen processing | product-development |
| [product-planning](plugins/product-planning) | 1.2.0 | Transform specifications into implementation plans, tasks, and test strategies using SDD patterns with tri-CLI (Gemini + Codex + OpenCode) deep analysis and consensus scoring | product-development |
| [product-implementation](plugins/product-implementation) | 3.0.0 | Execute implementation plans from product-planning, orchestrating TDD cycles, code generation, quality review, documentation, and implementation retrospective with KPI framework | product-development |
| [meta-skills](plugins/meta-skills) | 0.8.0 | 8 skills for mastering Claude Code, MCP servers, and agentic workflows — Figma Console + figma-use (170+ tools, per-screen Draft-to-Handoff with user decision gates, GROUP→FRAME conversion, constraint formulas, 9-step handoff checklist, convergence protocol, subagent delegation), Sequential Thinking, research MCP, mobile MCP, PAL multi-model, deep reasoning escalation, skill analyzer | productivity |
| [dev-skills](plugins/dev-skills) | 1.4.0 | 22 skills for software design and development — mobile (Android, Compose, Kotlin, CLI testing/benchmarking/a11y), web (frontend, accessibility, scroll), database, API, architecture, code quality, QA, and Figma integration | development |

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
