# Figma MCP Tools and Prompt Patterns

Quick reference for Figma MCP tools and prompt patterns to steer output.

## Core Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `get_design_context` | Structured design data + default React/Tailwind code | Primary tool, always start here |
| `get_screenshot` | Visual screenshot of selection | Visual reference for validation |
| `get_metadata` | Sparse XML outline (IDs, names, types, positions) | Before re-calling on large nodes |
| `get_variable_defs` | Variables/styles (colors, spacing, typography) | Align with design tokens |

## Additional Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `get_figjam` | XML + screenshots for FigJam diagrams | Architecture, flow diagrams |
| `create_design_system_rules` | Generate design-to-code guidance | Initial project setup |
| `get_code_connect_map` | Node-to-component mappings | Check existing Code Connect |
| `add_code_connect_map` | Add/update Code Connect mapping | Link Figma node to code |
| `whoami` | Authenticated user identity | Verify connection (remote only) |

## Prompt Patterns

### Change Framework

```
"generate my Figma selection in Vue"
"generate in plain HTML + CSS"
"implement this for iOS"
"generate in React Native"
"use Svelte components"
```

### Use Custom Components

```
"generate using components from `src/components/ui`"
"use my Button component from `@/ui/Button`"
"integrate with my design system in `packages/ui`"
```

### Combine Framework + Components

```
"generate my Figma selection using components from `src/ui` and style with Tailwind"
"implement in Vue using my component library in `@/components`"
```

### Variables and Styles

```
"get the variables used in my Figma selection"
"what color and spacing variables are used?"
"list variable names and their values"
"show me the design tokens for this selection"
```

### Code Connect

```
"show the code connect map for this selection"
"map this node to `src/components/ui/Button.tsx` with name `Button`"
"what code component is connected to this Figma node?"
```

### Large/Complex Designs

```
"first get metadata to understand the structure"
"break this down into individual sections"
"fetch each section separately to avoid truncation"
```

## Best Practice Flow

```
1. get_design_context → Primary design data
2. get_metadata       → (if large/truncated) Get node structure
3. get_variable_defs  → (optional) Align with tokens
4. get_screenshot     → Visual reference for validation
5. Implement          → Apply project conventions
6. Validate           → Compare with screenshot
```

## Tool Output Interpretation

### get_design_context Output

- **Layout properties:** Auto Layout, constraints, sizing
- **Typography:** Font family, size, weight, line height
- **Colors:** Fill colors, stroke colors, with token names if available
- **Spacing:** Padding, gaps, margins
- **Component info:** Variants, props, nested components

### get_metadata Output

- **XML format:** Sparse outline for navigation
- **Node IDs:** Use to fetch specific child nodes
- **Types:** Identify component instances, frames, groups
- **Positions/Sizes:** Layout understanding

### get_variable_defs Output

- **Color variables:** Primary, secondary, semantic colors
- **Spacing variables:** Scale values (4, 8, 12, 16...)
- **Typography variables:** Font sizes, line heights, weights

## Common Combinations

| Goal | Tools |
|------|-------|
| Implement single component | `get_design_context` → `get_screenshot` |
| Implement complex page | `get_metadata` → `get_design_context` (per section) → `get_screenshot` |
| Align with tokens | `get_variable_defs` → `get_design_context` |
| Connect to code | `get_code_connect_map` → `add_code_connect_map` |
