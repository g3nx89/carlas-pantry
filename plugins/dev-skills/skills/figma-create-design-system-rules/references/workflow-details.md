# Design System Rules Workflow Details

Detailed workflow, rule templates, and examples for creating project-specific design system rules.

## What Are Design System Rules?

Design system rules encode the "unwritten knowledge" of your codebase:
- Which layout primitives and components to use
- Where component files should be located
- How components should be named and structured
- What should never be hardcoded
- How to handle design tokens and styling
- Project-specific architectural patterns

---

## Detailed Workflow

### Step 1: Run create_design_system_rules Tool

Call the Figma MCP server's `create_design_system_rules` tool:

```
create_design_system_rules(
  clientLanguages="typescript,javascript",
  clientFrameworks="react"
)
```

This returns guidance and a template for creating design system rules.

### Step 2: Analyze the Codebase

**Component Organization:**
- Where are UI components located? (`src/components/`, `app/ui/`, `lib/components/`)
- Is there a dedicated design system directory?
- How are components organized? (by feature, by type, flat structure)

**Styling Approach:**
- CSS framework or approach? (Tailwind, CSS Modules, styled-components)
- Where are design tokens defined? (CSS variables, theme files, config files)
- Existing color, typography, or spacing tokens?

**Component Patterns:**
- Naming conventions? (PascalCase, kebab-case, prefixes)
- How are component props structured?
- Common composition patterns?

**Architecture Decisions:**
- State management approach?
- Routing system?
- Import patterns or path aliases?

### Step 3: Generate Project-Specific Rules

Based on codebase analysis, create comprehensive rules.

### Step 4: Save Rules to CLAUDE.md

Save generated rules to project's `CLAUDE.md`:

```markdown
# MCP Servers

## Figma MCP Server Rules

[Generated rules here]
```

### Step 5: Validate and Iterate

1. Test with a simple Figma component implementation
2. Verify rules are followed correctly
3. Refine rules that aren't working
4. Share with team for feedback
5. Update as project evolves

---

## Rule Templates

### Essential Component Rules

```markdown
## Component Organization

- UI components are in `src/components/ui/`
- Feature components are in `src/components/features/`
- Layout primitives are in `src/components/layout/`
- IMPORTANT: Always use components from `[YOUR_PATH]` when possible
- Follow `[NAMING_CONVENTION]` for component names
```

### Styling Rules

```markdown
## Styling Rules

- Use `[CSS_FRAMEWORK/APPROACH]` for styling
- Design tokens are defined in `[TOKEN_LOCATION]`
- IMPORTANT: Never hardcode colors - use tokens from `[TOKEN_FILE]`
- Spacing values must use the `[SPACING_SYSTEM]` scale
- Typography follows the scale defined in `[TYPOGRAPHY_LOCATION]`
```

### Figma MCP Integration Rules

```markdown
## Figma MCP Integration Rules

### Required Flow (do not skip)

1. Run get_design_context first to fetch structured representation
2. If response truncated, run get_metadata to get high-level node map, then re-fetch specific nodes
3. Run get_screenshot for visual reference
4. Only after context and screenshot, download assets and start implementation
5. Translate output into project conventions, styles, and framework
6. Validate against Figma for 1:1 look and behavior

### Implementation Rules

- Treat Figma MCP output (React + Tailwind) as design representation, not final code
- Replace Tailwind classes with `[YOUR_STYLING_APPROACH]` when applicable
- Reuse components from `[COMPONENT_PATH]` instead of duplicating
- Use project's color system, typography scale, and spacing tokens
- Respect existing routing, state management, and data-fetch patterns
- Strive for 1:1 visual parity
- Validate final UI against Figma screenshot
```

### Asset Handling Rules

```markdown
## Asset Handling

- Figma MCP server provides assets endpoint for images and SVGs
- IMPORTANT: If Figma returns localhost source for image/SVG, use it directly
- IMPORTANT: DO NOT import/add new icon packages
- IMPORTANT: DO NOT use placeholders if localhost source provided
- Store downloaded assets in `[ASSET_DIRECTORY]`
```

### Project-Specific Conventions

