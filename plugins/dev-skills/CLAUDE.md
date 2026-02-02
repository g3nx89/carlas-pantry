# dev-skills Plugin

## Purpose

This plugin provides skills to support software design and development activities.

## Structure

```
dev-skills/
├── .claude-plugin/plugin.json   # Plugin manifest
├── skills/                       # Development skills
└── README.md                     # Public documentation
```

## Development Guidelines

### Adding a New Skill

1. Create skill directory: `skills/{skill-name}/`
2. Add `SKILL.md` with frontmatter defining the skill
3. Add supporting files in `references/` subdirectory if needed
4. Update README.md with skill documentation
