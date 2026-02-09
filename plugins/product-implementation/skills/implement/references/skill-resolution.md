# Skill Reference Resolution Algorithm

Shared algorithm used by Stage 2, Stage 4, and Stage 5 coordinators to resolve domain-specific skill references from `detected_domains`. Each stage calls this algorithm with different parameters.

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `{source_config_key}` | Which config sub-section supplies the skill list | `domain_mapping`, `documentation_skills` |
| `{base_skills}` | Starting skill list before domain matching | `always_include` entries, or `documentation_skills.always` |
| `{fallback_text}` | Stage-specific fallback when no skills apply | `"No domain-specific skills available — ..."` |
| `{format_preamble}` | Introductory text for the formatted block | `"The following dev-skills are relevant..."` |

## Algorithm

```
1. Read `detected_domains` from the Stage 1 summary YAML frontmatter (top-level field, not nested under flags)
2. If `detected_domains` is empty or not present → return {fallback_text}
3. Read `dev_skills` section from $CLAUDE_PLUGIN_ROOT/config/implementation-config.yaml
4. If `dev_skills.enabled` is false → return {fallback_text}

5. Build skill list:
   a. Start with {base_skills} (these do NOT count toward the domain cap)
   b. For each domain in `detected_domains`:
      - Look up `dev_skills.{source_config_key}[domain].skills`
      - Add matched skills to the list
   c. Deduplicate (preserve first occurrence)
   d. Cap DOMAIN skills at `dev_skills.max_skills_per_dispatch` (default: 3)
      — {base_skills} are exempt from this cap
      — If more domain skills matched than the cap allows, keep in order
        of appearance in `detected_domains`

6. Resolve skill paths:
   - Plugin root: $CLAUDE_PLUGIN_ROOT/../{dev_skills.plugin_path}
     (sibling plugin in the same plugins/ directory)
   - For each skill, verify the SKILL.md file exists at the resolved path:
     $CLAUDE_PLUGIN_ROOT/../{plugin_path}/skills/{skill_name}/SKILL.md
   - If a skill file does not exist, omit it from the list and log a warning:
     "Skill {skill_name} not found at expected path — skipping"
   - If ALL skills are omitted (none found) → return {fallback_text}

7. Format output:
   {format_preamble}

   {for each resolved skill:}
   - **{skill_name}**: `{resolved_path}` — {reason or domain}
```

## Usage by Stage

### Stage 2 (Implementation)

```
source_config_key: domain_mapping
base_skills: dev_skills.always_include[].skill
fallback_text: "No domain-specific skills available — proceed with standard
               implementation patterns from the codebase."
format_preamble: "The following dev-skills are relevant to this implementation
                  domain. Consult their SKILL.md for patterns, anti-patterns,
                  and decision trees. Read on-demand — do NOT read all upfront.
                  Codebase conventions (CLAUDE.md, constitution.md) always take
                  precedence over skill guidance."
```

### Stage 4 (Quality Review)

Uses the same parameters as Stage 2 for base skill resolution. Additionally resolves conditional reviewers — see `stage-4-quality-review.md` Section 4.1a for the conditional reviewer extension.

### Stage 5 (Documentation)

```
source_config_key: documentation_skills.conditional
base_skills: dev_skills.documentation_skills.always
fallback_text: "No documentation skills available — produce prose documentation
               without diagrams."
format_preamble: "The following dev-skills provide diagram and documentation
                  patterns. Use Mermaid.js syntax for inline diagrams. Read
                  skill SKILL.md on-demand for syntax reference and best practices."
```

## Path Resolution

Skill paths use the **sibling plugin** pattern: `$CLAUDE_PLUGIN_ROOT/../{plugin_path}/skills/{skill_name}/SKILL.md`. This works because all plugins are installed under the same `plugins/` directory. `$CLAUDE_PLUGIN_ROOT` resolves to the current plugin's root (e.g., `plugins/product-implementation/`), so `../dev-skills/` reaches the sibling plugin.

## Context Budget

The formatted output adds ~5-10 lines to the agent prompt (skill paths only, not content). Agents read skill SKILL.md files on-demand when encountering relevant implementation decisions — they do NOT preload all skills into context.