```markdown
## Project-Specific Conventions

- [Unique architectural patterns]
- [Special import requirements]
- [Testing requirements]
- [Accessibility standards]
- [Performance considerations]
```

---

## Complete Examples

### Example 1: React + Tailwind Project

```markdown
# Figma MCP Integration Rules

## Component Organization

- UI components are in `src/components/ui/`
- Page components are in `src/app/`
- Use Tailwind for styling

## Figma Implementation Flow

1. Run get_design_context for the node
2. Run get_screenshot for visual reference
3. Map Figma colors to Tailwind colors in `tailwind.config.js`
4. Reuse components from `src/components/ui/` when possible
5. Validate against screenshot before completing

## Styling Rules

- IMPORTANT: Use Tailwind utility classes, not inline styles
- Colors defined in `tailwind.config.js` theme.colors
- Spacing uses Tailwind's default scale
- Custom components go in `src/components/ui/`

## Asset Rules

- IMPORTANT: Use localhost sources from Figma MCP server directly
- Store static assets in `public/assets/`
- DO NOT install new icon libraries
```

### Example 2: Vue + CSS Modules

```markdown
# Figma MCP Integration Rules

## Component Organization

- Components in `src/components/`
- Composables in `src/composables/`
- Vue SFC structure: <script setup>, <template>, <style scoped>

## Design Tokens

- IMPORTANT: All colors defined in `src/styles/tokens.css` as CSS variables
- Use `var(--color-primary)`, `var(--color-secondary)`, etc.
- Spacing: `var(--space-xs)` through `var(--space-xl)`
- Typography: `var(--text-sm)` through `var(--text-2xl)`

## Figma Implementation Flow

1. Run get_design_context and get_screenshot
2. Translate React output to Vue 3 Composition API
3. Map Figma colors to CSS variables in `src/styles/tokens.css`
4. Use CSS Modules for component styles
5. Check existing components in `src/components/` before creating new

## Styling Rules

- Use CSS Modules (`.module.css` files)
- IMPORTANT: Reference design tokens, never hardcode values
- Scoped styles with CSS modules
```

### Example 3: Design System Monorepo

```markdown
# Design System Rules

## Repository Structure

- Design system components: `packages/design-system/src/components/`
- Documentation: `packages/docs/`
- Design tokens: `packages/tokens/src/`

## Component Development

- IMPORTANT: All components in `packages/design-system/src/components/`
- File structure: `ComponentName/index.tsx`, `ComponentName.stories.tsx`, `ComponentName.test.tsx`
- Export all components from `packages/design-system/src/index.ts`

## Design Tokens

- Colors: `packages/tokens/src/colors.ts`
- Typography: `packages/tokens/src/typography.ts`
- Spacing: `packages/tokens/src/spacing.ts`
- IMPORTANT: Never hardcode values - import from tokens package

## Documentation Requirements

- Add Storybook story for every component
- Include JSDoc with @example
- Document all props with descriptions
- Add accessibility notes

## Figma Integration

1. Get design context and screenshot from Figma
2. Map Figma tokens to design system tokens
3. Create or extend component in design system package
4. Add Storybook stories for all variants
5. Validate against Figma screenshot
6. Update documentation
```

---

## Troubleshooting

### Rules aren't being followed

**Cause:** Rules may be too vague or not properly loaded.

**Solution:**
- Make rules more specific and actionable
- Verify rules are saved in correct CLAUDE.md
- Add "IMPORTANT:" prefix to critical rules

### Rules conflict with each other

**Cause:** Contradictory or overlapping rules.

**Solution:**
- Review all rules for conflicts
- Establish clear priority hierarchy
- Remove redundant rules
- Consolidate related rules

### Too many rules slow things down

**Cause:** Excessive rules increase context size.

**Solution:**
- Focus on 20% of rules that solve 80% of issues
- Remove overly specific rules
- Combine related rules
- Use progressive disclosure

### Rules become outdated

**Cause:** Codebase changes but rules don't.

**Solution:**
- Schedule periodic rule reviews
- Update rules with architectural changes
- Version control rule files
- Document rule changes in commits
