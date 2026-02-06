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

### Skill Authoring Standards

#### Hub-Spoke Model (Progressive Disclosure)

- SKILL.md should be lean: 1,500-2,000 words max, ideally under 300 lines
- Include brief patterns and code snippets in SKILL.md, full details in `references/`
- Every skill with reference files MUST have a **Reference Map** table:
  ```markdown
  ## Reference Map
  | Topic | Reference File | When to Read |
  |-------|----------------|--------------|
  | Navigation | `references/nav.md` | Setting up routes |
  ```
- After any skill rewrite, verify ALL reference files appear in the Reference Map (prevent orphaned files)

#### Required Sections

Every skill SKILL.md should include:
- **When to Use** - Trigger conditions
- **When NOT to Use** - Delegation to other skills with format: `- **Domain** → Use \`skill-name\` skill`
- **Reference Map** - If references/ directory exists
- **Anti-Patterns** - Common mistakes to avoid
- **Quick Reference** - Lookup table for frequent patterns

#### Cross-References Between Skills

- Use plain skill names in Related Skills tables: `database-design`, NOT `@[skills/database-design]`
- Validate all referenced skill names exist as directories under `skills/`
- Broken cross-references cause silent failures (skill not found, no error)

#### Content Deduplication

- Keep canonical definitions (Priority, Severity tables) in SKILL.md
- Replace duplicates in reference files with: `> **Note:** For [X] Definitions, see the main SKILL.md file.`
- When reference files overlap on a topic (e.g., styling), add cross-reference to the canonical source file rather than extracting into shared files
- Unique content in reference files (Response Time Guidelines, Priority vs Severity Matrix) should be surfaced in SKILL.md if frequently needed

#### Generalization Rules

- Use generic examples, not project-specific ones (e.g., `AppTheme` not `AmethystTheme`)
- Use placeholder paths (`app/src/main/...`) not hardcoded project paths
- Use generic deep link schemes (`myapp://`) not project-specific ones
- "When NOT to Use" should reference skills that actually exist in this plugin

#### Formatting Consistency

- No emoji in markdown section headers (`## Title`, not `## 🎯 Title`)
- Emoji in table cells for visual cues (❌/✅) is acceptable
- Use imperative/infinitive form in skill body text

### Skill Quality Verification

After creating or modifying skills:

- [ ] SKILL.md under 300 lines with Reference Map table
- [ ] "When NOT to Use" section present with valid skill references
- [ ] All files in `references/` listed in Reference Map
- [ ] No duplicate tables between SKILL.md and reference files
- [ ] No project-specific hardcoded content (paths, theme names, protocols)
- [ ] Cross-referenced skill names validated against existing `skills/` directories
- [ ] No emoji in section headers
